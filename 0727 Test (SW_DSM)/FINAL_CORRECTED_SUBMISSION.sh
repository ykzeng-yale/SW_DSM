#!/bin/bash
# Submit the FULLY CORRECTED 1000-rep jobs with proper DSM setup

echo "════════════════════════════════════════════════════════════════"
echo "  FINAL CORRECTED SUBMISSION - All Issues Fixed"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "FIXES APPLIED:"
echo "  1. PS models: Always use model.ps = 'logit'"
echo "  2. PG models for standalone: Use model.pg = 'glm'"
echo "  3. DSM: Uses SEPARATE covariate matrices:"
echo "     - X = X_ps for PS model"
echo "     - lp.pg = X_pg for PG model"
echo "     - model.pg = 'linpred' to use lp.pg"
echo ""
echo "This correctly allows:"
echo "  - CorCor: Both use X with interaction"
echo "  - MisCor: PS without interaction, PG with interaction"
echo "  - CorMis: PS with interaction, PG without interaction"
echo "  - MisMis: Both use X without interaction"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

# Upload corrected scripts
echo "Uploading fully corrected scripts to McCleary..."
for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    local_dir="PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
    remote_dir="/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_corrected"
    
    echo "  Uploading $scenario script..."
    scp "$local_dir/compare_methods_pate_retrospective_mccleary.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$remote_dir/"
done

echo ""
echo "Submitting corrected jobs..."
ssh yz2324@login2.mccleary.ycrc.yale.edu << 'SSH_EOF'
echo "Submitting from McCleary..."

scenarios=("CorCor" "MisCor" "CorMis" "MisMis")
job_ids=""

for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    work_dir="/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_corrected"
    
    echo "Submitting $scenario job (FULLY CORRECTED)..."
    cd "$work_dir"
    job_output=$(sbatch run_comparison_mccleary_optimized.sh)
    job_id=$(echo $job_output | awk '{print $4}')
    echo "  Job ID: $job_id"
    job_ids="$job_ids $job_id"
done

echo ""
echo "All FULLY CORRECTED jobs submitted!"
echo "Job IDs:$job_ids"
echo ""
echo "These jobs now have:"
echo "  - Correct model types (logit for PS, glm for PG)"
echo "  - Separate covariate matrices for DSM"
echo "  - Proper model misspecification handling"
SSH_EOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Submission Complete - FINAL CORRECTED VERSION"
echo "════════════════════════════════════════════════════════════════"


