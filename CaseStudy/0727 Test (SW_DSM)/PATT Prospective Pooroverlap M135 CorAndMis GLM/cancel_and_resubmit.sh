#!/bin/bash

echo "============================================================"
echo "Cancelling Current Jobs and Resubmitting with Fixed WDSM"
echo "============================================================"

# Job IDs to cancel
JOB_IDS="57549714 57549716 57549717 57549737"

echo ""
echo "Cancelling jobs: $JOB_IDS"
for JOB in $JOB_IDS; do
  echo "  Cancelling job $JOB..."
  ssh yz2324@login2.mccleary.ycrc.yale.edu "scancel $JOB"
done

echo ""
echo "Waiting for jobs to cancel..."
sleep 5

echo ""
echo "============================================================"
echo "Resubmitting with Fixed WDSM and Model Specifications"
echo "============================================================"

# Create timestamp for unique directory
TIMESTAMP=$(date +%Y%m%d_%H%M)

# Create remote directory
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_ModelSpecs_Poor_Fixed_$TIMESTAMP"
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload necessary files
echo ""
echo "Uploading files to $REMOTE_DIR ..."

# Upload all R scripts
echo "  Uploading R scripts..."
scp comprehensive_patt_comparison_*.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload FIXED WDSM directory
echo "  Uploading FIXED WDSM directory..."
scp -r ../WDSM yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload dsmatch-master directory
echo "  Uploading dsmatch-master directory..."
scp -r ../dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload population data
echo "  Uploading population data..."
scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload submission scripts
echo "  Uploading submission scripts..."
scp run_*_mccleary.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo ""
echo "============================================================"
echo "Submitting fixed jobs..."
echo "============================================================"

# Submit all 4 jobs
echo ""
echo "1. Submitting CorCor job (both models correct)..."
JOB1=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorCor_mccleary.sh" | awk '{print $4}')
echo "   Job ID: $JOB1"

echo "2. Submitting MisCor job (PS misspecified, PGS correct)..."
JOB2=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisCor_mccleary.sh" | awk '{print $4}')
echo "   Job ID: $JOB2"

echo "3. Submitting CorMis job (PS correct, PGS misspecified)..."
JOB3=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorMis_mccleary.sh" | awk '{print $4}')
echo "   Job ID: $JOB3"

echo "4. Submitting MisMis job (both misspecified)..."
JOB4=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisMis_mccleary.sh" | awk '{print $4}')
echo "   Job ID: $JOB4"

echo ""
echo "============================================================"
echo "✅ Fixed Jobs Submitted Successfully!"
echo "============================================================"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "New Job IDs:"
echo "  CorCor: $JOB1"
echo "  MisCor: $JOB2"
echo "  CorMis: $JOB3"
echo "  MisMis: $JOB4"
echo ""
echo "Key Fixes Applied:"
echo "  ✓ WDSM no longer hardcodes interaction terms"
echo "  ✓ Each model spec correctly configures PS and PGS formulas"
echo "  ✓ Interaction terms only included when needed"
echo ""
echo "Expected runtime: 3-4 hours per job"
echo "============================================================"
echo ""
echo "To check status:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER'"
echo ""
echo "To monitor output:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/patt_*_Poor_*.out'"
echo ""
echo "To download results when complete:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_*_Pooroverlap_results.RData ."
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_*_Pooroverlap_table.csv ."
echo ""
