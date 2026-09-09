#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "  SUBMITTING CORRECTED JOBS TO MCCLEARY - DAY PARTITION"
echo "  Using correct variable names and retrospective sampling"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Configuration for McCleary
SERVER="login2.mccleary.ycrc.yale.edu"
USER="yz2324"
REMOTE_BASE="/gpfs/gibbs/project/tong/yz2324"  # Using tong account for better fairshare
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
    REMOTE_DIR="${REMOTE_BASE}/pate_retrospective_goodoverlap_m135_${scenario_lower}_1000rep_final_corrected"
    
    # Create remote directory
    echo "  Creating remote directory: $REMOTE_DIR"
    ssh "$USER@$SERVER" "mkdir -p $REMOTE_DIR"
    
    # Copy the corrected R script
    echo "  Uploading corrected R script..."
    scp compare_methods_pate_retrospective_CORRECTED_FINAL.R "$USER@$SERVER:$REMOTE_DIR/compare_methods_pate_retrospective_mccleary.R"
    
    # Copy required source files - MUST be in parent directory structure
    echo "  Setting up directory structure for source files..."
    ssh "$USER@$SERVER" "mkdir -p $REMOTE_DIR/../dsmatch-master/R"
    scp dsmatch-master/R/dsmatchATE.R "$USER@$SERVER:$REMOTE_DIR/../dsmatch-master/R/"
    
    echo "  Uploading WDSM source files..."
    scp wdsm_method2_multinomial_bootstrap.R "$USER@$SERVER:$REMOTE_DIR/../"
    scp wdsm_ci_functions.R "$USER@$SERVER:$REMOTE_DIR/../"
    
    # Copy population data
    echo "  Uploading population data..."
    scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData "$USER@$SERVER:$REMOTE_DIR/"
    
    # Create submission script
    cat > temp_submit_mccleary_${scenario}.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=SCENARIO_NAME_corrected
#SBATCH --output=output_SCENARIO_NAME_%j.txt
#SBATCH --error=error_SCENARIO_NAME_%j.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem-per-cpu=8G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --account=tong

# Print job information
echo "Job started on $(date)"
echo "Running on node: $SLURM_NODELIST"
echo "Job ID: $SLURM_JOB_ID"
echo "Scenario: SCENARIO_NAME"

# Load R module
module load R/4.3.2-foss-2022b

# Set working directory
cd REMOTE_DIR

# Set environment variables
export SCENARIO="SCENARIO_NAME"
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

# Print system info
echo "Number of cores available: $SLURM_CPUS_PER_TASK"
echo "Memory per CPU: 8G"
echo "Total memory: $((SLURM_CPUS_PER_TASK * 8))G"

# Print R version
R --version

# List files in directory
echo "Files in working directory:"
ls -la

# Check data file
echo "Checking population data file:"
if [ -f "SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData" ]; then
    echo "  Population data file found"
    ls -lh SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData
else
    echo "  ERROR: Population data file not found!"
fi

# Run the simulation
echo "Starting R simulation for scenario SCENARIO_NAME at $(date)"
Rscript compare_methods_pate_retrospective_mccleary.R

# Check exit status
if [ $? -eq 0 ]; then
    echo "Simulation completed successfully at $(date)"
    echo "Listing results files:"
    ls -la *.RData
else
    echo "Simulation failed with exit code $? at $(date)"
fi
EOF
    
    # Replace placeholders
    sed "s/SCENARIO_NAME/${scenario}/g" temp_submit_mccleary_${scenario}.sh > temp_submit_final.sh
    sed -i '' "s|REMOTE_DIR|${REMOTE_DIR}|g" temp_submit_final.sh
    
    # Upload submission script
    echo "  Uploading submission script..."
    scp temp_submit_final.sh "$USER@$SERVER:$REMOTE_DIR/run_${scenario}_mccleary.sh"
    
    # Submit job
    echo "  Submitting job to McCleary..."
    ssh "$USER@$SERVER" "cd $REMOTE_DIR && sbatch run_${scenario}_mccleary.sh"
    
    # Clean up local temp files
    rm temp_submit_mccleary_${scenario}.sh temp_submit_final.sh
    
    echo "  ✅ $scenario submitted successfully!"
    echo ""
done

echo "════════════════════════════════════════════════════════════════"
echo "✅ ALL 4 SCENARIOS SUBMITTED TO MCCLEARY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Job Configuration:"
echo "  • Account: tong (better fairshare)"
echo "  • CPUs: 32 cores per job"
echo "  • Memory: 8GB per CPU (256GB total)"
echo "  • Time limit: 23 hours"
echo "  • Partition: day"
echo "  • M values: 1, 3, 5"
echo "  • Replications: 1000"
echo "  • Using correct variable names (z, y, x1-x6, y0, y1)"
echo "  • Retrospective sampling with survey weights"
echo ""
echo "Monitor commands:"
echo "  ssh $USER@$SERVER 'squeue -u $USER'"
echo "  ssh $USER@$SERVER 'sacct -u $USER --format=JobID,JobName,State,Elapsed,ExitCode'"
echo ""
echo "Check output/error logs:"
echo "  ssh $USER@$SERVER 'tail -f $REMOTE_BASE/pate_retrospective_goodoverlap_m135_corcor_1000rep_final_corrected/output*.txt'"
echo "════════════════════════════════════════════════════════════════"
