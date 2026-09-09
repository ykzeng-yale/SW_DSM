#!/bin/bash

# Submit M=5 100-rep jobs to LI_FAN account (day partition)
echo "============================================================"
echo "Submitting M=5 100-Replication Jobs to LI_FAN Account (Day Partition)"
echo "============================================================"

# Create timestamp for unique directory
TIMESTAMP=$(date +%Y%m%d_%H%M)

# Create remote directory under tong path
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_M5_100rep_Poor_$TIMESTAMP"
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload necessary files
echo ""
echo "Uploading files to $REMOTE_DIR ..."

# Upload M5 100-rep R scripts
echo "  Uploading M=5 100-rep R scripts..."
scp comprehensive_patt_comparison_*_M5_100rep.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload FIXED WDSM directory
echo "  Uploading FIXED WDSM directory..."
scp -r ../WDSM yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload dsmatch-master directory
echo "  Uploading dsmatch-master directory..."
scp -r ../dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload population data
echo "  Uploading population data..."
scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload submission scripts for 100-rep
echo "  Uploading submission scripts..."
scp run_*_M5_100rep_day.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo ""
echo "============================================================"
echo "Submitting M=5 100-rep Jobs to LI_FAN Account..."
echo "============================================================"

# Submit M=5 100-rep jobs to day partition with li_fan account
echo ""
echo "1. Submitting CorCor M=5 100-rep (LI_FAN account)..."
JOB1=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorCor_M5_100rep_day.sh" | awk '{print $4}')
echo "   Job ID: $JOB1"

echo "2. Submitting MisCor M=5 100-rep (LI_FAN account)..."
JOB2=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisCor_M5_100rep_day.sh" | awk '{print $4}')
echo "   Job ID: $JOB2"

echo "3. Submitting CorMis M=5 100-rep (LI_FAN account)..."
JOB3=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorMis_M5_100rep_day.sh" | awk '{print $4}')
echo "   Job ID: $JOB3"

echo "4. Submitting MisMis M=5 100-rep (LI_FAN account)..."
JOB4=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisMis_M5_100rep_day.sh" | awk '{print $4}')
echo "   Job ID: $JOB4"

echo ""
echo "============================================================"
echo "✅ M=5 100-rep Jobs Submitted to LI_FAN Account Successfully!"
echo "============================================================"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "LI_FAN Account Jobs (M=5, 100 Replications - Day Partition - 22h timeout):"
echo "  CorCor: $JOB1"
echo "  MisCor: $JOB2"
echo "  CorMis: $JOB3"
echo "  MisMis: $JOB4"
echo ""
echo "Key Features:"
echo "  ✓ Running under LI_FAN account"
echo "  ✓ M=5 only for faster results"
echo "  ✓ 100 replications (reduced from 1000)"
echo "  ✓ 20 cores, 8GB per CPU"
echo "  ✓ 20 replications per batch"
echo "  ✓ Fixed WDSM implementation"
echo "  ✓ Correct model specifications"
echo ""
echo "Expected runtime: 2-4 hours"
echo "============================================================"
echo ""
echo "To check status:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER | grep \"CorCor_M5_100rep\\|MisCor_M5_100rep\\|CorMis_M5_100rep\\|MisMis_M5_100rep\"'"
echo ""
echo "To monitor output:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/*_M5_100rep_*.out'"
echo ""
echo "To download results when complete:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_*_M5_100rep_Pooroverlap_results.RData ."
echo ""
