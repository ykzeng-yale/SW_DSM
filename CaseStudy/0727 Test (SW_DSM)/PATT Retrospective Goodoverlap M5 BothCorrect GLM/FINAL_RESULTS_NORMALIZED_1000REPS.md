# Final Results with Weight Normalization - 1000 Replications

## Job Information
- **Job ID**: 57160958
- **Completed**: August 7, 2025, 13:17 EDT
- **Runtime**: 63.82 minutes
- **Exit Code**: 0 (Success)

## Configuration
- **True PATT**: 1.0351
- **Sample Size**: ~5000 per replicate
- **Replications**: 1000
- **Bootstrap**: 200 iterations
- **Matches per unit (M)**: 5
- **Weight Normalization**: Applied (w × length(w)/sum(w))

## Precise Results (3 Decimal Places)

| Method | Relative Bias | Coverage | Relative Efficiency |
|--------|--------------|----------|-------------------|
| DSM (Unweighted) | **5.268%** | **0.828** | **2.137x** |
| PS (Unweighted) | **5.207%** | **0.963** | **1.000x** |
| PG (Unweighted) | **5.246%** | **0.841** | **2.220x** |
| PS Full (Weighted) | **-0.688%** | **0.916** | **2.487x** |
| WDSM V2 Standard GLM/LM (Weighted) | **-0.648%** | **0.932** | **2.672x** |

## Performance Summary
- **Lowest Bias**: WDSM V2 Standard GLM/LM (-0.648%)
- **Best Coverage**: PS (Unweighted) (96.3%)
- **Best Efficiency**: WDSM V2 Standard GLM/LM (2.672x)

## Key Findings

### Survey-Weighted Methods Excel
Both survey-weighted methods (PS Full and WDSM) show:
- **Minimal bias** (<0.7% relative bias)
- **Good coverage** (91.6% and 93.2%)
- **High efficiency** (2.5-2.7x better than PS)

### Unweighted Methods Show Positive Bias
All unweighted methods exhibit:
- **~5.2% positive bias**
- **Poor to moderate coverage** (82.8-96.3%)
- **Good efficiency** (2.1-2.2x for matching methods)

### Weight Normalization Impact
- Had minimal practical impact on results
- Slightly increased bias for PS Full but within acceptable range
- Confirms robustness of implementation

## Recommendations
1. **Use WDSM V2 Standard GLM/LM** for best overall performance
2. **PS Full (Weighted)** is a good alternative with simpler implementation
3. **Avoid unweighted methods** for retrospective sampling with survey weights
4. **Apply weight normalization** as a best practice even if impact is small

## Files Generated
- `comprehensive_patt_retrospective_results_1000reps_normalized.RData`
- `comprehensive_patt_retrospective_table_1000reps_normalized.csv`
- `comprehensive_patt_retrospective_plot_1000reps_normalized.pdf`
- `comprehensive_patt_retrospective_results_1000reps_normalized_precise.csv`
