##############################################################################
# POOR OVERLAP PATE RETROSPECTIVE ANALYSIS - CORRECTED FINAL VERSION
##############################################################################
# Scenario: MisCor
# Replications: 100
# WDSM: Good Overlap version with interaction parameters
# Data: Corrected structure handling
##############################################################################

rm(list = ls())
gc()

# Load required libraries
library(doParallel)
library(foreach)
library(iterators)
library(parallel)
library(R.utils)
library(survey)
library(sampling)
library(MatchIt)
library(marginaleffects)
library(boot)
library(nnet)

# Source dsmatch functions GLOBALLY
source_files <- list.files("dsmatch-master/R", pattern = "\\.R$", full.names = TRUE)
source_files <- source_files[!grepl("dsmatchATE\\.R", source_files)]
for (file in source_files) {
  source(file)
}
source("dsmatch-master/R/dsmatchATE.R")

# Source WDSM functions (Good Overlap version with interaction parameters)
source("wdsm_method2_multinomial_bootstrap.R")
source("wdsm_ci_functions.R")

# Parameters

# Record start time
start_time <- Sys.time()
n_reps <- 100  # PRODUCTION RUN with 100 replicates
n_sample <- 5000  # Sample size for retrospective sampling
M_values <- c(5)  # Fixed M value
B <- 200  # Bootstrap samples
alpha <- 0.05  # Significance level
scenarios <- c("MisCor")

# Load and prepare population data
cat("Loading population data...\n")
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")

# CRITICAL FIX: Extract data frame from list and rename columns
population <- SuperPopGen_PoorOverlap_AllinOne_0118_2025[[1]]
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "y"] <- "Y"
names(population)[names(population) == "x1"] <- "X1"
names(population)[names(population) == "x2"] <- "X2"
names(population)[names(population) == "x3"] <- "X3"
names(population)[names(population) == "x4"] <- "X4"
names(population)[names(population) == "x5"] <- "X5"
names(population)[names(population) == "x6"] <- "X6"

# Calculate true PATE
true_pate <- mean(population$y1 - population$y0)

cat("============================================================\n")
cat("True Population PATE:", true_pate, "\n")
cat("Population size:", nrow(population), "\n")
cat("Sample size:", n_sample, "\n")
cat("============================================================\n")

# Retrospective sampling function (probability-based)
retrospective_sample <- function(pop_data, n_sample = 5000) {
  N <- nrow(pop_data)
  c0 <- log(n_sample/N / (1 - n_sample/N))
  c1 <- log(1.05)
  c2 <- log(1.10)
  c3 <- log(1.15)
  c4 <- log(1.10)
  c5 <- log(1.05)
  c6 <- log(1.10)
  delta_z_in_s <- log(0.9)
  
  formula_S <- c0 + delta_z_in_s * pop_data$A +
               c1 * pop_data$X1 + c2 * pop_data$X2 +
               c3 * pop_data$X3 + c4 * pop_data$X4 +
               c5 * pop_data$X5 + c6 * pop_data$X6
  
  prob_S <- exp(formula_S) / (1 + exp(formula_S))
  pop_data$Prob <- prob_S
  pop_data$S <- rbinom(N, 1, prob_S)
  sample_data <- pop_data[pop_data$S == 1, ]
  sample_data$survey_weight <- 1 / sample_data$Prob
  return(sample_data)
}

