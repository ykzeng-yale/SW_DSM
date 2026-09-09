#!/usr/bin/env Rscript

# Test WDSM with SW_PSW-main Simulation Design
# Tests both PATE and PATT under prospective and retrospective sampling

# Required packages
library(survey)         
library(doParallel)     
library(foreach)        
library(data.table)     
library(sampling)       
library(MatchIt)        
library(MASS)           
library(boot)           

# Load WDSM package
devtools::load_all("WDSM")

# Set parameters (smaller for testing)
N <- 100000      # Reduced population size for testing
n.reps <- 500    # Number of simulation replicates
n_covar <- 6     # Number of covariates (excluding interaction)
n_strata <- 10   # Number of strata
n_cluster <- 20  # Number of clusters per stratum
tau_strata <- 0.35
tau_cluster <- 0.15
min_prob <- 0.000

# Set seed for reproducibility
set.seed(20220930)

cat("=== WDSM Simulation with SW_PSW Design ===\n")
cat("Population size:", N, "\n")
cat("Number of replications:", n.reps, "\n")
cat("Testing: PATE and PATT under prospective and retrospective sampling\n\n")

############################################################################################################################
# Generate Super Population (adapted from SW_PSW-main)
############################################################################################################################

cat("Generating super population...\n")

# Generate strata and cluster effects
mu_strata <- matrix(rnorm(n_strata * n_covar, mean = 0, sd = tau_strata), nrow = n_strata, ncol = n_covar)
mu_cluster <- matrix(rnorm(n_cluster * n_covar, mean = 0, sd = tau_cluster), nrow = n_cluster, ncol = n_covar)

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
        rnorm(N / (n_strata * n_cluster), mean = mu_cluster[cluster, variable] + mu_strata[strata, variable])
      )
      colnames(data) <- c("Cluster", "Strata", paste("X", variable, sep = ""))
      cluster_l[[cluster]] <- data
    }
    strata_l[[strata]] <- do.call("rbind", cluster_l)
  }
  variable_l[[variable]] <- data.frame(do.call("rbind", strata_l))
}

# Combine all covariates
data <- variable_l[[1]]
for (variable in 2:n_covar) {
  data <- cbind(data, variable_l[[variable]][, 3])
}
colnames(data) <- c("Cluster", "Strata", paste0("x", 1:n_covar))

# Propensity score model
expit <- function(x) { exp(x) / (1 + exp(x)) }

a0 <- log(35 / 80)
a1 <- log(1.10)
a2 <- log(1.25)
a3 <- log(1.50)
a4 <- log(1.75)
a5 <- log(2.00)
a6 <- log(2.50)
a7 <- log(1.10)  # Interaction
delta_z <- 0.6

formula_ps <- a0 + delta_z * (a1 * data$x1 + a2 * data$x2 + a3 * data$x3 + 
                               a4 * data$x4 + a5 * data$x5 + a6 * data$x6 + 
                               a7 * data$x1 * data$x2)

data$prob_treat <- expit(formula_ps)
data$z <- rbinom(N, 1, data$prob_treat)

# Outcome model
b0 <- 0.00
b1 <- 2.50
b2 <- -2.00
b3 <- 1.75
b4 <- -1.25
b5 <- 1.50
b6 <- 1.10
b70 <- 2.50  # Interaction in y0
b71 <- 1.50  # Interaction in y1
delta0 <- 0.3
delta1 <- 1
delta2 <- 0.2

data$y0 <- b0 + delta0 * (b1 * data$x1 + b2 * data$x2 + b3 * data$x3 + 
                          b4 * data$x4 + b5 * data$x5 + b6 * data$x6 + 
                          b70 * data$x1 * data$x2) + rnorm(N)

data$y1 <- data$y0 + delta1 + delta2 * (b1 * data$x1 + b2 * data$x2 + b3 * data$x3 + 
                                         b4 * data$x4 + b5 * data$x5 + b6 * data$x6 + 
                                         b71 * data$x1 * data$x2) + rnorm(N)

data$y <- data$z * data$y1 + (1 - data$z) * data$y0
data$ones <- 1
data$id <- 1:nrow(data)

# Calculate true population parameters
PATE_true <- mean(data$y1) - mean(data$y0)
PATT_true <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])

cat("\nTrue population parameters:\n")
cat("PATE =", round(PATE_true, 4), "\n")
cat("PATT =", round(PATT_true, 4), "\n\n")

