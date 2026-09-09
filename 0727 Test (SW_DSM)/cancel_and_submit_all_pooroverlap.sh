#!/bin/bash

echo "============================================================"
echo "Canceling Current Jobs and Submitting to Different Partitions"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"

# Cancel current pending jobs
echo "Step 1: Canceling current pending jobs..."
PENDING_JOBS="57567348 57567349 57567351 57567352"
for job_id in $PENDING_JOBS; do
    echo "Canceling job $job_id..."
    ssh $SERVER "scancel $job_id 2>/dev/null"
done

echo ""
echo "Step 2: Submitting to WEEK partition (Full M=1,3,5)..."
echo "============================================================"
./submit_pooroverlap_week_partition.sh

echo ""
echo "Step 3: Submitting to DAY partition (M=5 only)..."
echo "============================================================"
./submit_pooroverlap_M5_day_partition.sh

echo ""
echo "============================================================"
echo "All submissions complete!"
echo "============================================================"
echo ""
echo "Summary:"
echo "  - WEEK partition: Full analysis with M=1,3,5 (7 days)"
echo "  - DAY partition: Quick analysis with M=5 only (22 hours)"
echo ""
echo "The M=5 jobs should complete within 22 hours and give preliminary results."
echo "The full M=1,3,5 jobs will run for up to 7 days for complete analysis."
echo "============================================================"
