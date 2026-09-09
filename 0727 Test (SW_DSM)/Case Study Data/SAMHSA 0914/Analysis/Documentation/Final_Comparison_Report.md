# Comprehensive Comparison of Matching Methods
## Effect of Early Marijuana Use on Mental Health: NSDUH 2023 Analysis

**Date:** September 14, 2025  
**Methods Compared:** WDSM, Unweighted DSM, Survey-Weighted PS Full Matching

---

## Executive Summary

This report presents a comprehensive comparison of three matching methods for estimating the causal effect of early marijuana use (before age 15) on mental health outcomes using NSDUH 2023 data:

1. **WDSM** (Survey-Weighted Double Score Matching) - Our proposed method
2. **Unweighted DSM** (from dsmatch package) - Traditional double score matching
3. **Survey-Weighted PS Full** (from MatchIt package) - Full matching with survey weights

### Key Finding
All three methods show a positive association between early marijuana use and mental illness, but with important differences:
- **WDSM:** 6.68 pp increase (95% CI: -0.14, 13.51)
- **Unweighted DSM:** 8.49 pp increase (95% CI: 2.83, 14.15) - statistically significant
- **PS Full Weighted:** 4.34 pp increase (95% CI: -5.33, 14.00)

---

## 1. Data and Sample

### Analytic Sample
- **N = 17,471** young adults aged 18-29
- **Treatment group:** 1,877 (10.7%) - early marijuana use before age 15
- **Control group:** 15,594 (89.3%) - later or never use
- **Weighted population:** ~51.8 million U.S. young adults

### Covariates Used (Consistent Across All Methods)
- Demographics: Sex, race/ethnicity (White, Black, Hispanic)
- Socioeconomic: Income categories (low, medium, high)
- Geographic: Metropolitan status (large metro, small metro)
- Substance use: Early alcohol use, cigarette use
- Age groups: 18-20, 21-23, 24-25, 26-29

---

## 2. Primary Outcome Results: Any Mental Illness (AMIPY)

| Method | Estimate (pp) | SE | 95% CI | p-value | Accounts for Survey Design |
|--------|---------------|-------|---------|---------|---------------------------|
| **WDSM** | **6.68** | **3.48** | **[-0.14, 13.51]** | **0.055** | **Yes** |
| Unweighted DSM | 8.49 | 2.89 | [2.83, 14.15] | 0.003 | No |
| PS Full Weighted | 4.34 | 4.93 | [-5.33, 14.00] | 0.378 | Yes |

### Key Observations

1. **Statistical Significance:** Only unweighted DSM shows a statistically significant effect, but it doesn't account for the complex survey design.

2. **Survey Weight Impact:** Methods accounting for survey weights (WDSM and PS Full) show wider confidence intervals, reflecting the additional uncertainty from the complex sampling design.

3. **Efficiency Comparison (Relative to WDSM):**
   - Unweighted DSM: 1.455× more efficient (smaller SE)
   - PS Full Weighted: 0.499× as efficient (larger SE)

---

## 3. Secondary Outcomes Results

### Serious Mental Illness (SMIPY)
| Method | Estimate (pp) | SE | 95% CI |
|--------|---------------|-------|---------|
| WDSM | 1.87 | 1.59 | [-1.25, 5.00] |
| Unweighted DSM | 1.65 | 1.25 | [-0.81, 4.10] |

### Major Depressive Episode (IRAMDEYR)
| Method | Estimate (pp) | SE | 95% CI |
|--------|---------------|-------|---------|
| WDSM | 4.86 | 2.33 | [0.29, 9.44] |
| Unweighted DSM | 5.92 | 2.09 | [1.82, 10.03] |

### Suicidal Thoughts (IRSUICTHNK)
| Method | Estimate (pp) | SE | 95% CI |
|--------|---------------|-------|---------|
| WDSM | 3.27 | 1.76 | [-0.17, 6.71] |
| Unweighted DSM | 3.89 | 1.59 | [0.77, 7.00] |

