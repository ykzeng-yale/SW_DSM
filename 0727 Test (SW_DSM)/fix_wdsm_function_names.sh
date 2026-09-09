#!/bin/bash

echo "==============================================================="
echo "Fixing WDSM function names in comparison scripts"
echo "==============================================================="
echo ""

# Fix function calls in all FIXED_V3 scripts
for scenario in CorCor MisCor CorMis MisMis; do
    SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R"
    
    if [ -f "$SCRIPT" ]; then
        # Fix the function call
        sed -i '' 's/compute_wdsm_method2_ci(/compute_wdsm_method2_ci_FULLY_FIXED(/' "$SCRIPT"
        
        # Fix the export list
        sed -i '' 's/"wdsm_point_estimate"/"wdsm_point_estimate_FIXED"/' "$SCRIPT"
        sed -i '' 's/"compute_wdsm_method2_ci"/"compute_wdsm_method2_ci_FULLY_FIXED"/' "$SCRIPT"
        
        # Add missing exports if needed
        sed -i '' 's/"retrospective_sample"/"retrospective_sample", "calculate_weighted_reuse_counts_FIXED", "fit_mu_on_scores", "predict_mu_on_scores", "standardize_with_weights", "weighted_distance", "find_weighted_neighbors"/' "$SCRIPT"
        
        echo "✅ Fixed function names in $scenario script"
    fi
done

echo ""
echo "Function names corrected to match actual definitions"

