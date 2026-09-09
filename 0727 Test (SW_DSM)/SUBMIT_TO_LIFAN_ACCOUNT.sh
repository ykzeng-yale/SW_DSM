#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "  SUBMITTING 1000-REP JOBS TO LI_FAN ACCOUNT - DAY PARTITION"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Configuration
SERVER="login2.mccleary.ycrc.yale.edu"
USER="yz2324"
REMOTE_BASE="/gpfs/gibbs/project/li_fan/yz2324"

# Function to convert to lowercase
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# First, cancel the pending jobs
echo "Cancelling current pending jobs..."
ssh "$USER@$SERVER" << 'EOF'
# Cancel the pending jobs
scancel 57932104 57932108 57932110 57932112 2>/dev/null
echo "Previous jobs cancelled"
EOF

echo ""
echo "Submitting new jobs to li_fan account..."
echo ""

# Upload and submit for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Processing $scenario scenario..."
    
    scenario_lower=$(to_lower "$scenario")
    REMOTE_DIR="${REMOTE_BASE}/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_final"
    
    # Create updated submission script with li_fan account
    cat > temp_submit_lifan.sh <<EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_lifan
#SBATCH --output=output_${scenario}_lifan_%j.txt
#SBATCH --error=error_${scenario}_lifan_%j.txt
#SBATCH --cpus-per-task=30
#SBATCH --mem-per-cpu=8G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --account=li_fan

module load R/4.3.2-foss-2022b

cd $REMOTE_DIR

# Set environment variable for scenario
export SCENARIO="${scenario}"

Rscript compare_methods_pate_retrospective_mccleary.R
EOF
    
    # Upload submission script
    echo "  Uploading submission script..."
    scp temp_submit_lifan.sh "$USER@$SERVER:$REMOTE_DIR/run_${scenario}_lifan.sh"
    
    # Submit job
    echo "  Submitting job to li_fan account..."
    ssh "$USER@$SERVER" "cd $REMOTE_DIR && sbatch run_${scenario}_lifan.sh"
    
    # Clean up
    rm temp_submit_lifan.sh
    
    echo "  $scenario submitted successfully!"
    echo ""
done

echo "════════════════════════════════════════════════════════════════"
echo "All 4 scenarios submitted to li_fan account on day partition!"
echo "Use 'squeue -u yz2324' to monitor job status"
echo "════════════════════════════════════════════════════════════════"


