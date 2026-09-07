# Poor Overlap vs Good Overlap Implementation Alignment

## Summary
After reviewing the good overlap implementation files, I've confirmed that our poor overlap implementation is correctly aligned with the same approach, with proper handling of model specification scenarios.

## Key Components Verified

### 1. WDSM Implementation ✓
Both good and poor overlap cases use the same WDSM structure:
- **wdsm_method2_multinomial_bootstrap.R**: Properly parameterized with `use_interaction_ps` and `use_interaction_pg`
- **wdsm_ci_functions.R**: Correctly handles interaction flags for PS and PG models
- No hardcoded interaction terms in either implementation

### 2. DSM Implementation ✓
Correctly implemented in both cases:
```R
# DSM with independent PS and PG specifications
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps_dsm,          # X for PS model
  A = A,
  method = "dsm",
  model.ps = "logit",    
  model.pg = "linpred",  # Linear predictor for PG
  lp.pg = X_pg_dsm,      # Separate specification for PG
  M = M,
  ...
)
```

### 3. Model Specification Scenarios ✓

| Scenario | PS Model | PG Model | use_interaction_ps | use_interaction_pg |
|----------|----------|----------|-------------------|-------------------|
| CorCor   | Has X1:X2 | Has X1:X2 | TRUE | TRUE |
| MisCor   | No X1:X2 | Has X1:X2 | FALSE | TRUE |
| CorMis   | Has X1:X2 | No X1:X2 | TRUE | FALSE |
| MisMis   | No X1:X2 | No X1:X2 | FALSE | FALSE |

### 4. Key Files Synchronized
All scenarios now have consistent implementations:
- `compare_methods_pate_retrospective_mccleary_M5_100reps.R` (FINAL version)
- `wdsm_method2_multinomial_bootstrap.R`
- `wdsm_ci_functions.R`
- `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData`

## Implementation Details

### DSM Method
- Uses `X` parameter for PS model covariates
- Uses `model.pg = "linpred"` with `lp.pg` for PG model covariates
- Allows truly independent specification of PS and PG models

### PS Matching
- Uses `X` with appropriate interaction specification based on `use_interaction_ps`
- Always uses `model.ps = "logit"`

### PG Matching
- Uses `X` with appropriate interaction specification based on `use_interaction_pg`

### Survey-Weighted PS (MatchIt)
- PS formula includes interaction based on `use_interaction_ps`
- Outcome model includes interaction based on `use_interaction_pg`

### WDSM
- Properly parameterized with both `use_interaction_ps` and `use_interaction_pg`
- Bootstrap implementation correctly re-estimates models with appropriate specifications

## Validation Results
✓ All 4 scenarios (CorCor, MisCor, CorMis, MisMis) validated successfully
✓ WDSM files synchronized across all scenarios
✓ DSM implementation uses correct `lp.pg` approach
✓ Interaction logic properly implemented for each scenario

## Expected Results
With this aligned implementation:
- **CorCor**: All methods should perform well (WDSM <1% bias, ~95% coverage)
- **MisCor**: PS-based methods degraded, PG-based methods still good
- **CorMis**: PS-based methods still good, PG-based methods degraded
- **MisMis**: All methods degraded

## Ready for Submission
The final scripts are ready to be submitted with:
```bash
./submit_final_100rep_jobs.sh
```

This will submit 100-replication jobs for all 4 scenarios to the McCleary HPC cluster.
