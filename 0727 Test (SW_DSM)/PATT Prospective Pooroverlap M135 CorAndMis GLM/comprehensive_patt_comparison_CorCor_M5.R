#!/usr/bin/env Rscript
# Comprehensive Comparison: Baseline vs Survey-Weighted Matching Methods for PATT (Poor Overlap)
# McCleary HPC Version - Optimized for FORK cluster with 30 cores
# M=5 Only Version: Only M=5 neighbors for faster runtime
# Model Specification: CorCor (Both PS and PGS models correct - include X1:X2 interaction)
# All methods estimate Average Treatment Effect on the Treated (ATT/PATT)
# Comparing:
# 1. Unweighted DSM (dsmatch-master with bootstrap, GLM logit PS + linear outcome)
# 2. Unweighted PG matching (dsmatch-master with bootstrap, linear outcome model) 
# 3. Unweighted PS matching (dsmatch-master with bootstrap, GLM logit PS)
# 4. Survey-weighted PS full matching (MatchIt with marginaleffects, quasibinomial PS)
# 5. Survey-weighted DSM (Version 1 WDSM - Simplified with all updates:
#    quasibinomial PS + weighted LM + polynomial sieve + weighted standardization)
#
# Model Specification: CorCor
# - Both PS and PGS models correct (include X1:X2 interaction)

# ============================================================================
# Setup and Libraries
# ============================================================================
cat("\n============================================================\n")
cat("Loading required packages...\n")
cat("============================================================\n")

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(nnet)
library(MatchIt)
library(marginaleffects)
library(parallel)
library(doParallel)
library(foreach)
library(boot)
library(R.utils)  # For withTimeout

# Source required functions
cat("Sourcing custom functions...\n")

# Source ALL necessary dsmatch functions (not using devtools::load_all for HPC)
cat("Sourcing dsmatch functions...\n")
dsmatch_files <- c(
  "dsmatch-master/R/bisect.R",
  "dsmatch-master/R/is.lp.R",
  "dsmatch-master/R/is.ps.R", 
  "dsmatch-master/R/is.pg.R",
  "dsmatch-master/R/estforboot_covATT.R",
  "dsmatch-master/R/estforboot_dsATT.R",
  "dsmatch-master/R/estforboot_pgATT.R",
  "dsmatch-master/R/estforboot_psATT.R",
  "dsmatch-master/R/dsmatchATT.R"
)

for(file in dsmatch_files) {
  if(file.exists(file)) {
    source(file)
  } else {
    cat(sprintf("Warning: File %s not found\n", file))
  }
}

# Source WDSM functions
cat("Sourcing WDSM functions...\n")
wdsm_files <- c(
  "WDSM/R/wdsm_patt_prospective_v1_simplified.R",
  "WDSM/R/bootstrap_wdsm_final.R"
)

for(file in wdsm_files) {
  if(file.exists(file)) {
    source(file)
  } else {
    cat(sprintf("Warning: File %s not found\n", file))
  }
}

