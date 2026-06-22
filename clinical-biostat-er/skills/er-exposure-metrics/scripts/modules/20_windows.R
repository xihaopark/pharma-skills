# ---- Section B. Window construction --------------------------------------

# Per-subject event time given a row filter expression. The agent supplies
# the filter (e.g., ~ TTP == 3, ~ AECRS == "Y", ~ PARAMCD == "OS_EVENT").
# The primitive does not know what an event is.
event_time_per_subject <- function(records, id_col, time_col, filter_expr) {
  validate_columns(records, c(id_col, time_col), "event_time_per_subject")
  if (!inherits(filter_expr, "formula")) {
    stop("filter_expr must be a one-sided formula like ~ TTP == 3", call. = FALSE)
  }
  pred <- eval(filter_expr[[2]], envir = records, enclos = parent.frame())
  if (!is.logical(pred)) {
    stop("filter_expr must evaluate to a logical vector", call. = FALSE)
  }
  hit <- records[!is.na(pred) & pred, , drop = FALSE]
  if (nrow(hit) == 0) {
    return(data.frame(id = character(), event_time = numeric(), stringsAsFactors = FALSE))
  }
  agg <- stats::aggregate(hit[[time_col]], by = list(id = hit[[id_col]]),
                          FUN = function(x) max(x, na.rm = TRUE))
  data.frame(id = as.character(agg$id), event_time = as.numeric(agg$x), stringsAsFactors = FALSE)
}

# Per-subject window from an event-time table. lag = hours before event;
# lead = hours after event. lag = Inf opens the window to baseline.
compose_window <- function(event_time_table, lag, lead) {
  validate_columns(event_time_table, c("id", "event_time"), "compose_window")
  data.frame(
    id      = as.character(event_time_table$id),
    t_start = ifelse(is.infinite(lag), -Inf, event_time_table$event_time - lag),
    t_end   = event_time_table$event_time + lead,
    stringsAsFactors = FALSE
  )
}

# Constant window applied to every subject in subject_index.
compose_fixed_window <- function(subject_index, t_start, t_end, id_col = "subject_id") {
  validate_columns(subject_index, id_col, "compose_fixed_window")
  data.frame(
    id      = as.character(subject_index[[id_col]]),
    t_start = rep(t_start, nrow(subject_index)),
    t_end   = rep(t_end,   nrow(subject_index)),
    stringsAsFactors = FALSE
  )
}
