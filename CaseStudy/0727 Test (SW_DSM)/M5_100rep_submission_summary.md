# M5 100-Replication Job Submission Summary

## Date: 2025-01-20

## Configuration
- **Replications**: 100 (reduced from 1000)
- **M values**: M=5 only
- **Cores**: 20
- **Memory**: 8GB per CPU
- **Batch size**: 20 replications per batch
- **Time limit**: 22 hours
- **Partition**: day
- **Account**: li_fan (default)

## Submitted Jobs

| Scenario | Job ID    | Status | Job Name          | Directory |
|----------|-----------|--------|-------------------|-----------|
| CorCor   | 57627980  | PD     | m5_corcor_100rep  | `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_corcor_100rep/` |
| MisCor   | 57627981  | PD     | m5_miscor_100rep  | `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_miscor_100rep/` |
| CorMis   | 57627982  | PD     | m5_cormis_100rep  | `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_cormis_100rep/` |
| MisMis   | 57627986  | PD     | m5_mismis_100rep  | `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_mismis_100rep/` |

## Model Specification Scenarios
- **CorCor**: Both PS and PGS models correctly specified (with X1:X2 interaction)
- **MisCor**: PS misspecified (without X1:X2), PGS correct (with X1:X2)
- **CorMis**: PS correct (with X1:X2), PGS misspecified (without X1:X2)
- **MisMis**: Both PS and PGS models misspecified (without X1:X2 interaction)

## Files Modified
1. **R Scripts**: Updated to use 100 replications, 20 cores, batch size 20
2. **SLURM Scripts**: Updated to use 20 CPUs, 8GB per CPU, 22-hour limit
3. **Population Data**: Uploaded to each directory (82MB each, verified)

## Expected Runtime
With 100 replications and M=5 only, these jobs should complete within the 22-hour time limit, likely finishing in 2-3 hours based on previous performance.

## Monitoring Commands
```bash
# Check all 100-rep jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u yz2324 --jobs=57627980,57627981,57627982,57627986'

# Check all jobs on li_fan account
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -A li_fan -u yz2324'

# Download results when complete
for scenario in corcor miscor cormis mismis; do
  scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario}_100rep/pate_retrospective_comparison_results_mccleary*.RData .
done
```

## Notes
- These 100-rep jobs are designed for quick preliminary results
- They complement the full 1000-rep jobs running on the week partition
- All jobs use the li_fan SLURM account (default)
