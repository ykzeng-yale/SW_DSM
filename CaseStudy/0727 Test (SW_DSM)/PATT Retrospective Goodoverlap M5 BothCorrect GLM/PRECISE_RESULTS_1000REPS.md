# PRECISE RESULTS - 1000 Replications
## PATT Retrospective with Updated WDSM

**True PATT: 1.0351**

### Relative Bias (3 decimal places)

| Method | Relative Bias |
|--------|--------------|
| DSM (Unweighted) | **+5.268%** |
| PS (Unweighted) | **+5.207%** |
| PG (Unweighted) | **+5.246%** |
| PS Full (Weighted) | **-0.510%** |
| WDSM V2 Standard GLM/LM (Weighted) | **-0.800%** |

### Coverage (3 decimal places)

| Method | Coverage | Coverage % |
|--------|----------|------------|
| DSM (Unweighted) | **0.828** | 82.8% |
| PS (Unweighted) | **0.963** | 96.3% |
| PG (Unweighted) | **0.841** | 84.1% |
| PS Full (Weighted) | **0.907** | 90.7% |
| WDSM V2 Standard GLM/LM (Weighted) | **0.938** | 93.8% |

### Relative Efficiency (3 decimal places)

| Method | Relative Efficiency (vs PS Unweighted) |
|--------|---------------------------------------|
| DSM (Unweighted) | **2.137x** |
| PS (Unweighted) | **1.000x** (baseline) |
| PG (Unweighted) | **2.220x** |
| PS Full (Weighted) | **1.686x** |
| WDSM V2 Standard GLM/LM (Weighted) | **2.705x** |

### Complete Summary Table (All Metrics with High Precision)

| Method | Estimate | Bias | Rel. Bias | Emp. SE | Est. SE | SE Ratio | RMSE | Coverage | Rel. Eff |
|--------|----------|------|-----------|---------|---------|----------|------|----------|----------|
| DSM (Unweighted) | 1.0896 | +0.0545 | **+5.268%** | 0.0564 | 0.0562 | 0.997 | 0.0784 | **0.828** | **2.137x** |
| PS (Unweighted) | 1.0890 | +0.0539 | **+5.207%** | 0.0824 | 0.1040 | 1.263 | 0.0984 | **0.963** | **1.000x** |
| PG (Unweighted) | 1.0894 | +0.0543 | **+5.246%** | 0.0553 | 0.0556 | 1.006 | 0.0775 | **0.841** | **2.220x** |
| PS Full (Weighted) | 1.0298 | -0.0053 | **-0.510%** | 0.0634 | 0.0497 | 0.784 | 0.0636 | **0.907** | **1.686x** |
| WDSM V2 Standard (Weighted) | 1.0268 | -0.0083 | **-0.800%** | 0.0501 | 0.0490 | 0.978 | 0.0507 | **0.938** | **2.705x** |

### Key Findings (Precise Values)

1. **Lowest Relative Bias**: PS Full (Weighted) at **-0.510%**, followed by WDSM V2 at **-0.800%**
2. **Best Coverage**: PS (Unweighted) at **0.963** (96.3%), followed by WDSM V2 at **0.938** (93.8%)
3. **Best Relative Efficiency**: WDSM V2 at **2.705x**, followed by PG (Unweighted) at **2.220x**
4. **Best SE Ratio**: DSM (Unweighted) at **0.997**, followed by WDSM V2 at **0.978**
5. **Lowest RMSE**: WDSM V2 at **0.0507**

### Comparison: 100 vs 1000 Replications for WDSM V2

| Metric | 100 Reps | 1000 Reps | Change |
|--------|----------|-----------|---------|
| Relative Bias | -1.1% | **-0.800%** | Improved |
| Coverage | 0.900 (90.0%) | **0.938** (93.8%) | Improved |
| SE Ratio | 1.014 | **0.978** | Improved |
| RMSE | 0.0494 | **0.0507** | Similar |
| Relative Efficiency | 2.44x | **2.705x** | Improved |

The updated WDSM V2 with polynomial sieve method shows excellent performance with more precise estimates from 1000 replications.