spec_role_from_class <- function(class, dataset) {
  d <- gsub("[^a-z0-9]+", "", tolower(as.character(dataset)))
  cls <- toupper(as.character(class %||% ""))
  if (cls == "ADSL") return("population")
  if (d %in% c("adex", "ex"))                                       return("dosing_exposure")
  if (d %in% c("adpc", "pc"))                                       return("pk_ck_concentration")
  if (d %in% c("adpp", "pp"))                                       return("pk_ck_parameters")
  if (d %in% c("adrs", "adrsas", "adresp", "adeff", "adtr", "adqs"))
                                                                    return("efficacy_response")
  if (d %in% c("adae", "adce", "adceas"))                           return("safety")
  if (d %in% c("adlb", "advs", "adeg", "adcv"))                     return("safety_assessment")
  if (d %in% c("adtte"))                                            return("tte")
  if (d %in% c("adis"))                                             return("ada")
  "unknown"
}
