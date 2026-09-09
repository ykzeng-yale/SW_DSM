#!/bin/bash

# Submit 100-rep jobs to Bouchet Cluster
# Date: 2025-08-27

echo "==========================================
Submitting 100-REP Jobs to BOUCHET Cluster
==========================================
"

# Define scenarios and parameters
SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
# Updated path based on user request
REMOTE_DIR="/nfs/roberts/project/pi_gt353/yz2324/pooroverlap_100rep_bouchet_${TIMESTAMP}"
BOUCHET_LOGIN="yz2324@bouchet.ycrc.yale.edu"  # Bouchet login

echo "Configuration:"
echo "  Cluster: Bouchet"
echo "  Remote directory: $REMOTE_DIR"
echo "  Account: pi_gt353"
echo "  Partition: day"
echo "  Cores: 24 per job"
echo "  Memory: 192GB per job (8GB per CPU)"
echo ""

# Create remote directory
echo "Creating remote directory..."
ssh $BOUCHET_LOGIN "mkdir -p $REMOTE_DIR"

# First, update comparison scripts for 24 cores
echo "Preparing optimized scripts for Bouchet (24 cores)..."
for scenario in "${SCENARIOS[@]}"; do
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    
    # Create Bouchet-optimized version
    cp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R" \
       "$LOCAL_DIR/compare_methods_bouchet_100reps.R"
    
    # Update n_cores to 24
    sed -i '' 's/n_cores <- [0-9]*/n_cores <- 24/' "$LOCAL_DIR/compare_methods_bouchet_100reps.R"
done

# Create comprehensive archive
echo "Creating archive..."
tar -czf bouchet_100rep_simulation.tar.gz \
    "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_bouchet_100reps.R" \
    "PATE Retrospective Pooroverlap M135 MisCor GLM/compare_methods_bouchet_100reps.R" \
    "PATE Retrospective Pooroverlap M135 CorMis GLM/compare_methods_bouchet_100reps.R" \
    "PATE Retrospective Pooroverlap M135 MisMis GLM/compare_methods_bouchet_100reps.R" \
    "wdsm_method2_multinomial_bootstrap_WALD.R" \
    "wdsm_ci_functions.R" \
    "SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" \
    "dsmatch-master"

# Upload to Bouchet
echo "Uploading to Bouchet cluster..."
scp bouchet_100rep_simulation.tar.gz $BOUCHET_LOGIN:"$REMOTE_DIR/"
ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && tar -xzf bouchet_100rep_simulation.tar.gz && rm bouchet_100rep_simulation.tar.gz"

# Create and submit SLURM scripts for each scenario
for scenario in "${SCENARIOS[@]}"; do
    echo ""
    echo "Processing $scenario..."
    
    REMOTE_SCENARIO_DIR="$REMOTE_DIR/PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    
    cat > bouchet_${scenario}_100rep.sh << EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_100b
#SBATCH --output=${scenario}_100rep_bouchet_%j.out
#SBATCH --error=${scenario}_100rep_bouchet_%j.err
#SBATCH --account=pi_gt353
#SBATCH --partition=day
#SBATCH --cpus-per-task=24
#SBATCH --mem=192G
#SBATCH --time=23:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=yukang.zhang@yale.edu

echo "=========================================="
echo "100-REP ${scenario} on BOUCHET Cluster"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "Account: \$SLURM_JOB_ACCOUNT"
echo "Starting at: \$(date)"
echo ""
echo "Configuration:"
echo "- Cluster: Bouchet"
echo "- Cores: 24"
echo "- Memory: 192GB"
echo "- Sample size: n=5000"
echo "- Scenario: ${scenario}"
echo "- Replicates: 100"
echo "- Bootstrap: 200"
echo "- M: 5"
echo "- CI Method: Normal Wald"
echo "=========================================="
echo ""

cd "${REMOTE_SCENARIO_DIR}"

# Load R module for Bouchet
module load R/4.4.2-gfbf-2024a

# Copy shared files locally for better I/O
echo "Setting up local copies..."
cp ../../wdsm_method2_multinomial_bootstrap_WALD.R .
cp ../../wdsm_ci_functions.R .
cp ../../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData .
cp -r ../../dsmatch-master .

