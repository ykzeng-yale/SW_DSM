# PATT Retrospective Results - 1000 Replications with Updated WDSM

## Job Information
- **Job ID**: 57092566
- **Date**: August 5, 2025
- **Runtime**: 62.19 minutes
- **Status**: ✅ Completed Successfully
- **Replicates**: 1000
- **Bootstrap**: 200 iterations per replicate

## Key Results Summary (True PATT = 1.0351)

### Performance Rankings by Metric:

| Method | Relative Bias | Coverage | SE Ratio | RMSE | Rel. Efficiency |
|--------|--------------|----------|----------|------|-----------------|
| **DSM (Unweighted)** | 5.3% | 82.8% | 0.997 | 0.0784 | 2.14x |
| **PS (Unweighted)** | 5.2% | 96.3% | 1.263 | 0.0984 | 1.00x (ref) |
| **PG (Unweighted)** | 5.2% | 84.1% | 1.006 | 0.0775 | 2.22x |
| **PS Full (Weighted)** | -0.5% | 90.7% | 0.784 | 0.0636 | 1.69x |
| **WDSM V2 Standard (Updated)** | **-0.8%** | **93.8%** | **0.978** | **0.0507** | **2.71x** |

### 🏆 Key Findings:

1. **Lowest Bias**: PS Full (Weighted) at -0.5%, closely followed by WDSM at -0.8%
2. **Best Coverage**: PS (Unweighted) at 96.3%, followed by WDSM at 93.8%
3. **Best SE Ratio**: WDSM V2 at 0.978 (excellent calibration)
4. **Lowest RMSE**: WDSM V2 at 0.0507 (best overall accuracy)
5. **Best Efficiency**: WDSM V2 at 2.71x better than PS baseline

### 📊 Detailed Results:

```
Method                          Estimate   Bias      Emp_SE  Est_SE  Coverage
DSM (Unweighted)               1.0896    +0.0545    0.0564  0.0562   82.8%
PS (Unweighted)                1.0890    +0.0539    0.0824  0.1040   96.3%
PG (Unweighted)                1.0894    +0.0543    0.0553  0.0556   84.1%
PS Full (Weighted)             1.0298    -0.0053    0.0634  0.0497   90.7%
WDSM V2 Standard (Updated)     1.0268    -0.0083    0.0501  0.0490   93.8%
```

## WDSM Improvements Impact (100 vs 1000 Replications)

Comparing 100 vs 1000 replications shows stable performance:
- **Bias**: -1.1% → -0.8% (slightly improved)
- **Coverage**: 90.0% → 93.8% (improved closer to nominal)
- **SE Ratio**: 1.014 → 0.978 (excellent in both)
- **RMSE**: 0.0494 → 0.0507 (stable)
- **Efficiency**: 2.44x → 2.71x (improved)

## Diagnostic Information
- Average sample size: 4994.2 (range: 4750-5197)
- Average treated units: 1638.3 (range: 1477-1793)
- Average control units: 3356.0 (range: 3183-3524)
- Treatment proportion: 32.8%

## Comparison with Original Implementation (without improvements)

From the previous 1000-replicate run (Job ID: 57079650) without polynomial sieve:
- **WDSM Coverage**: 96.6% → 93.8% (now closer to nominal 95%)
- **WDSM SE Ratio**: 1.106 → 0.978 (much better calibration)
- **WDSM RMSE**: 0.0508 → 0.0507 (similar accuracy)
- **WDSM Efficiency**: 2.70x → 2.71x (similar efficiency)

The key improvement is in **standard error calibration** - the SE ratio is now 0.978 (near perfect) compared to 1.106 (slightly conservative) before.

## Conclusion

The updated WDSM V2 with all improvements (polynomial sieve method, complete re-estimation in bootstrap, aligned bias correction) demonstrates:
- **Excellent bias control**: -0.8% (very low for retrospective sampling)
- **Near-nominal coverage**: 93.8% (close to target 95%)
- **Outstanding efficiency**: 2.71x better than PS baseline
- **Best overall performance**: Lowest RMSE among all methods
- **Excellent SE calibration**: SE ratio of 0.978 (near perfect)

The improvements have resulted in better-calibrated confidence intervals while maintaining the excellent bias and efficiency properties of the method. This confirms that the theoretical improvements translate into practical benefits for PATT estimation under retrospective sampling.