# Main analysis function for each replicate
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M_values, B, alpha, scenarios) {
  
  tryCatch({
    # Also source WDSM functions inside worker
    source("wdsm_method2_multinomial_bootstrap.R")
    source("wdsm_ci_functions.R")
    
    # Also source dsmatch functions inside worker
    source_files <- list.files("dsmatch-master/R", pattern = "\\.R$", full.names = TRUE)
    source_files <- source_files[!grepl("dsmatchATE\\.R", source_files)]
    for (file in source_files) {
      source(file)
    }
    source("dsmatch-master/R/dsmatchATE.R")
    
    # Generate retrospective sample
    sample <- retrospective_sample(population, n_sample = n_sample)
    
    # Extract data
    Y <- sample$Y
    X <- as.matrix(sample[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    A <- sample$A
    
    # Extract survey weights
    w_raw <- sample$survey_weight
    # Normalized weights for PS Full (required for proper variance estimation)
    w_normalized <- w_raw * length(w_raw) / sum(w_raw)
    
    # Initialize results for all M values and scenarios
    replicate_results <- list()
    
    # Loop over scenarios
    for (scenario in scenarios) {
      
      # Determine which models to use based on scenario
      use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
      use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
      
      # Create X matrices for PS and PG models based on scenario
      if (use_interaction_ps) {
        X_ps <- cbind(X, X[,1] * X[,2])
        colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        X_ps <- X
        colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      if (use_interaction_pg) {
        X_pg <- cbind(X, X[,1] * X[,2])
        colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        X_pg <- X
        colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      # Loop over M values
      for (M in M_values) {
        
        # Initialize results for this M value and scenario
        m_results <- list()
        
        # ============================================================
        # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch-master)
        # ============================================================
        tryCatch({
          X_dsm <- if (use_interaction_ps && use_interaction_pg) {
            cbind(X, X[,1] * X[,2])
          } else {
            X
          }
          
          dsm_result <- dsmatchATE(
            Y = Y,
            Tr = A,
            X = X_ps,
            lp.pg = X_pg,
            model.ps = "logit",
            model.pg = "glm",
            estimand = "ATE",
            B = B
          )
          
          m_results$dsm_unweighted <- list(
            estimate = dsm_result$est.ds,
            se = sqrt(dsm_result$bootvar[1,1]),
            ci_lower = dsm_result$est.ds - 1.96 * sqrt(dsm_result$bootvar[1,1]),
            ci_upper = dsm_result$est.ds + 1.96 * sqrt(dsm_result$bootvar[1,1]),
            ci = c(dsm_result$est.ds - 1.96 * sqrt(dsm_result$bootvar[1,1]),
                   dsm_result$est.ds + 1.96 * sqrt(dsm_result$bootvar[1,1]))
          )
        }, error = function(e) {
          m_results$dsm_unweighted <- list(error = as.character(e))
        })
        
        # ============================================================
        # METHOD 2: UNWEIGHTED PG MATCHING (dsmatch-master)
        # ============================================================
        tryCatch({
          pg_result <- dsmatchATE(
            Y = Y,
            Tr = A,
            X = X_ps,
            lp.pg = X_pg,
            model.ps = "logit",
            model.pg = "glm",
            estimand = "ATE",
            B = B
          )
          
          m_results$pg_unweighted <- list(
            estimate = pg_result$est.pg,
            se = sqrt(pg_result$bootvar[2,2]),
            ci_lower = pg_result$est.pg - 1.96 * sqrt(pg_result$bootvar[2,2]),
            ci_upper = pg_result$est.pg + 1.96 * sqrt(pg_result$bootvar[2,2]),
            ci = c(pg_result$est.pg - 1.96 * sqrt(pg_result$bootvar[2,2]),
                   pg_result$est.pg + 1.96 * sqrt(pg_result$bootvar[2,2]))
          )
        }, error = function(e) {
          m_results$pg_unweighted <- list(error = as.character(e))
        })
        
        # ============================================================
        # METHOD 3: UNWEIGHTED PS MATCHING (dsmatch-master)
        # ============================================================
        tryCatch({
          ps_result <- dsmatchATE(
            Y = Y,
            Tr = A,
            X = X_ps,
            lp.pg = X_pg,
            model.ps = "logit",
            model.pg = "glm",
            estimand = "ATE",
            B = B
          )
          
          m_results$ps_unweighted <- list(
            estimate = ps_result$est.ps,
            se = sqrt(ps_result$bootvar[3,3]),
            ci_lower = ps_result$est.ps - 1.96 * sqrt(ps_result$bootvar[3,3]),
            ci_upper = ps_result$est.ps + 1.96 * sqrt(ps_result$bootvar[3,3]),
            ci = c(ps_result$est.ps - 1.96 * sqrt(ps_result$bootvar[3,3]),
                   ps_result$est.ps + 1.96 * sqrt(ps_result$bootvar[3,3]))
          )
        }, error = function(e) {
          m_results$ps_unweighted <- list(error = as.character(e))
        })
        
        # ============================================================
        # METHOD 4: SURVEY-WEIGHTED PS FULL MATCHING (MatchIt)
        # ============================================================
        tryCatch({
          formula_ps_matchit <- if (use_interaction_ps) {
            as.formula("A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2")
          } else {
            as.formula("A ~ x1 + x2 + x3 + x4 + x5 + x6")
          }
          
          df_matchit <- data.frame(
            A = A,
            x1 = X[,1], x2 = X[,2], x3 = X[,3],
            x4 = X[,4], x5 = X[,5], x6 = X[,6],
            Y = Y,
            sw = w_normalized
          )
          
          matchit_out <- matchit(
            formula_ps_matchit,
            data = df_matchit,
            method = "full",
            distance = "glm",
            link = "logit",
            estimand = "ATE",
            s.weights = df_matchit$sw
          )
          
          matched_data <- match.data(matchit_out)
          matched_data$combined_weight <- matched_data$weights * matched_data$sw
          
          # Outcome model with treatment-covariate interactions (always correct)
          fit <- lm(Y ~ A * (x1 + x2 + x3 + x4 + x5 + x6 + I(x1*x2)), 
                   data = matched_data, 
                   weights = combined_weight)
          
          # PATE estimation using survey weights
          ate_est <- avg_comparisons(
            fit,
            variables = "A",
            vcov = ~subclass,
            wts = "sw",
            newdata = matched_data
          )
          
          m_results$ps_weighted <- list(
            estimate = ate_est$estimate,
            se = ate_est$std.error,
            ci_lower = ate_est$conf.low,
            ci_upper = ate_est$conf.high,
            ci = c(ate_est$conf.low, ate_est$conf.high)
          )
        }, error = function(e) {
          m_results$ps_weighted <- list(error = as.character(e))
        })
        
        # ============================================================
        # METHOD 5: WDSM with Multinomial Bootstrap
        # ============================================================
        tryCatch({
          ci_results <- compute_wdsm_method2_ci(
            Y = Y, 
            A = A, 
            X = X,  # Base X without interaction
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
            ci_upper = ci_results$ci_upper,
            ci = c(ci_results$ci_lower, ci_results$ci_upper)
          )
        }, error = function(e) {
          m_results$wdsm_multinomial <- list(error = as.character(e))
        })
        
        # Store results for this M value and scenario
        key <- paste0(scenario, "_M", M)
        replicate_results[[key]] <- m_results
      }
    }
    
    return(replicate_results)
    
  }, error = function(e) {
    return(list(error = as.character(e)))
  })
}

# Set up parallel processing
n_cores <- min(12, detectCores() - 1)
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

cat("\n============================================================\n")
cat("Starting simulation with", n_reps, "replicates using", n_cores, "cores\n")
cat("Scenario:", scenarios, "\n")
cat("M value:", M_values, "\n")
cat("============================================================\n\n")

# Run simulation in parallel
all_results <- foreach(i.rep = 1:n_reps,
                      .errorhandling = 'pass',
                      .packages = c("survey", "sampling", "MatchIt", "MASS", 
                                   "boot", "nnet", "marginaleffects", "R.utils"),
                      .export = c("run_single_replicate", "population", "true_pate",
                                 "n_sample", "M_values", "B", "alpha", "scenarios",
                                 "retrospective_sample", "wdsm_point_estimate",
                                 "method2_multinomial_bootstrap_ci",
                                 "expit", "weighted_distance", "find_weighted_neighbors",
                                 "calculate_weighted_reuse_counts", "compute_wdsm_method2_ci",
                                 "dsmatchATE", "is.ps", "is.pg", "is.lp",
                                 "estforboot_dsATE", "estforboot_psATE", "estforboot_pgATE",
                                 "estforboot_covATE", "bisect")) %dopar% {
  
  cat("Starting replicate", i.rep, "of", n_reps, "\n")
  set.seed(20250127 + i.rep)
  
  result <- run_single_replicate(i.rep, population, true_pate, n_sample, 
                                M_values, B, alpha, scenarios)
  
  # Force garbage collection
  gc()
  
  return(result)
}

# Stop cluster
stopCluster(cl)

# Process results
successful_runs <- sum(!sapply(all_results, function(x) inherits(x, "error") || !is.null(x$error)))

cat("\n============================================================\n")
cat("Simulation completed in", round(difftime(Sys.time(), start_time, units = "mins"), 2), "minutes\n")
cat("============================================================\n\n")
cat("Successful runs:", successful_runs, "out of", n_reps, "\n")

# Aggregate results
methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
            "ps_weighted", "wdsm_multinomial")
            
aggregated_results <- list()

for (scenario in scenarios) {
  for (M in M_values) {
    key <- paste0(scenario, "_M", M)
    scenario_results <- list()
    
    for (method in methods) {
      estimates <- numeric()
      ses <- numeric()
      cis_lower <- numeric()
      cis_upper <- numeric()
      
      for (i in 1:length(all_results)) {
        if (!inherits(all_results[[i]], "error") && !is.null(all_results[[i]][[key]])) {
          method_result <- all_results[[i]][[key]][[method]]
          if (!is.null(method_result) && !inherits(method_result, "error") && 
              is.null(method_result$error)) {
            estimates <- c(estimates, method_result$estimate)
            ses <- c(ses, method_result$se)
            cis_lower <- c(cis_lower, method_result$ci[1])
            cis_upper <- c(cis_upper, method_result$ci[2])
          }
        }
      }
      
      if (length(estimates) > 0) {
        # Calculate metrics
        bias <- mean(estimates - true_pate) / true_pate * 100
        emp_se <- sd(estimates)
        mean_se <- mean(ses)
        se_ratio <- mean_se / emp_se
        coverage <- mean(cis_lower <= true_pate & cis_upper >= true_pate) * 100
        rmse <- sqrt(mean((estimates - true_pate)^2))
        
        scenario_results[[method]] <- list(
          n = length(estimates),
          bias = bias,
          emp_se = emp_se,
          mean_se = mean_se,
          se_ratio = se_ratio,
          coverage = coverage,
          rmse = rmse
        )
      } else {
        scenario_results[[method]] <- list(
          n = 0,
          bias = NA,
          emp_se = NA,
          mean_se = NA,
          se_ratio = NA,
          coverage = NA,
          rmse = NA
        )
      }
    }
    
    aggregated_results[[key]] <- scenario_results
  }
}

# Print summary
cat("\n============================================================\n")
cat("RESULTS SUMMARY (", successful_runs, " replicates)\n")
cat("True PATE:", true_pate, "\n")
cat("============================================================\n")

for (scenario in scenarios) {
  for (M in M_values) {
    key <- paste0(scenario, "_M", M)
    cat("\nScenario:", scenario, "| M =", M, "\n")
    cat("------------------------------------------------------------\n")
    cat(sprintf("%-20s %8s %8s %8s %8s\n", 
                "Method", "Bias", "SE", "Coverage", "RMSE"))
    cat("------------------------------------------------------------\n")
    
    for (method in methods) {
      if (!is.null(aggregated_results[[key]][[method]])) {
        res <- aggregated_results[[key]][[method]]
        if (res$n > 0) {
          cat(sprintf("%-20s %8.3f %8.3f %8.2f %8.3f\n",
                     method, res$bias, res$se_ratio, res$coverage, res$rmse))
        } else {
          cat(sprintf("%-20s %8s\n", method, "FAILED"))
        }
      }
    }
  }
}

cat("\n============================================================\n")
cat("TEST RUN COMPLETE!\n")
cat("Results saved to: raw_results_100reps_", scenarios, "_CORRECTED_FINAL.RData\n")
cat("============================================================\n")

# Save results
save(all_results, aggregated_results, true_pate, file = paste0("raw_results_100reps_", scenarios, "_CORRECTED_FINAL.RData"))
