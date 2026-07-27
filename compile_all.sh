#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCK_DIR="$ROOT_DIR/.build-presentation-variants.lock"
TEST_OUTPUT_DIR="$ROOT_DIR/output/test"
BUILD_DIR=
STAGING_DIR=

cd "$ROOT_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  printf 'ERROR: another compile_all.sh run is active.\n' >&2
  exit 1
fi

cleanup() {
  if [ -n "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
  fi
  if [ -n "$STAGING_DIR" ]; then
    rm -rf "$STAGING_DIR"
  fi
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$ROOT_DIR/output"
BUILD_DIR=$(mktemp -d "$ROOT_DIR/.build-presentation-variants.XXXXXX")
STAGING_DIR=$(mktemp -d "$ROOT_DIR/output/.test.XXXXXX")

if ! command -v latexmk >/dev/null 2>&1; then
  if ! command -v lualatex >/dev/null 2>&1; then
    printf 'ERROR: latexmk not found and lualatex is required for fallback builds.\n' >&2
    exit 1
  fi
  if ! command -v biber >/dev/null 2>&1; then
    printf 'ERROR: latexmk not found and biber is required for bibliography builds.\n' >&2
    exit 1
  fi
fi

write_wrapper() {
  local jobname="$1"
  local fontsize="$2"
  local aspectratio="$3"
  local mode="$4"

  cat > "$BUILD_DIR/$jobname.tex" <<EOF
\\newcommand{\\presentationfontsize}{$fontsize}
\\newcommand{\\presentationaspectratio}{$aspectratio}
\\newcommand{\\presentationmode}{$mode}
\\input{presentation.tex}
EOF
}

compile_pdf() {
  local jobname="$1"
  local destination_dir="$2"
  local warning_pattern='Overfull \\[hv]box|LaTeX Font Warning|Package biblatex Warning: Conflicting options|There were undefined references|Please rerun LaTeX|Please \(re\)run Biber|Missing character'
  local grep_status

  printf 'Building %s.pdf\n' "$jobname"

  if command -v latexmk >/dev/null 2>&1; then
    latexmk \
      -lualatex \
      -interaction=nonstopmode \
      -halt-on-error \
      -file-line-error \
      -jobname="$jobname" \
      -outdir="$BUILD_DIR" \
      "$BUILD_DIR/$jobname.tex"
  else
    lualatex \
      -interaction=nonstopmode \
      -halt-on-error \
      -file-line-error \
      -jobname="$jobname" \
      -output-directory="$BUILD_DIR" \
      "$BUILD_DIR/$jobname.tex"
    biber \
      --input-directory "$BUILD_DIR" \
      --output-directory "$BUILD_DIR" \
      "$jobname"
    lualatex \
      -interaction=nonstopmode \
      -halt-on-error \
      -file-line-error \
      -jobname="$jobname" \
      -output-directory="$BUILD_DIR" \
      "$BUILD_DIR/$jobname.tex"
    lualatex \
      -interaction=nonstopmode \
      -halt-on-error \
      -file-line-error \
      -jobname="$jobname" \
      -output-directory="$BUILD_DIR" \
      "$BUILD_DIR/$jobname.tex"
  fi

  if [ ! -f "$BUILD_DIR/$jobname.log" ]; then
    printf 'ERROR: %s.log was not produced.\n' "$jobname" >&2
    exit 1
  fi
  if grep -Eq "$warning_pattern" "$BUILD_DIR/$jobname.log"; then
    printf 'ERROR: %s.log contains a release-blocking warning.\n' "$jobname" >&2
    grep -E "$warning_pattern" "$BUILD_DIR/$jobname.log" >&2
    exit 1
  else
    grep_status=$?
    if [ "$grep_status" -ne 1 ]; then
      printf 'ERROR: unable to inspect %s.log.\n' "$jobname" >&2
      exit 1
    fi
  fi

  cp "$BUILD_DIR/$jobname.pdf" "$destination_dir/$jobname.pdf"
}

build_variant() {
  local jobname="$1"
  local fontsize="$2"
  local aspectratio="$3"
  local mode="$4"
  local destination_dir="$5"

  write_wrapper "$jobname" "$fontsize" "$aspectratio" "$mode"
  compile_pdf "$jobname" "$destination_dir"
}

build_variant presentation_10pt_43_light 10pt 43 light "$STAGING_DIR"
build_variant presentation_10pt_1610_light 10pt 1610 light "$STAGING_DIR"
build_variant presentation_10pt_169_light 10pt 169 light "$STAGING_DIR"
build_variant presentation_11pt_43_light 11pt 43 light "$STAGING_DIR"
build_variant presentation_11pt_1610_light 11pt 1610 light "$STAGING_DIR"
build_variant presentation_11pt_169_light 11pt 169 light "$STAGING_DIR"
build_variant presentation_12pt_43_light 12pt 43 light "$STAGING_DIR"
build_variant presentation_12pt_1610_light 12pt 1610 light "$STAGING_DIR"
build_variant presentation_12pt_169_light 12pt 169 light "$STAGING_DIR"
build_variant presentation_12pt_43_dark 12pt 43 dark "$STAGING_DIR"
build_variant presentation_12pt_1610_dark 12pt 1610 dark "$STAGING_DIR"
build_variant presentation_12pt_169_dark 12pt 169 dark "$STAGING_DIR"

rm -rf "$TEST_OUTPUT_DIR"
mv "$STAGING_DIR" "$TEST_OUTPUT_DIR"
STAGING_DIR=

printf 'Built all presentation test variants.\n'
