#!/usr/bin/env Rscript

# Test WDSM with SW_PSW-main Simulation Design
# This script tests Weighted Double Score Matching (WDSM) using the survey weighted
# simulation design from SW_PSW-main folder for both prospective and retrospective sampling

# Load required libraries
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

# Source necessary functions
source("WDSM/R/wdsmatchPATE_prospective.R")
source("WDSM/R/wdsmatchPATE_retrospective.R")
source("WDSM/R/wdsmatchPATT_prospective.R")
source("WDSM/R/wdsmatchPATT_retrospective.R")
source("WDSM/R/bootstrap_wdsm.R")
source("SW_PSW-main/Shared_PSW_MOM_CVR_WET_Function.R")
source("SW_PSW-main/EstSOD_Function.R")

# Set working directory
setwd(getwd())

# ==============================================================================
# SIMULATION PARAMETERS
# ==============================================================================
if (!exists("n_reps")) {
  n_reps <- 100  # Number of simulation replicates (reduce from 5000 for testing)
}
if (!exists("n_cores")) {
  n_cores <- 4   # Number of cores for parallel processing
}
set.seed(2024)

# ==============================================================================
# GENERATE SUPER POPULATION
# ==============================================================================
# We'll generate the super population data using the same structure as SW_PSW-main
N <- 1000000    # Total population size
n <- N * 0.005  # Sample size (0.5% of the population)
n_covar <- 7    # Number of covariates
n_strata <- 10  # Number of strata
n_cluster <- 20 # Number of clusters within each stratum
tau_strata <- 0.35
tau_cluster <- 0.15
min_prob <- 0.000

# Generate means for strata and clusters
mu_strata <- matrix(rnorm(n_strata * n_covar, mean = 0, sd = tau_strata), 
                    nrow = n_strata, ncol = n_covar)
mu_cluster <- matrix(rnorm(n_cluster * n_covar, mean = 0, sd = tau_cluster), 
                     nrow = n_cluster, ncol = n_covar)

# Generate covariates
cluster_l <- list()
strata_l <- list()
variable_l <- list()

for (variable in 1:n_covar) {
  for (strata in 1:n_strata) {
    for (cluster in 1:n_cluster) {
      data <- cbind(
        rep((strata - 1) * n_cluster + cluster, N / (n_strata * n_cluster)),
        rep(strata, N / (n_strata * n_cluster)),
        rnorm(N / (n_strata * n_cluster), 
              mean = mu_cluster[cluster, variable] + mu_strata[strata, variable])
      )
      colnames(data) <- c("Cluster", "Strata", paste("X", variable, sep = ""))
      cluster_l[[cluster]] <- data
    }
    strata_l[[strata]] <- do.call("rbind", cluster_l)
  }
  variable_l[[variable]] <- data.frame(do.call("rbind", strata_l))
}

# Combine all covariate data
data <- variable_l[[1]]
for (variable in 2:n_covar) {
  data <- cbind(data, variable_l[[variable]][, 3])
}

# Set column names
var_col <- paste("x", 1:n_covar, sep = "")
colnames(data) <- c("Cluster", "Strata", var_col)

# Generate propensity scores and treatment assignment
expit <- function(x) { exp(x) / (1 + exp(x)) }

# Propensity score model coefficients (good overlap)
a0 <- log(35 / 80)
a1 <- log(1.10)
a2 <- log(1.25)
a3 <- log(1.50)
a4 <- log(1.75)
a5 <- log(2.00)
a6 <- log(2.50)
a7 <- log(1.10)  # Interaction coefficient
delta_z <- 0.6

# Calculate propensity scores
formula <- a0 + delta_z * (
  a1 * data$x1 + a2 * data$x2 + a3 * data$x3 + a4 * data$x4 + 
  a5 * data$x5 + a6 * data$x6 + a7 * data$x1 * data$x2
)
data$prob_treat <- expit(formula)
data$z <- rbinom(N, 1, data$prob_treat)

# Generate outcomes
b0 <- 0.00
b1 <- 2.50
b2 <- -2.00
b3 <- 1.75
b4 <- -1.25
b5 <- 1.50
b6 <- 1.10
b70 <- 2.50
b71 <- 1.50
delta0 <- 0.3
delta1 <- 1
delta2 <- 0.2

