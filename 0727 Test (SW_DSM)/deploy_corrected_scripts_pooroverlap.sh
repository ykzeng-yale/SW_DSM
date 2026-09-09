#!/bin/bash

echo "============================================================"
echo "Deploying CORRECTED comparison scripts to all scenario folders"
echo "Based on Good Overlap implementation structure"
echo "============================================================"

# Copy the corrected script to each scenario folder and update the scenario parameter
for scenario in CorCor MisCor CorMis MisMis; do
    echo ""
    echo "Processing $scenario..."
    
    # Define the target directory
    TARGET_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    
    # Copy the corrected script
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED.R" \
       "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Update the scenario parameter in the copied script
    sed -i '' "s/scenarios <- c(\"CorCor\")/scenarios <- c(\"$scenario\")/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Also update output file names to include scenario
    sed -i '' "s/_CorCor\./_${scenario}\./g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Update the description in the header
    sed -i '' "s/Scenario: CorCor (Both PS and PGS correct)/Scenario: $scenario/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    echo "✓ Corrected script deployed to $scenario folder"
done

echo ""
echo "============================================================"
echo "All CORRECTED scripts deployed successfully!"
echo "============================================================"
echo ""
echo "Key fixes from Good Overlap implementation:"
echo "1. Source dsmatch files INSIDE the worker function"
echo "2. DSM: Uses X_ps for X parameter, X_pg for lp.pg parameter"
echo "3. PG matching: Uses model.pg='glm' (not 'linpred')"
echo "4. PS matching: Uses X_ps with correct interaction"
echo "5. All methods properly handle interaction terms per scenario"
echo ""
echo "Scenario specifications:"
echo "- CorCor: Both PS and PG have interaction"
echo "- MisCor: PS misspecified (no interaction), PG correct (has interaction)"
echo "- CorMis: PS correct (has interaction), PG misspecified (no interaction)"
echo "- MisMis: Both PS and PG misspecified (no interaction)"
echo "============================================================"
