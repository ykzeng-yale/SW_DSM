# MOORE 2025: COMPLETE ALL MATCHING METHODS ANALYSIS

**Date**: October 23, 2025  
**Script**: `Analysis/Scripts/MOORE_2025_COMPLETE_ALL_METHODS.R`  
**Status**: ✅ **READY TO RUN**

---

## 📋 OVERVIEW

This script applies **ALL 5 matching methods** to the Moore & Kapadia (2025) study's research question, with **full bootstrap inference (B=200)** for all methods.

### **Research Question**
Does being female (vs male) affect health outcomes among adults with substance use disorders?

### **Data Source**
- **NSDUH 2021-2023** pooled data
- **Sample**: Adults 18+ with past-year SUD (`UD5ILALANY == 1`)
- **N ≈ 9,465** (exact N after complete case filtering)

### **Outcomes**
1. **STI**: Sexually transmitted infection diagnosis past year (`STDANYYR`)
2. **SPD**: Serious psychological distress past year (`SPDPSTYR`)

### **Exposure**
- **Female (A=1)** vs **Male (A=0)** [Reference: `IRSEX`]

### **Covariates** (22 dummy variables)
- **Age**: 26-34, 35-49, 50-64, 65+ (ref: 18-25)
- **Race/ethnicity**: Black, Native American, Asian, Multi-race, Hispanic (ref: White)
- **Marital**: Widowed, Divorced, Separated, Never married (ref: Married)
- **Education**: HS grad, Some college, College grad (ref: <HS)
- **Insurance**: Insured vs uninsured
- **Employment**: Part-time, Unemployed, Other (ref: Full-time)
- **Poverty**: 100-200%, >200% FPL (ref: <100%)

---

## 🎯 METHODS IMPLEMENTED

### **1. WDSM (Survey-Weighted Double Score Matching)**
- **M = 5** matches (for stability with survey weights)
- **B = 200** bootstrap samples
- **Uses**: Survey weights (`ANALWT2_C1`) throughout
- **Implementation**: `wdsm_flexible()` function
- **Key feature**: Combines propensity and prognostic scores with survey design

```r
wdsm_result <- wdsm_flexible(
  data = moore_data,
  outcome_var = "Y",
  treatment_var = "A",
  ps_formula = ps_formula,
  pgs_formula = pgs_formula,
  weight_var = "w",
  M = 5,  # CRITICAL for survey-weighted
  B = 200
)
```

### **2. DSM (Unweighted Double Score Matching)**
- **M = 1** match (standard unweighted)
- **B = 200** bootstrap samples
- **Uses**: Both PS and PGS
- **Implementation**: `dsmatchATE(..., method="dsm")`

```r
dsm_result <- dsmatchATE(
  Y = Y,
  X = X,
  Treatment = A,
  method = "dsm",
  model.ps = "logit",
  model.pg = "linpred",
  lp.pg = X,
  M = 1,
  boots = 200
)
```

### **3. PSM (Unweighted Propensity Score Matching)**
- **M = 1** match
- **B = 200** bootstrap samples
- **Uses**: Propensity score only
- **Implementation**: `dsmatchATE(..., method="ps")`

```r
psm_result <- dsmatchATE(
  Y = Y,
  X = X,
  Treatment = A,
  method = "ps",
  model.ps = "logit",
  M = 1,
  boots = 200
)
```

### **4. PGM (Unweighted Prognostic Score Matching)**
- **M = 1** match
- **B = 200** bootstrap samples
- **Uses**: Prognostic score only
- **Implementation**: `dsmatchATE(..., method="pg")`

```r
pgm_result <- dsmatchATE(
  Y = Y,
  X = X,
  Treatment = A,
  method = "pg",
  model.pg = "linpred",
  lp.pg = X,
  M = 1,
  boots = 200
)
```

### **5. PS Full (Survey-Weighted Full Matching)**
- **Full matching** (uses all units)
- **Survey-weighted** (`s.weights = ~ sw`)
- **Implementation**: `matchit()` + `marginaleffects::avg_comparisons()`

