#!/bin/bash
# Submit the comprehensive PATT comparison to McCleary HPC (M=1,3,5 with Model Specifications - Poor Overlap)
# Configuration: 30 cores, 8GB/CPU, batch_size=100, 1000 replicates x 4 model specs x 3 M values

echo "=== Submitting Comprehensive PATT Comparison M=1,3,5 with Model Specifications (Poor Overlap) ==="
echo "=== (1000 replicates, 30 cores, 4 model specifications) ==="

# Create unique directory name with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M)
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_Poor_$TIMESTAMP"

# Create output directory structure
echo "Creating remote directory: $REMOTE_DIR"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

# Upload required files
echo "Uploading files to $REMOTE_DIR ..."

echo "  Uploading R script..."
scp comprehensive_patt_comparison_mccleary.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading WDSM directory..."
scp -r WDSM yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading dsmatch-master directory..."
scp -r dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading population data..."
scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  Uploading submission script..."
scp run_patt_comparison_mccleary.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Submit the job
echo ""
echo "Submitting job..."
JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_patt_comparison_mccleary.sh" | awk '{print $4}')

echo ""
echo "✅ PATT comparison M=1,3,5 with Model Specifications (Poor Overlap) submitted successfully!"
echo "============================================================"
echo "Job ID: $JOB_ID"
echo "Remote directory: $REMOTE_DIR"
echo "Configuration:"
echo "  - 32 CPUs requested (30 for R + overhead)"
echo "  - 8GB per CPU (~256GB total)"
echo "  - FORK cluster type"
echo "  - 1000 replicates x 4 model specs x 3 M values"
echo "  - Model specs: CorCor, MisCor, CorMis, MisMis"
echo "  - 30 cores for parallel processing"
echo "  - Batch size: 100"
echo "  - Methods: DSM, PG, PS (unweighted) + PS Full, WDSM (survey-weighted)"
echo "  - Time limit: 22 hours (day partition)"
echo "  - Expected runtime: 10-15 hours (4x model specs × 3x M values)"
echo "============================================================"
echo ""
echo "To check status:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j $JOB_ID'"
echo ""
echo "To monitor output:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f $REMOTE_DIR/patt_M135_CorAndMis_Poor_*.out'"
echo ""
echo "To download results when complete:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap* ."
echo ""
echo "To download all output:"
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/*.RData ."
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/*.csv ."
echo "  scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/*.pdf ."
echo ""