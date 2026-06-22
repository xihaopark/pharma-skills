# Study Folder Layout Contract

Core 1 (`er-understanding-data`) is the only place that resolves a study's folder layout. The result is written to `<study_root>/config/study_paths.yaml`. Every downstream skill, Rmd chunk, and standalone script reads that file rather than probing the filesystem.

This contract exists because runtime path discovery (probing `SourceData/`, `data/source/`, `mock_data/source/`, etc.) drifts silently across studies, embeds cross-study literals (e.g. `mock_dataset_01_small_molecules_onco`) in code that's supposed to be generic, and forces every consumer to reimplement the same fallback list. After Core 1 runs, paths are config — not search.

## Standard layout

A canonical ER study has four user-facing folders:

| Role | Default folder name | Purpose |
|---|---|---|
| `source_dir` | `SourceData/` | ADaM/SDTM source data (`.sas7bdat`, CSV) |
| `scripts_dir` | `Scripts/` | Per-study standalone R scripts (e.g. example runners) |
| `derived_dir` | `Models/` | Derived data products: NONMEM outputs, posthoc tables, exposure metrics |
| `outputs_dir` | `Outputs/` | Plot files, tables, manifests, deliverables |

Plus one fixed-name folder, never user-elicited:

| Role | Folder name | Purpose |
|---|---|---|
| `intermediate_dir` | `intermediate/` | Per-core intermediate artifacts (`intermediate/01_understanding_data/`, `intermediate/02_individual_pk_pd_review/`, etc.) |

## Recognized aliases

When Core 1 first runs on a study, it scans `<study_root>/` for any subdirectory matching the alias list for each role. Aliases exist to honor pre-existing study layouts; they are never reused at runtime.

| Role | Default | Recognized aliases |
|---|---|---|
| `source_dir` | `SourceData` | `SourceData`, `source_data`, `data/source`, `mock_data/source`, `source`, `sdtm` |
| `scripts_dir` | `Scripts` | `Scripts`, `scripts`, `R`, `src` |
| `derived_dir` | `Models` | `Models`, `Derived`, `derived_data`, `derived`, `posthoc` |
| `outputs_dir` | `Outputs` | `Outputs`, `Results`, `output`, `results`, `figures` |

Matching is case-sensitive on POSIX, case-insensitive on macOS. Aliases include nested paths (`data/source`, `mock_data/source`) — Core 1 treats them as a single relative path, not a dir-name match.

## Elicitation flow

Core 1 invokes elicitation only when `<study_root>/config/study_paths.yaml` does not already exist.

1. **Scan**: list every immediate subdirectory of `<study_root>`, plus the documented nested paths (`data/source`, `mock_data/source`).
2. **Match**: for each role, find aliases that resolve to an existing subdirectory.
3. **Prompt the user** (one batch question) showing what was detected and what defaults will be created. Example:

   > Detected for this study:
   > - `source_dir` → `data/source` (matches alias)
   > - `scripts_dir` → `Scripts` (matches default)
   > - `derived_dir` → not found; will create `Models/` if no override
   > - `outputs_dir` → not found; will create `Outputs/` if no override
   >
   > Confirm or supply paths.

4. **Apply**: accept user overrides; for any role still unset, create the default folder.
5. **Record**: write `config/study_paths.yaml` (schema below) and append one row per role to `intermediate/01_understanding_data/assumption_register.csv` noting which alias matched (or `default_created`).

On subsequent runs, Core 1 detects the existing `study_paths.yaml` and skips elicitation.

## Schema — `config/study_paths.yaml`

```yaml
generated_by: er-understanding-data
generated_at: 2026-05-27T14:00:00+0000
study_root: /absolute/path/to/<study>
source_dir: SourceData
scripts_dir: Scripts
derived_dir: Models
outputs_dir: Outputs
intermediate_dir: intermediate
notes:
  source_dir_alias_resolved: SourceData
  scripts_dir_alias_resolved: Scripts
  derived_dir_alias_resolved: default_created
  outputs_dir_alias_resolved: default_created
```

