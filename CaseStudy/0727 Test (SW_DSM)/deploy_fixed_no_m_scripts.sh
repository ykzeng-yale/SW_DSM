#!/bin/bash

echo "============================================================"
echo "Deploying FIXED scripts (M parameter removed) to all scenarios"
echo "Matching Good Overlap CORRECTED implementation exactly"
echo "============================================================"

# Copy the fixed script to each scenario folder
for scenario in CorCor MisCor CorMis MisMis; do
    echo ""
    echo "Processing $scenario..."
    
    # Define the target directory
    TARGET_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    
    # Copy the fixed script
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED_NO_M.R" \
       "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED_NO_M.R"
    
    # Update the scenario parameter in the copied script
    sed -i '' "s/scenarios <- c(\"CorCor\")/scenarios <- c(\"$scenario\")/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED_NO_M.R"
    
    # Update output file names to include scenario
    sed -i '' "s/_CorCor_FIXED/_${scenario}_FIXED/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED_NO_M.R"
    
    # Update the description in the header
    sed -i '' "s/Scenario: CorCor (Both PS and PGS correct)/Scenario: $scenario/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED_NO_M.R"
    
    echo "✓ Fixed script deployed to $scenario folder"
done

echo ""
echo "============================================================"
echo "All FIXED scripts deployed successfully!"
echo "============================================================"
echo ""
echo "Key fixes applied:"
echo "1. ✅ REMOVED M parameter from all dsmatchATE calls"
echo "   - DSM: No M parameter (matches Good Overlap CORRECTED)"
echo "   - PG: No M parameter (matches Good Overlap CORRECTED)"
echo "   - PS: No M parameter (matches Good Overlap CORRECTED)"
echo ""
echo "2. ✅ INCREASED timeout for WDSM from 300 to 600 seconds"
echo ""
echo "3. ✅ Kept all other correct implementations:"
echo "   - Source dsmatch files INSIDE worker"
echo "   - DSM: X_ps for X, X_pg for lp.pg"
echo "   - PG: model.pg='glm'"
echo "   - Scenario-specific interaction handling"
echo ""
echo "This now EXACTLY matches the Good Overlap CORRECTED implementation!"
echo "============================================================"
