#!/bin/bash

# McCleary HPC Submission Script for PATE Retrospective Pooroverlap M135 CorMis

echo "============================================================"
echo "PATE Retrospective Poor Overlap CorMis Scenario"
echo "Scenario: Both PS and PGS misspecified (no X1:X2)"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_CorMis"
LOCAL_DIR="."

# Step 1: Create remote directory
echo "Creating remote directory..."
ssh $SERVER "mkdir -p $REMOTE_DIR"

# Step 2: Upload files
echo "Uploading files to McCleary..."
rsync -avz --progress \
  --exclude="*.RData" \
  --exclude="*.pdf" \
  --exclude="*.csv" \
  --exclude="*.txt" \
  --exclude="*.md" \
  --exclude="*.log" \
  --exclude="*.out" \
  --exclude="*.err" \
  $LOCAL_DIR/ $SERVER:$REMOTE_DIR/

# Step 3: Submit job
echo "Submitting job to McCleary..."
ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_optimized.sh"

echo "============================================================"
echo "Job submitted successfully!"
echo "To check status: ssh $SERVER 'squeue -u \$USER'"
echo "To check output: ssh $SERVER 'ls -la $REMOTE_DIR/*.out'"
echo "============================================================"