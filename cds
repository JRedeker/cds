#!/usr/bin/env bash
# cds — Create Date-stamped Scratch directory and launch oc
#
# Usage:
#   cds                      Create ~/scratch/YYYY-MM-DD (today) and launch oc
#   cds 2026-01-15           Create ~/scratch/2026-01-15 and launch oc
#   cds --no-launch          Create+enter today's scratch dir without launching oc
#   cds 2026-01-15 --no-launch   Combined: explicit date, skip launcher
#   cds --help | -h          Show this help
#
# Launch flow preserved from the original alias:
#     mkdir -p ~/scratch/$(date +%Y-%m-%d) && cd ~/scratch/$(date +%Y-%m-%d) && oc
# This command now also initializes the dated folder as a git repo and seeds
# .gitignore + AGENTS.md from templates/ the first time each daily repo is created.
#
# Canonical project: https://github.com/JRedeker/cds
# Install with: ./install.sh

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

print_usage() {
    cat <<'EOF'
Usage: cds [date] [--no-launch]
       cds --help | -h

  cds                     Create ~/scratch/YYYY-MM-DD (today), cd, launch oc
  cds 2026-01-15          Create ~/scratch/2026-01-15, cd, launch oc
  cds --no-launch         Create+enter today's scratch dir, skip launcher
  cds DATE --no-launch    Create+enter specific date, skip launcher

Flags and date arg may appear in any order. Date format: YYYY-MM-DD.
EOF
}

repo_exists() {
    local dir="$1"

    if [[ -e "$dir/.git" ]]; then
        return 0
    fi

    command -v git >/dev/null 2>&1 || return 1
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

seed_file_if_missing() {
    local template="$1"
    local dest="$2"

    if [[ -e "$dest" ]]; then
        return 0
    fi

    cp "$template" "$dest"
}

init_repo_if_needed() {
    local dir="$1"

    if repo_exists "$dir"; then
        return 0
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "ERROR: git not found on PATH" >&2
        exit 1
    fi

    git -C "$dir" init -q
}

seed_daily_repo_files_if_needed() {
    local dir="$1"

    if [[ ! -f "$TEMPLATE_DIR/.gitignore" || ! -f "$TEMPLATE_DIR/AGENTS.md" ]]; then
        echo "ERROR: cds templates missing in $TEMPLATE_DIR" >&2
        exit 1
    fi

    seed_file_if_missing "$TEMPLATE_DIR/.gitignore" "$dir/.gitignore"
    seed_file_if_missing "$TEMPLATE_DIR/AGENTS.md" "$dir/AGENTS.md"
}

# ─── Parse arguments ──────────────────────────────────────────────────────────

NO_LAUNCH=
DATE=

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            print_usage
            exit 0
            ;;
        --no-launch)
            NO_LAUNCH=1
            shift
            ;;
        -*)
            echo "ERROR: unknown flag: $1" >&2
            echo "Run 'cds --help' for usage." >&2
            exit 2
            ;;
        *)
            if [[ -n "$DATE" ]]; then
                echo "ERROR: multiple date arguments: '$DATE' and '$1'" >&2
                exit 2
            fi
            DATE="$1"
            shift
            ;;
    esac
done

# ─── Validate explicit date format ────────────────────────────────────────────

if [[ -n "$DATE" && ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: invalid date format: $DATE (expected YYYY-MM-DD)" >&2
    exit 2
fi

# ─── Resolve target dir ───────────────────────────────────────────────────────

DATE="${DATE:-$(date +%Y-%m-%d)}"
SCRATCH_DIR="$HOME/scratch/$DATE"

# ─── Main flow ────────────────────────────────────────────────────────────────
# mkdir -p -> init repo if needed -> seed .gitignore/AGENTS.md if missing -> cd -> exec oc.
# Under `set -e`, any step failure aborts before later steps run.

mkdir -p "$SCRATCH_DIR"
init_repo_if_needed "$SCRATCH_DIR"
seed_daily_repo_files_if_needed "$SCRATCH_DIR"
cd "$SCRATCH_DIR"

if [[ -z "$NO_LAUNCH" ]]; then
    exec oc
fi
