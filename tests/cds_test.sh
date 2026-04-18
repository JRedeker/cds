#!/usr/bin/env bash
# tests/cds_test.sh — AC coverage for bin/cds
#
# Covers:
#   - --help / -h exits 0 and mentions date + --no-launch
#   - explicit date arg creates dated dir
#   - invalid date format rejected with non-zero exit
#   - --no-launch creates+enters dir without invoking oc
#   - idempotent on same-day rerun
#   - install.sh idempotent symlink management (inline tested here)
#   - optional shellcheck gate (skipped if shellcheck missing)
#
# Usage: bash tests/cds_test.sh
# Exit: number of failed assertions (0 = all pass)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CDS_BIN="$REPO_DIR/cds"
INSTALL_BIN="$REPO_DIR/install.sh"

# ─── Test Infrastructure ──────────────────────────────────────────────────────

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

pass() { echo "  PASS: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo "  FAIL: $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
skip() { echo "  SKIP: $1"; TESTS_SKIPPED=$((TESTS_SKIPPED + 1)); }

assert_eq()          { [ "$1" = "$2" ] && pass "$3" || fail "$3 (got '$1', expected '$2')"; }
assert_ne()          { [ "$1" != "$2" ] && pass "$3" || fail "$3 (both were '$1')"; }
assert_contains()    { echo "$1" | grep -q -- "$2" && pass "$3" || fail "$3 (pattern '$2' not found)"; }
assert_file_exists() { [ -f "$1" ] && pass "file exists: $1" || fail "file missing: $1"; }
assert_dir_exists()  { [ -d "$1" ] && pass "dir exists: $1" || fail "dir missing: $1"; }
assert_executable()  { [ -x "$1" ] && pass "executable: $1" || fail "not executable: $1"; }
assert_symlink()     { [ -L "$1" ] && pass "symlink: $1" || fail "not a symlink: $1"; }

section() { echo ""; echo "── $1 ──"; }

# ─── Helper: run cds with a temp HOME ─────────────────────────────────────────

run_cds() {
    local tmp_home="$1"
    shift
    HOME="$tmp_home" bash "$CDS_BIN" "$@"
}

# ─── Section 0: File properties ───────────────────────────────────────────────

section "bin/cds — file properties"

assert_file_exists "$CDS_BIN"
if [ -f "$CDS_BIN" ]; then
    assert_executable "$CDS_BIN"
    first_line=$(head -1 "$CDS_BIN")
    assert_contains "$first_line" "bash" "bin/cds has bash shebang"
    bash -n "$CDS_BIN" 2>/dev/null && pass "bin/cds syntax OK" || fail "bin/cds syntax error"
    grep -q 'set -euo pipefail' "$CDS_BIN" && pass "bin/cds uses set -euo pipefail" || fail "bin/cds missing set -euo pipefail"
fi

# ─── Section 1: --help / -h ───────────────────────────────────────────────────

section "bin/cds — --help / -h"

help_output=$(bash "$CDS_BIN" --help 2>&1); help_rc=$?
assert_eq "$help_rc" "0" "cds --help exits 0"
assert_contains "$help_output" "date" "cds --help mentions 'date'"
assert_contains "$help_output" "no-launch" "cds --help mentions '--no-launch'"

help_output_short=$(bash "$CDS_BIN" -h 2>&1); help_rc_short=$?
assert_eq "$help_rc_short" "0" "cds -h exits 0"

# ─── Section 2: Explicit date arg ─────────────────────────────────────────────

section "bin/cds — explicit date arg"

TMP=$(mktemp -d)
run_cds "$TMP" "2026-01-15" --no-launch >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "cds 2026-01-15 --no-launch exits 0"
assert_dir_exists "$TMP/scratch/2026-01-15"
rm -rf "$TMP"

# ─── Section 3: Invalid date format rejected ──────────────────────────────────

section "bin/cds — invalid date format"

TMP=$(mktemp -d)
err_output=$(run_cds "$TMP" "banana" --no-launch 2>&1); rc=$?
assert_ne "$rc" "0" "cds banana --no-launch exits non-zero"
assert_contains "$err_output" "ERROR" "error message printed to stderr"
[ ! -d "$TMP/scratch/banana" ] && pass "banana dir NOT created" || fail "banana dir was created (should not be)"
rm -rf "$TMP"

TMP=$(mktemp -d)
err_output=$(run_cds "$TMP" "2026/01/15" --no-launch 2>&1); rc=$?
assert_ne "$rc" "0" "cds 2026/01/15 (wrong separator) exits non-zero"
rm -rf "$TMP"

# ─── Section 4: --no-launch skips launcher ────────────────────────────────────

section "bin/cds — --no-launch skips launcher"

# Create a fake oc on PATH that records its invocation
TMP=$(mktemp -d)
FAKE_BIN="$TMP/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/oc" <<'EOF'
#!/usr/bin/env bash
echo "oc was invoked with args: $*" > "$TMP_SIGNAL"
EOF
chmod +x "$FAKE_BIN/oc"

SIGNAL="$TMP/oc_signal"
TMP_SIGNAL="$SIGNAL" PATH="$FAKE_BIN:$PATH" HOME="$TMP/home" bash "$CDS_BIN" --no-launch >/dev/null 2>&1
[ ! -f "$SIGNAL" ] && pass "--no-launch: oc was NOT invoked" || fail "--no-launch: oc WAS invoked (signal file exists)"

rm -rf "$TMP"

# ─── Section 5: --no-launch + explicit date ───────────────────────────────────

section "bin/cds — --no-launch with explicit date"

TMP=$(mktemp -d)
rc=0
run_cds "$TMP" --no-launch "2026-03-14" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "0" "cds --no-launch 2026-03-14 exits 0"
assert_dir_exists "$TMP/scratch/2026-03-14"
rm -rf "$TMP"

# ─── Section 6: Idempotence (same-day rerun) ──────────────────────────────────

section "bin/cds — idempotent on same-day rerun"

TMP=$(mktemp -d)
TODAY=$(date +%Y-%m-%d)
run_cds "$TMP" --no-launch >/dev/null 2>&1; rc1=$?
run_cds "$TMP" --no-launch >/dev/null 2>&1; rc2=$?
assert_eq "$rc1" "0" "first run exits 0"
assert_eq "$rc2" "0" "second run exits 0 (idempotent)"
assert_dir_exists "$TMP/scratch/$TODAY"
rm -rf "$TMP"

# ─── Section 7: Unknown flag rejected ─────────────────────────────────────────

section "bin/cds — unknown flags rejected"

TMP=$(mktemp -d)
err_output=$(run_cds "$TMP" --bogus-flag 2>&1); rc=$?
assert_ne "$rc" "0" "cds --bogus-flag exits non-zero"
rm -rf "$TMP"

# ─── Section 8: install.sh idempotency ────────────────────────────────────────

section "install.sh — idempotent symlink management"

assert_file_exists "$INSTALL_BIN"
if [ -f "$INSTALL_BIN" ]; then
    assert_executable "$INSTALL_BIN"
    bash -n "$INSTALL_BIN" 2>/dev/null && pass "install.sh syntax OK" || fail "install.sh syntax error"

    # Run twice against a temp HOME
    TMP=$(mktemp -d)
    HOME="$TMP" bash "$INSTALL_BIN" >/dev/null 2>&1; rc1=$?
    assert_eq "$rc1" "0" "install.sh first run exits 0"
    assert_symlink "$TMP/.local/bin/cds"
    if [ -L "$TMP/.local/bin/cds" ]; then
        target=$(readlink -f "$TMP/.local/bin/cds")
        assert_eq "$target" "$CDS_BIN" "symlink points at repo's cds"
    fi

    # Second run — should be no-op
    second_output=$(HOME="$TMP" bash "$INSTALL_BIN" 2>&1); rc2=$?
    assert_eq "$rc2" "0" "install.sh second run exits 0"
    assert_contains "$second_output" "Already installed" "second run prints 'Already installed'"

    # Existing symlink to a different target — should be replaced
    rm -f "$TMP/.local/bin/cds"
    mkdir -p "$TMP/elsewhere"
    echo '#!/bin/bash' > "$TMP/elsewhere/cds-other"
    chmod +x "$TMP/elsewhere/cds-other"
    ln -s "$TMP/elsewhere/cds-other" "$TMP/.local/bin/cds"
    replace_output=$(HOME="$TMP" bash "$INSTALL_BIN" 2>&1); rc3=$?
    assert_eq "$rc3" "0" "install.sh replaces different-target symlink, exits 0"
    assert_contains "$replace_output" "Replacing" "replacement prints notice"
    target=$(readlink -f "$TMP/.local/bin/cds")
    assert_eq "$target" "$CDS_BIN" "symlink now points at repo's cds after replacement"

    # Broken symlink — should be cleaned and recreated
    rm -f "$TMP/.local/bin/cds"
    ln -s "$TMP/nonexistent-target" "$TMP/.local/bin/cds"
    HOME="$TMP" bash "$INSTALL_BIN" >/dev/null 2>&1; rc4=$?
    assert_eq "$rc4" "0" "install.sh handles broken symlink, exits 0"
    if [ -L "$TMP/.local/bin/cds" ]; then
        target=$(readlink -f "$TMP/.local/bin/cds")
        assert_eq "$target" "$CDS_BIN" "symlink fixed after broken-link replacement"
    fi

    rm -rf "$TMP"
fi

# ─── Section 9: shellcheck (optional) ─────────────────────────────────────────

section "shellcheck (optional gate)"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$CDS_BIN" && pass "shellcheck: cds clean" || fail "shellcheck: cds has issues"
    [ -f "$INSTALL_BIN" ] && {
        shellcheck "$INSTALL_BIN" && pass "shellcheck: install.sh clean" || fail "shellcheck: install.sh has issues"
    }
else
    skip "shellcheck not installed"
fi

# ─── Results ──────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════"
echo "  Results: $TESTS_PASSED passed, $TESTS_FAILED failed, $TESTS_SKIPPED skipped"
echo "════════════════════════════════════"

exit "$TESTS_FAILED"