############################################################################################################################
# Sampling Functions
############################################################################################################################

# Prospective sampling (multi-stage)
prospective_sampling <- function(data) {
  size1 <- rep(N/n_strata, n_strata)  # Strata sizes
  size2 <- rep(5, n_strata)            # Clusters per stratum
  # Variable cluster sizes to get total sample ~0.5% of N
  size3 <- c(rep(17, 25), rep(15, 25), rep(14, 25), rep(13, 25),
             rep(12, 25), rep(8, 25), rep(7, 25), rep(6, 25),
             rep(5, 25), rep(3, 25))
  
  s <- mstage(data, stage = list("stratified", "cluster", ""),
              varnames = list("Strata", "Cluster", "ones"),
              size = list(size1, size2, size3),
              method = list("", "srswor", "srswor"))
  
  sample <- getdata(data, s)[[3]]
  sample$s.wt <- 1 / sample$Prob
  return(sample)
}

# Retrospective sampling (depends on treatment)
retrospective_sampling <- function(data) {
  c0 <- log(0.005 / (1 - 0.005))
  c1 <- log(1.05)
  c2 <- log(1.10)
  c3 <- log(1.15)
  c4 <- log(1.10)
  c5 <- log(1.05)
  c6 <- log(1.10)
  delta_z_in_s <- log(0.9)  # Treatment effect on sampling
  
  formula_S <- c0 + delta_z_in_s * data$z + c1 * data$x1 + c2 * data$x2 +
               c3 * data$x3 + c4 * data$x4 + c5 * data$x5 + c6 * data$x6
  
  prob_S <- expit(formula_S)
  data$Prob <- prob_S
  data$S <- rbinom(N, 1, prob_S)
  sample <- data[data$S == 1, ]
  
  # Calculate treatment-specific weights
  sample$prob_S0 <- expit(c0 + c1 * sample$x1 + c2 * sample$x2 + 
                         c3 * sample$x3 + c4 * sample$x4 + 
                         c5 * sample$x5 + c6 * sample$x6)
  sample$prob_S1 <- expit(c0 + delta_z_in_s + c1 * sample$x1 + c2 * sample$x2 + 
                         c3 * sample$x3 + c4 * sample$x4 + 
                         c5 * sample$x5 + c6 * sample$x6)
  
  sample$s.wt0 <- 1 / sample$prob_S0
  sample$s.wt1 <- 1 / sample$prob_S1
  sample$s.wt <- 1 / sample$Prob
  
  return(sample)
}

############################################################################################################################
# Run Simulation
############################################################################################################################

# Set up parallel processing
ncores <- min(4, parallel::detectCores() - 1)
cl <- makeCluster(ncores)
registerDoParallel(cl)

