# Final Small Scale WDSM Simulation
# This version correctly handles the WDSM function arguments

cat("=====================================\n")
cat("FINAL SMALL SCALE WDSM SIMULATION\n")
cat("=====================================\n\n")

# Set parameters
n_reps <- 10
sample_size <- 5000
set.seed(2024)

# Record start time
start_time <- Sys.time()

cat("Simulation parameters:\n")
cat("- Replications:", n_reps, "\n")
cat("- Sample size:", sample_size, "\n\n")

# Load libraries
suppressPackageStartupMessages({
  library(survey)
  library(sampling)
  library(MatchIt)
  library(MASS)
})

# Source WDSM functions
source("WDSM/R/wdsmatchPATE_prospective.R")
source("WDSM/R/wdsmatchPATE_retrospective.R")
source("WDSM/R/wdsmatchPATT_prospective.R")
source("WDSM/R/wdsmatchPATT_retrospective.R")

# Source SW_PSW functions
source("SW_PSW-main/Shared_PSW_MOM_CVR_WET_Function.R")
source("SW_PSW-main/EstSOD_Function.R")

# Helper functions
expit <- function(x) { 1 / (1 + exp(-x)) }

# Generate super population
cat("Generating super population...\n")
source("SW_PSW-main/Super_Population_GoodOvelap.R")

# Calculate true parameters
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])

cat("True Population Parameters:\n")
cat("ATE =", round(ate_sp, 4), "\n")
cat("ATT =", round(att_sp, 4), "\n\n")

# Simulation function
run_simulation <- function(rep_id, sampling_type) {
  set.seed(2024 + rep_id)
  
  tryCatch({
    # Sample data
    if (sampling_type == "prospective") {
      # Simple random sampling
      sample_idx <- sample(1:nrow(data), sample_size, replace = FALSE)
      sampled_data <- data[sample_idx, ]
      sampled_data$wt <- nrow(data) / sample_size
    } else {
      # Retrospective sampling
      prob_select <- expit(-1 + 0.5 * data$y)
      sample_idx <- sample(1:nrow(data), sample_size, 
                          replace = FALSE, prob = prob_select)
      sampled_data <- data[sample_idx, ]
      sampled_data$wt <- (1 / prob_select[sample_idx]) * (nrow(data) / sample_size)
    }
    
    # Normalize weights
    sampled_data$wt <- sampled_data$wt * nrow(sampled_data) / sum(sampled_data$wt)
    
    # Prepare data - ensure numeric
    Y <- as.numeric(sampled_data$y)
    X <- as.matrix(sampled_data[, c("x1", "x2", "x3", "x4", "x5", "x6", "x7")])
    # Ensure X is numeric
    storage.mode(X) <- "double"
    A <- as.numeric(sampled_data$z)
    weights <- as.numeric(sampled_data$wt)
    
    # Run WDSM
    if (sampling_type == "prospective") {
      # PATE
      wdsm_pate <- tryCatch({
        result <- wdsmatchPATE_prospective(
          Y = Y, X = X, A = A, weights = weights,
          method = "ps", ps = "fitted", boot = FALSE
        )
        result$estimate
      }, error = function(e) NA)
      
      # PATT
      wdsm_patt <- tryCatch({
        result <- wdsmatchPATT_prospective(
          Y = Y, X = X, A = A, weights = weights,
          method = "ps", ps = "fitted", boot = FALSE
        )
        result$estimate
      }, error = function(e) NA)
      
    } else {
      # For retrospective, we need weights0 and weights1
      # Use the same weights for simplicity
      weights0 <- weights
      weights1 <- weights
      
      # PATE
      wdsm_pate <- tryCatch({
        result <- wdsmatchPATE_retrospective(
          Y = Y, X = X, A = A, 
          weights0 = weights0, weights1 = weights1,
          method = "ps", ps = "fitted", boot = FALSE
        )
        result$estimate
      }, error = function(e) NA)
      
      # PATT
      wdsm_patt <- tryCatch({
        result <- wdsmatchPATT_retrospective(
          Y = Y, X = X, A = A, 
          weights0 = weights0, weights1 = weights1,
          method = "ps", ps = "fitted", boot = FALSE
        )
        result$estimate
      }, error = function(e) NA)
    }
    
    # Run PSW
    sampled_data$clusterid <- 1:nrow(sampled_data)
    design <- svydesign(ids = ~clusterid, weights = ~wt, data = sampled_data)
    psw_results <- tryCatch({
      EstSOD(design)
    }, error = function(e) {
      list(PATE = list(`W.PS` = NA),
           PATT = list(`W.PS` = NA))
    })
    
    # Return results
    return(data.frame(
      sampling_type = sampling_type,
      rep = rep_id,
      wdsm_pate = wdsm_pate,
      wdsm_patt = wdsm_patt,
      psw_pate = as.numeric(psw_results$PATE$`W.PS`[[1]]),
      psw_patt = as.numeric(psw_results$PATT$`W.PS`[[1]]),
      ate_true = ate_sp,
      att_true = att_sp
    ))
    
  }, error = function(e) {
    cat("Error in", sampling_type, "simulation", rep_id, ":", e$message, "\n")
    return(data.frame(
      sampling_type = sampling_type,
      rep = rep_id,
      wdsm_pate = NA,
      wdsm_patt = NA,
      psw_pate = NA,
      psw_patt = NA,
      ate_true = ate_sp,
      att_true = att_sp
    ))
  })
}

