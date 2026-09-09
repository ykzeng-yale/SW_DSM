#!/bin/bash

echo "============================================================"
echo "Deploying FINAL comparison scripts to all scenario folders"
echo "============================================================"

# Copy the final script to each scenario folder and update the scenario parameter
for scenario in CorCor MisCor CorMis MisMis; do
    echo ""
    echo "Processing $scenario..."
    
    # Define the target directory
    TARGET_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    
    # Copy the final script
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_FINAL.R" \
       "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Update the scenario parameter in the copied script
    sed -i '' "s/scenarios <- c(\"CorCor\")/scenarios <- c(\"$scenario\")/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Also update output file names to include scenario
    sed -i '' "s/_CorCor\./_${scenario}\./g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    echo "✓ Final script deployed to $scenario folder"
done

echo ""
echo "============================================================"
echo "All FINAL scripts deployed successfully!"
echo "============================================================"
echo ""
echo "Key implementation details:"
echo "1. DSM: Uses X parameter for PS model, lp.pg parameter for PG model"
echo "   - X = X_ps_dsm (with/without interaction based on use_interaction_ps)"
echo "   - model.pg = 'linpred', lp.pg = X_pg_dsm (with/without interaction based on use_interaction_pg)"
echo "2. PS matching: Uses X with correct interaction specification"
echo "3. PG matching: Uses X with correct interaction specification"
echo "4. All methods maintain model.ps = 'logit'"
echo ""
echo "This allows truly independent PS and PG specifications for each scenario:"
echo "- CorCor: Both PS and PG have interaction"
echo "- MisCor: PS misspecified (no interaction), PG correct (has interaction)"
echo "- CorMis: PS correct (has interaction), PG misspecified (no interaction)"
echo "- MisMis: Both PS and PG misspecified (no interaction)"
echo "============================================================"
