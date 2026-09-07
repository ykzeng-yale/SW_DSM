# PATE Retrospective Test Run (100 Replicates)

## Overview
This is a TEST VERSION with 100 replicates to verify everything works correctly on McCleary before running the full 1000 replicates.

## Changes Made for Test Version:
1. **Reduced replicates**: 100 instead of 1000
2. **Shorter time limit**: 2 hours instead of 8 hours
3. **Job name**: `pate_retro_test` to distinguish from full run

## To Submit Test Run:

```bash
# Make sure script is executable
chmod +x mccleary_submit_retrospective.sh

# Submit test version
./mccleary_submit_retrospective.sh
```

## Expected Behavior:
- **Runtime**: 30-60 minutes
- **Success rate**: Should be close to 100% with FORK cluster
- **Output files**: Same as full version but with only 100 replicates

## After Test Run Succeeds:

1. **Check results**:
   - Verify all 5 methods completed successfully
   - Check coverage rates are reasonable
   - Ensure no systematic errors

2. **For full 1000-replicate run**:
   - Edit `compare_methods_pate_retrospective_mccleary.R`
   - Change `n_reps <- 100` back to `n_reps <- 1000`
   - Update submission script time limit back to 8 hours
   - Resubmit with updated parameters

## Files to Check After Test:
- `pate_retro_*.out` - Job output log
- `pate_retro_*.err` - Error log (should be empty or minimal)
- `parallel_log.txt` - Parallel processing details
- `pate_retrospective_comparison_results_mccleary.RData` - Results file
- `pate_retrospective_comparison_table_mccleary.csv` - Summary table

## Success Criteria:
- ✅ All 5 methods have valid estimates
- ✅ Coverage rates between 90-100%
- ✅ No major errors in log files
- ✅ Complete replicates ≥ 90 out of 100

## Troubleshooting:
If errors occur:
1. Check error logs for specific method failures
2. Verify all required files were uploaded
3. Ensure FORK cluster type is being used
4. Check memory usage wasn't exceeded

## Next Steps:
Once test succeeds, you can confidently run the full 1000-replicate version!