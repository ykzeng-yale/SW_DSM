# Comprehensive Simulation Study: Comparing 5 WDSM CI Methods
# Evaluating Relative Bias and 95% Coverage Rate

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(nnet)
library(parallel)
library(doParallel)

# Set seed for reproducibility
set.seed(20250127)

# Source required functions
source("SW_PSW-main/EstSOD_Function.R")
source("SW_PSW-main/Shared_PSW_MOM_CVR_WET_Function.R")

# Helper function for standardization
standardize <- function(X) {
  X <- as.matrix(X)
  X.std <- scale(X)
  const.cols <- which(attr(X.std, "scaled:scale") == 0)
  if (length(const.cols) > 0) {
    X.std[, const.cols] <- X[, const.cols]
  }
  return(X.std)
}

# Function to find M nearest neighbors
find_nearest_neighbors <- function(distances, own_group, other_group, M) {
  nn_indices <- list()
  for (i in which(own_group)) {
    dists <- distances[i, other_group]
    nn_idx <- which(other_group)[order(dists)[1:min(M, sum(other_group))]]
    nn_indices[[as.character(i)]] <- nn_idx
  }
  return(nn_indices)
}

# Base WDSM point estimation function (used by all methods)
calculate_wdsm_base <- function(Y, X, A, w, M = 3, 
                               e_hat = NULL, mu_hat_0 = NULL, mu_hat_1 = NULL,
                               return_components = FALSE) {
  n <- length(Y)
  
  # Step 1: Estimate scores if not provided
  if (is.null(e_hat)) {
    ps_data <- data.frame(A = A, X = X)
    ps_model <- glm(A ~ ., data = ps_data, weights = w, family = binomial(link = "logit"))
    e_hat <- fitted(ps_model)
  }
  
  if (is.null(mu_hat_0) || is.null(mu_hat_1)) {
    # Prognostic scores
    data_0 <- data.frame(Y = Y[A == 0], X = X[A == 0, , drop = FALSE])
    data_1 <- data.frame(Y = Y[A == 1], X = X[A == 1, , drop = FALSE])
    
    pg_model_0 <- lm(Y ~ ., data = data_0, weights = w[A == 0])
    pg_model_1 <- lm(Y ~ ., data = data_1, weights = w[A == 1])
    
    newdata <- data.frame(X = X)
    mu_hat_0 <- predict(pg_model_0, newdata = newdata)
    mu_hat_1 <- predict(pg_model_1, newdata = newdata)
  }
  
  # Step 2: Form double scores
  S_0 <- cbind(e_hat, mu_hat_0)
  S_1 <- cbind(e_hat, mu_hat_1)
  
  # Standardize scores
  S_0 <- standardize(S_0)
  S_1 <- standardize(S_1)
  
  # Step 3: Calculate distances and find matches
  dist_S0 <- as.matrix(dist(S_0))
  dist_S1 <- as.matrix(dist(S_1))
  
  # For treated units, find matches in control
  matches_for_treated <- find_nearest_neighbors(dist_S0, A == 1, A == 0, M)
  
  # For control units, find matches in treated
  matches_for_control <- find_nearest_neighbors(dist_S1, A == 0, A == 1, M)
  
  # Step 4: Impute potential outcomes
  Y_hat_1 <- Y_hat_0 <- numeric(n)
  
  for (i in 1:n) {
    if (A[i] == 1) {
      Y_hat_1[i] <- Y[i]
      matches <- matches_for_treated[[as.character(i)]]
      if (length(matches) > 0) {
        Y_hat_0[i] <- sum(w[matches] * Y[matches]) / sum(w[matches])
      } else {
        Y_hat_0[i] <- Y[i]
      }
    } else {
      Y_hat_0[i] <- Y[i]
      matches <- matches_for_control[[as.character(i)]]
      if (length(matches) > 0) {
        Y_hat_1[i] <- sum(w[matches] * Y[matches]) / sum(w[matches])
      } else {
        Y_hat_1[i] <- Y[i]
      }
    }
  }
  
  # Step 5: Calculate estimator
  tau_hat <- sum(w * (Y_hat_1 - Y_hat_0)) / sum(w)
  
  if (return_components) {
    # Calculate reuse counts for Version 5
    K_S0 <- K_S1 <- numeric(n)
    
    for (i in 1:n) {
      if (A[i] == 0) {
        # How many times is control unit i used by treated units?
        for (j in which(A == 1)) {
          if (i %in% matches_for_treated[[as.character(j)]]) {
            match_weights <- w[matches_for_treated[[as.character(j)]]]
            K_S0[i] <- K_S0[i] + w[j] / sum(match_weights)
          }
        }
      } else {
        # How many times is treated unit i used by control units?
        for (j in which(A == 0)) {
          if (i %in% matches_for_control[[as.character(j)]]) {
            match_weights <- w[matches_for_control[[as.character(j)]]]
            K_S1[i] <- K_S1[i] + w[j] / sum(match_weights)
          }
        }
      }
    }
    
    return(list(
      tau_hat = tau_hat,
      Y_hat_0 = Y_hat_0,
      Y_hat_1 = Y_hat_1,
      matches_for_treated = matches_for_treated,
      matches_for_control = matches_for_control,
      K_S0 = K_S0,
      K_S1 = K_S1,
      e_hat = e_hat,
      mu_hat_0 = mu_hat_0,
      mu_hat_1 = mu_hat_1
    ))
  }
  
  return(tau_hat)
}

