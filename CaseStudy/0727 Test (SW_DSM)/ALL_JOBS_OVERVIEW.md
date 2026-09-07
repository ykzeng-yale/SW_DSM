# Complete Job Overview - Poor Overlap Analysis

## Date: 2025-01-19

## Summary of All Submitted Jobs

### 1. Week Partition Jobs (Full M=1,3,5 Analysis) - li_fan Account
- **Partition**: week (7 days)
- **Status**: PENDING (Priority queue)
- **Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_*_week/`

| Job ID   | Scenario | Status  |
|----------|----------|---------|
| 57613316 | CorCor   | PENDING |
| 57613319 | MisCor   | PENDING |
| 57613321 | CorMis   | PENDING |
| 57613329 | MisMis   | PENDING |

### 2. Day Partition Jobs (M=5 Only) - li_fan Account
- **Partition**: day (22 hours)
- **Status**: PENDING (QOSMaxCpuPerUserLimit)
- **Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_day/`

| Job ID   | Scenario | Status  |
|----------|----------|---------|
| 57613334 | CorCor   | PENDING |
| 57613340 | MisCor   | PENDING |
| 57613349 | CorMis   | PENDING |
| 57613353 | MisMis   | PENDING |

### 3. Day Partition Jobs (M=5 Only) - tong Account ✨ NEW
- **Partition**: day (22 hours)
- **Status**: PENDING (QOSMaxCpuPerUserLimit)
- **Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_day_tong/`

| Job ID   | Scenario | Status  |
|----------|----------|---------|
| 57623057 | CorCor   | PENDING |
| 57623075 | MisCor   | PENDING |
| 57623094 | CorMis   | PENDING |
| 57623103 | MisMis   | PENDING |

## Job Execution Strategy

1. **Tong Account M=5 Jobs** (likely to start first)
   - Using separate account quota
   - Quick results for M=5 analysis
   - Expected: ~22 hours once started

2. **Li_fan Account M=5 Jobs** (backup)
   - Same analysis as tong account
   - Provides redundancy
   - Expected: ~22 hours once started

3. **Week Partition Full Jobs** (comprehensive)
   - Complete M=1,3,5 analysis
   - Most thorough results
   - Expected: 2-7 days

## Critical Fix Applied
All jobs include the fixed WDSM implementation that correctly handles model misspecification scenarios by using `use_interaction_ps` and `use_interaction_pg` flags instead of hardcoding interaction terms.

## Quick Status Check Commands
```bash
# Check all your jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER'

# Check tong account M=5 jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep -E "57623057|57623075|57623094|57623103"'

# Check li_fan M=5 jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep -E "57613334|57613340|57613349|57613353"'

# Check week partition jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep wk'
```

## Expected Timeline
- **First results**: M=5 from tong account (within 22-48 hours)
- **Complete results**: Full M=1,3,5 from week partition (within 7 days)

