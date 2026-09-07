#!/bin/bash

# Submit M=5 10-rep test jobs to TONG account
echo "============================================================"
echo "Submitting M=5 10-Rep TEST Jobs to TONG Account"
echo "============================================================"

# Create timestamp for unique directory
TIMESTAMP=$(date +%Y%m%d_%H%M)

# Create remote directory under tong account path
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_TEST_$TIMESTAMP"
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload necessary files
echo ""
echo "Uploading files to $REMOTE_DIR ..."

# Upload 10-rep R scripts
echo "  Uploading M=5 10-rep test R scripts..."
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
echo "Submitting M=5 10-rep TEST Jobs to TONG Account..."
echo "============================================================"

# Submit 10-rep test jobs to day partition with tong account
echo ""
echo "1. Submitting CorCor M=5 10-rep TEST (TONG account)..."
JOB1=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorCor_M5_10rep_tong.sh" | awk '{print $4}')
echo "   Job ID: $JOB1"

echo "2. Submitting MisCor M=5 10-rep TEST (TONG account)..."
JOB2=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisCor_M5_10rep_tong.sh" | awk '{print $4}')
echo "   Job ID: $JOB2"

echo "3. Submitting CorMis M=5 10-rep TEST (TONG account)..."
JOB3=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorMis_M5_10rep_tong.sh" | awk '{print $4}')
echo "   Job ID: $JOB3"

echo "4. Submitting MisMis M=5 10-rep TEST (TONG account)..."
JOB4=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisMis_M5_10rep_tong.sh" | awk '{print $4}')
echo "   Job ID: $JOB4"

echo ""
echo "============================================================"
echo "✅ M=5 10-rep TEST Jobs Submitted to TONG Account!"
echo "============================================================"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "TONG Account TEST Jobs (M=5, 10 Replications):"
echo "  CorCor: $JOB1"
echo "  MisCor: $JOB2"
echo "  CorMis: $JOB3"
echo "  MisMis: $JOB4"
echo ""
echo "Key Features:"
echo "  ✓ Running under TONG account"
echo "  ✓ M=5 only"
echo "  ✓ 10 replications for quick test"
echo "  ✓ 10 cores, 8GB per CPU"
echo "  ✓ 5 replications per batch"
echo "  ✓ Fixed WDSM implementation with parameter passing"
echo "  ✓ Fixed variable naming (z->A, y->Y, etc.)"
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
