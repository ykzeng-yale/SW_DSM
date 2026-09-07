# FULLY FIXED WDSM - 20 Replicate Test Submission

## Critical Fixes Applied ✅

### 1. **Lambda_ij (Donor Share) - FIXED**
**OLD (Wrong):**
```r
K0_w[j] <- K0_w[j] + weights[i] / total_weight
```

**NEW (Correct):**
```r
lambda_ij = weights[j] / sum(weights[neighbors])
K0_w[j] <- K0_w[j] + weights[i] * lambda_ij
```

**Impact:** This was causing systematic bias by mis-weighting heavily reused donors in poor overlap regions.

### 2. **Separate Score Spaces - FIXED**
**OLD (Wrong):** Single unified 3D score `(logit(e), psi0, psi1)` for all matching

**NEW (Correct):** 
- S0 = `(logit(e), psi0)` for matching treated→control
- S1 = `(logit(e), psi1)` for matching control→treated

**Impact:** Improves matching quality by using appropriate score spaces.

### 3. **Score-Based Outcome Models - FIXED**
**OLD (Wrong):** Refitting on original covariates X in bootstrap

**NEW (Correct):** Refitting on score space with polynomial sieve:
```r
B <- cbind(1, S[,1], S[,2], S[,1]^2, S[,2]^2, S[,1]*S[,2])
mu_fit <- lm.fit(x = B, y = Y, w = weights)
```

**Impact:** Better captures matching-induced variance for proper coverage.

### 4. **Treatment-Aware Bootstrap - FIXED**
**OLD (Wrong):** Uniform multinomial across all units

**NEW (Correct):** Separate multinomial for treated/control with calibration:
```r
m1 <- rmultinom(1, n1, rep(1/n1, n1))  # Treated
m0 <- rmultinom(1, n0, rep(1/n0, n0))  # Control
# Then calibrate totals back
```

**Impact:** Respects retrospective sampling design for better variance estimation.

## Test Configuration

### Parameters:
- **Replicates:** 20 (quick test run)
- **Sample Size:** 1000
- **M Value:** 5 
- **Bootstrap:** 200 iterations
- **Cores:** 10 per job
- **Memory:** 8GB per CPU
- **Account:** tong
- **Partition:** day (4 hour limit)

### Scenarios:
- **CorCor:** Both PS and PGS correctly specified (with X1:X2)
- **MisCor:** PS misspecified (no X1:X2), PGS correct
- **CorMis:** PS correct, PGS misspecified (no X1:X2)
- **MisMis:** Both misspecified (no X1:X2)

### Data:
- Poor Overlap population (delta_z = 2)
- Retrospective sampling with probability-based selection
- Survey weights = 1/Prob

## Expected Results

### Before Fixes (from previous runs):
| Metric | Value |
|--------|-------|
| Bias (CorCor) | -3.0% |
| Coverage (CorCor) | 79% |
| SE Ratio | 0.634 |

### After Fixes (expected):
| Metric | Expected Value |
|--------|---------------|
| Bias (CorCor) | <1% |
| Coverage (CorCor) | ~93-95% |
| SE Ratio | ~0.95-1.05 |

## File Structure

Each scenario folder contains:
- `compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R` - Main script
- `wdsm_ci_functions.R` - FULLY FIXED point estimation
- `wdsm_method2_multinomial_bootstrap.R` - FULLY FIXED bootstrap
- `dsmatch-master/` - Unweighted matching functions
- `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData` - Data

## Key Implementation Details

### Point Estimation:
```r
# Separate score spaces
S0 <- cbind(logit(e), psi0)
S1 <- cbind(logit(e), psi1)

# Match within appropriate space
if (A[i] == 1) match in S0 space
if (A[i] == 0) match in S1 space

# Correct lambda for weighted imputation
lambda_ij = omega[j] / sum(omega[neighbors])

# Fit on scores, not X
mu0_fit <- fit_on_scores(Y, A, S0, weights, a=0)
mu1_fit <- fit_on_scores(Y, A, S1, weights, a=1)
```

### Bootstrap:
```r
# Treatment-aware weights
m1 ~ Multinomial(n1, 1/n1)
m0 ~ Multinomial(n0, 1/n0)

# Refit on scores each iteration
S0_b <- cbind(logit(e_b), psi0_b)
S1_b <- cbind(logit(e_b), psi1_b)
mu0_b <- fit_on_scores(Y, A, S0_b, wb, a=0)
mu1_b <- fit_on_scores(Y, A, S1_b, wb, a=1)

# Fixed matches and K_tilde
```

## Submission Commands

To submit:
```bash
./submit_20rep_fully_fixed_to_tong.sh
```

To check status:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong | grep FIXED'
```

To download results:
```bash
for s in CorCor MisCor CorMis MisMis; do
  scp yz2324@login2.mccleary.ycrc.yale.edu:/path/to/${s}/raw_results_20reps_${s}_FULLY_FIXED.RData .
done
```

## Timeline

- Submission: Now
- Expected completion: ~1-2 hours per scenario
- Total: ~2-3 hours (can run in parallel)

## Success Criteria

The fixes are successful if:
1. WDSM bias in CorCor reduces from 3% to <1%
2. Coverage improves from 79% to >90%
3. SE ratio improves from 0.63 to ~0.95-1.05
4. Model specification patterns hold correctly

## Notes

This is a test run with 20 replicates to verify the fixes work correctly. If successful, we should run the full 100 or 1000 replicates for publication-quality results.
