#!/usr/bin/env python3
"""Set up an ER workbench checkout for Claude skills and VS Code Rmd editing."""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


# Base set the generated study Rmd `00_setup` chunk library()-loads, mirrored from
# references/er-core-workflow-contract.md ("Required R Packages (`00_setup`)").
# `tidyverse` stays a single meta-package entry: requireNamespace("tidyverse") is
# TRUE only when the meta-package is installed, and installing it pulls in every
# member (dplyr/tidyr/ggplot2/forcats/tibble/purrr/stringr/readr).
REQUIRED_R_PACKAGES = [
    "tidyverse",
    "haven",
    "binom",
    "patchwork",
    "ggh4x",
    "survival",
    "survminer",
    "flextable",
    "officer",
    "table1",
    "ggpubr",
    "broom",
    "yaml",
    "jsonlite",
]

# Render-time tooling, reported separately at INFO level. Not part of the
# `00_setup` base set, but a setup skill whose point is Rmd readiness should still
# surface whether the notebook can be knit.
RENDER_R_PACKAGES = [
    "rmarkdown",
    "knitr",
]


def log(message: str) -> None:
    print(message)


def resolve_root(root_arg: str) -> Path:
    return Path(root_arg).expanduser().resolve()


def require_er_repo(root: Path) -> Path:
    candidates = [
        root / "clinical-biostat-er",
        root / "bundles" / "clinical-biostat-er",
    ]
    for bundle in candidates:
        if (bundle / "SKILL.md").is_file():
            return bundle
    missing = []
    missing.extend([
        "clinical-biostat-er/SKILL.md",
        "bundles/clinical-biostat-er/SKILL.md",
    ])
    raise SystemExit(
        "Not an ER workbench repo, missing one of: " + ", ".join(missing)
    )


def remove_or_backup_target(target: Path, dry_run: bool) -> None:
    if not target.exists():
        return
    stamp = datetime.now().strftime("%Y%m%d%H%M%S")
    backup = target.with_name(f"{target.name}.bak-{stamp}")
    if dry_run:
        log(f"[DRY-RUN] Would move existing {target} to {backup}")
        return
    target.rename(backup)
    log(f"[OK] Backed up existing Claude bundle to {backup}")


def copy_bundle_to_claude(bundle: Path, target: Path, dry_run: bool) -> None:
    if dry_run:
        remove_or_backup_target(target, dry_run=True)
        log(f"[DRY-RUN] Would copy {bundle} to {target}")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    remove_or_backup_target(target, dry_run=False)
    shutil.copytree(
        bundle,
        target,
        ignore=shutil.ignore_patterns(".DS_Store", "__pycache__", "*.pyc"),
    )
    log(f"[OK] Installed Claude skill bundle at {target}")


