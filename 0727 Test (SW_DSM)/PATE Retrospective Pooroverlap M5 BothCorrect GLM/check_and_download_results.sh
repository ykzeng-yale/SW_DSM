#!/bin/bash
# Quick script to check job status and download results

JOB_ID=57161953
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_weighted_20250807"

echo "============================================================"
echo "Checking status of PATE Retrospective Poor Overlap job"
echo "============================================================"

# Check job status
echo "Checking job status (Job ID: $JOB_ID)..."
ssh yz2324@login2.mccleary.ycrc.yale.edu "squeue -j $JOB_ID 2>/dev/null || echo 'Job not in queue (likely completed or failed)'"

echo ""
echo "Checking for output files..."
ssh yz2324@login2.mccleary.ycrc.yale.edu "ls -lh $REMOTE_DIR/pate_retrospective_*.* 2>/dev/null || echo 'No output files found yet'"

echo ""
echo "============================================================"
echo "To download results (when ready), run:"
echo "============================================================"
echo "scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/pate_retrospective_*.RData ."
echo "scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/pate_retrospective_*.pdf ."
echo "scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/pate_retrospective_*.csv ."
echo ""
echo "Or download all outputs:"
echo "scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/* ."