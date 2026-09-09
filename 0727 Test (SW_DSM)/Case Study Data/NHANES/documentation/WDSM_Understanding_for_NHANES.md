# Comprehensive Understanding of WDSM for NHANES Telomere Length Analysis

## Executive Summary

I have thoroughly studied the Weighted Double Score Matching (WDSM) methodology and understand how to apply it to estimate the Population Average Treatment Effect (PATE) of race on telomere length in the NHANES data, properly accounting for the complex survey design and socioeconomic confounders.

---

## Part 1: Understanding WDSM Theory

### 1.1 Core Innovation of WDSM

WDSM extends Double Score Matching (DSM) to complex survey data by:

1. **Double Score Framework**: Uses BOTH propensity scores AND prognostic scores for matching
   - Propensity Score: `e(X) = P(A=1|X)` - probability of treatment (being Black)
   - Prognostic Score: `Ψ_z(X) = E[Y(z)|X]` - expected outcome under treatment z
   - Double Score: `D_z = (e(X), Ψ_z(X))` - 2-dimensional matching variable

2. **Survey Weight Integration**: Properly incorporates survey weights at THREE critical stages:
   - Score estimation (weighted regression)
   - Within-match imputation (weighted averaging)
   - Final aggregation (Hájek normalization)

3. **Double Robustness**: Maintains consistency if EITHER:
   - Propensity score model is correctly specified, OR
   - Prognostic score model is correctly specified

### 1.2 Key Theoretical Components

#### Retrospective vs Prospective Sampling
- **Retrospective** (NHANES case): `P(S=1|X,Z)` - sampling depends on treatment
  - Different sampling rates for Black vs White participants
  - Requires treatment-specific weights: `w_z,i = 1/P(S=1|X,Z=z)`
  
- **Prospective**: `P(S=1|X)` - sampling independent of treatment
  - Common weights across treatment groups

#### Weighted Reuse Factor
```
K̃_z,j = Σ_i [w_{1-z,i} × I(j ∈ matches(i))] / [Σ_k∈matches(i) w_z,k]
```
This captures how often unit j is used as a donor, weighted by survey design.

#### Bias Correction via Polynomial Sieve
Uses polynomial expansion to approximate the true outcome model:
```
μ̂_bc = β₀ + β₁μ + β₂μ² + β₃e + β₄e² + β₅(e×μ)
```

---

## Part 2: Application to NHANES Telomere Length Study

### 2.1 NHANES Context Mapping

| WDSM Component | NHANES Application |
|----------------|-------------------|
| **Treatment (A)** | Race: 1 = Non-Hispanic Black, 0 = Non-Hispanic White |
| **Outcome (Y)** | Log-transformed telomere length (lTELOMEAN) |
| **Confounders (X)** | 12 SES indicators + demographics + blood composition |
| **Survey Weight** | WTMEC4YR (4-year MEC exam weight) |
| **Sampling Design** | RETROSPECTIVE - oversampling of Black participants |
| **Target Estimand** | PATE: E[Y(1) - Y(0)] in US population |

### 2.2 Why WDSM is Superior for NHANES

1. **Handles Retrospective Sampling**: NHANES deliberately oversamples Black participants
   - Traditional methods may fail to account for this informative sampling
   - WDSM uses treatment-specific weights appropriately

2. **Double Robustness**: Critical given model uncertainty
   - Propensity model: `Race ~ SES variables` (may be misspecified)
   - Prognostic model: `Telomere ~ SES + demographics + blood` (complex biology)
   - WDSM remains consistent if either model is correct

3. **Dimension Reduction**: Matches on 2D score instead of 20+ covariates
   - Reduces curse of dimensionality
   - Improves match quality with limited sample size

4. **Proper Survey Weight Usage**: Unlike disputed approaches in literature
   - Incorporates weights in score estimation (not just as covariate)
   - Weights within-match averaging
   - Uses Hájek normalization for population inference

### 2.3 NHANES-Specific Implementation Details

#### Step 1: Data Preparation
```r
# Load complete cases (n=5,270)
nhanes <- readRDS("data/nhanes_complete_cases.rds")

# Define variables
Y <- nhanes$lTELOMEAN  # Log telomere length
A <- nhanes$RACE_2CAT   # Race (1=Black, 0=White)
w <- nhanes$WTMEC4YR    # Survey weights

# Confounders matrix
X <- model.matrix(~ EDUC_3CAT + MARTL_3CAT + PIR_3CAT + 
                    EMPSTAT_4CAT + OCC_5CAT + HHSIZE_5CAT + 
                    HHINC_5CAT + HIQ_2CAT + WIC_2CAT + 
                    FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT + 
                    AGE + SEX + LBXWBCSI + LBXLYPCT + 
                    LBXMOPCT + LBXNEPCT + LBXEOPCT + LBXBAPCT, 
                  data = nhanes)[,-1]
```

#### Step 2: Score Estimation with Survey Weights
```r
# Propensity score (with potential interaction)
ps_model <- glm(A ~ X1 + X2 + ... + X1:X2, 
                family = quasibinomial(),
                weights = w)
e_score <- fitted(ps_model)

# Prognostic scores (separate for each treatment)
prog0_model <- lm(Y ~ X1 + X2 + ... + X1:X2, 
                  data = subset(nhanes, A==0),
                  weights = w[A==0])
psi0 <- predict(prog0_model, newdata = nhanes)

prog1_model <- lm(Y ~ X1 + X2 + ... + X1:X2,
                  data = subset(nhanes, A==1), 
                  weights = w[A==1])
psi1 <- predict(prog1_model, newdata = nhanes)
```

