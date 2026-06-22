---
name: er-setup
version: 1.0.0
description: >-
  IF a user has freshly cloned (or is refreshing) the ER workbench repo on macOS,
  Windows, or Linux/Ubuntu and needs Claude Code + VS Code to discover the bundled
  clinical-biostat-er skills, sync them to the global or project skills folder, check
  whether their working branch is current with the governed `main` bundle, recognize
  R/Rmd chunks, or verify Python/R/R-package readiness before running ER analysis,
  THEN invoke this setup skill. DO NOT invoke for running the analysis itself
  (that is the six core ER skills) or for editing clinical data.
---

# ER Setup

Make a first-time (or refreshed) ER workbench checkout usable with Claude Code and
R/Rmd editing — on **macOS, Windows, or Linux/Ubuntu**. This skill:

1. Checks the checkout's branch freshness against the governed `main` bundle and, when
   stale, asks how to reconcile **before** anything else.
2. Installs the repo-shipped `clinical-biostat-er` bundle into Claude's skills folder.
3. Merges VS Code R/Rmd settings for the OS you are running on.
4. Reports missing runtime dependencies (Python / R / R packages) with OS-specific
   install hints — never hard-coding user-specific paths.

The repo copy under `clinical-biostat-er/` is the single source of truth; the
installed copy under `~/.claude/skills/clinical-biostat-er/` is the per-machine
synced copy. Historical workbenches that keep the bundle under
`bundles/clinical-biostat-er/` remain supported by the setup script.

## Executing setup (priority ladder)

Run from the repository root. Pick the first rung that fits your OS:

1. **Windows (PowerShell):**
   ```powershell
   .\clinical-biostat-er\skills\er-setup\scripts\setup-er-repo.ps1 -Root .
   ```
2. **macOS / Linux (bash or zsh):**
   ```bash
   bash clinical-biostat-er/skills/er-setup/scripts/setup-er-repo.sh --root .
   ```
3. **Any OS (direct fallback):**
   ```bash
   python3 clinical-biostat-er/skills/er-setup/scripts/setup_er_repo.py --root .
   ```

The wrappers only locate Python and forward flags; all logic lives in
`setup_er_repo.py`. For per-OS install steps and gotchas, read the matching reference
doc in PART 3.

---

# PART 1 — MUST KNOW (read first)

## Branch-governance gate (runs FIRST)

Contributors work on their own branch (e.g. `internal-test-val-0N`); `main` holds the
**governed** bundle. The setup script runs a **read-only** comparison of *this
checkout's bundle skills* against `origin/main` (fetch → diff → classify) and prints one
of: `up-to-date`, `ahead-only`, `stale`, `diverged` (plus `+dirty` for uncommitted bundle
edits). It changes nothing in git.

When the report is **`stale`** or **`diverged`** (it prints `[ACTION-NEEDED]`), use
**AskUserQuestion** to ask how to reconcile, then run the chosen git command yourself:

- **Sync to main — keep local changes**: stash/commit local bundle edits, fast-forward or
  rebase `origin/main` into the branch, then restore. Non-destructive.
- **Sync to main — discard local bundle changes**: `git checkout origin/main -- clinical-biostat-er/`
  (or `git reset --hard origin/main` for the whole branch). **Destructive** — get a
  *second explicit confirmation* before running, and suggest a backup branch / `git stash`
  first.
- **Leave as-is**: proceed on the current branch; note the skills may be stale vs `main`.

For `up-to-date` / `ahead-only`, do **not** prompt — just report and continue. After any
sync, re-run the global-copy sync (PART 2) so the machine's `~/.claude` copy matches.

See `references/branch-governance.md` for the full model.

## Quick start

- Run the command for your OS (ladder above). Add `--dry-run` first in a shared checkout to
  preview every change without writing files.
- Confirm `clinical-biostat-er/SKILL.md` exists before setup (the script also supports legacy `bundles/clinical-biostat-er/SKILL.md` layouts).

## NEVER / ALWAYS

- **NEVER** run a destructive git reconcile (`git reset --hard`, discard) without an explicit
  user confirmation; offer a stash/backup-branch first.
