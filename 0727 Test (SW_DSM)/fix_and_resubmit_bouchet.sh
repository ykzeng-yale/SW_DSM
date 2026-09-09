#!/bin/bash

# Fix and resubmit Bouchet jobs with correct paths
# Date: 2025-08-27

echo "==========================================
Fixing and Resubmitting BOUCHET Jobs
==========================================
"

REMOTE_DIR="/nfs/roberts/project/pi_gt353/yz2324/pooroverlap_100rep_bouchet_20250827_031633"
BOUCHET_LOGIN="yz2324@bouchet.ycrc.yale.edu"
SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")

echo "Remote directory: $REMOTE_DIR"
echo ""

# Fix and resubmit each scenario
for scenario in "${SCENARIOS[@]}"; do
    echo "Fixing $scenario..."
    
    REMOTE_SCENARIO_DIR="$REMOTE_DIR/PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    
    # Create corrected SLURM script
    cat > bouchet_${scenario}_fixed.sh << EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_fix
#SBATCH --output=${scenario}_100rep_fixed_%j.out
#SBATCH --error=${scenario}_100rep_fixed_%j.err
#SBATCH --account=pi_gt353
#SBATCH --partition=day
#SBATCH --cpus-per-task=24
#SBATCH --mem=192G
#SBATCH --time=23:00:00

echo "=========================================="
echo "100-REP ${scenario} on BOUCHET (FIXED)"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "Starting at: \$(date)"
echo ""

cd "${REMOTE_SCENARIO_DIR}"

# Load R module
module load R/4.4.2-gfbf-2024a

# Copy files from parent directory (not ../../)
echo "Copying required files from parent directory..."
cp ../wdsm_method2_multinomial_bootstrap_WALD.R .
cp ../wdsm_ci_functions.R .
cp ../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData .
cp -r ../dsmatch-master .

# Verify files
echo "Verifying files:"
ls -la compare_methods_bouchet_100reps.R
ls -la wdsm_method2_multinomial_bootstrap_WALD.R
ls -la wdsm_ci_functions.R
ls -la SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData
ls -la dsmatch-master/R/dsmatchATE.R
echo ""

# Run R simulation
R --vanilla << 'RSCRIPT'
# Report environment
cat("R Version:", R.version.string, "\n")
cat("Cores available:", parallel::detectCores(), "\n")
cat("SLURM CPUs:", Sys.getenv("SLURM_CPUS_PER_TASK"), "\n\n")

# Set proper seed (without using C character in scenario name)
set.seed(20250827)

# Source and run
cat("Starting simulation at:", format(Sys.time()), "\n")
source("compare_methods_bouchet_100reps.R")
cat("Simulation completed at:", format(Sys.time()), "\n")
RSCRIPT

EXIT_CODE=\$?

echo ""
echo "Job completed with exit code: \$EXIT_CODE"
echo "Completed at: \$(date)"

# Check for results
if [ -f "raw_results_100reps_${scenario}_WALD_CI.RData" ]; then
    echo "✅ Results file created"
    ls -lh raw_results_100reps_${scenario}_WALD_CI.RData
else
    echo "⚠️ Results file not found"
fi

echo "=========================================="
EOF
    
    # Upload and submit
    scp bouchet_${scenario}_fixed.sh $BOUCHET_LOGIN:"$REMOTE_DIR/"
    JOB_ID=$(ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && sbatch bouchet_${scenario}_fixed.sh" | awk '{print $4}')
    echo "✅ Submitted Job ID: $JOB_ID for $scenario (FIXED)"
    
    # Clean up
    rm -f bouchet_${scenario}_fixed.sh
    echo ""
done

echo "==========================================
All FIXED jobs submitted to Bouchet!
==========================================

Monitor with:
ssh $BOUCHET_LOGIN 'squeue -u \$USER | grep fix'

Check progress:
ssh $BOUCHET_LOGIN 'for s in CorCor MisCor CorMis MisMis; do echo \"\$s:\"; tail -3 $REMOTE_DIR/\${s}_100rep_fixed*.out 2>/dev/null | grep -E \"replicate|Completed|exit code\"; echo; done'

Check for errors:
ssh $BOUCHET_LOGIN 'grep \"Error\" $REMOTE_DIR/*fixed*.err 2>/dev/null | head -10'
"