# VERSION 1: Standard Weighted Bootstrap (Resampling)
wdsm_ci_version1 <- function(Y, X, A, w, M = 3, B = 50, alpha = 0.05) {
  # Point estimate
  tau_hat <- calculate_wdsm_base(Y, X, A, w, M)
  
  # Bootstrap
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    # Sample with replacement, probabilities proportional to weights
    boot_idx <- sample(1:length(Y), size = length(Y), replace = TRUE, prob = w)
    
    Y_b <- Y[boot_idx]
    X_b <- X[boot_idx, , drop = FALSE]
    A_b <- A[boot_idx]
    w_b <- w[boot_idx]
    
    tau_boot[b] <- calculate_wdsm_base(Y_b, X_b, A_b, w_b, M)
  }
  
  # CI calculation
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  ci_percentile <- quantile(tau_boot, c(alpha/2, 1 - alpha/2))
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_percentile,
    method = "Version 1: Standard Weighted Bootstrap"
  ))
}

# VERSION 2: Exponential Weights Bootstrap
wdsm_ci_version2 <- function(Y, X, A, w, M = 3, B = 50, alpha = 0.05) {
  # Point estimate
  tau_hat <- calculate_wdsm_base(Y, X, A, w, M)
  
  # Bootstrap
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    # Generate exponential weights
    omega <- rexp(length(Y), rate = 1)
    w_star <- w * omega
    
    tau_boot[b] <- calculate_wdsm_base(Y, X, A, w_star, M)
  }
  
  # CI calculation
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  ci_percentile <- quantile(tau_boot, c(alpha/2, 1 - alpha/2))
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_percentile,
    method = "Version 2: Exponential Weights Bootstrap"
  ))
}

# VERSION 3: Bootstrap with Design Effect Adjustment
wdsm_ci_version3 <- function(Y, X, A, w, M = 3, B = 50, alpha = 0.05) {
  n <- length(Y)
  
  # Point estimate
  tau_hat <- calculate_wdsm_base(Y, X, A, w, M)
  
  # Bootstrap with multinomial resampling
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    # Generate bootstrap sample with normalized weights
    w_normalized <- w / sum(w)
    boot_idx <- sample(1:n, size = n, replace = TRUE, prob = w_normalized)
    
    # Calculate bootstrap weights (frequency * original weight)
    w_b <- numeric(n)
    for (i in 1:n) {
      w_b[i] <- w[i] * sum(boot_idx == i)
    }
    
    # Only use units that were selected
    selected <- w_b > 0
    if (sum(selected) < 10) next  # Skip if too few units
    
    tau_boot[b] <- calculate_wdsm_base(Y[selected], X[selected, , drop = FALSE], 
                                      A[selected], w_b[selected], M)
  }
  
  # Calculate variance with design effect adjustment
  V_boot <- var(tau_boot[is.finite(tau_boot)])
  n_eff <- sum(w)^2 / sum(w^2)
  design_effect <- n / n_eff
  V_adj <- V_boot * design_effect
  
  # CI calculation
  se <- sqrt(V_adj)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_normal,  # Using normal approximation
    method = "Version 3: Bootstrap with Design Effect"
  ))
}

