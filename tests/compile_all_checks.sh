#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/compile-all-checks.XXXXXX")
TEST_REPO="$TEST_ROOT/repo"
FAKE_BIN="$TEST_ROOT/bin"
FALLBACK_BIN="$TEST_ROOT/fallback-bin"

if ! command -v rg >/dev/null 2>&1; then
  printf 'ERROR: rg is required by tests/compile_all_checks.sh.\n' >&2
  exit 1
fi

cleanup() {
  if [ -n "${FIRST_PID:-}" ]; then
    kill "$FIRST_PID" >/dev/null 2>&1 || true
    wait "$FIRST_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_REPO/output/test" "$FAKE_BIN" "$FALLBACK_BIN"
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
if [ -n "${FAKE_MISSING_LOG_AT:-}" ] && [ "$count" -eq "$FAKE_MISSING_LOG_AT" ]; then
  :
elif [ -n "${FAKE_WARNING_AT:-}" ] && [ "$count" -eq "$FAKE_WARNING_AT" ]; then
  printf 'Missing character: There is no x in font fake!\n' > "$outdir/$jobname.log"
else
  : > "$outdir/$jobname.log"
fi
sleep "${FAKE_SLEEP:-0}"
FAKE_LATEXMK
chmod +x "$FAKE_BIN/latexmk"

export FAKE_REAL_GREP
FAKE_REAL_GREP=$(command -v grep)
cat > "$FAKE_BIN/grep" <<'FAKE_GREP'
#!/usr/bin/env bash
set -euo pipefail

if [ -n "${FAKE_GREP_ERROR:-}" ]; then
  exit 2
fi

exec "$FAKE_REAL_GREP" "$@"
FAKE_GREP
chmod +x "$FAKE_BIN/grep"

export FAKE_REAL_MV
FAKE_REAL_MV=$(command -v mv)
cat > "$FAKE_BIN/mv" <<'FAKE_MV'
#!/usr/bin/env bash
set -euo pipefail

if [ -n "${FAKE_FAIL_PUBLISH:-}" ]; then
  case "${1##*/}:${2:-}" in
    .test.*:*/output/test) exit 43 ;;
  esac
fi
if [ -n "${FAKE_INTERRUPT_PUBLISH:-}" ]; then
  case "${1##*/}:${2:-}" in
    .test.*:*/output/test)
      kill -TERM "$PPID"
      exit 143
      ;;
  esac
fi

exec "$FAKE_REAL_MV" "$@"
FAKE_MV
chmod +x "$FAKE_BIN/mv"

export FAKE_REAL_RM
FAKE_REAL_RM=$(command -v rm)
cat > "$FAKE_BIN/rm" <<'FAKE_RM'
#!/usr/bin/env bash
set -euo pipefail

if [ -n "${FAKE_FAIL_BUILD_CLEANUP:-}" ]; then
  for argument in "$@"; do
    case "${argument##*/}" in
      .build-presentation-variants.*) exit 44 ;;
    esac
  done
fi

exec "$FAKE_REAL_RM" "$@"
FAKE_RM
chmod +x "$FAKE_BIN/rm"

export PATH="$FAKE_BIN:$PATH"
export FAKE_COUNT_FILE="$TEST_ROOT/count"

for command_name in bash cat cp dirname grep mkdir mktemp mv rm rmdir; do
  ln -s "$(command -v "$command_name")" "$FALLBACK_BIN/$command_name"
done

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
export FAKE_MISSING_LOG_AT=2
if "$TEST_REPO/compile_all.sh" > "$TEST_ROOT/missing-log.log" 2>&1; then
  printf 'FAIL: a missing final log should fail compile_all.sh\n' >&2
  exit 1
fi
unset FAKE_MISSING_LOG_AT

if ! rg --fixed-strings --quiet 'presentation_10pt_1610_light.log was not produced' "$TEST_ROOT/missing-log.log"; then
  printf 'FAIL: a missing final log should have a specific diagnostic\n' >&2
  exit 1
fi
if [ ! -f "$TEST_REPO/output/test/sentinel.pdf" ]; then
  printf 'FAIL: a missing-log run should preserve the previous output directory\n' >&2
  exit 1
fi

rm -f "$FAKE_COUNT_FILE"
export FAKE_GREP_ERROR=1
if "$TEST_REPO/compile_all.sh" > "$TEST_ROOT/grep-error.log" 2>&1; then
  printf 'FAIL: a final-log search error should fail compile_all.sh\n' >&2
  exit 1
