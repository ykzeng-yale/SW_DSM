# Poor Overlap Simulation Results - 20 Replications

## Job Status: ✅ COMPLETED

| Scenario | Job ID | Status | Runtime | Exit Code |
|----------|--------|--------|---------|-----------|
| **CorCor** | 57869159 | COMPLETED | 17:01 | 0:0 |
| **MisCor** | 57869192 | COMPLETED | 16:18 | 0:0 |
| **CorMis** | 57869195 | COMPLETED | 16:45 | 0:0 |
| **MisMis** | 57869206 | COMPLETED | 16:17 | 0:0 |

## Key Parameters
- **Sample size**: n = 5000 (0.5% of N = 1,000,000)
- **True PATE**: 0.8664 (poor overlap with δ_z = 2)
- **Replications**: 20
- **Bootstrap**: B = 200
- **Matching ratio**: M = 5

## Results Summary

### Methods with Results
⚠️ **Only 2 out of 5 methods produced results:**
- ✅ PS Full (Survey-Weighted) - `ps_weighted`
- ✅ WDSM (Survey-Weighted DSM) - `wdsm_multinomial`
- ❌ DSM (unweighted) - No results
- ❌ PG (unweighted) - No results  
- ❌ PS (unweighted) - No results

### WDSM Performance Across Scenarios

| Scenario | Relative Bias (%) | Coverage (%) | SE Ratio | Expected |
|----------|------------------|--------------|----------|-----------|
| **CorCor** | -3.22 | 90.0 | 0.80 | <1% bias, 95% coverage |
| **MisCor** | -3.30 | 90.0 | 0.80 | Higher bias expected |
| **CorMis** | 1.80 | 95.0 | 0.82 | Good performance ✅ |
| **MisMis** | 27.90 | 50.0 | 0.96 | Poor (both models wrong) |

### PS Full (Survey-Weighted) Performance

| Scenario | Relative Bias (%) | Coverage (%) | SE Ratio |
|----------|------------------|--------------|----------|
| **CorCor** | -1.16 | 90.0 | 0.80 |
| **MisCor** | -2.24 | 90.0 | 0.76 |
| **CorMis** | -1.16 | 90.0 | 0.80 |
| **MisMis** | -2.24 | 90.0 | 0.76 |

## Key Findings

### ✅ Successes
1. **Jobs completed successfully** with proper runtime (~16-17 minutes)
2. **CorMis scenario**: WDSM achieved 1.8% bias and 95% coverage (good!)
3. **Weighted methods ran**: Both survey-weighted methods produced results

### ⚠️ Issues Identified
1. **Unweighted methods failed**: DSM, PG, PS methods produced no results
2. **WDSM CorCor performance**: -3.22% bias (expected <1%), 90% coverage (expected 95%)
3. **Limited results**: Only 40 results per scenario (20 reps × 2 methods)

### 📊 Expected vs Actual Pattern
- **Expected**: CorCor and CorMis should be similar for PS-based methods ✅ (both -1.16%)
- **Expected**: CorCor and MisCor should be similar for PG-based methods ❓ (can't verify - PG failed)
- **MisMis worst performance**: ✅ Confirmed (27.9% bias for WDSM)

## Next Steps
1. **Investigate unweighted method failures** - Check error logs
2. **Debug WDSM CorCor bias** - Should be <1%, getting -3.22%
3. **Run more replications** - 20 reps may be insufficient for stable estimates
4. **Fix coverage calibration** - Most methods at 90% instead of nominal 95%

## Files Generated
- `pooroverlap_CorCor_20rep_results.RData`
- `pooroverlap_MisCor_20rep_results.RData`
- `pooroverlap_CorMis_20rep_results.RData`
- `pooroverlap_MisMis_20rep_results.RData`
- `pooroverlap_20rep_all_summaries.RData`