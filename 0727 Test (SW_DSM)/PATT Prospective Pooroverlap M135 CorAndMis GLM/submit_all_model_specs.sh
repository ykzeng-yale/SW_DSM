#!/bin/bash

# Submit all 4 model specification jobs separately to HPC
# This allows each to run independently and finish faster

echo "============================================================"
echo "Submitting All Model Specification Jobs (Poor Overlap)"
echo "============================================================"

# Create timestamp for unique directory
TIMESTAMP=$(date +%Y%m%d_%H%M)

# Create remote directory
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_ModelSpecs_Poor_$TIMESTAMP"
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload necessary files
echo ""
echo "Uploading files to $REMOTE_DIR ..."

# Upload all R scripts
echo "  Uploading R scripts..."
scp comprehensive_patt_comparison_*.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload WDSM and dsmatch directories
echo "  Uploading WDSM directory..."
scp -r WDSM yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading dsmatch-master directory..."
scp -r dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload population data
echo "  Uploading population data..."
scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Upload submission scripts
echo "  Uploading submission scripts..."
scp run_*_mccleary.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo ""
echo "============================================================"
echo "Submitting jobs..."
echo "============================================================"

# Submit all 4 jobs
echo ""
echo "1. Submitting CorCor job..."
JOB1=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorCor_mccleary.sh" | awk '{print $4}')
echo "   Job ID: $JOB1"

echo "2. Submitting MisCor job..."
JOB2=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisCor_mccleary.sh" | awk '{print $4}')
echo "   Job ID: $JOB2"

echo "3. Submitting CorMis job..."
JOB3=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorMis_mccleary.sh" | awk '{print $4}')
echo "   Job ID: $JOB3"

echo "4. Submitting MisMis job..."
JOB4=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisMis_mccleary.sh" | awk '{print $4}')
echo "   Job ID: $JOB4"

echo ""
echo "============================================================"
echo "✅ All 4 Model Specification Jobs Submitted Successfully!"
echo "============================================================"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "Job IDs:"
echo "  CorCor: $JOB1"
echo "  MisCor: $JOB2"
echo "  CorMis: $JOB3"
echo "  MisMis: $JOB4"
echo ""
echo "Configuration for each job:"
echo "  - 32 CPUs (30 for R + overhead)"
echo "  - 8GB per CPU (~256GB total)"
echo "  - FORK cluster type"
echo "  - 1000 replicates x 3 M values (M=1,3,5)"
echo "  - 30 cores for parallel processing"
echo "  - Time limit: 22 hours (day partition)"
echo "  - Expected runtime: 3-4 hours per job"
echo "============================================================"
echo ""
echo "To check status of all jobs:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER'"
echo ""
echo "To monitor a specific job (replace JOB_ID):"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/patt_*_Poor_JOB_ID.out'"
echo ""
echo "To download results when complete:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_*_Pooroverlap_results.RData ."
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_*_Pooroverlap_table.csv ."
echo ""
