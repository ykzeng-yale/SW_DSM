# Poor Overlap Job Submission Summary

## Date: 2025-01-19

## Jobs Successfully Submitted

### Week Partition Jobs (Full Analysis: M=1,3,5)
- **Partition**: week (7-day timeout)
- **Resources**: 30 cores, 240GB RAM
- **Job IDs**:
  - 57613316: pate_poor_CorCor_wk (CorCor scenario)
  - 57613319: pate_poor_MisCor_wk (MisCor scenario)
  - 57613321: pate_poor_CorMis_wk (CorMis scenario)
  - 57613329: pate_poor_MisMis_wk (MisMis scenario)
- **Status**: PENDING (Priority queue)
- **Expected completion**: Within 7 days

### Day Partition Jobs (Reduced Analysis: M=5 Only)
- **Partition**: day (22-hour timeout)
- **Resources**: 30 cores, 240GB RAM
- **Job IDs**:
  - 57613334: pate_poor_CorCor_M5 (CorCor scenario)
  - 57613340: pate_poor_MisCor_M5 (MisCor scenario)
  - 57613349: pate_poor_CorMis_M5 (CorMis scenario)
  - 57613353: pate_poor_MisMis_M5 (MisMis scenario)
- **Status**: PENDING (QOSMaxCpuPerUserLimit - waiting for resources)
- **Expected completion**: Within 22 hours once started

## Critical WDSM Fix Applied
Before submission, we fixed a critical bug in WDSM implementation:
- **Issue**: WDSM functions hardcoded the `X1:X2` interaction term regardless of scenario
- **Fix**: Added `use_interaction_ps` and `use_interaction_pg` flags to dynamically handle model specification
- **Files Fixed**:
  - `wdsm_method2_multinomial_bootstrap.R`
  - `wdsm_ci_functions.R`

## Remote Directories on McCleary
- Week partition jobs: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_{scenario}_week/`
- Day partition jobs: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_{scenario}_day/`

## To Check Job Status
```bash
# Check all jobs
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER'

# Check week partition jobs only
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep wk'

# Check day partition M=5 jobs only
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep M5'
```

## To Download Results When Complete
```bash
# For day partition (M=5 only) results
rsync -avz yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*/*.{csv,RData} ./

# For week partition (full M=1,3,5) results
rsync -avz yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_*_week/*.{csv,RData} ./
```

## Notes
- The M=5-only jobs should complete first and provide preliminary results
- The full M=1,3,5 jobs will provide comprehensive analysis across all matching parameters
- All jobs include the fixed WDSM implementation that correctly handles model misspecification
