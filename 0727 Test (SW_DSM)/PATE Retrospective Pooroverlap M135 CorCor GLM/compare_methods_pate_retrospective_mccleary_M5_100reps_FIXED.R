# Poor Overlap PATE Retrospective Comparison - M=5, 100 reps - FIXED VERSION
# Fixed DSM, PG, PS model specifications to handle PS and PG independently

# Load packages
library(survey)
library(sampling)
library(MASS)
library(nnet)
library(MatchIt)
library(parallel)
library(doParallel)
library(foreach)
library(boot)
library(marginaleffects)
library(R.utils)

# Set random seed for reproducibility
set.seed(123)

# Source custom functions
source("dsmatch-master/R/dsmatchATE.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/bisect.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.pg.R")
source("wdsm_ci_functions.R")
source("wdsm_method2_multinomial_bootstrap.R")

# Function to perform retrospective sampling
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Stratified sampling on A
  n1 <- floor(n_sample / 2)
  n0 <- n_sample - n1
  
  # Sample indices
  idx1 <- sample(which(population$A == 1), n1, replace = FALSE)
  idx0 <- sample(which(population$A == 0), n0, replace = FALSE)
  
  # Combine samples
  idx <- c(idx1, idx0)
  sample_data <- population[idx, ]
  
  # Calculate sampling weights
  N1 <- sum(population$A == 1)
  N0 <- N - N1
  sample_data$sw <- ifelse(sample_data$A == 1, N1/n1, N0/n0)
  
  return(sample_data)
}

