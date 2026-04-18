# cds

Create a date-stamped scratch directory, initialize it as a git repo, and launch `oc`.

## What changed

`cds` no longer aims for exact alias parity with the old:

```bash
alias cds='mkdir -p ~/scratch/$(date +%Y-%m-%d) && cd ~/scratch/$(date +%Y-%m-%d) && oc'
```

It intentionally adds repo bootstrap behavior:

- every daily folder becomes its own git repo
- revisiting an older dated folder without `.git` upgrades it into a repo
- each initialized daily repo gets seeded `.gitignore` and `AGENTS.md`
- existing seeded files are never overwritten silently

The launch flow is still preserved: create/resolve dir → `cd` into it → `exec oc`.

## Install

```bash
./install.sh
```

This idempotently symlinks `~/.local/bin/cds` → this repo's `cds`.

## Usage

```bash
cds                              # create/upgrade ~/scratch/YYYY-MM-DD, git init if needed, seed files, cd, exec oc
cds 2026-01-15                   # same for an explicit date
cds --no-launch                  # create/upgrade + seed + cd, but skip oc
cds 2026-01-15 --no-launch       # explicit date, skip oc
cds --help                       # show help
cds -h                           # short form
```

Flags and the date arg may appear in any order. Date format is strict `YYYY-MM-DD`.

## Behavior Matrix

| Invocation | Creates dir? | Initializes git? | Seeds files? | `cd`s? | Launches `oc`? |
|------------|--------------|------------------|--------------|--------|----------------|
| `cds` | yes if missing | yes if needed | yes if missing | yes | yes |
| `cds 2026-01-15` | yes if missing | yes if needed | yes if missing | yes | yes |
| `cds --no-launch` | yes if missing | yes if needed | yes if missing | yes | no |
| revisit old non-repo day | no | yes | yes if missing | yes | yes/no based on flag |
| revisit existing daily repo | no | no-op | no-overwrite | yes | yes/no based on flag |
| `cds banana` | no | no | no | no | no |

If `git` is unavailable or `git init` fails, `cds` exits non-zero before launch. If `oc` is missing, the shell's normal `command not found` message is shown.

## Seeded Files

On first repo initialization, `cds` seeds from canonical templates in `templates/`:

- `templates/.gitignore`
- `templates/AGENTS.md`

These are copied into the daily repo only when the target files are missing.

### No-overwrite rule

If a daily repo already has its own `.gitignore` or `AGENTS.md`, `cds` leaves them untouched.

## Parent `~/scratch` Coexistence

The parent `~/scratch` repo should ignore top-level date-named daily dirs. This avoids noisy parent `git status` output and prevents accidental staging of embedded repos as gitlinks.

## Tests

```bash
bash tests/cds_test.sh      # repo bootstrap contract
bash tests/parity_test.sh   # launch-flow preservation
```

`cds_test.sh` covers:

- fresh repo creation
- explicit date repo init
- revisit upgrade for old non-repo days
- same-day rerun no-op behavior
- seeded `.gitignore` + `AGENTS.md`
- no-overwrite behavior for existing files
- `git` failure aborts before launch
- `--no-launch` and normal `oc` invocation behavior

`parity_test.sh` no longer asserts old alias parity. It now verifies that the create/`cd`/failure-path launch flow remains preserved after adding repo bootstrap.

If `shellcheck` is installed, `cds_test.sh` also lints `cds` and `install.sh`.

## Relationship with open-chad

The open-chad project still ships its own `bin/cds` fork. This repo is the canonical source of `~/.local/bin/cds` after `./install.sh` is run here.

## Why a script and not a function or alias?

- real scripts on PATH work from non-interactive shells and tools
- repo bootstrap, template seeding, and input validation are awkward in alias form
- a single canonical repo keeps `cds` behavior testable and versioned
