# 1000-Replication Corrected Jobs Submission Summary

## ✅ Successfully Submitted to li_fan Account

**Submission Time:** August 19, 2025, 12:13 PM EDT

## Job Details

| Job ID | Scenario | Status | Configuration | Remote Directory |
|--------|----------|--------|---------------|------------------|
| **57730511** | CorCor | PENDING | 1000 reps, M=5, 30 cores | `/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_corcor_1000rep_corrected/` |
| **57730512** | MisCor | PENDING | 1000 reps, M=5, 30 cores | `/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_miscor_1000rep_corrected/` |
| **57730513** | CorMis | PENDING | 1000 reps, M=5, 30 cores | `/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_cormis_1000rep_corrected/` |
| **57730514** | MisMis | PENDING | 1000 reps, M=5, 30 cores | `/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_mismis_1000rep_corrected/` |

## Configuration Settings

### Simulation Parameters
- **Replications:** 1000
- **M value:** 5 (number of matches)
- **Batch size:** 100 replications per batch
- **Methods:** All 5 (Unweighted DSM, PG, PS, Survey-weighted PS, WDSM)

### SLURM Configuration
- **Account:** li_fan (default)
- **Partition:** day
- **Time limit:** 23 hours
- **CPUs:** 30 cores
- **Memory per CPU:** 8 GB (240 GB total)

## Key Updates in This Version

### ✅ CORRECTED SE Ratio Calculation
The previous CorMis results had an incorrect SE ratio calculation. This version ensures:
- **Standard SE Ratio Formula:** `SE_Ratio = Mean_SE / Empirical_SD`
- **NOT:** Relative efficiency compared to PS Unweighted
- All scenarios now use consistent calculation methodology

### ✅ Verified Model Specifications
Confirmed correct implementation:
- **CorCor:** Both PS and PGS include X1:X2 interaction
- **MisCor:** PS excludes, PGS includes X1:X2
- **CorMis:** PS includes, PGS excludes X1:X2
- **MisMis:** Both exclude X1:X2 interaction

### ✅ WDSM Enhancements Confirmed
- Dynamic model specification via `use_interaction_ps` and `use_interaction_pg` parameters
- Polynomial sieve bias correction working correctly
- Multinomial bootstrap with proper weight handling

## Expected Runtime

Based on previous 100-replication runs (~2.5-3 hours):
- **Estimated completion time:** ~20-23 hours per job
- **Expected completion:** August 20, 2025, by 11:00 AM EDT

## Monitoring Commands

```bash
# Check job status
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u yz2324 | grep 5773051'

# Check specific job details
ssh yz2324@login2.mccleary.ycrc.yale.edu 'scontrol show job 57730511'

# Check output files (once running)
ssh yz2324@login2.mccleary.ycrc.yale.edu 'ls -lah /gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_*_1000rep_corrected/*.out'
```

## Local Directory Structure

```
PATE Retrospective Goodoverlap M5 CorCor 1000rep CORRECTED GLM/
PATE Retrospective Goodoverlap M5 MisCor 1000rep CORRECTED GLM/
PATE Retrospective Goodoverlap M5 CorMis 1000rep CORRECTED GLM/
PATE Retrospective Goodoverlap M5 MisMis 1000rep CORRECTED GLM/
```

## Next Steps

1. **Monitor job progress** - Check periodically for completion
2. **Download results** once complete:
   ```bash
   for scenario in corcor miscor cormis mismis; do
     scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_${scenario}_1000rep_corrected/*results*.RData ./
   done
   ```
3. **Analyze results** with corrected SE ratio calculations
4. **Generate final comparison tables** and plots

## Notes

- These jobs supersede any previous CorMis results with incorrect SE ratio calculations
- The WDSM implementation has been thoroughly verified to correctly handle all model misspecification scenarios
- All WDSM files are identical across scenarios (MD5 verified)
- Results will provide definitive comparison of method robustness to model misspecification

---

*Submission completed: August 19, 2025, 12:13 PM EDT*