```r
m_ps <- matchit(
  formula,
  data = match_data,
  method = "full",
  distance = "glm",
  link = "logit",
  s.weights = ~ sw,
  estimand = "ATE"
)
```

---

## 📊 OUTPUT STRUCTURE

### **1. Console Output**
- Real-time progress for each method
- Point estimates, SEs, and 95% CIs
- Formatted summary tables for both outcomes

### **2. Saved Objects**
```r
# Main results
saveRDS(all_results, "Analysis/Results/moore_2025_complete_all_methods.rds")

# Structure:
# all_results$STI$wdsm = list(estimate, se, ci_lower, ci_upper)
# all_results$STI$dsm = list(estimate, se, ci_lower, ci_upper)
# all_results$STI$psm = list(estimate, se, ci_lower, ci_upper)
# all_results$STI$pgm = list(estimate, se, ci_lower, ci_upper)
# all_results$STI$ps_full = list(estimate, se, ci_lower, ci_upper)
# all_results$SPD$... (same structure)
```

### **3. Comparison Table**
```r
write.csv(comparison_table, "Analysis/Results/moore_2025_comparison_table.csv")

# Columns:
# - Method: WDSM, DSM, PSM, PGM, PS Full
# - Outcome: STI, SPD
# - Estimate: Point estimate (risk difference)
# - SE: Standard error
# - CI_Lower: 95% CI lower bound
# - CI_Upper: 95% CI upper bound
# - CI_Width: Confidence interval width
# - M: Number of matches (5 for WDSM, 1 for others)
# - Weighted: TRUE for WDSM/PS Full, FALSE for others
```

---

## 🔍 COMPARISON WITH MOORE'S ORIGINAL RESULTS

### **Moore's Published Results**
- **Method**: Survey-weighted logistic regression
- **Estimates**: Adjusted odds ratios (aOR)
- **STI**: aOR = 2.00 (1.25–3.20) → **Female 2× higher odds**
- **SPD**: aOR = 2.06 (1.72–2.47) → **Female 2× higher odds**

### **Our Analysis**
- **Methods**: 5 different matching approaches
- **Estimates**: Risk differences (probability scale)
- **Advantages**:
  1. **Causal interpretation**: Direct effect on probability
  2. **Method comparison**: 5 different approaches
  3. **Robustness check**: Consistency across methods
  4. **Model-free**: Matching + outcome regression

### **Interpretation Note**
- Moore's **aOR = 2.00** means females have **2× the odds** of STI
- Our estimates will be **risk differences** (e.g., 0.05 = 5 percentage point increase)
- Both measure the **same causal effect**, just different scales
- To compare: Can convert our estimates to odds ratios if needed

---

## 🚀 HOW TO RUN

### **Prerequisites**
```r
# Ensure these are loaded:
library(tidyverse)
library(survey)
library(MatchIt)
library(marginaleffects)
library(Matching)

# And sourced:
source("dsmatch-master/R/*.R")  # All dsmatch functions
source("Analysis/Scripts/wdsm_flexible.R")
```

### **Execution**
```bash
# Option 1: R terminal
cd "/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914"
Rscript Analysis/Scripts/MOORE_2025_COMPLETE_ALL_METHODS.R

# Option 2: RStudio
# Open and run the script directly
```

### **Runtime Estimate**
- **WDSM**: ~5-10 minutes (B=200, M=5)
- **DSM**: ~3-5 minutes (B=200, M=1)
- **PSM**: ~2-3 minutes (B=200, M=1)
- **PGM**: ~2-3 minutes (B=200, M=1)
- **PS Full**: ~1-2 minutes
- **Total**: ~15-25 minutes for both outcomes

---

## 📈 EXPECTED RESULTS PATTERN

Based on Moore's findings and our previous analyses:

### **STI Outcome**
- **Small effect size**: Baseline risk ~1-3%
- **Positive effect**: Female > Male
- **Large CIs**: Due to low prevalence
- **Method agreement**: Expect similar direction across methods

