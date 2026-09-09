#!/bin/bash

# Submit M=5 only jobs to TONG account (day partition)
echo "============================================================"
echo "Submitting M=5 Only Jobs to TONG Account (Day Partition)"
echo "============================================================"

# Create timestamp for unique directory
TIMESTAMP=$(date +%Y%m%d_%H%M)

# Create remote directory under tong account path
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_M5_Poor_TongAccount_$TIMESTAMP"
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload necessary files
echo ""
echo "Uploading files to $REMOTE_DIR ..."

# Upload M5 R scripts
echo "  Uploading M=5 R scripts..."
scp comprehensive_patt_comparison_*_M5.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload FIXED WDSM directory
echo "  Uploading FIXED WDSM directory..."
scp -r ../WDSM yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload dsmatch-master directory
echo "  Uploading dsmatch-master directory..."
scp -r ../dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload population data
echo "  Uploading population data..."
scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload submission scripts for tong account
echo "  Uploading submission scripts..."
scp run_*_M5_tong.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo ""
echo "============================================================"
echo "Submitting M=5 Jobs to TONG Account..."
echo "============================================================"

# Submit M=5 only jobs to day partition with tong account
echo ""
echo "1. Submitting CorCor M=5 (TONG account)..."
TONG1=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorCor_M5_tong.sh" | awk '{print $4}')
echo "   Job ID: $TONG1"

echo "2. Submitting MisCor M=5 (TONG account)..."
TONG2=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisCor_M5_tong.sh" | awk '{print $4}')
echo "   Job ID: $TONG2"

echo "3. Submitting CorMis M=5 (TONG account)..."
TONG3=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorMis_M5_tong.sh" | awk '{print $4}')
echo "   Job ID: $TONG3"

echo "4. Submitting MisMis M=5 (TONG account)..."
TONG4=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisMis_M5_tong.sh" | awk '{print $4}')
echo "   Job ID: $TONG4"

echo ""
echo "============================================================"
echo "✅ M=5 Jobs Submitted to TONG Account Successfully!"
echo "============================================================"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "TONG Account Jobs (M=5 Only - Day Partition - 22h timeout):"
echo "  CorCor: $TONG1"
echo "  MisCor: $TONG2"
echo "  CorMis: $TONG3"
echo "  MisMis: $TONG4"
echo ""
echo "Key Features:"
echo "  ✓ Running under TONG account (not li_fan)"
echo "  ✓ M=5 only for faster results"
echo "  ✓ Fixed WDSM implementation"
echo "  ✓ Correct model specifications"
echo ""
echo "Expected runtime: 8-15 hours"
echo "============================================================"
echo ""
echo "To check TONG account jobs:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue --account=tong -u \$USER'"
echo ""
echo "To check ALL your jobs:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER'"
echo ""
echo "To monitor output:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/tong_*_M5_*.out'"
echo ""
echo "To download results when complete:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_*_M5_Pooroverlap_results.RData ."
echo ""

