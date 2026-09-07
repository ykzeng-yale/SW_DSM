#!/bin/bash

# Copy the fixed CorCor script to all other scenarios

SCENARIOS=("MisCor" "CorMis" "MisMis")

echo "Copying fixed script to all scenarios..."

for scenario in "${SCENARIOS[@]}"; do
    echo "Updating $scenario..."
    
    # Copy the fixed CorCor file
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R" \
       "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    # Update the scenario name
    sed -i '' "s/scenario <- \"CorCor\"/scenario <- \"$scenario\"/g" \
        "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    sed -i '' "s/Scenario: CorCor/Scenario: $scenario/g" \
        "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    echo "✅ Fixed $scenario"
done

echo "All scenarios updated with corrected population data reference!"