### **SPD Outcome**
- **Larger effect size**: Baseline risk ~10-15%
- **Strong positive effect**: Female >> Male
- **Tighter CIs**: Higher prevalence = more precision
- **Robust finding**: Should be consistent across all 5 methods

### **Cross-Method Comparison**
- **WDSM vs PS Full**: Should be similar (both survey-weighted)
- **DSM vs PSM vs PGM**: Should differ slightly (unweighted, different scores)
- **All methods**: Should agree on direction (positive effect)

---

## ✅ VALIDATION CHECKLIST

After running, verify:

1. ✅ **Sample size matches**: N ≈ 9,465
2. ✅ **All methods completed**: No NAs in results
3. ✅ **Positive estimates**: Female > Male for both outcomes
4. ✅ **SPD effect > STI effect**: Higher prevalence = larger effect
5. ✅ **CI coverage**: All CIs exclude zero (significant effects)
6. ✅ **Survey weights**: WDSM and PS Full use weights correctly
7. ✅ **Bootstrap convergence**: B=200 completed for all methods

---

## 🔧 TROUBLESHOOTING

### **Error: "Object not found"**
→ Check that all dsmatch functions are sourced correctly

### **Error: "Convergence failed"**
→ For WDSM: May need to adjust M or check for extreme weights
→ For PS models: Check for perfect separation in covariates

### **Warning: "Some bootstrap samples failed"**
→ Normal for a small percentage (<10%)
→ If >20% fail, investigate convergence issues

### **Different from Moore's results**
→ **Expected!** Different methods + risk difference vs odds ratio
→ Focus on **direction** and **significance**, not exact magnitude

---

## 📚 COMPARISON WITH `11_complete_both_outcomes.R`

### **Similarities**
- Same overall structure and function design
- Same bootstrap approach (B=200)
- Same parameter patterns for `dsmatchATE`
- Same error handling with `tryCatch()`

### **Differences**
| Feature | Moore 2025 | Lu 2023 (Script 11) |
|---------|-----------|---------------------|
| **Sample** | Adults 18+ with SUD | Young adults 18-29 |
| **Exposure** | Female vs Male | Early MJ use |
| **Outcomes** | STI, SPD | AMIPY, SMIPY |
| **N** | ~9,465 | ~17,625 |
| **Covariates** | 22 variables | 14 variables |
| **Weights** | ANALWT2_C1 (pooled) | ANALWT2_C |

---

## 🎓 METHODOLOGICAL CONTRIBUTIONS

### **Why This Analysis Matters**

1. **First comprehensive comparison** of matching methods for Moore's question
2. **Extends Moore's analysis** beyond logistic regression
3. **Provides causal estimates** on probability scale (more interpretable)
4. **Robustness check** across 5 different approaches
5. **Survey-weighted inference** properly implemented

### **Novel Aspects**

1. **WDSM applied to sex disparities**: First application to gender/health
2. **Full method comparison**: All 5 methods on same data
3. **Bootstrap for all**: Consistent B=200 across methods
4. **Survey weights integrated**: WDSM and PS Full use design weights

---

## 📝 CITATION

If using this analysis:

```
Moore RE, Kapadia SN. Sex-Based Disparities in Health Outcomes Among Persons 
with Substance Use Disorder. J Gen Intern Med. 2025. PMID: 40758304.

Analysis extended using 5 matching methods (WDSM, DSM, PSM, PGM, PS Full) 
with bootstrap inference (B=200). Data: NSDUH 2021-2023 pooled.
```

---

## ✅ STATUS

**Script**: ✅ Complete and ready to run  
**Data**: ✅ Available (NSDUH 2021-2023)  
**Functions**: ✅ All sourced and tested  
**Documentation**: ✅ This guide  

**Next Steps**: 
1. Run the script
2. Review results
3. Compare with Moore's original findings
4. Create visualization comparing all 5 methods
5. Write up methods comparison

---

**Last Updated**: October 23, 2025  
**Maintained By**: Data Analysis Team



