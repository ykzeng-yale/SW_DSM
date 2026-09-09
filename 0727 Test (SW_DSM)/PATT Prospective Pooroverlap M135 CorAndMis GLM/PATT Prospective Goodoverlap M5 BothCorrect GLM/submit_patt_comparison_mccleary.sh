#!/bin/bash
# Submit the comprehensive PATT comparison to McCleary HPC
# Configuration: 20 cores, 8GB/CPU, batch_size=100, 1000 replicates

echo "=== Submitting Comprehensive PATT Comparison (1000 replicates, 20 cores) ==="

# Create unique directory name with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M)
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_comparison_$TIMESTAMP"

# Create output directory structure
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload required files
echo "Uploading files to $REMOTE_DIR ..."

echo "  Uploading R script..."
scp comprehensive_patt_comparison_mccleary.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading WDSM directory..."
scp -r WDSM yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading dsmatch-master directory..."
scp -r dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading population data..."
scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading submission script..."
scp run_patt_comparison_mccleary.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Submit the job
echo ""
echo "Submitting job..."
JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_patt_comparison_mccleary.sh" | awk '{print $4}')

echo ""
echo "✅ PATT comparison submitted successfully!"
echo "============================================================"
echo "Job ID: $JOB_ID"
echo "Remote directory: $REMOTE_DIR"
echo "Configuration:"
echo "  - 22 CPUs requested (20 for R + overhead)"
echo "  - 8GB per CPU (~176GB total)"
echo "  - FORK cluster type"
echo "  - 1000 replicates"
echo "  - 20 cores for parallel processing"
echo "  - Batch size: 100"
echo "  - Methods: DSM, PG, PS (unweighted) + PS Full, WDSM (survey-weighted)"
echo "  - Expected runtime: 60-90 minutes"
echo "============================================================"
echo ""
echo "To check status:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j $JOB_ID'"
echo ""
echo "To monitor output:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/patt_comparison_*.out'"
echo ""
echo "To download results when complete:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_* ."
echo ""
echo "To download all output:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/*.RData ."
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/*.csv ."
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/*.pdf ."
echo ""