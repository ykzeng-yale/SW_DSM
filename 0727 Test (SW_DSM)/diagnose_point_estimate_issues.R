# Diagnostic script to investigate point estimate issues

# Load libraries and functions
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

# True PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("True PATE:", true_pate, "\n\n")

# Function to diagnose a single sample
diagnose_sample <- function(seed_val) {
  set.seed(seed_val)
  sample_data <- retrospective_sample(population, n_sample = 5000)
  
  cat("=== Sample Diagnostics (seed =", seed_val, ") ===\n")
  cat("Sample size:", nrow(sample_data), "\n")
  cat("Treated units:", sum(sample_data$A), "\n")
  cat("Control units:", sum(1 - sample_data$A), "\n")
  
  # Check survey weights
  cat("\nSurvey Weights:\n")
  cat("  Mean:", mean(sample_data$survey_weight), "\n")
  cat("  SD:", sd(sample_data$survey_weight), "\n")
  cat("  Min:", min(sample_data$survey_weight), "\n")
  cat("  Max:", max(sample_data$survey_weight), "\n")
  cat("  95th percentile:", quantile(sample_data$survey_weight, 0.95), "\n")
  cat("  99th percentile:", quantile(sample_data$survey_weight, 0.99), "\n")
  
  # Check effective sample size
  eff_n <- sum(sample_data$survey_weight)^2 / sum(sample_data$survey_weight^2)
  cat("  Effective sample size:", round(eff_n, 1), "\n")
  cat("  Ratio to actual n:", round(eff_n / nrow(sample_data), 3), "\n")
  
  # Get scores from point estimation
  tryCatch({
    # Estimate propensity score
    ps_model <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                    data = sample_data, 
                    family = binomial,
                    weights = sample_data$survey_weight)
    e_score <- predict(ps_model, type = "response")
    
    cat("\nPropensity Scores:\n")
    cat("  Mean:", mean(e_score), "\n")
    cat("  SD:", sd(e_score), "\n")
    cat("  Min:", min(e_score), "\n")
    cat("  Max:", max(e_score), "\n")
    cat("  # near 0 (<0.01):", sum(e_score < 0.01), "\n")
    cat("  # near 1 (>0.99):", sum(e_score > 0.99), "\n")
    
    # Check overlap
    cat("\nPropensity Score Overlap:\n")
    cat("  Treated - Mean:", mean(e_score[sample_data$A == 1]), "\n")
    cat("  Control - Mean:", mean(e_score[sample_data$A == 0]), "\n")
    cat("  Treated - Range:", range(e_score[sample_data$A == 1]), "\n")
    cat("  Control - Range:", range(e_score[sample_data$A == 0]), "\n")
    
    # Estimate prognostic scores
    prog0_model <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                      data = sample_data[sample_data$A == 0,],
                      weights = sample_data$survey_weight[sample_data$A == 0])
    psi0 <- predict(prog0_model, newdata = sample_data)
    
    prog1_model <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                      data = sample_data[sample_data$A == 1,],
                      weights = sample_data$survey_weight[sample_data$A == 1])
    psi1 <- predict(prog1_model, newdata = sample_data)
    
    cat("\nPrognostic Scores Y(0):\n")
    cat("  Mean:", mean(psi0), "\n")
    cat("  SD:", sd(psi0), "\n")
    cat("  Range:", range(psi0), "\n")
    
    cat("\nPrognostic Scores Y(1):\n")
    cat("  Mean:", mean(psi1), "\n")
    cat("  SD:", sd(psi1), "\n")
    cat("  Range:", range(psi1), "\n")
    
    # Check outcomes
    cat("\nOutcomes:\n")
    cat("  Y - Mean:", mean(sample_data$Y), "\n")
    cat("  Y - SD:", sd(sample_data$Y), "\n")
    cat("  Y - Range:", range(sample_data$Y), "\n")
    cat("  Y|A=0 - Mean:", mean(sample_data$Y[sample_data$A == 0]), "\n")
    cat("  Y|A=1 - Mean:", mean(sample_data$Y[sample_data$A == 1]), "\n")
    
    # Get point estimate
    point_results <- wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE)
    cat("\nPoint Estimate:", point_results$tau, "\n")
    cat("Error from truth:", point_results$tau - true_pate, "\n")
    
    # Check extreme weights times outcomes
    cat("\nExtreme Weighted Outcomes:\n")
    weighted_Y <- sample_data$survey_weight * sample_data$Y
    cat("  Max(w*Y):", max(weighted_Y), "\n")
    cat("  Min(w*Y):", min(weighted_Y), "\n")
    cat("  Top 5 w*Y:", sort(weighted_Y, decreasing = TRUE)[1:5], "\n")
    
    # Check if extreme weights correspond to extreme outcomes
    extreme_weight_idx <- which(sample_data$survey_weight > quantile(sample_data$survey_weight, 0.95))
    cat("\nOutcomes for units with extreme weights (>95th percentile):\n")
    cat("  Mean Y:", mean(sample_data$Y[extreme_weight_idx]), "\n")
    cat("  Range Y:", range(sample_data$Y[extreme_weight_idx]), "\n")
    
  }, error = function(e) {
    cat("\nERROR in estimation:", e$message, "\n")
  })
  
  cat("\n" ,rep("=", 60), "\n\n")
  
  return(sample_data)
}

# Diagnose multiple samples, including the problematic ones from simulation
problematic_seeds <- c(2024 + 3, 2024 + 12, 2024 + 14, 2024 + 19)  # Seeds that gave extreme estimates
normal_seeds <- c(2024 + 1, 2024 + 2)  # Seeds that gave reasonable estimates

cat("DIAGNOSING PROBLEMATIC SAMPLES:\n\n")
for (seed in problematic_seeds) {
  diagnose_sample(seed)
}

cat("\n\nDIAGNOSING NORMAL SAMPLES FOR COMPARISON:\n\n")
for (seed in normal_seeds) {
  diagnose_sample(seed)
} 