#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR="$ROOT_DIR/.build-presentation-variants"

cd "$ROOT_DIR"

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

mkdir -p "$BUILD_DIR"

write_wrapper() {
  local jobname="$1"
  local aspectratio="$2"
  local mode="$3"

  cat > "$BUILD_DIR/$jobname.tex" <<EOF
\\newcommand{\\presentationaspectratio}{$aspectratio}
\\newcommand{\\presentationmode}{$mode}
\\input{presentation.tex}
EOF
}

compile_pdf() {
  local jobname="$1"

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
    lualatex \
      -interaction=nonstopmode \
      -halt-on-error \
      -file-line-error \
      -jobname="$jobname" \
      -output-directory="$BUILD_DIR" \
      "$BUILD_DIR/$jobname.tex"
  fi

  cp "$BUILD_DIR/$jobname.pdf" "$ROOT_DIR/$jobname.pdf"
}

build_variant() {
  local jobname="$1"
  local aspectratio="$2"
  local mode="$3"

  write_wrapper "$jobname" "$aspectratio" "$mode"
  compile_pdf "$jobname"
}

build_variant presentation_light 43 light
build_variant presentation_dark 43 dark
build_variant presentation_wide 169 light
build_variant presentation_wide_dark 169 dark

printf 'Built all presentation variants.\n'
