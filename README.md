# cds

Create Date-stamped Scratch directory and launch opencode.

## Installation

```bash
# Add to PATH (e.g., in ~/.zshrc)
export PATH="$HOME/dev/smallsoft/cds:$PATH"

# Or symlink to a directory already in PATH
ln -s ~/dev/smallsoft/cds/cds ~/.local/bin/cds
```

## Usage

```bash
# Create ~/scratch/YYYY-MM-DD and launch opencode
cds

# Use a specific date
cds 2026-01-15
```

## What it does

1. Creates `~/scratch/<date>` directory (if it doesn't exist)
2. Changes to that directory
3. Launches opencode