def claude_targets(root: Path, target_mode: str) -> list[Path]:
    targets: list[Path] = []
    if target_mode in {"global", "both"}:
        targets.append(Path.home() / ".claude" / "skills" / "clinical-biostat-er")
    if target_mode in {"project", "both"}:
        targets.append(root / ".claude" / "skills" / "clinical-biostat-er")
    return targets


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        with path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Cannot parse JSON in {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise SystemExit(f"Expected JSON object in {path}")
    return payload


def write_json(path: Path, payload: dict[str, Any], dry_run: bool) -> None:
    text = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    if dry_run:
        log(f"[DRY-RUN] Would write {path}:")
        for line in text.splitlines():
            log(f"  {line}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    log(f"[OK] Updated {path}")


def which_r_binary() -> str | None:
    candidates = ["R.exe", "R"] if platform.system() == "Windows" else ["R"]
    for candidate in candidates:
        found = shutil.which(candidate)
        if found:
            return found
    return None


def current_vscode_r_platform() -> str:
    system = platform.system()
    if system == "Windows":
        return "windows"
    if system == "Darwin":
        return "mac"
    return "linux"


def os_r_keys(vscode_r_platform: str) -> tuple[str, str]:
    if vscode_r_platform == "current":
        vscode_r_platform = current_vscode_r_platform()
    if vscode_r_platform == "windows":
        return "r.rpath.windows", "r.rterm.windows"
    if vscode_r_platform == "mac":
        return "r.rpath.mac", "r.rterm.mac"
    return "r.rpath.linux", "r.rterm.linux"


# Generic package-manager commands only — never hard-code a user/OneDrive/Python/R
# install path. `tool` is one of: "python", "r", "r-packages".
_INSTALL_HINTS: dict[str, dict[str, list[str]]] = {
    "Darwin": {
        "python": ["brew install python@3.12  (or: port install python312)"],
        "r": ["brew install --cask r  (or download the CRAN .pkg from https://cran.r-project.org)"],
        "r-packages": [
            "Re-run this setup with --install-missing-r-packages, or in R:",
            "  install.packages(c(...), repos='https://cloud.r-project.org')",
        ],
    },
    "Windows": {
        "python": [
            "winget install Python.Python.3.12",
            "  (or download from https://www.python.org/downloads/)",
        ],
        "r": [
            "winget install RProject.R",
            "  (or download the installer from https://cran.r-project.org)",
        ],
        "r-packages": [
            "Re-run this setup with --install-missing-r-packages, or in R:",
            "  install.packages(c(...), repos='https://cloud.r-project.org')",
        ],
    },
    "Linux": {
        "python": ["sudo apt-get install python3 python3-pip  (Debian/Ubuntu)"],
        "r": ["sudo apt-get install r-base r-base-dev  (Debian/Ubuntu)"],
        "r-packages": [
            "Re-run this setup with --install-missing-r-packages, or in R:",
            "  install.packages(c(...), repos='https://cloud.r-project.org')",
            "Note: CRAN compiles from source on Linux; some packages need system libs first:",
            "  sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev \\",
            "    libfontconfig1-dev libfreetype6-dev libcairo2-dev",
        ],
    },
}


def os_install_hint(tool: str) -> list[str]:
    system = platform.system()
    family = system if system in _INSTALL_HINTS else "Linux"
    return _INSTALL_HINTS[family].get(tool, [])


def log_install_hint(tool: str) -> None:
    for line in os_install_hint(tool):
        log(f"       {line}")


def merge_vscode_settings(root: Path, dry_run: bool, vscode_r_platform: str) -> None:
    vscode_dir = root / ".vscode"
    settings_path = vscode_dir / "settings.json"
    settings = load_json(settings_path)

    settings["r.lsp.enabled"] = True
    associations = settings.get("files.associations")
    if not isinstance(associations, dict):
        associations = {}
    associations["*.Rmd"] = "rmd"
    associations["*.rmd"] = "rmd"
    settings["files.associations"] = associations

    rpath_key, rterm_key = os_r_keys(vscode_r_platform)
    r_binary = which_r_binary()
    target_platform = current_vscode_r_platform() if vscode_r_platform == "current" else vscode_r_platform
    current_platform = current_vscode_r_platform()
    if r_binary and target_platform == current_platform:
        settings.setdefault(rpath_key, r_binary)
        settings.setdefault(rterm_key, r_binary)
        log(f"[OK] Detected R executable for VS Code: {r_binary}")
    elif rpath_key in settings or rterm_key in settings:
        log(f"[OK] Preserved existing VS Code R path keys for {target_platform}.")
    else:
        log(
            f"[WARN] No R path written for the '{target_platform}' VS Code target "
            f"(it differs from this OS, or no R was found here). Run setup on that OS, "
            f"or set {rpath_key} and {rterm_key} in VS Code manually."
        )

    write_json(settings_path, settings, dry_run=dry_run)

    extensions_path = vscode_dir / "extensions.json"
    extensions = load_json(extensions_path)
    recommendations = extensions.get("recommendations")
    if not isinstance(recommendations, list):
        recommendations = []
    if "REditorSupport.r" not in recommendations:
        recommendations.append("REditorSupport.r")
    extensions["recommendations"] = recommendations
    write_json(extensions_path, extensions, dry_run=dry_run)


def command_exists(name: str) -> str | None:
    return shutil.which(name)


def run_checked(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


# --- Git branch-governance gate (READ-ONLY) ---------------------------------
#
# `main` holds the governed clinical-biostat-er bundle. Contributors set up their
# environment on their own working branch (e.g. internal-test-val-0N). Before
# touching anything, report whether this checkout's bundle skills are current vs
# the governed origin/main. This function NEVER mutates the repo (no merge, rebase,
# reset, checkout). When a sync is needed, the er-setup skill asks the user and
# Claude runs the chosen git command after an explicit confirm.

GOVERNED_REMOTE = "origin"
GOVERNED_BRANCH = "main"


def _git(root: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    return run_checked(["git", "-C", str(root), *args])


def _git_ok(result: subprocess.CompletedProcess[str]) -> bool:
    return result.returncode == 0


def check_branch_governance(root: Path, bundle: Path) -> dict[str, Any]:
    """Detect (read-only) how this checkout's bundle compares to origin/main.

    Returns a dict with at least {"status": <classification>}. Classifications:
      no-git | no-origin | detached | up-to-date | ahead-only | stale | diverged
    `dirty` (uncommitted bundle edits) is reported as a separate boolean.
    """
    if not command_exists("git"):
        log("[INFO] git not found on PATH; skipping branch-governance check.")
        return {"status": "no-git"}
    if not _git_ok(_git(root, ["rev-parse", "--is-inside-work-tree"])):
        log("[INFO] Not a git working tree (e.g. tarball install); "
            "skipping branch-governance check.")
        return {"status": "no-git"}

    branch = _git(root, ["rev-parse", "--abbrev-ref", "HEAD"]).stdout.strip()
    if branch == "HEAD":
        sha = _git(root, ["rev-parse", "--short", "HEAD"]).stdout.strip()
        log(f"[INFO] Detached HEAD at {sha}; skipping branch-governance check "
            f"(checkout a branch to compare against {GOVERNED_REMOTE}/{GOVERNED_BRANCH}).")
        return {"status": "detached", "sha": sha}

    origin_url = _git(root, ["remote", "get-url", GOVERNED_REMOTE])
    if not _git_ok(origin_url):
        log(f"[INFO] No '{GOVERNED_REMOTE}' remote; skipping branch-governance check.")
        return {"status": "no-origin", "branch": branch}
    log(f"[OK] Branch: {branch}  (governed: {GOVERNED_REMOTE}/{GOVERNED_BRANCH} "
        f"@ {origin_url.stdout.strip()})")

    # Read-only fetch of the governed tip. No merge / no checkout.
    fetched = _git_ok(_git(root, ["fetch", GOVERNED_REMOTE, GOVERNED_BRANCH]))
    governed = f"{GOVERNED_REMOTE}/{GOVERNED_BRANCH}"
    if not fetched:
        # Offline / auth-gated: fall back to whatever ref we already have.
        if not _git_ok(_git(root, ["rev-parse", "--verify", "--quiet", governed])):
            governed = GOVERNED_BRANCH  # last resort: a local 'main'
        log(f"[WARN] Could not fetch {GOVERNED_REMOTE} {GOVERNED_BRANCH}; comparing "
            f"against local '{governed}' — may be stale. Run 'git fetch {GOVERNED_REMOTE} "
            f"{GOVERNED_BRANCH}' for a current comparison.")
    if not _git_ok(_git(root, ["rev-parse", "--verify", "--quiet", governed])):
        log(f"[WARN] No '{governed}' ref available; cannot classify branch freshness.")
        return {"status": "no-governed-ref", "branch": branch}

    # Classification is driven by the *net content difference* of the bundle (a
    # two-dot diff of governed-tip vs HEAD), NOT raw commit counts. Commit counts
    # over-report churn (commits that add then revert), and unrelated repo history
    # (test_datasets_*, projects/, ...) is excluded by the pathspec. This directly
    # answers the real question: is my skill *content* the governed content?
    bundle_pathspec = bundle.relative_to(root).as_posix().rstrip("/") + "/"
    diff_quiet = _git(root, ["diff", "--quiet", governed, "HEAD", "--", bundle_pathspec])
    content_differs = diff_quiet.returncode == 1  # 0 = identical, 1 = differs

    # Path-scoped commit counts only label the direction once content differs.
    def _count(rev_range: str) -> int:
        out = _git(root, ["rev-list", "--count", rev_range, "--", bundle_pathspec])
        return int(out.stdout.strip()) if _git_ok(out) and out.stdout.strip() else 0

    behind = _count(f"HEAD..{governed}")   # governed bundle commits HEAD is missing
    ahead = _count(f"{governed}..HEAD")     # local bundle commits not on governed

    dirty_out = _git(root, ["status", "--porcelain", "--", bundle_pathspec])
    dirty = bool(_git_ok(dirty_out) and dirty_out.stdout.strip())

    if not content_differs:
        status = "up-to-date"
    elif behind > 0 and ahead > 0:
        status = "diverged"
    elif behind > 0:
        status = "stale"
    else:
        status = "ahead-only"

    suffix = " +dirty" if dirty else ""
    log(f"[OK] Bundle freshness vs {governed}: {status} "
        f"(behind {behind}, ahead {ahead}){suffix}.")
    if content_differs:
        bundle_diff = _git(root, ["diff", "--stat", governed, "HEAD", "--", bundle_pathspec])
        if _git_ok(bundle_diff) and bundle_diff.stdout.strip():
            log("[INFO] Bundle files differing from the governed copy:")
            for line in bundle_diff.stdout.strip().splitlines():
                log(f"       {line.strip()}")
    if status in {"stale", "diverged"}:
        log(f"[WARN] Your '{branch}' bundle is behind the governed {governed}. The "
            "er-setup skill will ask whether to sync (keep or discard local changes) "
            "before any git command runs; no repo change is made here.")
    elif status == "ahead-only":
        log(f"[INFO] Your '{branch}' bundle has local edits not yet on {governed} "
            "(ahead-only); nothing to pull.")
    if dirty:
        log("[INFO] Uncommitted bundle edits present — a 'keep local changes' sync must "
            "stash/commit them first; a 'discard' sync would lose them.")

    return {
        "status": status,
        "branch": branch,
        "governed": governed,
        "behind": behind,
        "ahead": ahead,
        "dirty": dirty,
        "content_differs": content_differs,
        "fetched": fetched,
        "bundle_pathspec": bundle_pathspec,
    }


def _missing_r_packages(rscript: str, packages: list[str]) -> list[str] | None:
    """Return the subset of `packages` not installed, or None if the check errored."""
    expr = (
        "pkgs <- c("
        + ",".join(repr(pkg) for pkg in packages)
        + "); missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly=TRUE)]; "
        "cat(paste(missing, collapse='\\n'))"
    )
    result = run_checked([rscript, "-e", expr])
    if result.returncode != 0:
        log("[WARN] R package check failed:")
        log(result.stderr.strip() or result.stdout.strip())
        return None
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def check_r_packages(install_missing: bool, dry_run: bool) -> None:
    rscript = command_exists("Rscript")
    if not rscript:
        log("[WARN] Rscript not found on PATH; cannot check R packages.")
        log_install_hint("r")
        return

    # Render-time tooling (rmarkdown/knitr): reported at INFO level only — not part
    # of the 00_setup base set, but useful to know the notebook can be knit.
    render_missing = _missing_r_packages(rscript, RENDER_R_PACKAGES)
    if render_missing:
        log("[INFO] Render tooling not installed: " + ", ".join(render_missing)
            + " (needed to knit the workflow Rmd).")

    missing = _missing_r_packages(rscript, REQUIRED_R_PACKAGES)
    if missing is None:
        return
    if not missing:
        log("[OK] Required R packages are available.")
        return
    log("[WARN] Missing R packages: " + ", ".join(missing))
    if not install_missing:
        log("[INFO] Re-run with --install-missing-r-packages to install them.")
        log_install_hint("r-packages")
        return
    install_expr = (
        "install.packages(c("
        + ",".join(repr(pkg) for pkg in missing)
        + "), repos='https://cloud.r-project.org')"
    )
    if dry_run:
        log(f"[DRY-RUN] Would install missing R packages with {rscript} -e \"{install_expr}\"")
        return
    install_result = run_checked([rscript, "-e", install_expr])
    if install_result.returncode != 0:
        log("[WARN] R package installation failed:")
        log(install_result.stderr.strip() or install_result.stdout.strip())
        log_install_hint("r-packages")
        return
    log("[OK] Installed missing R packages.")


def check_cairo_device(rscript: str) -> None:
    """On Linux, warn if R lacks a Cairo-capable PNG device.

    ER plots use Unicode glyphs (theme_er.R) that need a Unicode-capable device —
    Cairo (png(type="cairo")) or ragg::agg_png on Linux, Quartz on macOS. A
    non-Cairo Linux build silently writes a BLANK png (mbcsToSbcs), so flag it at
    setup time rather than after a study run produces empty figures.
    """
    if platform.system() != "Linux":
        return
    probe = run_checked([rscript, "-e", "cat(isTRUE(capabilities('cairo')))"])
    has_cairo = probe.returncode == 0 and probe.stdout.strip() == "TRUE"
    has_ragg = _missing_r_packages(rscript, ["ragg"]) == []
    if has_cairo or has_ragg:
        log("[OK] Linux: a Unicode-capable PNG device is available "
            f"({'Cairo' if has_cairo else 'ragg'}).")
        return
    log("[WARN] Linux: R has no Cairo-capable PNG device and 'ragg' is not installed. "
        "ER plots use Unicode glyphs and will render as BLANK png on the default "
        "bitmap device. Use png(type='cairo')/ragg::agg_png — install 'ragg' "
        "(install.packages('ragg')) or an R build with Cairo support.")


def check_runtimes(install_missing_r_packages: bool, dry_run: bool) -> None:
    log(f"[OK] Python executable: {sys.executable}")
    rscript = command_exists("Rscript")
    if rscript:
        version = run_checked([rscript, "--version"])
        output = (version.stdout or version.stderr).strip()
        log(f"[OK] Rscript: {rscript}" + (f" ({output})" if output else ""))
    else:
        log("[WARN] Rscript not found on PATH.")
        log_install_hint("r")
    r_binary = which_r_binary()
    if r_binary:
        log(f"[OK] R executable: {r_binary}")
    else:
        log("[WARN] R executable not found on PATH.")
        log_install_hint("r")
    check_r_packages(install_missing=install_missing_r_packages, dry_run=dry_run)
    if rscript:
        check_cairo_device(rscript)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Set up an ER repo for Claude bundle skills and VS Code Rmd editing."
    )
    parser.add_argument("--root", default=".", help="Repository root. Default: current directory.")
    parser.add_argument(
        "--claude-target",
        choices=["global", "project", "both"],
        default="global",
        help="Where to install the clinical-biostat-er bundle for Claude discovery.",
    )
    parser.add_argument(
        "--configure-vscode",
        dest="configure_vscode",
        action="store_true",
        default=True,
        help="Merge VS Code R/Rmd settings. Default: enabled.",
    )
    parser.add_argument(
        "--no-configure-vscode",
        dest="configure_vscode",
        action="store_false",
        help="Skip VS Code settings merge.",
    )
    parser.add_argument(
        "--vscode-r-platform",
        choices=["windows", "current", "mac", "linux"],
        default="current",
        help=(
            "Which VS Code R path keys to manage. Default: current (auto-detect the "
            "OS running setup — macOS, Windows, or Linux)."
        ),
    )
    parser.add_argument(
        "--check-runtimes",
        dest="check_runtimes",
        action="store_true",
        default=True,
        help="Check Python/R/R package readiness. Default: enabled.",
    )
    parser.add_argument(
        "--no-check-runtimes",
        dest="check_runtimes",
        action="store_false",
        help="Skip runtime checks.",
    )
    parser.add_argument(
        "--branch-check",
        dest="branch_check",
        action="store_true",
        default=True,
        help="Report this checkout's bundle freshness vs the governed origin/main. Default: enabled (read-only).",
    )
    parser.add_argument(
        "--no-branch-check",
        dest="branch_check",
        action="store_false",
        help="Skip the git branch-governance check.",
    )
    parser.add_argument(
        "--install-missing-r-packages",
        action="store_true",
        help="Install missing R packages from CRAN. Default: report only.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print changes without writing files.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = resolve_root(args.root)
    bundle = require_er_repo(root)
    log(f"[OK] ER repo root: {root}")
    log(f"[OK] Bundle source: {bundle}")

    # Branch-governance gate (read-only). Detection only — when a sync is needed the
    # er-setup skill asks the user and Claude runs the chosen git command.
    governance = {"status": "skipped"}
    if args.branch_check:
        governance = check_branch_governance(root, bundle)
    else:
        log("[INFO] Skipped branch-governance check.")
    if governance.get("status") in {"stale", "diverged"}:
        log("[ACTION-NEEDED] Bundle is behind the governed main — decide how to sync "
            "(keep or discard local changes) before relying on these skills. See "
            "references/branch-governance.md.")

    for target in claude_targets(root, args.claude_target):
        copy_bundle_to_claude(bundle, target, dry_run=args.dry_run)

    if args.configure_vscode:
        merge_vscode_settings(
            root,
            dry_run=args.dry_run,
            vscode_r_platform=args.vscode_r_platform,
        )
    else:
        log("[INFO] Skipped VS Code configuration.")

    if args.check_runtimes:
        check_runtimes(
            install_missing_r_packages=args.install_missing_r_packages,
            dry_run=args.dry_run,
        )
    else:
        log("[INFO] Skipped runtime checks.")

    log("[OK] ER setup completed." if not args.dry_run else "[OK] ER setup dry-run completed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
