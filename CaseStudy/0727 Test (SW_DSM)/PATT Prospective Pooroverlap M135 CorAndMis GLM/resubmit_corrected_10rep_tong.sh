#!/bin/bash

# Cancel and resubmit corrected 10-rep test jobs to TONG account
echo "============================================================"
echo "Canceling old jobs and resubmitting CORRECTED 10-Rep TEST Jobs"
echo "============================================================"

# Try to cancel old jobs (might already be done)
echo "Attempting to cancel old jobs 57731699, 57731702, 57731704, 57731705..."
ssh yz2324@login2.mccleary.ycrc.yale.edu 'scancel 57731699 57731702 57731704 57731705 2>/dev/null'

# Create timestamp for unique directory
TIMESTAMP=$(date +%Y%m%d_%H%M)

# Use the same remote directory but with new timestamp
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_CORRECTED_$TIMESTAMP"
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload necessary files
echo ""
echo "Uploading CORRECTED files to $REMOTE_DIR ..."

# Upload CORRECTED 10-rep R scripts
echo "  Uploading CORRECTED M=5 10-rep test R scripts (with PS Full fix)..."
scp comprehensive_patt_comparison_*_M5_10rep.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload FIXED WDSM directory
echo "  Uploading FIXED WDSM directory..."
scp -r ../WDSM yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload dsmatch-master directory
echo "  Uploading dsmatch-master directory..."
scp -r ../dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload population data
echo "  Uploading population data..."
scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload submission scripts for 10-rep test
echo "  Uploading submission scripts..."
scp run_*_M5_10rep_tong.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo ""
echo "============================================================"
echo "Submitting CORRECTED M=5 10-rep TEST Jobs to TONG Account..."
echo "============================================================"

# Submit CORRECTED 10-rep test jobs to day partition with tong account
echo ""
echo "1. Submitting CORRECTED CorCor M=5 10-rep TEST (TONG account)..."
JOB1=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorCor_M5_10rep_tong.sh" | awk '{print $4}')
echo "   Job ID: $JOB1"

echo "2. Submitting CORRECTED MisCor M=5 10-rep TEST (TONG account)..."
JOB2=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisCor_M5_10rep_tong.sh" | awk '{print $4}')
echo "   Job ID: $JOB2"

echo "3. Submitting CORRECTED CorMis M=5 10-rep TEST (TONG account)..."
JOB3=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorMis_M5_10rep_tong.sh" | awk '{print $4}')
echo "   Job ID: $JOB3"

echo "4. Submitting CORRECTED MisMis M=5 10-rep TEST (TONG account)..."
JOB4=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisMis_M5_10rep_tong.sh" | awk '{print $4}')
echo "   Job ID: $JOB4"

echo ""
echo "============================================================"
echo "✅ CORRECTED M=5 10-rep TEST Jobs Submitted to TONG Account!"
echo "============================================================"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "TONG Account TEST Jobs (M=5, 10 Replications, CORRECTED):"
echo "  CorCor: $JOB1"
echo "  MisCor: $JOB2"
echo "  CorMis: $JOB3"
echo "  MisMis: $JOB4"
echo ""
echo "Key Fixes Applied:"
echo "  ✅ PS Full outcome model ALWAYS uses full interactions: Y ~ A * (x1 + x2 + x3 + x4 + x5 + x6 + x1_x2)"
echo "  ✅ Bootstrap also creates x1_x2 interaction for consistency"
echo "  ✅ Fixed WDSM parameter passing (ps_form -> ps_formula)"
echo "  ✅ Fixed variable naming (z->A, y->Y, etc.)"
echo ""
echo "Expected runtime: 15-30 minutes"
echo "============================================================"
echo ""
echo "To check status:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue --account=tong -u \$USER | grep \"10rep\"'"
echo ""
echo "To monitor output:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/tong_*_10rep_*.out'"
echo ""
echo "To download results when complete:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_*_M5_10rep_Pooroverlap_results.RData ."
echo ""
echo "If successful, scale up to 1000 replications!"
echo ""
