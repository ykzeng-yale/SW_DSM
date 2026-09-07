# Comprehensive Job Status - Li_Fan Account
## Date: 2025-01-19

## 🟢 DAY Partition Jobs - RUNNING

### 100-Rep Poor Overlap Jobs (M=5) - IN PROGRESS
| Job ID   | Scenario | Status  | Runtime | Expected Completion |
|----------|----------|---------|---------|---------------------|
| 57628018 | CorCor   | RUNNING | 1h 27m  | ~2-3 hours remaining |
| 57628020 | MisCor   | RUNNING | 1h 22m  | ~2-3 hours remaining |
| 57628021 | CorMis   | RUNNING | 22m     | ~3-4 hours remaining |
| 57628023 | MisMis   | RUNNING | 17m     | ~3-4 hours remaining |

**Location**: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_100reps_lifan/`
**Status**: Jobs are actively running! No CSV results yet, but should complete within 2-4 hours.

### Other Running Day Jobs
| Job ID   | Name            | Runtime | 
|----------|-----------------|---------|
| 57627980 | m5_corcor_100re | 3h 14m  |
| 57627981 | m5_miscor_100re | 3h 14m  |
| 57627982 | m5_cormis_100re | 3h 14m  |
| 57627986 | m5_mismis_100re | 3h 14m  |

## 🟡 WEEK Partition Jobs - LONG RUNNING

### M135 Jobs - Running for 3+ Days
| Job ID   | Name            | Status  | Runtime  | Note |
|----------|-----------------|---------|----------|------|
| 57613786 | CorCor_M135     | RUNNING | 3d 3h 14m | PATT Goodoverlap |
| 57613787 | MisCor_M135     | RUNNING | 3d 3h 14m | PATT Goodoverlap |
| 57613788 | CorMis_M135     | RUNNING | 3d 3h 14m | PATT Goodoverlap |
| 57613789 | MisMis_M135     | RUNNING | 3d 3h 14m | PATT Goodoverlap |
| 57613898 | patt_CorCor     | RUNNING | 3d 3h 13m | PATT analysis |

**Note**: These are PATT Retrospective Goodoverlap jobs, not the Poor Overlap PATE jobs you're tracking.

### Week Jobs Still Pending
- 57622897-57622900: M135 jobs (PENDING - MaxCpuPerAccount)
- 57613902, 57613909, 57613914: PATT jobs (PENDING - MaxCpuPerAccount)

## 📊 Summary

### ✅ Good News
1. **100-rep jobs are RUNNING!** Started ~1-2 hours ago
2. Expected completion: Within 2-4 hours
3. Jobs are on appropriate nodes (r813u03n07, r813u03n08, r813u03n11, r813u09n10)

### ⚠️ Important Notes
1. **No completed results yet** - jobs still processing
2. Week partition jobs are for PATT Goodoverlap (different analysis)
3. Many jobs still pending due to resource limits

## To Check Progress
```bash
# Check 100-rep job progress
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep -E "57628018|57628020|57628021|57628023"'

# Check for results (will appear when jobs complete)
ssh yz2324@login2.mccleary.ycrc.yale.edu 'ls -la /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_100reps_lifan/*.csv'
```

## Expected Timeline
- **100-rep jobs**: Should complete in 2-4 hours (by ~8:00 PM today)
- **Week partition jobs**: May continue for several more days
