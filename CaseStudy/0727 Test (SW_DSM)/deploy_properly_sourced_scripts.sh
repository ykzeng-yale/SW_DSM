#!/bin/bash

echo "Deploying properly sourced scripts to all scenarios..."

# Use the fixed CorCor script as template
SOURCE_SCRIPT="PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R"

for scenario in MisCor CorMis MisMis; do
    echo ""
    echo "Processing $scenario..."
    
    TARGET_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    TARGET_SCRIPT="${TARGET_DIR}/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R"
    
    # Copy the template
    cp "$SOURCE_SCRIPT" "$TARGET_SCRIPT"
    
    # Update the scenario in the script
    sed -i '' "s/scenarios <- c(\"CorCor\")/scenarios <- c(\"${scenario}\")/" "$TARGET_SCRIPT"
    
    # Update the comment to reflect the correct scenario
    sed -i '' "s/# Scenario: CorCor (Both PS and PGS correct)/# Scenario: ${scenario}/" "$TARGET_SCRIPT"
    
    # Update output file names
    sed -i '' "s/_CorCor/_${scenario}/g" "$TARGET_SCRIPT"
    
    echo "  Created: $TARGET_SCRIPT"
done

echo ""
echo "All PROPERLY_SOURCED scripts deployed!"
echo ""
echo "Summary:"
echo "- All scripts now properly source BOTH:"
echo "  1. wdsm_method2_multinomial_bootstrap.R (contains compute_wdsm_method2_ci)"
echo "  2. wdsm_ci_functions.R (contains wdsm_point_estimate)"
echo "- Each scenario has its own script with correct scenario setting"
