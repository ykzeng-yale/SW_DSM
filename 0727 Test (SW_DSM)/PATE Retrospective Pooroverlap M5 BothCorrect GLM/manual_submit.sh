#!/bin/bash
# Manual submission script for weight-normalized version

REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_weighted_20250807"

echo "=== Submitting PATE Retrospective Poor Overlap (Weight Normalized) ==="
echo "Remote directory: $REMOTE_DIR"
echo ""

# Upload files
echo "Uploading files..."

echo "  1. Main comparison script..."
scp compare_methods_pate_retrospective_mccleary.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  2. WDSM functions..."
scp wdsm_method2_multinomial_bootstrap.R wdsm_ci_functions.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  3. Population data..."
scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  4. dsmatch-master directory..."
scp -r dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "  5. Submission script..."
scp submit_pate_retrospective_mccleary.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Submit the job
echo ""
echo "Submitting job..."
ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch submit_pate_retrospective_mccleary.sh"

echo ""
echo "✅ Submission complete!"
echo "Remote directory: $REMOTE_DIR"