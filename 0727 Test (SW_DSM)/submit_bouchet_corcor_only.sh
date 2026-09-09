#!/bin/bash

# Submit only CorCor to Bouchet for testing
# Date: 2025-08-27

echo "==========================================
Submitting CorCor ONLY to BOUCHET for Testing
==========================================
"

REMOTE_DIR="/nfs/roberts/project/pi_gt353/yz2324/pooroverlap_corcor_test_$(date +%Y%m%d_%H%M%S)"
BOUCHET_LOGIN="yz2324@bouchet.ycrc.yale.edu"

echo "Configuration:"
echo "  Remote directory: $REMOTE_DIR"
echo "  Scenario: CorCor only"
echo "  Cores: 24"
echo "  Memory: 192GB"
echo ""

# Create remote directory
echo "Creating remote directory..."
ssh $BOUCHET_LOGIN "mkdir -p $REMOTE_DIR"

# Prepare the CorCor script with 24 cores
echo "Preparing CorCor script..."
LOCAL_DIR="PATE Retrospective Pooroverlap M135 CorCor GLM"
cp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R" \
   "$LOCAL_DIR/compare_methods_bouchet_corcor.R"
sed -i '' 's/n_cores <- [0-9]*/n_cores <- 24/' "$LOCAL_DIR/compare_methods_bouchet_corcor.R"

# Create targeted archive
echo "Creating archive..."
tar -czf bouchet_corcor_test.tar.gz \
    "$LOCAL_DIR/compare_methods_bouchet_corcor.R" \
    "wdsm_method2_multinomial_bootstrap_WALD.R" \
    "wdsm_ci_functions.R" \
    "SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" \
    "dsmatch-master"

# Upload
echo "Uploading files..."
scp bouchet_corcor_test.tar.gz $BOUCHET_LOGIN:"$REMOTE_DIR/"
ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && tar -xzf bouchet_corcor_test.tar.gz && rm bouchet_corcor_test.tar.gz"

# Create detailed SLURM script for CorCor
cat > bouchet_corcor_test.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=CorCor_test
#SBATCH --output=CorCor_test_%j.out
#SBATCH --error=CorCor_test_%j.err
#SBATCH --account=pi_gt353
#SBATCH --partition=day
#SBATCH --cpus-per-task=24
#SBATCH --mem=192G
#SBATCH --time=02:00:00

echo "=========================================="
echo "CorCor TEST on BOUCHET Cluster"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Starting at: $(date)"
echo ""

# Set working directory
WORK_DIR="REPLACE_REMOTE_DIR/PATE Retrospective Pooroverlap M135 CorCor GLM"
cd "$WORK_DIR"

echo "Working directory: $WORK_DIR"
echo "Contents:"
ls -la
echo ""

# Load R module
module load R/4.4.2-gfbf-2024a

# Copy files to local directory
echo "Setting up files..."
cp ../wdsm_method2_multinomial_bootstrap_WALD.R .
cp ../wdsm_ci_functions.R .
cp ../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData .
cp -r ../dsmatch-master .

# Verify all files are present
echo "Verifying required files:"
for file in compare_methods_bouchet_corcor.R \
            wdsm_method2_multinomial_bootstrap_WALD.R \
            wdsm_ci_functions.R \
            SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData \
            dsmatch-master/R/dsmatchATE.R; do
    if [ -f "$file" ]; then
        echo "  ✓ $file ($(ls -lh $file | awk '{print $5}'))"
    else
        echo "  ✗ $file MISSING!"
        exit 1
    fi
done
echo ""

# Create a test R script to verify everything works
echo "Running initial verification..."
R --vanilla << 'RTEST'
# Test that all packages can be loaded
cat("Testing package loading...\n")
required_packages <- c("tidyverse", "doParallel", "foreach", "MASS", "glmnet", 
                       "MatchIt", "marginaleffects", "survey", "matrixStats")

for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
        cat("  ✗", pkg, "FAILED TO LOAD\n")
        stop(paste("Package", pkg, "not available"))
    } else {
        cat("  ✓", pkg, "loaded\n")
    }
}

# Test that WDSM functions can be sourced
cat("\nTesting WDSM functions...\n")
source("wdsm_method2_multinomial_bootstrap_WALD.R")
cat("  ✓ wdsm_method2_multinomial_bootstrap_WALD.R sourced\n")
source("wdsm_ci_functions.R")
cat("  ✓ wdsm_ci_functions.R sourced\n")

