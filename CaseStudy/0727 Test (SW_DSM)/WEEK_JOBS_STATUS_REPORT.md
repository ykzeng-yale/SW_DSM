# Week Partition Jobs Status Report

## Date: 2025-01-19

## Currently Running Week Jobs (From Previous Submissions)

### Job 57426738: M135_modelspec_week_1000rep
- **Status**: RUNNING
- **Runtime**: 1 day 13 hours 55 minutes (and counting)
- **Type**: PATE **Prospective** Goodoverlap M135 CorAndMis GLM
- **Working Directory**: `/gpfs/gibbs/project/tong/yz2324/PATE Prospective Goodoverlap M135 CorAndMis GLM/`
- **Notes**: This job appears to be stuck - the output log shows it stopped at "Setting up parallel backend with 30 cores (FORK cluster)..."
- **Last Activity**: August 11 (based on file timestamps)

### Job 57549601: M135_modelspec_week_1000rep
- **Status**: RUNNING  
- **Runtime**: 11 hours (and counting)
- **Type**: PATE **Prospective** Goodoverlap M135 CorAndMis GLM (same as above)
- **Working Directory**: Same as Job 57426738
- **Notes**: Appears to be a duplicate submission of the same job

## Issues Identified

1. **Both jobs appear stuck**: The output files haven't been updated since August 11
2. **Both are Prospective analyses**: These are NOT the Retrospective Poor Overlap jobs we just submitted
3. **Possible parallel processing issue**: Jobs seem stuck at the FORK cluster initialization

## Newly Submitted Week Jobs (Poor Overlap Retrospective)

### Currently Pending (Priority Queue)
- Job 57613316: pate_poor_CorCor_wk (Poor Overlap Retrospective)
- Job 57613319: pate_poor_MisCor_wk (Poor Overlap Retrospective)
- Job 57613321: pate_poor_CorMis_wk (Poor Overlap Retrospective)
- Job 57613329: pate_poor_MisMis_wk (Poor Overlap Retrospective)

These are waiting in the priority queue and will start once resources become available.

## Recommendations

1. **Consider canceling stuck jobs**: Jobs 57426738 and 57549601 have been running for extended periods without progress
   ```bash
   ssh yz2324@login2.mccleary.ycrc.yale.edu "scancel 57426738 57549601"
   ```

2. **Monitor new submissions**: The newly submitted Poor Overlap Retrospective jobs are properly configured with the fixed WDSM implementation

3. **Check if Prospective results are needed**: If the Prospective analysis results are important, you may need to debug and resubmit those jobs separately
