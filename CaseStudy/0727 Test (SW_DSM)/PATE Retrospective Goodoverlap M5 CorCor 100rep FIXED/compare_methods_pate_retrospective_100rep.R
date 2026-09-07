# Comprehensive Method Comparison Script for PATE Retrospective Sampling
# Scenario: CorCor - Both PS and PGS correct
# TRUE 100 REPLICATIONS - FIXED VERSION

# Clear environment
rm(list = ls())
gc()

# Load required libraries
library(parallel)
library(doParallel)
library(foreach)
library(MASS)
library(nnet)
library(MatchIt)
library(boot)
library(survey)
library(marginaleffects)
library(R.utils)

# Source the required functions
source("wdsm_ci_functions.R")
source("wdsm_method2_multinomial_bootstrap.R")
source("dsmatch-master/R/dsmatchATE.R")

# HARDCODED SCENARIO CONFIGURATION
scenario_name <- "CorCor"
use_interaction_ps <- TRUE
use_interaction_pg <- TRUE

cat("\n", strrep("=", 80), "\n")
cat("STARTING SIMULATION: SCENARIO", scenario_name, "\n")
cat("PS interaction:", use_interaction_ps, "\n")
cat("PG interaction:", use_interaction_pg, "\n")
cat(strrep("=", 80), "\n\n")

# Set simulation parameters
n_reps <- 100  # TRUE 100 REPLICATIONS
n_sample <- 500
M <- 5  # Fixed M value
B <- 200
alpha <- 0.05
true_pate <- 0.866

# Load population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")

# Function to run a single replicate
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M, B, alpha) {
  
  tryCatch({
    # Sample from population
    sampled_indices <- sample(nrow(population), n_sample, replace = FALSE)
    sample_data <- population[sampled_indices, ]
    
    # Extract components
    Y <- sample_data$Y
    A <- sample_data$A
    X1 <- sample_data$X1
    X2 <- sample_data$X2
    X3 <- sample_data$X3
    X4 <- sample_data$X4
    X5 <- sample_data$X5
    X6 <- sample_data$X6
    pi <- sample_data$pi
    
    # Create survey weights
    sw <- 1/pi
    
    # Build covariate matrices based on scenario
    if (use_interaction_ps) {
      X_ps <- cbind(X1, X2, X3, X4, X5, X6, X1*X2)
      colnames(X_ps) <- c("X1", "X2", "X3", "X4", "X5", "X6", "X1:X2")
    } else {
      X_ps <- cbind(X1, X2, X3, X4, X5, X6)
      colnames(X_ps) <- c("X1", "X2", "X3", "X4", "X5", "X6")
    }
    
    if (use_interaction_pg) {
      X_pg <- cbind(X1, X2, X3, X4, X5, X6, X1*X2)
      colnames(X_pg) <- c("X1", "X2", "X3", "X4", "X5", "X6", "X1:X2")
    } else {
      X_pg <- cbind(X1, X2, X3, X4, X5, X6)
      colnames(X_pg) <- c("X1", "X2", "X3", "X4", "X5", "X6")
    }
    
    # Initialize results
    results <- list()
    
    # 1. Unweighted DSM
    dsm_result <- dsmatchATE(
      Y = Y,
      X = X_ps,
      A = A,
      method = "dsm",
      model.ps = "logit",
      model.pg = "linpred",
      lp.pg = X_pg,
      M = M,
      cov.balance = FALSE,
      varest = TRUE,
      boots = B,
      mc = FALSE,
      ncpus = 1
    )
    
    results$dsm_unweighted <- list(
      estimate = dsm_result$ATE,
      se = dsm_result$SE.ATE,
      ci_lower = dsm_result$ATE - qnorm(1-alpha/2) * dsm_result$SE.ATE,
      ci_upper = dsm_result$ATE + qnorm(1-alpha/2) * dsm_result$SE.ATE
    )
    
    # 2. Unweighted PG matching
    pg_result <- dsmatchATE(
      Y = Y,
      X = X_pg,
      A = A,
      method = "pg",
      model.pg = "glm",
      M = M,
      cov.balance = FALSE,
      varest = TRUE,
      boots = B,
      mc = FALSE,
      ncpus = 1
    )
    
    results$pg_unweighted <- list(
      estimate = pg_result$ATE,
      se = pg_result$SE.ATE,
      ci_lower = pg_result$ATE - qnorm(1-alpha/2) * pg_result$SE.ATE,
      ci_upper = pg_result$ATE + qnorm(1-alpha/2) * pg_result$SE.ATE
    )
    
    # 3. Unweighted PS matching
    ps_result <- dsmatchATE(
      Y = Y,
      X = X_ps,
      A = A,
      method = "ps",
      model.ps = "logit",
      M = M,
      cov.balance = FALSE,
      varest = TRUE,
      boots = B,
      mc = FALSE,
      ncpus = 1
    )
    
    results$ps_unweighted <- list(
      estimate = ps_result$ATE,
      se = ps_result$SE.ATE,
      ci_lower = ps_result$ATE - qnorm(1-alpha/2) * ps_result$SE.ATE,
      ci_upper = ps_result$ATE + qnorm(1-alpha/2) * ps_result$SE.ATE
    )
    
    # 4. Survey-weighted PS Full matching
    data_for_matchit <- data.frame(
      Y = Y, A = A, X1 = X1, X2 = X2, X3 = X3, 
      X4 = X4, X5 = X5, X6 = X6, sw = sw
    )
    
    # PS formula based on scenario
    if (use_interaction_ps) {
      ps_formula_matchit <- A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
    } else {
      ps_formula_matchit <- A ~ X1 + X2 + X3 + X4 + X5 + X6
    }
    
    m_sw <- matchit(ps_formula_matchit, 
                    data = data_for_matchit,
                    method = "full",
                    distance = "glm",
                    link = "logit",
                    s.weights = data_for_matchit$sw)
    
    md_sw <- match.data(m_sw, weights = "sw")
    
    # Outcome model ALWAYS correctly specified for bias correction
    outcome_formula <- Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2)
    fit_sw <- lm(outcome_formula, data = md_sw, weights = weights)
    
    ate_sw <- avg_comparisons(fit_sw, 
                              variables = "A", 
                              vcov = ~subclass,
                              newdata = md_sw,
                              wts = "sw")
    
    results$ps_weighted <- list(
      estimate = ate_sw$estimate,
      se = ate_sw$std.error,
      ci_lower = ate_sw$conf.low,
      ci_upper = ate_sw$conf.high
    )
    
    # 5. WDSM with multinomial bootstrap
    data_wdsm <- data.frame(
      Y = Y, A = A, X1 = X1, X2 = X2, X3 = X3,
      X4 = X4, X5 = X5, X6 = X6, weights = sw
    )
    
    wdsm_result <- wdsm_multinomial_bootstrap(
      data = data_wdsm,
      sampling = "retrospective",
      estimand = "PATE",
      B = B,
      alpha = alpha,
      use_interaction_ps = use_interaction_ps,
      use_interaction_pg = use_interaction_pg
    )
    
    results$wdsm_multinomial <- list(
      estimate = wdsm_result$estimate,
      se = wdsm_result$se,
      ci_lower = wdsm_result$ci[1],
      ci_upper = wdsm_result$ci[2]
    )
    
    return(results)
    
  }, error = function(e) {
    cat("Error in replicate", i.rep, ":", e$message, "\n")
    return(NULL)
  })
}