# Test that dsmatch functions can be sourced
cat("\nTesting dsmatch functions...\n")
dsmatch_files <- c(
    "dsmatch-master/R/bisect.R",
    "dsmatch-master/R/is.lp.R",
    "dsmatch-master/R/is.ps.R",
    "dsmatch-master/R/is.pg.R",
    "dsmatch-master/R/estforboot_dsATE.R",
    "dsmatch-master/R/estforboot_psATE.R",
    "dsmatch-master/R/estforboot_pgATE.R",
    "dsmatch-master/R/estforboot_covATE.R",
    "dsmatch-master/R/dsmatchATE.R"
)
for (file in dsmatch_files) {
    source(file)
    cat("  ✓", file, "sourced\n")
}

# Test data loading
cat("\nTesting data loading...\n")
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
cat("  ✓ Population data loaded\n")
cat("  Population size:", nrow(SuperPopGen_PoorOverlap_AllinOne_0118_2025[[1]]), "\n")

cat("\n✅ All preliminary tests passed!\n\n")
RTEST

# If tests pass, run the actual simulation
if [ $? -eq 0 ]; then
    echo "Starting main simulation..."
    R --vanilla << 'RMAIN'
# Set options for debugging
options(error = function() {
    cat("\n=== ERROR OCCURRED ===\n")
    traceback()
    cat("=====================\n")
})

# Report environment
cat("R Version:", R.version.string, "\n")
cat("Cores detected:", parallel::detectCores(), "\n")
cat("SLURM CPUs:", Sys.getenv("SLURM_CPUS_PER_TASK"), "\n")
cat("Starting at:", format(Sys.time()), "\n\n")

# Source and run
tryCatch({
    source("compare_methods_bouchet_corcor.R")
    cat("\n✅ Simulation completed successfully!\n")
}, error = function(e) {
    cat("\n❌ Simulation failed with error:\n")
    print(e)
    quit(status = 1)
})

cat("Completed at:", format(Sys.time()), "\n")
RMAIN
else
    echo "❌ Preliminary tests failed!"
    exit 1
fi

# Check for results
echo ""
echo "Checking for results..."
if [ -f "raw_results_100reps_CorCor_WALD_CI.RData" ]; then
    echo "✅ Results file created successfully!"
    ls -lh raw_results_100reps_CorCor_WALD_CI.RData
else
    echo "⚠️ Warning: Results file not found"
    echo "Contents of directory:"
    ls -la *.RData
fi

echo ""
echo "=========================================="
echo "Job completed at: $(date)"
echo "=========================================="
EOF

# Replace the remote directory placeholder
sed -i '' "s|REPLACE_REMOTE_DIR|$REMOTE_DIR|g" bouchet_corcor_test.sh

# Upload and submit
echo ""
echo "Submitting CorCor test job..."
scp bouchet_corcor_test.sh $BOUCHET_LOGIN:"$REMOTE_DIR/"
JOB_ID=$(ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && sbatch bouchet_corcor_test.sh" | awk '{print $4}')
echo "✅ Submitted Job ID: $JOB_ID for CorCor TEST"

# Clean up
rm -f bouchet_corcor_test.sh
rm -f bouchet_corcor_test.tar.gz
rm -f "$LOCAL_DIR/compare_methods_bouchet_corcor.R"

echo ""
echo "==========================================
CorCor TEST Job Submitted to Bouchet!
==========================================

Remote directory: $REMOTE_DIR

Monitor status:
ssh $BOUCHET_LOGIN 'squeue -u \$USER --job $JOB_ID'

Watch progress (live):
ssh $BOUCHET_LOGIN 'tail -f $REMOTE_DIR/CorCor_test_${JOB_ID}.out'

Check errors:
ssh $BOUCHET_LOGIN 'cat $REMOTE_DIR/CorCor_test_${JOB_ID}.err'

Check completion:
ssh $BOUCHET_LOGIN 'sacct -j $JOB_ID --format=JobID,JobName,State,Elapsed,ExitCode'

Download results (when complete):
scp \"$BOUCHET_LOGIN:$REMOTE_DIR/PATE Retrospective Pooroverlap M135 CorCor GLM/raw_results_100reps_CorCor_WALD_CI.RData\" \\
    corcor_test_results.RData

IMPORTANT:
=========
If this CorCor test succeeds, we can then submit the other scenarios (MisCor, CorMis, MisMis).
The test includes comprehensive verification steps to identify any issues before the main run.
"
