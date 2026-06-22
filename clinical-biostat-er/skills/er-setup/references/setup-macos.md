# ER Setup — macOS

## Quick Reference

- **You need:** a terminal (zsh/bash), Python 3, R, and optionally VS Code.
- **Run setup (from the repo root):**
  ```bash
  bash bundles/clinical-biostat-er/skills/er-setup/scripts/setup-er-repo.sh --root .
  ```
  Add `--dry-run` first to preview. The wrapper finds Python and delegates to
  `setup_er_repo.py`; VS Code keys auto-detect macOS (`--vscode-r-platform current`).

## Install steps

1. **Python 3** — usually already present (`python3 --version`). Otherwise:
   ```bash
   brew install python@3.12      # Homebrew
   # or: port install python312  # MacPorts
   ```
2. **R** — install the GUI/runtime:
   ```bash
   brew install --cask r
   # or download the .pkg from https://cran.r-project.org
   ```
   Confirm `Rscript --version` resolves. The path is environment-specific —
   `/usr/local/bin/Rscript` (Intel Homebrew / CRAN) or under `/opt/homebrew/bin` (Apple
   Silicon Homebrew). Feature-detect; do not hard-code.
3. **R packages** — the 14-package `00_setup` base set
   (`tidyverse, haven, binom, patchwork, ggh4x, survival, survminer, flextable, officer,
   table1, ggpubr, broom, yaml, jsonlite`). Let setup report them, then either:
   ```bash
   bash .../setup-er-repo.sh --root . --install-missing-r-packages
   # or in R:
   install.packages(c("tidyverse", ...), repos = "https://cloud.r-project.org")
   ```
4. **VS Code + R support** — install VS Code (`brew install --cask visual-studio-code`) and the
   `REditorSupport.r` extension (setup adds it to `.vscode/extensions.json`). Setup writes
   `r.rpath.mac` / `r.rterm.mac` when R is on PATH.

## Gotchas

- **Homebrew vs system R PATH** — make sure the R you intend is first on PATH; Apple Silicon
  Homebrew lives under `/opt/homebrew`, Intel under `/usr/local`.
- **Quartz device is Unicode-capable** — the ER theme's Unicode glyphs (★/◎/↑) render fine on
  macOS; no Cairo workaround needed (unlike Linux).
- **`--cask r` vs CRAN GUI** — either works; the CRAN `.pkg` also installs the R.app GUI.

## Best Practices

- Run with `--dry-run` first in a shared checkout.
- Prefer the `.sh` wrapper over calling `python3` directly (clear missing-Python hint).
- Keep the repo `bundles/` copy and the installed `~/.claude/...` copy in sync; re-run setup
  after a branch reconcile.
- Do not install R packages unless asked — use `--install-missing-r-packages` deliberately.

## Cross-References

- `../SKILL.md`
- `branch-governance.md`
- `vscode-rmd-settings.md`
- `setup-windows.md`, `setup-linux.md`
