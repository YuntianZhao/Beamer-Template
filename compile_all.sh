#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCK_DIR="$ROOT_DIR/.build-presentation-variants.lock"
LOCK_OWNER_FILE="$LOCK_DIR/owner"
TEST_OUTPUT_DIR="$ROOT_DIR/output/test"
BUILD_DIR=
STAGING_DIR=
BACKUP_DIR=
LOCK_OWNED=
PUBLICATION_COMPLETE=

cd "$ROOT_DIR"

cleanup() {
  local lock_owner=

  if [ -n "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR" || true
  fi
  if [ -n "$BACKUP_DIR" ] && [ -e "$BACKUP_DIR/test" ] && [ -z "$PUBLICATION_COMPLETE" ]; then
    if [ -e "$TEST_OUTPUT_DIR" ] || [ -L "$TEST_OUTPUT_DIR" ]; then
      rm -rf "$TEST_OUTPUT_DIR" || true
    fi
    if [ ! -e "$TEST_OUTPUT_DIR" ] && [ ! -L "$TEST_OUTPUT_DIR" ]; then
      mv "$BACKUP_DIR/test" "$TEST_OUTPUT_DIR" || true
    fi
  fi
  if [ -n "$STAGING_DIR" ]; then
    rm -rf "$STAGING_DIR" || true
  fi
  if [ -n "$BACKUP_DIR" ]; then
    if [ -n "$PUBLICATION_COMPLETE" ] || [ ! -e "$BACKUP_DIR/test" ]; then
      rm -rf "$BACKUP_DIR" || true
    fi
  fi
  if [ -n "$LOCK_OWNED" ]; then
    if [ -f "$LOCK_OWNER_FILE" ]; then
      IFS= read -r lock_owner < "$LOCK_OWNER_FILE" || true
    fi
    if [ "$lock_owner" = "$$" ]; then
      rm -f "$LOCK_OWNER_FILE" || true
    fi
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [ ! -d "$LOCK_DIR" ]; then
    if [ -e "$LOCK_DIR" ] || [ -L "$LOCK_DIR" ]; then
      printf 'ERROR: compile_all.sh lock path exists and is not a directory: %s.\n' "$LOCK_DIR" >&2
    else
      printf 'ERROR: unable to create compile_all.sh lock at %s.\n' "$LOCK_DIR" >&2
    fi
    exit 1
  fi
  existing_lock_owner=
  if [ -f "$LOCK_OWNER_FILE" ]; then
    IFS= read -r existing_lock_owner < "$LOCK_OWNER_FILE" || true
  fi
  case "$existing_lock_owner" in
    ''|*[!0-9]*)
      printf 'ERROR: malformed compile_all.sh lock at %s; remove it after confirming no build is active.\n' \
        "$LOCK_DIR" >&2
      ;;
    *)
      if kill -0 "$existing_lock_owner" 2>/dev/null; then
        printf 'ERROR: another compile_all.sh run is active.\n' >&2
      else
        printf 'ERROR: stale compile_all.sh lock at %s (owner PID %s is not running); remove it and rerun.\n' \
          "$LOCK_DIR" "$existing_lock_owner" >&2
      fi
      ;;
  esac
  exit 1
fi
LOCK_OWNED=1
if ! printf '%s\n' "$$" > "$LOCK_OWNER_FILE"; then
  printf 'ERROR: unable to record compile_all.sh lock ownership.\n' >&2
  rm -f "$LOCK_OWNER_FILE" || true
  exit 1
fi

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

BACKUP_DIR=$(mktemp -d "$ROOT_DIR/output/.test.previous.XXXXXX")
if [ -e "$TEST_OUTPUT_DIR" ]; then
  if ! mv "$TEST_OUTPUT_DIR" "$BACKUP_DIR/test"; then
    printf 'ERROR: unable to preserve the previous presentation test matrix.\n' >&2
    exit 1
  fi
fi

if mv "$STAGING_DIR" "$TEST_OUTPUT_DIR"; then
  STAGING_DIR=
  PUBLICATION_COMPLETE=1
  rm -rf "$BACKUP_DIR"
  BACKUP_DIR=
else
  printf 'ERROR: unable to publish the presentation test matrix.\n' >&2
  if [ -e "$TEST_OUTPUT_DIR" ] && ! rm -rf "$TEST_OUTPUT_DIR"; then
    printf 'ERROR: previous output is preserved at %s/test.\n' "$BACKUP_DIR" >&2
    BACKUP_DIR=
    exit 1
  fi
  if [ -e "$BACKUP_DIR/test" ] && ! mv "$BACKUP_DIR/test" "$TEST_OUTPUT_DIR"; then
    printf 'ERROR: previous output is preserved at %s/test.\n' "$BACKUP_DIR" >&2
    BACKUP_DIR=
    exit 1
  fi
  exit 1
fi

printf 'Built all presentation test variants.\n'
