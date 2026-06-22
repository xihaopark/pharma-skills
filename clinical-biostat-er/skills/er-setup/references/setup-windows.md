# ER Setup — Windows

## Quick Reference

- **You need:** PowerShell, Python 3, R, and optionally VS Code.
- **Run setup (from the repo root):**
  ```powershell
  .\bundles\clinical-biostat-er\skills\er-setup\scripts\setup-er-repo.ps1 -Root .
  ```
  Add `-DryRun` first to preview. The wrapper finds Python and delegates to
  `setup_er_repo.py`; VS Code keys auto-detect Windows (`-VscodeRPlatform current` →
  `windows`).

## Install steps

1. **Python 3:**
   ```powershell
   winget install Python.Python.3.12
   # or download from https://www.python.org/downloads/
   ```
   Re-open PowerShell so PATH refreshes; confirm `python --version`.
2. **R:**
   ```powershell
   winget install RProject.R
   # or download the installer from https://cran.r-project.org
   ```
   Ensure `R.exe` / `Rscript.exe` are on PATH (`Rscript --version`). The setup script looks
   for `R.exe` first, then `R`.
3. **R packages** — the 14-package `00_setup` base set
   (`tidyverse, haven, binom, patchwork, ggh4x, survival, survminer, flextable, officer,
   table1, ggpubr, broom, yaml, jsonlite`). Let setup report them, then either:
   ```powershell
   .\...\setup-er-repo.ps1 -Root . -InstallMissingRPackages
   # or in R:
   install.packages(c("tidyverse", ...), repos = "https://cloud.r-project.org")
   ```
4. **VS Code + R support** — install VS Code and the `REditorSupport.r` extension (setup adds
   it to `.vscode/extensions.json`). Setup writes `r.rpath.windows` / `r.rterm.windows` when R
   is on PATH.

## Gotchas

- **PATH after install** — winget/CRAN installs may not refresh the current shell; open a new
  PowerShell window before re-running setup.
- **PowerShell execution policy** — if `setup-er-repo.ps1` is blocked, run it in a session
  with `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` (or use the
  `python3 setup_er_repo.py` fallback).
- **OneDrive-redirected home** — `~`/`%USERPROFILE%` may be under OneDrive; the script resolves
  the home dynamically. Do **not** hard-code a OneDrive or `C:\Users\<name>` path anywhere.
- **`R.exe` vs `R`** — the script prefers `R.exe`; bare `R` is the Unix name.

## Best Practices

- Run with `-DryRun` first in a shared checkout.
- Prefer the `.ps1` wrapper over calling Python directly (clear missing-Python hint + winget tip).
- Keep the repo `bundles\` copy and the installed `~\.claude\...` copy in sync; re-run setup
  after a branch reconcile.
- Do not install R packages unless asked — use `-InstallMissingRPackages` deliberately.

## Cross-References

- `../SKILL.md`
- `branch-governance.md`
- `vscode-rmd-settings.md`
- `setup-macos.md`, `setup-linux.md`
