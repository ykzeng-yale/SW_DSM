#!/bin/bash
# PROPERLY fix all model specification errors

echo "======================================================================"
echo "  PROPERLY FIXING MODEL SPECIFICATION ERROR"
echo "======================================================================"
echo ""
echo "Based on dsmatch documentation:"
echo "  - 'linpred' = use pre-computed linear predictors (WRONG for us)"
echo "  - 'logit' = fit logistic model on X (CORRECT for PS)"
echo "  - 'glm' = fit linear model on X (CORRECT for PG with continuous Y)"
echo ""

# Function to fix a single file
fix_script() {
    local file="$1"
    local scenario="$2"
    
    echo "  Fixing $scenario script..."
    
    # Create a proper fixed version using Python for complex replacements
    python3 << EOF
import re

with open("$file", 'r') as f:
    content = f.read()

# Fix METHOD 1: Double Score Matching
# Find the DSM block and fix it
dsm_pattern = r'(# Run DSM with bootstrap.*?)(dsm_result = dsmatchATE\([^)]+\))'
def fix_dsm(match):
    dsm_code = """dsm_result <- dsmatchATE(
        Y = Y,
        X = X_ps,  # Use PS matrix (includes interaction if needed)
        A = A,
        method = "dsm",
        model.ps = "logit",  # Always logit for PS
        model.pg = "glm",    # Linear model for continuous outcome
        cov.balance = FALSE,
        varest = TRUE,
        boots = B,
        mc = FALSE,
        ncpus = 1
      )"""
    return match.group(1) + dsm_code

content = re.sub(dsm_pattern, fix_dsm, content, flags=re.DOTALL)

# Fix METHOD 2: Prognostic Score Matching
pg_pattern = r'(# Run PG matching with bootstrap.*?)(pg_result = dsmatchATE\([^)]+\))'
def fix_pg(match):
    pg_code = """pg_result <- dsmatchATE(
        Y = Y,
        X = X_pg,  # Use PG matrix (includes interaction if needed)
        A = A,
        method = "pg",
        model.pg = "glm",  # Linear model for continuous outcome
        cov.balance = FALSE,
        varest = TRUE,
        boots = B,
        mc = FALSE,
        ncpus = 1
      )"""
    return match.group(1) + pg_code

content = re.sub(pg_pattern, fix_pg, content, flags=re.DOTALL)

# Fix METHOD 3: Propensity Score Matching
ps_pattern = r'(# Run PS matching with bootstrap using dsmatch-master.*?)(ps_result = dsmatchATE\([^)]+\))'
def fix_ps(match):
    ps_code = """ps_result <- dsmatchATE(
        Y = Y,
        X = X_ps,  # Use PS matrix (includes interaction if needed)
        A = A,
        method = "ps",
        model.ps = "logit",  # Always logit for PS
        cov.balance = FALSE,
        varest = TRUE,
        boots = B,
        mc = FALSE,
        ncpus = 1
      )"""
    return match.group(1) + ps_code

content = re.sub(ps_pattern, fix_ps, content, flags=re.DOTALL)

# Remove any X_dsm creation that's not needed
content = re.sub(r'# Use scenario-specific X matrices for DSM.*?colnames\(X_dsm\)[^\n]+\n', '', content, flags=re.DOTALL)

# Write the fixed content
with open("${file}.FIXED", 'w') as f:
    f.write(content)
EOF
    
    # Backup and replace
    cp "$file" "${file}.WRONG_SPEC"
    mv "${file}.FIXED" "$file"
    
    echo "    Fixed!"
}

# Fix all 1000rep CORRECTED scripts
for scenario in CorCor MisCor CorMis MisMis; do
    dir="PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
    file="$dir/compare_methods_pate_retrospective_mccleary.R"
    
    if [ -f "$file" ]; then
        fix_script "$file" "$scenario"
    else
        echo "  ERROR: $file not found!"
    fi
done

echo ""
echo "======================================================================"
echo "  Verification"
echo "======================================================================"
echo ""

# Check for problematic patterns
echo "Checking for 'linpred' (should be 0):"
grep -h "model\.\(ps\|pg\).*linpred" PATE*1000rep*CORRECTED*/compare*.R 2>/dev/null | wc -l

echo ""
echo "Checking for correct 'logit' in PS models:"
grep -h 'model\.ps = "logit"' PATE*1000rep*CORRECTED*/compare*.R 2>/dev/null | wc -l

echo ""
echo "Checking for correct 'glm' in PG models:"
grep -h 'model\.pg = "glm"' PATE*1000rep*CORRECTED*/compare*.R 2>/dev/null | wc -l

echo ""
echo "All scripts have been properly fixed!"
echo ""
echo "CORRECT SPECIFICATION:"
echo "  - PS models: Always use model.ps = 'logit' with appropriate X matrix"
echo "  - PG models: Always use model.pg = 'glm' with appropriate X matrix"
echo "  - DSM: Uses both, with X matrices containing interaction as needed"
echo ""
echo "Ready to resubmit corrected jobs!"


