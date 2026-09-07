#!/bin/bash
# Quick submission script for Bouchet test

echo "=========================================="
echo "Submitting Test Job to Bouchet Cluster"
echo "=========================================="
echo ""

# Configuration
REMOTE_USER="yz2324"
REMOTE_HOST="bouchet.ycrc.yale.edu"
REMOTE_DIR="/home/yz2324/"

# Files to upload
FILES="bouchet_test_job.R submit_bouchet_test.sh"

echo "Step 1: Uploading files to Bouchet..."
echo "  Host: $REMOTE_HOST"
echo "  Account: pi_gt353 (0.991 fairshare)"
echo ""

# Upload files
scp $FILES ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}

if [ $? -eq 0 ]; then
    echo ""
    echo "Step 2: Submitting job..."
    echo ""
    
    # Submit the job
    ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_DIR} && sbatch submit_bouchet_test.sh"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ SUCCESS! Test job submitted to Bouchet!"
        echo ""
        echo "With fairshare 0.991, your job should start within seconds!"
        echo ""
        echo "Monitor your job with:"
        echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} 'squeue -u \$USER'"
        echo ""
        echo "Check output with:"
        echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} 'ls -la bouchet_test_*.out'"
    else
        echo "❌ Job submission failed"
    fi
else
    echo "❌ File upload failed - check your connection"
fi
