#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/template-checks-checks.XXXXXX")
FAKE_BIN="$TEST_ROOT/bin"

if ! REAL_RG=$(command -v rg); then
  printf 'ERROR: rg is required by tests/template_checks_checks.sh.\n' >&2
  exit 1
fi

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/rg" <<'FAKE_RG'
#!/usr/bin/env bash
set -euo pipefail

for argument in "$@"; do
  if [ "$argument" = "${FAKE_RG_ERROR_PATTERN:-}" ]; then
    exit 2
  fi
done

exec "$REAL_RG" "$@"
FAKE_RG
chmod +x "$FAKE_BIN/rg"

export REAL_RG
export PATH="$FAKE_BIN:$PATH"

check_order_search_error() {
  local pattern="$1"
  local position="$2"
  local log="$TEST_ROOT/$position.log"
  local expected="FAIL: unable to inspect RELEASING.md for: release procedure should verify the annotated tag after creating it ($position command)"

  if FAKE_RG_ERROR_PATTERN="$pattern" bash "$ROOT_DIR/tests/template_checks.sh" > "$log" 2>&1; then
    printf 'FAIL: an injected ripgrep error should fail template_checks.sh\n' >&2
    exit 1
  fi
  if ! "$REAL_RG" --fixed-strings --quiet -- "$expected" "$log"; then
    printf 'FAIL: check_before should distinguish a %s-command search error from a missing command\n' "$position" >&2
    exit 1
  fi
  if "$REAL_RG" --fixed-strings --quiet -- "(missing $position command)" "$log"; then
    printf 'FAIL: a ripgrep error should not be reported as a missing %s command\n' "$position" >&2
    exit 1
  fi
}

check_order_search_error 'git tag -a "$version" -m "$version"' first
check_order_search_error 'git cat-file -e "$version^{tag}"' second

printf 'template_checks.sh checks passed.\n'
