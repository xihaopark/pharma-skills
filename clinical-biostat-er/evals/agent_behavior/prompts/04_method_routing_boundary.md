# Case 04: Method Routing Boundary

You are evaluating whether the skill respects implemented method boundaries.

Task:

Assume an ER question requests a model family outside the currently executable
Core 5 defaults. Explain how the workflow should route this request and what
should be written to the method audit or skip log.

Constraints:

- Do not implement the new model family.
- Do not silently fit an ad hoc model.
- Ground the answer in local bundle contracts.

Expected answer:

- Identify currently executable Core 5 model families.
- Explain what happens to unsupported method families.
- Identify the audit/skip-log behavior expected from the workflow.
- State what would be needed to promote the method from candidate to executable.
