# 🚨 CRITICAL WDSM FIXES NEEDED

## Three Major Issues Identified by Theoretical Analysis

### 1. ❌ **Lambda_ij (Donor Share) Issue** - CONFIRMED BUG

**Current Implementation (WRONG):**
```r
# Line 122 in wdsm_ci_functions.R
K0_w[j] <- K0_w[j] + weights[i] / total_weight
```

**Problem:** Missing the donor's own weight! We're using equal shares (1/M concept) while imputing with weighted averages.

**Correct Implementation:**
```r
# For survey-weighted imputation, lambda_ij must be:
lambda_ij = weights[j] / sum(weights[neighbors])
K0_w[j] <- K0_w[j] + weights[i] * (weights[j] / total_weight)
```

### 2. ❌ **Cross-Space Matching** - CONFIRMED ISSUE  

**Current Implementation (PROBLEMATIC):**
```r
# Lines 212-213: Using unified score for all
double_score <- cbind(e_score_logit, psi0, psi1)
S <- standardize_with_weights(double_score, w)

# Lines 223-224: Comparing treated to control in SAME space
distances <- apply(S[control_idx, , drop = FALSE], 1, 
                  function(x) weighted_distance(S[i,], x))
```

**Problem:** We're using a 3-dimensional unified score, but should use:
- S0 = (logit(e), psi0) for matching treated→control  
- S1 = (logit(e), psi1) for matching control→treated

**Correct Implementation:**
```r
# Build separate score spaces
S0 <- cbind(e_score_logit, psi0)  # For treated->control matching
S1 <- cbind(e_score_logit, psi1)  # For control->treated matching
S0_std <- standardize_with_weights(S0, w)
S1_std <- standardize_with_weights(S1, w)

# Match within appropriate space
if (A[i] == 1) {
  # Compare S0[i] to S0[control_idx]
  distances <- apply(S0_std[control_idx,], 1, 
                    function(x) weighted_distance(S0_std[i,], x))
} else {
  # Compare S1[i] to S1[treated_idx]  
  distances <- apply(S1_std[treated_idx,], 1,
                    function(x) weighted_distance(S1_std[i,], x))
}
```

### 3. ❌ **Bootstrap Refits on X, Not Scores** - CONFIRMED

**Current Implementation (SUBOPTIMAL):**
```r
# Lines 100-113 in bootstrap: Refitting on X
prog0_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                data = df_0, weights = ...)
```

**Problem:** Should refit outcome models on the score space, not original covariates.

**Correct Implementation:**
```r
# Fit outcome models on scores with polynomial sieve
fit_mu_on_scores <- function(Y, A, S, w, a) {
  idx <- which(A == a)
  # Polynomial basis on scores
  B <- cbind(1, S[,1], S[,2], S[,1]^2, S[,2]^2, S[,1]*S[,2])
  lm.fit(x = B[idx,], y = Y[idx], w = w[idx])
}
```

## Impact on Results

These three issues together explain:
- **3% bias**: Lambda_ij mismatch systematically mis-weights heavily reused donors
- **79% coverage**: Bootstrap variance underestimated due to X-refitting instead of score-refitting
- **Poor overlap amplifies problems**: Boundary donors are reused most, making weight errors critical

## Complete Fix Implementation

```r
# FIXED calculate_weighted_reuse_counts
calculate_weighted_reuse_counts_FIXED <- function(n, A, matches_0, matches_1, weights) {
  omega <- weights / sum(weights)
  Gamma0 <- Gamma1 <- rep(0, n)
  
  # Treated recipients -> control donors (with correct lambda)
  for (i in which(A == 1)) {
    neighbors <- matches_0[[i]]
    if (!is.null(neighbors) && length(neighbors) > 0) {
      # FIXED: Include donor weight in lambda
      lambda_vec <- omega[neighbors] / sum(omega[neighbors])
      for (k in seq_along(neighbors)) {
        j <- neighbors[k]
        Gamma0[j] <- Gamma0[j] + omega[i] * lambda_vec[k]
      }
    }
  }
  
  # Control recipients -> treated donors (with correct lambda)
  for (i in which(A == 0)) {
    neighbors <- matches_1[[i]]
    if (!is.null(neighbors) && length(neighbors) > 0) {
      # FIXED: Include donor weight in lambda
      lambda_vec <- omega[neighbors] / sum(omega[neighbors])
      for (k in seq_along(neighbors)) {
        j <- neighbors[k]
        Gamma1[j] <- Gamma1[j] + omega[i] * lambda_vec[k]
      }
    }
  }
  
  # Convert to K-tilde (reuse multipliers)
  K_tilde <- rep(0, n)
  K_tilde[A == 0] <- Gamma0[A == 0] / pmax(omega[A == 0], 1e-10)
  K_tilde[A == 1] <- Gamma1[A == 1] / pmax(omega[A == 1], 1e-10)
  
  return(list(K0_w = K_tilde * (A == 0), 
              K1_w = K_tilde * (A == 1)))
}
```

## Priority of Fixes

1. **HIGHEST**: Fix lambda_ij (reuse counts) - Direct cause of bias
2. **HIGH**: Fix score spaces (S0 vs S1) - Improves matching quality
3. **MEDIUM**: Fix bootstrap refitting - Improves coverage

## Expected Results After Fixes

With all three fixes:
- Bias: 3% → <1%
- Coverage: 79% → ~93-95%
- SE Ratio: 0.63 → ~0.95-1.05

The theoretical analysis is correct - these are real bugs that need fixing!
