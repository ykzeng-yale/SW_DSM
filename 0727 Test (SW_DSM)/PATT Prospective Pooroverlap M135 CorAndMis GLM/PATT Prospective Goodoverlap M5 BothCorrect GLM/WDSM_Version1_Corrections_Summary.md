# WDSM Version 1 Corrections Summary

## Key Issues Identified and Fixed

Based on the PATE prospective implementation, several critical issues were identified and corrected in the PATT Version 1 implementation:

### 1. Bootstrap Weight Normalization

**Original (Incorrect):**
```r
m_star <- rmultinom(1, n, p_weights)[, 1]
omega_star <- m_star / n
# Then used: w * omega_star
```

**Corrected:**
```r
m_star <- as.numeric(rmultinom(1, n, p_weights))
w_b <- w * m_star  # Bootstrap weights
```

**Why this matters:** The original normalization by `n` was incorrect. The PATE implementation shows that bootstrap weights should be `w * m_star` directly, where `m_star` are the multinomial counts.

### 2. Bootstrap Validity Check

**Added:**
```r
if (sum(w_b[A == 1]) == 0 || sum(w_b[A == 0]) == 0) {
  tau_boot[b] <- NA
  next
}
```

**Why this matters:** Some bootstrap samples might have no treated or control units, which would cause errors in estimation.

### 3. Bootstrap Calculation for PATT

**Original:** Used a formula with numerator/denominator that was incorrect for PATT

**Corrected:** Implemented proper linearization specific to PATT:
```r
# Main estimator components
tau_boot_main <- 0
w_treated_sum <- sum(w_b[treated_idx])

for (i in treated_idx) {
  # Main outcome contribution
  tau_boot_main <- tau_boot_main + w_b[i] * Y[i] / w_treated_sum
  
  # Subtract matched control contribution (using FIXED matching)
  matched_idx <- matches[[as.character(i)]]
  if (length(matched_idx) > 0 && sum(w_b[matched_idx]) > 0) {
    matched_contrib <- sum(w_b[matched_idx] * Y[matched_idx]) / sum(w_b[matched_idx])
    tau_boot_main <- tau_boot_main - w_b[i] * matched_contrib / w_treated_sum
  }
}

# Add augmentation term for controls (using FIXED K_M)
augment_term <- 0
for (j in control_idx) {
  if (K_M[j] > 0) {
    augment_term <- augment_term - w_b[j] * K_M[j] * (Y[j] - mu0_star[j]) / w_treated_sum
  }
}
```

### 4. Bootstrap Percentile CI

**Added:**
```r
CI_percentile <- quantile(tau_boot_valid, probs = c(0.025, 0.975))
```

**Why this matters:** Bootstrap percentile CIs are often more accurate than normal approximation CIs, especially when the bootstrap distribution is skewed.

### 5. Robust Error Handling

**Added:**
- Removal of NA values before variance calculation
- Minimum sample size check (at least 10 valid bootstrap samples)
- Proper initialization of return values

## Key Differences Between PATE and PATT

1. **Estimand:**
   - PATE: τ = E[Y(1) - Y(0)] (population average)
   - PATT: τ = E[Y(1) - Y(0) | A=1] (average for treated only)

2. **Matching Direction:**
   - PATE: Bidirectional (treated↔control)
   - PATT: Unidirectional (treated→control only)

3. **Prognostic Scores:**
   - PATE: Estimates both μ₀ and μ₁
   - PATT: Only estimates μ₀ (control outcome model)

4. **Bootstrap Formula:**
   - PATE: Involves both treatment groups symmetrically
   - PATT: Focuses on treated units with control augmentation

## Files Updated

1. **Original Version 1:** `WDSM/R/wdsm_patt_prospective_v1.R` (updated with corrections)
2. **Corrected Version:** `WDSM/R/wdsm_patt_prospective_v1_corrected.R` (new implementation)
3. **Documentation:** Updated to reflect the corrections

## Recommendations

1. Use the bootstrap percentile CI rather than normal approximation CI
2. Always check `n_valid_boot` to ensure sufficient bootstrap samples
3. The bias correction is crucial for d=2 matching - don't skip it
4. Monitor convergence of bootstrap estimates