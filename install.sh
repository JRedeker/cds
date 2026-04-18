#!/usr/bin/env bash
# install.sh — idempotently symlink ~/.local/bin/cds to this repo's cds
#
# Running this multiple times is safe. If an existing symlink points
# elsewhere (e.g. another cds installation), this script prints a
# replacement notice and overwrites it. Regular files and broken symlinks
# are also handled.
#
# No sudo required — writes only to ~/.local/bin.
#
# Usage: ./install.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$REPO_DIR/cds"
TARGET="$HOME/.local/bin/cds"

if [[ ! -f "$SOURCE" ]]; then
    echo "ERROR: source script not found: $SOURCE" >&2
    exit 1
fi

mkdir -p "$(dirname "$TARGET")"

# Idempotent: handle existing file/symlink
if [[ -L "$TARGET" || -e "$TARGET" ]]; then
    if [[ "$(readlink -f "$TARGET" 2>/dev/null)" == "$SOURCE" ]]; then
        echo "Already installed: $TARGET → $SOURCE"
        exit 0
    fi
    existing_target=$(readlink "$TARGET" 2>/dev/null || echo "regular file")
    echo "Replacing existing $TARGET (was: $existing_target)"
    rm -f "$TARGET"
fi

ln -s "$SOURCE" "$TARGET"
echo "Installed: $TARGET → $SOURCE"
