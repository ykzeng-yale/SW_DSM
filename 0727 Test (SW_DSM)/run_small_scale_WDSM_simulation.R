# Small Scale WDSM Simulation with Complete Analysis
# This runs a small simulation with proper standard errors and coverage analysis

cat("=====================================\n")
cat("SMALL SCALE WDSM SIMULATION\n")
cat("=====================================\n\n")

# Set parameters for small scale simulation
n_reps <- 20  # Small number of replications
n_cores <- 2  # Use only 2 cores
n_boot <- 50  # Reduced bootstrap samples for speed

# Record start time
start_time <- Sys.time()

cat("Simulation parameters:\n")
cat("- Replications:", n_reps, "\n")
cat("- Bootstrap samples:", n_boot, "\n")
cat("- Cores:", n_cores, "\n")
cat("- Start time:", format(start_time, "%Y-%m-%d %H:%M:%S"), "\n\n")

# Source all necessary functions
cat("Loading required libraries and functions...\n")
suppressPackageStartupMessages({
  library(survey)
  library(doParallel)
  library(foreach)
  library(data.table)
  library(sampling)
  library(MatchIt)
  library(Hmisc)
  library(MASS)
  library(boot)
  library(magrittr)
})

# Source WDSM functions
source("WDSM/R/wdsmatchPATE_prospective.R")
source("WDSM/R/wdsmatchPATE_retrospective.R")
source("WDSM/R/wdsmatchPATT_prospective.R")
source("WDSM/R/wdsmatchPATT_retrospective.R")
source("WDSM/R/bootstrap_wdsm.R")

# Source SW_PSW functions
source("SW_PSW-main/Shared_PSW_MOM_CVR_WET_Function.R")
source("SW_PSW-main/EstSOD_Function.R")

# Generate super population
cat("\nGenerating super population...\n")
source("SW_PSW-main/Super_Population_GoodOvelap.R")

# Calculate true parameters
es_sp <- data$prob_treat
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])
ato_sp <- sum(es_sp * (1 - es_sp) * data$y1) / sum(es_sp * (1 - es_sp)) - 
          sum(es_sp * (1 - es_sp) * data$y0) / sum(es_sp * (1 - es_sp))

cat("True Population Parameters:\n")
cat("ATE =", round(ate_sp, 4), "\n")
cat("ATT =", round(att_sp, 4), "\n")
cat("ATO =", round(ato_sp, 4), "\n\n")

# Define sampling parameters (from SW_PSW design)
nc <- 50  # Total number of clusters (5 per stratum × 10 strata)
# Size per cluster for each stratum
size3 <- c(rep(850 / 5, 5), rep(750 / 5, 5), rep(700 / 5, 5), rep(650 / 5, 5), 
           rep(600 / 5, 5), rep(400 / 5, 5), rep(350 / 5, 5), rep(300 / 5, 5), 
           rep(250 / 5, 5), rep(150 / 5, 5))
ns <- size3[1]  # Use first stratum's cluster size for simplicity

