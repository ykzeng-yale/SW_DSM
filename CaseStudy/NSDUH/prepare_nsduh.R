nsduh_case_directory <- function(run_root) {
  file.path(run_root, "CaseStudy", "NSDUH")
}

nsduh_prepare_data <- function(run_root) {
  case_directory <- nsduh_case_directory(run_root)
  input_path <- Sys.getenv("NSDUH_INPUT")
  if (!nzchar(input_path)) stop("Set NSDUH_INPUT to the reconstructed NSDUH analysis file")
  if (!file.exists(input_path)) stop("NSDUH source data are not available: ", input_path)
  analytic_data <- as.data.frame(readRDS(input_path))
  required <- c("IRSEX", "NEWRACE2", "IRFAMIN3", "COUTYP4", "CIGEVER",
                "IRALCAGE", "AGE3", "AMIPY", "SMIPY", "early_mj_use", "ANALWT2_C")
  missing_columns <- setdiff(required, names(analytic_data))
  if (length(missing_columns)) stop("Missing source columns: ", paste(missing_columns, collapse = ", "))

  # These transformations and the shared two-outcome complete-case filter are
  # identical to the original script. No extra covariate exclusions are made.
  comparison_data <- analytic_data
  comparison_data$male <- ifelse(comparison_data$IRSEX == 1, 1, 0)
  comparison_data$white <- ifelse(comparison_data$NEWRACE2 == 1, 1, 0)
  comparison_data$black <- ifelse(comparison_data$NEWRACE2 == 2, 1, 0)
  comparison_data$hispanic <- ifelse(comparison_data$NEWRACE2 == 7, 1, 0)
  comparison_data$income_low <- ifelse(comparison_data$IRFAMIN3 <= 2, 1, 0)
  comparison_data$income_medium <- ifelse(comparison_data$IRFAMIN3 <= 4 & comparison_data$IRFAMIN3 > 2, 1, 0)
  comparison_data$income_high <- ifelse(comparison_data$IRFAMIN3 <= 6 & comparison_data$IRFAMIN3 > 4, 1, 0)
  comparison_data$large_metro <- ifelse(comparison_data$COUTYP4 == 1, 1, 0)
  comparison_data$small_metro <- ifelse(comparison_data$COUTYP4 == 2, 1, 0)
  comparison_data$ever_cigarette <- ifelse(comparison_data$CIGEVER == 1, 1, 0)
  comparison_data$early_alcohol <- ifelse(comparison_data$IRALCAGE < 15 & comparison_data$IRALCAGE < 900, 1, 0)
  comparison_data$early_alcohol <- ifelse(is.na(comparison_data$early_alcohol), 0, comparison_data$early_alcohol)
  comparison_data$age_21_23 <- ifelse(comparison_data$AGE3 == 5, 1, 0)
  comparison_data$age_24_25 <- ifelse(comparison_data$AGE3 == 6, 1, 0)
  comparison_data$age_26_29 <- ifelse(comparison_data$AGE3 == 7, 1, 0)
  keep <- !is.na(comparison_data$AMIPY) & !is.na(comparison_data$SMIPY) &
          !is.na(comparison_data$early_mj_use) & !is.na(comparison_data$ANALWT2_C)
  comparison_data <- comparison_data[keep, , drop = FALSE]
  covariates <- c("male", "white", "black", "hispanic", "income_low",
                  "income_medium", "income_high", "large_metro", "small_metro",
                  "early_alcohol", "ever_cigarette", "age_21_23", "age_24_25", "age_26_29")
  missing_covariates <- vapply(comparison_data[covariates], function(x) sum(is.na(x)), integer(1))
  if (any(missing_covariates)) stop("Source-model covariates contain missing values; do not silently alter the sample.")
  A <- comparison_data$early_mj_use
  w <- comparison_data$ANALWT2_C
  if (!all(A %in% c(0, 1))) stop("Treatment is not binary 0/1.")
  if (!all(is.finite(w) & w > 0)) stop("Survey weights must be finite and positive.")
  for (outcome in c("AMIPY", "SMIPY")) {
    if (!all(comparison_data[[outcome]] %in% c(0, 1))) stop(outcome, " is not binary 0/1.")
  }
  comparison_data$A <- A
  terms <- paste(covariates, collapse = " + ")
  diagnostics <- list(
    input_path = input_path,
    input_md5 = unname(tools::md5sum(input_path)),
    input_rows = nrow(analytic_data), excluded_rows = sum(!keep),
    n = nrow(comparison_data), n_treated = sum(A == 1), n_control = sum(A == 0),
    represented_population = sum(w), weighted_treatment_prevalence = sum(w * A) / sum(w),
    weights = summary(w), weight_effective_n = sum(w)^2 / sum(w^2),
    covariate_missing = missing_covariates,
    covariate_ranges = lapply(comparison_data[covariates], range),
    duplicated_covariate_rows = sum(duplicated(comparison_data[covariates])),
    outcome_by_arm = lapply(c("AMIPY", "SMIPY"), function(outcome) {
      data.frame(outcome = outcome, arm = 0:1,
                 n = vapply(0:1, function(z) sum(A == z), integer(1)),
                 cases = vapply(0:1, function(z) sum(comparison_data[[outcome]][A == z]), numeric(1)),
                 weighted_mean = vapply(0:1, function(z) weighted.mean(comparison_data[[outcome]][A == z], w[A == z]), numeric(1)))
    })
  )
  list(data = comparison_data, covariates = covariates, diagnostics = diagnostics,
       ps_formula = as.formula(paste("A ~", terms)),
       pgs_formula = as.formula(paste("Y ~", terms)), case_directory = case_directory)
}
