#!/bin/bash
# Submit the PATE Retrospective comparison to McCleary HPC
# Configuration: 20 cores, 8GB/CPU, batch_size=100

echo "=== Submitting PATE Retrospective Comparison (1000 replicates, 20 cores) ==="

# Create unique directory name with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M)
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retro_$TIMESTAMP"

# Create output directory structure
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload required files
echo ""
echo "Uploading files to $REMOTE_DIR ..."

echo "  1. Uploading main comparison script..."
scp compare_methods_pate_retrospective_mccleary.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  2. Uploading WDSM functions..."
scp wdsm_method2_multinomial_bootstrap.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/
scp wdsm_ci_functions.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  3. Uploading population data..."
scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  4. Uploading dsmatch-master directory..."
scp -r dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  5. Uploading submission script..."
scp submit_pate_retrospective_mccleary.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Submit the job
echo ""
echo "Submitting job..."
JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch submit_pate_retrospective_mccleary.sh" | awk '{print $4}')

echo ""
echo "✅ PATE Retrospective comparison submitted successfully!"
echo "============================================================"
echo "Job ID: $JOB_ID"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "Configuration:"
echo "  - 22 CPUs requested (20 for R + overhead)"
echo "  - 8GB per CPU (~176GB total)"
echo "  - FORK cluster type"
echo "  - 1000 replicates (FULL RUN)"
echo "  - 5000 sample size (retrospective)"
echo "  - 200 bootstrap iterations"
echo "  - 5 methods being compared"
echo "  - Expected runtime: 1.5-2 hours (based on 8.84 min for 100 reps)"
echo "============================================================"
echo ""
echo "Useful commands:"
echo ""
echo "Check status:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j $JOB_ID'"
echo ""
echo "Monitor output:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/pate_retro_*.out'"
echo ""
echo "Check parallel log:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/parallel_log.txt'"
echo ""
echo "Download results when complete:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/pate_retrospective_*.RData ."
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/pate_retrospective_*.pdf ."
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/pate_retrospective_*.csv ."
echo ""
echo "Download all outputs:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/* ."
echo ""
echo "============================================================"