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
# Functional parity with the original alias:
#     mkdir -p ~/scratch/$(date +%Y-%m-%d) && cd ~/scratch/$(date +%Y-%m-%d) && oc
#
# Canonical project: https://github.com/JRedeker/cds
# Install with: ./install.sh

set -euo pipefail

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

# ─── Parity-critical hot path ─────────────────────────────────────────────────
# Original alias: mkdir -p ... && cd ... && oc
# Under `set -e`, identical short-circuit semantics.

mkdir -p "$SCRATCH_DIR"
cd "$SCRATCH_DIR"

if [[ -z "$NO_LAUNCH" ]]; then
    exec oc
fi