# Run simulations in parallel
results_list <- foreach(i.rep = 1:n.reps, 
                       .packages = c("survey", "MatchIt", "sampling", "Matching"),
                       .combine = rbind) %dopar% {
  
  set.seed(20220930 + i.rep)
  
  # Results storage
  results <- list()
  
  # Test 1: Prospective PATE
  sample_pros <- prospective_sampling(data)
  X_sample <- as.matrix(sample_pros[, paste0("x", 1:6)])
  
  # Create interaction term
  X_with_inter <- cbind(X_sample, X_sample[,1] * X_sample[,2])
  
  tryCatch({
    res_pros_pate <- wdsmatchPATE_prospective(
      Y = sample_pros$y,
      X = X_with_inter,
      A = sample_pros$z,
      weights = sample_pros$s.wt,
      method = "dsm",
      M = 3,
      model.ps = "logit",
      model.pg = "glm",
      bias.correct = TRUE,
      varest = TRUE,
      boots = 100
    )
    
    results$pros_pate_est <- res_pros_pate$est.dsm
    results$pros_pate_covered <- (PATE_true >= res_pros_pate$bootq1) & 
                                 (PATE_true <= res_pros_pate$bootq2)
    results$pros_pate_ci_width <- res_pros_pate$bootq2 - res_pros_pate$bootq1
  }, error = function(e) {
    results$pros_pate_est <- NA
    results$pros_pate_covered <- NA
    results$pros_pate_ci_width <- NA
  })
  
  # Test 2: Prospective PATT
  tryCatch({
    res_pros_patt <- wdsmatchPATT_prospective(
      Y = sample_pros$y,
      X = X_with_inter,
      A = sample_pros$z,
      weights = sample_pros$s.wt,
      method = "dsm",
      M = 3,
      model.ps = "logit",
      model.pg = "glm",
      bias.correct = TRUE,
      varest = TRUE,
      boots = 100
    )
    
    results$pros_patt_est <- res_pros_patt$est.dsm
    results$pros_patt_covered <- (PATT_true >= res_pros_patt$bootq1) & 
                                (PATT_true <= res_pros_patt$bootq2)
    results$pros_patt_ci_width <- res_pros_patt$bootq2 - res_pros_patt$bootq1
  }, error = function(e) {
    results$pros_patt_est <- NA
    results$pros_patt_covered <- NA
    results$pros_patt_ci_width <- NA
  })
  
  # Test 3: Retrospective PATE
  sample_retro <- retrospective_sampling(data)
  X_retro <- as.matrix(sample_retro[, paste0("x", 1:6)])
  X_retro_inter <- cbind(X_retro, X_retro[,1] * X_retro[,2])
  
  tryCatch({
    res_retro_pate <- wdsmatchPATE_retrospective(
      Y = sample_retro$y,
      X = X_retro_inter,
      A = sample_retro$z,
      weights0 = sample_retro$s.wt0,
      weights1 = sample_retro$s.wt1,
      method = "dsm",
      M = 3,
      model.ps = "logit",
      model.pg = "glm",
      bias.correct = TRUE,
      varest = TRUE,
      boots = 100
    )
    
    results$retro_pate_est <- res_retro_pate$est.dsm
    results$retro_pate_covered <- (PATE_true >= res_retro_pate$bootq1) & 
                                 (PATE_true <= res_retro_pate$bootq2)
    results$retro_pate_ci_width <- res_retro_pate$bootq2 - res_retro_pate$bootq1
  }, error = function(e) {
    results$retro_pate_est <- NA
    results$retro_pate_covered <- NA
    results$retro_pate_ci_width <- NA
  })
  
  # Test 4: Retrospective PATT
  tryCatch({
    res_retro_patt <- wdsmatchPATT_retrospective(
      Y = sample_retro$y,
      X = X_retro_inter,
      A = sample_retro$z,
      weights0 = sample_retro$s.wt0,
      weights1 = sample_retro$s.wt1,
      method = "dsm",
      M = 3,
      model.ps = "logit",
      model.pg = "glm",
      bias.correct = TRUE,
      varest = TRUE,
      boots = 100
    )
    
    results$retro_patt_est <- res_retro_patt$est.dsm
    results$retro_patt_covered <- (PATT_true >= res_retro_patt$bootq1) & 
                                 (PATT_true <= res_retro_patt$bootq2)
    results$retro_patt_ci_width <- res_retro_patt$bootq2 - res_retro_patt$bootq1
  }, error = function(e) {
    results$retro_patt_est <- NA
    results$retro_patt_covered <- NA
    results$retro_patt_ci_width <- NA
  })
  
  # Return results as data frame row
  data.frame(
    rep = i.rep,
    pros_pate_est = results$pros_pate_est,
    pros_pate_covered = results$pros_pate_covered,
    pros_pate_ci_width = results$pros_pate_ci_width,
    pros_patt_est = results$pros_patt_est,
    pros_patt_covered = results$pros_patt_covered,
    pros_patt_ci_width = results$pros_patt_ci_width,
    retro_pate_est = results$retro_pate_est,
    retro_pate_covered = results$retro_pate_covered,
    retro_pate_ci_width = results$retro_pate_ci_width,
    retro_patt_est = results$retro_patt_est,
    retro_patt_covered = results$retro_patt_covered,
    retro_patt_ci_width = results$retro_patt_ci_width
  )
}

# Stop cluster
stopCluster(cl)

############################################################################################################################
# Analyze Results
############################################################################################################################

cat("\n=== SIMULATION RESULTS ===\n\n")

# Remove failed simulations
results_clean <- results_list[complete.cases(results_list), ]
n_valid <- nrow(results_clean)
cat("Valid simulations:", n_valid, "out of", n.reps, "\n\n")

