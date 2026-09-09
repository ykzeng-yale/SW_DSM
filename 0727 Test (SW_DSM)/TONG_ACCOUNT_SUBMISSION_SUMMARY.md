# Tong Account Job Submission Summary

## Date: 2025-01-19

## M=5 Jobs Successfully Submitted to TONG Account

### Job Details
- **Account**: tong (separate from li_fan account)
- **Partition**: day (22-hour timeout)
- **Resources**: 30 cores, 8GB per CPU (240GB total)
- **M values**: 5 only (reduced analysis for quick results)

### Job IDs and Status
| Job ID   | Scenario | Job Name                     | Status  | Reason               |
|----------|----------|------------------------------|---------|----------------------|
| 57623057 | CorCor   | pate_poor_CorCor_M5_tong   | PENDING | QOSMaxCpuPerUserLimit |
| 57623075 | MisCor   | pate_poor_MisCor_M5_tong   | PENDING | QOSMaxCpuPerUserLimit |
| 57623094 | CorMis   | pate_poor_CorMis_M5_tong   | PENDING | QOSMaxCpuPerUserLimit |
| 57623103 | MisMis   | pate_poor_MisMis_M5_tong   | PENDING | QOSMaxCpuPerUserLimit |

### Remote Directories
All jobs are running in separate directories under the tong account:
- CorCor: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorCor_day_tong/`
- MisCor: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisCor_day_tong/`
- CorMis: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorMis_day_tong/`
- MisMis: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisMis_day_tong/`

## Key Features
1. **Fixed WDSM Implementation**: All jobs include the corrected WDSM functions that properly handle model misspecification scenarios
2. **Separate Account**: Using "tong" account instead of "li_fan" for better resource allocation
3. **M=5 Only**: Reduced analysis for faster results (expected completion within 22 hours once started)

## To Check Status
```bash
# Check specific job IDs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep -E "57623057|57623075|57623094|57623103"'

# Check all M5 jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep M5'
```

## To Download Results When Complete
```bash
# Download all M=5 results from tong account directories
rsync -avz yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_day_tong/*.{csv,RData} ./
```

## Notes
- Jobs are currently pending due to CPU limits, but will start automatically when resources become available
- These jobs are running in parallel with the li_fan account jobs but use separate resource quotas
- The tong account submission allows for better resource utilization across different accounts

