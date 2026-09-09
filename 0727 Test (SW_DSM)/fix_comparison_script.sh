#!/bin/bash

echo "Fixing model specification issues in comparison scripts..."

# Fix for each scenario folder
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Fixing $scenario folder..."
    
    SCRIPT_PATH="PATE Retrospective Pooroverlap M135 $scenario GLM/compare_methods_pate_retrospective_mccleary.R"
    SCRIPT_100REP="PATE Retrospective Pooroverlap M135 $scenario GLM/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Create a fixed version of the key section
    cat > temp_fix.txt << 'EOF'
      # ============================================================
      # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch-master)
      # ============================================================
      tryCatch({
        # FIXED: DSM needs to handle PS and PG specifications separately
        # Always use base X for DSM - it will handle models internally
        X_dsm <- X
        colnames(X_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6")
        
        # Run DSM with appropriate model specifications
        dsm_result <- dsmatchATE(
          Y = Y,
          X = X_dsm,
          A = A,
          method = "dsm",
          # PS model specification
          model.ps = if (use_interaction_ps) {
            # Use linear predictor with interaction
            "linpred"
          } else {
            # Use logit without interaction
            "logit"
          },
          lp.ps = if (use_interaction_ps) {
            # Provide X with interaction for PS
            cbind(X, X[,1] * X[,2])
          } else {
            NULL
          },
          # PG model specification
          model.pg = if (use_interaction_pg) {
            # Use linear predictor with interaction
            "linpred"
          } else {
            # Use linear predictor without interaction
            "linpred"
          },
          lp.pg = if (use_interaction_pg) {
            # Provide X with interaction for PG
            cbind(X, X[,1] * X[,2])
          } else {
            X
          },
          cov.balance = FALSE,
          varest = TRUE,
          boots = B,
          mc = FALSE,
          ncpus = 1
        )
        
        m_results$dsm_unweighted <- list(
          estimate = dsm_result$est.ds,
          se = sqrt(dsm_result$bootvar[1,1]),
          ci_lower = dsm_result$est.ds - qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1]),
          ci_upper = dsm_result$est.ds + qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1])
        )
        
      }, error = function(e) {
        cat("DSM Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
        m_results$dsm_unweighted <- list(
          estimate = NA,
          se = NA,
          ci_lower = NA,
          ci_upper = NA
        )
      })
      
      # ============================================================
      # METHOD 2: UNWEIGHTED PROGNOSTIC SCORE MATCHING (dsmatch-master)
      # ============================================================
      tryCatch({
        # FIXED: PG matching should use correct specification
        pg_result <- dsmatchATE(
          Y = Y,
          X = X,
          A = A,
          method = "pg",
          model.pg = "linpred",
          lp.pg = if (use_interaction_pg) {
            cbind(X, X[,1] * X[,2])
          } else {
            X
          },
          cov.balance = FALSE,
          varest = TRUE,
          boots = B,
          mc = FALSE,
          ncpus = 1
        )
        
        m_results$pg_unweighted <- list(
          estimate = pg_result$est.pg,
          se = sqrt(pg_result$bootvar[1,1]),
          ci_lower = pg_result$est.pg - qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1]),
          ci_upper = pg_result$est.pg + qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1])
        )
        
      }, error = function(e) {
        m_results$pg_unweighted <- list(
          estimate = NA,
          se = NA,
          ci_lower = NA,
          ci_upper = NA
        )
      })
      
      # ============================================================
      # METHOD 3: UNWEIGHTED PROPENSITY SCORE MATCHING (dsmatch-master)
      # ============================================================
      tryCatch({
        # FIXED: PS matching should use correct specification
        ps_result <- dsmatchATE(
          Y = Y,
          X = X,
          A = A,
          method = "ps",
          model.ps = if (use_interaction_ps) {
            "linpred"
          } else {
            "logit"
          },
          lp.ps = if (use_interaction_ps) {
            cbind(X, X[,1] * X[,2])
          } else {
            NULL
          },
          cov.balance = FALSE,
          varest = TRUE,
          boots = B,
          mc = FALSE,
          ncpus = 1
        )
        
        m_results$ps_unweighted <- list(
          estimate = ps_result$est.ps,
          se = sqrt(ps_result$bootvar[1,1]),
          ci_lower = ps_result$est.ps - qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1]),
          ci_upper = ps_result$est.ps + qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1])
        )
        
      }, error = function(e) {
        m_results$ps_unweighted <- list(
          estimate = NA,
          se = NA,
          ci_lower = NA,
          ci_upper = NA
        )
      })
EOF
    
    echo "Script fixes prepared for $scenario"
done

echo "Fix prepared. This needs to be manually applied to the comparison scripts."
echo "The key issue was that DSM was only using interaction when BOTH PS and PG needed it,"
echo "but it should handle them SEPARATELY based on use_interaction_ps and use_interaction_pg."