fi
unset FAKE_GREP_ERROR

if ! rg --fixed-strings --quiet 'unable to inspect presentation_10pt_43_light.log' "$TEST_ROOT/grep-error.log"; then
  printf 'FAIL: a final-log search error should have a specific diagnostic\n' >&2
  exit 1
fi
if [ ! -f "$TEST_REPO/output/test/sentinel.pdf" ]; then
  printf 'FAIL: a final-log search error should preserve the previous output directory\n' >&2
  exit 1
fi

if PATH="$FALLBACK_BIN" "$TEST_REPO/compile_all.sh" > "$TEST_ROOT/missing-lualatex.log" 2>&1; then
  printf 'FAIL: fallback mode should fail when lualatex is unavailable\n' >&2
  exit 1
fi
if ! rg --fixed-strings --quiet 'latexmk not found and lualatex is required for fallback builds' "$TEST_ROOT/missing-lualatex.log"; then
  printf 'FAIL: missing fallback lualatex should have a specific preflight diagnostic\n' >&2
  exit 1
fi

cat > "$FALLBACK_BIN/lualatex" <<'FAKE_LUALATEX'
#!/usr/bin/env bash
set -euo pipefail

printf 'lualatex invoked\n' >> "$FAKE_FALLBACK_INVOCATIONS"
exit 99
FAKE_LUALATEX
chmod +x "$FALLBACK_BIN/lualatex"
export FAKE_FALLBACK_INVOCATIONS="$TEST_ROOT/fallback-invocations"
if PATH="$FALLBACK_BIN" "$TEST_REPO/compile_all.sh" > "$TEST_ROOT/missing-biber.log" 2>&1; then
  printf 'FAIL: fallback mode should fail when biber is unavailable\n' >&2
  exit 1
fi
if ! rg --fixed-strings --quiet 'latexmk not found and biber is required for bibliography builds' "$TEST_ROOT/missing-biber.log"; then
  printf 'FAIL: missing fallback biber should have a specific preflight diagnostic\n' >&2
  exit 1
fi
if [ -e "$FAKE_FALLBACK_INVOCATIONS" ]; then
  printf 'FAIL: fallback commands should not run before all fallback dependencies pass preflight\n' >&2
  exit 1
fi

rm -f "$FAKE_COUNT_FILE"
export FAKE_FAIL_PUBLISH=1
if "$TEST_REPO/compile_all.sh"; then
  printf 'FAIL: an injected publication failure should fail compile_all.sh\n' >&2
  exit 1
fi
unset FAKE_FAIL_PUBLISH

if [ ! -f "$TEST_REPO/output/test/sentinel.pdf" ]; then
  printf 'FAIL: a publication failure should restore the previous output directory\n' >&2
  exit 1
fi
if compgen -G "$TEST_REPO/output/test/presentation_*.pdf" >/dev/null; then
  printf 'FAIL: a publication failure should not expose the staged matrix\n' >&2
  exit 1
fi

rm -f "$FAKE_COUNT_FILE"
export FAKE_INTERRUPT_PUBLISH=1
if "$TEST_REPO/compile_all.sh"; then
  printf 'FAIL: an interrupted publication should fail compile_all.sh\n' >&2
  exit 1
fi
unset FAKE_INTERRUPT_PUBLISH

if [ ! -f "$TEST_REPO/output/test/sentinel.pdf" ]; then
  printf 'FAIL: an interrupted publication should restore the previous output directory\n' >&2
  exit 1
fi
if compgen -G "$TEST_REPO/output/test/presentation_*.pdf" >/dev/null; then
  printf 'FAIL: an interrupted publication should not expose the staged matrix\n' >&2
  exit 1
fi

rm -f "$FAKE_COUNT_FILE"
export FAKE_FAIL_AT=2
export FAKE_FAIL_BUILD_CLEANUP=1
if "$TEST_REPO/compile_all.sh"; then
  printf 'FAIL: an injected build and cleanup failure should fail compile_all.sh\n' >&2
  exit 1
fi
unset FAKE_FAIL_AT
unset FAKE_FAIL_BUILD_CLEANUP

if [ -d "$TEST_REPO/.build-presentation-variants.lock" ]; then
  "$FAKE_REAL_RM" -rf \
    "$TEST_REPO/.build-presentation-variants.lock" \
    "$TEST_REPO"/.build-presentation-variants.* \
    "$TEST_REPO"/output/.test.*
  printf 'FAIL: cleanup failure should not prevent lock release\n' >&2
  exit 1
