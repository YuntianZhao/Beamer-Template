#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/compile-all-checks.XXXXXX")
TEST_REPO="$TEST_ROOT/repo"
FAKE_BIN="$TEST_ROOT/bin"

if ! command -v rg >/dev/null 2>&1; then
  printf 'ERROR: rg is required by tests/compile_all_checks.sh.\n' >&2
  exit 1
fi

cleanup() {
  if [ -n "${FIRST_PID:-}" ]; then
    kill "$FIRST_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_REPO/output/test" "$FAKE_BIN"
cp "$ROOT_DIR/compile_all.sh" "$TEST_REPO/compile_all.sh"
chmod +x "$TEST_REPO/compile_all.sh"

cat > "$FAKE_BIN/latexmk" <<'FAKE_LATEXMK'
#!/usr/bin/env bash
set -euo pipefail

jobname=
outdir=
for argument in "$@"; do
  case "$argument" in
    -jobname=*) jobname=${argument#-jobname=} ;;
    -outdir=*) outdir=${argument#-outdir=} ;;
  esac
done

if [ -z "$jobname" ] || [ -z "$outdir" ]; then
  printf 'fake latexmk did not receive jobname and outdir\n' >&2
  exit 2
fi

count=0
if [ -f "$FAKE_COUNT_FILE" ]; then
  count=$(<"$FAKE_COUNT_FILE")
fi
count=$((count + 1))
printf '%s\n' "$count" > "$FAKE_COUNT_FILE"

if [ -n "${FAKE_FAIL_AT:-}" ] && [ "$count" -eq "$FAKE_FAIL_AT" ]; then
  exit 42
fi

mkdir -p "$outdir"
printf 'fake pdf for %s\n' "$jobname" > "$outdir/$jobname.pdf"
if [ -n "${FAKE_WARNING_AT:-}" ] && [ "$count" -eq "$FAKE_WARNING_AT" ]; then
  printf 'Missing character: There is no x in font fake!\n' > "$outdir/$jobname.log"
else
  : > "$outdir/$jobname.log"
fi
sleep "${FAKE_SLEEP:-0}"
FAKE_LATEXMK
chmod +x "$FAKE_BIN/latexmk"

export PATH="$FAKE_BIN:$PATH"
export FAKE_COUNT_FILE="$TEST_ROOT/count"

printf 'previous complete output\n' > "$TEST_REPO/output/test/sentinel.pdf"
export FAKE_FAIL_AT=2
if "$TEST_REPO/compile_all.sh"; then
  printf 'FAIL: an injected variant failure should fail compile_all.sh\n' >&2
  exit 1
fi
unset FAKE_FAIL_AT

if [ ! -f "$TEST_REPO/output/test/sentinel.pdf" ]; then
  printf 'FAIL: a failed run should preserve the previous output directory\n' >&2
  exit 1
fi
if compgen -G "$TEST_REPO/output/test/presentation_*.pdf" >/dev/null; then
  printf 'FAIL: a failed run should not publish a partial matrix\n' >&2
  exit 1
fi

rm -f "$FAKE_COUNT_FILE"
export FAKE_WARNING_AT=2
if "$TEST_REPO/compile_all.sh"; then
  printf 'FAIL: a warning-bearing final log should fail compile_all.sh\n' >&2
  exit 1
fi
unset FAKE_WARNING_AT

if [ ! -f "$TEST_REPO/output/test/sentinel.pdf" ]; then
  printf 'FAIL: a warning-bearing run should preserve the previous output directory\n' >&2
  exit 1
fi
if compgen -G "$TEST_REPO/output/test/presentation_*.pdf" >/dev/null; then
  printf 'FAIL: a warning-bearing run should not publish a partial matrix\n' >&2
  exit 1
fi

rm -f "$FAKE_COUNT_FILE"
"$TEST_REPO/compile_all.sh"
set -- "$TEST_REPO"/output/test/presentation_*.pdf
if [ "$#" -ne 12 ]; then
  printf 'FAIL: successful run published %s PDFs instead of 12\n' "$#" >&2
  exit 1
fi
if [ -e "$TEST_REPO/output/test/sentinel.pdf" ]; then
  printf 'FAIL: successful publication should replace stale output\n' >&2
  exit 1
fi

rm -f "$FAKE_COUNT_FILE"
export FAKE_SLEEP=0.2
"$TEST_REPO/compile_all.sh" > "$TEST_ROOT/first.log" 2>&1 &
FIRST_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -d "$TEST_REPO/.build-presentation-variants.lock" ] && break
  sleep 0.05
done
if [ ! -d "$TEST_REPO/.build-presentation-variants.lock" ]; then
  printf 'FAIL: compile_all.sh should create a single-run lock\n' >&2
  exit 1
fi
if "$TEST_REPO/compile_all.sh" > "$TEST_ROOT/second.log" 2>&1; then
  printf 'FAIL: a concurrent compile_all.sh invocation should fail\n' >&2
  exit 1
fi
if ! rg --fixed-strings --quiet 'another compile_all.sh run is active' "$TEST_ROOT/second.log"; then
  printf 'FAIL: concurrent-run failure should be actionable\n' >&2
  exit 1
fi
wait "$FIRST_PID"
FIRST_PID=

printf 'compile_all.sh checks passed.\n'
