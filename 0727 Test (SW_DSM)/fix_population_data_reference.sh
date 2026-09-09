#!/bin/bash

# Fix the population data reference in all scenarios

SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")

echo "Fixing population data references..."

for scenario in "${SCENARIOS[@]}"; do
    echo "Fixing $scenario..."
    
    FILE="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    # Fix the population data loading section
    sed -i '' 's/true_pate <- SuperPop_Poor\$true_pate/# Extract population data and true PATE\
population <- SuperPopGen_PoorOverlap_AllinOne_0118_2025\[\[1\]\]\
# true_pate is already in the loaded workspace/g' "$FILE"
    
    sed -i '' 's/nrow(SuperPop_Poor\$data)/nrow(population)/g' "$FILE"
    
    # Fix the export list
    sed -i '' 's/"SuperPop_Poor"/"population"/g' "$FILE"
    
    # Fix the function call
    sed -i '' 's/pop_data = SuperPop_Poor\$data/pop_data = population/g' "$FILE"
    
    echo "✅ Fixed $scenario"
done

echo "All population data references fixed!"


