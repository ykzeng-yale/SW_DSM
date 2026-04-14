# Case Study Analyses

Corrected case study analyses for the paper using the `wdsmatch` R package.

## Case Study 1: NSDUH — Early Marijuana Use and Mental Illness

- **Data**: 2023 National Survey on Drug Use and Health (NSDUH)
- **Sampling design**: **Prospective** (non-informative) — PS estimated without survey weights
- **Treatment**: Early marijuana use initiation (before age 15)
- **Outcomes**: AMIPY (any mental illness past year), SMIPY (serious mental illness past year)
- **N**: 17,471 young adults aged 18–29
- **Methods**: PSM, PGM, DSM, SW-PSM, WDSM (M=5)

### Corrected WDSM Results (M=5, B=200)

| Outcome | Estimate | 95% CI |
|---------|----------|--------|
| AMIPY | 0.060 | [0.033, 0.147] |
| SMIPY | 0.026 | [0.007, 0.114] |

## Case Study 2: NHANES — Short Sleep Duration and HbA1c

- **Data**: NHANES 2007–2018
- **Sampling design**: **Retrospective** (informative) — PS estimated with survey weights
- **Treatment**: Short sleep duration (<7 hours/night)
- **Outcome**: HbA1c (% glycated hemoglobin)
- **N**: 3,793 non-diabetic adults aged 40–70
- **Methods**: PSM, PGM, DSM, SW-PSM, WDSM (M=1,3,5)

### Corrected WDSM Results (B=200)

| M | Estimate | 95% CI |
|---|----------|--------|
| 1 | 0.116 | [0.023, 0.140] |
| 3 | 0.086 | [0.023, 0.140] |
| 5 | 0.079 | [0.023, 0.140] |

## Bugs Fixed in Corrected Analysis

1. PGS was estimated with survey weights (should be unweighted per Eq. 4)
2. NHANES sieve used probability-scale PS (should use logit)
3. NSDUH was treated as retrospective (should be prospective)
4. Bootstrap PGS re-estimation used survey weights (should use multinomial only)

## Files

```
CaseStudy/
├── README.md
├── NSDUH/
│   ├── run_wdsm_corrected.R          Corrected analysis using wdsmatch package
│   ├── 11_complete_both_outcomes.R    Original full comparison script
│   └── wdsm_flexible_OLD_BUGGY.R     Old WDSM function (buggy, for reference)
├── NHANES/
│   ├── run_wdsm_corrected.R          Corrected analysis using wdsmatch package
│   ├── ANALYSIS_10_SLEEP_HBA1C_FIXED.R  Original analysis script
│   └── WDSM_PATE_Retrospective_OLD_BUGGY.R  Old WDSM function (buggy)
└── Figures/
    ├── CaseStudy_Combined_WDSM.png   Updated figure
    ├── CaseStudy_Combined_WDSM.pdf
    └── visualize_casestudy.R         Figure generation script
```
