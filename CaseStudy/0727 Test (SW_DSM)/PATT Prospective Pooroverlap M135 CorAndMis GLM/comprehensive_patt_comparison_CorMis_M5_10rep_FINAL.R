#!/usr/bin/env Rscript
# ============================================================================
# COMPREHENSIVE PATT COMPARISON: CorCor (Poor Overlap) - FINAL VERSION
# Based on working retrospective structure
# ============================================================================

cat("\n============================================================\n")
cat("Loading required packages...\n")
cat("============================================================\n")

suppressPackageStartupMessages({
  library(sampling)
  library(MatchIt)
  library(marginaleffects)
  library(survey)
  library(boot)
  library(R.utils)
  library(parallel)
  library(doParallel)
  library(foreach)
})

# ============================================================================
# Fixed Parameters
# ============================================================================
model_spec <- "CorMis"  # PS correct, PGS misspecified
n_reps <- 10
M <- 5
B <- 200
alpha <- 0.05
n_cores <- 10
batch_size <- 5

# ============================================================================
# Load Data GLOBALLY (before parallel processing)
# ============================================================================
cat("Loading population data GLOBALLY (Poor Overlap)...\n")
if (file.exists("/gpfs/gibbs/project/tong/yz2324/")) {
  # On HPC
  data_path <- "/gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_FINAL_20250820/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData"
} else {
  # Local
  data_path <- "SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData"
}
load(data_path)
data_full <- SuperPopGen_PoorOverlap_AllinOne_0118_2025[[1]]
cat(sprintf("Population size: %d\n", nrow(data_full)))

# Calculate true PATT GLOBALLY
true_patt <- mean(data_full$y1[data_full$z == 1] - data_full$y0[data_full$z == 1])
cat(sprintf("True PATT: %.4f\n", true_patt))

# ============================================================================
# Source Functions GLOBALLY (before parallel processing)
# ============================================================================
cat("Sourcing dsmatch functions GLOBALLY...\n")
if (file.exists("/gpfs/gibbs/project/tong/yz2324/")) {
  # On HPC - use absolute path
  base_dir <- "/gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_FINAL_20250820/"
  source(paste0(base_dir, "dsmatch-master/R/bisect.R"))
  source(paste0(base_dir, "dsmatch-master/R/is.lp.R"))
  source(paste0(base_dir, "dsmatch-master/R/is.ps.R"))
  source(paste0(base_dir, "dsmatch-master/R/is.pg.R"))
  source(paste0(base_dir, "dsmatch-master/R/estforboot_covATT.R"))
  source(paste0(base_dir, "dsmatch-master/R/estforboot_dsATT.R"))
  source(paste0(base_dir, "dsmatch-master/R/estforboot_pgATT.R"))
  source(paste0(base_dir, "dsmatch-master/R/estforboot_psATT.R"))
  source(paste0(base_dir, "dsmatch-master/R/dsmatchATT.R"))
} else {
  # Local
  source("dsmatch-master/R/bisect.R")
  source("dsmatch-master/R/is.lp.R")
  source("dsmatch-master/R/is.ps.R")
  source("dsmatch-master/R/is.pg.R")
  source("dsmatch-master/R/estforboot_covATT.R")
  source("dsmatch-master/R/estforboot_dsATT.R")
  source("dsmatch-master/R/estforboot_pgATT.R")
  source("dsmatch-master/R/estforboot_psATT.R")
  source("dsmatch-master/R/dsmatchATT.R")
}