#### Step 3: Polynomial Sieve Bias Correction
```r
# Bias correction for prognostic scores
sieve_vars_0 <- cbind(psi0, psi0^2, e_score, e_score^2, e_score*psi0)
bc0_model <- lm(Y ~ ., data = sieve_vars_0[A==0,], weights = w[A==0])
mu0_bc <- predict(bc0_model, newdata = sieve_vars_0)

# Similar for treated group
```

#### Step 4: Double Score Matching
```r
# Standardize scores
D0_std <- scale(cbind(e_score, mu0_bc))
D1_std <- scale(cbind(e_score, mu1_bc))

# For each unit, find M=5 nearest neighbors in opposite treatment
# using Euclidean distance in standardized double score space
```

#### Step 5: Weighted Imputation
```r
# For control units, impute Y(1) using weighted average of matched treated
Y_hat_1[A==0] <- weighted.mean(Y[matches], w[matches])

# For treated units, impute Y(0) using weighted average of matched controls  
Y_hat_0[A==1] <- weighted.mean(Y[matches], w[matches])
```

#### Step 6: PATE Estimation
```r
# Hájek-type estimator
tau_WDSM <- sum(w * (Y_hat_1 - Y_hat_0)) / sum(w)
```

### 2.4 Variance Estimation: Multinomial Bootstrap

For retrospective sampling (NHANES case), use multinomial bootstrap:

```r
# Generate multinomial weights
m_star <- rmultinom(1, n, rep(1/n, n))
w_boot <- m_star * w  # Multiply by survey weights

# Re-estimate all models with bootstrap weights
# Compute bootstrap PATE estimate
# Repeat B=500 times for variance estimation
```

---

## Part 3: Key Advantages Over Salerno et al. Methods

### 3.1 Comparison with Paper's Methods

| Method (Salerno) | Limitation | WDSM Solution |
|-----------------|------------|---------------|
| **Multiple Regression** | Model dependent, no weight incorporation | Double robust, survey-weighted |
| **Survey-Weighted Regression** | Single model, high-dimensional | Dimension reduction via scores |
| **IPTW** | Propensity score only, extreme weights | Also uses prognostic score, bounded weights |
| **IPW1/IPW2** | Complex weight formulation | Intuitive matching framework |
| **Outcome Modeling** | Requires correct outcome model | Double robust protection |

### 3.2 Specific Improvements

1. **Model Robustness**: Paper's methods require correct model specification
   - WDSM maintains consistency with partial misspecification
   - Critical for complex telomere biology

2. **Interpretability**: Matching creates explicit counterfactual comparisons
   - Can examine matched pairs
   - Assess balance diagnostics

3. **Efficiency**: Better variance properties through:
   - Dimension reduction (2D vs 20+D)
   - Optimal use of survey weights
   - Bias correction via polynomial sieve

4. **Theoretical Foundation**: Rigorous asymptotic theory
   - Proven consistency and asymptotic normality
   - Valid variance estimation for complex surveys

---

## Part 4: Expected Results and Interpretation

### 4.1 Anticipated Findings

Based on the paper's results and WDSM advantages:

1. **Point Estimate**: Expect ACD around 0.010-0.015
   - Lower than naive estimate (0.0265)
   - Similar to paper's adjusted methods

2. **Confidence Interval**: Likely includes zero
   - Suggesting no significant racial difference after SES adjustment
   - Wider than simple methods due to proper uncertainty quantification

3. **Interpretation**: After balancing SES between racial groups:
   - Telomere length differences largely disappear
   - Supporting socioeconomic explanation over genetic factors

### 4.2 Diagnostic Checks

Before accepting results, verify:

1. **Covariate Balance**: Standardized differences < 0.1 after matching
2. **Common Support**: Sufficient overlap in double scores
3. **Match Quality**: Average distance to matches reasonable
4. **Weight Distribution**: No extreme weights dominating

---

## Part 5: Implementation Strategy

### 5.1 Phased Approach

**Phase 1: Basic WDSM**
- Implement core matching algorithm
- Use standard models (no interactions initially)
- Verify against simulation results

**Phase 2: Model Refinement**
- Test interaction terms (X1:X2)
- Compare different M values (3, 5, 7)
- Assess sensitivity to model specification

**Phase 3: Full Analysis**
- Complete bootstrap inference (B=500)
- Sensitivity analyses
- Comparison with Salerno methods

### 5.2 Code Organization

```
wdsm_nhanes_analysis/
├── 01_data_prep.R           # Prepare NHANES for WDSM
├── 02_score_estimation.R    # Estimate PS and PGS
├── 03_wdsm_matching.R       # Core WDSM algorithm
├── 04_bootstrap_inference.R # Variance estimation
├── 05_diagnostics.R         # Balance and quality checks
└── 06_comparison.R          # Compare with paper methods
```

---

## Conclusion

I have a comprehensive understanding of WDSM theory and its application to the NHANES telomere length analysis. The method is particularly well-suited for this problem because:

1. **NHANES uses retrospective sampling** with deliberate oversampling of Black participants
2. **Model uncertainty is high** given complex biological and social mechanisms
3. **Survey weights are critical** for population-level inference
4. **Double robustness provides protection** against model misspecification

The WDSM approach will provide more reliable estimates of the racial difference in telomere length after accounting for SES, with proper uncertainty quantification that respects the complex survey design.

Ready to proceed with implementation upon your approval.