# Potential outcomes
data$y0 <- b0 + delta0 * (
  b1 * data$x1 + b2 * data$x2 + b3 * data$x3 + 
  b4 * data$x4 + b5 * data$x5 + b6 * data$x6 + 
  b70 * data$x1 * data$x2
) + rnorm(N)

data$y1 <- data$y0 + delta1 + delta2 * (
  b1 * data$x1 + b2 * data$x2 + b3 * data$x3 + 
  b4 * data$x4 + b5 * data$x5 + b6 * data$x6 + 
  b71 * data$x1 * data$x2
) + rnorm(N)

# Observed outcome
data$y <- data$z * data$y1 + (1 - data$z) * data$y0

# Calculate true population parameters
es_sp <- data$prob_treat
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])
ato_sp <- sum(es_sp * (1 - es_sp) * data$y1) / sum(es_sp * (1 - es_sp)) - 
          sum(es_sp * (1 - es_sp) * data$y0) / sum(es_sp * (1 - es_sp))

cat("True Population Parameters:\n")
cat("ATE =", ate_sp, "\n")
cat("ATT =", att_sp, "\n")
cat("ATO =", ato_sp, "\n\n")

# ==============================================================================
# MAIN SIMULATION FUNCTION
# ==============================================================================
run_simulation <- function(i_rep, sampling_type = "prospective") {
  
  set.seed(i_rep)
  
  # ----------------------------------------------------------------------------
  # STEP 1: Create Sample
  # ----------------------------------------------------------------------------
  if (sampling_type == "prospective") {
    # Multi-stage sampling (same as SW_PSW-main)
    size1 <- rep(100000, 10)  # Population size per stratum
    size2 <- rep(5, 10)       # Number of clusters per stratum
    size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
               rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
               rep(250/5, 5), rep(150/5, 5))
    
    s <- mstage(data, stage = list("stratified", "cluster", ""), 
                varnames = list("Strata", "Cluster", "ones"), 
                size = list(size1, size2, size3), 
                method = list("", "srswor", "srswor"))
    
    sample <- getdata(data, s)[[3]]
    sample$s.wt <- 1 / sample$Prob  # Survey weights
    
  } else {  # retrospective sampling
    # Treatment-dependent sampling
    c0 <- log(0.005 / (1 - 0.005)) 
    c1 <- log(1.05)  
    c2 <- log(1.10)  
    c3 <- log(1.15)  
    c4 <- log(1.10) 
    c5 <- log(1.05) 
    c6 <- log(1.10) 
    delta_z_in_s <- log(0.9)
    
    formula_S <- c0 + delta_z_in_s * data$z + c1 * data$x1 + c2 * data$x2 +
      c3 * data$x3 + c4 * data$x4 + c5 * data$x5 + c6 * data$x6
    
    prob_S <- expit(formula_S)
    data$Prob <- prob_S
    data$S <- rbinom(N, 1, prob_S)
    sample <- data[data$S == 1, ]
    sample$s.wt <- 1 / sample$Prob  # Survey weights
  }
  
  # Add ID column
  data$ones <- 1
  data$id <- 1:nrow(data)
  sample$id <- sample$id
  
  # ----------------------------------------------------------------------------
  # STEP 2: Prepare Data for WDSM
  # ----------------------------------------------------------------------------
  Y <- sample$y
  A <- sample$z
  X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
  
  # For retrospective sampling, we need treatment-specific weights
  if (sampling_type == "retrospective") {
    # In retrospective design, weights depend on treatment
    # We already have s.wt = 1/P(S=1|X,Z)
    weights0 <- sample$s.wt  # For control units
    weights1 <- sample$s.wt  # For treated units
  } else {
    # In prospective design, weights don't depend on treatment
    weights <- sample$s.wt
  }
  
  # ----------------------------------------------------------------------------
  # STEP 3: Run WDSM Estimators
  # ----------------------------------------------------------------------------
  results <- list()
  
  if (sampling_type == "prospective") {
    # PATE estimation - Prospective
    wdsm_pate <- tryCatch({
      wdsmatchPATE_prospective(
        Y = Y, X = X, A = A, weights = weights,
        method = "dsm",
        model.ps = "logit",
        model.pg = "glm",
        M = 3,
        bias.correct = TRUE,
        varest = FALSE  # Turn off bootstrap for speed in simulation
      )
    }, error = function(e) {
      list(est.dsm = NA, est.ps = NA)
    })
    
    # PATT estimation - Prospective
    wdsm_patt <- tryCatch({
      wdsmatchPATT_prospective(
        Y = Y, X = X, A = A, weights = weights,
        method = "dsm",
        model.ps = "logit",
        model.pg = "glm",
        M = 3,
        bias.correct = TRUE,
        varest = FALSE
      )
    }, error = function(e) {
      list(est.dsm = NA, est.ps = NA)
    })
    
  } else {  # retrospective
    # PATE estimation - Retrospective
    wdsm_pate <- tryCatch({
      wdsmatchPATE_retrospective(
        Y = Y, X = X, A = A, 
        weights0 = weights0, weights1 = weights1,
        method = "dsm",
        model.ps = "logit",
        model.pg = "glm",
        M = 3,
        bias.correct = TRUE,
        varest = FALSE
      )
    }, error = function(e) {
      list(est.dsm = NA, est.ps = NA)
    })
    
    # PATT estimation - Retrospective
    wdsm_patt <- tryCatch({
      wdsmatchPATT_retrospective(
        Y = Y, X = X, A = A,
        weights0 = weights0, weights1 = weights1,
        method = "dsm",
        model.ps = "logit",
        model.pg = "glm",
        M = 3,
        bias.correct = TRUE,
        varest = FALSE
      )
    }, error = function(e) {
      list(est.dsm = NA, est.ps = NA)
    })
  }
  
  # ----------------------------------------------------------------------------
  # STEP 4: Run Comparison Methods (PSW)
  # ----------------------------------------------------------------------------
  # For comparison, run PSW estimator
  covariatesPS <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1:x2")
  covariatesOM <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1:x2")
  covariatesSMD <- c("x1", "x2", "x3", "x4", "x5", "x6")
  SW_Design <- ifelse(sampling_type == "prospective", "Independent", "Retrospective")
  
  psw_results <- tryCatch({
    EstSOD(sample, "s.wt", "z", "y", "W", SW_Design, 
           covariatesPS, covariatesOM, covariatesSMD, min_prob, 
           "Cluster", "Strata")
  }, error = function(e) {
    rep(NA, 72)  # EstSOD returns 72 values
  })
  
  # Extract PSW estimates
  psw_pate <- psw_results[1]  # First element is PATE
  psw_patt <- psw_results[2]  # Second element is PATT
  
  # ----------------------------------------------------------------------------
  # STEP 5: Store Results
  # ----------------------------------------------------------------------------
  results$sampling_type <- sampling_type
  results$rep <- i_rep
  
  # WDSM estimates
  results$wdsm_pate <- wdsm_pate$est.dsm
  results$wdsm_patt <- wdsm_patt$est.dsm
  results$wdsm_pate_ps <- wdsm_pate$est.ps  # PS-only matching
  results$wdsm_patt_ps <- wdsm_patt$est.ps
  
  # PSW estimates for comparison
  results$psw_pate <- psw_pate
  results$psw_patt <- psw_patt
  
  # True values
  results$ate_true <- ate_sp
  results$att_true <- att_sp
  
  return(results)
}

