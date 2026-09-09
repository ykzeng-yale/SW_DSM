#!/bin/bash

echo "============================================================"
echo "Deploying CORRECT comparison scripts to all scenario folders"
echo "============================================================"

# Copy the correct script to each scenario folder and update the scenario parameter
for scenario in CorCor MisCor CorMis MisMis; do
    echo ""
    echo "Processing $scenario..."
    
    # Define the target directory
    TARGET_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    
    # Copy the correct script
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECT.R" \
       "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Update the scenario parameter in the copied script
    sed -i '' "s/scenarios <- c(\"CorCor\")/scenarios <- c(\"$scenario\")/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Also update output file names to include scenario
    sed -i '' "s/_CorCor_CORRECT/_${scenario}/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    echo "✓ Correct script deployed to $scenario folder"
done

echo ""
echo "============================================================"
echo "All correct scripts deployed successfully!"
echo "============================================================"
echo ""
echo "Key corrections applied:"
echo "1. DSM: Uses separate X matrices for PS and PG models"
echo "   - X.ps parameter for PS model covariates"
echo "   - X parameter for PG/outcome model covariates"
echo "2. PS matching: Always uses logit, only changes X.ps covariates"
echo "3. PG matching: Only changes X covariates (interaction or not)"
echo "4. NO model type changes (logit stays logit)"
echo ""
echo "Expected results in CorCor scenario:"
echo "- WDSM: <1% bias, ~95% coverage"
echo "- DSM: ~1-2% bias, ~94-96% coverage"
echo "- All methods: Proper handling of interaction terms"
echo "============================================================"
