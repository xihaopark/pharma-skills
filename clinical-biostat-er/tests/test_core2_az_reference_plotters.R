args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

source("skills/er-individual-pk-pd-review/scripts/er_individual_pk_pd_review_helpers.R")

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

corpus <- file.path(
  bundle_root,
  "skills", "er-individual-pk-pd-review", "code_corpus",
  "az_mock01_core2_reference_plotters.R"
)
assert(file.exists(corpus), "AZ Core2 direct plotting corpus is missing")
corpus_text <- paste(readLines(corpus, warn = FALSE), collapse = "\n")
for (pattern in c(
  "create_individual_pk_plot <- function",
  "create_swimmer_plot <- function",
  "facet_wrap2(~ID",
  "Time after first dose of DrugA (Weeks)",
  "scale_y_discrete(labels = mask_id_labels)"
)) {
  assert(grepl(pattern, corpus_text, fixed = TRUE),
         paste("AZ direct plotting corpus missing copied pattern:", pattern))
}

ids <- c("mock0002", "mock0003", "mock0001")
pk_profile <- data.frame(
  ID = rep(ids, each = 3),
  TIME = rep(c(0, 168, 336), times = 3),
  AVAL = c(12, 90, 18, 8, 75, 15, 6, 60, 12),
  PARAMREP = "Analyte1, Intact, Quant (ug/mL)",
  PARAMCD = "L01EI4U2",
  Cohort_Label = "DrugA Low Dose",
  LLOQ = 0.1,
  stringsAsFactors = FALSE
)
dose_records <- data.frame(
  ID = c(ids, ids, ids),
  STTIME = c(0, 0, 0, 1, 1, 1, 168, 168, 168),
  ENDTIME = c(0.5, 0.5, 0.5, 500, 500, 500, 168.5, 168.5, 168.5),
  EXTRT = c(rep("DrugA", 3), rep("DrugB", 3), rep("DrugA", 3)),
  EXTRT_GROUP = c("Study drug", "Study drug", "Background treatment",
                  "Study drug", "Study drug", "Background treatment",
                  "Background treatment", "Background treatment", "Study drug"),
  EXDOSE = c(4, 4, 4, 1, 1, 1, 3, 3, 3),
  ACTDOSE = c(4, 4, 4, NA, NA, NA, 3, 3, 3),
  Cohort = "DrugA Low Dose",
  Cohort_Label = "DrugA Low Dose",
  stringsAsFactors = FALSE
)
response_status <- data.frame(
  ID = ids,
  Responder = c("Non-responder", "Unconfirmed\nResponder", "Responder"),
  stringsAsFactors = FALSE
)
response_events <- data.frame(
  ID = ids,
  STTIME = c(336, 400, 504),
  adapter_status = "candidate",
  stringsAsFactors = FALSE
)
safety_events <- data.frame(
  ID = c(ids, ids),
  STTIME = c(200, 210, 220, 250, 260, 270),
  event_type = c("grade3plus_ae", "grade3plus_ae",
                 "grade3plus_ae", "Adjudicated ILD",
                 "Not-adjudicated ILD", "Adjudicated ILD"),
  AEDECOD = c("Stomatitis", "Stomatitis", "Stomatitis",
              "Pneumonitis", "Pneumonitis", "Pneumonitis"),
  AETOXGR = c(3, 3, 3, NA, NA, NA),
  adapter_status = "candidate",
  stringsAsFactors = FALSE
)
frames <- core2_prepare_az_reference_frames(
  pk_profile, dose_records, response_status, response_events, safety_events
)
expected_order <- c("mock0001", "mock0003", "mock0002")
assert(identical(core2_az_subject_order(frames$dat_ex2, "DrugA Low Dose"),
                 expected_order),
       "AZ reference adapter should order IDs by Responder, Unconfirmed Responder, Non-responder")
assert(identical(levels(frames$dat_ex2$ID), expected_order),
       "AZ reference adapter should factor dat_ex2 IDs in AZ facet order")

out_dir <- tempfile("core2_az_direct_")
dir.create(out_dir)
individual_out <- file.path(out_dir, "individual.png")
spec <- list(
  plot_class = "individual_profile",
  treatment_group = "DrugA Low Dose",
  profile_analyte = "Analyte1, Intact, Quant (ug/mL)",
  title = "Individual PK data (intact ADC) for patients in Low Dose dose group",
  width = 8,
  height = 5
)
p <- core2_render_az_reference_plot(
  spec = spec,
  pk_profile = pk_profile,
  dose_records = dose_records,
  response_status = response_status,
  response_events = response_events,
  safety_events = safety_events,
  output_path = individual_out,
  root_dir = bundle_root
)
assert(file.exists(individual_out) && file.info(individual_out)$size > 0,
       "AZ direct individual PK renderer did not emit a PNG")
assert(identical(p$labels$x, "Time after first dose of DrugA (Weeks)"),
       "AZ direct individual PK renderer should preserve AZ x-axis label")
assert(identical(p$labels$y, "Analyte1, Intact, Quant (ug/mL)"),
       "AZ direct individual PK renderer should preserve AZ y-axis label")
has_y_log <- any(vapply(p$scales$scales, function(scale) {
  any(scale$aesthetics %in% "y") &&
    grepl("log", paste(class(scale), collapse = " "), ignore.case = TRUE)
}, logical(1)))
assert(!has_y_log, "AZ direct individual PK renderer must not add a log y-axis")
assert(identical(unname(core2_az_mask_id_labels("mock0001")), "mock****"),
       "AZ direct ID masking should preserve the original mask rule")
assert(identical(attr(p, "az_reference_origin"), "az_rmd_direct_extract_tool"),
       "AZ direct renderer should mark direct-extract origin")

individual_audit <- core2_az_reference_layer_audit(frames, spec)
assert(all(c("subject_order", "pk_point", "response_marker",
             "dose_marker") %in% individual_audit$layer),
       "AZ individual PK audit should expose subject, strip, PK, response, and dose layers")
strip_rows <- individual_audit[individual_audit$layer == "subject_order", , drop = FALSE]
assert(identical(strip_rows$subject_id, expected_order),
       "AZ individual PK audit should preserve subject order")
assert(identical(strip_rows$strip_fill, c("#BF78A6", "#FFE6F7", "#F2F2F2")),
       "AZ individual PK audit should preserve AZ responder strip colors")

swim <- core2_az_create_swimmer_plot(frames, "DrugA Low Dose",
                                     "Dosing of Low Dose group",
                                     root_dir = bundle_root)
assert(identical(swim$labels$x, "Time after first dose of DrugA (Weeks)"),
       "AZ direct swimmer renderer should preserve AZ x-axis label")
assert(identical(swim$labels$y, "Subject ID"),
       "AZ direct swimmer renderer should preserve AZ y-axis label")
swim_audit <- core2_az_reference_layer_audit(
  frames,
  list(plot_class = "swimmer_event_overlay",
       treatment_group = "DrugA Low Dose",
       reference_figure = "swimmer_low_dose.png")
)
assert(all(c("drugb_interval", "dose_arrow", "response_star") %in% swim_audit$layer),
       "AZ swimmer audit should expose interval, dose-arrow, and response-star layers")
assert(any(swim_audit$layer == "drugb_interval" & swim_audit$x == 1 / 168),
       "AZ swimmer audit should express DrugB intervals in weeks from STTIME/168")

cat("Core2 AZ direct reference plotter tests passed\n")