# Function to calculate and display results
analyze_results <- function(est_col, covered_col, width_col, true_val, label) {
  estimates <- results_clean[[est_col]]
  covered <- results_clean[[covered_col]]
  widths <- results_clean[[width_col]]
  
  bias <- mean(estimates) - true_val
  rel_bias <- 100 * bias / abs(true_val)
  coverage <- mean(covered)
  avg_width <- mean(widths)
  
  cat(label, "\n")
  cat("  True value:", round(true_val, 4), "\n")
  cat("  Average estimate:", round(mean(estimates), 4), "\n")
  cat("  Bias:", round(bias, 4), "\n")
  cat("  Relative bias:", round(rel_bias, 2), "%\n")
  cat("  95% CI coverage:", round(coverage, 3), 
      ifelse(coverage >= 0.93 & coverage <= 0.97, " ✓", " ✗"), "\n")
  cat("  Average CI width:", round(avg_width, 4), "\n\n")
  
  return(list(bias = bias, rel_bias = rel_bias, coverage = coverage))
}

# Analyze all scenarios
pros_pate_res <- analyze_results("pros_pate_est", "pros_pate_covered", 
                                "pros_pate_ci_width", PATE_true, 
                                "Prospective PATE:")

pros_patt_res <- analyze_results("pros_patt_est", "pros_patt_covered", 
                                "pros_patt_ci_width", PATT_true, 
                                "Prospective PATT:")

retro_pate_res <- analyze_results("retro_pate_est", "retro_pate_covered", 
                                 "retro_pate_ci_width", PATE_true, 
                                 "Retrospective PATE:")

retro_patt_res <- analyze_results("retro_patt_est", "retro_patt_covered", 
                                 "retro_patt_ci_width", PATT_true, 
                                 "Retrospective PATT:")

# Summary table
cat("=== SUMMARY TABLE ===\n\n")
summary_df <- data.frame(
  Estimand = c("PATE", "PATE", "PATT", "PATT"),
  Sampling = c("Prospective", "Retrospective", "Prospective", "Retrospective"),
  "Rel_Bias_%" = round(c(pros_pate_res$rel_bias, retro_pate_res$rel_bias,
                         pros_patt_res$rel_bias, retro_patt_res$rel_bias), 2),
  Coverage = round(c(pros_pate_res$coverage, retro_pate_res$coverage,
                     pros_patt_res$coverage, retro_patt_res$coverage), 3),
  "In_Range" = c(pros_pate_res$coverage >= 0.93 & pros_pate_res$coverage <= 0.97,
                 retro_pate_res$coverage >= 0.93 & retro_pate_res$coverage <= 0.97,
                 pros_patt_res$coverage >= 0.93 & pros_patt_res$coverage <= 0.97,
                 retro_patt_res$coverage >= 0.93 & retro_patt_res$coverage <= 0.97)
)
print(summary_df)

# Save results
save(results_list, results_clean, summary_df, 
     file = "WDSM_simulation_results_SW_PSW_design.RData")

cat("\nResults saved to WDSM_simulation_results_SW_PSW_design.RData\n")

# Create visualization
library(ggplot2)
library(tidyr)

# Prepare data for plotting
plot_data <- results_clean %>%
  select(pros_pate_est, pros_patt_est, retro_pate_est, retro_patt_est) %>%
  pivot_longer(everything(), names_to = "method", values_to = "estimate") %>%
  mutate(
    Estimand = ifelse(grepl("pate", method), "PATE", "PATT"),
    Sampling = ifelse(grepl("pros", method), "Prospective", "Retrospective")
  )

# Add true values
plot_data$true_value <- ifelse(plot_data$Estimand == "PATE", PATE_true, PATT_true)

# Create boxplot
p <- ggplot(plot_data, aes(x = interaction(Estimand, Sampling), y = estimate)) +
  geom_boxplot(aes(fill = Sampling), alpha = 0.6) +
  geom_hline(data = data.frame(Estimand = c("PATE", "PATT"), 
                               true_value = c(PATE_true, PATT_true)),
             aes(yintercept = true_value), 
             color = "red", linetype = "dashed", size = 1) +
  facet_wrap(~ Estimand, scales = "free_x") +
  scale_fill_manual(values = c("Prospective" = "lightblue", "Retrospective" = "lightgreen")) +
  labs(x = "Estimand and Sampling Design",
       y = "Estimate",
       title = "WDSM Performance with SW_PSW Simulation Design",
       subtitle = "Red dashed line indicates true value") +
  theme_minimal(base_size = 14) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("WDSM_simulation_boxplot.pdf", p, width = 10, height = 6)
cat("\nBoxplot saved to WDSM_simulation_boxplot.pdf\n")

cat("\n=== SIMULATION COMPLETE ===\n") 