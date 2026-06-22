# ER Setup — Branch Governance

## Quick Reference

`main` holds the **governed** `clinical-biostat-er` bundle. Contributors do not work on
`main`; they set up and work on their own branch (e.g. `internal-test-val-0N`). Before doing
anything else, setup compares **this checkout's bundle skills** against `origin/main` and
reports one classification — it never changes git on its own:

| Classification | Meaning | Setup action |
|---|---|---|
| `up-to-date` | Bundle content matches the governed `main`. | Continue, no prompt. |
| `ahead-only` | Local bundle edits not yet on `main`; nothing to pull. | Continue, no prompt. |
| `stale` | Governed `main` has bundle changes you are missing. | Ask how to sync. |
| `diverged` | Both sides changed the bundle. | Ask how to sync. |
| `+dirty` | Uncommitted edits under `bundles/clinical-biostat-er/`. | Surfaced with the above. |

Other statuses (`no-git`, `no-origin`, `detached`, `no-governed-ref`) skip governance
gracefully with an INFO/WARN line — setup still proceeds.

## How detection works

All git here is **read-only** (`rev-parse`, `remote get-url`, `fetch`, `diff`, `rev-list`,
`status`). The script never runs merge / rebase / reset / checkout.

1. Confirm a git work tree and an `origin` remote; otherwise skip.
2. Resolve the current branch (detached HEAD → skip).
3. `git fetch origin main` (read-only). On failure (offline / auth-gated), fall back to the
   local `origin/main` ref and WARN that the comparison may be stale.
4. Classify off the **net content difference of the bundle** — `git diff --quiet
   origin/main HEAD -- bundles/clinical-biostat-er/`. This answers "is my skill *content*
   the governed content?" and ignores unrelated repo history (`test_datasets_*`, `projects/`,
   …) and commit-count churn (commits that add then revert).
5. Path-scoped commit counts (`rev-list --count … -- bundles/clinical-biostat-er/`) label the
   direction (behind / ahead) only once content differs.
6. `git status --porcelain -- bundles/clinical-biostat-er/` sets the `+dirty` flag.

## Reconcile choices (Claude runs these, not the script)

When the report is `stale` or `diverged` (`[ACTION-NEEDED]`), ask the user via
AskUserQuestion, then run the chosen command:

- **Sync to main — keep local changes** (non-destructive): if `+dirty`, `git stash` (or
  commit) first; then `git fetch origin main` and `git merge origin/main` (or
  `git rebase origin/main`); then `git stash pop` if you stashed.
- **Sync to main — discard local bundle changes** (**destructive**): either
  `git checkout origin/main -- bundles/clinical-biostat-er/` (bundle only) or
  `git reset --hard origin/main` (whole branch). Get a **second explicit confirmation**
  first and suggest a backup branch (`git branch backup/<name>`) or `git stash`.
- **Leave as-is**: proceed on the current branch; record that the skills may be stale vs
  `main`.

After any sync, re-run the global-copy sync so `~/.claude/skills/clinical-biostat-er/`
matches the now-updated branch:
`python3 bundles/clinical-biostat-er/skills/er-setup/scripts/setup_er_repo.py --root .`

## Gotchas

- **Offline fetch fallback** — a failed `git fetch` means the comparison is against a possibly
  stale local ref; the WARN line says so. Run `git fetch origin main` and re-run for certainty.
- **Detached HEAD** — no branch to compare; governance is skipped. Check out a branch.
- **No git / tarball install** — no `.git` dir means governance is skipped (a valid install
  mode); freshness can't be verified.
- **`+dirty` blocks a clean fast-forward** — "keep local changes" must stash/commit first; it
  will not silently merge over uncommitted work.
- **Commit counts ≠ content** — a branch can be many commits behind/ahead yet have *identical*
  bundle content; that is correctly reported `up-to-date`. Classification is content-driven.
- **Re-sync after reconcile** — updating the branch does not update the installed `~/.claude`
  copy; re-run setup.

## Cross-References

- `../SKILL.md` (PART 1 gate)
- `setup-macos.md`, `setup-windows.md`, `setup-linux.md`
