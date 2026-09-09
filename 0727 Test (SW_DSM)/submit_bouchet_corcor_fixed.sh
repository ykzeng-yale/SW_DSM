#!/bin/bash

# Submit CorCor to Bouchet with package fix
# Date: 2025-08-27

echo "==========================================
Submitting CorCor to BOUCHET (Package Fixed)
==========================================
"

REMOTE_DIR="/nfs/roberts/project/pi_gt353/yz2324/pooroverlap_corcor_fixed_$(date +%Y%m%d_%H%M%S)"
BOUCHET_LOGIN="yz2324@bouchet.ycrc.yale.edu"

echo "Remote directory: $REMOTE_DIR"
echo ""

# Create remote directory
ssh $BOUCHET_LOGIN "mkdir -p $REMOTE_DIR"

# Prepare modified CorCor script
echo "Creating modified comparison script..."
LOCAL_DIR="PATE Retrospective Pooroverlap M135 CorCor GLM"
cp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R" \
   "$LOCAL_DIR/compare_methods_bouchet_fixed.R"

# Modify the script to handle missing marginaleffects package
sed -i '' 's/n_cores <- [0-9]*/n_cores <- 24/' "$LOCAL_DIR/compare_methods_bouchet_fixed.R"

# Add package check at the beginning of the script (after library statements)
sed -i '' '/library(glmnet)/a\
\
# Check if marginaleffects is available, skip PS Full if not\
has_marginaleffects <- requireNamespace("marginaleffects", quietly = TRUE)\
if (!has_marginaleffects) {\
  cat("Warning: marginaleffects package not available. PS Full Matching will be skipped.\\n")\
}\
' "$LOCAL_DIR/compare_methods_bouchet_fixed.R"

# Wrap the PS Full method in a conditional
sed -i '' '/# 4. Survey-Weighted PS Full Matching/,/error = function(e) {$/{
s/tryCatch({/if (has_marginaleffects) { tryCatch({/
}' "$LOCAL_DIR/compare_methods_bouchet_fixed.R"

# Create archive
tar -czf bouchet_corcor_fixed.tar.gz \
    "$LOCAL_DIR/compare_methods_bouchet_fixed.R" \
    "wdsm_method2_multinomial_bootstrap_WALD.R" \
    "wdsm_ci_functions.R" \
    "SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" \
    "dsmatch-master"

# Upload
echo "Uploading files..."
scp bouchet_corcor_fixed.tar.gz $BOUCHET_LOGIN:"$REMOTE_DIR/"
ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && tar -xzf bouchet_corcor_fixed.tar.gz && rm bouchet_corcor_fixed.tar.gz"

# Create SLURM script
cat > bouchet_corcor_fixed.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=CorCor_fixed
#SBATCH --output=CorCor_fixed_%j.out
#SBATCH --error=CorCor_fixed_%j.err
#SBATCH --account=pi_gt353
#SBATCH --partition=day
#SBATCH --cpus-per-task=24
#SBATCH --mem=192G
#SBATCH --time=02:00:00

echo "=========================================="
echo "CorCor FIXED on BOUCHET"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Starting at: $(date)"
echo ""

cd "REPLACE_REMOTE_DIR/PATE Retrospective Pooroverlap M135 CorCor GLM"

# Load R module
module load R/4.4.2-gfbf-2024a

# Copy files locally
cp ../wdsm_method2_multinomial_bootstrap_WALD.R .
cp ../wdsm_ci_functions.R .
cp ../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData .
cp -r ../dsmatch-master .

echo "Running simulation..."
R --vanilla << 'RSCRIPT'
# Try to install marginaleffects if not available
if (!requireNamespace("marginaleffects", quietly = TRUE)) {
    cat("Attempting to install marginaleffects...\n")
    tryCatch({
        install.packages("marginaleffects", repos = "https://cloud.r-project.org", quiet = TRUE)
        if (requireNamespace("marginaleffects", quietly = TRUE)) {
            cat("  ✓ marginaleffects installed successfully\n")
        }
    }, error = function(e) {
        cat("  ✗ Could not install marginaleffects. PS Full method will be skipped.\n")
    })
}

# Report environment
cat("\nR Version:", R.version.string, "\n")
cat("Cores:", parallel::detectCores(), "\n")
cat("Starting at:", format(Sys.time()), "\n\n")

# Source and run
source("compare_methods_bouchet_fixed.R")

cat("\nCompleted at:", format(Sys.time()), "\n")
RSCRIPT

echo ""
echo "Checking for results..."
if [ -f "raw_results_100reps_CorCor_WALD_CI.RData" ]; then
    echo "✅ Results file created!"
    ls -lh raw_results_100reps_CorCor_WALD_CI.RData
else
    echo "⚠️ Results file not found"
fi

echo "=========================================="
echo "Completed at: $(date)"
echo "=========================================="
EOF

# Replace directory placeholder
sed -i '' "s|REPLACE_REMOTE_DIR|$REMOTE_DIR|g" bouchet_corcor_fixed.sh

# Upload and submit
scp bouchet_corcor_fixed.sh $BOUCHET_LOGIN:"$REMOTE_DIR/"
JOB_ID=$(ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && sbatch bouchet_corcor_fixed.sh" | awk '{print $4}')
echo "✅ Submitted Job ID: $JOB_ID for CorCor (FIXED)"

# Clean up
rm -f bouchet_corcor_fixed.sh bouchet_corcor_fixed.tar.gz
rm -f "$LOCAL_DIR/compare_methods_bouchet_fixed.R"

echo ""
echo "==========================================
CorCor FIXED Job Submitted!
==========================================

Job ID: $JOB_ID
Directory: $REMOTE_DIR

Monitor:
ssh $BOUCHET_LOGIN 'squeue -u \$USER --job $JOB_ID'

Watch output:
ssh $BOUCHET_LOGIN 'tail -f $REMOTE_DIR/CorCor_fixed_${JOB_ID}.out'

Check completion:
ssh $BOUCHET_LOGIN 'sacct -j $JOB_ID --format=JobID,State,Elapsed,ExitCode'

Download results:
scp \"$BOUCHET_LOGIN:$REMOTE_DIR/PATE Retrospective Pooroverlap M135 CorCor GLM/raw_results_100reps_CorCor_WALD_CI.RData\" corcor_fixed_results.RData
"
