#!/bin/bash
# Submit the PATT retrospective comparison with 1000 replicates
# Configuration: 20 cores, 8GB/CPU, batch_size=100

echo "=== Submitting PATT Retrospective Comparison (1000 replicates, 20 cores) ==="

# Create unique directory name with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M)
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_retrospective_$TIMESTAMP"

# Create output directory structure
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload required files
echo "Uploading files to $REMOTE_DIR ..."

echo "  Uploading PATT retrospective comparison R script..."
scp compare_methods_patt_retrospective_mccleary.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading wdsm_patt_v2_standard.R..."
scp wdsm_patt_v2_standard.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData..."
scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading dsmatch-master directory..."
scp -r dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading submission script..."
scp submit_patt_retrospective_mccleary.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Submit the job
echo ""
echo "Submitting PATT retrospective comparison job..."
JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch submit_patt_retrospective_mccleary.sh" | awk '{print $4}')

echo ""
echo "✅ PATT retrospective comparison submitted successfully!"
echo "============================================================"
echo "Job ID: $JOB_ID"
echo "Remote directory: $REMOTE_DIR"
echo "Configuration:"
echo "  - 22 CPUs requested (20 for R + overhead)"
echo "  - 8GB per CPU (~176GB total)"
echo "  - FORK cluster type"
echo "  - 1000 replicates"
echo "  - 20 cores"
echo "  - Batch size: 100"
echo "  - Expected runtime: 90-120 minutes"
echo "============================================================"
echo ""
echo "To check status:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j $JOB_ID'"
echo ""
echo "To monitor output:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/patt_retrospective_*.out'"
echo ""
echo "To download results when complete:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_retrospective_* ."
echo ""
echo "To check parallel log:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -100 $REMOTE_DIR/parallel_log.txt'"
echo ""