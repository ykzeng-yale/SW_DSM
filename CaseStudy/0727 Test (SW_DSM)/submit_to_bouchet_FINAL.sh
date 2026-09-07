#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "  SUBMITTING CORRECTED JOBS TO BOUCHET CLUSTER - DAY PARTITION"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Configuration for Bouchet cluster
SERVER="login.bouchet.hpc.yale.edu"
USER="yz2324"
REMOTE_BASE="/nfs/roberts/project/pi_gt353/yz2324"
LOCAL_BASE="/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Code Experiment/0727 Test (SW_DSM)"

# Function to convert to lowercase
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Create directories and upload files for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Processing $scenario scenario..."
    
    scenario_lower=$(to_lower "$scenario")
    REMOTE_DIR="${REMOTE_BASE}/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_corrected"
    
    # Create remote directory
    echo "  Creating remote directory..."
    ssh "$USER@$SERVER" "mkdir -p $REMOTE_DIR"
    
    # Copy the corrected R script
    echo "  Uploading R scripts..."
    scp compare_methods_pate_retrospective_CORRECTED_FINAL.R "$USER@$SERVER:$REMOTE_DIR/compare_methods_pate_retrospective_mccleary.R"
    
    # Copy required source files
    echo "  Uploading source files..."
    scp -r dsmatch-master "$USER@$SERVER:$REMOTE_DIR/"
    scp wdsm_method2_multinomial_bootstrap.R "$USER@$SERVER:$REMOTE_DIR/"
    scp wdsm_ci_functions.R "$USER@$SERVER:$REMOTE_DIR/"
    
    # Copy population data with correct variable names
    echo "  Uploading population data..."
    scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData "$USER@$SERVER:$REMOTE_DIR/"
    
    # Create submission script for Bouchet with more resources
    cat > temp_submit_bouchet.sh <<EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_bouchet
#SBATCH --output=output_${scenario}_%j.txt
#SBATCH --error=error_${scenario}_%j.txt
#SBATCH --cpus-per-task=48
#SBATCH --mem-per-cpu=8G
#SBATCH --time=23:00:00
#SBATCH --partition=day

# Load R module (update based on Bouchet availability)
module load R/4.4.1

cd $REMOTE_DIR

# Set environment variable for scenario
export SCENARIO="${scenario}"

# Run with more memory available
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

Rscript compare_methods_pate_retrospective_mccleary.R
EOF
    
    # Upload submission script
    echo "  Uploading submission script..."
    scp temp_submit_bouchet.sh "$USER@$SERVER:$REMOTE_DIR/run_${scenario}_bouchet.sh"
    
    # Submit job
    echo "  Submitting job to Bouchet..."
    ssh "$USER@$SERVER" "cd $REMOTE_DIR && sbatch run_${scenario}_bouchet.sh"
    
    # Clean up
    rm temp_submit_bouchet.sh
    
    echo "  $scenario submitted successfully!"
    echo ""
done

echo "════════════════════════════════════════════════════════════════"
echo "All 4 scenarios submitted to Bouchet cluster on day partition!"
echo ""
echo "Configuration:"
echo "  - 48 cores per job (increased from 30)"
echo "  - 8GB per CPU (384GB total memory)"
echo "  - 23 hour time limit"
echo "  - Day partition"
echo "  - Path: /nfs/roberts/project/pi_gt353/yz2324"
echo ""
echo "Use 'ssh $USER@$SERVER squeue -u $USER' to monitor job status"
echo "════════════════════════════════════════════════════════════════"