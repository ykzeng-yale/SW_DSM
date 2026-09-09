# Job Status Update - 2025-01-19

## ❌ 100-Rep Jobs (li_fan account) - NOT FINISHED

### Current Status: **PENDING**

| Job ID   | Scenario | Status  | Estimated Start | Reason    |
|----------|----------|---------|-----------------|-----------|
| 57628018 | CorCor   | PENDING | Aug 17, 02:44   | Priority  |
| 57628020 | MisCor   | PENDING | Aug 17, 02:44   | Priority  |
| 57628021 | CorMis   | PENDING | Aug 17, 02:45   | Priority  |
| 57628023 | MisMis   | PENDING | Aug 17, 02:45   | Priority  |

**Status**: These jobs have not started yet. They are queued with "Priority" status, meaning they're waiting for resources to become available.

### Queue Position
- Currently **40+ jobs** ahead in the li_fan account queue
- 2 li_fan jobs currently running (57613769, 57613768)
- Expected wait time: Several hours to days

## ⚠️ Tong Account Jobs - FAILED

### Node Failure Issues
The tong account M5 jobs (1000 reps) that were running have **FAILED** due to NODE_FAIL:

| Job ID   | Scenario | Runtime Before Failure | Status     |
|----------|----------|------------------------|------------|
| 57622901 | CorCor   | 10:03:01              | NODE_FAIL  |
| 57622902 | MisCor   | 07:38:04              | NODE_FAIL  |
| 57622903 | CorMis   | 07:28:09              | NODE_FAIL  |
| 57622904 | MisMis   | 07:21:04              | NODE_FAIL  |

**Issue**: These jobs encountered hardware failures on the compute nodes after running for 7-10 hours.

## 📊 Summary

1. **100-rep jobs (li_fan)**: Still pending, haven't started yet
2. **1000-rep jobs (tong)**: Failed due to node issues after partial completion
3. **No completed results available yet**

## Recommendations

1. **Wait for 100-rep jobs**: These should eventually start and complete within 2-4 hours once running
2. **Consider resubmitting tong jobs**: The failed 1000-rep jobs could be resubmitted if full results are needed
3. **Check queue periodically**: 
   ```bash
   ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep -E "57628018|57628020|57628021|57628023"'
   ```

## Expected Timeline
- The 100-rep jobs may take **1-2 more days** to start given the queue length
- Once started, they should complete in **2-4 hours**
