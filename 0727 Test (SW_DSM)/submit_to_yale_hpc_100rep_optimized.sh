#!/bin/bash

# Flexible submission script for Yale HPC clusters (McCleary, Grace, etc.)
# Optimized for 100 replications with more cores

echo "==========================================
Yale HPC Cluster Submission - Optimized Configuration
==========================================
"

# User configuration - MODIFY THESE AS NEEDED
CLUSTER_LOGIN="yz2324@login.mccleary.ycrc.yale.edu"  # Change to appropriate cluster
ACCOUNT="tong"  # or "li_fan" based on fairshare
PROJECT_DIR="/gpfs/gibbs/project/${ACCOUNT}/yz2324"  # Adjust based on cluster
N_CORES=20  # Increased from 12 for better performance
MEM_PER_CPU="8G"  # Increased from 5G for stability
PARTITION="day"  # or "week" for longer runs
TIME_LIMIT="23:00:00"  # 23 hours for day partition

# Display configuration
echo "Configuration:"
echo "  Cluster login: $CLUSTER_LOGIN"
echo "  Account: $ACCOUNT"
echo "  Project directory: $PROJECT_DIR"
echo "  Cores: $N_CORES"
echo "  Memory per CPU: $MEM_PER_CPU"
echo "  Partition: $PARTITION"
echo "  Time limit: $TIME_LIMIT"
echo ""

# Define scenarios
SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_DIR="${PROJECT_DIR}/pooroverlap_100rep_optimized_${TIMESTAMP}"

echo "Remote directory: $REMOTE_DIR"
echo ""

# Create remote directory
echo "Creating remote directory..."
ssh $CLUSTER_LOGIN "mkdir -p $REMOTE_DIR"

# Update comparison scripts for optimal core count
echo "Updating scripts for $N_CORES cores..."
for scenario in "${SCENARIOS[@]}"; do
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    
    # Create optimized version
    cp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R" \
       "$LOCAL_DIR/compare_methods_optimized_100reps.R"
    
    # Update n_cores
    sed -i '' "s/n_cores <- [0-9]*/n_cores <- $N_CORES/" \
        "$LOCAL_DIR/compare_methods_optimized_100reps.R"
done

# Create comprehensive archive
echo "Creating archive with all necessary files..."
tar -czf yale_hpc_simulation.tar.gz \
    "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_optimized_100reps.R" \
    "PATE Retrospective Pooroverlap M135 MisCor GLM/compare_methods_optimized_100reps.R" \
    "PATE Retrospective Pooroverlap M135 CorMis GLM/compare_methods_optimized_100reps.R" \
    "PATE Retrospective Pooroverlap M135 MisMis GLM/compare_methods_optimized_100reps.R" \
    "wdsm_method2_multinomial_bootstrap_WALD.R" \
    "wdsm_ci_functions.R" \
    "SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" \
    "dsmatch-master"

# Upload archive
echo "Uploading simulation files..."
scp yale_hpc_simulation.tar.gz $CLUSTER_LOGIN:"$REMOTE_DIR/"

# Extract on remote
echo "Extracting files on cluster..."
ssh $CLUSTER_LOGIN "cd $REMOTE_DIR && tar -xzf yale_hpc_simulation.tar.gz && rm yale_hpc_simulation.tar.gz"

# Submit jobs for each scenario
echo ""
echo "Submitting jobs..."
for scenario in "${SCENARIOS[@]}"; do
    echo "Processing $scenario..."
    
    REMOTE_SCENARIO_DIR="$REMOTE_DIR/PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    
    # Create SLURM script
    cat > slurm_${scenario}_100rep_opt.sh << EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_opt
#SBATCH --output=${scenario}_100rep_opt_%j.out
#SBATCH --error=${scenario}_100rep_opt_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$N_CORES
#SBATCH --mem-per-cpu=$MEM_PER_CPU
#SBATCH --time=$TIME_LIMIT
#SBATCH --partition=$PARTITION
#SBATCH --account=$ACCOUNT

echo "=========================================="
echo "OPTIMIZED 100-REP ${scenario}"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "CPUs: \$SLURM_CPUS_PER_TASK"
echo "Memory: \$SLURM_MEM_PER_CPU per CPU"
echo "Starting at: \$(date)"
echo ""
echo "Simulation Configuration:"
echo "- Sample size: n=5000"
echo "- Scenario: ${scenario}"
echo "- Replicates: 100"
echo "- Bootstrap: 200"
echo "- Matching M: 5"
echo "- CI Method: Normal Wald"
echo "- Cores: $N_CORES"
echo ""

# Change to scenario directory
cd "${REMOTE_SCENARIO_DIR}"

