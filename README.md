# cds

Create Date-stamped Scratch directory and launch `oc`.

The original alias was:

```bash
alias cds='mkdir -p ~/scratch/$(date +%Y-%m-%d) && cd ~/scratch/$(date +%Y-%m-%d) && oc'
```

This script is a drop-in replacement with full functional parity on the no-args path, plus a few additive ergonomics.

## Install

```bash
./install.sh
```

This idempotently symlinks `~/.local/bin/cds` → this repo's `cds`. Run as many times as you like; existing symlinks pointing elsewhere are replaced (with a notice).

No sudo required.

## Usage

```bash
cds                              # ~/scratch/YYYY-MM-DD (today), cd, exec oc
cds 2026-01-15                   # ~/scratch/2026-01-15, cd, exec oc
cds --no-launch                  # create + cd today, skip oc
cds 2026-01-15 --no-launch       # create + cd specific date, skip oc
cds --help                       # show help
cds -h                           # short form
```

Flags and the date arg may appear in any order. Date format: `YYYY-MM-DD` (strict).

## Behavior Matrix

| Invocation | Creates dir? | `cd`s? | Launches `oc`? | Exit |
|------------|--------------|--------|----------------|------|
| `cds` | yes (today) | yes | yes (`exec oc`) | matches `oc` exit |
| `cds 2026-01-15` | yes (specific) | yes | yes | matches `oc` exit |
| `cds --no-launch` | yes | yes | no | 0 on success |
| `cds banana` | no | no | no | 2 (validation error) |
| `cds --bogus` | no | no | no | 2 (unknown flag) |
| `cds --help` | no | no | no | 0 |

If `oc` is not on PATH, the shell's standard "command not found" message is shown — same behavior as the original alias.

## Tests

```bash
bash tests/parity_test.sh   # alias-vs-cds regression (parity-critical)
bash tests/cds_test.sh      # full AC coverage (help, dates, install, etc.)
```

Both should exit 0. The parity test verifies that `cds --no-launch` produces identical exit code, dir state, and cwd as the original alias's `mkdir -p ... && cd ...` pipeline, on happy and failure paths.

If `shellcheck` is installed, `cds_test.sh` will also lint `cds` and `install.sh`.

## Relationship with open-chad

The [open-chad](https://github.com/anomalyco/open-chad) project also ships a `cds` script (its `bin/cds`, which launches `openchad` instead of `oc`). After installing this canonical version, `~/.local/bin/cds` will point here.

Note: if you ever re-run open-chad's `install.sh`, it may attempt to re-create the symlink. open-chad's installer prompts before overwriting; decline that prompt to keep this canonical version. The `oc` and `openchad` symlinks installed by open-chad are unaffected.

## Why a script and not a function or alias?

- Real scripts on PATH are reachable from non-interactive shells, scripts, and other tools — aliases and functions are not.
- Argument parsing, error handling, and date validation are awkward in alias form.
- A canonical `cds` lives in one place (this repo) and is installed via symlink — single source of truth.
