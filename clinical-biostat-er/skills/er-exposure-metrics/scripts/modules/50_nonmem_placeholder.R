# ---- Section C. NONMEM-ready input (placeholder) ------------------------

# Stub. Implementation deferred until a study explicitly requests NONMEM
# dataset prep. Orchestrator only calls this when
# spec$nonmem_run$status == "requested"; otherwise it writes a needs_review
# row instead.
build_nonmem_input <- function(pk_records, dose_records, subject_index,
                               spec, derived_dir) {
  # IMPLEMENTATION (deferred): assemble NM-TRAN columns ID, TIME, EVID, AMT,
  # DV, MDV, RATE/DUR, CMT, plus covariates from spec$nonmem_run$covariates;
  # write derived_dir/nonmem_input.csv and nonmem_input_manifest.csv with
  # row counts, subject coverage, missingness flags.
  NULL
}
