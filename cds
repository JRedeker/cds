#!/bin/bash
# cds - Create Date-stamped Scratch directory and launch opencode
#
# Usage: cds [date]
#   cds        - Use today's date (YYYY-MM-DD)
#   cds 2026-01-15 - Use specific date

set -e

DATE="${1:-$(date +%Y-%m-%d)}"
SCRATCH_DIR="$HOME/scratch/$DATE"

mkdir -p "$SCRATCH_DIR"
cd "$SCRATCH_DIR"

echo "Launching opencode in $SCRATCH_DIR"
exec opencode