# VERSION 4: Linearized Bootstrap with Multinomial Weights
wdsm_ci_version4 <- function(Y, X, A, w, M = 3, B = 50, alpha = 0.05) {
  n <- length(Y)
  
  # Point estimate with components
  result <- calculate_wdsm_base(Y, X, A, w, M, return_components = TRUE)
  tau_hat <- result$tau_hat
  
  # Bootstrap
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    # Generate multinomial weights
    p <- w / sum(w)
    m_star <- as.numeric(rmultinom(1, n, p))
    omega_star <- m_star / n
    
    # Combined weights
    w_b <- omega_star * w
    
    # Re-estimate scores with bootstrap weights
    ps_data <- data.frame(A = A, X = X)
    ps_model <- glm(A ~ ., data = ps_data, weights = w_b, family = binomial(link = "logit"))
    e_hat_b <- fitted(ps_model)
    
    data_0 <- data.frame(Y = Y[A == 0], X = X[A == 0, , drop = FALSE])
    data_1 <- data.frame(Y = Y[A == 1], X = X[A == 1, , drop = FALSE])
    
    pg_model_0 <- lm(Y ~ ., data = data_0, weights = w_b[A == 0])
    pg_model_1 <- lm(Y ~ ., data = data_1, weights = w_b[A == 1])
    
    newdata <- data.frame(X = X)
    mu_hat_0_b <- predict(pg_model_0, newdata = newdata)
    mu_hat_1_b <- predict(pg_model_1, newdata = newdata)
    
    # Linearized form using original matching structure
    tau_boot[b] <- sum(w_b * (mu_hat_1_b - mu_hat_0_b)) / sum(w_b)
    
    # Add the influence function part
    for (i in 1:n) {
      if (A[i] == 1) {
        influence <- (Y[i] - mu_hat_1_b[i])
        matches <- result$matches_for_treated[[as.character(i)]]
        if (length(matches) > 0) {
          influence <- influence + sum((Y[matches] - mu_hat_0_b[matches]) * w[matches]) / sum(w[matches])
        }
        tau_boot[b] <- tau_boot[b] + w_b[i] * influence / sum(w_b)
      } else {
        influence <- -(Y[i] - mu_hat_0_b[i])
        matches <- result$matches_for_control[[as.character(i)]]
        if (length(matches) > 0) {
          influence <- influence - sum((Y[matches] - mu_hat_1_b[matches]) * w[matches]) / sum(w[matches])
        }
        tau_boot[b] <- tau_boot[b] + w_b[i] * influence / sum(w_b)
      }
    }
  }
  
  # CI calculation
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  ci_percentile <- quantile(tau_boot, c(alpha/2, 1 - alpha/2))
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_percentile,
    method = "Version 4: Linearized Bootstrap"
  ))
}