# ============================================================================
# Function to run a single replicate for a specific M value - CorCor only
# ============================================================================
run_single_replicate_M <- function(i.rep, data, true_patt, M, B, alpha) {
  
  # No time limit - let methods run to completion
  # Poor overlap may require more computation time
  
  tryCatch({
    # Source dsmatch functions inside the worker (for PSOCK compatibility)
    dsmatch_files <- c(
      "dsmatch-master/R/bisect.R",
      "dsmatch-master/R/is.lp.R",
      "dsmatch-master/R/is.ps.R",
      "dsmatch-master/R/is.pg.R",
      "dsmatch-master/R/estforboot_covATT.R",
      "dsmatch-master/R/estforboot_dsATT.R",
      "dsmatch-master/R/estforboot_pgATT.R",
      "dsmatch-master/R/estforboot_psATT.R",
      "dsmatch-master/R/dsmatchATT.R"
    )
    
    for(file in dsmatch_files) {
      if(file.exists(file)) {
        source(file)
      }
    }
    
    # Source WDSM functions inside the worker (for PSOCK compatibility)
    wdsm_files <- c(
      "WDSM/R/wdsm_patt_prospective_v1_simplified.R",
      "WDSM/R/bootstrap_wdsm_final.R"
    )
    
    for(file in wdsm_files) {
      if(file.exists(file)) {
        source(file)
      }
    }
    
    replicate_results <- list()
    
    # ============================================================
    # Data Preparation for Each Replicate
    # ============================================================
    set.seed(12345 + i.rep)
    
    # Sample from population using srswor
    s <- srswor(n = 1000, N = nrow(data))
    sample_data <- data[s == 1, ]
    
    # Extract components
    Y <- sample_data$Y
    A <- sample_data$A
    X <- as.matrix(sample_data[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    colnames(X) <- c("x1", "x2", "x3", "x4", "x5", "x6")
    
    # Calculate survey weights
    p_z <- mean(data$A)
    prob <- rep(1000 / nrow(data), 1000)
    w <- 1 / prob
    
    # Create survey design object
    sample_svy <- data.frame(
      Y = Y, 
      A = A, 
      X, 
      weights = w
    )
    design <- svydesign(ids = ~1, weights = ~weights, data = sample_svy)
    
    # ============================================================
    # Model Specification: CorCor
    # ============================================================
    # Both PS and PGS models correct (include X1:X2 interaction)
    ps_correct <- TRUE
    pgs_correct <- TRUE
    
    # ============================================================
    # Method 1: Unweighted DSM
    # ============================================================
    DSM_result <- tryCatch({
      # For DSM: PS uses X1:X2 interaction, PGS uses X1:X2 interaction
      X_dsm <- if (ps_correct) {
        cbind(X, X[,1] * X[,2])
      } else {
        X
      }
      
      # Outcome model matrix (for PGS)
      X_pgs <- if (pgs_correct) {
        cbind(X, X[,1] * X[,2])
      } else {
        X
      }
      
      colnames(X_dsm) <- if (ps_correct) {
        c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      colnames(X_pgs) <- if (pgs_correct) {
        c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      result <- withTimeout({
        dsmatchATT(
          Y = Y,
          Tr = A,
          X = X_dsm,
          X.out = X_pgs,  # Use appropriate matrix for outcome model
          M = M,
          B = B,
          estimand = "ATT",
          weight.mat = TRUE,
          m.type = 2,
          p.type = 1,
          alpha = alpha
        )
      }, timeout = 240, onTimeout = "error")
      
      list(
        method = "DSM",
        est = result$est,
        se = result$se,
        ci_lower = result$ci[1],
        ci_upper = result$ci[2]
      )
    }, error = function(e) {
      list(method = "DSM", est = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    replicate_results$DSM <- DSM_result
    
    # ============================================================
    # Method 2: Unweighted PG Matching
    # ============================================================
    PG_result <- tryCatch({
      # For PG matching: only use outcome model (PGS)
      X_pgs <- if (pgs_correct) {
        cbind(X, X[,1] * X[,2])
      } else {
        X
      }
      
      colnames(X_pgs) <- if (pgs_correct) {
        c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      result <- withTimeout({
        dsmatchATT(
          Y = Y,
          Tr = A,
          X = X_pgs,  # Use PGS matrix directly
          M = M,
          B = B,
          estimand = "ATT",
          weight.mat = TRUE,
          m.type = 1,  # PG matching only
          p.type = 0,  # No PS
          alpha = alpha
        )
      }, timeout = 240, onTimeout = "error")
      
      list(
        method = "PG",
        est = result$est,
        se = result$se,
        ci_lower = result$ci[1],
        ci_upper = result$ci[2]
      )
    }, error = function(e) {
      list(method = "PG", est = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    replicate_results$PG <- PG_result
    
    # ============================================================
    # Method 3: Unweighted PS Matching
    # ============================================================
    PS_result <- tryCatch({
      # For PS matching: only use propensity score model
      X_ps <- if (ps_correct) {
        cbind(X, X[,1] * X[,2])
      } else {
        X
      }
      
      colnames(X_ps) <- if (ps_correct) {
        c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      result <- withTimeout({
        dsmatchATT(
          Y = Y,
          Tr = A,
          X = X_ps,  # Use PS matrix
          M = M,
          B = B,
          estimand = "ATT",
          weight.mat = TRUE,
          m.type = 0,  # No outcome model
          p.type = 1,  # PS matching
          alpha = alpha
        )
      }, timeout = 240, onTimeout = "error")
      
      list(
        method = "PS",
        est = result$est,
        se = result$se,
        ci_lower = result$ci[1],
        ci_upper = result$ci[2]
      )
    }, error = function(e) {
      list(method = "PS", est = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    replicate_results$PS <- PS_result
    
    # ============================================================
    # Method 4: Survey-Weighted PS Full Matching
    # ============================================================
    PS_Full_result <- tryCatch({
      # Prepare data for MatchIt with interaction term if PS correct
      if (ps_correct) {
        sample_svy$x1_x2 <- sample_svy$x1 * sample_svy$x2
        ps_formula_matchit <- A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2
      } else {
        ps_formula_matchit <- A ~ x1 + x2 + x3 + x4 + x5 + x6
      }
      
      # Normalize weights
      w_original <- sample_svy$weights
      w_normalized <- w_original * length(w_original) / sum(w_original)
      sample_svy$sw <- w_normalized
      
      # PS full matching
      result <- withTimeout({
        m.out <- matchit(
          ps_formula_matchit,
          data = sample_svy,
          method = "full",
          distance = "glm",
          link = "logit",
          s.weights = sample_svy$sw,
          estimand = "ATT"
        )
        
        # Outcome regression with matched data
        m.data <- match.data(m.out)
        if (pgs_correct) {
          if(!"x1_x2" %in% names(m.data)) {
            m.data$x1_x2 <- m.data$x1 * m.data$x2
          }
          outcome_formula <- Y ~ A + x1 + x2 + x3 + x4 + x5 + x6 + x1_x2
        } else {
          outcome_formula <- Y ~ A + x1 + x2 + x3 + x4 + x5 + x6
        }
        
        fit <- lm(outcome_formula, data = m.data, weights = sw)
        
        # Bootstrap for SE
        boot_fun <- function(data, indices) {
          boot_data <- data[indices, ]
          boot_m.out <- matchit(
            ps_formula_matchit,
            data = boot_data,
            method = "full",
            distance = "glm",
            link = "logit",
            s.weights = boot_data$sw,
            estimand = "ATT"
          )
          boot_m.data <- match.data(boot_m.out)
          boot_fit <- lm(outcome_formula, data = boot_m.data, weights = sw)
          coef(boot_fit)["A"]
        }
        
        boot_res <- boot(sample_svy, boot_fun, R = B, parallel = "no")
        
        list(
          est = coef(fit)["A"],
          se = sd(boot_res$t, na.rm = TRUE),
          ci_lower = quantile(boot_res$t, probs = alpha/2, na.rm = TRUE),
          ci_upper = quantile(boot_res$t, probs = 1 - alpha/2, na.rm = TRUE)
        )
      }, timeout = 240, onTimeout = "error")
      
      list(
        method = "PS_Full",
        est = as.numeric(result$est),
        se = result$se,
        ci_lower = as.numeric(result$ci_lower),
        ci_upper = as.numeric(result$ci_upper)
      )
    }, error = function(e) {
      list(method = "PS_Full", est = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    replicate_results$PS_Full <- PS_Full_result
    
    # ============================================================
    # Method 5: Survey-Weighted DSM (WDSM v1_simplified)
    # ============================================================
    WDSM_result <- tryCatch({
      # WDSM v1_simplified now accepts formula parameters for flexible model specification
      # For CorCor: Both models are correct, so include interaction term
      X_wdsm <- cbind(X, X[,1] * X[,2])
      colnames(X_wdsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      
      # CorCor: Both models include interaction
      ps_formula_wdsm <- "A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2"
      pgs_formula_wdsm <- "Y ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2"
      
      sample_wdsm <- list(
        X = X_wdsm,  # X matrix with interaction term
        A = A,
        Y = Y,
        w = w_original
      )
      
      wdsm_result <- withTimeout({
        wdsm_patt_prospective_v1_simplified(
          sample = sample_wdsm,
          M = M,
          B = B,
          ps_formula = ps_formula_wdsm,   # Pass PS formula
          pgs_formula = pgs_formula_wdsm,  # Pass PGS formula
          show_progress = FALSE
        )
      }, timeout = 240, onTimeout = "error")
      
      list(
        method = "WDSM",
        est = wdsm_result$tau_hat,
        se = wdsm_result$se,
        ci_lower = wdsm_result$ci[1],
        ci_upper = wdsm_result$ci[2]
      )
    }, error = function(e) {
      list(method = "WDSM", est = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    replicate_results$WDSM <- WDSM_result
    
    # Add true value and other info
    replicate_results <- lapply(replicate_results, function(res) {
      c(res, list(
        true_patt = true_patt,
        bias = if(!is.na(res$est)) res$est - true_patt else NA,
        covers_true = if(!is.na(res$ci_lower) && !is.na(res$ci_upper)) {
          true_patt >= res$ci_lower && true_patt <= res$ci_upper
        } else {
          NA
        },
        M = M,
        model_spec = "CorCor"
      ))
    })
    
    return(replicate_results)
    
  }, error = function(e) {
    cat("Replicate", i.rep, "M=", M, "failed:", e$message, "\n")
    return(list(error = paste("Replicate", i.rep, "M=", M, "failed:", e$message)))
  })
}

# ============================================================================
# Wrapper function to run all M values for a single replicate - CorCor only
# ============================================================================
run_single_replicate <- function(i.rep, data, true_patt, B, alpha) {
  M_values <- c(5)  # Only M=5 for faster runtime
  results <- list()
  
  for (M in M_values) {
    results[[paste0("M", M, "_CorCor")]] <- run_single_replicate_M(i.rep, data, true_patt, M, B, alpha)
  }
  
  return(results)
}

# ============================================================================
# Main Script
# ============================================================================
cat("\n============================================================\n")
cat("COMPREHENSIVE PATT COMPARISON: M=5 Only, Model Spec: CorCor (Poor Overlap)\n")
cat("============================================================\n")

# Parameters
n.reps <- 1000
B <- 200
alpha <- 0.05
M_values <- c(5)  # Only M=5 for faster runtime

# Load population data
cat("Loading population data (Poor Overlap)...\n")
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_PoorOverlap_AllinOne_0118_2025

# Access scenario 1 data (poor overlap)
data <- data_sets[[1]]
cat(sprintf("Population size: %d\n", nrow(data)))

# Calculate true PATT (ground truth)
true_patt <- mean(data$Y1[data$A == 1] - data$Y0[data$A == 1])
cat(sprintf("True PATT: %.4f\n", true_patt))

# Setup parallel processing
n_cores <- min(30, detectCores() - 2)
cat(sprintf("\nSetting up parallel processing with %d cores...\n", n_cores))

# Use FORK cluster for memory efficiency (Mac/Linux only)
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

# Parallel computation with detailed error handling
cat(sprintf("\nRunning %d replicates for Model Spec: CorCor...\n", n.reps))

# Use error handling and combine strategy
batch_size <- 100
n_batches <- ceiling(n.reps / batch_size)

all_results <- list()

for (batch in 1:n_batches) {
  start_idx <- (batch - 1) * batch_size + 1
  end_idx <- min(batch * batch_size, n.reps)
  batch_indices <- start_idx:end_idx
  
  cat(sprintf("Processing batch %d/%d (replicates %d-%d)...\n", 
              batch, n_batches, start_idx, end_idx))
  
  batch_results <- foreach(i.rep = batch_indices,
                          .errorhandling = 'pass',
                          .maxcombine = batch_size) %dopar% {
    gc()  # Clean up memory
    run_single_replicate(i.rep, data, true_patt, B, alpha)
  }
  
  all_results <- c(all_results, batch_results)
  
  # Check for errors in batch
  errors <- sapply(batch_results, function(x) inherits(x, "simpleError"))
  if (any(errors)) {
    cat(sprintf("Warning: %d errors in batch %d\n", sum(errors), batch))
  }
  
  gc()  # Clean up memory after batch
}

# Stop cluster
stopCluster(cl)

cat("\n============================================================\n")
cat("All replicates completed. Processing results...\n")
cat("============================================================\n")

# Process results
summary_stats_all <- list()

for (M in M_values) {
  key <- paste0("M", M, "_CorCor")
  cat(sprintf("\nProcessing results for M=%d, Model Spec: CorCor...\n", M))
  
  # Extract results for this M value and model spec
  results_M <- lapply(all_results, function(x) {
    if (!is.null(x[[key]]) && !inherits(x[[key]], "simpleError")) {
      x[[key]]
    } else {
      NULL
    }
  })
  
  # Remove NULL entries
  results_M <- results_M[!sapply(results_M, is.null)]
  
  # Process each method
  methods <- c("DSM", "PG", "PS", "PS_Full", "WDSM")
  
  for (method in methods) {
    method_results <- lapply(results_M, function(x) x[[method]])
    
    # Extract estimates, SEs, and coverage
    estimates <- sapply(method_results, function(x) x$est)
    ses <- sapply(method_results, function(x) x$se)
    covers <- sapply(method_results, function(x) x$covers_true)
    
    # Remove NA values for statistics
    valid_idx <- !is.na(estimates)
    n_valid <- sum(valid_idx)
    n_failed <- sum(!valid_idx)
    
    if (n_valid > 0) {
      mean_est <- mean(estimates[valid_idx])
      mean_bias <- mean(estimates[valid_idx] - true_patt)
      rel_bias <- mean_bias / true_patt
      sd_est <- sd(estimates[valid_idx])
      mean_se <- mean(ses[valid_idx], na.rm = TRUE)
      coverage <- mean(covers[valid_idx], na.rm = TRUE)
      rmse <- sqrt(mean((estimates[valid_idx] - true_patt)^2))
      
      # CI width
      ci_widths <- sapply(method_results[valid_idx], function(x) {
        if(!is.na(x$ci_upper) && !is.na(x$ci_lower)) {
          x$ci_upper - x$ci_lower
        } else {
          NA
        }
      })
      mean_ci_width <- mean(ci_widths, na.rm = TRUE)
    } else {
      mean_est <- mean_bias <- rel_bias <- sd_est <- mean_se <- coverage <- rmse <- mean_ci_width <- NA
    }
    
    # Store summary statistics
    summary_stats_all[[paste0(method, "_M", M, "_CorCor")]] <- list(
      Method = method,
      M = M,
      Model_Spec = "CorCor",
      N_Valid = n_valid,
      N_Failed = n_failed,
      Mean_Estimate = mean_est,
      Mean_Bias = mean_bias,
      Relative_Bias = rel_bias,
      SD_Estimate = sd_est,
      Mean_SE = mean_se,
      SE_Ratio = if(!is.na(mean_se) && !is.na(sd_est) && sd_est > 0) mean_se/sd_est else NA,
      Coverage = coverage,
      RMSE = rmse,
      Mean_CI_Width = mean_ci_width,
      True_PATT = true_patt
    )
    
    cat(sprintf("  %s: Valid=%d, Failed=%d, Bias=%.4f, Rel.Bias=%.3f, SE=%.4f, Coverage=%.3f\n",
                method, n_valid, n_failed, mean_bias, rel_bias, mean_se, coverage))
  }
}

# Save results
cat("\n============================================================\n")
cat("Saving results...\n")
cat("============================================================\n")

save(all_results, summary_stats_all, true_patt, M_values,
     file = "comprehensive_patt_comparison_CorCor_M5_Pooroverlap_results.RData")

# Create summary table
summary_df <- do.call(rbind, lapply(summary_stats_all, function(x) {
  data.frame(
    Method = x$Method,
    M = x$M,
    Model_Spec = x$Model_Spec,
    N_Valid = x$N_Valid,
    N_Failed = x$N_Failed,
    Mean_Estimate = round(x$Mean_Estimate, 4),
    Mean_Bias = round(x$Mean_Bias, 4),
    Relative_Bias = round(x$Relative_Bias, 3),
    SD_Estimate = round(x$SD_Estimate, 4),
    Mean_SE = round(x$Mean_SE, 4),
    SE_Ratio = round(x$SE_Ratio, 3),
    Coverage = round(x$Coverage, 3),
    RMSE = round(x$RMSE, 4),
    Mean_CI_Width = round(x$Mean_CI_Width, 4)
  )
}))

# Print summary table
cat("\n============================================================\n")
cat("SUMMARY TABLE - Model Spec: CorCor (Poor Overlap)\n")
cat("============================================================\n")
print(summary_df)

# Save summary table
write.csv(summary_df, "comprehensive_patt_comparison_CorCor_M5_Pooroverlap_table.csv", row.names = FALSE)

cat("\n============================================================\n")
cat("Analysis complete! Results saved.\n")
cat("Files created:\n")
cat("  - comprehensive_patt_comparison_CorCor_M5_Pooroverlap_results.RData\n")
cat("  - comprehensive_patt_comparison_CorCor_M5_Pooroverlap_table.csv\n")
cat("============================================================\n")
