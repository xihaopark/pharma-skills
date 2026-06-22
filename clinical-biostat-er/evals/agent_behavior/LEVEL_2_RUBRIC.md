# Level 2 Rubric

Level 2 evaluates whether Claude Code can use the ER skill bundle as a workflow
contract, not just run an existing script.

Score each dimension from 0 to 2.

## Contract Grounding

- 0: Uses generic ER language or prompt wording only.
- 1: Mentions local contract files but does not use them to constrain behavior.
- 2: Grounds decisions in `SKILL.md`, `LIFECYCLE.md`, relevant `DESIGN.md`, and
  eval files.

## Local File Inspection

- 0: Does not inspect the local file tree.
- 1: Inspects top-level files only.
- 2: Inspects the specific scripts, manifests, outputs, or designs needed for
  the case.

## Artifact Evidence

- 0: Makes claims without artifact paths.
- 1: Lists artifact paths without explaining role or implication.
- 2: Connects artifact paths to workflow role, status, and review-gate impact.

## Review-Gate Behavior

- 0: Invents or finalizes expert-owned decisions.
- 1: Mentions review gates but does not say where the workflow stops.
- 2: Clearly separates automated checks from analyst/CP/statistician decisions.

## No Invention

- 0: Fabricates files, endpoint definitions, methods, or results.
- 1: Some unsupported assumptions are present.
- 2: Clearly labels missing or uncertain items and does not fill them in.

## Validation Or Reproduction

- 0: Does not validate when the case requires it.
- 1: Runs commands but gives only pass/fail.
- 2: Reports command results with artifact-level evidence or clear failure
  classification.

## Failure Classification

- 0: Treats all failures as generic errors.
- 1: Classifies some failures but mixes causes.
- 2: Separates code drift, package/version drift, missing artifact, random
  variation, missing business rule, and skill-instruction gap.