- **NEVER** hard-code OneDrive, Windows-user, Python, or R install paths in setup code or docs.
- **NEVER** copy `.claude/settings.local.json` into the global Claude skills folder.
- **NEVER** edit clinical data or generated analysis outputs during setup.
- **ALWAYS** keep the repo `clinical-biostat-er/` copy (source of truth) and the installed
  `~/.claude/...` copy in sync — re-sync after any branch reconcile.
- **ALWAYS** keep the timestamped backup the script creates when replacing an existing
  installed bundle.

---

# PART 2 — HOW TO DO (during setup)

1. **Branch check** runs first (PART 1). Reconcile only when `stale`/`diverged`.
2. **Install the bundle** to Claude's skills folder. Default target is `global`
   (`~/.claude/skills/clinical-biostat-er`); `project` writes `.claude/skills/...`; `both`
   does each. An existing target is moved to `<name>.bak-<timestamp>` first — keep it.
3. **Merge VS Code settings** (`.vscode/settings.json` + `extensions.json`). The script
   auto-detects your OS (`--vscode-r-platform current`) and writes the matching
   `r.rpath.<os>` / `r.rterm.<os>` keys when R is on PATH; existing keys are preserved, not
   overwritten. See `references/vscode-rmd-settings.md`.
4. **Runtime report**: Python, Rscript, R, the 14-package `00_setup` base set, render
   tooling (rmarkdown/knitr, INFO), and on Linux a Cairo/ragg PNG-device check. Missing items
   print OS-specific install hints. Packages are **only** installed with
   `--install-missing-r-packages` (opt-in).
5. **Per-OS specifics**: route to the reference doc for the user's OS (PART 3) for exact
   install commands and gotchas.

## Options

- `--root .` — repository root.
- `--claude-target global|project|both` — where to install the bundle. Default `global`.
- `--vscode-r-platform current|windows|mac|linux` — which VS Code R keys to manage.
  Default `current` (auto-detect the running OS).
- `--no-branch-check` — skip the git branch-governance comparison.
- `--no-configure-vscode` — skip the VS Code settings merge.
- `--no-check-runtimes` — skip Python/R/R-package checks.
- `--install-missing-r-packages` — install missing CRAN packages. Use only when the user
  explicitly asks.
- `--dry-run` — print planned changes without writing files (branch check still runs; it is
  read-only).

PowerShell switch equivalents: `-Root`, `-ClaudeTarget`, `-VscodeRPlatform`, `-NoBranchCheck`,
`-NoConfigureVscode`, `-NoCheckRuntimes`, `-InstallMissingRPackages`, `-DryRun`.

---

# PART 3 — REFERENCES & RESOURCES

## Per-OS setup

- macOS → `references/setup-macos.md`
- Windows → `references/setup-windows.md`
- Linux / Ubuntu → `references/setup-linux.md`

## Cross-cutting

- Branch governance model → `references/branch-governance.md`
- VS Code R/Rmd settings the script merges → `references/vscode-rmd-settings.md`

## Troubleshooting

- **`stale` / `diverged` branch** → reconcile per PART 1; if a fast-forward fails, you have
  uncommitted bundle edits (`+dirty`) — stash/commit first.
- **`[WARN] Could not fetch origin main`** → offline or auth-gated; the comparison fell back
  to a local ref and may be behind. Run `git fetch origin main` and re-run.
- **`Rscript not found` / `R executable not found`** → install R for your OS (see the per-OS
  doc); ensure it is on PATH.
- **Missing R packages on Linux** → CRAN compiles from source; install the system libs listed
  in `references/setup-linux.md` before `--install-missing-r-packages`.
- **Blank PNGs on Linux** → R lacks a Cairo-capable device; install `ragg` or a Cairo-enabled
  R build (see `references/setup-linux.md`).
- **R keys not written** → you ran setup on a different OS than `--vscode-r-platform` targets;
  run on that OS or set the keys manually.

## Setup report / provenance

Setup prints an `[OK]/[WARN]/[INFO]/[ACTION-NEEDED]` report. When recording a study run's
provenance, capture: the **branch + freshness classification**, the **OS/wrapper** used, and
the **backup path** created when replacing an installed bundle.