# Run simulation function with bootstrap SEs
run_simulation_with_se <- function(rep_id, sampling_type) {
  set.seed(2024 + rep_id)
  
  tryCatch({
    # Draw sample (following SW_PSW design)
    if (sampling_type == "prospective") {
      # Multi-stage sampling: first sample clusters from strata, then units from clusters
      size1 <- rep(100000, 10)  # Population size per stratum
      size2 <- rep(5, 10)       # Number of clusters per stratum
      
      sample_data <- mstage(data, stage = list("stratum", "cluster", ""), 
                           varnames = list("stratumid", "clusterid", "id"),
                           size = list(size1, size2, size3), 
                           method = list("srswor", "srswor", "srswor"))
      sample_indices <- getdata(data, sample_data)[[2]]
    } else {
      # Retrospective sampling (outcome-dependent)
      temp_data <- data
      temp_data$prob_select <- expit(temp_data$prob_select_coef[1] + 
                                     temp_data$prob_select_coef[2] * temp_data$y)
      
      size1 <- rep(100000, 10)  # Population size per stratum
      size2 <- rep(5, 10)       # Number of clusters per stratum
      
      sample_data <- mstage(temp_data, stage = list("stratum", "cluster", ""), 
                           varnames = list("stratumid", "clusterid", "id"),
                           size = list(size1, size2, size3), 
                           method = list("srswor", "srswor", "systematic"),
                           pik = list(inclusionprobabilities(rep(1, 10), 10),
                                     by(temp_data$prob_select, 
                                        list(temp_data$stratum, temp_data$cluster), mean),
                                     temp_data$prob_select))
      sample_indices <- getdata(temp_data, sample_data)[[2]]
    }
    
    # Get sampled data
    sampled_data <- data[sample_indices, ]
    
    # Calculate weights
    if (sampling_type == "prospective") {
      sampled_data$wt <- 1 / sampled_data$Prob
    } else {
      sampled_data$wt <- 1 / (sampled_data$Prob * sampled_data$prob_select)
    }
    
    # Prepare data for WDSM
    Y <- sampled_data$y
    X <- as.matrix(sampled_data[, c("x1", "x2", "x3", "x4", "x5", "x6", "x7")])
    A <- sampled_data$z
    weights <- sampled_data$wt
    
    # Run WDSM with bootstrap
    if (sampling_type == "prospective") {
      # PATE
      wdsm_pate_result <- wdsmatchPATE_prospective(
        Y = Y, X = X, A = A, weights = weights,
        method = "double", ps = "fitted", boot = TRUE, nboot = n_boot
      )
      
      # PATT
      wdsm_patt_result <- wdsmatchPATT_prospective(
        Y = Y, X = X, A = A, weights = weights,
        method = "double", ps = "fitted", boot = TRUE, nboot = n_boot
      )
    } else {
      # PATE
      wdsm_pate_result <- wdsmatchPATE_retrospective(
        Y = Y, X = X, A = A, weights = weights,
        method = "double", ps = "fitted", boot = TRUE, nboot = n_boot
      )
      
      # PATT
      wdsm_patt_result <- wdsmatchPATT_retrospective(
        Y = Y, X = X, A = A, weights = weights,
        method = "double", ps = "fitted", boot = TRUE, nboot = n_boot
      )
    }
    
    # Run PSW for comparison
    design <- svydesign(ids = ~clusterid, weights = ~wt, data = sampled_data)
    psw_results <- tryCatch({
      EstSOD(design)
    }, error = function(e) {
      list(PATE = list(`W.PS` = NA, se = NA),
           PATT = list(`W.PS` = NA, se = NA))
    })
    
    # Return results
    return(data.frame(
      sampling_type = sampling_type,
      rep = rep_id,
      # WDSM results
      wdsm_pate = wdsm_pate_result$estimate,
      wdsm_pate_se = wdsm_pate_result$se,
      wdsm_patt = wdsm_patt_result$estimate,
      wdsm_patt_se = wdsm_patt_result$se,
      # PSW results
      psw_pate = psw_results$PATE$`W.PS`[[1]],
      psw_pate_se = psw_results$PATE$se[[1]],
      psw_patt = psw_results$PATT$`W.PS`[[1]],
      psw_patt_se = psw_results$PATT$se[[1]],
      # True values
      ate_true = ate_sp,
      att_true = att_sp
    ))
    
  }, error = function(e) {
    cat("Error in", sampling_type, "simulation", rep_id, ":", e$message, "\n")
    return(NULL)
  })
}

# Set up parallel processing
cl <- makeCluster(n_cores)
registerDoParallel(cl)

# Export necessary objects to cluster
clusterEvalQ(cl, {
  suppressPackageStartupMessages({
    library(survey)
    library(sampling)
    library(MatchIt)
    library(MASS)
    library(boot)
  })
})

clusterExport(cl, c("data", "N", "n", "nc", "ns", "size3", "ate_sp", "att_sp", "ato_sp", 
                    "expit", "mstage", "getdata", "inclusionprobabilities",
                    "run_simulation_with_se",
                    "wdsmatchPATE_prospective", "wdsmatchPATE_retrospective",
                    "wdsmatchPATT_prospective", "wdsmatchPATT_retrospective",
                    "EstSOD", "PSW_Estimator", "PSW_SandwichVariance",
                    "MOM_Estimator", "MOM_SandwichVariance",
                    "CVR_Estimator", "CVR_SandwichVariance",
                    "WET_Estimator", "WET_SandwichVariance",
                    "SMD_Calculator", "calc_pooled_sd", "n_boot"))

