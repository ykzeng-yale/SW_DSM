# Small Scale Test of 5 WDSM CI Methods with Detailed Progress
# 10 resampling iterations, 5 bootstrap samples per method

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

# Copy essential functions from main simulation script
standardize <- function(X) {
  X <- as.matrix(X)
  X.std <- scale(X)
  const.cols <- which(attr(X.std, "scaled:scale") == 0)
  if (length(const.cols) > 0) {
    X.std[, const.cols] <- X[, const.cols]
  }
  return(X.std)
}

find_nearest_neighbors <- function(distances, own_group, other_group, M) {
  nn_indices <- list()
  for (i in which(own_group)) {
    dists <- distances[i, other_group]
    nn_idx <- which(other_group)[order(dists)[1:min(M, sum(other_group))]]
    nn_indices[[as.character(i)]] <- nn_idx
  }
  return(nn_indices)
}

# Modified base function with progress tracking
calculate_wdsm_base <- function(Y, X, A, w, M = 3, 
                               e_hat = NULL, mu_hat_0 = NULL, mu_hat_1 = NULL,
                               return_components = FALSE, show_progress = FALSE) {
  n <- length(Y)
  
  if (show_progress) cat("  - Estimating scores...")
  
  # Step 1: Estimate scores if not provided
  if (is.null(e_hat)) {
    ps_data <- data.frame(A = A, X = X)
    ps_model <- glm(A ~ ., data = ps_data, weights = w, family = binomial(link = "logit"))
    e_hat <- fitted(ps_model)
  }
  
  if (is.null(mu_hat_0) || is.null(mu_hat_1)) {
    data_0 <- data.frame(Y = Y[A == 0], X = X[A == 0, , drop = FALSE])
    data_1 <- data.frame(Y = Y[A == 1], X = X[A == 1, , drop = FALSE])
    
    pg_model_0 <- lm(Y ~ ., data = data_0, weights = w[A == 0])
    pg_model_1 <- lm(Y ~ ., data = data_1, weights = w[A == 1])
    
    newdata <- data.frame(X = X)
    mu_hat_0 <- predict(pg_model_0, newdata = newdata)
    mu_hat_1 <- predict(pg_model_1, newdata = newdata)
  }
  
  if (show_progress) cat(" matching...")
  
  # Step 2: Form double scores
  S_0 <- cbind(e_hat, mu_hat_0)
  S_1 <- cbind(e_hat, mu_hat_1)
  
  S_0 <- standardize(S_0)
  S_1 <- standardize(S_1)
  
  # Step 3: Calculate distances and find matches
  dist_S0 <- as.matrix(dist(S_0))
  dist_S1 <- as.matrix(dist(S_1))
  
  matches_for_treated <- find_nearest_neighbors(dist_S0, A == 1, A == 0, M)
  matches_for_control <- find_nearest_neighbors(dist_S1, A == 0, A == 1, M)
  
  if (show_progress) cat(" calculating estimate...")
  
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
  
  if (show_progress) cat(" done\n")
  
  if (return_components) {
    K_S0 <- K_S1 <- numeric(n)
    
    for (i in 1:n) {
      if (A[i] == 0) {
        for (j in which(A == 1)) {
          if (i %in% matches_for_treated[[as.character(j)]]) {
            match_weights <- w[matches_for_treated[[as.character(j)]]]
            K_S0[i] <- K_S0[i] + w[j] / sum(match_weights)
          }
        }
      } else {
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

# Modified version functions with progress tracking
wdsm_ci_version1 <- function(Y, X, A, w, M = 3, B = 5, alpha = 0.05) {
  cat("\n  VERSION 1: Standard Weighted Bootstrap\n")
  tau_hat <- calculate_wdsm_base(Y, X, A, w, M)
  cat("  Point estimate:", round(tau_hat, 4), "\n")
  
  tau_boot <- numeric(B)
  cat("  Bootstrap progress: ")
  
  for (b in 1:B) {
    cat(b, "")
    boot_idx <- sample(1:length(Y), size = length(Y), replace = TRUE, prob = w)
    
    Y_b <- Y[boot_idx]
    X_b <- X[boot_idx, , drop = FALSE]
    A_b <- A[boot_idx]
    w_b <- w[boot_idx]
    
    tau_boot[b] <- calculate_wdsm_base(Y_b, X_b, A_b, w_b, M, show_progress = FALSE)
  }
  cat("\n")
  
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  ci_percentile <- quantile(tau_boot, c(alpha/2, 1 - alpha/2))
  
  cat("  Bootstrap estimates:", round(tau_boot, 4), "\n")
  cat("  SE:", round(se, 4), " CI:", round(ci_normal, 4), "\n")
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_percentile,
    method = "Version 1"
  ))
}

wdsm_ci_version2 <- function(Y, X, A, w, M = 3, B = 5, alpha = 0.05) {
  cat("\n  VERSION 2: Exponential Weights Bootstrap\n")
  tau_hat <- calculate_wdsm_base(Y, X, A, w, M)
  cat("  Point estimate:", round(tau_hat, 4), "\n")
  
  tau_boot <- numeric(B)
  cat("  Bootstrap progress: ")
  
  for (b in 1:B) {
    cat(b, "")
    omega <- rexp(length(Y), rate = 1)
    w_star <- w * omega
    
    tau_boot[b] <- calculate_wdsm_base(Y, X, A, w_star, M, show_progress = FALSE)
  }
  cat("\n")
  
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  ci_percentile <- quantile(tau_boot, c(alpha/2, 1 - alpha/2))
  
  cat("  Bootstrap estimates:", round(tau_boot, 4), "\n")
  cat("  SE:", round(se, 4), " CI:", round(ci_normal, 4), "\n")
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_percentile,
    method = "Version 2"
  ))
}