- `study_root` is absolute (machine-specific). Relative paths under it are portable.
- All other paths are **relative to `study_root`**.
- `notes.<role>_alias_resolved` records either the alias the user's existing folder matched, or `default_created` if Core 1 had to create the directory.
- `intermediate_dir` is fixed at `intermediate` and not prompted; it appears here so consumers have a single source of truth.

## Runtime contract

Every `00_setup` chunk and every standalone runner reads the file like this:

```r
study_paths_file <- file.path(root_dir, 'config', 'study_paths.yaml')
if (!file.exists(study_paths_file)) {
  stop('Missing config/study_paths.yaml. Run er-understanding-data on this study first ',
       'to elicit and record the standard folder layout.', call. = FALSE)
}
study_paths <- yaml::read_yaml(study_paths_file)
resolve_study_path <- function(rel) {
  base <- study_paths$study_root %||% root_dir
  p <- if (file.exists(rel)) rel else file.path(base, rel)
  normalizePath(p, mustWork = FALSE)
}
source_dir       <- resolve_study_path(study_paths$source_dir)
scripts_dir      <- resolve_study_path(study_paths$scripts_dir)
derived_dir      <- resolve_study_path(study_paths$derived_dir)
outputs_dir      <- resolve_study_path(study_paths$outputs_dir)
intermediate_dir <- resolve_study_path(file.path(study_paths$intermediate_dir %||% 'intermediate', '01_understanding_data'))
```

No fallbacks, no candidate lists. If the file is missing, the chunk fails loudly and tells the user how to fix it.

## Root directory emission

`root_dir` is the variable the runtime block above resolves everything against, so it must already be bound when `00_setup` runs. Core 1 emits it as a **single absolute literal**, on one line, with no auto-detection:

```r
root_dir <- "/absolute/path/to/study_root"
if (requireNamespace("knitr", quietly = TRUE)) knitr::opts_knit$set(root.dir = root_dir)
```

- The literal **must be absolute**. Under `rmarkdown::render()` the chunk cwd is the Rmd's `analysis/` folder; a relative `"./study/"` literal would resolve against the wrong directory. The `knitr::opts_knit$set(root.dir = ...)` pin keeps interactive and headless runs in agreement.
- The reusable generator (`er_core1_setup_code(study_root)`) interpolates the resolved absolute path directly into the `root_dir <- "…"` line — no placeholder token is left in the emitted Rmd.
- **If the user supplies no root**, Core 1 creates a `study_0x/` folder in the current working directory with the standard structure (`config/`, `intermediate/`, `outputs/`, and the data folders), drops the source data into it, and writes that folder's absolute path as `root_dir` (and as `study_root` in `study_paths.yaml`).
- `study_root` in `study_paths.yaml` must equal this same absolute path. An empty `study_root: ""` is a broken state (it forces the `%||% root_dir` fallback) and Core 1 must write the absolute path instead.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `Missing config/study_paths.yaml. Run er-understanding-data...` | Core 1 was never run on this study | Invoke `er-understanding-data` once |
| File exists but `study_root` points to a different machine | Repo moved between machines | Re-run Core 1 elicitation; `study_root` is rewritten in place |
| One of the relative paths no longer exists | User deleted/renamed a folder | Re-run Core 1; it will re-prompt for that role |

## Anti-patterns

- Probing `c('SourceData', 'data/source', ...)` at runtime in any consumer. The whole point of this contract is that probing happens once, in Core 1.
- Embedding study-specific names (endpoint labels, product names, study-id literals) in `00_setup` logic. The chunk body is identical across studies; the **only** per-study value is the absolute `root_dir` literal Core 1 writes (see "Root directory emission"). Everything else lives in `study_paths.yaml` / the spec.
- Reading `study_paths.yaml` from a downstream skill and writing back to it. Only Core 1 writes this file.
