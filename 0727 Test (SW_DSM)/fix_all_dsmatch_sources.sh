#!/bin/bash

# Fix dsmatch sourcing in all poor overlap scenarios

SCENARIOS=("MisCor" "CorMis" "MisMis")  # CorCor already fixed

echo "Fixing dsmatch source files for remaining scenarios..."

for scenario in "${SCENARIOS[@]}"; do
    echo "Fixing $scenario..."
    
    FILE="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    # Copy the fixed version from CorCor
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R" "$FILE"
    
    # Just update the scenario name
    sed -i '' "s/scenario <- \"CorCor\"/scenario <- \"$scenario\"/g" "$FILE"
    sed -i '' "s/Scenario: CorCor/Scenario: $scenario/g" "$FILE"
    
    echo "✅ Fixed $scenario"
done

echo "All scenarios fixed with correct dsmatch source statements!"
