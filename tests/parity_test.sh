#!/usr/bin/env bash
# tests/parity_test.sh — launch-flow preservation after repo bootstrap

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CDS_BIN="$REPO_DIR/cds"

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo "  PASS: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo "  FAIL: $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
assert_eq() { [ "$1" = "$2" ] && pass "$3" || fail "$3 (got '$1', expected '$2')"; }
assert_ne() { [ "$1" != "$2" ] && pass "$3" || fail "$3 (both were '$1')"; }
assert_dir_exists() { [ -d "$1" ] && pass "dir exists: $1" || fail "dir missing: $1"; }
section() { echo ""; echo "── $1 ──"; }

run_alias_equivalent() {
    local tmp_home="$1"
    HOME="$tmp_home" bash -c '
        set -e
        mkdir -p "$HOME/scratch/$(date +%Y-%m-%d)"
        cd "$HOME/scratch/$(date +%Y-%m-%d)"
        pwd
    '
}

run_cds_no_launch() {
    local tmp_home="$1"
    HOME="$tmp_home" bash "$CDS_BIN" --no-launch
}

section "Preflight"
[ -f "$CDS_BIN" ] && pass "cds binary exists" || { fail "cds binary missing"; exit 1; }
[ -x "$CDS_BIN" ] && pass "cds binary executable" || fail "cds binary not executable"

section "Launch-flow preservation — happy path"
TMP_ALIAS=$(mktemp -d)
TMP_CDS=$(mktemp -d)
TODAY=$(date +%Y-%m-%d)

alias_out=$(run_alias_equivalent "$TMP_ALIAS" 2>&1); alias_rc=$?
cds_out=$(run_cds_no_launch "$TMP_CDS" 2>&1); cds_rc=$?

assert_eq "$alias_rc" "0" "alias-equivalent exits 0"
assert_eq "$cds_rc" "0" "cds --no-launch exits 0"
assert_eq "$alias_rc" "$cds_rc" "exit codes match on happy path"
assert_dir_exists "$TMP_ALIAS/scratch/$TODAY"
assert_dir_exists "$TMP_CDS/scratch/$TODAY"
assert_dir_exists "$TMP_CDS/scratch/$TODAY/.git"

if echo "$alias_out" | grep -q "scratch/$TODAY$"; then
    pass "alias cwd reached scratch/$TODAY"
else
    fail "alias cwd output did not end with scratch/$TODAY: '$alias_out'"
fi

rm -rf "$TMP_ALIAS" "$TMP_CDS"

section "Launch-flow preservation — failure path"
READONLY_PARENT=$(mktemp -d)
chmod -w "$READONLY_PARENT"
TMP_HOME_ALIAS="$READONLY_PARENT/home_alias"
TMP_HOME_CDS="$READONLY_PARENT/home_cds"

run_alias_equivalent "$TMP_HOME_ALIAS" >/dev/null 2>&1
alias_fail_rc=$?
run_cds_no_launch "$TMP_HOME_CDS" >/dev/null 2>&1
cds_fail_rc=$?

assert_ne "$alias_fail_rc" "0" "alias-equivalent exits non-zero on read-only parent"
assert_ne "$cds_fail_rc" "0" "cds exits non-zero on read-only parent"

chmod +w "$READONLY_PARENT"
rm -rf "$READONLY_PARENT"

echo ""
echo "════════════════════════════════════"
echo "  Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "════════════════════════════════════"

exit "$TESTS_FAILED"
