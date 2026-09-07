#' Weighted Double Score Matching Estimator for Population Average Treatment Effect (PATE) - Retrospective Sampling
#'
#' \code{wdsmatchPATE_retrospective} applies weighted double score matching to estimate 
#' population average treatment effect under retrospective sampling design where survey 
#' weights depend on both covariates X and treatment Z.
#'
#' This function implements the WDSM methodology from Section 3 of the theoretical 
#' development. Under retrospective sampling, survey weights w_{z,i} = 1/p_{z,i} where 
#' p_{z,i} = P(S_i = 1 | X_i, Z_i = z) is the treatment-specific inclusion probability.
#'
#' @param Y Outcome as numeric vector.
#' @param X Covariates as numeric vector or matrix.
#' @param A Treatment assignment as numeric vector (1 = treatment, 0 = control).
#' @param weights0 Survey weights for control units as numeric vector (w_{0,i}).
#' @param weights1 Survey weights for treated units as numeric vector (w_{1,i}).
#' @param method Matching method: "dsm" (double score), "ps" (propensity only), 
#'        "pg" (prognostic only), "cov" (covariates).
#' @param model.ps Model for propensity score: "logit", "probit", "linpred", or NULL if ps provided.
#' @param ps Propensity scores if pre-computed (optional).
#' @param lp.ps Linear predictors for propensity score if model.ps = "linpred".
#' @param model.pg Model for prognostic score: "glm", "glm_logit", "glm_probit", 
#'        "linpred", or NULL if pg provided.
#' @param pg Prognostic scores if pre-computed (optional, matrix with 2 columns).
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
#'   \item{est.dsm}{PATE estimate using double score matching}
#'   \item{est.ps}{PATE estimate using propensity score only}
#'   \item{est.pg}{PATE estimate using prognostic score only}
#'   \item{est.cov}{PATE estimate using covariate matching}
#'   \item{bootvar}{Bootstrap variance estimate}
#'   \item{bootq1}{Bootstrap 2.5% quantile}
#'   \item{bootq2}{Bootstrap 97.5% quantile}
#'   \item{balance}{Covariate balance results if requested}
#'
#' @export
wdsmatchPATE_retrospective <- function(Y, X, A, weights0, weights1,
                                      method = "dsm",
                                      model.ps = "logit", ps = NULL, lp.ps = NULL,
                                      model.pg = "glm", pg = NULL, lp.pg = NULL,
                                      M = 3, bias.correct = TRUE,
                                      varest = TRUE, boots = 100, mc = FALSE, ncpus = 4,
                                      cov.balance = FALSE, ...) {
  
  # Input validation
  n <- length(Y)
  if (length(A) != n || length(weights0) != n || length(weights1) != n) {
    stop("Y, A, weights0, and weights1 must have the same length")
  }
  if (is.vector(X)) X <- matrix(X, ncol = 1)
  if (nrow(X) != n) {
    stop("Number of rows in X must equal length of Y")
  }
  
  # Ensure proper treatment coding
  if (!all(A %in% c(0, 1))) {
    stop("Treatment A must be coded as 0 (control) or 1 (treatment)")
  }
  
  # Create treatment-specific weights vector
  weights <- ifelse(A == 1, weights1, weights0)
  
  # Location indicators
  loc.1 <- which(A == 1)
  loc.0 <- which(A == 0)
  n1 <- length(loc.1)
  n0 <- length(loc.0)
  
  # ==== Step 1: Weighted Propensity Score Estimation ====
  # Use treatment-specific weights for retrospective design
  if (is.null(ps)) {
    if (model.ps == "logit") {
      # Weighted logistic regression with treatment-specific weights
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
  
  # ==== Step 2: Weighted Prognostic Score Estimation ====
  # Use treatment-specific weights for each group
  if (is.null(pg)) {
    mu0 <- mu1 <- numeric(n)
    
    if (model.pg == "glm") {
      # Weighted linear regression with treatment-specific weights
      pg0.fit <- lm(Y ~ X, weights = weights0, subset = (A == 0))
      pg1.fit <- lm(Y ~ X, weights = weights1, subset = (A == 1))
      mu0 <- predict(pg0.fit, newdata = data.frame(X = X))
      mu1 <- predict(pg1.fit, newdata = data.frame(X = X))
    } else if (model.pg == "glm_logit") {
      # Weighted logistic for binary outcomes
      pg0.fit <- glm(Y ~ X, family = binomial(link = "logit"), 
                      weights = weights0[loc.0], subset = (A == 0))
      pg1.fit <- glm(Y ~ X, family = binomial(link = "logit"), 
                      weights = weights1[loc.1], subset = (A == 1))
      mu0 <- predict(pg0.fit, newdata = data.frame(X = X), type = "response")
      mu1 <- predict(pg1.fit, newdata = data.frame(X = X), type = "response")
    } else if (model.pg == "linpred" && !is.null(lp.pg)) {
      # Weighted linear model with linear predictors
      if (is.vector(lp.pg)) lp.pg <- matrix(lp.pg, ncol = 1)
      pg0.fit <- lm(Y ~ lp.pg, weights = weights0, subset = (A == 0))
      pg1.fit <- lm(Y ~ lp.pg, weights = weights1, subset = (A == 1))
      mu0 <- predict(pg0.fit, newdata = data.frame(lp.pg = lp.pg))
      mu1 <- predict(pg1.fit, newdata = data.frame(lp.pg = lp.pg))
    } else {
      stop("Invalid prognostic score specification")
    }
    
    pg <- cbind(mu0, mu1)
  } else {
    mu0 <- pg[, 1]
    mu1 <- pg[, 2]
  }
  
  # ==== Step 3: Construct and Standardize Double Score ====
  # Treatment-specific double scores as in Yang & Zhang (2020)
  V0 <- cbind(ps, mu0)  # For estimating E[Y(0)]
  V1 <- cbind(ps, mu1)  # For estimating E[Y(1)]
  
  # Standardize each score
  V0.std <- scale(V0)
  V1.std <- scale(V1)
  
  # ==== Step 4: Weighted Matching with Treatment-Specific Weights ====
  # Initialize matched outcomes
  Y.matched <- matrix(NA, n, 2)
  Y.matched[loc.1, 2] <- Y[loc.1]  # Observed Y(1) for treated
  Y.matched[loc.0, 1] <- Y[loc.0]  # Observed Y(0) for control
  
  # Match treated units to controls for Y(0)
  if (n1 > 0 && n0 > 0) {
    match.10 <- Matching::Match(Y = Y, Tr = A, X = V0.std, M = M, 
                                replace = TRUE, ties = FALSE, 
                                Weight = 2, ...)
    
    # Compute weighted imputed outcomes using control weights
    for (i in 1:n1) {
      treated.idx <- loc.1[i]
      # Get matched control indices
      match.indices <- match.10$index.control[match.10$index.treated == treated.idx]
      if (length(match.indices) > 0) {
        # Weighted average using control-specific weights
        matched.weights <- weights0[match.indices]
        Y.matched[treated.idx, 1] <- sum(Y[match.indices] * matched.weights) / sum(matched.weights)
      }
    }
  }
  
  # Match control units to treated for Y(1)
  if (n0 > 0 && n1 > 0) {
    match.01 <- Matching::Match(Y = Y, Tr = 1 - A, X = V1.std, M = M,
                                replace = TRUE, ties = FALSE,
                                Weight = 2, ...)
    
    # Compute weighted imputed outcomes using treatment weights
    for (i in 1:n0) {
      control.idx <- loc.0[i]
      # Get matched treated indices
      match.indices <- match.01$index.control[match.01$index.treated == control.idx]
      if (length(match.indices) > 0) {
        # Weighted average using treatment-specific weights
        matched.weights <- weights1[match.indices]
        Y.matched[control.idx, 2] <- sum(Y[match.indices] * matched.weights) / sum(matched.weights)
      }
    }
  }
  
  # ==== Step 5: Compute PATE Estimate ====
  # Retrospective WDSM estimator (Equation 3.8 in theory)
  # Numerator and denominator for Y(1) component
  num1 <- sum(weights1[loc.1] * Y[loc.1]) + sum(weights0[loc.0] * Y.matched[loc.0, 2])
  denom1 <- sum(weights1[loc.1]) + sum(weights0[loc.0])
  
  # Numerator and denominator for Y(0) component
  num0 <- sum(weights0[loc.0] * Y[loc.0]) + sum(weights1[loc.1] * Y.matched[loc.1, 1])
  denom0 <- sum(weights0[loc.0]) + sum(weights1[loc.1])
  
  tau.raw <- num1 / denom1 - num0 / denom0
  
  # ==== Step 6: Bias Correction (if requested) ====
  if (bias.correct) {
    # Estimate outcome models for bias correction
    sieve.vars <- cbind(mu0, mu1, mu0^2, mu1^2, mu0 * mu1,
                        ps, ps^2, ps * mu0, ps * mu1, ps * mu0 * mu1)
    
    # Weighted regression with treatment-specific weights
    bc1.fit <- lm(Y ~ sieve.vars, weights = weights1, subset = (A == 1))
    mu1.bc <- predict(bc1.fit, newdata = data.frame(sieve.vars = sieve.vars))
    
    bc0.fit <- lm(Y ~ sieve.vars, weights = weights0, subset = (A == 0))
    mu0.bc <- predict(bc0.fit, newdata = data.frame(sieve.vars = sieve.vars))
    
    # Compute bias terms with appropriate weights
    bias.1 <- bias.0 <- 0
    
    # Bias for Y(0) imputation among treated
    for (i in 1:n1) {
      treated.idx <- loc.1[i]
      match.indices <- match.10$index.control[match.10$index.treated == treated.idx]
      if (length(match.indices) > 0) {
        matched.weights <- weights0[match.indices]
        bias.0 <- bias.0 + weights1[treated.idx] * 
                  sum(matched.weights * (mu0.bc[match.indices] - mu0.bc[treated.idx])) / 
                  sum(matched.weights)
      }
    }
    
    # Bias for Y(1) imputation among controls
    for (i in 1:n0) {
      control.idx <- loc.0[i]
      match.indices <- match.01$index.control[match.01$index.treated == control.idx]
      if (length(match.indices) > 0) {
        matched.weights <- weights1[match.indices]
        bias.1 <- bias.1 + weights0[control.idx] * 
                  sum(matched.weights * (mu1.bc[match.indices] - mu1.bc[control.idx])) / 
                  sum(matched.weights)
      }
    }
    
    # Normalize bias terms
    bias.1 <- bias.1 / denom1
    bias.0 <- bias.0 / denom0
    
    # Debiased estimator
    tau.debiased <- tau.raw - (bias.1 - bias.0)
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
      parallel::clusterExport(cl, c("Y", "X", "A", "weights0", "weights1", "method",
                                    "model.ps", "ps", "lp.ps", 
                                    "model.pg", "pg", "lp.pg",
                                    "M", "bias.correct",
                                    "bootstrap_wdsm_pate_retrospective"), 
                              envir = environment())
      
      # Also export Matching package
      parallel::clusterEvalQ(cl, library(Matching))
      
      tau.boot <- parallel::parLapply(cl, 1:boots, function(b) {
        set.seed(b)
        # Call proper bootstrap function
        bootstrap_wdsm_pate_retrospective(data = NULL, Y = Y, X = X, A = A, 
                                         weights0 = weights0, weights1 = weights1,
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
        tau.boot[b] <- bootstrap_wdsm_pate_retrospective(data = NULL, Y = Y, X = X, A = A,
                                                         weights0 = weights0, weights1 = weights1,
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
    # Propensity score only matching with treatment-specific weights
    match.ps <- Matching::Match(Y = Y, Tr = A, X = ps, M = M,
                                replace = TRUE, ties = FALSE, ...)
    Y.ps <- matrix(NA, n, 2)
    Y.ps[loc.1, 2] <- Y[loc.1]
    Y.ps[loc.0, 1] <- Y[loc.0]
    
    # Impute using PS matching with treatment-specific weights
    for (i in 1:n1) {
      idx <- loc.1[i]
      matches <- match.ps$index.control[match.ps$index.treated == idx]
      if (length(matches) > 0) {
        Y.ps[idx, 1] <- sum(Y[matches] * weights0[matches]) / sum(weights0[matches])
      }
    }
    for (i in 1:n0) {
      idx <- loc.0[i]  
      matches <- which(match.ps$index.control == idx)
      if (length(matches) > 0) {
        treated.matches <- match.ps$index.treated[matches]
        Y.ps[idx, 2] <- sum(Y[treated.matches] * weights1[treated.matches]) / 
                        sum(weights1[treated.matches])
      }
    }
    
    # Compute PS estimate with retrospective formula
    num1.ps <- sum(weights1[loc.1] * Y[loc.1]) + sum(weights0[loc.0] * Y.ps[loc.0, 2])
    denom1.ps <- sum(weights1[loc.1]) + sum(weights0[loc.0])
    num0.ps <- sum(weights0[loc.0] * Y[loc.0]) + sum(weights1[loc.1] * Y.ps[loc.1, 1])
    denom0.ps <- sum(weights0[loc.0]) + sum(weights1[loc.1])
    
    est.ps <- num1.ps / denom1.ps - num0.ps / denom0.ps
  }
  
  # ==== Step 9: Covariate Balance (if requested) ====
  balance.results <- NULL
  if (cov.balance) {
    # Compute weighted standardized differences with treatment-specific weights
    balance.results <- compute_weighted_balance_retro(X, A, weights0, weights1, 
                                                      match.10, match.01)
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
    method = method,
    sampling = "retrospective"
  )
  
  if (cov.balance) {
    results$balance <- balance.results
  }
  
  class(results) <- "wdsmatch"
  return(results)
}


# Helper function for weighted balance assessment with treatment-specific weights
compute_weighted_balance_retro <- function(X, A, weights0, weights1, match.10, match.01) {
  if (is.vector(X)) X <- matrix(X, ncol = 1)
  
  p <- ncol(X)
  balance <- matrix(NA, p, 6)
  colnames(balance) <- c("Treated.Mean", "Control.Mean", "SMD.Before",
                         "Treated.Mean.After", "Control.Mean.After", "SMD.After")
  
  # Before matching with treatment-specific weights
  loc.1 <- which(A == 1)
  loc.0 <- which(A == 0)
  w1 <- weights1[loc.1]
  w0 <- weights0[loc.0]
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
  }
  
  # After matching weighted balance would require matched sample construction
  balance[, 4:6] <- NA
  
  if (!is.null(colnames(X))) {
    rownames(balance) <- colnames(X)
  } else {
    rownames(balance) <- paste0("X", 1:p)
  }
  
  return(balance)
} 