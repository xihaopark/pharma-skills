core6_source_dependency_handoff <- function(root_dir) {
  audit_path <- file.path(root_dir, "intermediate", "01_understanding_data",
                          "source_dependency_audit.csv")
  empty <- data.frame(
    dependency_id = character(),
    required = logical(),
    status = character(),
    reason = character(),
    review_gate = character(),
    source_file = character(),
    handoff_status = character(),
    decision_lane = character(),
    owner = character(),
    next_action = character(),
    stringsAsFactors = FALSE
  )
  audit <- core6_read_csv(audit_path)
  if (is.null(audit) || !nrow(audit)) return(empty)

  required <- if ("required" %in% names(audit)) {
    x <- audit$required
    if (is.logical(x)) {
      x
    } else {
      tolower(as.character(x)) %in% c("true", "t", "1", "yes", "y")
    }
  } else {
    rep(FALSE, nrow(audit))
  }
  status <- if ("status" %in% names(audit)) as.character(audit$status) else rep("", nrow(audit))
  reason <- if ("reason" %in% names(audit)) as.character(audit$reason) else rep("", nrow(audit))
  review_gate <- if ("review_gate" %in% names(audit)) as.character(audit$review_gate) else rep("", nrow(audit))
  dependency_id <- if ("dependency_id" %in% names(audit)) {
    as.character(audit$dependency_id)
  } else {
    paste0("dependency_", seq_len(nrow(audit)))
  }

  blocked_required <- required & status %in% c("blocked", "failed", "missing", "unresolved")
  handoff_status <- ifelse(blocked_required, "blocked_required_dependency",
                           ifelse(status == "available", "available_dependency",
                                  "dependency_review_required"))
  decision_lane <- ifelse(blocked_required, "must_resolve_before_downstream",
                          "document_for_traceability")
  owner <- ifelse(blocked_required, "AZ source-data owner; workflow/statistics",
                  "workflow")
  next_action <- ifelse(
    blocked_required,
    paste0("Request or resolve required source dependency `", dependency_id,
           "` before claiming reference Results reproduction."),
    paste0("Keep source dependency `", dependency_id,
           "` in the review package for traceability.")
  )

  data.frame(
    dependency_id = dependency_id,
    required = required,
    status = status,
    reason = reason,
    review_gate = review_gate,
    source_file = core6_rel_path(audit_path, root_dir),
    handoff_status = handoff_status,
    decision_lane = decision_lane,
    owner = owner,
    next_action = next_action,
    stringsAsFactors = FALSE
  )
}
