#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "  SUBMITTING CORRECTED JOBS TO BOUCHET CLUSTER"  
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Using Bouchet cluster with:"
echo "  - Path: /nfs/roberts/project/pi_gt353/yz2324"
echo "  - Direct liquid-cooled cores for better performance"
echo ""

# Configuration for Bouchet cluster (from memory)
SERVER="login.bouchet.hpc.yale.edu"
USER="yz2324"
REMOTE_BASE="/nfs/roberts/project/pi_gt353/yz2324"
LOCAL_BASE="$(pwd)"

# Function to convert to lowercase
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Create directories and upload files for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "════════════════════════════════════════════"
    echo "Processing $scenario scenario..."
    echo "════════════════════════════════════════════"
    
    scenario_lower=$(to_lower "$scenario")
    REMOTE_DIR="${REMOTE_BASE}/pate_retrospective_goodoverlap_m135_${scenario_lower}_1000rep_corrected"
    
    # Create remote directory
    echo "  Creating remote directory: $REMOTE_DIR"
    ssh "$USER@$SERVER" "mkdir -p $REMOTE_DIR"
    
    # Copy the corrected R script
    echo "  Uploading main R script..."
    scp compare_methods_pate_retrospective_CORRECTED_FINAL.R "$USER@$SERVER:$REMOTE_DIR/compare_methods_pate_retrospective_mccleary.R"
    
    # Copy required source files
    echo "  Uploading DSMatch source files..."
    scp -r dsmatch-master "$USER@$SERVER:$REMOTE_DIR/"
    
    echo "  Uploading WDSM source files..."
    scp wdsm_method2_multinomial_bootstrap.R "$USER@$SERVER:$REMOTE_DIR/"
    scp wdsm_ci_functions.R "$USER@$SERVER:$REMOTE_DIR/"
    
    # Copy population data
    echo "  Uploading population data (85MB)..."
    scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData "$USER@$SERVER:$REMOTE_DIR/"
    
    # Create submission script for Bouchet with optimized settings
    cat > temp_submit_bouchet_${scenario}.sh <<EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_M135
#SBATCH --output=output_${scenario}_%j.txt
#SBATCH --error=error_${scenario}_%j.txt
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=384G
#SBATCH --time=23:00:00
#SBATCH --partition=day

# Print job information
echo "Job started on \$(date)"
echo "Running on node: \$SLURM_NODELIST"
echo "Job ID: \$SLURM_JOB_ID"
echo "Scenario: ${scenario}"

# Load R module (check availability with 'module spider R' on Bouchet)
module purge
module load R/4.4.1 || module load R/4.3.2 || module load R

# Set working directory
cd $REMOTE_DIR

# Set environment variables
export SCENARIO="${scenario}"
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export R_MAX_NUM_DLLS=1000

# Print R version
R --version

# Run the simulation
echo "Starting R simulation for scenario ${scenario} at \$(date)"
Rscript compare_methods_pate_retrospective_mccleary.R

# Check exit status
if [ \$? -eq 0 ]; then
    echo "Simulation completed successfully at \$(date)"
else
    echo "Simulation failed with exit code \$? at \$(date)"
fi
EOF
    
    # Upload submission script
    echo "  Uploading submission script..."
    scp temp_submit_bouchet_${scenario}.sh "$USER@$SERVER:$REMOTE_DIR/run_${scenario}_bouchet.sh"
    
    # Submit job
    echo "  Submitting job to Bouchet..."
    ssh "$USER@$SERVER" "cd $REMOTE_DIR && sbatch run_${scenario}_bouchet.sh"
    
    # Clean up local temp file
    rm temp_submit_bouchet_${scenario}.sh
    
    echo "  ✅ $scenario submitted successfully!"
    echo ""
done

echo "════════════════════════════════════════════════════════════════"
echo "✅ ALL 4 SCENARIOS SUBMITTED TO BOUCHET CLUSTER"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Job Configuration:"
echo "  • Cluster: Bouchet (direct liquid-cooled)"
echo "  • Nodes: 1 per job"
echo "  • CPUs: 48 cores per job"
echo "  • Memory: 384GB per job"
echo "  • Time limit: 23 hours"
echo "  • Partition: day"
echo "  • M values: 1, 3, 5"
echo "  • Replications: 1000"
echo "  • Path: /nfs/roberts/project/pi_gt353/yz2324"
echo ""
echo "Monitor commands:"
echo "  ssh $USER@$SERVER 'squeue -u $USER'"
echo "  ssh $USER@$SERVER 'sacct -u $USER --format=JobID,JobName,State,Elapsed'"
echo ""
echo "Download results (when complete):"
echo "  for s in corcor miscor cormis mismis; do"
echo "    scp $USER@$SERVER:$REMOTE_BASE/pate_retrospective_goodoverlap_m135_\${s}_1000rep_corrected/*.RData results/"
echo "  done"
echo "════════════════════════════════════════════════════════════════"