# VERSION 5: Two-Stage Replication with Fixed Reuse Counts
wdsm_ci_version5 <- function(Y, X, A, w, M = 3, B = 50, alpha = 0.05) {
  n <- length(Y)
  
  # Point estimate with components including reuse counts
  result <- calculate_wdsm_base(Y, X, A, w, M, return_components = TRUE)
  tau_hat <- result$tau_hat
  K_S0 <- result$K_S0
  K_S1 <- result$K_S1
  
  # Bootstrap
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    # Generate bootstrap weights
    boot_idx <- sample(1:n, size = n, replace = TRUE, prob = w / sum(w))
    m_star <- tabulate(boot_idx, nbins = n)
    w_star <- w * m_star
    
    # Re-estimate scores only
    ps_data <- data.frame(A = A, X = X)
    ps_model <- glm(A ~ ., data = ps_data, weights = w_star, family = binomial(link = "logit"))
    e_hat_star <- fitted(ps_model)
    
    data_0 <- data.frame(Y = Y[A == 0], X = X[A == 0, , drop = FALSE])
    data_1 <- data.frame(Y = Y[A == 1], X = X[A == 1, , drop = FALSE])
    
    pg_model_0 <- lm(Y ~ ., data = data_0, weights = w_star[A == 0])
    pg_model_1 <- lm(Y ~ ., data = data_1, weights = w_star[A == 1])
    
    newdata <- data.frame(X = X)
    mu_hat_0_star <- predict(pg_model_0, newdata = newdata)
    mu_hat_1_star <- predict(pg_model_1, newdata = newdata)
    
    # Calculate bootstrap replicate using fixed reuse counts
    term1 <- sum(w_star * (mu_hat_1_star - mu_hat_0_star)) / sum(w_star)
    
    term2 <- 0
    for (i in 1:n) {
      if (A[i] == 1) {
        term2 <- term2 + w_star[i] * (1 + K_S1[i]) * (Y[i] - mu_hat_1_star[i]) / sum(w_star)
      } else {
        term2 <- term2 - w_star[i] * (1 + K_S0[i]) * (Y[i] - mu_hat_0_star[i]) / sum(w_star)
      }
    }
    
    tau_boot[b] <- term1 + term2
  }
  
  # CI calculation
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  ci_percentile <- quantile(tau_boot, c(alpha/2, 1 - alpha/2))
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_percentile,
    method = "Version 5: Two-Stage with Fixed Reuse"
  ))
}