wdsm_ci_version3 <- function(Y, X, A, w, M = 3, B = 5, alpha = 0.05) {
  n <- length(Y)
  
  cat("\n  VERSION 3: Bootstrap with Design Effect\n")
  tau_hat <- calculate_wdsm_base(Y, X, A, w, M)
  cat("  Point estimate:", round(tau_hat, 4), "\n")
  
  tau_boot <- numeric(B)
  cat("  Bootstrap progress: ")
  
  for (b in 1:B) {
    cat(b, "")
    w_normalized <- w / sum(w)
    boot_idx <- sample(1:n, size = n, replace = TRUE, prob = w_normalized)
    
    w_b <- numeric(n)
    for (i in 1:n) {
      w_b[i] <- w[i] * sum(boot_idx == i)
    }
    
    selected <- w_b > 0
    if (sum(selected) < 10) {
      tau_boot[b] <- NA
      next
    }
    
    tau_boot[b] <- calculate_wdsm_base(Y[selected], X[selected, , drop = FALSE], 
                                      A[selected], w_b[selected], M, show_progress = FALSE)
  }
  cat("\n")
  
  V_boot <- var(tau_boot[is.finite(tau_boot)])
  n_eff <- sum(w)^2 / sum(w^2)
  design_effect <- n / n_eff
  V_adj <- V_boot * design_effect
  
  se <- sqrt(V_adj)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  
  cat("  Bootstrap estimates:", round(tau_boot[!is.na(tau_boot)], 4), "\n")
  cat("  Design effect:", round(design_effect, 3), "\n")
  cat("  SE:", round(se, 4), " CI:", round(ci_normal, 4), "\n")
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_normal,
    method = "Version 3"
  ))
}

wdsm_ci_version4 <- function(Y, X, A, w, M = 3, B = 5, alpha = 0.05) {
  n <- length(Y)
  
  cat("\n  VERSION 4: Linearized Bootstrap\n")
  result <- calculate_wdsm_base(Y, X, A, w, M, return_components = TRUE)
  tau_hat <- result$tau_hat
  cat("  Point estimate:", round(tau_hat, 4), "\n")
  
  tau_boot <- numeric(B)
  cat("  Bootstrap progress: ")
  
  for (b in 1:B) {
    cat(b, "")
    p <- w / sum(w)
    m_star <- as.numeric(rmultinom(1, n, p))
    omega_star <- m_star / n
    w_b <- omega_star * w
    
    # Re-estimate scores
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
    
    # Linearized form
    tau_boot[b] <- sum(w_b * (mu_hat_1_b - mu_hat_0_b)) / sum(w_b)
    
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
  cat("\n")
  
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  ci_percentile <- quantile(tau_boot, c(alpha/2, 1 - alpha/2))
  
  cat("  Bootstrap estimates:", round(tau_boot, 4), "\n")
  cat("  SE:", round(se, 4), " CI:", round(ci_normal, 4), "\n")
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_percentile,
    method = "Version 4"
  ))
}

wdsm_ci_version5 <- function(Y, X, A, w, M = 3, B = 5, alpha = 0.05) {
  n <- length(Y)
  
  cat("\n  VERSION 5: Two-Stage with Fixed Reuse\n")
  result <- calculate_wdsm_base(Y, X, A, w, M, return_components = TRUE)
  tau_hat <- result$tau_hat
  K_S0 <- result$K_S0
  K_S1 <- result$K_S1
  cat("  Point estimate:", round(tau_hat, 4), "\n")
  
  tau_boot <- numeric(B)
  cat("  Bootstrap progress: ")
  
  for (b in 1:B) {
    cat(b, "")
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
    
    # Calculate with fixed reuse counts
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
  cat("\n")
  
  se <- sd(tau_boot)
  ci_normal <- c(tau_hat - qnorm(1 - alpha/2) * se, 
                 tau_hat + qnorm(1 - alpha/2) * se)
  ci_percentile <- quantile(tau_boot, c(alpha/2, 1 - alpha/2))
  
  cat("  Bootstrap estimates:", round(tau_boot, 4), "\n")
  cat("  SE:", round(se, 4), " CI:", round(ci_normal, 4), "\n")
  
  return(list(
    tau_hat = tau_hat,
    se = se,
    ci_normal = ci_normal,
    ci_percentile = ci_percentile,
    method = "Version 5"
  ))
}

# Main execution
cat("=== SMALL SCALE TEST: 10 RESAMPLINGS, 5 BOOTSTRAP ===\n")
cat("Loading data and setting up...\n\n")

# Generate the super population data
source("SW_PSW-main/Super_Population_GoodOvelap.R")

# Extract population parameters
data_pop <- data_sets[[1]]
true_pate <- mean(data_pop$y1) - mean(data_pop$y0)
cat("True PATE:", round(true_pate, 4), "\n")

# Define sampling parameters
size1 <- rep(100000, 10)
size2 <- rep(5, 10)
size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
           rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
           rep(250/5, 5), rep(150/5, 5))

