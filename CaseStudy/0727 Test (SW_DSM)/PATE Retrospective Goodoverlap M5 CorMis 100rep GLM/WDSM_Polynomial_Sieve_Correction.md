# WDSM Polynomial Sieve Method Correction

## Summary
Corrected the WDSM implementation to properly implement the polynomial sieve method based on the successful PATT retrospective code example.

## Key Issues Fixed

### 1. **Incorrect Polynomial Sieve Placement**
- **Previous**: Tried to replace the initial prognostic score estimation with polynomial sieve
- **Corrected**: Polynomial sieve is applied AFTER initial score estimation as a bias correction step

### 2. **Workflow Correction**
The correct workflow is now:
1. Estimate propensity scores with GLM (quasibinomial)
2. Estimate initial prognostic scores with LM 
3. **Apply polynomial sieve method** using the initial scores
4. Use sieve-corrected predictions in matching bias correction

### 3. **Polynomial Sieve Variables**
For each outcome model (mu0 and mu1):
- Variables: `mu, mu^2, ps, ps^2, ps*mu`
- Uses propensity scores on probability scale (not logit)
- Fits weighted regression on control/treated units respectively

### 4. **Bootstrap Re-estimation**
In each bootstrap iteration:
1. Re-estimate propensity and prognostic scores with bootstrap weights
2. **Re-fit polynomial sieve models** with re-estimated scores
3. Use the re-estimated sieve predictions for influence functions

## Code Changes

### wdsm_ci_functions.R
Added Step 2.5 after initial score estimation:
```r
# Step 2.5: Apply polynomial sieve method for bias correction
# For control outcome model (mu0)
sieve_vars_0 <- cbind(psi0, psi0^2, e_score, e_score^2, e_score * psi0)
bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0, ...)
mu0_bc <- predict(bc0_fit, ...)

# Similar for mu1
```

### wdsm_method2_multinomial_bootstrap.R
- Updated to re-estimate polynomial sieve in each bootstrap iteration
- Uses bias-corrected scores (`mu0_bc_star`, `mu1_bc_star`) throughout
- Fixed parameter extraction from point estimate

## Technical Details

### Polynomial Sieve Formula
Following dsmatch-master and the PATT example:
```
Y ~ mu + mu^2 + ps + ps^2 + ps*mu
```

Where:
- `mu` = initial prognostic score estimate
- `ps` = propensity score (probability scale)
- Separate models for mu0 (using controls) and mu1 (using treated)

### Survey Weight Handling
- All regressions use survey weights
- Bootstrap combines survey weights with bootstrap weights: `w_star * weights`

## Verification
The implementation now matches the successful PATT retrospective code structure, adapted for PATE estimation with both mu0 and mu1.