# Main simulation function
run_simulation <- function(n_sims = 100, B_boot = 50) {
  
  # Generate the super population data
  source("SW_PSW-main/Super_Population_GoodOvelap.R")
  
  # Extract population parameters
  data_pop <- data_sets[[1]]
  true_pate <- mean(data_pop$y1) - mean(data_pop$y0)
  
  cat("True PATE:", true_pate, "\n\n")
  
  # Initialize results storage
  results <- list()
  methods <- c("version1", "version2", "version3", "version4", "version5")
  
  for (method in methods) {
    results[[method]] <- list(
      estimates = numeric(n_sims),
      ci_lower_normal = numeric(n_sims),
      ci_upper_normal = numeric(n_sims),
      ci_lower_percentile = numeric(n_sims),
      ci_upper_percentile = numeric(n_sims),
      covered_normal = logical(n_sims),
      covered_percentile = logical(n_sims)
    )
  }
  
  # Define sampling parameters
  size1 <- rep(100000, 10)
  size2 <- rep(5, 10)
  size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
             rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
             rep(250/5, 5), rep(150/5, 5))
  
  # Run simulations
  for (sim in 1:n_sims) {
    if (sim %% 10 == 0) cat("Simulation", sim, "of", n_sims, "\n")
    
    # Create a sample
    data_pop$ones <- 1
    data_pop$id <- 1:nrow(data_pop)
    
    s <- mstage(data_pop, stage = list("stratified", "cluster", ""), 
                varnames = list("Strata", "Cluster", "ones"), 
                size = list(size1, size2, size3), 
                method = list("", "srswor", "srswor"))
    
    sample <- getdata(data_pop, s)[[3]]
    sample$s.wt <- 1 / sample$Prob
    
    # Extract variables
    Y <- sample$y
    X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
    A <- sample$z
    w <- sample$s.wt
    
    # Run all methods
    tryCatch({
      # Version 1
      res1 <- wdsm_ci_version1(Y, X, A, w, M = 3, B = B_boot)
      results$version1$estimates[sim] <- res1$tau_hat
      results$version1$ci_lower_normal[sim] <- res1$ci_normal[1]
      results$version1$ci_upper_normal[sim] <- res1$ci_normal[2]
      results$version1$ci_lower_percentile[sim] <- res1$ci_percentile[1]
      results$version1$ci_upper_percentile[sim] <- res1$ci_percentile[2]
      results$version1$covered_normal[sim] <- (true_pate >= res1$ci_normal[1]) & 
                                              (true_pate <= res1$ci_normal[2])
      results$version1$covered_percentile[sim] <- (true_pate >= res1$ci_percentile[1]) & 
                                                  (true_pate <= res1$ci_percentile[2])
      
      # Version 2
      res2 <- wdsm_ci_version2(Y, X, A, w, M = 3, B = B_boot)
      results$version2$estimates[sim] <- res2$tau_hat
      results$version2$ci_lower_normal[sim] <- res2$ci_normal[1]
      results$version2$ci_upper_normal[sim] <- res2$ci_normal[2]
      results$version2$ci_lower_percentile[sim] <- res2$ci_percentile[1]
      results$version2$ci_upper_percentile[sim] <- res2$ci_percentile[2]
      results$version2$covered_normal[sim] <- (true_pate >= res2$ci_normal[1]) & 
                                              (true_pate <= res2$ci_normal[2])
      results$version2$covered_percentile[sim] <- (true_pate >= res2$ci_percentile[1]) & 
                                                  (true_pate <= res2$ci_percentile[2])
      
      # Version 3
      res3 <- wdsm_ci_version3(Y, X, A, w, M = 3, B = B_boot)
      results$version3$estimates[sim] <- res3$tau_hat
      results$version3$ci_lower_normal[sim] <- res3$ci_normal[1]
      results$version3$ci_upper_normal[sim] <- res3$ci_normal[2]
      results$version3$ci_lower_percentile[sim] <- res3$ci_percentile[1]
      results$version3$ci_upper_percentile[sim] <- res3$ci_percentile[2]
      results$version3$covered_normal[sim] <- (true_pate >= res3$ci_normal[1]) & 
                                              (true_pate <= res3$ci_normal[2])
      results$version3$covered_percentile[sim] <- (true_pate >= res3$ci_percentile[1]) & 
                                                  (true_pate <= res3$ci_percentile[2])
      
      # Version 4
      res4 <- wdsm_ci_version4(Y, X, A, w, M = 3, B = B_boot)
      results$version4$estimates[sim] <- res4$tau_hat
      results$version4$ci_lower_normal[sim] <- res4$ci_normal[1]
      results$version4$ci_upper_normal[sim] <- res4$ci_normal[2]
      results$version4$ci_lower_percentile[sim] <- res4$ci_percentile[1]
      results$version4$ci_upper_percentile[sim] <- res4$ci_percentile[2]
      results$version4$covered_normal[sim] <- (true_pate >= res4$ci_normal[1]) & 
                                              (true_pate <= res4$ci_normal[2])
      results$version4$covered_percentile[sim] <- (true_pate >= res4$ci_percentile[1]) & 
                                                  (true_pate <= res4$ci_percentile[2])
      
      # Version 5
      res5 <- wdsm_ci_version5(Y, X, A, w, M = 3, B = B_boot)
      results$version5$estimates[sim] <- res5$tau_hat
      results$version5$ci_lower_normal[sim] <- res5$ci_normal[1]
      results$version5$ci_upper_normal[sim] <- res5$ci_normal[2]
      results$version5$ci_lower_percentile[sim] <- res5$ci_percentile[1]
      results$version5$ci_upper_percentile[sim] <- res5$ci_percentile[2]
      results$version5$covered_normal[sim] <- (true_pate >= res5$ci_normal[1]) & 
                                              (true_pate <= res5$ci_normal[2])
      results$version5$covered_percentile[sim] <- (true_pate >= res5$ci_percentile[1]) & 
                                                  (true_pate <= res5$ci_percentile[2])
      
    }, error = function(e) {
      cat("Error in simulation", sim, ":", e$message, "\n")
    })
  }
  
  # Calculate summary statistics
  summary_stats <- data.frame()
  
  for (method in methods) {
    # Remove NA values
    valid_idx <- !is.na(results[[method]]$estimates)
    
    method_summary <- data.frame(
      Method = method,
      Mean_Estimate = mean(results[[method]]$estimates[valid_idx]),
      Bias = mean(results[[method]]$estimates[valid_idx]) - true_pate,
      Relative_Bias = (mean(results[[method]]$estimates[valid_idx]) - true_pate) / true_pate * 100,
      SD = sd(results[[method]]$estimates[valid_idx]),
      Coverage_Normal = mean(results[[method]]$covered_normal[valid_idx]) * 100,
      Coverage_Percentile = mean(results[[method]]$covered_percentile[valid_idx]) * 100,
      Avg_CI_Width_Normal = mean(results[[method]]$ci_upper_normal[valid_idx] - 
                                 results[[method]]$ci_lower_normal[valid_idx]),
      Avg_CI_Width_Percentile = mean(results[[method]]$ci_upper_percentile[valid_idx] - 
                                    results[[method]]$ci_lower_percentile[valid_idx])
    )
    
    summary_stats <- rbind(summary_stats, method_summary)
  }
  
  # Add method names
  summary_stats$Method_Name <- c(
    "Version 1: Standard Weighted Bootstrap",
    "Version 2: Exponential Weights Bootstrap",
    "Version 3: Bootstrap with Design Effect",
    "Version 4: Linearized Bootstrap",
    "Version 5: Two-Stage with Fixed Reuse"
  )
  
  return(list(
    results = results,
    summary = summary_stats,
    true_pate = true_pate
  ))
}