# Initialize results storage
results <- data.frame()

# Run 10 simulations
n_sims <- 10
B_boot <- 5

for (sim in 1:n_sims) {
  cat("\n", paste(rep("=", 60), collapse=""), "\n")
  cat("SIMULATION", sim, "of", n_sims, "\n")
  cat(paste(rep("=", 60), collapse=""), "\n")
  
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
  
  cat("\nSample size:", length(Y), "(Treated:", sum(A), "Control:", sum(1-A), ")\n")
  cat("Effective sample size:", round(sum(w)^2 / sum(w^2), 1), "\n")
  
  # Run all 5 methods
  tryCatch({
    # Version 1
    res1 <- wdsm_ci_version1(Y, X, A, w, M = 3, B = B_boot)
    
    # Version 2
    res2 <- wdsm_ci_version2(Y, X, A, w, M = 3, B = B_boot)
    
    # Version 3
    res3 <- wdsm_ci_version3(Y, X, A, w, M = 3, B = B_boot)
    
    # Version 4
    res4 <- wdsm_ci_version4(Y, X, A, w, M = 3, B = B_boot)
    
    # Version 5
    res5 <- wdsm_ci_version5(Y, X, A, w, M = 3, B = B_boot)
    
    # Store results
    sim_results <- data.frame(
      Simulation = sim,
      Method = c("V1", "V2", "V3", "V4", "V5"),
      Estimate = c(res1$tau_hat, res2$tau_hat, res3$tau_hat, res4$tau_hat, res5$tau_hat),
      Bias = c(res1$tau_hat, res2$tau_hat, res3$tau_hat, res4$tau_hat, res5$tau_hat) - true_pate,
      SE = c(res1$se, res2$se, res3$se, res4$se, res5$se),
      CI_Lower = c(res1$ci_normal[1], res2$ci_normal[1], res3$ci_normal[1], 
                   res4$ci_normal[1], res5$ci_normal[1]),
      CI_Upper = c(res1$ci_normal[2], res2$ci_normal[2], res3$ci_normal[2], 
                   res4$ci_normal[2], res5$ci_normal[2]),
      Covered = c(
        true_pate >= res1$ci_normal[1] & true_pate <= res1$ci_normal[2],
        true_pate >= res2$ci_normal[1] & true_pate <= res2$ci_normal[2],
        true_pate >= res3$ci_normal[1] & true_pate <= res3$ci_normal[2],
        true_pate >= res4$ci_normal[1] & true_pate <= res4$ci_normal[2],
        true_pate >= res5$ci_normal[1] & true_pate <= res5$ci_normal[2]
      )
    )
    
    results <- rbind(results, sim_results)
    
  }, error = function(e) {
    cat("\nError in simulation", sim, ":", e$message, "\n")
  })
}

# Calculate summary statistics
cat("\n\n", paste(rep("=", 60), collapse=""), "\n")
cat("SUMMARY RESULTS\n")
cat(paste(rep("=", 60), collapse=""), "\n\n")

summary_by_method <- aggregate(
  cbind(Estimate, Bias, SE, Covered) ~ Method, 
  data = results,
  FUN = function(x) c(mean = mean(x), sd = sd(x))
)

# Format output
method_names <- c("V1: Standard Bootstrap", 
                  "V2: Exponential Weights", 
                  "V3: Design Effect", 
                  "V4: Linearized", 
                  "V5: Fixed Reuse")

for (i in 1:5) {
  method <- paste0("V", i)
  method_data <- summary_by_method[summary_by_method$Method == method, ]
  
  cat("\n", method_names[i], "\n")
  cat("  Mean Estimate:", round(method_data$Estimate[, "mean"], 4), "\n")
  cat("  Mean Bias:", round(method_data$Bias[, "mean"], 4), 
      "(Relative:", round(method_data$Bias[, "mean"] / true_pate * 100, 2), "%)\n")
  cat("  Mean SE:", round(method_data$SE[, "mean"], 4), "\n")
  cat("  Coverage:", round(method_data$Covered[, "mean"] * 100, 0), "%\n")
}

# Save results
save(results, true_pate, file = "wdsm_small_scale_results.RData")

cat("\n\nResults saved to wdsm_small_scale_results.RData\n")
cat("True PATE:", round(true_pate, 4), "\n") 