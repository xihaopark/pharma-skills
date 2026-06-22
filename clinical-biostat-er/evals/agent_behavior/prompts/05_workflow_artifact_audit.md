# Case 05: Workflow Artifact Audit

You are evaluating whether the local `clinical-biostat-er` skill bundle lets an
agent reason beyond a smoke-test reproduction run.

Task:

Inspect the mock dataset 01 baseline outputs and reconstruct the Core 1-5
artifact trail. Explain which artifacts appear to correspond to data
understanding, DQ, exposure metrics, ER exploration, and statistical modeling.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` as read-only.
- Do not generate or overwrite outputs.
- Do not claim that an artifact exists unless you inspected the local file tree.
- Do not claim clinical/statistical finality; this is an artifact audit.

Expected answer:

- A table with columns: core, artifact path, artifact type, evidence inspected,
  likely workflow role, review-gate implication.
- A list of missing or ambiguous artifacts that make the workflow hard to audit.
- A distinction between "reproduction harness passed" and "analyst workflow is
  fully validated".
- The next concrete improvement needed in the skill bundle or eval harness.
