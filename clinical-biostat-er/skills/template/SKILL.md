---
name: template
description: Use when developing, modifying, reviewing, or validating TFLs (tables, figures, listings) in this repo, especially when touching R/Rmd templates, output shells, derivation logic, or study-specific display code. Ensures TFL work is aligned to the repo's business rules before implementation and during review.
---

# Template

## Purpose

Align TFL development with the repo's business rules before changing code, shells, specs, or generated outputs. Treat the business rule as the source of truth for what the TFL should mean, not as a post-hoc formatting check.

## Five-Core Routing

Within this bundle, this skill remains the business-rule alignment gate for all six core ER skills. If a template, Rmd, table, plot, model, or derivation conflicts with the six-core workflow contract, align to the six-core contract unless an explicit study business rule overrides it.

## Workflow

1. **Find the governing rule**
   - Search the repo for the relevant business rule, issue doc, spec, task plan, or template note before editing TFL code.
   - Prefer explicit study or output-level rules over inferred behavior from existing code.
   - If no governing rule is found, state the gap and ask for confirmation before inventing analysis, population, endpoint, visit/window, grouping, censoring, or display logic.

2. **Map rule to TFL behavior**
   - Translate the rule into concrete TFL requirements: population, endpoint, analysis set, strata, timepoint/window, grouping, denominator, summary statistic, sort order, display precision, footnotes, and exclusion handling.
   - Identify which parts are data derivation, analysis logic, and presentation formatting.
   - Keep assumptions visible in implementation notes, task docs, or review comments.

3. **Implement against the rule**
   - Update templates, R/Rmd code, shell text, and tests in the smallest scope that satisfies the rule.
   - Preserve existing repo conventions for naming, output structure, rendering, and validation.
   - Do not copy logic from another TFL unless its business rule matches the current output.

4. **Validate alignment**
   - Check that generated outputs or snapshots reflect the rule, not only that code runs.
   - Compare denominators, ordering, labels, footnotes, and missing/exclusion behavior against the rule.
   - Record any unresolved mismatch as a blocker or review question rather than silently choosing a behavior.

## Stop Conditions

Stop and ask the user, CP/statistics reviewer, or task owner when:

- The business rule is missing, ambiguous, or conflicts with code/templates.
- The requested TFL change affects analysis populations, endpoint definitions, censoring, exclusions, denominators, or interpretation.
- A formatting-only request appears to imply a business-rule change.
- Existing outputs differ from the rule and it is unclear whether the rule or historical output is authoritative.

## Output Contract

When reporting work, include:

- The business rule source or the fact that it was missing.
- The TFL behavior implemented or reviewed against that rule.
- Any assumptions, mismatches, or reviewer questions.
- The validation performed, including generated output checks when applicable.
