#!/bin/bash

# Fix export lists in all poor overlap scenarios

SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")

for scenario in "${SCENARIOS[@]}"; do
    echo "Fixing exports for $scenario..."
    
    FILE="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    # Fix the export list to include all helper functions
    sed -i '' '/\.export = c(/,/)/ {
        s/calculate_weighted_reuse_counts", "compute_wdsm_method2_ci")/calculate_weighted_reuse_counts", "compute_wdsm_method2_ci",\
                                  "standardize_with_weights", "show_progress",\
                                  "method1_bootstrap_ci", "method2_bootstrap_ci")/
    }' "$FILE"
    
    echo "✅ Fixed exports for $scenario"
done

echo "All export lists updated!"
