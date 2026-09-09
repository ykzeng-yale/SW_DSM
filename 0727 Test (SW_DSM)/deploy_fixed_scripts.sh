#!/bin/bash

echo "============================================================"
echo "Deploying FIXED comparison scripts to all scenario folders"
echo "============================================================"

# Copy the fixed script to each scenario folder and update the scenario parameter
for scenario in CorCor MisCor CorMis MisMis; do
    echo ""
    echo "Processing $scenario..."
    
    # Define the target directory
    TARGET_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    
    # Copy the fixed script
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED.R" \
       "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED.R"
    
    # Update the scenario parameter in the copied script
    sed -i '' "s/scenarios <- c(\"CorCor\")/scenarios <- c(\"$scenario\")/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED.R"
    
    # Also update output file names to include scenario
    sed -i '' "s/_CorCor_FIXED/_${scenario}_FIXED/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED.R"
    
    echo "✓ Fixed script deployed to $scenario folder"
done

echo ""
echo "============================================================"
echo "All fixed scripts deployed successfully!"
echo "============================================================"
echo ""
echo "Key fixes applied:"
echo "1. DSM now handles PS and PG specifications SEPARATELY"
echo "2. PG matching uses correct interaction specification"
echo "3. PS matching uses correct interaction specification"
echo "4. All methods properly respect use_interaction_ps and use_interaction_pg flags"
echo ""
echo "Expected improvements in CorCor scenario:"
echo "- WDSM: Should achieve <1% bias, ~95% coverage"
echo "- DSM: Should achieve ~1-2% bias, ~94-96% coverage"
echo "- Other methods: Should also show significant improvement"
echo "============================================================"