# ==============================================================================
# RUN SIMULATION
# ==============================================================================
if (!exists("RUN_SIMULATION") || RUN_SIMULATION == TRUE) {
  
cat("Starting WDSM Simulation with SW_PSW Design\n")
cat("Number of replications:", n_reps, "\n")
cat("Number of cores:", n_cores, "\n\n")

# Set up parallel processing
cl <- makeCluster(n_cores)
registerDoParallel(cl)

# Export necessary objects to cluster
clusterExport(cl, c("data", "N", "n", "ate_sp", "att_sp", "ato_sp", "min_prob",
                    "expit", "mstage", "getdata", "run_simulation",
                    "wdsmatchPATE_prospective", "wdsmatchPATE_retrospective",
                    "wdsmatchPATT_prospective", "wdsmatchPATT_retrospective",
                    "EstSOD", "PSW_Estimator", "PSW_SandwichVariance",
                    "MOM_Estimator", "MOM_SandwichVariance",
                    "CVR_Estimator", "CVR_SandwichVariance",
                    "WET_Estimator", "WET_SandwichVariance",
                    "SMD_Calculator", "calc_pooled_sd",
                    "bootstrap_wdsm_pate_prospective", "bootstrap_wdsm_pate_retrospective",
                    "bootstrap_wdsm_patt_prospective", "bootstrap_wdsm_patt_retrospective",
                    "compute_weighted_balance"))

# Also load required packages on each worker
clusterEvalQ(cl, {
  library(survey)
  library(sampling)
  library(Matching)
  library(MASS)
})

# Run prospective sampling simulations
cat("Running prospective sampling simulations...\n")
results_prospective <- foreach(i = 1:n_reps, .combine = rbind, .errorhandling = 'remove') %dopar% {
  tryCatch({
    run_simulation(i, "prospective")
  }, error = function(e) {
    cat("Error in prospective simulation", i, ":", e$message, "\n")
    NULL
  })
}

# Run retrospective sampling simulations  
cat("Running retrospective sampling simulations...\n")
results_retrospective <- foreach(i = 1:n_reps, .combine = rbind, .errorhandling = 'remove') %dopar% {
  tryCatch({
    run_simulation(i, "retrospective")
  }, error = function(e) {
    cat("Error in retrospective simulation", i, ":", e$message, "\n")
    NULL
  })
}

# Stop cluster
stopCluster(cl)

# ==============================================================================
# ANALYZE RESULTS
# ==============================================================================
analyze_results <- function(results, sampling_type) {
  cat("\n", toupper(sampling_type), "SAMPLING RESULTS\n")
  cat(rep("=", 60), "\n", sep = "")
  
  # Remove NA values
  results <- results[!is.na(results$wdsm_pate), ]
  n_valid <- nrow(results)
  cat("Valid replications:", n_valid, "out of", n_reps, "\n\n")
  
  # PATE Results
  cat("POPULATION AVERAGE TREATMENT EFFECT (PATE)\n")
  cat(rep("-", 40), "\n", sep = "")
  
  # WDSM
  # Convert to numeric if needed
  results$wdsm_pate <- as.numeric(results$wdsm_pate)
  results$ate_true <- as.numeric(results$ate_true)
  
  bias_wdsm_pate <- mean(results$wdsm_pate - results$ate_true)
  rel_bias_wdsm_pate <- bias_wdsm_pate / results$ate_true[1] * 100
  rmse_wdsm_pate <- sqrt(mean((results$wdsm_pate - results$ate_true)^2))
  
  cat("WDSM (Double Score Matching):\n")
  cat("  Mean estimate:", mean(results$wdsm_pate), "\n")
  cat("  Bias:", bias_wdsm_pate, "\n")
  cat("  Relative bias:", round(rel_bias_wdsm_pate, 2), "%\n")
  cat("  RMSE:", rmse_wdsm_pate, "\n")
  cat("  SD:", sd(results$wdsm_pate), "\n\n")
  
  # PSW for comparison
  if (!all(is.na(results$psw_pate))) {
    results$psw_pate <- as.numeric(results$psw_pate)
    bias_psw_pate <- mean(results$psw_pate - results$ate_true, na.rm = TRUE)
    rel_bias_psw_pate <- bias_psw_pate / results$ate_true[1] * 100
    rmse_psw_pate <- sqrt(mean((results$psw_pate - results$ate_true)^2, na.rm = TRUE))
    
    cat("PSW (Propensity Score Weighting):\n")
    cat("  Mean estimate:", mean(results$psw_pate, na.rm = TRUE), "\n")
    cat("  Bias:", bias_psw_pate, "\n")
    cat("  Relative bias:", round(rel_bias_psw_pate, 2), "%\n")
    cat("  RMSE:", rmse_psw_pate, "\n")
    cat("  SD:", sd(results$psw_pate, na.rm = TRUE), "\n\n")
  }
  
  # PATT Results
  cat("POPULATION AVERAGE TREATMENT EFFECT ON TREATED (PATT)\n")
  cat(rep("-", 40), "\n", sep = "")
  
  # WDSM
  # Convert to numeric if needed
  results$wdsm_patt <- as.numeric(results$wdsm_patt)
  results$att_true <- as.numeric(results$att_true)
  
  bias_wdsm_patt <- mean(results$wdsm_patt - results$att_true)
  rel_bias_wdsm_patt <- bias_wdsm_patt / results$att_true[1] * 100
  rmse_wdsm_patt <- sqrt(mean((results$wdsm_patt - results$att_true)^2))
  
  cat("WDSM (Double Score Matching):\n")
  cat("  Mean estimate:", mean(results$wdsm_patt), "\n")
  cat("  Bias:", bias_wdsm_patt, "\n")
  cat("  Relative bias:", round(rel_bias_wdsm_patt, 2), "%\n")
  cat("  RMSE:", rmse_wdsm_patt, "\n")
  cat("  SD:", sd(results$wdsm_patt), "\n\n")
  
  # PSW for comparison
  if (!all(is.na(results$psw_patt))) {
    results$psw_patt <- as.numeric(results$psw_patt)
    bias_psw_patt <- mean(results$psw_patt - results$att_true, na.rm = TRUE)
    rel_bias_psw_patt <- bias_psw_patt / results$att_true[1] * 100
    rmse_psw_patt <- sqrt(mean((results$psw_patt - results$att_true)^2, na.rm = TRUE))
    
    cat("PSW (Propensity Score Weighting):\n")
    cat("  Mean estimate:", mean(results$psw_patt, na.rm = TRUE), "\n")
    cat("  Bias:", bias_psw_patt, "\n")
    cat("  Relative bias:", round(rel_bias_psw_patt, 2), "%\n")
    cat("  RMSE:", rmse_psw_patt, "\n")
    cat("  SD:", sd(results$psw_patt, na.rm = TRUE), "\n\n")
  }
  
  # Return summary statistics
  return(list(
    sampling_type = sampling_type,
    n_valid = n_valid,
    wdsm_pate_bias = bias_wdsm_pate,
    wdsm_pate_rel_bias = rel_bias_wdsm_pate,
    wdsm_patt_bias = bias_wdsm_patt,
    wdsm_patt_rel_bias = rel_bias_wdsm_patt,
    psw_pate_bias = ifelse(all(is.na(results$psw_pate)), NA, bias_psw_pate),
    psw_pate_rel_bias = ifelse(all(is.na(results$psw_pate)), NA, rel_bias_psw_pate),
    psw_patt_bias = ifelse(all(is.na(results$psw_patt)), NA, bias_psw_patt),
    psw_patt_rel_bias = ifelse(all(is.na(results$psw_patt)), NA, rel_bias_psw_patt)
  ))
}

# Analyze results
results_prospective_df <- as.data.frame(results_prospective)
results_retrospective_df <- as.data.frame(results_retrospective)

summary_prospective <- analyze_results(results_prospective_df, "prospective")
summary_retrospective <- analyze_results(results_retrospective_df, "retrospective")

# ==============================================================================
# SAVE RESULTS
# ==============================================================================
save(results_prospective_df, results_retrospective_df,
     summary_prospective, summary_retrospective,
     file = paste0("WDSM_SW_PSW_simulation_results_", Sys.Date(), ".RData"))

cat("\nSimulation completed! Results saved.\n")

# Create summary table
summary_table <- data.frame(
  Sampling = c("Prospective", "Retrospective"),
  WDSM_PATE_RelBias = c(summary_prospective$wdsm_pate_rel_bias, 
                        summary_retrospective$wdsm_pate_rel_bias),
  WDSM_PATT_RelBias = c(summary_prospective$wdsm_patt_rel_bias,
                        summary_retrospective$wdsm_patt_rel_bias),
  PSW_PATE_RelBias = c(summary_prospective$psw_pate_rel_bias,
                       summary_retrospective$psw_pate_rel_bias),
  PSW_PATT_RelBias = c(summary_prospective$psw_patt_rel_bias,
                       summary_retrospective$psw_patt_rel_bias)
)

cat("\nSUMMARY TABLE (Relative Bias %)\n")
print(round(summary_table, 2))

} # End of RUN_SIMULATION check 