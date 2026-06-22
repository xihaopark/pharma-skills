# Case 26: Claude Entrypoint Smoke

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Prove you can discover the local `clinical-biostat-er` skill bundle entrypoint
> and describe the correct next execution path for mock01 semantic-parity work.
> Do not run analysis scripts and do not modify files.

Read these files:

```text
CLAUDE.md
SKILL.md
evals/agent_behavior/README.md
```

Expected answer:

- List the files you read.
- State that Case25 is the current mock01 semantic-rule decision-gate path.
- Include the two commands:
  - `Rscript evals/agent_behavior/prepare_claude_case_run.R --case=25 ...`
  - `Rscript evals/agent_behavior/run_prepared_claude_case.R --manifest=... --execute=true ...`
- Mention that `--execute=false` is the dry-run command wiring mode.
- Mention that live runs should use `--timeout-seconds`.
- State the baseline hygiene boundary for both mock datasets.
- State that `candidate_evidence_found` must not be patched directly.
- State that only `ready_for_runtime_patch` rows may drive Core 5 edits.
- State that `blocked_pending_review` remains an AZ/CP/statistics review gate.
- State that scaffold/eval output is not final, not semantic parity, not
  regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
