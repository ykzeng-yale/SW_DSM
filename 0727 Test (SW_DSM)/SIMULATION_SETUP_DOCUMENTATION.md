# Survey-Weighted Double Score Matching (SW-DSM) Simulation Setup Documentation

## Critical Lessons Learned

### 1. Population Data Setup ✅
**Requirement**: Use correct population data matching the intended overlap scenario

**Implementation**:
- **Good Overlap**: `SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData`
  - δ_z = 0.5 in PS model (moderate treatment-covariate association)
- **Poor Overlap**: `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData`  
  - δ_z = 2.0 in PS model (strong treatment-covariate association)
- Population size: N = 1,000,000
- True model includes X1:X2 interaction in both PS and outcome models

**Verification**:
```r
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
pop <- SuperPopGen_PoorOverlap_AllinOne_0118_2025[[1]]
# Check: y0, y1, x1-x6, strata, cluster variables present
```

### 2. Sampling Mechanism ✅
**Requirement**: Use correct sampling design (retrospective for our case)

**Retrospective Sampling Implementation**:
```r
# Coefficients from SW_PSW-main
c0 <- log(n_sample/N / (1 - n_sample/N))
c1 <- log(1.05); c2 <- log(1.10); c3 <- log(1.15)
c4 <- log(1.10); c5 <- log(1.05); c6 <- log(1.10)
delta_z_in_s <- log(0.9)  # Treatment effect on sampling

# Probability-based selection
prob_S <- exp(formula_S) / (1 + exp(formula_S))
survey_weight <- 1 / prob_S
```

**Common Mistake**: Using simplified 50/50 stratified sampling instead of probability-based

### 3. Parallel Processing Source Requirements ✅
**Critical**: Functions must be sourced INSIDE each parallel worker

**Correct Implementation**:
```r
run_single_replicate <- function(...) {
  # Source INSIDE the worker function
  dsmatch_files <- c(
    "dsmatch-master/R/dsmatchATE.R",
    "dsmatch-master/R/bisect.R",
    # ... all helper functions
  )
  for (file in dsmatch_files) source(file)
  
  source("wdsm_method2_multinomial_bootstrap.R")
  source("wdsm_ci_functions.R")
  
  # Now run methods...
}
```

**Why**: FORK clusters on Mac/Linux share memory, but PSOCK clusters (HPC) don't

### 4. Model Specification Parameter Passing ✅
**Requirement**: Correctly vary model specifications by scenario

**Implementation Pattern**:
```r
# Determine specifications based on scenario
use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")

# Apply to covariate matrices
if (use_interaction_ps) {
  X_ps <- cbind(X, X[,1] * X[,2])
} else {
  X_ps <- X
}

# Pass to methods
dsmatchATE(X = X_ps, lp.pg = X_pg, ...)  # DSM uses both
dsmatchATE(X = X_ps, method = "ps", ...)  # PS uses X_ps
dsmatchATE(X = X_pg, method = "pg", ...)  # PG uses X_pg
```

### 5. Performance Metrics Calculation ✅
**Requirement**: Calculate relative metrics correctly

**Correct Formulas**:
```r
# Relative Bias (percentage)
rel_bias <- (mean(estimates) - true_pate) / abs(true_pate) * 100

# Relative Efficiency (SE ratio)
emp_se <- sd(estimates)  # Monte Carlo empirical SE
mean_se <- mean(ses)      # Average reported SE
se_ratio <- mean_se / emp_se

# Coverage (95% CI)
coverage <- mean(ci_lowers <= true_pate & ci_uppers >= true_pate)

# RMSE
rmse <- sqrt(mean((estimates - true_pate)^2))
```

### 6. Timeout Configuration ⚠️
**Critical**: NO individual method timeouts

**Wrong**:
```r
# DON'T DO THIS
R.utils::withTimeout({
  dsm_result <- dsmatchATE(...)
}, timeout = 300)
```

**Correct**:
```bash
# Only SLURM job-level timeout
#SBATCH --time=04:00:00  # For test runs
#SBATCH --time=23:00:00  # For full runs on day partition
```

### 7. WDSM Implementation Requirements ✅

#### 7.1 Normal CI Construction (not quantile)
```r
# CORRECT: Normal-based CI
ci_lower <- estimate - qnorm(1 - alpha/2) * se
ci_upper <- estimate + qnorm(1 - alpha/2) * se

# WRONG: Quantile-based CI
# ci_lower <- quantile(bootstrap_samples, alpha/2)
```

