# Comparator implementations for the simulation study.
# Nearest-neighbor comparators retain the vendored dsmatch M=1 algorithms.
# Their ordinary bootstrap sample variance uses B-1, unlike WDSM's B divisor.
comparator_final_dependencies <- c("Matching", "boot", "MatchIt", "optmatch",
                                   "marginaleffects", "sandwich")

comparator_final_check_dependencies <- function() {
  missing <- comparator_final_dependencies[!vapply(comparator_final_dependencies,
    requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Missing comparator packages: ", paste(missing, collapse = ", "))
  invisible(TRUE)
}

.comparator_final_vendor <- function(repo, B, ledger) {
  # The private environment isolates instrumentation and vendor function names.
  # No installed package or vendored source file is modified.
  env <- new.env(parent = asNamespace("stats"))
  files <- c("is.lp.R", "is.ps.R", "is.pg.R", "dsmatchATE.R", "dsmatchATT.R",
             "estforboot_dsATE.R", "estforboot_psATE.R", "estforboot_pgATE.R",
             "estforboot_dsATT.R", "estforboot_psATT.R", "estforboot_pgATT.R")
  for (file in files) {
    path <- file.path(repo, "R", "dsmatch", file)
    if (!file.exists(path)) stop("Missing vendored comparator source: ", path)
    sys.source(path, envir = env)
  }
  env$glm <- function(...) {
    fit <- stats::glm(...)
    ledger$glm_fits <- ledger$glm_fits + 1L
    if (!isTRUE(fit$converged) || any(!is.finite(fit$coefficients)) ||
        any(!is.finite(fit$fitted.values))) {
      stop("Comparator nuisance GLM did not return a converged, finite fit")
    }
    if (fit$family$family %in% c("binomial", "quasibinomial") &&
        any(fit$fitted.values <= 0 | fit$fitted.values >= 1)) {
      stop("Comparator nuisance GLM returned boundary probabilities")
    }
    fit
  }
  env$lm <- function(...) {
    fit <- stats::lm(...)
    ledger$lm_fits <- ledger$lm_fits + 1L
    ledger$rank_deficient_lm <- ledger$rank_deficient_lm +
      as.integer(anyNA(fit$coefficients))
    if (any(!is.finite(fit$fitted.values)) || any(!is.finite(fit$residuals))) {
      stop("Comparator outcome regression returned nonfinite fitted values")
    }
    fit
  }
  # All active ATE/ATT branches call var only on the B x 1 bootstrap matrix.
  # Validate all draws before na.rm=TRUE could discard nonfinite values.
  env$var <- function(x, y = NULL, na.rm = FALSE, use) {
    if (!is.null(y) || !is.matrix(x) || nrow(x) != B || ncol(x) != 1L) {
      stop("Unexpected comparator bootstrap variance input")
    }
    if (any(!is.finite(x))) stop("Comparator bootstrap contains nonfinite draws")
    ledger$bootstrap_draws <- as.numeric(x[, 1L])
    stats::var(x, na.rm = FALSE)
  }
  env
}

compare_final <- function(data, survey_weight = data$survey_weight,
                          method = c("DSM", "PGM", "PSM", "SWPSM"),
                          estimand = c("PATE", "PATT"), M = 1L, B = 200L,
                          alpha = 0.05,
                          sampling_design = c("retrospective", "prospective"),
                          use_interaction_ps = TRUE, use_interaction_pg = TRUE,
                          repo = ".") {
  method <- match.arg(method)
  estimand <- match.arg(estimand)
  sampling_design <- match.arg(tolower(sampling_design), c("retrospective", "prospective"))
  if (length(M) != 1L || !is.finite(M) || M != 1L) {
    stop("Comparators retain M=1 nearest-neighbor matching; SWPSM uses full matching")
  }
  if (length(B) != 1L || !is.finite(B) || B < 2 || B != as.integer(B)) {
    stop("B must be an integer at least 2")
  }
  if (length(alpha) != 1L || !is.finite(alpha) || alpha <= 0 || alpha >= 1) {
    stop("alpha must be strictly between zero and one")
  }
  for (flag in list(use_interaction_ps, use_interaction_pg)) {
    if (!is.logical(flag) || length(flag) != 1L || is.na(flag)) {
      stop("Model specification flags must be single nonmissing logical values")
    }
  }
  required <- c("Y", "A", paste0("X", 1:6))
  if (!is.data.frame(data) || !all(required %in% names(data)) ||
      !all(vapply(data[required], is.numeric, logical(1))) ||
      any(!is.finite(as.matrix(data[required]))) ||
      !all(data$A %in% 0:1) || length(unique(data$A)) != 2L) {
    stop("data must contain finite numeric Y, binary A with both arms, and X1 through X6")
  }
  if (length(survey_weight) != nrow(data) || !is.numeric(survey_weight) ||
      any(!is.finite(survey_weight) | survey_weight <= 0)) {
    stop("survey_weight must have one positive finite value per observation")
  }
  comparator_final_check_dependencies()
  warnings_seen <- character()
  ledger <- new.env(parent = emptyenv())
  ledger$glm_fits <- ledger$lm_fits <- ledger$rank_deficient_lm <- 0L
  ledger$bootstrap_draws <- numeric()
  result <- withCallingHandlers({
    if (method != "SWPSM") {
      env <- .comparator_final_vendor(repo, as.integer(B), ledger)
      X <- as.matrix(data[paste0("X", 1:6)])
      X_ps <- if (use_interaction_ps) cbind(X, X1X2 = X[, 1L] * X[, 2L]) else X
      X_pg <- if (use_interaction_pg) cbind(X, X1X2 = X[, 1L] * X[, 2L]) else X
      method_code <- switch(method, DSM = "dsm", PGM = "pg", PSM = "ps")
      args <- list(Y = data$Y, X = if (method == "PGM") X_pg else X_ps,
                   A = data$A, method = method_code, cov.balance = FALSE,
                   varest = TRUE, boots = as.integer(B), mc = FALSE, ncpus = 1L)
      if (method %in% c("DSM", "PSM")) args$model.ps <- "logit"
      if (method == "DSM") {
        args$model.pg <- "linpred"
        args$lp.pg <- X_pg
      } else if (method == "PGM") args$model.pg <- "glm"
      fit <- do.call(env[[if (estimand == "PATE") "dsmatchATE" else "dsmatchATT"]], args)
      estimate <- as.numeric(fit[[switch(method, DSM = "est.ds", PGM = "est.pg", PSM = "est.ps")]])
      variance <- as.numeric(fit$bootvar)
      if (length(ledger$bootstrap_draws) != B) stop("Comparator did not expose all requested bootstrap draws")
      list(estimate = estimate, variance = variance,
           variance_method = "vendored_dsmatch_iid_bootstrap_sample_variance_B_minus_1",
           variance_divisor = as.integer(B - 1L),
           bootstrap_requested = as.integer(B), bootstrap_successful = length(ledger$bootstrap_draws),
           matching = "nearest_neighbor_with_replacement_M1",
           outcome_model = if (method == "PSM") "vendor_cubic_PS_variance_regression" else
             if (use_interaction_pg) "main_effects_plus_X1_X2_interaction" else "main_effects")
    } else {
      df <- data[required]
      df$sw <- survey_weight * nrow(data) / sum(survey_weight)
      ps_formula <- if (use_interaction_ps) A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 else
        A ~ X1 + X2 + X3 + X4 + X5 + X6
      # Use mean-one survey weights and validate MatchIt's stored GLM.
      matched <- MatchIt::matchit(ps_formula, data = df, method = "full",
        distance = "glm", link = "logit", estimand = if (estimand == "PATE") "ATE" else "ATT",
        s.weights = df$sw, verbose = FALSE, include.obj = TRUE)
      ps_fit <- matched$model
      if (is.null(ps_fit) && inherits(matched$obj, "glm")) ps_fit <- matched$obj
      if (is.null(ps_fit) || !inherits(ps_fit, "glm")) stop("MatchIt did not retain the propensity GLM for validation")
      ledger$glm_fits <- 1L
      if (!isTRUE(ps_fit$converged) || any(!is.finite(ps_fit$coefficients)) ||
          any(!is.finite(matched$distance)) || any(matched$distance <= 0 | matched$distance >= 1)) {
        stop("SWPSM propensity fit did not return converged finite interior probabilities")
      }
      # match.data is available in MatchIt 4.6.x.
      md <- MatchIt::match.data(matched, data = df, include.s.weights = TRUE)
      if (nrow(md) != nrow(df) || any(!is.finite(md$weights) | md$weights <= 0) ||
          anyNA(md$subclass)) stop("SWPSM full matching did not retain every observation with positive weight")
      outcome_formula <- Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2)
      outcome_fit <- stats::lm(outcome_formula, data = md, weights = weights)
      ledger$lm_fits <- 1L
      if (any(!is.finite(outcome_fit$coefficients))) stop("SWPSM outcome model is rank deficient or nonfinite")
      target <- if (estimand == "PATE") md else md[md$A == 1L, , drop = FALSE]
      contrast <- marginaleffects::avg_comparisons(outcome_fit, newdata = target,
        variables = "A", vcov = ~subclass, wts = "sw", conf_level = 1 - alpha)
      list(estimate = as.numeric(contrast$estimate), variance = as.numeric(contrast$std.error)^2,
           variance_method = "full_matching_subclass_cluster_sandwich_delta_method",
           variance_divisor = NA_integer_, bootstrap_requested = 0L, bootstrap_successful = 0L,
           matching = "optimal_full_matching", outcome_model = "always_correct_treatment_interacted_main_effects_plus_X1_X2",
           subclass_count = length(unique(md$subclass)),
           ps_iterations = ps_fit$iter, min_ps = min(matched$distance), max_ps = max(matched$distance))
    }
  }, warning = function(w) {
    # Warning text is retained in the result; no warning changes a failed fit
    # into a successful fit. GLM convergence and every bootstrap draw are checked.
    warnings_seen <<- c(warnings_seen, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  if (length(result$estimate) != 1L || length(result$variance) != 1L ||
      !is.finite(result$estimate) || !is.finite(result$variance) || result$variance < 0) {
    stop("Comparator returned an invalid scalar estimate or variance")
  }
  se <- sqrt(result$variance)
  z <- stats::qnorm(1 - alpha / 2)
  list(estimate = result$estimate, se = se,
       ci_lower = result$estimate - z * se, ci_upper = result$estimate + z * se,
       variance = result$variance, variance_method = result$variance_method,
       diagnostics = c(result[setdiff(names(result), c("estimate", "variance", "variance_method"))],
         list(method = method, estimand = estimand, sampling_design = sampling_design,
              n = nrow(data), n_treated = sum(data$A == 1L),
              glm_fits_checked = ledger$glm_fits, lm_fits_checked = ledger$lm_fits,
              rank_deficient_lm = ledger$rank_deficient_lm,
              warnings = unique(warnings_seen),
              package_versions = vapply(comparator_final_dependencies,
                function(p) as.character(utils::packageVersion(p)), character(1)),
              bootstrap_draws = ledger$bootstrap_draws)))
}
