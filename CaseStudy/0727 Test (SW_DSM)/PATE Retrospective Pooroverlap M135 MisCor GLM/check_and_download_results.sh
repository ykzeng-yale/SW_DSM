#!/bin/bash

# McCleary HPC Results Download Script

echo "============================================================"
echo "Checking and Downloading Results from McCleary"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_corandmis"
LOCAL_DIR="."

# Step 1: Check job status
echo "Checking job status..."
ssh $SERVER "squeue -u \$USER"

# Step 2: Check output files
echo ""
echo "Checking output files..."
ssh $SERVER "ls -lah $REMOTE_DIR/*.out $REMOTE_DIR/*.err $REMOTE_DIR/*.RData $REMOTE_DIR/*.csv 2>/dev/null"

# Step 3: Download results
echo ""
echo "Downloading results..."
rsync -avz --progress \
  $SERVER:$REMOTE_DIR/*.RData \
  $SERVER:$REMOTE_DIR/*.csv \
  $SERVER:$REMOTE_DIR/*.out \
  $SERVER:$REMOTE_DIR/*.err \
  $LOCAL_DIR/

echo "============================================================"
echo "Download complete!"
echo "============================================================"