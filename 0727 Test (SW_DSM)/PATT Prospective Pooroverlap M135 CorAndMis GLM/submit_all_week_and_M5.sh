#!/bin/bash

# Submit full M=1,3,5 to week partition and M=5 only to day partition
echo "============================================================"
echo "Submitting All Model Specs: Week (Full) and Day (M5 Only)"
echo "============================================================"

# Create timestamp for unique directory
TIMESTAMP=$(date +%Y%m%d_%H%M)

# Create remote directory
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_ModelSpecs_Poor_WeekAndM5_$TIMESTAMP"
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload necessary files
echo ""
echo "Uploading files to $REMOTE_DIR ..."

# Upload all R scripts (both full and M5 versions)
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
scp run_*_week.sh run_*_M5_day.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo ""
echo "============================================================"
echo "Submitting jobs to WEEK partition (Full M=1,3,5)..."
echo "============================================================"

# Submit full M=1,3,5 jobs to week partition
echo ""
echo "1. Submitting CorCor WEEK (Full M=1,3,5)..."
WEEK1=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorCor_week.sh" | awk '{print $4}')
echo "   Job ID: $WEEK1"

echo "2. Submitting MisCor WEEK (Full M=1,3,5)..."
WEEK2=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisCor_week.sh" | awk '{print $4}')
echo "   Job ID: $WEEK2"

echo "3. Submitting CorMis WEEK (Full M=1,3,5)..."
WEEK3=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorMis_week.sh" | awk '{print $4}')
echo "   Job ID: $WEEK3"

echo "4. Submitting MisMis WEEK (Full M=1,3,5)..."
WEEK4=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisMis_week.sh" | awk '{print $4}')
echo "   Job ID: $WEEK4"

echo ""
echo "============================================================"
echo "Submitting jobs to DAY partition (M=5 Only)..."
echo "============================================================"

# Submit M=5 only jobs to day partition
echo ""
echo "5. Submitting CorCor DAY (M=5 Only)..."
DAY1=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorCor_M5_day.sh" | awk '{print $4}')
echo "   Job ID: $DAY1"

echo "6. Submitting MisCor DAY (M=5 Only)..."
DAY2=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisCor_M5_day.sh" | awk '{print $4}')
echo "   Job ID: $DAY2"

echo "7. Submitting CorMis DAY (M=5 Only)..."
DAY3=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_CorMis_M5_day.sh" | awk '{print $4}')
echo "   Job ID: $DAY3"

echo "8. Submitting MisMis DAY (M=5 Only)..."
DAY4=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_MisMis_M5_day.sh" | awk '{print $4}')
echo "   Job ID: $DAY4"

echo ""
echo "============================================================"
echo "✅ All 8 Jobs Submitted Successfully!"
echo "============================================================"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "WEEK Partition Jobs (Full M=1,3,5 - 7 day timeout):"
echo "  CorCor: $WEEK1"
echo "  MisCor: $WEEK2"
echo "  CorMis: $WEEK3"
echo "  MisMis: $WEEK4"
echo ""
echo "DAY Partition Jobs (M=5 Only - 22 hour timeout):"
echo "  CorCor: $DAY1"
echo "  MisCor: $DAY2"
echo "  CorMis: $DAY3"
echo "  MisMis: $DAY4"
echo ""
echo "Key Features:"
echo "  ✓ WDSM fixed - no hardcoded interactions"
echo "  ✓ Each model spec correctly configured"
echo "  ✓ Week jobs: Full M=1,3,5 (longer runtime, 7 days)"
echo "  ✓ Day jobs: M=5 only (faster runtime, 22 hours)"
echo ""
echo "Expected runtime:"
echo "  - Week partition: 2-4 days"
echo "  - Day partition: 8-15 hours"
echo "============================================================"
echo ""
echo "To check status:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER'"
echo ""
echo "To monitor output:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/week_*_Poor_*.out'"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/day_*_M5_*.out'"
echo ""
echo "To download results when complete:"
echo "  # Full M=1,3,5 results:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_*_Pooroverlap_results.RData ."
echo "  # M=5 only results:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_*_M5_Pooroverlap_results.RData ."
echo ""
