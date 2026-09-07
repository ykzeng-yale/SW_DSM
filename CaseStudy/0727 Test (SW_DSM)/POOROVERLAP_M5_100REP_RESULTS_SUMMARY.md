# Poor Overlap M=5 100-Replication Results Summary
## Date: 2025-01-19

## ✅ Job Completion Status

| Job ID   | Scenario | Status     | Runtime  | Exit Code |
|----------|----------|------------|----------|-----------|
| 57628018 | CorCor   | COMPLETED ✓ | 1h 44m   | 0:0      |
| 57628020 | MisCor   | COMPLETED* | 1h 43m   | 0:0      |
| 57628021 | CorMis   | COMPLETED ✓ | 1h 42m   | 0:0      |
| 57628023 | MisMis   | COMPLETED ✓ | 1h 43m   | 0:0      |

*MisCor completed but had errors calculating summary statistics - no CSV output generated

## 📊 Results Summary (M=5, 100 replications)

### Scenario: CorCor (Both PS and PGS correctly specified)
| Method            | Mean Est. | Bias   | Rel. Bias% | Emp. SE | SE Ratio | Coverage% | RMSE  |
|-------------------|-----------|--------|------------|---------|----------|-----------|-------|
| DSM Unweighted    | 0.914     | 0.047  | 5.44       | 0.108   | 1.037    | **95**    | 0.117 |
| PG Unweighted     | 0.915     | 0.049  | 5.64       | 0.059   | 1.145    | 91        | 0.076 |
| PS Unweighted     | 0.925     | 0.059  | 6.78       | 0.305   | 1.057    | **98**    | 0.309 |
| PS Weighted       | 0.859     | -0.008 | -0.91      | 0.152   | 0.745    | 87        | 0.152 |
| WDSM Multinomial  | 0.832     | -0.034 | -3.94      | 0.118   | 0.689    | 79        | 0.123 |

### Scenario: CorMis (PS correct, PGS misspecified)
| Method            | Mean Est. | Bias   | Rel. Bias% | Emp. SE | SE Ratio | Coverage% | RMSE  |
|-------------------|-----------|--------|------------|---------|----------|-----------|-------|
| DSM Unweighted    | 0.914     | 0.048  | 5.48       | 0.111   | 1.129    | **96**    | 0.120 |
| PG Unweighted     | 1.058     | 0.191  | 22.06      | 0.089   | 0.970    | 45        | 0.211 |
| PS Unweighted     | 0.925     | 0.059  | 6.78       | 0.305   | 1.057    | **98**    | 0.309 |
| PS Weighted       | 0.837     | -0.030 | -3.41      | 0.211   | 0.707    | 86        | 0.212 |
| WDSM Multinomial  | 0.840     | -0.027 | -3.08      | 0.146   | 0.728    | 85        | 0.147 |

### Scenario: MisCor (PS misspecified, PGS correct)
**No results available** - Job encountered errors in statistical calculations

### Scenario: MisMis (Both PS and PGS misspecified)
| Method            | Mean Est. | Bias   | Rel. Bias% | Emp. SE | SE Ratio | Coverage% | RMSE  |
|-------------------|-----------|--------|------------|---------|----------|-----------|-------|
| DSM Unweighted    | 1.012     | 0.145  | 16.79      | 0.115   | 1.112    | 83        | 0.185 |
| PG Unweighted     | 1.058     | 0.191  | 22.06      | 0.089   | 0.970    | 45        | 0.211 |
| PS Unweighted     | 1.192     | 0.326  | 37.57      | 0.297   | 1.049    | 77        | 0.439 |
| PS Weighted       | 1.097     | 0.231  | 26.63      | 0.232   | 0.659    | 55        | 0.326 |
| WDSM Multinomial  | 1.147     | 0.280  | 32.34      | 0.182   | 0.583    | 29        | 0.334 |

## 🎯 Key Findings

### Best Performers by Coverage (≥90%):
1. **CorCor scenario**: 
   - PS Unweighted (98%)
   - DSM Unweighted (95%)
   - PG Unweighted (91%)

2. **CorMis scenario**:
   - PS Unweighted (98%)
   - DSM Unweighted (96%)

3. **MisMis scenario**:
   - None achieved nominal coverage (all <90%)

### Bias Performance:
- **Lowest bias**: PS Weighted in CorCor (-0.91% relative bias)
- **Highest bias**: PS Unweighted in MisMis (37.57% relative bias)

### SE Ratio (Ideal = 1.0):
- Best calibrated: PS Unweighted (1.037-1.057 across scenarios)
- Most underestimated: WDSM Multinomial (0.583-0.728)

## ⚠️ Issues Noted

1. **MisCor scenario failed** - Error in variance calculations prevented results generation
2. **WDSM consistently underperforms** in coverage (29-85%)
3. **Model misspecification impact** is severe - MisMis scenario shows poor performance across all methods

## 📁 Files Downloaded

Location: `PoorOverlap_M5_100rep_Results/`
- `pate_retrospective_pooroverlap_comparison_table_M5_100reps_CorCor.csv`
- `pate_retrospective_pooroverlap_comparison_table_M5_100reps_CorMis.csv`
- `pate_retrospective_pooroverlap_comparison_table_M5_100reps_MisMis.csv`

## Notes
- True PATE = 0.8664 (based on bias calculations)
- 100 replications per scenario
- M = 5 matches
- Poor overlap setting increases estimation difficulty
