# PATE Retrospective Poor Overlap - Final Results Summary

## Job Completion Status: ✅ SUCCESS

### Job Details
- **Job ID**: 57117031
- **Submitted**: 2025-08-05 10:56 AM
- **Completed**: 2025-08-05 1:27 PM
- **Total Runtime**: 88.87 minutes (~1.5 hours)
- **Exit Code**: 0 (Success)
- **Complete Replicates**: 1000/1000

### Performance Results (Poor Overlap Scenario)

| Method | Estimate | Bias | Bias % | Emp SD | Coverage | CI Width | Var Rel Eff |
|--------|----------|------|--------|--------|----------|----------|-------------|
| **WDSM (Multinomial Bootstrap)** | 0.8651 | -0.0012 | **-0.1%** | 0.0965 | **93.1%** | 0.3497 | 10.51 |
| **DSM (Unweighted)** | 0.9123 | 0.0459 | 5.3% | 0.1186 | **93.0%** | 0.4436 | 6.96 |
| **PG (Unweighted)** | 0.9141 | 0.0477 | 5.5% | 0.0672 | 89.3% | 0.2655 | 21.71 |
| **PS (Unweighted)** | 0.9552 | 0.0888 | 10.3% | 0.3130 | **95.4%** | 1.2800 | 1.00 |
| **PS Full (Survey-Weighted)** | 0.8511 | -0.0153 | -1.8% | 0.1890 | 79.8% | 0.4741 | 2.74 |

*True PATE = 0.8664*

## Key Findings (Poor Overlap)

### Best Performers:
1. **WDSM (Multinomial Bootstrap)**
   - **Lowest bias**: -0.1% (essentially unbiased)
   - **Good coverage**: 93.1% (nominal)
   - **High efficiency**: 10.51× more efficient than PS
   - **Narrow CI**: 0.3497 width

2. **DSM (Unweighted)**
   - Moderate bias: 5.3%
   - Good coverage: 93.0%
   - Good efficiency: 6.96× more efficient than PS

### Poor Performers:
1. **PS Full (Survey-Weighted)**
   - **Poor coverage**: 79.8% (well below nominal)
   - Low bias but high variance (SD = 0.1890)
   - Likely affected by extreme weights in poor overlap

2. **PS (Unweighted)**
   - High bias: 10.3%
   - Very wide CI: 1.2800
   - High variance (SD = 0.3130)

## Poor Overlap Impact

The poor overlap scenario (control mean PS = 0.156, treated mean PS = 0.666) reveals:

1. **WDSM maintains excellent performance** even with poor overlap
2. **Survey-weighted methods struggle** with coverage (79.8%)
3. **PS matching shows increased bias** (10.3%) in poor overlap
4. **DSM and PG show moderate robustness** to poor overlap

## Files Downloaded
- ✅ `pate_retrospective_comparison_results_mccleary.RData` (177KB)
- ✅ `pate_retrospective_comparison_plot_mccleary.pdf` (5.6KB)
- ✅ `pate_retrospective_bias_variance_plot_mccleary.pdf` (4.8KB)
- ✅ `pate_retrospective_comparison_table_mccleary.csv` (548B)
- ✅ `pate_retro_57117031.out` (5.8KB)

## Conclusion

In the poor overlap scenario:
- **WDSM emerges as the clear winner** with minimal bias and good coverage
- **Traditional survey-weighted methods fail** to maintain nominal coverage
- **Double score methods (DSM, WDSM) show robustness** to poor overlap
- **PS-based methods suffer** from increased bias or coverage issues