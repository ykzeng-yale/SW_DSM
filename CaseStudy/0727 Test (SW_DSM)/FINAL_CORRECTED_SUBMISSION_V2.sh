#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "  FINAL FULLY CORRECTED SUBMISSION - All Critical Issues Fixed"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "FIXES APPLIED:"
echo "  1. PS models: Always use model.ps = 'logit'"
echo "  2. PG models for standalone: Use model.pg = 'glm'"
echo "  3. DSM: Uses SEPARATE covariate matrices:"
echo "     - X = X_ps for PS model"
echo "     - lp.pg = X_pg for PG model"
echo "     - model.pg = 'linpred' to use lp.pg"
echo "  4. Survey-Weighted Full PSM: Outcome model ALWAYS uses full"
echo "     specification Y ~ A * (X1+X2+X3+X4+X5+X6+X1:X2)"
echo "  5. Unweighted methods: PS always uses logit (no linpred)"
echo ""
echo "Expected Results:"
echo "  - CorCor and CorMis: Identical for Survey-Weighted Full PSM"
echo "  - MisCor and MisMis: Identical for Survey-Weighted Full PSM"
echo "  - DSM should show different results for all 4 scenarios"
echo ""
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

# Upload and submit for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Processing $scenario scenario..."
    
    LOCAL_DIR="PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
    scenario_lower=$(to_lower "$scenario")
    REMOTE_DIR="${REMOTE_BASE}/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_final"
    
    echo "  Creating remote directory..."
    ssh "$USER@$SERVER" "mkdir -p $REMOTE_DIR"
    
    echo "  Uploading files..."
    # Upload R scripts
    scp "${LOCAL_DIR}/compare_methods_pate_retrospective_mccleary.R" \
        "$USER@$SERVER:$REMOTE_DIR/"
    scp "wdsm_ci_functions.R" "$USER@$SERVER:$REMOTE_DIR/"
    scp "wdsm_method2_multinomial_bootstrap.R" "$USER@$SERVER:$REMOTE_DIR/"
    
    # Upload SuperPopGen data
    echo "  Uploading population data (81MB)..."
    scp "SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData" \
        "$USER@$SERVER:$REMOTE_DIR/"
    
    # Upload dsmatch-master folder
    echo "  Uploading dsmatch-master..."
    scp -r "dsmatch-master" "$USER@$SERVER:$REMOTE_DIR/"
    
    # Create submission script
    cat > temp_submit.sh <<EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_final
#SBATCH --output=output_${scenario}_%j.txt
#SBATCH --error=error_${scenario}_%j.txt
#SBATCH --cpus-per-task=30
#SBATCH --mem-per-cpu=8G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --account=li_fan

module load R/4.3.2-foss-2022b

cd $REMOTE_DIR

Rscript compare_methods_pate_retrospective_mccleary.R
EOF
    
    # Upload submission script
    scp temp_submit.sh "$USER@$SERVER:$REMOTE_DIR/run_${scenario}_final.sh"
    
    # Submit job
    echo "  Submitting job..."
    ssh "$USER@$SERVER" "cd $REMOTE_DIR && sbatch run_${scenario}_final.sh"
    
    # Clean up
    rm temp_submit.sh
    
    echo "  $scenario submitted successfully!"
    echo ""
done

echo "════════════════════════════════════════════════════════════════"
echo "All 4 scenarios submitted with fully corrected specifications!"
echo "Use 'squeue -u yz2324' to monitor job status"
echo "════════════════════════════════════════════════════════════════"


