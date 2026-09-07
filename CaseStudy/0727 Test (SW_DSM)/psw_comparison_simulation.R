# PSW Comparison Under Different Sampling Designs
# This simulation compares propensity score weighting under prospective and retrospective sampling

cat("=====================================\n")
cat("PSW COMPARISON SIMULATION\n")
cat("=====================================\n\n")

# Set parameters
n_reps <- 20
sample_size <- 5000
set.seed(2024)

# Load libraries
suppressPackageStartupMessages({
  library(survey)
  library(sampling)
  library(MASS)
})

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
      # Retrospective sampling (outcome-dependent)
      prob_select <- expit(-1 + 0.5 * data$y)
      sample_idx <- sample(1:nrow(data), sample_size, 
                          replace = FALSE, prob = prob_select)
      sampled_data <- data[sample_idx, ]
      sampled_data$wt <- (1 / prob_select[sample_idx]) * (nrow(data) / sample_size)
    }
    
    # Normalize weights
    sampled_data$wt <- sampled_data$wt * nrow(sampled_data) / sum(sampled_data$wt)
    
    # Create cluster ID
    sampled_data$clusterid <- 1:nrow(sampled_data)
    
    # Create survey design
    design <- svydesign(ids = ~clusterid, weights = ~wt, data = sampled_data)
    
    # Run PSW estimation
    psw_results <- EstSOD(design)
    
    # Extract estimates
    pate_est <- as.numeric(psw_results$PATE$`W.PS`[[1]])
    pate_se <- as.numeric(psw_results$PATE$se[[1]])
    patt_est <- as.numeric(psw_results$PATT$`W.PS`[[1]])
    patt_se <- as.numeric(psw_results$PATT$se[[1]])
    
    # Return results
    return(data.frame(
      sampling_type = sampling_type,
      rep = rep_id,
      pate_est = pate_est,
      pate_se = pate_se,
      patt_est = patt_est,
      patt_se = patt_se,
      ate_true = ate_sp,
      att_true = att_sp
    ))
    
  }, error = function(e) {
    cat("Error in", sampling_type, "rep", rep_id, ":", e$message, "\n")
    return(NULL)
  })
}

# Run simulations
cat("Running simulations...\n")
results <- rbind(
  do.call(rbind, lapply(1:n_reps, function(i) run_simulation(i, "prospective"))),
  do.call(rbind, lapply(1:n_reps, function(i) run_simulation(i, "retrospective")))
)

# Check if results exist
if (is.null(results) || nrow(results) == 0) {
  cat("No valid results obtained!\n")
  stop("Simulation failed to produce any results")
}

# Remove NULL results
results <- results[!is.na(results$pate_est), ]

# Calculate coverage
calc_coverage <- function(estimates, ses, true_value, alpha = 0.05) {
  z_crit <- qnorm(1 - alpha/2)
  lower <- estimates - z_crit * ses
  upper <- estimates + z_crit * ses
  coverage <- mean(lower <= true_value & upper >= true_value, na.rm = TRUE)
  return(coverage * 100)
}

# Analyze results
cat("\n=====================================\n")
cat("SIMULATION RESULTS\n")
cat("=====================================\n\n")

# Summary by sampling type
for (stype in c("prospective", "retrospective")) {
  sdata <- results[results$sampling_type == stype, ]
  
  if (!is.null(sdata) && nrow(sdata) > 0) {
    cat(toupper(stype), "SAMPLING RESULTS (n =", nrow(sdata), ")\n")
    cat(paste(rep("-", 40), collapse=""), "\n\n")
    
    # PATE
    pate_bias <- mean(sdata$pate_est - sdata$ate_true[1])
    pate_rel_bias <- (pate_bias / sdata$ate_true[1]) * 100
    pate_rmse <- sqrt(mean((sdata$pate_est - sdata$ate_true[1])^2))
    pate_coverage <- calc_coverage(sdata$pate_est, sdata$pate_se, sdata$ate_true[1])
    
    cat("PATE (True value =", round(sdata$ate_true[1], 4), ")\n")
    cat("  Mean estimate:", round(mean(sdata$pate_est), 4), "\n")
    cat("  Bias:", round(pate_bias, 4), "\n")
    cat("  Relative bias:", round(pate_rel_bias, 2), "%\n")
    cat("  RMSE:", round(pate_rmse, 4), "\n")
    cat("  95% CI Coverage:", round(pate_coverage, 1), "%\n\n")
    
    # PATT
    patt_bias <- mean(sdata$patt_est - sdata$att_true[1])
    patt_rel_bias <- (patt_bias / sdata$att_true[1]) * 100
    patt_rmse <- sqrt(mean((sdata$patt_est - sdata$att_true[1])^2))
    patt_coverage <- calc_coverage(sdata$patt_est, sdata$patt_se, sdata$att_true[1])
    
    cat("PATT (True value =", round(sdata$att_true[1], 4), ")\n")
    cat("  Mean estimate:", round(mean(sdata$patt_est), 4), "\n")
    cat("  Bias:", round(patt_bias, 4), "\n")
    cat("  Relative bias:", round(patt_rel_bias, 2), "%\n")
    cat("  RMSE:", round(patt_rmse, 4), "\n")
    cat("  95% CI Coverage:", round(patt_coverage, 1), "%\n\n")
  }
}

# Save results
save(results, ate_sp, att_sp,
     file = paste0("psw_comparison_results_", Sys.Date(), ".RData"))

cat("=====================================\n")
cat("SIMULATION COMPLETED\n")
cat("=====================================\n")
cat("Results saved to:", paste0("psw_comparison_results_", Sys.Date(), ".RData"), "\n\n")

# Summary table
cat("SUMMARY TABLE\n")
summary_df <- data.frame(
  Sampling = c("Prospective", "Retrospective"),
  PATE_RelBias = NA,
  PATE_Coverage = NA,
  PATT_RelBias = NA,
  PATT_Coverage = NA
)

for (i in 1:2) {
  stype <- tolower(summary_df$Sampling[i])
  sdata <- results[results$sampling_type == stype, ]
  
  if (!is.null(sdata) && nrow(sdata) > 0) {
    pate_bias <- mean(sdata$pate_est - sdata$ate_true[1])
    summary_df$PATE_RelBias[i] <- round((pate_bias / sdata$ate_true[1]) * 100, 2)
    summary_df$PATE_Coverage[i] <- round(calc_coverage(sdata$pate_est, sdata$pate_se, sdata$ate_true[1]), 1)
    
    patt_bias <- mean(sdata$patt_est - sdata$att_true[1])
    summary_df$PATT_RelBias[i] <- round((patt_bias / sdata$att_true[1]) * 100, 2)
    summary_df$PATT_Coverage[i] <- round(calc_coverage(sdata$patt_est, sdata$patt_se, sdata$att_true[1]), 1)
  }
}

print(summary_df) 