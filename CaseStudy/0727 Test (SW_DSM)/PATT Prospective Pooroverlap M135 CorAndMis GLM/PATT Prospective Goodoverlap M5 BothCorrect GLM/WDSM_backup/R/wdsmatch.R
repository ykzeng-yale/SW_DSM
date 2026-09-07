#' Weighted Double Score Matching for Survey Data
#'
#' Main function for weighted double score matching (WDSM) that estimates 
#' population-level causal effects from complex survey data. Supports both 
#' PATE and PATT estimation under prospective and retrospective sampling designs.
#'
#' @param Y Outcome as numeric vector.
#' @param X Covariates as numeric vector or matrix.
#' @param A Treatment assignment as numeric vector (1 = treatment, 0 = control).
#' @param weights Survey weights. For prospective sampling, a single numeric vector.
#'        For retrospective sampling, can be either:
#'        - A list with elements 'weights0' and 'weights1' for control and treatment weights
#'        - A matrix with two columns (control weights, treatment weights)
#' @param estimand Target estimand: "PATE" or "PATT".
#' @param sampling Sampling design: "prospective" or "retrospective".
#' @param method Matching method: "dsm" (double score), "ps" (propensity only), 
#'        "pg" (prognostic only), "cov" (covariates), or "all" (compare all methods).
#' @param model.ps Model for propensity score: "logit", "probit", "linpred", or NULL if ps provided.
#' @param ps Propensity scores if pre-computed (optional).
#' @param lp.ps Linear predictors for propensity score if model.ps = "linpred".
#' @param model.pg Model for prognostic score: "glm", "glm_logit", "glm_probit", 
#'        "linpred", or NULL if pg provided.
#' @param pg Prognostic scores if pre-computed (optional).
#' @param lp.pg Linear predictors for prognostic score if model.pg = "linpred".
#' @param M Number of matches per unit (default = 3).
#' @param bias.correct Whether to apply bias correction (default = TRUE).
#' @param varest Whether to estimate variance (default = TRUE).
#' @param boots Number of bootstrap replicates if varest = TRUE (default = 100).
#' @param mc Whether to use parallel processing for bootstrap (default = FALSE).
#' @param ncpus Number of cores for parallel processing if mc = TRUE.
#' @param cov.balance Whether to report covariate balance (default = FALSE).
#' @param ... Additional arguments passed to underlying functions.
#'
#' @return An object of class "wdsmatch" containing:
#'   \item{est.dsm}{Estimate using double score matching}
#'   \item{est.ps}{Estimate using propensity score only (if requested)}
#'   \item{est.pg}{Estimate using prognostic score only (if requested)}
#'   \item{est.cov}{Estimate using covariate matching (if requested)}
#'   \item{bootvar}{Bootstrap variance estimate}
#'   \item{bootq1}{Bootstrap 2.5% quantile}
#'   \item{bootq2}{Bootstrap 97.5% quantile}
#'   \item{ci.lower}{95% confidence interval lower bound}
#'   \item{ci.upper}{95% confidence interval upper bound}
#'   \item{balance}{Covariate balance results if requested}
#'   \item{estimand}{Target estimand (PATE or PATT)}
#'   \item{sampling}{Sampling design (prospective or retrospective)}
#'   \item{n}{Total sample size}
#'   \item{n1}{Number of treated units}
#'   \item{n0}{Number of control units}
#'
#' @examples
#' \dontrun{
#' # Example with prospective sampling for PATE
#' data(lalonde)
#' Y <- lalonde$re78
#' X <- lalonde[, c("age", "educ", "black", "hisp", "married", "nodegr", "re74", "re75")]
#' A <- lalonde$treat
#' 
#' # Simulate survey weights (in practice, use actual survey weights)
#' weights <- runif(length(Y), 0.5, 2)
#' 
#' # Estimate PATE with prospective sampling
#' result.pate <- wdsmatch(Y, X, A, weights, 
#'                         estimand = "PATE", 
#'                         sampling = "prospective",
#'                         method = "dsm")
#' print(result.pate)
#' 
#' # Estimate PATT with retrospective sampling
#' weights0 <- runif(length(Y), 0.5, 2)
#' weights1 <- runif(length(Y), 0.5, 2.5)
#' weights.retro <- list(weights0 = weights0, weights1 = weights1)
#' 
#' result.patt <- wdsmatch(Y, X, A, weights.retro,
#'                         estimand = "PATT",
#'                         sampling = "retrospective",
#'                         method = "dsm")
#' print(result.patt)
#' }
#'
#' @export
wdsmatch <- function(Y, X, A, weights,
                     estimand = c("PATE", "PATT"),
                     sampling = c("prospective", "retrospective"),
                     method = c("dsm", "ps", "pg", "cov", "all"),
                     model.ps = "logit", ps = NULL, lp.ps = NULL,
                     model.pg = "glm", pg = NULL, lp.pg = NULL,
                     M = 3, bias.correct = TRUE,
                     varest = TRUE, boots = 100, mc = FALSE, ncpus = 4,
                     cov.balance = FALSE, ...) {
  
  # Match arguments
  estimand <- match.arg(estimand)
  sampling <- match.arg(sampling)
  method <- match.arg(method)
  
  # Process weights based on sampling design
  if (sampling == "prospective") {
    if (is.list(weights) || is.matrix(weights)) {
      stop("For prospective sampling, weights should be a single numeric vector")
    }
    weights.pro <- weights
  } else {  # retrospective
    if (is.list(weights)) {
      if (!all(c("weights0", "weights1") %in% names(weights))) {
        stop("For retrospective sampling, list must contain 'weights0' and 'weights1'")
      }
      weights0 <- weights$weights0
      weights1 <- weights$weights1
    } else if (is.matrix(weights)) {
      if (ncol(weights) != 2) {
        stop("For retrospective sampling, weight matrix must have 2 columns")
      }
      weights0 <- weights[, 1]
      weights1 <- weights[, 2]
    } else {
      stop("For retrospective sampling, weights must be a list or 2-column matrix")
    }
  }
  
  # Call appropriate function based on estimand and sampling
  if (estimand == "PATE") {
    if (sampling == "prospective") {
      result <- wdsmatchPATE_prospective(Y, X, A, weights.pro,
                                         method = method,
                                         model.ps = model.ps, ps = ps, lp.ps = lp.ps,
                                         model.pg = model.pg, pg = pg, lp.pg = lp.pg,
                                         M = M, bias.correct = bias.correct,
                                         varest = varest, boots = boots,
                                         mc = mc, ncpus = ncpus,
                                         cov.balance = cov.balance, ...)
    } else {
      result <- wdsmatchPATE_retrospective(Y, X, A, weights0, weights1,
                                           method = method,
                                           model.ps = model.ps, ps = ps, lp.ps = lp.ps,
                                           model.pg = model.pg, pg = pg, lp.pg = lp.pg,
                                           M = M, bias.correct = bias.correct,
                                           varest = varest, boots = boots,
                                           mc = mc, ncpus = ncpus,
                                           cov.balance = cov.balance, ...)
    }
  } else {  # PATT
    if (sampling == "prospective") {
      result <- wdsmatchPATT_prospective(Y, X, A, weights.pro,
                                         method = method,
                                         model.ps = model.ps, ps = ps, lp.ps = lp.ps,
                                         model.pg = model.pg, pg = pg, lp.pg = lp.pg,
                                         M = M, bias.correct = bias.correct,
                                         varest = varest, boots = boots,
                                         mc = mc, ncpus = ncpus,
                                         cov.balance = cov.balance, ...)
    } else {
      result <- wdsmatchPATT_retrospective(Y, X, A, weights0, weights1,
                                           method = method,
                                           model.ps = model.ps, ps = ps, lp.ps = lp.ps,
                                           model.pg = model.pg, pg = pg, lp.pg = lp.pg,
                                           M = M, bias.correct = bias.correct,
                                           varest = varest, boots = boots,
                                           mc = mc, ncpus = ncpus,
                                           cov.balance = cov.balance, ...)
    }
  }
  
  # Add confidence intervals
  if (varest && !is.na(result$bootvar)) {
    result$ci.lower <- result$est.dsm - 1.96 * sqrt(result$bootvar)
    result$ci.upper <- result$est.dsm + 1.96 * sqrt(result$bootvar)
  } else {
    result$ci.lower <- NA
    result$ci.upper <- NA
  }
  
  result$estimand <- estimand
  
  return(result)
}


