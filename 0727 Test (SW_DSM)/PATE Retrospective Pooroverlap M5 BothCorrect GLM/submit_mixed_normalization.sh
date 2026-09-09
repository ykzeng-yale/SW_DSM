#!/bin/bash
# Submit Mixed Normalization Version
# PS Full: Normalized weights (w × n/sum(w))
# WDSM: Raw weights (1/sampling_prob)

REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_mixed_20250809"

echo "================================================================"
echo "Submitting MIXED NORMALIZATION VERSION"
echo "PS Full: Normalized weights | WDSM: Raw weights"
echo "Remote directory: $REMOTE_DIR"
echo "================================================================"
echo ""

# Upload files
echo "Uploading files..."

echo "  1. Mixed normalization comparison script..."
scp compare_methods_pate_retrospective_mccleary_mixed.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/compare_methods_pate_retrospective_mccleary.R

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
echo "================================================================"
echo "✅ Mixed Normalization Version Submitted!"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "Monitor with:"
echo "  ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u yz2324'"
echo "================================================================"
