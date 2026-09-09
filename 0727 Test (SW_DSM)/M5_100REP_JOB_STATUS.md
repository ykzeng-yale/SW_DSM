# M=5 100-Replication Job Status Report

## Date: 2025-01-19

## ✅ Successfully Submitted 100-Rep Jobs (li_fan account)

### Job Details
- **Account**: li_fan (default)
- **Partition**: day (22-hour timeout)
- **Resources**: 20 cores, 8GB per CPU (160GB total)
- **Parameters**: 
  - M values: 5 only
  - Replications: 100 (reduced from 1000)
  - Batch size: 20 replications per batch
  - Parallel cores: 20

### Job IDs and Status
| Job ID   | Scenario | Job Name            | Status  | Reason               |
|----------|----------|---------------------|---------|----------------------|
| 57628018 | CorCor   | pate_CorCor_M5_100r | PENDING | QOSMaxCpuPerUserLimit |
| 57628020 | MisCor   | pate_MisCor_M5_100r | PENDING | QOSMaxCpuPerUserLimit |
| 57628021 | CorMis   | pate_CorMis_M5_100r | PENDING | QOSMaxCpuPerUserLimit |
| 57628023 | MisMis   | pate_MisMis_M5_100r | PENDING | QOSMaxCpuPerUserLimit |

### Remote Directories
- CorCor: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorCor_100reps_lifan/`
- MisCor: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisCor_100reps_lifan/`
- CorMis: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorMis_100reps_lifan/`
- MisMis: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisMis_100reps_lifan/`

## 🏃 Currently Running Jobs (tong account)

### Tong Account M=5 Jobs (1000 reps) - RUNNING
| Job ID   | Job Name    | Status  | Runtime | Node       |
|----------|-------------|---------|---------|------------|
| 57622901 | M5_CorCor   | RUNNING | 8:17:29 | r813u03n06 |
| 57622902 | M5_MisCor   | RUNNING | 5:52:27 | r813u03n05 |
| 57622903 | M5_CorMis   | RUNNING | 5:42:26 | r813u03n04 |
| 57622904 | M5_MisMis   | RUNNING | 5:34:57 | r813u09n12 |
| 57622926 | M5only_pate | RUNNING | 5:27:25 | r813u03n11 |
| 57622927 | M5only_pate | RUNNING | 0:34:34 | r813u03n03 |
| 57622928 | M5only_pate | RUNNING | 0:34:34 | r813u03n11 |
| 57622929 | M5only_pate | RUNNING | 0:34:34 | r813u03n10 |

## Key Updates
1. **100-rep jobs properly configured**: All R scripts have been correctly updated with:
   - `n_reps <- 100` (reduced from 1000)
   - `M_values <- c(5)` (M=5 only)
   - `n_cores <- 20` (optimized for available resources)
   - `batch_size <- 20` (20 reps per batch)

2. **Fixed WDSM implementation**: All jobs include the corrected WDSM functions that properly handle model misspecification scenarios

3. **Expected completion times**:
   - 100-rep jobs (li_fan): ~2-4 hours once started
   - 1000-rep jobs (tong): Currently running, expect completion within 10-15 hours

## To Check Status
```bash
# Check 100-rep jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep -E "57628018|57628020|57628021|57628023"'

# Check all M5 jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep M5'

# Check running tong jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep " R "'
```

## To Download Results When Complete
```bash
# Download 100-rep results (li_fan account)
rsync -avz yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_100reps_lifan/*.{csv,RData} ./

# Download 1000-rep results (tong account - when complete)
rsync -avz yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_day_tong/*.{csv,RData} ./
```