#### 7.2 Bias Correction with Score Transformation
```r
# Score transformation to bounded space
e_bounded <- pmax(pmin(e_score, 0.999), 0.001)
e_logit <- qlogis(e_bounded)

# Separate score spaces
S0 <- cbind(e_logit, psi0)  # For matching treated→control
S1 <- cbind(e_logit, psi1)  # For matching control→treated

# Bias correction via polynomial sieve on scores
B <- cbind(1, S[,1], S[,2], S[,1]^2, S[,2]^2, S[,1]*S[,2])
mu_fit <- lm.fit(x = B, y = Y[idx], w = weights[idx])
```

#### 7.3 Survey-Weighted Imputation (Lambda_ij)
```r
# CORRECT: Weight-aware imputation shares
donor_weights <- omega[neighbors]
lambda_vec <- donor_weights / sum(donor_weights)
Gamma[j] <- Gamma[j] + omega[i] * lambda_vec[k]

# WRONG: Equal weights ignoring survey design
# lambda <- 1 / length(neighbors)
```

#### 7.4 Treatment-Aware Bootstrap
```r
# Separate multinomial for treated/control
m1 <- rmultinom(1, n1, rep(1/n1, n1))[,1]
m0 <- rmultinom(1, n0, rep(1/n0, n0))[,1]

# Apply and calibrate
wb[A == 1] <- weights[A == 1] * m1
wb[A == 0] <- weights[A == 0] * m0
wb[A == 1] <- wb[A == 1] * (sum(weights[A == 1]) / sum(wb[A == 1]))
wb[A == 0] <- wb[A == 0] * (sum(weights[A == 0]) / sum(wb[A == 0]))
```

## Common Pitfalls to Avoid

1. **Hard-coding interaction terms** - Use flags to control inclusion
2. **Wrong model types** - PS always "logit", PG "glm" or "linpred" 
3. **Missing source() in workers** - Causes silent failures
4. **Individual timeouts** - Let SLURM handle job timeouts
5. **Quantile CI for WDSM** - Use normal-based CI
6. **Ignoring survey weights in imputation** - Use weighted lambda_ij
7. **Cross-space matching** - Keep S0 and S1 separate
8. **Refitting on X not scores** - Always refit on score space

## Verification Checklist

Before submitting any simulation:

- [ ] Population data matches intended scenario
- [ ] Sampling mechanism correctly implemented
- [ ] Functions sourced inside parallel workers
- [ ] Model specifications vary correctly by scenario
- [ ] WDSM uses normal CI construction
- [ ] No individual method timeouts
- [ ] Metrics use correct formulas
- [ ] SLURM cores match R script cores
- [ ] Account specified correctly in SLURM

## Expected Performance Patterns

### Model Specification Effects:
- **PS methods**: Similar for (CorCor, CorMis) and (MisCor, MisMis)
- **PG methods**: Similar for (CorCor, MisCor) and (CorMis, MisMis)
- **DSM/WDSM**: Best for CorCor, worst for MisMis

### Method Comparisons:
- **Coverage**: Should be ~93-95% for all correctly implemented methods
- **Bias**: WDSM with fixes should achieve <1% in CorCor
- **SE Ratio**: Should be ~0.95-1.05 (not 0.63 as before fixes)

## File Organization

```
PATE Retrospective [Overlap] M135 [Scenario] GLM/
├── compare_methods_pate_retrospective_mccleary_*.R  # Main script
├── wdsm_ci_functions.R                              # WDSM point estimation
├── wdsm_method2_multinomial_bootstrap.R             # WDSM bootstrap
├── dsmatch-master/                                  # Unweighted methods
└── run_job.sh                                       # SLURM submission
```

## Submission Commands

```bash
# Test run (20 reps)
./submit_20rep_fully_fixed_to_tong.sh

# Check status
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong'

# Download results
for s in CorCor MisCor CorMis MisMis; do
  scp yz2324@login2.mccleary.ycrc.yale.edu:/path/${s}/raw_results_*.RData .
done
```

## References

- Original simulation: `SW_PSW-main/`
- Good overlap reference: `PATE Retrospective Goodoverlap M5 CorCor 1000rep CORRECTED GLM/`
- WDSM theory: See WDSM_CRITICAL_FIXES_NEEDED.md