# Function to run a single replicate (FIXED)
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M_values, B, alpha, scenarios) {
  
  # Set timeout for this replicate
  setTimeLimit(cpu = 900, elapsed = 900)
  
  tryCatch({
    # Perform retrospective sampling
    sample_data <- retrospective_sample(population, n_sample)
    
    # Extract variables
    Y <- sample_data$Y
    A <- sample_data$A
    X <- as.matrix(sample_data[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    w_raw <- sample_data$sw
    w_normalized <- w_raw * length(w_raw) / sum(w_raw)
    
    # Initialize results storage
    replicate_results <- list()
    
    # Loop over different model specification scenarios
    for (scenario in scenarios) {
      
      # Determine model specifications based on scenario
      use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
      use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
      
      # Loop over different M values
      for (M in M_values) {
        
        # Initialize results for this M value and scenario
        m_results <- list()
        
        # ============================================================
        # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING - FIXED
        # ============================================================
        tryCatch({
          # DSM needs to handle PS and PG specifications SEPARATELY
          
          # Run DSM with appropriate model specifications
          dsm_result <- dsmatchATE(
            Y = Y,
            X = X,
            A = A,
            method = "dsm",
            # PS model specification
            model.ps = if (use_interaction_ps) {
              "linpred"  # Use linear predictor with interaction
            } else {
              "logit"    # Use logit without interaction
            },
            lp.ps = if (use_interaction_ps) {
              cbind(X, X[,1] * X[,2])  # Provide X with interaction for PS
            } else {
              NULL
            },
            # PG model specification - FIXED to handle independently
            model.pg = "linpred",  # Always use linpred for PG
            lp.pg = if (use_interaction_pg) {
              cbind(X, X[,1] * X[,2])  # Provide X with interaction for PG
            } else {
              X  # Base X without interaction
            },
            M = M,
            cov.balance = FALSE,
            varest = TRUE,
            boots = B,
            mc = FALSE,
            ncpus = 1
          )
          
          m_results$dsm_unweighted <- list(
            estimate = dsm_result$est.ds,
            se = sqrt(dsm_result$bootvar[1,1]),
            ci_lower = dsm_result$est.ds - qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1]),
            ci_upper = dsm_result$est.ds + qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1])
          )
          
        }, error = function(e) {
          cat("DSM Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$dsm_unweighted <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 2: UNWEIGHTED PROGNOSTIC SCORE MATCHING - FIXED
        # ============================================================
        tryCatch({
          # PG matching should use correct specification
          pg_result <- dsmatchATE(
            Y = Y,
            X = X,
            A = A,
            method = "pg",
            model.pg = "linpred",
            lp.pg = if (use_interaction_pg) {
              cbind(X, X[,1] * X[,2])
            } else {
              X
            },
            M = M,
            cov.balance = FALSE,
            varest = TRUE,
            boots = B,
            mc = FALSE,
            ncpus = 1
          )
          
          m_results$pg_unweighted <- list(
            estimate = pg_result$est.pg,
            se = sqrt(pg_result$bootvar[1,1]),
            ci_lower = pg_result$est.pg - qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1]),
            ci_upper = pg_result$est.pg + qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1])
          )
          
        }, error = function(e) {
          cat("PG Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$pg_unweighted <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 3: UNWEIGHTED PROPENSITY SCORE MATCHING - FIXED
        # ============================================================
        tryCatch({
          # PS matching should use correct specification
          ps_result <- dsmatchATE(
            Y = Y,
            X = X,
            A = A,
            method = "ps",
            model.ps = if (use_interaction_ps) {
              "linpred"
            } else {
              "logit"
            },
            lp.ps = if (use_interaction_ps) {
              cbind(X, X[,1] * X[,2])
            } else {
              NULL
            },
            M = M,
            cov.balance = FALSE,
            varest = TRUE,
            boots = B,
            mc = FALSE,
            ncpus = 1
          )
          
          m_results$ps_unweighted <- list(
            estimate = ps_result$est.ps,
            se = sqrt(ps_result$bootvar[1,1]),
            ci_lower = ps_result$est.ps - qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1]),
            ci_upper = ps_result$est.ps + qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1])
          )
          
        }, error = function(e) {
          cat("PS Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$ps_unweighted <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 4: SURVEY-WEIGHTED PROPENSITY SCORE MATCHING (MatchIt)
        # ============================================================
        tryCatch({
          # Create data frame with normalized survey weights
          match_data_sw <- data.frame(
            Y = Y,
            A = A,
            X1 = X[,1],
            X2 = X[,2],
            X3 = X[,3],
            X4 = X[,4],
            X5 = X[,5],
            X6 = X[,6],
            sw = w_normalized
          )
          
          # PS formula based on scenario
          ps_formula <- if (use_interaction_ps) {
            A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
          } else {
            A ~ X1 + X2 + X3 + X4 + X5 + X6
          }
          
          # Run survey-weighted propensity score matching using full matching for ATE
          m_ps_sw <- matchit(
            ps_formula,
            data = match_data_sw,
            method = "full",
            distance = "glm",
            link = "logit",
            s.weights = ~ sw,
            estimand = "ATE"
          )
          
          # Extract matched data with combined weights
          md_sw <- match.data(m_ps_sw)
          
          # Outcome model formula based on PGS scenario
          outcome_formula <- if (use_interaction_pg) {
            Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2)
          } else {
            Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6)
          }
          
          # Fit outcome model with product weights
          fit_sw <- lm(outcome_formula,
                      data = md_sw,
                      weights = weights)
          
          # Estimate marginal ATE using g-computation
          ate_result <- avg_comparisons(
            fit_sw,
            variables = "A",
            vcov = ~subclass,
            wts = md_sw$sw
          )
          
          # Extract results
          m_results$ps_weighted <- list(
            estimate = ate_result$estimate,
            se = ate_result$std.error,
            ci_lower = ate_result$conf.low,
            ci_upper = ate_result$conf.high
          )
          
        }, error = function(e) {
          cat("PS Survey-Weighted Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$ps_weighted <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 5: WDSM with Multinomial Bootstrap
        # ============================================================
        tryCatch({
          # WDSM uses the scenario-specific covariate specifications
          ci_results <- compute_wdsm_method2_ci(
            Y = Y, 
            A = A, 
            X = X,
            weights = w_raw,
            M = M,
            n_bootstrap = B,
            alpha = alpha,
            use_bias_correction = TRUE,
            return_samples = FALSE,
            use_interaction_ps = use_interaction_ps,
            use_interaction_pg = use_interaction_pg
          )
          
          m_results$wdsm_multinomial <- list(
            estimate = ci_results$estimate,
            se = ci_results$se,
            ci_lower = ci_results$ci_lower,
            ci_upper = ci_results$ci_upper
          )
          
        }, error = function(e) {
          cat("WDSM Multinomial Bootstrap Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$wdsm_multinomial <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # Store results for this M value and scenario
        replicate_results[[paste0(scenario, "_M", M)]] <- m_results
        
      } # End of M loop
    } # End of scenario loop
    
    # Remove time limit
    setTimeLimit(cpu = Inf, elapsed = Inf)
    
    return(replicate_results)
    
  }, error = function(e) {
    setTimeLimit(cpu = Inf, elapsed = Inf)
    return(list(error = paste("Replicate", i.rep, "failed:", e$message)))
  })
}

# ============================================================================
# Load Data
# ============================================================================
cat("\n============================================================\n")
cat("Loading population data...\n")
cat("============================================================\n")

load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_PoorOverlap_AllinOne_0118_2025

# Extract first dataset and rename columns to match our convention
population <- data_sets[[1]]
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "y"] <- "Y"
names(population)[names(population) == "y0"] <- "Y0"
names(population)[names(population) == "y1"] <- "Y1"
for (i in 1:6) {
  names(population)[names(population) == paste0("x", i)] <- paste0("X", i)
}

# Parameters
n_reps <- 100    # Number of simulation replicates
n_sample <- 5000  # Sample size for retrospective sampling
M_values <- c(5)  # Number of matches per unit
B <- 200          # Bootstrap iterations
alpha <- 0.05     # Significance level
scenarios <- c("CorCor")  # Model specification scenario

# Calculate true population PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("\nTrue Population PATE:", round(true_pate, 4), "\n")

# ============================================================================
# Main Simulation Loop with FORK Cluster
# ============================================================================
start_time <- Sys.time()

# Parallel setup
n_cores <- 20
batch_size <- 20  # 20 reps per batch for 100 total reps

# Create cluster
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log_100reps.txt")
registerDoParallel(cl)

# Run simulations
cat("\n============================================================\n")
cat("Starting simulation with", n_reps, "replicates...\n")
cat("Using", n_cores, "cores with batch size", batch_size, "\n")
cat("============================================================\n")

all_results <- foreach(
  i.rep = 1:n_reps,
  .combine = 'c',
  .errorhandling = 'pass',
  .maxcombine = batch_size,
  .export = c("run_single_replicate", "population", "true_pate",
             "n_sample", "M_values", "B", "alpha", "scenarios",
             "retrospective_sample", "wdsm_point_estimate",
             "method2_multinomial_bootstrap_ci", "expit",
             "weighted_distance", "find_weighted_neighbors",
             "calculate_weighted_reuse_counts", "compute_wdsm_method2_ci")
) %dopar% {
  gc()
  result <- withTimeout({
    run_single_replicate(i.rep, population, true_pate, n_sample, M_values, B, alpha, scenarios)
  }, timeout = 300)
  gc()
  list(result)
}

# Stop cluster
stopCluster(cl)

# ============================================================================
# Process Results
# ============================================================================
cat("\n============================================================\n")
cat("Processing results...\n")
cat("============================================================\n")

# Filter out errors and organize results
valid_results <- list()
for (i in 1:length(all_results)) {
  if (!is.null(all_results[[i]]) && !inherits(all_results[[i]], "error")) {
    if (!is.null(all_results[[i]]$error)) {
      cat("Replicate", i, "had error:", all_results[[i]]$error, "\n")
    } else {
      valid_results[[paste0("rep_", i)]] <- all_results[[i]]
    }
  } else if (inherits(all_results[[i]], "error")) {
    cat("Replicate", i, "error:", all_results[[i]]$message, "\n")
  }
}

cat("\nSuccessfully completed", length(valid_results), "out of", n_reps, "replicates\n")

# Organize results by scenario and M
results_by_scenario_m <- list()
for (scenario in scenarios) {
  for (M in M_values) {
    key <- paste0(scenario, "_M", M)
    results_by_scenario_m[[key]] <- list()
    
    for (rep_name in names(valid_results)) {
      if (key %in% names(valid_results[[rep_name]])) {
        results_by_scenario_m[[key]][[rep_name]] <- valid_results[[rep_name]][[key]]
      }
    }
  }
}

# Create summary table
summary_data <- data.frame()

for (scenario in scenarios) {
  for (M in M_values) {
    key <- paste0(scenario, "_M", M)
    
    if (key %in% names(results_by_scenario_m)) {
      scenario_m_results <- results_by_scenario_m[[key]]
      
      # Extract results for each method
      methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
                  "ps_weighted", "wdsm_multinomial")
      
      for (method in methods) {
        estimates <- c()
        ses <- c()
        ci_lowers <- c()
        ci_uppers <- c()
        
        for (rep_name in names(scenario_m_results)) {
          if (method %in% names(scenario_m_results[[rep_name]])) {
            result <- scenario_m_results[[rep_name]][[method]]
            if (!is.na(result$estimate)) {
              estimates <- c(estimates, result$estimate)
              ses <- c(ses, result$se)
              ci_lowers <- c(ci_lowers, result$ci_lower)
              ci_uppers <- c(ci_uppers, result$ci_upper)
            }
          }
        }
        
        if (length(estimates) > 0) {
          # Calculate metrics
          mean_estimate <- mean(estimates)
          bias <- mean(estimates) - true_pate
          rel_bias <- (mean(estimates) - true_pate) / abs(true_pate)
          emp_se <- sd(estimates)
          mean_se <- mean(ses)
          se_ratio <- mean_se / emp_se
          coverage <- mean(ci_lowers <= true_pate & ci_uppers >= true_pate)
          rmse <- sqrt(mean((estimates - true_pate)^2))
          
          summary_data <- rbind(summary_data, data.frame(
            Scenario = scenario,
            M = M,
            Method = method,
            N_Valid = length(estimates),
            Mean_Estimate = mean_estimate,
            Bias = bias,
            Rel_Bias = rel_bias,
            Empirical_SE = emp_se,
            Mean_SE = mean_se,
            SE_Ratio = se_ratio,
            Coverage = coverage,
            RMSE = rmse,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }
}

# Round numeric columns for display
numeric_cols <- c("Mean_Estimate", "Bias", "Rel_Bias", "Empirical_SE", 
                 "Mean_SE", "SE_Ratio", "Coverage", "RMSE")
summary_data[numeric_cols] <- round(summary_data[numeric_cols], 4)

# Display results
cat("\n============================================================\n")
cat("Summary Results\n")
cat("============================================================\n")
print(summary_data)

cat("\nTrue PATE:", round(true_pate, 4), "\n")

# Save results
write.csv(summary_data, 
         paste0("pate_retrospective_pooroverlap_comparison_table_M5_100reps_", scenarios[1], "_FIXED.csv"),
         row.names = FALSE)

save(all_results, valid_results, results_by_scenario_m, summary_data, true_pate,
     file = paste0("pate_retrospective_pooroverlap_comparison_results_M5_100reps_", scenarios[1], "_FIXED.RData"))

# Print completion time
end_time <- Sys.time()
total_time <- difftime(end_time, start_time, units = "mins")

cat("\n============================================================\n")
cat("Analysis complete!\n")
cat("Total time:", round(total_time, 2), "minutes\n")
cat("Results saved to CSV and RData files\n")
cat("============================================================\n")
