# Check rate of propensity score model failure

source("wdsm_ci_functions.R")

# Load population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_GoodOverlap_AllinOne_0118_2025
population <- data_sets[[1]]

# Rename columns
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "y"] <- "Y"
names(population)[names(population) == "y0"] <- "Y0"
names(population)[names(population) == "y1"] <- "Y1"
for (i in 1:6) {
  names(population)[names(population) == paste0("x", i)] <- paste0("X", i)
}

# Function to check propensity score estimation
check_ps_estimation <- function(seed_val) {
  set.seed(seed_val)
  sample_data <- retrospective_sample(population, n_sample = 5000)
  
  # Try to estimate propensity score
  ps_model <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                  data = sample_data, 
                  family = binomial,
                  weights = sample_data$survey_weight)
  e_score <- predict(ps_model, type = "response")
  
  # Check for failure
  mean_ps <- mean(e_score)
  sd_ps <- sd(e_score)
  min_ps <- min(e_score)
  max_ps <- max(e_score)
  converged <- ps_model$converged
  
  # Failure indicators
  all_near_zero <- sum(e_score < 0.01) == length(e_score)
  all_near_one <- sum(e_score > 0.99) == length(e_score)
  no_variation <- sd_ps < 1e-10
  
  failed <- all_near_zero || all_near_one || no_variation || !converged
  
  return(list(
    seed = seed_val,
    failed = failed,
    converged = converged,
    mean_ps = mean_ps,
    sd_ps = sd_ps,
    min_ps = min_ps,
    max_ps = max_ps,
    all_near_zero = all_near_zero,
    all_near_one = all_near_one,
    no_variation = no_variation
  ))
}

# Check 100 random samples
n_check <- 100
results <- list()

cat("Checking propensity score estimation across", n_check, "samples...\n\n")

for (i in 1:n_check) {
  if (i %% 10 == 0) cat("Progress:", i, "/", n_check, "\n")
  results[[i]] <- check_ps_estimation(2024 + i)
}

# Summarize results
results_df <- do.call(rbind, lapply(results, as.data.frame))
n_failed <- sum(results_df$failed)
failure_rate <- n_failed / n_check

cat("\n=== SUMMARY ===\n")
cat("Total samples checked:", n_check, "\n")
cat("Samples with PS failure:", n_failed, "\n")
cat("Failure rate:", sprintf("%.1f%%", failure_rate * 100), "\n\n")

# Show details of failures
if (n_failed > 0) {
  cat("Failed samples:\n")
  failed_samples <- results_df[results_df$failed, ]
  print(failed_samples[, c("seed", "converged", "mean_ps", "sd_ps", "all_near_zero", "all_near_one")])
} 