fi
"$FAKE_REAL_RM" -rf \
  "$TEST_REPO"/.build-presentation-variants.* \
  "$TEST_REPO"/output/.test.*

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
  [ -f "$TEST_REPO/.build-presentation-variants.lock/owner" ] && break
  sleep 0.05
done
if [ ! -f "$TEST_REPO/.build-presentation-variants.lock/owner" ]; then
  printf 'FAIL: compile_all.sh should record single-run lock ownership\n' >&2
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

mkdir "$TEST_REPO/.build-presentation-variants.lock"
printf '99999999\n' > "$TEST_REPO/.build-presentation-variants.lock/owner"
if "$TEST_REPO/compile_all.sh" > "$TEST_ROOT/stale-lock.log" 2>&1; then
  printf 'FAIL: a stale compile_all.sh lock should fail safely\n' >&2
  exit 1
fi
if ! rg --fixed-strings --quiet 'stale compile_all.sh lock' "$TEST_ROOT/stale-lock.log" ||
   ! rg --fixed-strings --quiet 'remove it and rerun' "$TEST_ROOT/stale-lock.log"; then
  printf 'FAIL: stale-lock failure should identify safe recovery\n' >&2
  exit 1
fi
if [ ! -d "$TEST_REPO/.build-presentation-variants.lock" ]; then
  printf 'FAIL: stale-lock diagnosis should not delete the existing lock\n' >&2
  exit 1
fi
"$FAKE_REAL_RM" -rf "$TEST_REPO/.build-presentation-variants.lock"

mkdir "$TEST_REPO/.build-presentation-variants.lock"
printf 'not-a-pid\n' > "$TEST_REPO/.build-presentation-variants.lock/owner"
if "$TEST_REPO/compile_all.sh" > "$TEST_ROOT/malformed-lock.log" 2>&1; then
  printf 'FAIL: a malformed compile_all.sh lock should fail safely\n' >&2
  exit 1
fi
if ! rg --fixed-strings --quiet 'malformed compile_all.sh lock' "$TEST_ROOT/malformed-lock.log" ||
   ! rg --fixed-strings --quiet 'after confirming no build is active' "$TEST_ROOT/malformed-lock.log"; then
  printf 'FAIL: malformed-lock failure should require safe manual recovery\n' >&2
  exit 1
fi
if [ ! -d "$TEST_REPO/.build-presentation-variants.lock" ]; then
  printf 'FAIL: malformed-lock diagnosis should not delete the existing lock\n' >&2
  exit 1
fi
"$FAKE_REAL_RM" -rf "$TEST_REPO/.build-presentation-variants.lock"

printf 'not a lock directory\n' > "$TEST_REPO/.build-presentation-variants.lock"
if "$TEST_REPO/compile_all.sh" > "$TEST_ROOT/invalid-lock-path.log" 2>&1; then
  printf 'FAIL: a non-directory lock path should fail safely\n' >&2
  exit 1
fi
if ! rg --fixed-strings --quiet 'lock path exists and is not a directory' "$TEST_ROOT/invalid-lock-path.log"; then
  printf 'FAIL: non-directory lock failure should identify the acquisition error\n' >&2
  exit 1
fi
if [ ! -f "$TEST_REPO/.build-presentation-variants.lock" ]; then
  printf 'FAIL: non-directory lock diagnosis should not delete the existing path\n' >&2
  exit 1
fi
"$FAKE_REAL_RM" -f "$TEST_REPO/.build-presentation-variants.lock"

REAP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/compile-all-reap-check.XXXXXX")
REAP_READY="$REAP_ROOT/ready"
REAP_DONE="$REAP_ROOT/done"
(
  trap 'sleep 0.5; : > "$REAP_DONE"; exit 0' TERM
  : > "$REAP_READY"
  while :; do :; done
) &
FIRST_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -f "$REAP_READY" ] && break
  sleep 0.05
done
if [ ! -f "$REAP_READY" ]; then
  printf 'FAIL: background cleanup probe did not start\n' >&2
  exit 1
fi
cleanup
trap - EXIT
if [ ! -f "$REAP_DONE" ]; then
  wait "$FIRST_PID" >/dev/null 2>&1 || true
  FIRST_PID=
  "$FAKE_REAL_RM" -rf "$REAP_ROOT"
  printf 'FAIL: cleanup should reap the terminated background fake build before returning\n' >&2
  exit 1
fi
FIRST_PID=
"$FAKE_REAL_RM" -rf "$REAP_ROOT"

printf 'compile_all.sh checks passed.\n'
