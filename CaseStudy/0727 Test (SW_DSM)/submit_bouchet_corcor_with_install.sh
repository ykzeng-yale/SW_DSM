#!/bin/bash

# Submit CorCor to Bouchet with package installation
# Date: 2025-08-27

echo "==========================================
Submitting CorCor to BOUCHET (With Package Install)
==========================================
"

REMOTE_DIR="/nfs/roberts/project/pi_gt353/yz2324/pooroverlap_corcor_install_$(date +%Y%m%d_%H%M%S)"
BOUCHET_LOGIN="yz2324@bouchet.ycrc.yale.edu"

echo "Remote directory: $REMOTE_DIR"
echo ""

# Create remote directory
ssh $BOUCHET_LOGIN "mkdir -p $REMOTE_DIR"

# Use original script with n_cores updated
echo "Preparing CorCor script..."
LOCAL_DIR="PATE Retrospective Pooroverlap M135 CorCor GLM"
cp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R" \
   "$LOCAL_DIR/compare_methods_bouchet_install.R"
sed -i '' 's/n_cores <- [0-9]*/n_cores <- 24/' "$LOCAL_DIR/compare_methods_bouchet_install.R"

# Create archive
tar -czf bouchet_corcor_install.tar.gz \
    "$LOCAL_DIR/compare_methods_bouchet_install.R" \
    "wdsm_method2_multinomial_bootstrap_WALD.R" \
    "wdsm_ci_functions.R" \
    "SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" \
    "dsmatch-master"

# Upload
echo "Uploading files..."
scp bouchet_corcor_install.tar.gz $BOUCHET_LOGIN:"$REMOTE_DIR/"
ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && tar -xzf bouchet_corcor_install.tar.gz && rm bouchet_corcor_install.tar.gz"

# Create SLURM script with package installation
cat > bouchet_corcor_install.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=CorCor_inst
#SBATCH --output=CorCor_install_%j.out
#SBATCH --error=CorCor_install_%j.err
#SBATCH --account=pi_gt353
#SBATCH --partition=day
#SBATCH --cpus-per-task=24
#SBATCH --mem=192G
#SBATCH --time=02:00:00

echo "=========================================="
echo "CorCor with Package Install on BOUCHET"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Starting at: $(date)"
echo ""

cd "REPLACE_REMOTE_DIR/PATE Retrospective Pooroverlap M135 CorCor GLM"

# Load R module
module load R/4.4.2-gfbf-2024a

# Copy files locally
echo "Copying files..."
cp ../wdsm_method2_multinomial_bootstrap_WALD.R .
cp ../wdsm_ci_functions.R .
cp ../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData .
cp -r ../dsmatch-master .

echo ""
echo "Installing required packages and running simulation..."
R --vanilla << 'RSCRIPT'
# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Install marginaleffects if not available
cat("Checking for marginaleffects package...\n")
if (!requireNamespace("marginaleffects", quietly = TRUE)) {
    cat("Installing marginaleffects package...\n")
    install.packages("marginaleffects", quiet = TRUE, verbose = FALSE)
    if (requireNamespace("marginaleffects", quietly = TRUE)) {
        cat("✓ marginaleffects installed successfully\n")
    } else {
        cat("✗ Failed to install marginaleffects\n")
        stop("Could not install required package")
    }
} else {
    cat("✓ marginaleffects already available\n")
}

# Install/check other potentially missing packages
cat("\nChecking other required packages...\n")
required_pkgs <- c("tidyverse", "doParallel", "foreach", "MASS", "glmnet", 
                    "MatchIt", "marginaleffects", "survey", "matrixStats")

for (pkg in required_pkgs) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
        cat("Installing", pkg, "...\n")
        install.packages(pkg, quiet = TRUE, verbose = FALSE)
    }
    if (requireNamespace(pkg, quietly = TRUE)) {
        cat("  ✓", pkg, "available\n")
    } else {
        cat("  ✗", pkg, "FAILED\n")
        stop(paste("Could not install", pkg))
    }
}

# Report environment
cat("\n========================================\n")
cat("Environment ready!\n")
cat("R Version:", R.version.string, "\n")
cat("Cores available:", parallel::detectCores(), "\n")
cat("SLURM CPUs:", Sys.getenv("SLURM_CPUS_PER_TASK"), "\n")
cat("========================================\n\n")

# Set seed for reproducibility
set.seed(20250827)

# Source and run
cat("Starting simulation at:", format(Sys.time()), "\n")
tryCatch({
    source("compare_methods_bouchet_install.R")
    cat("\n✅ Simulation completed successfully!\n")
}, error = function(e) {
    cat("\n❌ Simulation failed:\n")
    print(e)
    traceback()
    quit(status = 1)
})

cat("Completed at:", format(Sys.time()), "\n")
RSCRIPT

# Check for results
echo ""
echo "Checking for results..."
if [ -f "raw_results_100reps_CorCor_WALD_CI.RData" ]; then
    echo "✅ Results file created successfully!"
    ls -lh raw_results_100reps_CorCor_WALD_CI.RData
else
    echo "⚠️ Results file not found"
fi

echo ""
echo "=========================================="
echo "Job completed at: $(date)"
echo "=========================================="
EOF

# Replace directory placeholder
sed -i '' "s|REPLACE_REMOTE_DIR|$REMOTE_DIR|g" bouchet_corcor_install.sh

# Upload and submit
scp bouchet_corcor_install.sh $BOUCHET_LOGIN:"$REMOTE_DIR/"
JOB_ID=$(ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && sbatch bouchet_corcor_install.sh" | awk '{print $4}')
echo "✅ Submitted Job ID: $JOB_ID for CorCor (with package install)"

# Clean up
rm -f bouchet_corcor_install.sh bouchet_corcor_install.tar.gz
rm -f "$LOCAL_DIR/compare_methods_bouchet_install.R"

echo ""
echo "==========================================
CorCor Job Submitted with Package Install!
==========================================

Job ID: $JOB_ID
Directory: $REMOTE_DIR

This job will:
1. Install marginaleffects package if needed
2. Verify all required packages
3. Run the full 100-replication simulation

Monitor status:
ssh $BOUCHET_LOGIN 'squeue -u \$USER --job $JOB_ID'

Watch progress:
ssh $BOUCHET_LOGIN 'tail -f $REMOTE_DIR/CorCor_install_${JOB_ID}.out'

Check errors:
ssh $BOUCHET_LOGIN 'cat $REMOTE_DIR/CorCor_install_${JOB_ID}.err | head -50'

Check completion:
ssh $BOUCHET_LOGIN 'sacct -j $JOB_ID --format=JobID,JobName,State,Elapsed,ExitCode'

Download results (when complete):
scp \"$BOUCHET_LOGIN:$REMOTE_DIR/PATE Retrospective Pooroverlap M135 CorCor GLM/raw_results_100reps_CorCor_WALD_CI.RData\" \\
    bouchet_corcor_results.RData

NEXT STEPS:
==========
Once this CorCor job completes successfully, we can submit the remaining scenarios:
- MisCor
- CorMis  
- MisMis
"
