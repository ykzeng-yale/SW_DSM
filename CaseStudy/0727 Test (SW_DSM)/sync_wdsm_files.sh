#!/bin/bash

echo "============================================================"
echo "Syncing WDSM files across all Poor Overlap scenarios"
echo "============================================================"
echo ""
echo "This ensures all scenarios use the same WDSM implementation"
echo "that properly handles use_interaction_ps and use_interaction_pg"
echo ""

# Define the source files (from CorCor which should have the latest version)
SOURCE_DIR="PATE Retrospective Pooroverlap M135 CorCor GLM"

# Check if source files exist
if [ ! -f "$SOURCE_DIR/wdsm_method2_multinomial_bootstrap.R" ]; then
    echo "Error: Source wdsm_method2_multinomial_bootstrap.R not found!"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/wdsm_ci_functions.R" ]; then
    echo "Error: Source wdsm_ci_functions.R not found!"
    exit 1
fi

# Scenarios to update
scenarios=("MisCor" "CorMis" "MisMis")

for scenario in "${scenarios[@]}"; do
    TARGET_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    
    echo "Updating $scenario scenario..."
    
    # Copy WDSM files
    cp "$SOURCE_DIR/wdsm_method2_multinomial_bootstrap.R" "$TARGET_DIR/"
    cp "$SOURCE_DIR/wdsm_ci_functions.R" "$TARGET_DIR/"
    
    echo "  ✓ Copied wdsm_method2_multinomial_bootstrap.R"
    echo "  ✓ Copied wdsm_ci_functions.R"
done

echo ""
echo "============================================================"
echo "All WDSM files synchronized successfully!"
echo "============================================================"
echo ""
echo "Key features of synchronized WDSM implementation:"
echo "1. Properly parameterized with use_interaction_ps and use_interaction_pg"
echo "2. No hardcoded interaction terms"
echo "3. Compatible with all model specification scenarios"
echo "============================================================"