# Copy shared files locally for better I/O performance
echo "Setting up local copies for better I/O..."
cp ../../wdsm_method2_multinomial_bootstrap_WALD.R .
cp ../../wdsm_ci_functions.R .
cp ../../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData .
cp -r ../../dsmatch-master .

# Load R module
module load R/4.3.2-foss-2022b

# Verify file presence
echo "Verifying files..."
ls -la compare_methods_optimized_100reps.R
ls -la wdsm_method2_multinomial_bootstrap_WALD.R
ls -la wdsm_ci_functions.R
echo ""

# Run simulation with detailed error handling
R --vanilla << 'RSCRIPT'
# Enhanced error reporting
options(error = function() {
  cat("\n=== ERROR OCCURRED ===\n")
  print(sys.calls())
  traceback()
  cat("===================\n\n")
})

# Set random seed for reproducibility
set.seed(20250826)

# Source and run
cat("Starting R simulation...\n")
source("compare_methods_optimized_100reps.R")
cat("R simulation completed.\n")
RSCRIPT

# Save exit code
EXIT_CODE=\$?

# Report completion
echo ""
echo "Job completed with exit code: \$EXIT_CODE"
echo "Completed at: \$(date)"

# Check if results were created
if [ -f "raw_results_100reps_${scenario}_WALD_CI.RData" ]; then
    echo "✅ Results file created successfully"
    ls -lh raw_results_100reps_${scenario}_WALD_CI.RData
else
    echo "⚠️ Warning: Results file not found"
fi

echo "=========================================="
EOF
    
    # Upload SLURM script
    scp slurm_${scenario}_100rep_opt.sh $CLUSTER_LOGIN:"$REMOTE_DIR/"
    
    # Submit job
    JOB_ID=$(ssh $CLUSTER_LOGIN "cd $REMOTE_DIR && sbatch slurm_${scenario}_100rep_opt.sh" | awk '{print $4}')
    echo "✅ Submitted Job ID: $JOB_ID for $scenario"
    
    # Clean up local files
    rm -f slurm_${scenario}_100rep_opt.sh
    rm -f "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_optimized_100reps.R"
    
    echo ""
done

# Clean up archive
rm -f yale_hpc_simulation.tar.gz

echo "==========================================
ALL JOBS SUBMITTED SUCCESSFULLY!
==========================================

Submission Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Remote Directory: $REMOTE_DIR
Cluster: $(echo $CLUSTER_LOGIN | cut -d@ -f2 | cut -d. -f2)
Account: $ACCOUNT
Resources: ${N_CORES} cores, $(echo $MEM_PER_CPU | sed 's/G/*'${N_CORES}' = /')$(($N_CORES * ${MEM_PER_CPU%G}))GB total memory
Time Limit: $TIME_LIMIT
Scenarios: ${SCENARIOS[@]}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Expected Performance:
• Runtime: ~40-60 minutes per scenario
• Total time: ~1-2 hours for all scenarios (parallel)
• Output: 4 RData files with 100 replications each

Monitoring Commands:
──────────────────────
Check job status:
ssh $CLUSTER_LOGIN 'squeue -u \$USER --account=$ACCOUNT'

Monitor progress:
ssh $CLUSTER_LOGIN 'for s in CorCor MisCor CorMis MisMis; do echo \"\$s:\"; tail -3 $REMOTE_DIR/*\${s}*opt*.out 2>/dev/null | grep -E \"replicate|Completed|exit code\"; echo; done'

Check for errors:
ssh $CLUSTER_LOGIN 'grep -l \"Error\" $REMOTE_DIR/*opt*.err 2>/dev/null'

View specific error:
ssh $CLUSTER_LOGIN 'tail -50 $REMOTE_DIR/[SCENARIO]_100rep_opt_*.err'

Download Results:
──────────────────
# When jobs complete, download results:
mkdir -p yale_hpc_results_${TIMESTAMP}
for scenario in CorCor MisCor CorMis MisMis; do
    echo \"Downloading \$scenario results...\"
    scp \"$CLUSTER_LOGIN:$REMOTE_DIR/PATE Retrospective Pooroverlap M135 \${scenario} GLM/raw_results_100reps_\${scenario}_WALD_CI.RData\" \\
        \"yale_hpc_results_${TIMESTAMP}/results_\${scenario}.RData\"
done

# Or download all at once:
ssh $CLUSTER_LOGIN \"cd $REMOTE_DIR && tar -czf all_results.tar.gz */raw_results*.RData\"
scp $CLUSTER_LOGIN:$REMOTE_DIR/all_results.tar.gz .
tar -xzf all_results.tar.gz

Analysis Script:
──────────────────
After download, run: R -e 'source(\"analyze_all_scenarios_corrected.R\")'
"
