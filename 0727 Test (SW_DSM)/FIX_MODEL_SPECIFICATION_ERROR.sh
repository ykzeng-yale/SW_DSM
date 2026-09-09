#!/bin/bash
# CRITICAL FIX: Model specification should ONLY change interaction term, NOT model type!

echo "======================================================================"
echo "CRITICAL FIX: Correcting Model Specification Error"
echo "======================================================================"
echo ""
echo "ERROR FOUND: Scripts are switching between 'logit' and 'linpred' models"
echo "CORRECT BEHAVIOR: Always use 'logit', only change X matrix (with/without X1:X2)"
echo ""

# Fix all 1000rep CORRECTED folders
for scenario in CorCor MisCor CorMis MisMis; do
    dir="PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
    file="$dir/compare_methods_pate_retrospective_mccleary.R"
    
    echo "Fixing $scenario..."
    
    if [ -f "$file" ]; then
        # Create backup
        cp "$file" "${file}.BAD_MODEL_SPEC"
        
        # Fix DSM method (Method 1)
        # WRONG: model.ps = if (use_interaction_ps) "linpred" else "logit",
        # RIGHT: model.ps = "logit",
        sed -i '' 's/model\.ps = if (use_interaction_ps) "linpred" else "logit"/model.ps = "logit"/' "$file"
        
        # WRONG: lp.ps = if (use_interaction_ps) X_ps else NULL,
        # RIGHT: Remove lp.ps line entirely - let dsmatch use X matrix with logit
        sed -i '' '/lp\.ps = if (use_interaction_ps) X_ps else NULL,/d' "$file"
        
        # Fix PS method (Method 3) - same issues
        # Already fixed by above since it's the same pattern
        
        # For DSM, we need to use the correct X matrix
        # Change X = X_dsm to X = X_ps for DSM method
        sed -i '' '/method = "dsm"/,/^[[:space:]]*$/{s/X = X_dsm,/X = X_ps,/}' "$file"
        
        # For PG method, keep model.pg = "linpred" and lp.pg = X_pg (this is correct)
        # No changes needed for PG
        
        echo "  Fixed $file"
    else
        echo "  ERROR: File not found: $file"
    fi
done

echo ""
echo "======================================================================"
echo "Creating Correct Version of Comparison Script"
echo "======================================================================"

# Create a reference correct version
cat > "CORRECT_MODEL_SPEC_compare_methods.R" << 'EOF'
# CORRECT MODEL SPECIFICATION APPROACH
# Only the X matrix changes, NOT the model type!

# For each scenario:
# CorCor: PS uses X with X1:X2, PGS uses X with X1:X2
# MisCor: PS uses X without X1:X2, PGS uses X with X1:X2  
# CorMis: PS uses X with X1:X2, PGS uses X without X1:X2
# MisMis: PS uses X without X1:X2, PGS uses X without X1:X2

# Determine which models include interaction
use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")

# Create X matrices
if (use_interaction_ps) {
  X_ps <- cbind(X, X[,1] * X[,2])
  colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
} else {
  X_ps <- X
  colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6")
}

if (use_interaction_pg) {
  X_pg <- cbind(X, X[,1] * X[,2])
  colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
} else {
  X_pg <- X
  colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6")
}

# METHOD 1: DSM - CORRECT VERSION
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps,  # Use PS matrix for DSM
  A = A,
  method = "dsm",
  model.ps = "logit",  # ALWAYS logit!
  model.pg = "lm",     # Linear model for prognostic score
  cov.balance = FALSE,
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)

# METHOD 3: PS Matching - CORRECT VERSION  
ps_result <- dsmatchATE(
  Y = Y,
  X = X_ps,  # Use PS matrix
  A = A,
  method = "ps",
  model.ps = "logit",  # ALWAYS logit!
  cov.balance = FALSE,
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)

# METHOD 2: PG Matching - This one was already correct
pg_result <- dsmatchATE(
  Y = Y,
  X = X_pg,  # Use PG matrix
  A = A,
  method = "pg",
  model.pg = "lm",  # Linear model for prognostic score
  cov.balance = FALSE,
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)
EOF

echo "Reference correct version saved to: CORRECT_MODEL_SPEC_compare_methods.R"
echo ""
echo "======================================================================"
echo "CRITICAL ISSUES TO FIX:"
echo "======================================================================"
echo ""
echo "1. ALL dsmatch methods should use model.ps = 'logit' ALWAYS"
echo "2. Remove lp.ps parameter - not needed when using logit"
echo "3. DSM should use X_ps matrix (with/without interaction based on scenario)"
echo "4. PS matching should use X_ps matrix"
echo "5. PG matching should use X_pg matrix with model.pg = 'lm'"
echo ""
echo "THE SUBMITTED JOBS ARE RUNNING WITH WRONG MODEL SPECIFICATIONS!"
echo "We need to cancel them and resubmit with corrected scripts!"


