#' Weighted Double Score Matching Estimator for Population Average Treatment Effect on the Treated (PATT) - Prospective Sampling
#'
#' \code{wdsmatchPATT_prospective} applies weighted double score matching to estimate 
#' population average treatment effect on the treated under prospective sampling design 
#' where survey weights depend only on covariates X.
#'
#' This function implements the WDSM methodology from Section 4 of the theoretical 
#' development. PATT estimation requires only the weaker unconfoundedness assumption 
#' Y_i(0) ⊥ Z_i | X_i and focuses on matching control units to treated units.
#'
#' @param Y Outcome as numeric vector.
#' @param X Covariates as numeric vector or matrix.
#' @param A Treatment assignment as numeric vector (1 = treatment, 0 = control).
#' @param weights Survey weights as numeric vector (w_i = 1/p_i).
#' @param method Matching method: "dsm" (double score), "ps" (propensity only), 
#'        "pg" (prognostic only), "cov" (covariates).
#' @param model.ps Model for propensity score: "logit", "probit", "linpred", or NULL if ps provided.
#' @param ps Propensity scores if pre-computed (optional).
#' @param lp.ps Linear predictors for propensity score if model.ps = "linpred".
#' @param model.pg Model for prognostic score: "glm", "glm_logit", "glm_probit", 
#'        "linpred", or NULL if pg provided. Note: Only control prognostic score is needed.
#' @param pg Control prognostic score if pre-computed (optional, numeric vector).
#' @param lp.pg Linear predictors for prognostic score if model.pg = "linpred".
#' @param M Number of matches per unit (default = 3).
#' @param bias.correct Whether to apply bias correction (default = TRUE).
#' @param varest Whether to estimate variance (default = TRUE).
#' @param boots Number of bootstrap replicates if varest = TRUE (default = 100).
#' @param mc Whether to use parallel processing for bootstrap (default = FALSE).
#' @param ncpus Number of cores for parallel processing if mc = TRUE.
#' @param cov.balance Whether to report covariate balance (default = FALSE).
#' @param ... Additional arguments passed to Matching::Match.
#'
#' @return A list containing:
#'   \item{est.dsm}{PATT estimate using double score matching}
#'   \item{est.ps}{PATT estimate using propensity score only}
#'   \item{est.pg}{PATT estimate using prognostic score only}
#'   \item{est.cov}{PATT estimate using covariate matching}
#'   \item{bootvar}{Bootstrap variance estimate}
#'   \item{bootq1}{Bootstrap 2.5% quantile}
#'   \item{bootq2}{Bootstrap 97.5% quantile}
#'   \item{balance}{Covariate balance results if requested}
#'
#' @export
wdsmatchPATT_prospective <- function(Y, X, A, weights,
                                    method = "dsm",
                                    model.ps = "logit", ps = NULL, lp.ps = NULL,
                                    model.pg = "glm", pg = NULL, lp.pg = NULL,
                                    M = 3, bias.correct = TRUE,
                                    varest = TRUE, boots = 100, mc = FALSE, ncpus = 4,
                                    cov.balance = FALSE, ...) {
  
  # Input validation
  n <- length(Y)
  if (length(A) != n || length(weights) != n) {
    stop("Y, A, and weights must have the same length")
  }
  if (is.vector(X)) X <- matrix(X, ncol = 1)
  if (nrow(X) != n) {
    stop("Number of rows in X must equal length of Y")
  }
  
  # Ensure proper treatment coding
  if (!all(A %in% c(0, 1))) {
    stop("Treatment A must be coded as 0 (control) or 1 (treatment)")
  }
  
  # Location indicators
  loc.1 <- which(A == 1)
  loc.0 <- which(A == 0)
  n1 <- length(loc.1)
  n0 <- length(loc.0)
  
  # Weighted sample sizes
  n1.w <- sum(weights[loc.1])
  n0.w <- sum(weights[loc.0])
  
  # ==== Step 1: Weighted Propensity Score Estimation ====
  if (is.null(ps)) {
    if (model.ps == "logit") {
      # Weighted logistic regression
      ps.fit <- glm(A ~ X, family = binomial(link = "logit"), weights = weights)
      ps <- fitted(ps.fit)
    } else if (model.ps == "probit") {
      # Weighted probit regression
      ps.fit <- glm(A ~ X, family = binomial(link = "probit"), weights = weights)
      ps <- fitted(ps.fit)
    } else if (model.ps == "linpred" && !is.null(lp.ps)) {
      # Weighted logistic with linear predictors
      if (is.vector(lp.ps)) lp.ps <- matrix(lp.ps, ncol = 1)
      ps.fit <- glm(A ~ lp.ps, family = binomial(link = "logit"), weights = weights)
      ps <- fitted(ps.fit)
    } else {
      stop("Invalid propensity score specification")
    }
  }
  
  # ==== Step 2: Weighted Control Prognostic Score Estimation ====
  # For PATT, we only need the control prognostic score
  if (is.null(pg)) {
    mu0 <- numeric(n)
    
    if (model.pg == "glm") {
      # Weighted linear regression for continuous outcomes
      pg0.fit <- lm(Y ~ X, weights = weights, subset = (A == 0))
      mu0 <- predict(pg0.fit, newdata = data.frame(X = X))
    } else if (model.pg == "glm_logit") {
      # Weighted logistic for binary outcomes
      pg0.fit <- glm(Y ~ X, family = binomial(link = "logit"), 
                      weights = weights[loc.0], subset = (A == 0))
      mu0 <- predict(pg0.fit, newdata = data.frame(X = X), type = "response")
    } else if (model.pg == "linpred" && !is.null(lp.pg)) {
      # Weighted linear model with linear predictors
      if (is.vector(lp.pg)) lp.pg <- matrix(lp.pg, ncol = 1)
      pg0.fit <- lm(Y ~ lp.pg, weights = weights, subset = (A == 0))
      mu0 <- predict(pg0.fit, newdata = data.frame(lp.pg = lp.pg))
    } else {
      stop("Invalid prognostic score specification")
    }
    
    pg <- mu0
  } else {
    mu0 <- pg
  }
  
  # ==== Step 3: Construct and Standardize Double Score ====
  # For PATT, use control-specific double score V0
  V0 <- cbind(ps, mu0)
  
  # Standardize the score
  V0.std <- scale(V0)
  
  # ==== Step 4: Weighted Matching (Control to Treated) ====
  # For PATT, we only match control units to treated units
  Y.matched.0 <- rep(NA, n)
  Y.matched.0[loc.0] <- Y[loc.0]  # Observed Y(0) for controls
  
  # Match controls to each treated unit
  if (n1 > 0 && n0 > 0) {
    match.10 <- Matching::Match(Y = Y, Tr = A, X = V0.std, M = M,
                                replace = TRUE, ties = FALSE,
                                Weight = 2, ...)
    
    # Compute weighted imputed control outcomes for treated units
    for (i in 1:n1) {
      treated.idx <- loc.1[i]
      # Get matched control indices
      match.indices <- match.10$index.control[match.10$index.treated == treated.idx]
      if (length(match.indices) > 0) {
        # Weighted average of matched controls
        matched.weights <- weights[match.indices]
        Y.matched.0[treated.idx] <- sum(Y[match.indices] * matched.weights) / sum(matched.weights)
      }
    }
  }
  
  # ==== Step 5: Compute PATT Estimate ====
  # Raw WDSM estimator for PATT (Section 4.1)
  tau.raw <- sum(weights[loc.1] * (Y[loc.1] - Y.matched.0[loc.1])) / n1.w
  
  # ==== Step 6: Bias Correction (if requested) ====
  if (bias.correct) {
    # Estimate control outcome model for bias correction
    # Use sieve estimation approach
    sieve.vars <- cbind(mu0, mu0^2, ps, ps^2, ps * mu0)
    
    # Weighted regression for control group
    bc0.fit <- lm(Y ~ sieve.vars, weights = weights, subset = (A == 0))
    mu0.bc <- predict(bc0.fit, newdata = data.frame(sieve.vars = sieve.vars))
    
    # Compute bias term
    bias.0 <- 0
    
    # Bias for Y(0) imputation among treated
    for (i in 1:n1) {
      treated.idx <- loc.1[i]
      match.indices <- match.10$index.control[match.10$index.treated == treated.idx]
      if (length(match.indices) > 0) {
        matched.weights <- weights[match.indices]
        bias.0 <- bias.0 + weights[treated.idx] * 
                  sum(matched.weights * (mu0.bc[match.indices] - mu0.bc[treated.idx])) / 
                  sum(matched.weights)
      }
    }
    
    # Normalize bias term
    bias.0 <- bias.0 / n1.w
    
    # Debiased estimator
    tau.debiased <- tau.raw - bias.0
  } else {
    tau.debiased <- tau.raw
  }
  
  # ==== Step 7: Variance Estimation (Bootstrap) ====
  if (varest) {
    tau.boot <- numeric(boots)
    
    # Load bootstrap function
    # The bootstrap_wdsm.R file contains the proper bootstrap implementation
    
    if (mc && ncpus > 1) {
      # Parallel bootstrap
      cl <- parallel::makeCluster(ncpus)
      
      # Export necessary objects and functions to cluster
      parallel::clusterExport(cl, c("Y", "X", "A", "weights", "method",
                                    "model.ps", "ps", "lp.ps", 
                                    "model.pg", "pg", "lp.pg",
                                    "M", "bias.correct",
                                    "bootstrap_wdsm_patt_prospective"), 
                              envir = environment())
      
      # Also export Matching package
      parallel::clusterEvalQ(cl, library(Matching))
      
      tau.boot <- parallel::parLapply(cl, 1:boots, function(b) {
        set.seed(b)
        # Call proper bootstrap function
        bootstrap_wdsm_patt_prospective(data = NULL, Y = Y, X = X, A = A, 
                                       weights = weights,
                                       method = method,
                                       model.ps = model.ps, ps = ps, lp.ps = lp.ps,
                                       model.pg = model.pg, pg = pg, lp.pg = lp.pg,
                                       M = M, bias.correct = bias.correct)
      })
      
      parallel::stopCluster(cl)
      tau.boot <- unlist(tau.boot)
    } else {
      # Sequential bootstrap
      for (b in 1:boots) {
        set.seed(b)
        tau.boot[b] <- bootstrap_wdsm_patt_prospective(data = NULL, Y = Y, X = X, A = A,
                                                       weights = weights,
                                                       method = method,
                                                       model.ps = model.ps, ps = ps, lp.ps = lp.ps,
                                                       model.pg = model.pg, pg = pg, lp.pg = lp.pg,
                                                       M = M, bias.correct = bias.correct)
      }
    }
    
    # Remove any NA values from failed bootstrap iterations
    tau.boot <- tau.boot[!is.na(tau.boot)]
    
    if (length(tau.boot) < boots * 0.9) {
      warning(paste("Only", length(tau.boot), "out of", boots, 
                    "bootstrap iterations succeeded. Consider increasing sample size or adjusting model."))
    }
    
    boot.var <- var(tau.boot)
    boot.q1 <- quantile(tau.boot, 0.025)
    boot.q2 <- quantile(tau.boot, 0.975)
  } else {
    boot.var <- boot.q1 <- boot.q2 <- NA
  }
  
  # ==== Step 8: Alternative Methods (if requested) ====
  est.ps <- est.pg <- est.cov <- NA
  
  if (method %in% c("ps", "all")) {
    # Propensity score only matching
    match.ps <- Matching::Match(Y = Y, Tr = A, X = ps, M = M,
                                replace = TRUE, ties = FALSE, ...)
    Y.ps.0 <- rep(NA, n)
    Y.ps.0[loc.0] <- Y[loc.0]
    
    # Impute using PS matching
    for (i in 1:n1) {
      idx <- loc.1[i]
      matches <- match.ps$index.control[match.ps$index.treated == idx]
      if (length(matches) > 0) {
        Y.ps.0[idx] <- sum(Y[matches] * weights[matches]) / sum(weights[matches])
      }
    }
    
    est.ps <- sum(weights[loc.1] * (Y[loc.1] - Y.ps.0[loc.1])) / n1.w
  }
  
  if (method %in% c("pg", "all")) {
    # Prognostic score only matching
    match.pg <- Matching::Match(Y = Y, Tr = A, X = mu0, M = M,
                                replace = TRUE, ties = FALSE, ...)
    Y.pg.0 <- rep(NA, n)
    Y.pg.0[loc.0] <- Y[loc.0]
    
    # Impute using PG matching
    for (i in 1:n1) {
      idx <- loc.1[i]
      matches <- match.pg$index.control[match.pg$index.treated == idx]
      if (length(matches) > 0) {
        Y.pg.0[idx] <- sum(Y[matches] * weights[matches]) / sum(weights[matches])
      }
    }
    
    est.pg <- sum(weights[loc.1] * (Y[loc.1] - Y.pg.0[loc.1])) / n1.w
  }
  
  # ==== Step 9: Covariate Balance (if requested) ====
  balance.results <- NULL
  if (cov.balance) {
    # Compute weighted standardized differences for matched treated units
    balance.results <- compute_weighted_balance_PATT(X, A, weights, match.10)
  }
  
  # Return results
  results <- list(
    est.dsm = tau.debiased,
    est.ps = est.ps,
    est.pg = est.pg,
    est.cov = est.cov,
    bootvar = boot.var,
    bootq1 = boot.q1,
    bootq2 = boot.q2,
    n = n,
    n1 = n1,
    n0 = n0,
    n1.w = n1.w,
    n0.w = n0.w,
    method = method,
    sampling = "prospective",
    estimand = "PATT"
  )
  
  if (cov.balance) {
    results$balance <- balance.results
  }
  
  class(results) <- "wdsmatch"
  return(results)
}


