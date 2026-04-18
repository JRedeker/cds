#!/usr/bin/env bash
# tests/cds_test.sh — repo-bootstrap contract for cds

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CDS_BIN="$REPO_DIR/cds"
INSTALL_BIN="$REPO_DIR/install.sh"
GITIGNORE_TEMPLATE="$REPO_DIR/templates/.gitignore"
AGENTS_TEMPLATE="$REPO_DIR/templates/AGENTS.md"

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

pass() { echo "  PASS: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo "  FAIL: $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
skip() { echo "  SKIP: $1"; TESTS_SKIPPED=$((TESTS_SKIPPED + 1)); }

assert_eq() { [ "$1" = "$2" ] && pass "$3" || fail "$3 (got '$1', expected '$2')"; }
assert_ne() { [ "$1" != "$2" ] && pass "$3" || fail "$3 (both were '$1')"; }
assert_contains() { echo "$1" | grep -q -- "$2" && pass "$3" || fail "$3 (pattern '$2' not found)"; }
assert_file_exists() { [ -f "$1" ] && pass "file exists: $1" || fail "file missing: $1"; }
assert_dir_exists() { [ -d "$1" ] && pass "dir exists: $1" || fail "dir missing: $1"; }
assert_executable() { [ -x "$1" ] && pass "executable: $1" || fail "not executable: $1"; }
assert_symlink() { [ -L "$1" ] && pass "symlink: $1" || fail "not a symlink: $1"; }
assert_file_content_eq() { cmp -s "$1" "$2" && pass "$3" || fail "$3 (files differ: $1 vs $2)"; }
assert_file_content_unchanged() { [ "$(cat "$1")" = "$2" ] && pass "$3" || fail "$3 (content changed)"; }

section() { echo ""; echo "── $1 ──"; }

run_cds() {
    local tmp_home="$1"
    shift
    HOME="$tmp_home" bash "$CDS_BIN" "$@"
}

today() {
    date +%Y-%m-%d
}

section "bin/cds — file properties"
assert_file_exists "$CDS_BIN"
if [ -f "$CDS_BIN" ]; then
    assert_executable "$CDS_BIN"
    first_line=$(head -1 "$CDS_BIN")
    assert_contains "$first_line" "bash" "bin/cds has bash shebang"
    bash -n "$CDS_BIN" 2>/dev/null && pass "bin/cds syntax OK" || fail "bin/cds syntax error"
    grep -q 'set -euo pipefail' "$CDS_BIN" && pass "bin/cds uses set -euo pipefail" || fail "bin/cds missing set -euo pipefail"
fi

section "bin/cds — --help / -h"
help_output=$(bash "$CDS_BIN" --help 2>&1); help_rc=$?
assert_eq "$help_rc" "0" "cds --help exits 0"
assert_contains "$help_output" "date" "cds --help mentions 'date'"
assert_contains "$help_output" "no-launch" "cds --help mentions '--no-launch'"

help_output_short=$(bash "$CDS_BIN" -h 2>&1); help_rc_short=$?
assert_eq "$help_rc_short" "0" "cds -h exits 0"

section "fresh run — creates repo and seeds files"
TMP=$(mktemp -d)
TODAY=$(today)
run_cds "$TMP" --no-launch >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "fresh cds --no-launch exits 0"
assert_dir_exists "$TMP/scratch/$TODAY/.git"
assert_file_exists "$TMP/scratch/$TODAY/.gitignore"
assert_file_exists "$TMP/scratch/$TODAY/AGENTS.md"
assert_file_exists "$GITIGNORE_TEMPLATE"
assert_file_exists "$AGENTS_TEMPLATE"
if [ -f "$TMP/scratch/$TODAY/.gitignore" ] && [ -f "$GITIGNORE_TEMPLATE" ]; then
    assert_file_content_eq "$TMP/scratch/$TODAY/.gitignore" "$GITIGNORE_TEMPLATE" "seeded .gitignore matches template"
fi
if [ -f "$TMP/scratch/$TODAY/AGENTS.md" ] && [ -f "$AGENTS_TEMPLATE" ]; then
    assert_file_content_eq "$TMP/scratch/$TODAY/AGENTS.md" "$AGENTS_TEMPLATE" "seeded AGENTS.md matches template"
fi
rm -rf "$TMP"

section "explicit date — repo init still occurs"
TMP=$(mktemp -d)
run_cds "$TMP" "2026-01-15" --no-launch >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "cds 2026-01-15 --no-launch exits 0"
assert_dir_exists "$TMP/scratch/2026-01-15/.git"
assert_file_exists "$TMP/scratch/2026-01-15/.gitignore"
assert_file_exists "$TMP/scratch/2026-01-15/AGENTS.md"
rm -rf "$TMP"

section "revisit old non-repo folder upgrades it"
TMP=$(mktemp -d)
mkdir -p "$TMP/scratch/2026-03-14"
echo "hello" > "$TMP/scratch/2026-03-14/existing.txt"
run_cds "$TMP" 2026-03-14 --no-launch >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "revisit old folder exits 0"
assert_dir_exists "$TMP/scratch/2026-03-14/.git"
assert_file_exists "$TMP/scratch/2026-03-14/existing.txt"
assert_file_exists "$TMP/scratch/2026-03-14/.gitignore"
assert_file_exists "$TMP/scratch/2026-03-14/AGENTS.md"
rm -rf "$TMP"

section "same-day rerun is non-destructive"
TMP=$(mktemp -d)
TODAY=$(today)
run_cds "$TMP" --no-launch >/dev/null 2>&1; rc1=$?
run_cds "$TMP" --no-launch >/dev/null 2>&1; rc2=$?
assert_eq "$rc1" "0" "first run exits 0"
assert_eq "$rc2" "0" "second run exits 0"
assert_dir_exists "$TMP/scratch/$TODAY/.git"
rm -rf "$TMP"

section "existing seeded files are not overwritten"
TMP=$(mktemp -d)
TODAY=$(today)
mkdir -p "$TMP/scratch/$TODAY"
printf 'custom-ignore\n' > "$TMP/scratch/$TODAY/.gitignore"
printf 'custom-agents\n' > "$TMP/scratch/$TODAY/AGENTS.md"
run_cds "$TMP" --no-launch >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "run with custom files exits 0"
assert_dir_exists "$TMP/scratch/$TODAY/.git"
assert_file_content_unchanged "$TMP/scratch/$TODAY/.gitignore" "custom-ignore" ".gitignore preserved"
assert_file_content_unchanged "$TMP/scratch/$TODAY/AGENTS.md" "custom-agents" "AGENTS.md preserved"
rm -rf "$TMP"

section "invalid date format rejected"
TMP=$(mktemp -d)
err_output=$(run_cds "$TMP" banana --no-launch 2>&1); rc=$?
assert_ne "$rc" "0" "cds banana --no-launch exits non-zero"
assert_contains "$err_output" "ERROR" "error message printed"
[ ! -d "$TMP/scratch/banana" ] && pass "banana dir NOT created" || fail "banana dir was created"
rm -rf "$TMP"

section "--no-launch skips launcher"
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
[ ! -f "$SIGNAL" ] && pass "--no-launch: oc was NOT invoked" || fail "--no-launch: oc WAS invoked"
rm -rf "$TMP"

section "normal launch still invokes oc"
TMP=$(mktemp -d)
FAKE_BIN="$TMP/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/oc" <<'EOF'
#!/usr/bin/env bash
echo "$PWD|$*" > "$TMP_SIGNAL"
exit 0
EOF
chmod +x "$FAKE_BIN/oc"
SIGNAL="$TMP/oc_signal"
TODAY=$(today)
TMP_SIGNAL="$SIGNAL" PATH="$FAKE_BIN:$PATH" HOME="$TMP/home" bash "$CDS_BIN" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "normal cds run exits 0 when fake oc succeeds"
assert_file_exists "$SIGNAL"
if [ -f "$SIGNAL" ]; then
    assert_contains "$(cat "$SIGNAL")" "scratch/$TODAY|" "oc invoked from dated dir with no args"
fi
assert_dir_exists "$TMP/home/scratch/$TODAY/.git"
rm -rf "$TMP"

section "git missing or init failure aborts before launch"
TMP=$(mktemp -d)
FAKE_BIN="$TMP/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
echo "fake git failure" >&2
exit 9
EOF
cat > "$FAKE_BIN/oc" <<'EOF'
#!/usr/bin/env bash
echo "oc should not be called" > "$TMP_SIGNAL"
EOF
chmod +x "$FAKE_BIN/git" "$FAKE_BIN/oc"
SIGNAL="$TMP/oc_signal"
TODAY=$(today)
err_output=$(TMP_SIGNAL="$SIGNAL" PATH="$FAKE_BIN:$PATH" HOME="$TMP/home" bash "$CDS_BIN" --no-launch 2>&1); rc=$?
assert_ne "$rc" "0" "git failure causes non-zero exit"
[ ! -f "$SIGNAL" ] && pass "oc not called when git fails" || fail "oc called despite git failure"
[ ! -d "$TMP/home/scratch/$TODAY/.git" ] && pass "repo not created when git init fails" || fail "repo created despite git failure"
rm -rf "$TMP"

section "install.sh — idempotent symlink management"
assert_file_exists "$INSTALL_BIN"
if [ -f "$INSTALL_BIN" ]; then
    assert_executable "$INSTALL_BIN"
    bash -n "$INSTALL_BIN" 2>/dev/null && pass "install.sh syntax OK" || fail "install.sh syntax error"
fi

section "shellcheck (optional gate)"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$CDS_BIN" && pass "shellcheck: cds clean" || fail "shellcheck: cds has issues"
    [ -f "$INSTALL_BIN" ] && {
        shellcheck "$INSTALL_BIN" && pass "shellcheck: install.sh clean" || fail "shellcheck: install.sh has issues"
    }
else
    skip "shellcheck not installed"
fi

echo ""
echo "════════════════════════════════════"
echo "  Results: $TESTS_PASSED passed, $TESTS_FAILED failed, $TESTS_SKIPPED skipped"
echo "════════════════════════════════════"

exit "$TESTS_FAILED"