# Run the simulation
cat("Starting simulation study with 100 replications...\n")
cat("Using 50 bootstrap samples per method\n\n")

sim_results <- run_simulation(n_sims = 100, B_boot = 50)

# Print results
cat("\n\n=== SIMULATION RESULTS ===\n")
cat("True PATE:", sim_results$true_pate, "\n\n")

# Print summary table
print(sim_results$summary[, c("Method_Name", "Mean_Estimate", "Bias", 
                              "Relative_Bias", "SD", "Coverage_Normal", 
                              "Coverage_Percentile")])

# Save results
save(sim_results, file = "wdsm_all_methods_simulation_results.RData")

# Create visualization
pdf("wdsm_all_methods_comparison_plots.pdf", width = 12, height = 10)

# Plot 1: Bias comparison
par(mfrow = c(2, 2))
barplot(sim_results$summary$Relative_Bias, 
        names.arg = paste0("V", 1:5),
        main = "Relative Bias (%) by Method",
        ylab = "Relative Bias (%)",
        col = rainbow(5))
abline(h = 0, lty = 2)

# Plot 2: Coverage comparison
coverage_data <- rbind(
  sim_results$summary$Coverage_Normal,
  sim_results$summary$Coverage_Percentile
)
barplot(coverage_data, 
        beside = TRUE,
        names.arg = paste0("V", 1:5),
        main = "95% Coverage Rate by Method",
        ylab = "Coverage (%)",
        col = c("lightblue", "lightgreen"),
        legend = c("Normal", "Percentile"))
abline(h = 95, lty = 2, col = "red")

# Plot 3: CI Width comparison
barplot(sim_results$summary$Avg_CI_Width_Normal, 
        names.arg = paste0("V", 1:5),
        main = "Average CI Width by Method",
        ylab = "CI Width",
        col = rainbow(5))

# Plot 4: Sampling distributions
plot(0, type = "n", xlim = c(0.5, 1.5), ylim = c(0, 5),
     main = "Sampling Distributions", xlab = "Estimate", ylab = "Method")
for (i in 1:5) {
  estimates <- sim_results$results[[methods[i]]]$estimates
  points(estimates, rep(i, length(estimates)), pch = 16, 
         col = rgb(i/5, 0, 1-i/5, 0.3))
}
abline(v = sim_results$true_pate, col = "red", lwd = 2)

dev.off()

cat("\nResults saved to:\n")
cat("- wdsm_all_methods_simulation_results.RData\n")
cat("- wdsm_all_methods_comparison_plots.pdf\n") 