# Run prospective sampling simulations
cat("Running prospective sampling simulations...\n")
results_prospective <- foreach(i = 1:n_reps, .combine = rbind, .errorhandling = 'remove') %dopar% {
  run_simulation_with_se(i, "prospective")
}

# Run retrospective sampling simulations  
cat("Running retrospective sampling simulations...\n")
results_retrospective <- foreach(i = 1:n_reps, .combine = rbind, .errorhandling = 'remove') %dopar% {
  run_simulation_with_se(i, "retrospective")
}

# Stop cluster
stopCluster(cl)

# Calculate coverage
calc_coverage <- function(estimates, ses, true_value, alpha = 0.05) {
  z_crit <- qnorm(1 - alpha/2)
  lower <- estimates - z_crit * ses
  upper <- estimates + z_crit * ses
  coverage <- mean(lower <= true_value & upper >= true_value, na.rm = TRUE)
  return(coverage * 100)
}

# Analyze results
cat("\n\n=====================================\n")
cat("SIMULATION RESULTS\n")
cat("=====================================\n\n")

# Prospective results
cat("PROSPECTIVE SAMPLING (n =", nrow(results_prospective), "valid replications)\n")
cat(paste(rep("-", 50), collapse=""), "\n")

if (nrow(results_prospective) > 0) {
  # PATE
  cat("\nPATE (True value =", round(ate_sp, 4), ")\n")
  
  # WDSM
  wdsm_pate_bias <- mean(results_prospective$wdsm_pate - ate_sp, na.rm = TRUE)
  wdsm_pate_rel_bias <- (wdsm_pate_bias / ate_sp) * 100
  wdsm_pate_coverage <- calc_coverage(results_prospective$wdsm_pate, 
                                      results_prospective$wdsm_pate_se, ate_sp)
  
  cat("  WDSM: Bias =", round(wdsm_pate_bias, 4), 
      "(", round(wdsm_pate_rel_bias, 2), "%),",
      "Coverage =", round(wdsm_pate_coverage, 1), "%\n")
  
  # PSW
  if (!all(is.na(results_prospective$psw_pate))) {
    psw_pate_bias <- mean(results_prospective$psw_pate - ate_sp, na.rm = TRUE)
    psw_pate_rel_bias <- (psw_pate_bias / ate_sp) * 100
    psw_pate_coverage <- calc_coverage(results_prospective$psw_pate[!is.na(results_prospective$psw_pate_se)], 
                                       results_prospective$psw_pate_se[!is.na(results_prospective$psw_pate_se)], 
                                       ate_sp)
    
    cat("  PSW:  Bias =", round(psw_pate_bias, 4), 
        "(", round(psw_pate_rel_bias, 2), "%),",
        "Coverage =", round(psw_pate_coverage, 1), "%\n")
  }
  
  # PATT
  cat("\nPATT (True value =", round(att_sp, 4), ")\n")
  
  # WDSM
  wdsm_patt_bias <- mean(results_prospective$wdsm_patt - att_sp, na.rm = TRUE)
  wdsm_patt_rel_bias <- (wdsm_patt_bias / att_sp) * 100
  wdsm_patt_coverage <- calc_coverage(results_prospective$wdsm_patt, 
                                      results_prospective$wdsm_patt_se, att_sp)
  
  cat("  WDSM: Bias =", round(wdsm_patt_bias, 4), 
      "(", round(wdsm_patt_rel_bias, 2), "%),",
      "Coverage =", round(wdsm_patt_coverage, 1), "%\n")
  
  # PSW
  if (!all(is.na(results_prospective$psw_patt))) {
    psw_patt_bias <- mean(results_prospective$psw_patt - att_sp, na.rm = TRUE)
    psw_patt_rel_bias <- (psw_patt_bias / att_sp) * 100
    psw_patt_coverage <- calc_coverage(results_prospective$psw_patt[!is.na(results_prospective$psw_patt_se)], 
                                       results_prospective$psw_patt_se[!is.na(results_prospective$psw_patt_se)], 
                                       att_sp)
    
    cat("  PSW:  Bias =", round(psw_patt_bias, 4), 
        "(", round(psw_patt_rel_bias, 2), "%),",
        "Coverage =", round(psw_patt_coverage, 1), "%\n")
  }
}

