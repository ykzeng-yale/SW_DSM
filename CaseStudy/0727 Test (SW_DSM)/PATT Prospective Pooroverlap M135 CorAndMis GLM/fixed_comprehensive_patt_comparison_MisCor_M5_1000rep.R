#!/usr/bin/env Rscript
# ============================================================================
# COMPREHENSIVE PATT COMPARISON: MisCor (Poor Overlap) - 1000 REPLICATES
# With proper relative efficiency calculation (PS as reference)
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
model_spec <- "MisCor"  # PS misspecified, PGS correct
n_reps <- 1000  # Changed from 100 to 1000
M <- 5  # Only for WDSM; unweighted methods use 1:1 matching
B <- 200
alpha <- 0.05
n_cores <- 10
batch_size <- 50  # Increased batch size for 1000 reps

# ============================================================================
# Load Data GLOBALLY (before parallel processing)
# ============================================================================
cat("Loading population data GLOBALLY (Poor Overlap)...\n")
if (file.exists("/gpfs/gibbs/project/tong/yz2324/")) {
  # On HPC
  data_path <- "/gpfs/gibbs/project/tong/yz2324/patt_1000rep_20250822/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData"
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
# Source Functions GLOBALLY
# ============================================================================
cat("Sourcing functions GLOBALLY...\n")

# Source dsmatch functions
if (file.exists("/gpfs/gibbs/project/tong/yz2324/")) {
  # On HPC - use absolute paths
  source("/gpfs/gibbs/project/tong/yz2324/patt_1000rep_20250822/dsmatch-master/R/dsmatchATT.R")
  source("/gpfs/gibbs/project/tong/yz2324/patt_1000rep_20250822/dsmatch-master/R/dsmatchATT.utils.R")
  source("/gpfs/gibbs/project/tong/yz2324/patt_1000rep_20250822/WDSM/R/wdsm_patt_prospective_v1_simplified.R")
} else {
  # Local - use relative paths
  source("dsmatch-master/R/dsmatchATT.R")
  source("dsmatch-master/R/dsmatchATT.utils.R")
  source("WDSM/R/wdsm_patt_prospective_v1_simplified.R")
}

# ============================================================================
# Main Simulation Function
# ============================================================================
run_single_replicate <- function(rep_id, data_full, true_patt, M, B, alpha, model_spec) {
  set.seed(2025 + rep_id)
  
  cat(sprintf("\n=== Replicate %d ===\n", rep_id))
  
  data_full$ones <- 1  # Add ones column for sampling
  # Multi-stage sampling (matching original simulation)
  N1 <- 50
  n1 <- 25
  N2_values <- round(runif(N1, 100, 500))
  n2_values <- round(0.2 * N2_values)
  N3_values <- matrix(NA, sum(N2_values), 1)
  index <- 0
  for (i in 1:N1) {
    for (j in 1:N2_values[i]) {
      index <- index + 1
      N3_values[index] <- round(runif(1, 5, 50))
    }
  }
  n3_values <- round(0.1 * N3_values)
  
  # Create size list for mstage
  size1 <- n1
  size2 <- n2_values
  size3 <- as.vector(n3_values)
  
  # Perform multi-stage sampling
  suppressWarnings({
    sample_indices <- mstage(
      data_full,
      stage = list("stratified", "cluster", ""),
      varnames = list("Strata", "Cluster", "ones"),
      size = list(size1, size2, size3),
      method = list("", "srswor", "srswor")
    )
  })
  
  # Get sampled data
  sample_data <- getdata(data_full, sample_indices)
  sample_data$s.wt <- 1 / sample_data$Prob
  
  # Extract variables  
  n_sample <- nrow(sample_data)
  n_treated <- sum(sample_data$z)
  n_control <- sum(1 - sample_data$z)
  
  cat(sprintf("  Sample size: %d (Treated: %d, Control: %d)\n", 
              n_sample, n_treated, n_control))
  
  # Prepare data
  Y <- sample_data$y
  A <- sample_data$z
  sw <- sample_data$s.wt
  
  # For MisCor: PS misspecified (no interaction), PGS correct (with interaction)
  # X for PS model (no interaction)
  X_no_interaction <- cbind(
    sample_data$x1,
    sample_data$x2,
    sample_data$x3,
    sample_data$x4,
    sample_data$x5,
    sample_data$x6
  )
  colnames(X_no_interaction) <- c("x1", "x2", "x3", "x4", "x5", "x6")
  
  # lp.pg for PG model (with interaction)
  X_with_interaction <- cbind(
    sample_data$x1,
    sample_data$x2,
    sample_data$x3,
    sample_data$x4,
    sample_data$x5,
    sample_data$x6,
    sample_data$x1 * sample_data$x2
  )
  colnames(X_with_interaction) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
  
  # Initialize results
  method_results <- list()
  
  # ===========================================================================
  # Method 1: DSM (Unweighted)
  # ===========================================================================
  cat("  Running DSM...\n")
  tryCatch({
    dsm_result <- dsmatchATT(
      Y = Y,
      X = X_no_interaction,  # PS model without interaction
      A = A,
      method = "dsm",
      model.ps = "logit",
      model.pg = "linpred",
      lp.pg = X_with_interaction,  # PG model with interaction
      varest = TRUE,
      boots = B,
      mc = FALSE,
      ncpus = 1,
      replace = TRUE  # Use 1:1 matching with replacement, not M=5
    )
    
    method_results$DSM <- list(
      est = dsm_result$ATT,
      se = dsm_result$se.ATT
    )
  }, error = function(e) {
    cat("    DSM error:", as.character(e), "\n")
    method_results$DSM <- list(est = NA, se = NA)
  })
  
  # ===========================================================================
  # Method 2: PG (Unweighted)
  # ===========================================================================
  cat("  Running PG...\n")
  tryCatch({
    pg_result <- dsmatchATT(
      Y = Y,
      X = X_no_interaction,  # PS model without interaction (for PG, only lp.pg matters)
      A = A,
      method = "pg",
      model.ps = "logit",
      model.pg = "linpred",
      lp.pg = X_with_interaction,  # PG model with interaction (correct)
      varest = TRUE,
      boots = B,
      mc = FALSE,
      ncpus = 1,
      replace = TRUE  # Use 1:1 matching with replacement, not M=5
    )
    
    method_results$PG <- list(
      est = pg_result$ATT,
      se = pg_result$se.ATT
    )
  }, error = function(e) {
    cat("    PG error:", as.character(e), "\n")
    method_results$PG <- list(est = NA, se = NA)
  })
  
  # ===========================================================================
  # Method 3: PS (Unweighted)
  # ===========================================================================
  cat("  Running PS...\n")
  tryCatch({
    ps_result <- dsmatchATT(
      Y = Y,
      X = X_no_interaction,  # PS model without interaction (misspecified)
      A = A,
      method = "ps",
      model.ps = "logit",
      model.pg = "linpred",
      lp.pg = X_with_interaction,  # PG model not used for PS
      varest = TRUE,
      boots = B,
      mc = FALSE,
      ncpus = 1,
      replace = TRUE  # Use 1:1 matching with replacement, not M=5
    )
    
    method_results$PS <- list(
      est = ps_result$ATT,
      se = ps_result$se.ATT
    )
  }, error = function(e) {
    cat("    PS error:", as.character(e), "\n")
    method_results$PS <- list(est = NA, se = NA)
  })
  
  # ===========================================================================
  # Method 4: PS Full (Survey-Weighted)
  # ===========================================================================
  cat("  Running PS Full...\n")
  tryCatch({
    # Normalize weights
    sw_norm <- sw * n_sample / sum(sw)
    
    # PS Full matching with misspecified PS
    ps_formula <- A ~ x1 + x2 + x3 + x4 + x5 + x6  # Misspecified PS (no interaction)
    ps_full_obj <- matchit(
      ps_formula,
      data = sample_data,
      method = "full",
      distance = "glm",
      link = "logit",
      estimand = "ATT",
      weights = sw_norm
    )
    
    # Extract matched data
    matched_data <- match.data(ps_full_obj, weights = "sw")
    
    # Outcome model with FULL interaction terms (correct specification)
    outcome_formula <- y ~ A * (x1 + x2 + x3 + x4 + x5 + x6 + x1:x2)
    fit <- lm(outcome_formula, data = matched_data, weights = sw)
    
    # Calculate PATT with bootstrap variance
    boot_fn <- function(data, indices) {
      boot_data <- data[indices, ]
      boot_fit <- lm(outcome_formula, data = boot_data, weights = sw)
      coef(boot_fit)["A"]
    }
    
    boot_res <- boot(matched_data, boot_fn, R = B)
    
    method_results$PS_Full <- list(
      est = coef(fit)["A"],
      se = sd(boot_res$t)
    )
  }, error = function(e) {
    cat("    PS Full error:", as.character(e), "\n")
    method_results$PS_Full <- list(est = NA, se = NA)
  })
  
  # ===========================================================================
  # Method 5: WDSM
  # ===========================================================================
  cat("  Running WDSM...\n")
  tryCatch({
    # For MisCor: PS misspecified (no interaction), PGS correct (with interaction)
    ps_formula_wdsm <- A ~ x1 + x2 + x3 + x4 + x5 + x6  # No interaction
    pgs_formula_wdsm <- y ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2  # With interaction
    
    # Prepare WDSM data
    sample_data$x1_x2 <- sample_data$x1 * sample_data$x2
    
    wdsm_result <- wdsm_patt_prospective_v1_simplified(
      sample_data,
      M = M,
      B = B,
      ps_formula = ps_formula_wdsm,
      pgs_formula = pgs_formula_wdsm,
      show_progress = FALSE
    )
    
    method_results$WDSM <- list(
      est = wdsm_result$tau_hat,
      se = wdsm_result$SE
    )
  }, error = function(e) {
    cat("    WDSM error:", as.character(e), "\n")
    method_results$WDSM <- list(est = NA, se = NA)
  })
  
  return(list(
    rep = rep_id,
    n_sample = n_sample,
    n_treated = n_treated,
    n_control = n_control,
    DSM = method_results$DSM,
    PG = method_results$PG,
    PS = method_results$PS,
    PS_Full = method_results$PS_Full,
    WDSM = method_results$WDSM
  ))
}

# ============================================================================
# Run Parallel Simulation
# ============================================================================
cat("\n============================================================\n")
cat("Starting parallel simulation...\n")
cat(sprintf("Model specification: %s\n", model_spec))
cat(sprintf("Replicates: %d\n", n_reps))
cat(sprintf("Cores: %d\n", n_cores))
cat(sprintf("Batch size: %d\n", batch_size))
cat("============================================================\n")

# Set up parallel backend
cl <- makeCluster(n_cores, type = "FORK", outfile = "")
registerDoParallel(cl)

# Run simulation with batching
results_list <- foreach(
  rep_batch = split(1:n_reps, ceiling(seq_along(1:n_reps)/batch_size)),
  .combine = 'c',
  .errorhandling = 'pass',
  .maxcombine = batch_size,
  .export = c("data_full", "true_patt", "dsmatchATT", "is.lp", "is.ps", 
              "is.model", "matchATT", "wdsm_patt_prospective_v1_simplified",
              "M", "B", "alpha", "model_spec")
) %dopar% {
  batch_results <- list()
  for (i in seq_along(rep_batch)) {
    rep_id <- rep_batch[i]
    batch_results[[i]] <- run_single_replicate(rep_id, data_full, true_patt, 
                                              M, B, alpha, model_spec)
  }
  batch_results
}

# Stop cluster
stopCluster(cl)

# ============================================================================
# Process Results
# ============================================================================
cat("\n============================================================\n")
cat("Processing results...\n")
cat("============================================================\n")

# Extract results
method_results <- list(
  DSM = list(
    estimates = sapply(results_list, function(x) x$DSM$est),
    ses = sapply(results_list, function(x) x$DSM$se)
  ),
  PG = list(
    estimates = sapply(results_list, function(x) x$PG$est),
    ses = sapply(results_list, function(x) x$PG$se)
  ),
  PS = list(
    estimates = sapply(results_list, function(x) x$PS$est),
    ses = sapply(results_list, function(x) x$PS$se)
  ),
  PS_Full = list(
    estimates = sapply(results_list, function(x) x$PS_Full$est),
    ses = sapply(results_list, function(x) x$PS_Full$se)
  ),
  WDSM = list(
    estimates = sapply(results_list, function(x) x$WDSM$est),
    ses = sapply(results_list, function(x) x$WDSM$se)
  )
)

# Calculate performance metrics
z_crit <- qnorm(1 - alpha/2)
performance_metrics <- list()

for (method in names(method_results)) {
  ests <- method_results[[method]]$estimates
  ses <- method_results[[method]]$ses
  
  # Filter valid results
  valid <- !is.na(ests) & !is.na(ses)
  ests_valid <- ests[valid]
  ses_valid <- ses[valid]
  n_valid <- sum(valid)
  
  if (n_valid > 0) {
    # Bias and relative bias
    bias <- mean(ests_valid - true_patt)
    rel_bias <- bias / true_patt
    
    # Coverage (using Wald CI for all methods including WDSM)
    ci_lower <- ests_valid - z_crit * ses_valid
    ci_upper <- ests_valid + z_crit * ses_valid
    coverage <- mean((ci_lower <= true_patt) & (ci_upper >= true_patt))
    
    # Empirical variance
    emp_var <- var(ests_valid)
    
    # Average estimated variance
    avg_est_var <- mean(ses_valid^2)
    
    # SE ratio (average SE / empirical SE)
    se_ratio <- sqrt(avg_est_var) / sqrt(emp_var)
    
    performance_metrics[[method]] <- list(
      n_valid = n_valid,
      bias = bias,
      rel_bias = rel_bias,
      coverage = coverage,
      emp_var = emp_var,
      avg_est_var = avg_est_var,
      se_ratio = se_ratio
    )
  } else {
    performance_metrics[[method]] <- list(
      n_valid = 0,
      bias = NA,
      rel_bias = NA,
      coverage = NA,
      emp_var = NA,
      avg_est_var = NA,
      se_ratio = NA
    )
  }
}

# Calculate relative efficiency (using PS as reference)
ps_emp_var <- performance_metrics$PS$emp_var
for (method in names(performance_metrics)) {
  if (performance_metrics[[method]]$n_valid > 0) {
    performance_metrics[[method]]$rel_efficiency <- ps_emp_var / performance_metrics[[method]]$emp_var
  } else {
    performance_metrics[[method]]$rel_efficiency <- NA
  }
}

# ============================================================================
# Display Results
# ============================================================================
cat("\n============================================================\n")
cat(sprintf("FINAL RESULTS - %s (Poor Overlap)\n", model_spec))
cat("============================================================\n")
cat(sprintf("True PATT: %.4f\n", true_patt))
cat(sprintf("Successful replicates: %d / %d\n", 
            length(results_list[!sapply(results_list, is.null)]), n_reps))

cat("\nPerformance Metrics:\n")
cat("------------------------------------------------------------\n")
cat(sprintf("%-10s %6s %8s %8s %8s %8s %8s\n", 
            "Method", "Valid", "RelBias", "Coverage", "SE_Ratio", "RelEff", "EmpVar"))
cat("------------------------------------------------------------\n")

for (method in names(performance_metrics)) {
  m <- performance_metrics[[method]]
  cat(sprintf("%-10s %6d %8.3f %8.3f %8.3f %8.3f %8.4f\n",
              method, m$n_valid, m$rel_bias, m$coverage, m$se_ratio, 
              m$rel_efficiency, m$emp_var))
}

# ============================================================================
# Save Results
# ============================================================================
runtime <- proc.time()[3]
output_file <- sprintf("comprehensive_patt_comparison_%s_M5_%drep_Pooroverlap_results.RData", 
                      model_spec, n_reps)

save(method_results, results_list, performance_metrics, true_patt, M, runtime, 
     file = output_file)

cat("\n============================================================\n")
cat(sprintf("Results saved to: %s\n", output_file))
cat(sprintf("Total runtime: %.2f minutes\n", runtime/60))
cat("============================================================\n")
