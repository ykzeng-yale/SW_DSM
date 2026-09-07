#!/bin/bash

echo "============================================================"
echo "Validating Poor Overlap Setup for All Scenarios"
echo "============================================================"
echo ""

# Function to check if a file contains specific pattern
check_pattern() {
    local file=$1
    local pattern=$2
    local description=$3
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo "    ✓ $description"
        return 0
    else
        echo "    ✗ $description (NOT FOUND)"
        return 1
    fi
}

# Scenarios to check
scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

all_valid=true

for scenario in "${scenarios[@]}"; do
    echo ""
    echo "Checking $scenario scenario..."
    echo "----------------------------"
    
    DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    
    # Check if directory exists
    if [ ! -d "$DIR" ]; then
        echo "  ✗ Directory not found: $DIR"
        all_valid=false
        continue
    fi
    
    # Check comparison script
    COMP_SCRIPT="$DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    if [ -f "$COMP_SCRIPT" ]; then
        echo "  Comparison script checks:"
        
        # Check scenario setting
        check_pattern "$COMP_SCRIPT" "scenarios <- c(\"$scenario\")" "Scenario correctly set to $scenario"
        
        # Check DSM implementation with lp.pg
        check_pattern "$COMP_SCRIPT" "model.pg = \"linpred\"" "DSM uses model.pg = 'linpred'"
        check_pattern "$COMP_SCRIPT" "lp.pg = X_pg_dsm" "DSM uses lp.pg for PG specification"
        
        # Check scenario logic
        case $scenario in
            "CorCor")
                expected_ps="use_interaction_ps <- .*TRUE"
                expected_pg="use_interaction_pg <- .*TRUE"
                ;;
            "MisCor")
                expected_ps="use_interaction_ps <- .*FALSE"
                expected_pg="use_interaction_pg <- .*TRUE"
                ;;
            "CorMis")
                expected_ps="use_interaction_ps <- .*TRUE"
                expected_pg="use_interaction_pg <- .*FALSE"
                ;;
            "MisMis")
                expected_ps="use_interaction_ps <- .*FALSE"
                expected_pg="use_interaction_pg <- .*FALSE"
                ;;
        esac
        
        # Since we set scenario at the top, check if the logic for flags exists
        if grep -q "use_interaction_ps <- (scenario == \"CorCor\" || scenario == \"CorMis\")" "$COMP_SCRIPT" 2>/dev/null; then
            echo "    ✓ PS interaction logic present"
        else
            echo "    ⚠ PS interaction logic may need review"
        fi
        
        if grep -q "use_interaction_pg <- (scenario == \"CorCor\" || scenario == \"MisCor\")" "$COMP_SCRIPT" 2>/dev/null; then
            echo "    ✓ PG interaction logic present"
        else
            echo "    ⚠ PG interaction logic may need review"
        fi
        
    else
        echo "  ✗ Comparison script not found: $COMP_SCRIPT"
        all_valid=false
    fi
    
    # Check WDSM files
    echo "  WDSM implementation checks:"
    WDSM_BOOT="$DIR/wdsm_method2_multinomial_bootstrap.R"
    WDSM_CI="$DIR/wdsm_ci_functions.R"
    
    if [ -f "$WDSM_BOOT" ]; then
        check_pattern "$WDSM_BOOT" "use_interaction_ps = TRUE" "WDSM bootstrap has use_interaction_ps parameter"
        check_pattern "$WDSM_BOOT" "use_interaction_pg = TRUE" "WDSM bootstrap has use_interaction_pg parameter"
    else
        echo "    ✗ WDSM bootstrap file not found"
        all_valid=false
    fi
    
    if [ -f "$WDSM_CI" ]; then
        check_pattern "$WDSM_CI" "use_interaction_ps = TRUE" "WDSM CI has use_interaction_ps parameter"
        check_pattern "$WDSM_CI" "use_interaction_pg = TRUE" "WDSM CI has use_interaction_pg parameter"
    else
        echo "    ✗ WDSM CI file not found"
        all_valid=false
    fi
    
    # Check data file
    DATA_FILE="$DIR/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData"
    if [ -f "$DATA_FILE" ]; then
        echo "    ✓ Poor overlap data file present"
    else
        echo "    ✗ Poor overlap data file missing"
        all_valid=false
    fi
done

echo ""
echo "============================================================"
if [ "$all_valid" = true ]; then
    echo "✓ All scenarios appear to be set up correctly!"
else
    echo "✗ Some issues found. Please review and fix."
fi
echo "============================================================"
echo ""
echo "Expected behavior for each scenario:"
echo "  CorCor: PS has X1:X2, PG has X1:X2"
echo "  MisCor: PS no X1:X2, PG has X1:X2"
echo "  CorMis: PS has X1:X2, PG no X1:X2"
echo "  MisMis: PS no X1:X2, PG no X1:X2"
echo "============================================================"