# ============================================================================
# Main Simulation Function
# ============================================================================
run_simulation <- function(batch_indices) {
  
  batch_results <- list()
  
  for (idx in seq_along(batch_indices)) {
    i.rep <- batch_indices[idx]
    set.seed(12345 + i.rep)
    
    cat("  Replicate", i.rep, "\n")
    
    # Source WDSM inside worker (like retrospective)
    if (file.exists("/gpfs/gibbs/project/tong/yz2324/")) {
      base_dir <- "/gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_FINAL_20250820/"
      source(paste0(base_dir, "WDSM/R/wdsm_patt_prospective_v1_simplified.R"))
    } else {
      source("WDSM/R/wdsm_patt_prospective_v1_simplified.R")
    }
    
    # Sample from population using srswor
    s <- srswor(n = 1000, N = nrow(data_full))
    sample_data <- data_full[s == 1, ]
    
    # Calculate survey weights
    sample_data$inclusion_prob <- s[s == 1] * (1000 / nrow(data_full))
    sample_data$survey_weight <- 1 / sample_data$inclusion_prob
    
    # Extract variables (using lowercase names from data)
    Y <- sample_data$y
    X <- as.matrix(sample_data[, c("x1", "x2", "x3", "x4", "x5", "x6")])
    A <- sample_data$z
    w_original <- sample_data$survey_weight
    
    # Normalize weights for MatchIt
    w_normalized <- w_original * length(w_original) / sum(w_original)
    
    n_sample <- nrow(sample_data)
    n_treated <- sum(A == 1)
    n_control <- sum(A == 0)
    
    rep_results <- list(
      rep = i.rep,
      n_sample = n_sample,
      n_treated = n_treated,
      n_control = n_control
    )
    
    # Check if we have enough units
    if (n_treated < 2 || n_control < M * 2) {
      warning(paste("Replicate", i.rep, "has too few units for matching"))
      rep_results$DSM <- list(est = NA, se = NA)
      rep_results$PG <- list(est = NA, se = NA)
      rep_results$PS <- list(est = NA, se = NA)
      rep_results$PS_Full <- list(est = NA, se = NA)
      rep_results$WDSM <- list(est = NA, se = NA)
      batch_results[[idx]] <- rep_results
      next
    }
    
    # CorMis: PS correct (with interaction), PGS misspecified (no interaction)
    X_with_interaction <- cbind(X, X[,1] * X[,2])
    colnames(X_with_interaction) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
    
    # Method 1: DSM (Unweighted) - PS correct, PGS misspecified
    tryCatch({
      dsm_result <- withTimeout({
        dsmatchATT(
          Y = Y,
          X = X_with_interaction,  # PS correct (with interaction)
          A = A,
          method = "dsm",
          model.ps = "logit",
          model.pg = "linpred",
          lp.pg = X,  # PGS misspecified (no interaction)
          varest = TRUE,
          boots = B,
          mc = FALSE,
          ncpus = 1,
          M = M
        )
      }, timeout = 180, onTimeout = "error")
      
      rep_results$DSM <- list(
        est = dsm_result$est.ds,
        se = sqrt(dsm_result$bootvar[1,1])
      )
    }, error = function(e) {
      cat("    DSM error:", as.character(e), "\n")
      rep_results$DSM <- list(est = NA, se = NA)
    })
    
    # Method 2: PG (Unweighted) - PGS misspecified
    tryCatch({
      pg_result <- withTimeout({
        dsmatchATT(
          Y = Y,
          X = X,  # No interaction for PGS
          A = A,
          method = "pg",
          model.pg = "linpred",
          lp.pg = X,  # PGS misspecified (no interaction)
          varest = TRUE,
          boots = B,
          mc = FALSE,
          ncpus = 1,
          M = M
        )
      }, timeout = 180, onTimeout = "error")
      
      rep_results$PG <- list(
        est = pg_result$est.pg,
        se = sqrt(pg_result$bootvar[1,1])
      )
    }, error = function(e) {
      cat("    PG error:", as.character(e), "\n")
      rep_results$PG <- list(est = NA, se = NA)
    })
    
    # Method 3: PS (Unweighted) - PS correct
    tryCatch({
      ps_result <- withTimeout({
        dsmatchATT(
          Y = Y,
          X = X_with_interaction,  # PS correct (with interaction)
          A = A,
          method = "ps",
          model.ps = "logit",
          varest = TRUE,
          boots = B,
          mc = FALSE,
          ncpus = 1,
          M = M
        )
      }, timeout = 180, onTimeout = "error")
      
      rep_results$PS <- list(
        est = ps_result$est.ps,
        se = sqrt(ps_result$bootvar[1,1])
      )
    }, error = function(e) {
      cat("    PS error:", as.character(e), "\n")
      rep_results$PS <- list(est = NA, se = NA)
    })
    
    # Method 4: PS Full (Survey-weighted)
    tryCatch({
      match_data <- data.frame(
        Y = Y,
        A = A,
        x1 = X[,1],
        x2 = X[,2],
        x3 = X[,3],
        x4 = X[,4],
        x5 = X[,5],
        x6 = X[,6],
        sw = w_normalized
      )
      
      # CorMis: PS model CORRECT - include interaction
      m_ps_full <- matchit(
        A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2,  # PS correct
        data = match_data,
        method = "full",
        distance = "glm",
        link = "logit",
        s.weights = ~ sw,
        estimand = "ATT"
      )
      
      md <- match.data(m_ps_full)
      
      # Outcome model always correctly specified
      fit <- lm(Y ~ A * (x1 + x2 + x3 + x4 + x5 + x6 + x1:x2), 
                data = md,
                weights = weights)
      
      att_result <- avg_comparisons(
        fit,
        variables = "A",
        vcov = ~subclass,
        newdata = subset(md, A == 1),
        wts = "sw"
      )
      
      rep_results$PS_Full <- list(
        est = att_result$estimate[1],
        se = att_result$std.error[1]
      )
    }, error = function(e) {
      cat("    PS Full error:", as.character(e), "\n")
      rep_results$PS_Full <- list(est = NA, se = NA)
    })
    
    # Method 5: WDSM (Survey-weighted)
    tryCatch({
      # WDSM always gets X with interaction term (like Good Overlap script)
      X_wdsm <- cbind(X, X[,1] * X[,2])
      colnames(X_wdsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      
      # CorMis: PS correct, PGS misspecified
      ps_formula_wdsm <- "A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2"  # PS correct
      pgs_formula_wdsm <- "Y ~ x1 + x2 + x3 + x4 + x5 + x6"  # PGS misspecified (no interaction)
      
      sample_wdsm <- list(
        X = X_wdsm,
        A = A,
        Y = Y,
        w = w_original
      )
      
      wdsm_result <- withTimeout({
        wdsm_patt_prospective_v1_simplified(
          sample = sample_wdsm,
          M = M,
          B = B,  # CRITICAL: Must include B parameter!
          ps_formula = ps_formula_wdsm,
          pgs_formula = pgs_formula_wdsm,
          show_progress = FALSE
        )
      }, timeout = 240, onTimeout = "error")
      
      rep_results$WDSM <- list(
        est = wdsm_result$tau_hat,
        se = wdsm_result$SE
      )
    }, error = function(e) {
      cat("    WDSM error:", as.character(e), "\n")
      rep_results$WDSM <- list(est = NA, se = NA)
    })
    
    batch_results[[idx]] <- rep_results
    gc()
  }
  
  return(batch_results)
}

# ============================================================================
# Setup Parallel Processing
# ============================================================================
cat("\nSetting up parallel processing with", n_cores, "cores...\n")
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log_CorCor.txt")
registerDoParallel(cl)

cat("Starting simulation...\n")
cat("  Replicates:", n_reps, "\n")
cat("  Batch size:", batch_size, "\n")
cat("  Bootstrap iterations:", B, "\n\n")

# Create batches
batches <- split(1:n_reps, ceiling(seq_along(1:n_reps) / batch_size))

# Run simulation with proper exports
start_time <- Sys.time()

results_list <- foreach(
  batch = batches,
  .combine = 'c',
  .errorhandling = 'pass',
  .packages = c('sampling', 'MatchIt', 'marginaleffects', 'survey', 'boot', 'R.utils'),
  .export = c('run_simulation', 'data_full', 'true_patt', 'M', 'B', 'alpha', 'model_spec',
              'dsmatchATT', 'bisect', 'is.ps', 'is.pg', 'is.lp',
              'estforboot_dsATT', 'estforboot_psATT',
              'estforboot_pgATT', 'estforboot_covATT')
) %dopar% {
  run_simulation(batch)
}

stopCluster(cl)

end_time <- Sys.time()
runtime <- difftime(end_time, start_time, units = "mins")

# ============================================================================
# Process Results
# ============================================================================
cat("\n============================================================\n")
cat("All replicates completed. Processing results...\n")
cat("============================================================\n")

# Extract results
method_results <- list(
  DSM = list(estimates = numeric(), ses = numeric()),
  PG = list(estimates = numeric(), ses = numeric()),
  PS = list(estimates = numeric(), ses = numeric()),
  PS_Full = list(estimates = numeric(), ses = numeric()),
  WDSM = list(estimates = numeric(), ses = numeric())
)

for (result in results_list) {
  if (!is.null(result)) {
    for (method in names(method_results)) {
      if (!is.null(result[[method]])) {
        if (!is.na(result[[method]]$est)) {
          method_results[[method]]$estimates <- c(method_results[[method]]$estimates, result[[method]]$est)
          method_results[[method]]$ses <- c(method_results[[method]]$ses, result[[method]]$se)
        }
      }
    }
  }
}

# Calculate summary statistics
cat(sprintf("\nProcessing results for M=%d, Model Spec: %s...\n", M, model_spec))

for (method in names(method_results)) {
  estimates <- method_results[[method]]$estimates
  ses <- method_results[[method]]$ses
  
  n_valid <- length(estimates)
  n_failed <- n_reps - n_valid
  
  if (n_valid > 0) {
    mean_est <- mean(estimates)
    mean_bias <- mean(estimates - true_patt)
    rel_bias <- mean_bias / true_patt
    emp_se <- sd(estimates)
    mean_se <- mean(ses)
    
    # Coverage
    ci_lower <- estimates - qnorm(1 - alpha/2) * ses
    ci_upper <- estimates + qnorm(1 - alpha/2) * ses
    coverage <- mean(ci_lower <= true_patt & ci_upper >= true_patt)
    
    cat(sprintf("  %s: Valid=%d, Failed=%d, Bias=%.4f, Rel.Bias=%.3f, SE=%.4f, Coverage=%.3f\n",
                method, n_valid, n_failed, mean_bias, rel_bias, mean_se, coverage))
  } else {
    cat(sprintf("  %s: Valid=%d, Failed=%d, Bias=NA, Rel.Bias=NA, SE=NA, Coverage=NA\n",
                method, 0, n_failed))
  }
}

# ============================================================================
# Save Results
# ============================================================================
cat("\n============================================================\n")
cat("Saving results...\n")
cat("============================================================\n")

output_file <- sprintf("comprehensive_patt_comparison_%s_M5_10rep_Pooroverlap_FINAL_results.RData", model_spec)
save(results_list, method_results, true_patt, runtime, M, file = output_file)

cat("\n============================================================\n")
cat("Analysis complete! Results saved.\n")
cat(sprintf("File: %s\n", output_file))
cat(sprintf("Runtime: %.2f minutes\n", runtime))
cat("============================================================\n")
