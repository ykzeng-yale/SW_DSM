#!/bin/bash

echo "==============================================================="
echo "Deploying FULLY FIXED WDSM to All Scenarios"
echo "==============================================================="
echo ""

# Copy the FULLY FIXED WDSM functions to each scenario folder
for scenario in CorCor MisCor CorMis MisMis; do
    DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    
    echo "Updating $scenario scenario..."
    
    # Copy the FULLY FIXED WDSM functions
    cp wdsm_ci_functions_FULLY_FIXED.R "$DIR/wdsm_ci_functions.R"
    cp wdsm_method2_multinomial_bootstrap_FULLY_FIXED.R "$DIR/wdsm_method2_multinomial_bootstrap.R"
    
    echo "✅ Copied FULLY FIXED WDSM functions to $DIR"
done

echo ""
echo "All scenarios updated with FULLY FIXED WDSM!"
echo ""
echo "Key fixes applied:"
echo "1. Lambda_ij corrected for survey-weighted imputation"
echo "2. Separate S0/S1 score spaces for proper matching"
echo "3. Outcome models fitted on scores, not X"
echo "4. Treatment-aware bootstrap with proper calibration"
