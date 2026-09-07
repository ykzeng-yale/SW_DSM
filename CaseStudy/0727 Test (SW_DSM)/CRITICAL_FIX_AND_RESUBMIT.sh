#!/bin/bash
# Resubmit the PROPERLY CORRECTED 1000-rep jobs

echo "════════════════════════════════════════════════════════════════"
echo "  CRITICAL FIX: Model Specification Error Corrected"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "WHAT WAS WRONG:"
echo "  - Used 'linpred' with pre-computed linear predictors"
echo "  - This completely changed the model type, not just covariates"
echo ""
echo "WHAT'S CORRECT NOW:"
echo "  - Always use model.ps = 'logit' for propensity scores"
echo "  - Always use model.pg = 'glm' for prognostic scores"
echo "  - Only X matrix changes (with/without X1:X2 interaction)"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Uploading corrected scripts and resubmitting..."
echo "════════════════════════════════════════════════════════════════"
echo ""

scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

# Upload corrected scripts
echo "Uploading corrected scripts to McCleary..."
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
    
    echo "Submitting $scenario job (PROPERLY CORRECTED)..."
    cd "$work_dir"
    job_output=$(sbatch run_comparison_mccleary_optimized.sh)
    job_id=$(echo $job_output | awk '{print $4}')
    echo "  Job ID: $job_id"
    job_ids="$job_ids $job_id"
done

echo ""
echo "All CORRECTED jobs submitted!"
echo "Job IDs:$job_ids"
echo ""
echo "These jobs now have the CORRECT model specification:"
echo "  - PS models: Always logit"
echo "  - PG models: Always glm"
echo "  - Only covariate matrices change for interaction"
SSH_EOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Submission Complete - CORRECT VERSION"
echo "════════════════════════════════════════════════════════════════"