#' Print method for wdsmatch objects
#'
#' @param x A wdsmatch object
#' @param ... Additional arguments (ignored)
#' @export
print.wdsmatch <- function(x, ...) {
  cat("\nWeighted Double Score Matching Results\n")
  cat("=====================================\n")
  cat("Estimand:", x$estimand, "\n")
  cat("Sampling:", x$sampling, "\n")
  cat("Sample size: n =", x$n, "(n1 =", x$n1, ", n0 =", x$n0, ")\n\n")
  
  cat("Estimates:\n")
  cat("  Double Score Matching:", sprintf("%.4f", x$est.dsm), "\n")
  
  if (!is.na(x$est.ps)) {
    cat("  Propensity Score Only:", sprintf("%.4f", x$est.ps), "\n")
  }
  if (!is.na(x$est.pg)) {
    cat("  Prognostic Score Only:", sprintf("%.4f", x$est.pg), "\n")
  }
  if (!is.na(x$est.cov)) {
    cat("  Covariate Matching:   ", sprintf("%.4f", x$est.cov), "\n")
  }
  
  if (!is.na(x$bootvar)) {
    cat("\nInference (based on", x$method, "matching):\n")
    cat("  Bootstrap SE:", sprintf("%.4f", sqrt(x$bootvar)), "\n")
    cat("  95% CI: [", sprintf("%.4f", x$ci.lower), ",", 
        sprintf("%.4f", x$ci.upper), "]\n")
    cat("  Bootstrap 95% CI: [", sprintf("%.4f", x$bootq1), ",",
        sprintf("%.4f", x$bootq2), "]\n")
  }
  
  if (!is.null(x$balance)) {
    cat("\nCovariate Balance:\n")
    print(round(x$balance, 3))
  }
  
  invisible(x)
}


#' Summary method for wdsmatch objects
#'
#' @param object A wdsmatch object
#' @param ... Additional arguments (ignored)
#' @export
summary.wdsmatch <- function(object, ...) {
  print(object)
} 