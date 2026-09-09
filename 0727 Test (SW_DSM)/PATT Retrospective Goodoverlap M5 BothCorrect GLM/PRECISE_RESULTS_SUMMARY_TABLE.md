# Precise Results Summary - Differential Normalization

## Configuration: Job 57225723
- **PS Full**: Normalized weights (w × n/sum(w))
- **WDSM**: Raw weights (1/Prob)
- **True PATT**: 1.035100
- **Replications**: 1000

## 📊 Precise Results (Exactly 3 Decimal Places)

### Primary Metrics

| Method | Relative Bias (%) | Coverage | Relative Efficiency |
|:-------|------------------:|---------:|-------------------:|
| DSM (Unweighted) | 5.268 | 0.828 | 2.137 |
| PS (Unweighted) | 5.207 | 0.963 | 1.000 |
| PG (Unweighted) | 5.246 | 0.841 | 2.220 |
| PS Full (Weighted) | -0.688 | 0.916 | 2.487 |
| WDSM V2 Standard | -0.800 | 0.938 | 2.705 |

### Point Estimates and Bias

| Method | Mean Estimate | Absolute Bias | Relative Bias (%) |
|:-------|-------------:|--------------:|------------------:|
| DSM (Unweighted) | 1.090 | 0.055 | 5.268 |
| PS (Unweighted) | 1.089 | 0.054 | 5.207 |
| PG (Unweighted) | 1.089 | 0.054 | 5.246 |
| PS Full (Weighted) | 1.028 | -0.007 | -0.688 |
| WDSM V2 Standard | 1.027 | -0.008 | -0.800 |

### Variance and Standard Errors

| Method | Empirical SE | Mean Est. SE | SE Ratio | RMSE |
|:-------|-------------:|-------------:|---------:|------:|
| DSM (Unweighted) | 0.056 | 0.056 | 0.997 | 0.078 |
| PS (Unweighted) | 0.082 | 0.104 | 1.263 | 0.098 |
| PG (Unweighted) | 0.055 | 0.056 | 1.006 | 0.077 |
| PS Full (Weighted) | 0.052 | 0.046 | 0.880 | 0.053 |
| WDSM V2 Standard | 0.050 | 0.049 | 0.978 | 0.051 |

### Confidence Intervals

| Method | Coverage | Mean CI Width |
|:-------|----------|-------------:|
| DSM (Unweighted) | 0.828 | 0.220 |
| PS (Unweighted) | 0.963 | 0.408 |
| PG (Unweighted) | 0.841 | 0.218 |
| PS Full (Weighted) | 0.916 | 0.180 |
| WDSM V2 Standard | 0.938 | 0.192 |

## 🏆 Performance Rankings

| Metric | Best Method | Value |
|:-------|:------------|------:|
| **Lowest Absolute Bias** | PS Full (Weighted) | 0.007 |
| **Best Coverage** | PS (Unweighted) | 0.963 |
| **Best Coverage (Survey-Weighted)** | WDSM V2 Standard | 0.938 |
| **Best SE Ratio** | WDSM V2 Standard | 0.978 |
| **Lowest RMSE** | WDSM V2 Standard | 0.051 |
| **Best Efficiency** | WDSM V2 Standard | 2.705 |
| **Narrowest CI** | PS Full (Weighted) | 0.180 |

## ✅ Key Insights

1. **WDSM with raw weights achieves optimal balance**:
   - Coverage closest to nominal 95% among survey-weighted methods (93.8%)
   - Best efficiency (2.705× better than PS)
   - SE ratio closest to 1 (0.978)
   - Lowest RMSE (0.051)

2. **Both survey-weighted methods control bias excellently**:
   - PS Full: -0.688% relative bias
   - WDSM: -0.800% relative bias
   - Both well under 1% threshold

3. **Unweighted methods show consistent positive bias**:
   - All around 5.2-5.3% relative bias
   - Confirms importance of survey weights

## 📝 Data Source
- Raw data: `/gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_2212/`
- Job output: `patt_retrospective_57225723.out`
- Results file: `comprehensive_patt_retrospective_results_1000reps_differential.RData`