# Set up parallel processing
n_cores <- 20
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

# Run simulation with progress reporting
cat("Starting", n_reps, "replications on", n_cores, "cores...\n")
start_time <- Sys.time()

all_results <- foreach(i = 1:n_reps, 
                       .combine = 'c',
                       .errorhandling = 'pass',
                       .options.future = list(seed = TRUE)) %dopar% {
  if (i %% 10 == 0) cat("Completed", i, "replications\n")
  list(run_single_replicate(i, population, true_pate, n_sample, M, B, alpha))
}

# Stop cluster
stopCluster(cl)

# Process results
valid_results <- all_results[!sapply(all_results, is.null)]
cat("\nSuccessfully completed", length(valid_results), "out of", n_reps, "replications\n")

# Convert to data frame
summary_data <- data.frame()
for (i in 1:length(valid_results)) {
  rep_results <- valid_results[[i]]
  for (method_name in names(rep_results)) {
    summary_data <- rbind(summary_data, data.frame(
      Replicate = i,
      Method = method_name,
      Estimate = rep_results[[method_name]]$estimate,
      SE = rep_results[[method_name]]$se,
      CI_Lower = rep_results[[method_name]]$ci_lower,
      CI_Upper = rep_results[[method_name]]$ci_upper,
      M = M,
      Scenario = scenario_name
    ))
  }
}

# Calculate summary statistics
summary_stats <- summary_data %>%
  group_by(Method) %>%
  summarise(
    Mean_Estimate = mean(Estimate, na.rm = TRUE),
    Bias = mean(Estimate, na.rm = TRUE) - true_pate,
    Mean_SE = mean(SE, na.rm = TRUE),
    Empirical_SD = sd(Estimate, na.rm = TRUE),
    Relative_Bias = (mean(Estimate, na.rm = TRUE) - true_pate) / true_pate,
    Coverage = mean(CI_Lower <= true_pate & CI_Upper >= true_pate, na.rm = TRUE),
    CI_Width = mean(CI_Upper - CI_Lower, na.rm = TRUE),
    .groups = 'drop'
  )

# Add relative efficiency
ps_var <- summary_stats$Empirical_SD[summary_stats$Method == "ps_unweighted"]^2
summary_stats$Relative_Efficiency <- ps_var / (summary_stats$Empirical_SD^2)

# Clean method names
summary_stats$Method <- case_when(
  summary_stats$Method == "dsm_unweighted" ~ "DSM (Unweighted)",
  summary_stats$Method == "pg_unweighted" ~ "PG (Unweighted)",
  summary_stats$Method == "ps_unweighted" ~ "PS (Unweighted)",
  summary_stats$Method == "ps_weighted" ~ "PS Full (Survey-Weighted)",
  summary_stats$Method == "wdsm_multinomial" ~ "WDSM (Multinomial Bootstrap)",
  TRUE ~ summary_stats$Method
)

# Print results
cat("\n", strrep("=", 80), "\n")
cat("SIMULATION COMPLETE: SCENARIO", scenario_name, "\n")
cat(strrep("=", 80), "\n")

print(summary_stats)

# Save results
save(all_results, summary_data, summary_stats, n_reps, n_sample, M, B, true_pate,
     file = paste0("pate_retrospective_100rep_", tolower(scenario_name), "_results.RData"))

write.csv(summary_stats, 
          paste0("pate_retrospective_100rep_", tolower(scenario_name), "_summary.csv"),
          row.names = FALSE)

end_time <- Sys.time()
cat("\nTotal runtime:", difftime(end_time, start_time, units = "mins"), "minutes\n")
