# Core Function 1: Understanding Data And Summary Statistics

Purpose: make the ER data context explicit before modeling. The clinical pharmacology reviewer should understand what source data exist, who is evaluable, which exposure and endpoint candidates are present, how dose/exposure and response/safety evidence can be linked, and which decisions need expert review.

Key outputs:

- source dataset inventory;
- dataset role mapping from discovered source names/domains such as `adsl`, `adex`, `adpc`, `adpp`, `adrs`, `adae`, and `adtte`;
- subject and dose group summaries;
- endpoint availability table;
- exposure availability table;
- anticipated intermediate dataset plan;
- first-look safety/efficacy summaries when data-checkable;
- readiness table for downstream ER exploration and modeling.
- clinical pharmacologist overview text summary covering dataset landscape, population/dose context, exposure evidence, endpoint evidence, downstream readiness, and CP/statistics review gates.

Audience and summary lens: assume the reviewer understands PK/PD, dose-response, exposure metrics, clinical efficacy and safety endpoints, and early-development decision-making, but does not know this study package. The summary should orient them to actual source domains, what is usable now, what is only a candidate, and what must be confirmed before Core 2-5 analysis. Format the overview as short titled sections with bullet points in every section body.

Reusable pattern from `ER_template_v7_edited.Rmd` section `A. Data Pre-processing`: staged import of ADaM-like datasets, study constants/review-owned lists, dosing and dose-anchor derivations, subject-level covariates, response flags, AE/safety flags, PK/CK time alignment, TTE availability, baseline tumor/biomarker joins when present, and anticipated NONMEM/posthoc or downstream intermediate records. Do not transfer sample-specific product names, dose mapping, response definitions, AESI lists, subject exclusions, fixed time windows, or posthoc file names to new studies.

The initialized Rmd should contain runnable analysis-starting code for helper functions, preprocessing, and anticipated intermediate dataset generation. It should not stop at printing inventory CSVs.
