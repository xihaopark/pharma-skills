# ER Skill Bundle Review Upload Checklist

Use this checklist before uploading the `clinical-biostat-er` bundle or sending
the lightweight review packet to colleagues.

## Source Scope

Upload the source repository changes for:

- top-level contracts: `SKILL.md`, `CLAUDE.md`, `README-handoff.md`,
  `LIFECYCLE.md`, `RELEASE_READINESS.md`, `DELIVERY_REVIEW.md`;
- core skill contracts: `skills/*/SKILL.md`, `skills/*/DESIGN.md`,
  `skills/*/references/`;
- runtime modules: `scripts/shared/`, `skills/*/scripts/modules/`, and the old
  compatibility helper entrypoints;
- eval harnesses: `evals/agent_behavior/`, `evals/reproduction/mock_dataset_01/`;
- tests: `tests/`;
- reviewer docs and figure: `docs/`.

Do not upload generated run payloads as source:

- `clinical-biostat-er/evals/_runs/`;
- `clinical-biostat-er/evals/visual_review/`;
- `clinical-biostat-er/evals/claude_code_runs/`;
- `clinical-biostat-er/dist/`;
- root mock dataset folders as generated-output destinations.

These generated paths are intentionally gitignored. Attach selected evidence
through the lightweight review packet instead of committing the full directories.

## Current Review Packet

Build or refresh the lightweight packet from the bundle root:

```bash
Rscript scripts/build_review_packet.R \
  --packet-name=clinical-biostat-er-review-packet_current
```

Expected output:

```text
dist/clinical-biostat-er-review-packet_current/
dist/clinical-biostat-er-review-packet_current.zip
```

The packet must contain:

- `PACKET_MANIFEST.md`;
- `DELIVERY_REVIEW.md`;
- `RELEASE_READINESS.md`;
- `docs/evaluation_standard.md`;
- `docs/review_evidence/mock01_current_status.md`;
- `evals/agent_behavior/current_frontier.csv`;
- `coverage_summary.csv`;
- `results_table_diff_summary.csv`;
- `figure_semantic_contract.csv`;
- `figure_plotted_data_summary.csv`;
- `figure_semantic_contract_README.md`.

## Required Validation

Run from `clinical-biostat-er/`:

```bash
Rscript tests/test_review_packet_builder.R
Rscript tests/test_figure_semantic_contract.R
Rscript tests/test_reproduction_comparison_pack.R
Rscript tests/test_setup_discovery_contracts.R
Rscript evals/agent_behavior/run_mock01_review_acceptance.R
```

The last command is the current mock01-only acceptance command. It must include
passing rows for:

- `01_setup_discovery`;
- `08_comparison_pack`;
- `09_figure_semantic_contract`;
- `10_review_packet_builder`.

It also writes `mock01_acceptance_evidence.csv`, which must show:

- 9 `table_matched` rows;
- 48 `contract_pass` figure rows;
- 48 plotted-data evidence rows;
- 0 missing-artifact backlog rows.

## Current Evidence Boundary

Current mock01 evidence supports:

- 9/9 AZ reference Results tables matched;
- 48/48 Results figures present by same-name inventory;
- 48/48 figure semantic contracts passing;
- plotted-data evidence recorded for all 48 Results figures;
- Core 2 reference preview contract passing for 6/6 reference previews.

This is not a pixel-level visual regression claim. It is not regulatory-ready,
labeling-ready, dose-selection-ready, or decision-ready without AZ/CP/statistics
review.

## Upload Notes

- Keep the GitHub repository private.
- Use `xihaopark/AZ` as the project repository identity; this bundle is not a
  fork of any external upstream.
- Do not rewrite or delete root mock dataset baselines during upload prep.
- If attaching evidence outside Git, attach the zip packet, not the full
  multi-GB generated run directories.
- `run_agent_behavior_regression.R` remains an internal broader regression
  harness. It includes exploratory mock02/CAR-T guardrails and is not the
  acceptance command for this mock01-only delivery.