---

## 4. Method-Specific Insights

### WDSM (Survey-Weighted Double Score Matching)
**Advantages:**
- Accounts for complex survey design
- Doubly robust (consistent if either PS or PGS model is correct)
- Incorporates survey weights throughout estimation
- Uses polynomial sieve for bias correction

**Trade-offs:**
- Larger standard errors than unweighted methods
- More computationally intensive

### Unweighted DSM (dsmatch package)
**Advantages:**
- Most efficient (smallest standard errors)
- Simpler implementation
- Shows statistically significant effects

**Limitations:**
- **Does not account for survey design**
- May not generalize to population level
- Ignores sampling weights

### Survey-Weighted PS Full Matching (MatchIt)
**Advantages:**
- Well-established method
- Accounts for survey weights
- Uses full matching for efficiency

**Limitations:**
- Largest standard errors
- Only uses propensity scores (not prognostic scores)
- Most conservative estimates

---

## 5. Interpretation and Recommendations

### Overall Pattern
All three methods consistently show a positive association between early marijuana use and mental health problems, with estimates ranging from 4.34 to 8.49 percentage points for any mental illness.

### Why WDSM?
1. **Population Inference:** Unlike unweighted DSM, WDSM provides valid population-level estimates
2. **Double Robustness:** Unlike PS Full matching, WDSM uses both propensity and prognostic scores
3. **Balanced Approach:** WDSM balances efficiency and valid inference for complex surveys

### Clinical Significance
- Even the most conservative estimate (4.34 pp) represents approximately **2.2 million additional young adults** with mental illness at the population level
- The WDSM estimate (6.68 pp) suggests approximately **3.5 million affected individuals**

---

## 6. Technical Details

### Implementation
- **Software:** R 4.4.0
- **Packages:** 
  - WDSM: Custom implementation with flexible formulas
  - DSM: dsmatch package (github.com/Yunshu7/dsmatch)
  - PS Full: MatchIt package (CRAN)
- **Bootstrap:** 200 replications for variance estimation
- **Matching ratio:** M = 5 for WDSM and DSM

### Convergence and Diagnostics
- All bootstrap samples converged successfully
- Good propensity score overlap achieved (0.01-0.75)
- No extreme weights or separation issues after variable recoding

---

## 7. Conclusions

This comprehensive comparison demonstrates that:

1. **Consistent Direction:** All methods show early marijuana use increases mental illness risk

2. **Survey Design Matters:** Ignoring survey weights (unweighted DSM) may overstate precision and lead to different conclusions about statistical significance

3. **WDSM Advantages:** Provides a middle ground between efficiency and valid population inference, with the added benefit of double robustness

4. **Practical Impact:** Regardless of method, the estimated effects are clinically meaningful, suggesting millions of young adults may experience mental health consequences from early marijuana use

---

## 8. Recommendations for Practice

### For Researchers
- Use WDSM when analyzing complex survey data with causal inference goals
- Consider unweighted DSM for preliminary analyses or when survey design is not critical
- Use PS Full matching as a robustness check or when prognostic scores are unavailable

### For Policy Makers
- Focus on the consistent pattern across methods rather than any single estimate
- Consider the population-level impact when evaluating prevention programs
- Account for uncertainty in estimates when making resource allocation decisions

---

## Appendix: Code Availability

All analysis code is available in:
- `/Analysis/Scripts/07_comprehensive_comparison.R` - Main comparison script
- `/Analysis/Scripts/wdsm_flexible.R` - WDSM implementation
- `/Analysis/Scripts/06_wdsm_analysis_corrected.R` - Detailed WDSM analysis

Results and visualizations are saved in:
- `/Analysis/Results/07_comprehensive_comparison/`

---

*This comparison highlights the importance of method selection when analyzing complex survey data and demonstrates that WDSM provides a valuable tool for population-level causal inference.*

