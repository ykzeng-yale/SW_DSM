# Final Results Tables for NHANES Analysis

## Table 1: Average controlled difference (ACD) estimates and corresponding 95% confidence intervals across various analytic approaches for the comparison of effect of race (non-Hispanic Black versus non-Hispanic White participants) on log-transformed telomere length among n = 5,270 participants in the National Health and Nutrition Examination Survey (NHANES).

| Method | ACD Estimate | 95% Confidence Interval |
|--------|--------------|------------------------|
| **Unweighted Double Score Matching (DSM)** | 0.0232 | 0.0022, 0.0443 |
| **Survey-Weighted PS Full Matching** | -0.0321 | -0.0572, -0.0069 |
| **Weighted Double Score Matching (WDSM)** | 0.0156 | -0.0033, 0.0393 |

---

## Table 2: Population average treatment effect (PATE) estimates and corresponding 95% confidence intervals across various analytic approaches for the effect of lead exposure (dichotomized at median) on log-transformed telomere length among n = 5,267 participants in the National Health and Nutrition Examination Survey (NHANES).

| Method | PATE Estimate | 95% Confidence Interval |
|--------|---------------|------------------------|
| **Unweighted Double Score Matching (DSM)** | -0.0014 | -0.0176, 0.0148 |
| **Survey-Weighted PS Full Matching** | -0.0109 | -0.0300, 0.0083 |
| **Weighted Double Score Matching (WDSM)** | -0.0033 | -0.0215, 0.0152 |

---

## Interpretation

### Race Analysis (Table 1):
- **DSM (Unweighted)**: Shows a significant positive effect (0.0232, p < 0.05), suggesting Black individuals have 2.35% longer telomeres
- **PS Full Matching**: Shows a significant NEGATIVE effect (-0.0321, p < 0.05), suggesting Black individuals have 3.15% SHORTER telomeres
- **WDSM**: Shows a non-significant positive effect (0.0156, p > 0.05), suggesting Black individuals have 1.58% longer telomeres

The conflicting results highlight the importance of proper survey weight incorporation. WDSM provides the most balanced approach by incorporating weights throughout the matching process while maintaining double robustness.

### Lead Exposure Analysis (Table 2):
- All methods show negative effects (reduced telomere length with higher lead exposure)
- None of the effects are statistically significant at the 0.05 level
- Effect sizes range from -0.14% (DSM) to -1.08% (PS Full Matching)
- WDSM shows -0.33% reduction, much smaller than Salerno's reported 3.3-5.0% reduction

The consistency in direction (negative) but variability in magnitude demonstrates how methodological choices affect effect size estimates even when statistical significance is consistent.

---

## Comparison with Salerno et al.

### Original Salerno Results (Race Analysis):
| Method | ACD Estimate | 95% Confidence Interval |
|--------|--------------|------------------------|
| Multiple Regression | 0.0265 | 0.0106, 0.0423 |
| IPTW Estimator | 0.0263 | 0.0080, 0.0446 |
| Survey-Weighted Multiple Regression | 0.0298 | -0.0012, 0.0607 |
| Outcome Modeling and Direct Standardization | 0.0176 | -0.0030, 0.0381 |
| Inverse Probability Weighting 1 | 0.0150 | -0.0151, 0.0451 |
| Inverse Probability Weighting 2 | 0.0132 | -0.0081, 0.0345 |

Our WDSM estimate (0.0156) aligns closely with Salerno's propensity score-based methods (0.0132-0.0176), all showing non-significant effects after proper adjustment.

---

## Key Methodological Insights

1. **Survey Weight Impact**: Ignoring survey weights (DSM) can lead to false positive findings
2. **Double Robustness**: WDSM and DSM provide protection against model misspecification through dual score usage
3. **Direction Sensitivity**: PS Full Matching shows opposite direction from other methods in race analysis
4. **Conservative Estimates**: WDSM generally provides more conservative estimates with proper uncertainty quantification



