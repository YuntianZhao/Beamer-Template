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

compile_fixture() {
  local name="$1"
  local engine="$2"
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
    -jobname="$name" -outdir="$output_dir" "tests/fixtures/$name.tex"
}

check_dark() {
  local name=dark-semantic-colors
  local output_dir="$BUILD_ROOT/$name"
  local xml="$output_dir/$name.xml"

  compile_fixture "$name" lualatex
  pdftohtml -xml -stdout "$output_dir/$name.pdf" > "$xml"
  # Poppler 26.07.0 truncates selected RGB channels when serializing PDF colors.
  if ! rg --fixed-strings --quiet \
    -e 'color="#f85149"' -e 'color="#f85148"' -- "$xml"; then
    printf 'FAIL: dark alerted text should use GitHubRed\n' >&2
    exit 1
  fi
  if ! rg --fixed-strings --quiet \
    -e 'color="#2f81f7"' -e 'color="#2e80f7"' -- "$xml"; then
    printf 'FAIL: dark structure text should use GitHubBlue\n' >&2
    exit 1
  fi
  assert_present 'color="#3fb950"' "$xml" 'dark example text should use GitHubGreen'
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
  compile_fixture url-fragment lualatex
}

case "$FILTER" in
  all)
    check_dark
    check_pdflatex
    check_fields
    check_url
    ;;
  dark) check_dark ;;
  pdflatex) check_pdflatex ;;
  fields) check_fields ;;
  url) check_url ;;
  *)
    printf 'ERROR: unknown runtime check %s.\n' "$FILTER" >&2
    exit 1
    ;;
esac

printf 'Runtime checks passed (%s).\n' "$FILTER"
