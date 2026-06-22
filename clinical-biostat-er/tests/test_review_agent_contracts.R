args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

core_skills <- c(
  "er-understanding-data" = "intermediate/01_understanding_data/core1_review_findings.csv",
  "er-individual-pk-pd-review" = "intermediate/02_individual_pk_pd_review/core2_review_findings.csv",
  "er-exposure-metrics" = "intermediate/03_exposure_metrics/core3_review_findings.csv",
  "er-exposure-response-exploration" = "intermediate/04_exposure_response_exploration/core4_review_findings.csv",
  "er-statistical-modeling" = "intermediate/05_statistical_modeling/core5_review_findings.csv",
  "er-reporting-and-review" = "intermediate/06_reporting_review/core6_review_findings.csv"
)

expected_schema <- "schema: [challenge, finding, severity, cited_artifact, cited_row, review_gate, recommended_action]"

for (skill in names(core_skills)) {
  agent_path <- file.path("skills", skill, "agents", "review.yaml")
  skill_path <- file.path("skills", skill, "SKILL.md")

  if (!file.exists(agent_path)) {
    stop("Missing review agent contract: ", agent_path, call. = FALSE)
  }
  if (!file.exists(skill_path)) {
    stop("Missing SKILL.md: ", skill_path, call. = FALSE)
  }

  agent_lines <- readLines(agent_path, warn = FALSE)
  agent_text <- paste(agent_lines, collapse = "\n")
  skill_text <- paste(readLines(skill_path, warn = FALSE), collapse = "\n")

  required_tokens <- c(
    "interface:",
    "review:",
    "reads:",
    "challenges:",
    "output:",
    expected_schema,
    unname(core_skills[[skill]])
  )
  missing_tokens <- required_tokens[!vapply(required_tokens, grepl, logical(1), x = agent_text, fixed = TRUE)]
  if (length(missing_tokens)) {
    stop(
      "Review agent contract missing required token(s) for ", skill, ": ",
      paste(missing_tokens, collapse = ", "),
      call. = FALSE
    )
  }

  deferred_review_agent_pattern <- "agents/review.yaml[^\\n.]*deferred|deferred[^\\n.]*agents/review.yaml"
  if (grepl(deferred_review_agent_pattern, skill_text)) {
    stop("SKILL.md still marks review agent as deferred: ", skill_path, call. = FALSE)
  }

  if (!grepl("agents/review.yaml", skill_text, fixed = TRUE)) {
    stop("SKILL.md does not reference agents/review.yaml: ", skill_path, call. = FALSE)
  }
}

cat("Review agent contract tests passed\n")
