# ER Setup — Linux / Ubuntu

## Quick Reference

- **You need:** a shell (bash/zsh), Python 3, R, system build libs (CRAN compiles from
  source), and optionally VS Code.
- **Run setup (from the repo root):**
  ```bash
  bash bundles/clinical-biostat-er/skills/er-setup/scripts/setup-er-repo.sh --root .
  ```
  Add `--dry-run` first to preview. VS Code keys auto-detect Linux
  (`--vscode-r-platform current`).

## Install steps

1. **Python 3** (Debian/Ubuntu):
   ```bash
   sudo apt-get install python3 python3-pip
   ```
2. **R** (Debian/Ubuntu):
   ```bash
   sudo apt-get install r-base r-base-dev
   ```
   For a current R, prefer the CRAN apt repo (https://cran.r-project.org/bin/linux/ubuntu/).
   Confirm `Rscript --version`.
3. **System libraries** — CRAN packages build from source on Linux, so install dev headers
   **before** installing R packages:
   ```bash
   sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev \
     libfontconfig1-dev libfreetype6-dev libcairo2-dev
   ```
4. **R packages** — the 14-package `00_setup` base set
   (`tidyverse, haven, binom, patchwork, ggh4x, survival, survminer, flextable, officer,
   table1, ggpubr, broom, yaml, jsonlite`). Let setup report them, then either:
   ```bash
   bash .../setup-er-repo.sh --root . --install-missing-r-packages
   # or in R:
   install.packages(c("tidyverse", ...), repos = "https://cloud.r-project.org")
   ```
   Also install **`ragg`** (or use a Cairo-enabled R) — see the gotcha below.
5. **VS Code + R support** — install VS Code and the `REditorSupport.r` extension (setup adds
   it to `.vscode/extensions.json`). Setup writes `r.rpath.linux` / `r.rterm.linux` when R is
   on PATH.

## Gotchas

- **Blank-PNG / Cairo (headline gotcha)** — ER plots use Unicode glyphs (★/◎/↑) that need a
  Unicode-capable PNG device. On a non-Cairo R build the default bitmap device raises a silent
  `mbcsToSbcs` error and writes a **blank PNG**. Setup checks `capabilities('cairo')` and whether
  `ragg` is installed and WARNs if neither is available. Fix: `install.packages('ragg')` (use
  `ragg::agg_png`) or install an R build with Cairo (`png(type = "cairo")`). This is a *runtime*
  plotting failure, not a setup failure — fix it before a study run produces empty figures.
- **CRAN compiles from source** — `--install-missing-r-packages` can fail on a fresh box until
  the system libs (step 3) are installed; the failure is a missing `-dev` header, not a broken
  script.
- **PATH / non-interactive shells** — ensure `Rscript` and `python3` resolve in the shell you
  run setup from.

## Best Practices

- Run with `--dry-run` first in a shared checkout.
- Install the system libs (step 3) before R packages.
- Prefer the `.sh` wrapper over calling `python3` directly (clear missing-Python hint).
- Keep the repo `bundles/` copy and the installed `~/.claude/...` copy in sync; re-run setup
  after a branch reconcile.
- Do not install R packages unless asked — use `--install-missing-r-packages` deliberately.

## Cross-References

- `../SKILL.md`
- `branch-governance.md`
- `vscode-rmd-settings.md`
- `setup-macos.md`, `setup-windows.md`
