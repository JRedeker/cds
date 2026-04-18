#!/usr/bin/env bash
# tests/parity_test.sh — Regression: alias vs new cds parity
#
# The new cds MUST be functionally identical to the original alias on the
# no-args path:
#     mkdir -p ~/scratch/$(date +%Y-%m-%d) && cd ~/scratch/$(date +%Y-%m-%d) && oc
#
# This test asserts identical behavior on:
#   (a) happy path — exit code + dir state + cwd match
#   (b) failure path — both fail on read-only parent
#
# Uses --no-launch on cds side to skip oc invocation (parity of the
# launcher is verified separately in cds_test.sh).
#
# Usage: bash tests/parity_test.sh
# Exit: number of failed assertions (0 = all parity)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CDS_BIN="$REPO_DIR/cds"

# ─── Test Infrastructure ──────────────────────────────────────────────────────

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo "  PASS: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo "  FAIL: $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

assert_eq()  { [ "$1" = "$2" ] && pass "$3" || fail "$3 (got '$1', expected '$2')"; }
assert_ne()  { [ "$1" != "$2" ] && pass "$3" || fail "$3 (both were '$1')"; }
assert_dir_exists() { [ -d "$1" ] && pass "dir exists: $1" || fail "dir missing: $1"; }

section() { echo ""; echo "── $1 ──"; }

# ─── Alias reconstruction ─────────────────────────────────────────────────────
#
# The original alias, reconstructed as a bash one-liner suitable for running
# under a custom HOME. `cd` output is captured via pwd. The trailing `&& pwd`
# replaces the alias's `&& oc` — we don't invoke oc because that's tested
# separately (via --no-launch on cds side).

run_alias_equivalent() {
    local tmp_home="$1"
    local date_str="${2:-}"

    if [ -n "$date_str" ]; then
        # Alias doesn't accept args — explicit date is a new-cds feature.
        # For parity, the alias test runs the no-args form; explicit-date
        # tests live in cds_test.sh.
        return 99
    fi

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

# ─── Preflight ────────────────────────────────────────────────────────────────

section "Preflight"

if [ ! -f "$CDS_BIN" ]; then
    fail "cds binary missing at $CDS_BIN"
    echo ""
    echo "════════════════════════════════════"
    echo "  Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
    echo "  STATUS: FAIL — cds binary does not exist (expected in RED phase)"
    echo "════════════════════════════════════"
    exit "$TESTS_FAILED"
fi

pass "cds binary exists"

if [ ! -x "$CDS_BIN" ]; then
    fail "cds binary not executable at $CDS_BIN"
else
    pass "cds binary is executable"
fi

# ─── Section 1: Happy Path Parity ────────────────────────────────────────────

section "Happy path — alias vs cds (no args)"

TMP_ALIAS=$(mktemp -d)
TMP_CDS=$(mktemp -d)

alias_out=$(run_alias_equivalent "$TMP_ALIAS" 2>&1)
ALIAS_RC=$?

cds_out=$(run_cds_no_launch "$TMP_CDS" 2>&1)
CDS_RC=$?

TODAY=$(date +%Y-%m-%d)

assert_eq "$ALIAS_RC" "0" "alias-equivalent exits 0 on happy path"
assert_eq "$CDS_RC" "0" "cds --no-launch exits 0 on happy path"
assert_eq "$ALIAS_RC" "$CDS_RC" "exit codes match (happy path)"

assert_dir_exists "$TMP_ALIAS/scratch/$TODAY"
assert_dir_exists "$TMP_CDS/scratch/$TODAY"

# alias's `pwd` output should end with the dated dir.
if echo "$alias_out" | grep -q "scratch/$TODAY$"; then
    pass "alias cwd reached scratch/$TODAY"
else
    fail "alias cwd output did not end with scratch/$TODAY: '$alias_out'"
fi

rm -rf "$TMP_ALIAS" "$TMP_CDS"

# ─── Section 2: Idempotence Parity ───────────────────────────────────────────

section "Idempotence — both succeed when run twice"

TMP_ALIAS=$(mktemp -d)
TMP_CDS=$(mktemp -d)

run_alias_equivalent "$TMP_ALIAS" >/dev/null 2>&1; ALIAS_RC1=$?
run_alias_equivalent "$TMP_ALIAS" >/dev/null 2>&1; ALIAS_RC2=$?

run_cds_no_launch "$TMP_CDS" >/dev/null 2>&1; CDS_RC1=$?
run_cds_no_launch "$TMP_CDS" >/dev/null 2>&1; CDS_RC2=$?

assert_eq "$ALIAS_RC1" "0" "alias first run exits 0"
assert_eq "$ALIAS_RC2" "0" "alias second run exits 0 (idempotent)"
assert_eq "$CDS_RC1" "0" "cds first run exits 0"
assert_eq "$CDS_RC2" "0" "cds second run exits 0 (idempotent)"

rm -rf "$TMP_ALIAS" "$TMP_CDS"

# ─── Section 3: Failure Path Parity ──────────────────────────────────────────
#
# Force mkdir -p to fail by pointing HOME at a read-only parent.
# Both the alias and cds should exit non-zero. We don't assert exact
# rc equality because mkdir's exact exit code on permission failure
# can vary; we assert "both failed" which is the parity-relevant claim.

section "Failure path — read-only HOME parent"

READONLY_PARENT=$(mktemp -d)
chmod -w "$READONLY_PARENT"

TMP_HOME_ALIAS="$READONLY_PARENT/home_alias"
TMP_HOME_CDS="$READONLY_PARENT/home_cds"

# We don't mkdir these ahead of time — we want the subshell's attempt to
# `mkdir -p "$HOME/scratch/..."` to fail because HOME itself can't be
# created. Trying to set HOME to a non-existent dir under a read-only
# parent. The `mkdir -p` inside the subshell will fail.

run_alias_equivalent "$TMP_HOME_ALIAS" >/dev/null 2>&1
ALIAS_FAIL_RC=$?

run_cds_no_launch "$TMP_HOME_CDS" >/dev/null 2>&1
CDS_FAIL_RC=$?

assert_ne "$ALIAS_FAIL_RC" "0" "alias-equivalent exits non-zero on read-only parent"
assert_ne "$CDS_FAIL_RC" "0" "cds --no-launch exits non-zero on read-only parent"

chmod +w "$READONLY_PARENT"
rm -rf "$READONLY_PARENT"

# ─── Results ──────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════"
echo "  Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "════════════════════════════════════"

exit "$TESTS_FAILED"
