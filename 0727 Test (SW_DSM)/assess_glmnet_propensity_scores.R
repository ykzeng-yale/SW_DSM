# Assess glmnet for propensity score estimation vs true population probabilities

library(glmnet)
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

cat("=== POPULATION ANALYSIS ===\n")
cat("Population size:", nrow(population), "\n")
cat("Treatment rate:", mean(population$A), "\n\n")

# Step 1: Calculate TRUE population propensity scores
# Fit a model to the entire population to get "true" propensity scores
cat("Fitting true population propensity score model...\n")
true_ps_model <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                     data = population, 
                     family = binomial)
true_e_score <- predict(true_ps_model, type = "response")

cat("True population propensity scores:\n")
cat("  Mean:", mean(true_e_score), "\n")
cat("  SD:", sd(true_e_score), "\n")
cat("  Range:", range(true_e_score), "\n\n")

# Function to assess glmnet on a sample
assess_glmnet_sample <- function(seed_val) {
  set.seed(seed_val)
  sample_data <- retrospective_sample(population, n_sample = 5000)
  
  # Prepare data for glmnet
  X <- model.matrix(~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 - 1, data = sample_data)
  y <- sample_data$A
  w <- sample_data$survey_weight
  
  # Method 1: Standard GLM (will likely fail)
  glm_failed <- FALSE
  glm_e_score <- rep(NA, nrow(sample_data))
  
  tryCatch({
    ps_glm <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                  data = sample_data, 
                  family = binomial,
                  weights = w)
    glm_e_score <- predict(ps_glm, type = "response")
    glm_failed <- !ps_glm$converged || sd(glm_e_score) < 1e-10
  }, warning = function(w) {
    glm_failed <<- TRUE
  }, error = function(e) {
    glm_failed <<- TRUE
  })
  
  # Method 2: Ridge regression (alpha = 0)
  cv_ridge <- cv.glmnet(X, y, family = "binomial", 
                        weights = w, 
                        alpha = 0,  # Ridge
                        nfolds = 10)
  ridge_e_score <- predict(cv_ridge, newx = X, s = "lambda.min", type = "response")[,1]
  
  # Method 3: Elastic net (alpha = 0.5)
  cv_elastic <- cv.glmnet(X, y, family = "binomial", 
                          weights = w, 
                          alpha = 0.5,  # Elastic net
                          nfolds = 10)
  elastic_e_score <- predict(cv_elastic, newx = X, s = "lambda.min", type = "response")[,1]
  
  # Method 4: LASSO (alpha = 1)
  cv_lasso <- cv.glmnet(X, y, family = "binomial", 
                        weights = w, 
                        alpha = 1,  # LASSO
                        nfolds = 10)
  lasso_e_score <- predict(cv_lasso, newx = X, s = "lambda.min", type = "response")[,1]
  
  # Get true propensity scores for sampled units
  sample_indices <- as.numeric(rownames(sample_data))
  true_e_sample <- true_e_score[sample_indices]
  
  # Calculate performance metrics
  calc_metrics <- function(estimated, truth) {
    if (all(is.na(estimated))) {
      return(c(mae = NA, rmse = NA, correlation = NA))
    }
    mae <- mean(abs(estimated - truth), na.rm = TRUE)
    rmse <- sqrt(mean((estimated - truth)^2, na.rm = TRUE))
    
    # Check if there's any variation in the estimates
    if (sd(estimated, na.rm = TRUE) < 1e-10 || sd(truth, na.rm = TRUE) < 1e-10) {
      cor_val <- NA
    } else {
      cor_val <- cor(estimated, truth, use = "complete.obs")
    }
    return(c(mae = mae, rmse = rmse, correlation = cor_val))
  }
  
  return(list(
    seed = seed_val,
    glm_failed = glm_failed,
    glm_metrics = calc_metrics(glm_e_score, true_e_sample),
    ridge_metrics = calc_metrics(ridge_e_score, true_e_sample),
    elastic_metrics = calc_metrics(elastic_e_score, true_e_sample),
    lasso_metrics = calc_metrics(lasso_e_score, true_e_sample),
    glm_sd = sd(glm_e_score, na.rm = TRUE),
    ridge_sd = sd(ridge_e_score),
    elastic_sd = sd(elastic_e_score),
    lasso_sd = sd(lasso_e_score),
    ridge_lambda = cv_ridge$lambda.min,
    elastic_lambda = cv_elastic$lambda.min,
    lasso_lambda = cv_lasso$lambda.min
  ))
}

# Test on multiple samples
cat("=== COMPARING METHODS ACROSS SAMPLES ===\n\n")

n_tests <- 20
results <- list()

for (i in 1:n_tests) {
  cat("Testing sample", i, "of", n_tests, "...\n")
  results[[i]] <- assess_glmnet_sample(2024 + i)
}

# Summarize results
cat("\n=== SUMMARY ACROSS", n_tests, "SAMPLES ===\n\n")

# Extract metrics
glm_failures <- sum(sapply(results, function(x) x$glm_failed))
cat("GLM failures:", glm_failures, "/", n_tests, sprintf("(%.1f%%)\n", 100*glm_failures/n_tests))

# Average performance metrics
methods <- c("glm", "ridge", "elastic", "lasso")
metric_names <- c("mae", "rmse", "correlation")

cat("\nAverage performance metrics (vs true population propensity scores):\n")
cat(sprintf("%-10s", "Method"))
for (m in metric_names) cat(sprintf("%12s", m))
cat("\n")

for (method in methods) {
  cat(sprintf("%-10s", method))
  for (metric in metric_names) {
    values <- sapply(results, function(x) x[[paste0(method, "_metrics")]][metric])
    cat(sprintf("%12.4f", mean(values, na.rm = TRUE)))
  }
  cat("\n")
}

# SD of estimated propensity scores
cat("\nAverage SD of estimated propensity scores:\n")
for (method in methods) {
  sd_values <- sapply(results, function(x) x[[paste0(method, "_sd")]])
  cat(sprintf("  %s: %.4f\n", method, mean(sd_values, na.rm = TRUE)))
}

# Show a detailed example
cat("\n=== DETAILED EXAMPLE (Sample 1) ===\n")
set.seed(2025)
sample_data <- retrospective_sample(population, n_sample = 5000)
sample_indices <- as.numeric(rownames(sample_data))
true_e_sample <- true_e_score[sample_indices]

# Fit glmnet
X <- model.matrix(~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 - 1, data = sample_data)
y <- sample_data$A
w <- sample_data$survey_weight

cv_ridge <- cv.glmnet(X, y, family = "binomial", weights = w, alpha = 0)
ridge_e_score <- predict(cv_ridge, newx = X, s = "lambda.min", type = "response")[,1]

# Compare distributions
cat("\nTrue vs Ridge propensity scores:\n")
cat("  True - Mean:", mean(true_e_sample), ", SD:", sd(true_e_sample), "\n")
cat("  Ridge - Mean:", mean(ridge_e_score), ", SD:", sd(ridge_e_score), "\n")
cat("  Correlation:", cor(true_e_sample, ridge_e_score), "\n")

# Show some examples
cat("\nSome example comparisons:\n")
cat("   True    Ridge   Difference\n")
for (i in c(1:5, 100:105)) {
  cat(sprintf("%7.4f  %7.4f  %+8.4f\n", 
              true_e_sample[i], ridge_e_score[i], 
              ridge_e_score[i] - true_e_sample[i]))
} 