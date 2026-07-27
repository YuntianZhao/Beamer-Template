#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR="$ROOT_DIR/.build-presentation-variants"
TEST_OUTPUT_DIR="$ROOT_DIR/output/test"

cd "$ROOT_DIR"

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

mkdir -p "$BUILD_DIR" "$TEST_OUTPUT_DIR"

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
    if ! command -v biber >/dev/null 2>&1; then
      printf 'ERROR: latexmk not found and biber is required for bibliography builds.\n' >&2
      exit 1
    fi

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

build_variant presentation_10pt_43_light 10pt 43 light "$TEST_OUTPUT_DIR"
build_variant presentation_10pt_1610_light 10pt 1610 light "$TEST_OUTPUT_DIR"
build_variant presentation_10pt_169_light 10pt 169 light "$TEST_OUTPUT_DIR"
build_variant presentation_11pt_43_light 11pt 43 light "$TEST_OUTPUT_DIR"
build_variant presentation_11pt_1610_light 11pt 1610 light "$TEST_OUTPUT_DIR"
build_variant presentation_11pt_169_light 11pt 169 light "$TEST_OUTPUT_DIR"
build_variant presentation_12pt_43_light 12pt 43 light "$TEST_OUTPUT_DIR"
build_variant presentation_12pt_1610_light 12pt 1610 light "$TEST_OUTPUT_DIR"
build_variant presentation_12pt_169_light 12pt 169 light "$TEST_OUTPUT_DIR"
build_variant presentation_12pt_43_dark 12pt 43 dark "$TEST_OUTPUT_DIR"
build_variant presentation_12pt_1610_dark 12pt 1610 dark "$TEST_OUTPUT_DIR"
build_variant presentation_12pt_169_dark 12pt 169 dark "$TEST_OUTPUT_DIR"

printf 'Built all presentation test variants.\n'
