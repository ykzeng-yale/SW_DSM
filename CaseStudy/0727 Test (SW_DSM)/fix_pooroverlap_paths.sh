#!/bin/bash

# Fix the path issues in poor overlap scripts

echo "Fixing path issues in poor overlap scripts..."

SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")

for scenario in "${SCENARIOS[@]}"; do
    echo "Fixing $scenario..."
    
    # Fix the paths in the comparison script
    sed -i '' 's|source("../wdsm_method2_multinomial_bootstrap_WALD.R")|source("wdsm_method2_multinomial_bootstrap_WALD.R")|g' \
        "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    sed -i '' 's|source("../wdsm_ci_functions.R")|source("wdsm_ci_functions.R")|g' \
        "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    sed -i '' 's|load("../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")|load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")|g' \
        "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    echo "✅ Fixed paths for $scenario"
done

echo "All paths fixed!"