# Helper function for weighted balance assessment for PATT
compute_weighted_balance_PATT <- function(X, A, weights, match.10) {
  if (is.vector(X)) X <- matrix(X, ncol = 1)
  
  p <- ncol(X)
  balance <- matrix(NA, p, 6)
  colnames(balance) <- c("Treated.Mean", "Control.Mean", "SMD.Before",
                         "Treated.Mean.Matched", "Control.Mean.Matched", "SMD.After")
  
  # Location indicators
  loc.1 <- which(A == 1)
  loc.0 <- which(A == 0)
  
  # Before matching
  w1 <- weights[loc.1]
  w0 <- weights[loc.0]
  X1 <- X[loc.1, , drop = FALSE]
  X0 <- X[loc.0, , drop = FALSE]
  
  for (j in 1:p) {
    # Weighted means before matching
    mean1.before <- sum(w1 * X1[, j]) / sum(w1)
    mean0.before <- sum(w0 * X0[, j]) / sum(w0)
    
    # Weighted variance
    var1 <- sum(w1 * (X1[, j] - mean1.before)^2) / sum(w1)
    var0 <- sum(w0 * (X0[, j] - mean0.before)^2) / sum(w0)
    pooled.sd <- sqrt((var1 + var0) / 2)
    
    # SMD before matching
    smd.before <- (mean1.before - mean0.before) / pooled.sd
    
    balance[j, 1] <- mean1.before
    balance[j, 2] <- mean0.before
    balance[j, 3] <- smd.before
    
    # After matching - compute matched control mean for each treated unit
    if (!is.null(match.10)) {
      matched.mean0 <- 0
      total.weight <- 0
      
      for (i in 1:length(loc.1)) {
        treated.idx <- loc.1[i]
        match.indices <- match.10$index.control[match.10$index.treated == treated.idx]
        if (length(match.indices) > 0) {
          matched.weights <- weights[match.indices]
          matched.mean0 <- matched.mean0 + 
                           w1[i] * sum(matched.weights * X[match.indices, j]) / sum(matched.weights)
          total.weight <- total.weight + w1[i]
        }
      }
      
      mean0.after <- matched.mean0 / total.weight
      smd.after <- (mean1.before - mean0.after) / pooled.sd
      
      balance[j, 4] <- mean1.before  # Treated mean stays the same
      balance[j, 5] <- mean0.after
      balance[j, 6] <- smd.after
    }
  }
  
  if (!is.null(colnames(X))) {
    rownames(balance) <- colnames(X)
  } else {
    rownames(balance) <- paste0("X", 1:p)
  }
  
  return(balance)
} 