# Verify files
echo "Verifying required files:"
ls -la compare_methods_bouchet_100reps.R
ls -la wdsm_method2_multinomial_bootstrap_WALD.R
ls -la wdsm_ci_functions.R
ls -la SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData
echo ""

# Run R simulation with error handling
R --vanilla << 'RSCRIPT'
# Enhanced error reporting
options(error = function() {
  cat("\n=== ERROR OCCURRED ===\n")
  print(sys.calls())
  traceback()
  cat("===================\n\n")
})

# Report R environment
cat("R Version:", R.version.string, "\n")
cat("Detected cores:", parallel::detectCores(), "\n")
cat("SLURM CPUs:", Sys.getenv("SLURM_CPUS_PER_TASK"), "\n\n")

# Set seed for reproducibility
set.seed(20250827${scenario:0:1})

# Source and run
cat("Starting simulation at:", format(Sys.time()), "\n")
source("compare_methods_bouchet_100reps.R")
cat("Simulation completed at:", format(Sys.time()), "\n")
RSCRIPT

EXIT_CODE=\$?

# Report results
echo ""
echo "Job completed with exit code: \$EXIT_CODE"
echo "Completed at: \$(date)"

# Check for results file
if [ -f "raw_results_100reps_${scenario}_WALD_CI.RData" ]; then
    echo "✅ Results file created successfully"
    ls -lh raw_results_100reps_${scenario}_WALD_CI.RData
else
    echo "⚠️ Warning: Results file not found"
fi

echo "=========================================="
EOF
    
    # Upload and submit
    scp bouchet_${scenario}_100rep.sh $BOUCHET_LOGIN:"$REMOTE_DIR/"
    JOB_ID=$(ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && sbatch bouchet_${scenario}_100rep.sh" | awk '{print $4}')
    echo "✅ Submitted Job ID: $JOB_ID for $scenario"
    
    # Clean up
    rm -f bouchet_${scenario}_100rep.sh
    rm -f "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_bouchet_100reps.R"
done

# Clean up archive
rm -f bouchet_100rep_simulation.tar.gz

echo ""
echo "==========================================
ALL 100-REP JOBS SUBMITTED TO BOUCHET!
==========================================

Submission Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cluster: Bouchet
Account: pi_gt353
Directory: $REMOTE_DIR
Resources: 24 cores, 192GB memory per job
Partition: day (23 hour limit)
Scenarios: ${SCENARIOS[@]}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Expected Performance:
• Runtime: ~30-45 minutes per scenario (with 24 cores)
• Queue wait: Variable based on fairshare
• Total time: ~1 hour if all run in parallel

Monitoring Commands:
──────────────────────
Check job status:
ssh $BOUCHET_LOGIN 'squeue -u \$USER | grep 100b'

Monitor progress:
ssh $BOUCHET_LOGIN 'for s in CorCor MisCor CorMis MisMis; do echo \"\$s:\"; tail -3 $REMOTE_DIR/*\${s}*100rep*.out 2>/dev/null | grep -E \"replicate|Completed|exit code\"; echo; done'

Check for errors:
ssh $BOUCHET_LOGIN 'grep -l \"Error\" $REMOTE_DIR/*100rep*.err 2>/dev/null'

View job efficiency:
ssh $BOUCHET_LOGIN 'seff JOB_ID'

Download Results:
──────────────────
# When complete, download results:
mkdir -p bouchet_results_${TIMESTAMP}
for scenario in CorCor MisCor CorMis MisMis; do
    echo \"Downloading \$scenario...\"
    scp \"$BOUCHET_LOGIN:$REMOTE_DIR/PATE Retrospective Pooroverlap M135 \${scenario} GLM/raw_results_100reps_\${scenario}_WALD_CI.RData\" \\
        \"bouchet_results_${TIMESTAMP}/\${scenario}_results.RData\"
done

# Or download all at once:
ssh $BOUCHET_LOGIN \"cd $REMOTE_DIR && tar -czf results.tar.gz */raw_results*.RData\"
scp $BOUCHET_LOGIN:$REMOTE_DIR/results.tar.gz bouchet_results_${TIMESTAMP}.tar.gz
tar -xzf bouchet_results_${TIMESTAMP}.tar.gz

Analysis:
──────────────────
# After download:
R -e 'source(\"analyze_all_scenarios_corrected.R\")'
"
