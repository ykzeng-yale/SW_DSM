#!/bin/bash

# Submit 100-rep jobs to Bouchet Cluster with optimal configuration
# Date: 2025-08-26

echo "==========================================
Submitting 100-REP Jobs to BOUCHET Cluster
==========================================
"

# Define scenarios and parameters
SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_DIR="/gpfs/loomis/project/fan_li/yz2324/pooroverlap_100rep_bouchet_${TIMESTAMP}"
BOUCHET_LOGIN="yz2324@farnam.hpc.yale.edu"  # Bouchet uses Farnam login

echo "Remote directory: $REMOTE_DIR"
echo "Cluster: Bouchet (via Farnam)"
echo ""

# Create remote directory
ssh $BOUCHET_LOGIN "mkdir -p $REMOTE_DIR"

# Create optimized comparison script with 20 cores for Bouchet
echo "Creating optimized comparison script for Bouchet..."
for scenario in "${SCENARIOS[@]}"; do
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    
    # Update the comparison script for 20 cores
    cp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R" \
       "$LOCAL_DIR/compare_methods_pate_retrospective_bouchet_100reps.R"
    
    # Update n_cores to 20 for Bouchet
    sed -i '' 's/n_cores <- 12/n_cores <- 20/' "$LOCAL_DIR/compare_methods_pate_retrospective_bouchet_100reps.R"
    
done

# Package all files
echo "Creating archive for upload..."
tar -czf bouchet_simulation_files.tar.gz \
    "PATE Retrospective Pooroverlap M135 CorCor GLM" \
    "PATE Retrospective Pooroverlap M135 MisCor GLM" \
    "PATE Retrospective Pooroverlap M135 CorMis GLM" \
    "PATE Retrospective Pooroverlap M135 MisMis GLM" \
    "wdsm_method2_multinomial_bootstrap_WALD.R" \
    "wdsm_ci_functions.R" \
    "SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" \
    "dsmatch-master"

# Upload to Bouchet
echo "Uploading files to Bouchet cluster..."
scp bouchet_simulation_files.tar.gz $BOUCHET_LOGIN:"$REMOTE_DIR/"
ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && tar -xzf bouchet_simulation_files.tar.gz"

# Create SLURM scripts for each scenario
for scenario in "${SCENARIOS[@]}"; do
    echo "Creating SLURM script for $scenario..."
    
    REMOTE_SCENARIO_DIR="$REMOTE_DIR/PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    
    cat > bouchet_${scenario}_100rep.sh << EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_100b
#SBATCH --output=${scenario}_100rep_bouchet_%j.out
#SBATCH --error=${scenario}_100rep_bouchet_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=24:00:00
#SBATCH --partition=day

echo "=========================================="
echo "100-REP ${scenario} on BOUCHET Cluster"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURMD_NODENAME"
echo "Starting at: \$(date)"
echo "Working directory: ${REMOTE_SCENARIO_DIR}"
echo ""
echo "Configuration:"
echo "- Cluster: Bouchet"
echo "- Cores: 20"
echo "- Memory per CPU: 8GB (Total: 160GB)"
echo "- Sample size: n=5000"
echo "- Scenario: ${scenario}"
echo "- Replicates: 100"
echo "- Bootstrap: 200"
echo "- M: 5"
echo "- CI Method: Normal Wald"
echo ""

cd "${REMOTE_SCENARIO_DIR}"

# Load R module (Bouchet may have different module names)
module load R/4.4.1

# Verify files exist
echo "Verifying required files:"
ls -la compare_methods_pate_retrospective_bouchet_100reps.R
ls -la ../../wdsm_method2_multinomial_bootstrap_WALD.R
ls -la ../../wdsm_ci_functions.R
ls -la ../../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData
ls -la ../../dsmatch-master/R/dsmatchATE.R
echo ""

# Copy shared files to local directory for better I/O
cp ../../wdsm_method2_multinomial_bootstrap_WALD.R .
cp ../../wdsm_ci_functions.R .
cp ../../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData .
cp -r ../../dsmatch-master .

# Run R script
R --no-save << 'RSCRIPT'
# Set options for better error reporting
options(error = function() {
  calls <- sys.calls()
  if (length(calls) > 0) {
    cat("Call stack:\n")
    for (i in 1:length(calls)) {
      cat(i, ": ", deparse(calls[[i]])[1], "\n")
    }
  }
  traceback()
})

source("compare_methods_pate_retrospective_bouchet_100reps.R")
RSCRIPT

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Upload SLURM script
    scp bouchet_${scenario}_100rep.sh $BOUCHET_LOGIN:"$REMOTE_DIR/"
    
    # Submit job
    echo "Submitting $scenario job..."
    JOB_ID=$(ssh $BOUCHET_LOGIN "cd $REMOTE_DIR && sbatch bouchet_${scenario}_100rep.sh" | awk '{print $4}')
    echo "✅ Submitted Job ID: $JOB_ID for $scenario"
    echo ""
    
    # Clean up local files
    rm -f bouchet_${scenario}_100rep.sh
done

# Clean up
rm -f bouchet_simulation_files.tar.gz

echo "==========================================
All 100-REP jobs submitted to BOUCHET cluster!
==========================================

Remote directory: $REMOTE_DIR

Configuration Summary:
✅ Cluster: Bouchet 
✅ Cores: 20 per job
✅ Memory: 160GB per job (8GB per CPU)
✅ Time limit: 24 hours
✅ Partition: day
✅ Replications: 100
✅ All 5 methods enabled
✅ WDSM uses Normal Wald CI
✅ Correct retrospective sampling
✅ Correct sample size (n=5000)

Expected runtime: ~45-60 minutes per scenario (faster with 20 cores)

To check status:
ssh $BOUCHET_LOGIN 'squeue -u \$USER | grep 100b'

To monitor progress:
ssh $BOUCHET_LOGIN 'for s in CorCor MisCor CorMis MisMis; do echo \"\$s:\"; tail -5 $REMOTE_DIR/bouchet_\${s}_100rep_*.out 2>/dev/null | grep -E \"replicate|Completed\"; done'

To check errors:
ssh $BOUCHET_LOGIN 'for s in CorCor MisCor CorMis MisMis; do echo \"\$s errors:\"; tail -20 $REMOTE_DIR/bouchet_\${s}_100rep_*.err 2>/dev/null | grep -E \"Error|Warning\" | head -5; done'

To download results when complete:
for s in CorCor MisCor CorMis MisMis; do 
  scp $BOUCHET_LOGIN:\"$REMOTE_DIR/PATE Retrospective Pooroverlap M135 \${s} GLM/raw_results_100reps_\${s}_WALD_CI.RData\" bouchet_100rep_\${s}.RData
  echo \"Downloaded \${s}\"
done

Alternative download (if spaces cause issues):
ssh $BOUCHET_LOGIN 'cd $REMOTE_DIR && tar -czf results.tar.gz */raw_results*.RData'
scp $BOUCHET_LOGIN:$REMOTE_DIR/results.tar.gz bouchet_results.tar.gz
tar -xzf bouchet_results.tar.gz
"
