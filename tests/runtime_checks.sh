#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/beamer-runtime-checks.XXXXXX")
FILTER=${1:-all}

cleanup() {
  rm -rf "$BUILD_ROOT"
}
trap cleanup EXIT

cd "$ROOT_DIR"

for command_name in latexmk biber pdffonts pdftohtml pdfinfo pdftotext rg; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'ERROR: %s is required by tests/runtime_checks.sh.\n' "$command_name" >&2
    exit 1
  fi
done

assert_present() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! rg --fixed-strings --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

assert_regex() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! rg --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  local status

  if rg --fixed-strings --quiet -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  else
    status=$?
    if [ "$status" -ne 1 ]; then
      printf 'FAIL: unable to inspect %s for: %s\n' "$file" "$message" >&2
      exit 1
    fi
  fi
}

assert_pdf_text_color() {
  local text="$1"
  local color_pattern="$2"
  local xml="$3"
  local message="$4"
  local text_line
  local font_id
  local status

  if text_line=$(rg --fixed-strings --max-count 1 -- "$text" "$xml"); then
    :
  else
    status=$?
    if [ "$status" -eq 1 ]; then
      printf 'FAIL: %s (probe text not found)\n' "$message" >&2
    else
      printf 'FAIL: unable to inspect %s for: %s\n' "$xml" "$message" >&2
    fi
    exit 1
  fi

  font_id=${text_line#* font=\"}
  if [ "$font_id" = "$text_line" ]; then
    printf 'FAIL: %s (probe font not found)\n' "$message" >&2
    exit 1
  fi
  font_id=${font_id%%\"*}
  if ! rg --quiet -- "<fontspec id=\"$font_id\"[^>]*color=\"$color_pattern\"" "$xml"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

assert_clean_log() {
  local log="$1"
  local message="$2"
  local pattern='Overfull \\[hv]box|LaTeX Font Warning|Package biblatex Warning: Conflicting options|There were undefined references|Please rerun LaTeX|Please \(re\)run Biber|Missing character'
  local status

  if rg --quiet -- "$pattern" "$log"; then
    printf 'FAIL: %s\n' "$message" >&2
    rg -- "$pattern" "$log" >&2
    exit 1
  else
    status=$?
    if [ "$status" -ne 1 ]; then
      printf 'FAIL: unable to inspect %s for warnings.\n' "$log" >&2
      exit 1
    fi
  fi
}

compile_source() {
  local name="$1"
  local engine="$2"
  local source="$3"
  local engine_flag
  local output_dir="$BUILD_ROOT/$name"

  case "$engine" in
    lualatex) engine_flag=-lualatex ;;
    pdflatex) engine_flag=-pdf ;;
    xelatex) engine_flag=-xelatex ;;
    *)
      printf 'ERROR: unsupported fixture engine %s.\n' "$engine" >&2
      exit 1
      ;;
  esac

  mkdir -p "$output_dir"
  latexmk -g "$engine_flag" -interaction=nonstopmode -halt-on-error \
    -jobname="$name" -outdir="$output_dir" "$source"
}

compile_fixture() {
  local name="$1"
  local engine="$2"
  compile_source "$name" "$engine" "tests/fixtures/$name.tex"
}

check_dark() {
  local name=dark-semantic-colors
  local output_dir="$BUILD_ROOT/$name"
  local xml="$output_dir/$name.xml"

  compile_fixture "$name" lualatex
  pdftohtml -xml -stdout "$output_dir/$name.pdf" > "$xml"
  # Poppler 26.07.0 truncates selected RGB channels when serializing PDF colors.
  assert_pdf_text_color 'Alert probe.' '#(f85149|f85148)' "$xml" 'dark alert probe should use GitHubRed'
  assert_pdf_text_color 'Structure probe.' '#(2f81f7|2e80f7)' "$xml" 'dark structure probe should use GitHubBlue'
  assert_pdf_text_color 'Example probe.' '#3fb950' "$xml" 'dark example probe should use GitHubGreen'
}

check_pdflatex() {
  local name=pdflatex-compatibility
  local output_dir="$BUILD_ROOT/$name"
  local log="$output_dir/$name.log"
  local fonts="$output_dir/$name.fonts"

  compile_fixture "$name" pdflatex
  pdffonts "$output_dir/$name.pdf" > "$fonts"
  assert_absent 'Missing = inserted for \ifnum' "$log" 'multi-token calligraphic math should compile under pdfLaTeX'
  assert_absent 'LaTeX Font Warning: Font shape `T1/LibertinusSans-TLF/b/it' "$log" 'pdfLaTeX should use an explicit italic-preserving fallback'
  assert_absent 'Some font shapes were not available' "$log" 'pdfLaTeX should not finish with font substitutions'
  assert_present 'LibertinusSans-Italic' "$fonts" 'bold-italic fallback should preserve italic emphasis'
}

check_fields() {
  local name=beamer-fields
  local output_dir="$BUILD_ROOT/$name"
  local text="$output_dir/$name.txt"
  local info="$output_dir/$name.info"

  compile_fixture "$name" lualatex
  pdftotext "$output_dir/$name.pdf" "$text"
  pdfinfo "$output_dir/$name.pdf" > "$info"
  assert_present 'Metadata Subtitle' "$text" 'title subtitle should render'
  assert_present 'Institute Probe' "$text" 'institute should render'
  assert_present 'Title Graphic Probe' "$text" 'title graphic should render'
  assert_present 'Frame Subtitle Probe' "$text" 'frame subtitle should render'
  assert_regex '^Title:[[:space:]]+Metadata Title - Metadata Subtitle$' "$info" 'PDF title should follow title and subtitle'
  assert_regex '^Author:[[:space:]]+Metadata Author$' "$info" 'PDF author should follow the Beamer author'
}

check_url() {
  local name=url-fragment
  local output_dir="$BUILD_ROOT/$name"
  local text="$output_dir/$name.txt"
  local xml="$output_dir/$name.xml"
  local url='https://example.test/paper#section'

  compile_fixture "$name" lualatex
  pdftotext "$output_dir/$name.pdf" "$text"
  pdftohtml -xml -stdout "$output_dir/$name.pdf" > "$xml"
  assert_present "$url" "$text" 'rendered paper URL should retain its fragment'
  assert_present "href=\"$url\"" "$xml" 'paper URL annotation should retain its fragment target'
}

check_sample() {
  compile_source presentation-default lualatex presentation.tex
  assert_clean_log "$BUILD_ROOT/presentation-default/presentation-default.log" 'default LuaLaTeX sample should be warning-clean'

  compile_source presentation-default-pdf pdflatex presentation.tex
  assert_clean_log "$BUILD_ROOT/presentation-default-pdf/presentation-default-pdf.log" 'default pdfLaTeX sample should be warning-clean'

  compile_source presentation-12pt-169 lualatex tests/fixtures/presentation-12pt-169.tex
  assert_clean_log "$BUILD_ROOT/presentation-12pt-169/presentation-12pt-169.log" '12pt 16:9 sample should be warning-clean'
}

case "$FILTER" in
  all)
    check_dark
    check_pdflatex
    check_fields
    check_url
    check_sample
    ;;
  dark) check_dark ;;
  pdflatex) check_pdflatex ;;
  fields) check_fields ;;
  url) check_url ;;
  sample) check_sample ;;
  *)
    printf 'ERROR: unknown runtime check %s.\n' "$FILTER" >&2
    exit 1
    ;;
esac

printf 'Runtime checks passed (%s).\n' "$FILTER"
