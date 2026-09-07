#!/bin/bash

# Helper script to submit M135 experiment to McCleary HPC

echo "============================================================"
echo "SUBMITTING M135 EXPERIMENT TO MCCLEARY HPC"
echo "============================================================"
echo ""
echo "Configuration:"
echo "  - Partition: day (faster allocation)"
echo "  - Time limit: 23:59:00"
echo "  - M values: 1, 3, 5"
echo "  - Replicates: 1000"
echo "  - Methods: 5 (DSM, PG, PS, PS-weighted, WDSM)"
echo ""
echo "============================================================"
echo "Step 1: Connecting to McCleary..."
echo "============================================================"

# Define server and paths
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/PATE_Retrospective_Goodoverlap_M135_BothCorrect_GLM"
LOCAL_DIR="."

echo "Target directory: $REMOTE_DIR"
echo ""

# Upload files
echo "============================================================"
echo "Step 2: Uploading files to McCleary..."
echo "============================================================"
echo "Creating remote directory..."
ssh $SERVER "mkdir -p $REMOTE_DIR/dsmatch-master/R"

echo "Uploading main files..."
scp compare_methods_pate_retrospective_mccleary.R $SERVER:$REMOTE_DIR/
scp submit_pate_retrospective_mccleary.sh $SERVER:$REMOTE_DIR/
scp wdsm_method2_multinomial_bootstrap.R $SERVER:$REMOTE_DIR/
scp wdsm_ci_functions.R $SERVER:$REMOTE_DIR/
scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData $SERVER:$REMOTE_DIR/

echo "Uploading dsmatch functions..."
scp -r dsmatch-master/R/*.R $SERVER:$REMOTE_DIR/dsmatch-master/R/

echo ""
echo "============================================================"
echo "Step 3: Submitting job..."
echo "============================================================"
ssh $SERVER "cd $REMOTE_DIR && sbatch submit_pate_retrospective_mccleary.sh"

echo ""
echo "============================================================"
echo "Step 4: Checking job status..."
echo "============================================================"
ssh $SERVER "squeue -u yz2324"

echo ""
echo "============================================================"
echo "SUBMISSION COMPLETE!"
echo "============================================================"
echo ""
echo "To monitor the job:"
echo "  ssh $SERVER"
echo "  squeue -u yz2324"
echo ""
echo "To check output:"
echo "  ssh $SERVER"
echo "  cd $REMOTE_DIR"
echo "  tail -f pate_retro_M135_*.out"
echo ""
echo "To download results (after completion):"
echo "  scp $SERVER:$REMOTE_DIR/pate_retrospective_comparison_results_mccleary_M135.RData ."
echo "  scp $SERVER:$REMOTE_DIR/pate_retrospective_comparison_plot_mccleary_M135.pdf ."
echo "  scp $SERVER:$REMOTE_DIR/pate_retrospective_comparison_table_mccleary_M135.csv ."
echo ""
echo "============================================================"