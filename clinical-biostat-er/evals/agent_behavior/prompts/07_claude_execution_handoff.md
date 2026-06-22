# Case 07: Claude Execution Handoff

You are evaluating whether the agent can prepare a constrained handoff for a
second Claude Code run.

Task:

Create a Claude Code execution handoff for running an ER analysis-quality eval
against mock dataset 01 without modifying baseline outputs. The handoff should
be specific enough that another agent can execute it with minimal interpretation.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Read `skills/codex-claude-handoff/SKILL.md` if present.
- The handoff must direct all generated outputs to
  `evals/_runs/<case_id>_<timestamp>/`.
- The handoff must explicitly forbid writes to root-level mock dataset
  baselines.
- Do not ask the second agent to invent missing endpoint definitions or model
  families.

Expected answer:

- A handoff block with: objective, input paths, output path, allowed commands,
  forbidden actions, review gates, validation commands, expected artifacts, and
  failure classification rules.
- A short explanation of how this handoff would catch shallow behavior.