# Run simulations
cat("Running simulations...\n")
results <- rbind(
  do.call(rbind, lapply(1:n_reps, function(i) run_simulation(i, "prospective"))),
  do.call(rbind, lapply(1:n_reps, function(i) run_simulation(i, "retrospective")))
)

# Analyze results
cat("\n=====================================\n")
cat("SIMULATION RESULTS\n")
cat("=====================================\n\n")

# Function to calculate metrics
calc_summary <- function(data, method_col, true_col) {
  valid <- !is.na(data[[method_col]])
  if (sum(valid) == 0) return(NULL)
  
  estimates <- data[[method_col]][valid]
  true_value <- data[[true_col]][1]
  
  bias <- mean(estimates - true_value)
  rel_bias <- (bias / true_value) * 100
  rmse <- sqrt(mean((estimates - true_value)^2))
  
  return(list(
    mean_est = mean(estimates),
    bias = bias,
    rel_bias = rel_bias,
    rmse = rmse,
    n_valid = sum(valid)
  ))
}

# Summary by sampling type
for (stype in c("prospective", "retrospective")) {
  sdata <- results[results$sampling_type == stype, ]
  
  cat(toupper(stype), "SAMPLING RESULTS\n")
  cat(paste(rep("-", 40), collapse=""), "\n\n")
  
  # PATE
  cat("PATE (True value =", round(ate_sp, 4), ")\n")
  
  # WDSM
  wdsm_pate <- calc_summary(sdata, "wdsm_pate", "ate_true")
  if (!is.null(wdsm_pate)) {
    cat("  WDSM:\n")
    cat("    Mean estimate:", round(wdsm_pate$mean_est, 4), "\n")
    cat("    Relative bias:", round(wdsm_pate$rel_bias, 2), "%\n")
    cat("    RMSE:", round(wdsm_pate$rmse, 4), "\n")
    cat("    Valid reps:", wdsm_pate$n_valid, "/", n_reps, "\n\n")
  }
  
  # PSW
  psw_pate <- calc_summary(sdata, "psw_pate", "ate_true")
  if (!is.null(psw_pate)) {
    cat("  PSW:\n")
    cat("    Mean estimate:", round(psw_pate$mean_est, 4), "\n")
    cat("    Relative bias:", round(psw_pate$rel_bias, 2), "%\n")
    cat("    RMSE:", round(psw_pate$rmse, 4), "\n")
    cat("    Valid reps:", psw_pate$n_valid, "/", n_reps, "\n\n")
  }
  
  # PATT
  cat("PATT (True value =", round(att_sp, 4), ")\n")
  
  # WDSM
  wdsm_patt <- calc_summary(sdata, "wdsm_patt", "att_true")
  if (!is.null(wdsm_patt)) {
    cat("  WDSM:\n")
    cat("    Mean estimate:", round(wdsm_patt$mean_est, 4), "\n")
    cat("    Relative bias:", round(wdsm_patt$rel_bias, 2), "%\n")
    cat("    RMSE:", round(wdsm_patt$rmse, 4), "\n")
    cat("    Valid reps:", wdsm_patt$n_valid, "/", n_reps, "\n\n")
  }
  
  # PSW
  psw_patt <- calc_summary(sdata, "psw_patt", "att_true")
  if (!is.null(psw_patt)) {
    cat("  PSW:\n")
    cat("    Mean estimate:", round(psw_patt$mean_est, 4), "\n")
    cat("    Relative bias:", round(psw_patt$rel_bias, 2), "%\n")
    cat("    RMSE:", round(psw_patt$rmse, 4), "\n")
    cat("    Valid reps:", psw_patt$n_valid, "/", n_reps, "\n\n")
  }
}

# Save results
save(results, ate_sp, att_sp,
     file = paste0("final_simulation_results_", Sys.Date(), ".RData"))

# End time
end_time <- Sys.time()
duration <- difftime(end_time, start_time, units = "mins")

cat("\n=====================================\n")
cat("SIMULATION COMPLETED\n")
cat("=====================================\n")
cat("Duration:", round(duration, 2), "minutes\n")
cat("Results saved to:", paste0("final_simulation_results_", Sys.Date(), ".RData"), "\n\n")

# Summary table
cat("SUMMARY - Relative Bias (%):\n")
summary_df <- data.frame(
  Sampling = rep(c("Prospective", "Retrospective"), each = 2),
  Method = rep(c("WDSM", "PSW"), 2),
  PATE = NA,
  PATT = NA
)

# Fill in summary values
for (i in 1:nrow(summary_df)) {
  stype <- tolower(summary_df$Sampling[i])
  method <- tolower(summary_df$Method[i])
  sdata <- results[results$sampling_type == stype, ]
  
  pate_col <- paste0(method, "_pate")
  patt_col <- paste0(method, "_patt")
  
  pate_summary <- calc_summary(sdata, pate_col, "ate_true")
  patt_summary <- calc_summary(sdata, patt_col, "att_true")
  
  if (!is.null(pate_summary)) summary_df$PATE[i] <- round(pate_summary$rel_bias, 2)
  if (!is.null(patt_summary)) summary_df$PATT[i] <- round(patt_summary$rel_bias, 2)
}

print(summary_df) 