# Retrospective results
cat("\n\nRETROSPECTIVE SAMPLING (n =", nrow(results_retrospective), "valid replications)\n")
cat(paste(rep("-", 50), collapse=""), "\n")

if (nrow(results_retrospective) > 0) {
  # PATE
  cat("\nPATE (True value =", round(ate_sp, 4), ")\n")
  
  # WDSM
  wdsm_pate_bias <- mean(results_retrospective$wdsm_pate - ate_sp, na.rm = TRUE)
  wdsm_pate_rel_bias <- (wdsm_pate_bias / ate_sp) * 100
  wdsm_pate_coverage <- calc_coverage(results_retrospective$wdsm_pate, 
                                      results_retrospective$wdsm_pate_se, ate_sp)
  
  cat("  WDSM: Bias =", round(wdsm_pate_bias, 4), 
      "(", round(wdsm_pate_rel_bias, 2), "%),",
      "Coverage =", round(wdsm_pate_coverage, 1), "%\n")
  
  # PSW
  if (!all(is.na(results_retrospective$psw_pate))) {
    psw_pate_bias <- mean(results_retrospective$psw_pate - ate_sp, na.rm = TRUE)
    psw_pate_rel_bias <- (psw_pate_bias / ate_sp) * 100
    psw_pate_coverage <- calc_coverage(results_retrospective$psw_pate[!is.na(results_retrospective$psw_pate_se)], 
                                       results_retrospective$psw_pate_se[!is.na(results_retrospective$psw_pate_se)], 
                                       ate_sp)
    
    cat("  PSW:  Bias =", round(psw_pate_bias, 4), 
        "(", round(psw_pate_rel_bias, 2), "%),",
        "Coverage =", round(psw_pate_coverage, 1), "%\n")
  }
  
  # PATT
  cat("\nPATT (True value =", round(att_sp, 4), ")\n")
  
  # WDSM
  wdsm_patt_bias <- mean(results_retrospective$wdsm_patt - att_sp, na.rm = TRUE)
  wdsm_patt_rel_bias <- (wdsm_patt_bias / att_sp) * 100
  wdsm_patt_coverage <- calc_coverage(results_retrospective$wdsm_patt, 
                                      results_retrospective$wdsm_patt_se, att_sp)
  
  cat("  WDSM: Bias =", round(wdsm_patt_bias, 4), 
      "(", round(wdsm_patt_rel_bias, 2), "%),",
      "Coverage =", round(wdsm_patt_coverage, 1), "%\n")
  
  # PSW
  if (!all(is.na(results_retrospective$psw_patt))) {
    psw_patt_bias <- mean(results_retrospective$psw_patt - att_sp, na.rm = TRUE)
    psw_patt_rel_bias <- (psw_patt_bias / att_sp) * 100
    psw_patt_coverage <- calc_coverage(results_retrospective$psw_patt[!is.na(results_retrospective$psw_patt_se)], 
                                       results_retrospective$psw_patt_se[!is.na(results_retrospective$psw_patt_se)], 
                                       att_sp)
    
    cat("  PSW:  Bias =", round(psw_patt_bias, 4), 
        "(", round(psw_patt_rel_bias, 2), "%),",
        "Coverage =", round(psw_patt_coverage, 1), "%\n")
  }
}

# Save results
save(results_prospective, results_retrospective, 
     file = paste0("small_scale_WDSM_results_", Sys.Date(), ".RData"))

# End time
end_time <- Sys.time()
duration <- difftime(end_time, start_time, units = "mins")

cat("\n\n=====================================\n")
cat("SIMULATION COMPLETED\n")
cat("=====================================\n")
cat("Duration:", round(duration, 2), "minutes\n")
cat("Results saved to:", paste0("small_scale_WDSM_results_", Sys.Date(), ".RData"), "\n\n")

cat("Key findings:\n")
cat("- Coverage rates should be close to 95% for valid confidence intervals\n")
cat("- Lower relative bias indicates better unbiased estimation\n")
cat("- This small scale simulation provides initial validation of the methods\n") 