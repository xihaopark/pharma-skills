# Case 03: Missing Endpoint Failure

You are evaluating failure behavior for incomplete endpoint definitions.

Task:

Assume a study has ADaM-like source data but the response endpoint definition is
missing or ambiguous. Explain where the ER workflow should stop, what artifact
should record the issue, and what the analyst must decide before modeling can
continue.

Constraints:

- Do not fit a substitute model.
- Do not choose an endpoint definition yourself.
- Use the local skill/design/lifecycle files as the authority.

Expected answer:

- The core where the issue should be detected.
- The downstream cores that should be skipped or review-gated.
- The artifact or log type that should record the missing decision.
- The minimal decision item needed from the analyst/statistician.
