# =============================================================================
# PATE RETROSPECTIVE SAMPLING WITH MODEL MISSPECIFICATION - MisCor
# =============================================================================

# Load required libraries
suppressPackageStartupMessages({
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
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(matrixStats)
  library(Hmisc)
})

# Source matching functions
source("dsmatch-master/R/dsmatchATE.R")
source("dsmatch-master/R/utils.R")
source("wdsm_ci_functions.R")
source("wdsm_method2_multinomial_bootstrap.R")

# =============================================================================
# Define Single Replicate Function
# =============================================================================
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M_values, B, alpha) {
  
  tryCatch({
    # Set timeout for this replicate  
    setTimeLimit(cpu = 1800, elapsed = 1800)
    
    # Retrospective sampling based on disease status
    n_cases <- round(n_sample / 2)
    n_controls <- n_sample - n_cases
    
    cases <- population[population$Y == 1, ]
    controls <- population[population$Y == 0, ]
    
    if (nrow(cases) < n_cases || nrow(controls) < n_controls) {
      stop("Not enough cases or controls in population")
    }
    
    sampled_cases <- cases[sample(nrow(cases), n_cases, replace = FALSE), ]
    sampled_controls <- controls[sample(nrow(controls), n_controls, replace = FALSE), ]
    sample <- rbind(sampled_cases, sampled_controls)
    
    # Extract variables
    Y <- sample$Y
    X <- as.matrix(sample[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    A <- sample$A
    
    # Extract survey weights
    w_raw <- sample$survey_weight
    # Normalized weights for PS Full
    w_normalized <- w_raw * length(w_raw) / sum(w_raw)
    
    # =========================================================================
    # SCENARIO-SPECIFIC MODEL SPECIFICATION: MisCor
    # =========================================================================
    use_interaction_ps <- FALSE
    use_interaction_pg <- TRUE
    
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
    
    # Initialize results for all M values
    replicate_results <- list()
    
    # Loop over different M values
    for (M in M_values) {
      
      m_results <- list()
      
      # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING
      tryCatch({
        dsm_result <- dsmatchATE(
          Y = Y,
          X = X_ps,  # PS model uses X_ps
          A = A,
          method = "dsm",
          model.ps = "logit",
          model.pg = "linpred",
          lp.pg = X_pg,  # PG model uses X_pg
          M = M,
          cov.balance = FALSE,
          varest = TRUE,
          boots = B,
          mc = FALSE,
          ncpus = 1
        )
        
        ci_lower <- dsm_result$ATE - qnorm(1 - alpha/2) * dsm_result$se.ATE
        ci_upper <- dsm_result$ATE + qnorm(1 - alpha/2) * dsm_result$se.ATE
        
        m_results$dsm_unweighted <- list(
          estimate = dsm_result$ATE,
          se = dsm_result$se.ATE,
          ci_lower = ci_lower,
          ci_upper = ci_upper
        )
      }, error = function(e) {
        m_results$dsm_unweighted <- list(error = e$message)
      })
      
      # METHOD 2: UNWEIGHTED PROGNOSTIC SCORE MATCHING
      tryCatch({
        pg_result <- dsmatchATE(
          Y = Y,
          X = X_pg,  # Use scenario-specific X_pg
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
        
        ci_lower <- pg_result$ATE - qnorm(1 - alpha/2) * pg_result$se.ATE
        ci_upper <- pg_result$ATE + qnorm(1 - alpha/2) * pg_result$se.ATE
        
        m_results$pg_unweighted <- list(
          estimate = pg_result$ATE,
          se = pg_result$se.ATE,
          ci_lower = ci_lower,
          ci_upper = ci_upper
        )
      }, error = function(e) {
        m_results$pg_unweighted <- list(error = e$message)
      })
      
      # METHOD 3: UNWEIGHTED PROPENSITY SCORE MATCHING
      tryCatch({
        ps_result <- dsmatchATE(
          Y = Y,
          X = X_ps,  # Use scenario-specific X_ps
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
        
        ci_lower <- ps_result$ATE - qnorm(1 - alpha/2) * ps_result$se.ATE
        ci_upper <- ps_result$ATE + qnorm(1 - alpha/2) * ps_result$se.ATE
        
        m_results$ps_unweighted <- list(
          estimate = ps_result$ATE,
          se = ps_result$se.ATE,
          ci_lower = ci_lower,
          ci_upper = ci_upper
        )
      }, error = function(e) {
        m_results$ps_unweighted <- list(error = e$message)
      })
      
      # METHOD 4: SURVEY-WEIGHTED PROPENSITY SCORE FULL MATCHING
      tryCatch({
        df_matchit <- data.frame(
          Y = Y,
          A = A,
          X1 = X[,1], X2 = X[,2], X3 = X[,3],
          X4 = X[,4], X5 = X[,5], X6 = X[,6],
          sw = w_normalized
        )
        
        # PS formula based on scenario
        ps_formula <- if (use_interaction_ps) {
          A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
        } else {
          A ~ X1 + X2 + X3 + X4 + X5 + X6
        }
        
        m_sw <- matchit(ps_formula,
                       data = df_matchit,
                       method = "full",
                       distance = "glm",
                       link = "logit",
                       s.weights = df_matchit$sw,
                       estimand = "ATE")
        
        md_sw <- match.data(m_sw)
        
        # Outcome model - ALWAYS correctly specified for bias correction
        outcome_formula <- Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2)
        fit_sw <- lm(outcome_formula,
                    data = md_sw,
                    weights = weights)
        
        # Bootstrap for SE
        boot_sw <- function(data, indices) {
          d <- data[indices, ]
          
          ps_formula_boot <- if (use_interaction_ps) {
            A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
          } else {
            A ~ X1 + X2 + X3 + X4 + X5 + X6
          }
          
          m_boot <- matchit(ps_formula_boot,
                           data = d,
                           method = "full",
                           distance = "glm",
                           link = "logit",
                           s.weights = d$sw,
                           estimand = "ATE")
          
          md_boot <- match.data(m_boot)
          fit_boot <- lm(outcome_formula,
                        data = md_boot,
                        weights = weights)
          
          comp_boot <- avg_comparisons(fit_boot,
                                       variables = "A",
                                       vcov = ~subclass,
                                       wts = "sw",
                                       newdata = md_boot)
          return(comp_boot$estimate[1])
        }
        
        boot_results_sw <- boot(df_matchit, boot_sw, R = B)
        
        comp_sw <- avg_comparisons(fit_sw,
                                   variables = "A",
                                   vcov = ~subclass,
                                   wts = "sw",
                                   newdata = md_sw)
        
        ate_sw <- comp_sw$estimate[1]
        se_sw <- sd(boot_results_sw$t, na.rm = TRUE)
        ci_sw <- quantile(boot_results_sw$t, c(alpha/2, 1-alpha/2), na.rm = TRUE)
        
        m_results$ps_weighted <- list(
          estimate = ate_sw,
          se = se_sw,
          ci_lower = ci_sw[1],
          ci_upper = ci_sw[2]
        )
      }, error = function(e) {
        m_results$ps_weighted <- list(error = e$message)
      })
      
      # METHOD 5: SURVEY-WEIGHTED DOUBLE SCORE MATCHING (WDSM)
      tryCatch({
        df_wdsm <- data.frame(
          Y = Y,
          A = A,
          X1 = X[,1], X2 = X[,2], X3 = X[,3],
          X4 = X[,4], X5 = X[,5], X6 = X[,6],
          weights = w_raw
        )
        
        wdsm_result <- wdsm_multinomial_boot(
          data = df_wdsm,
          estimand = "PATE",
          sampling = "retrospective",
          n_boot = B,
          alpha = alpha,
          use_interaction_ps = use_interaction_ps,
          use_interaction_pg = use_interaction_pg
        )
        
        m_results$wdsm_multinomial <- list(
          estimate = wdsm_result$estimate,
          se = wdsm_result$se,
          ci_lower = wdsm_result$ci_lower,
          ci_upper = wdsm_result$ci_upper
        )
      }, error = function(e) {
        m_results$wdsm_multinomial <- list(error = e$message)
      })
      
      # Store results for this M value
      replicate_results[[paste0("M", M)]] <- m_results
    }
    
    # Remove time limit
    setTimeLimit(cpu = Inf, elapsed = Inf)
    
    return(replicate_results)
    
  }, error = function(e) {
    setTimeLimit(cpu = Inf, elapsed = Inf)
    return(list(error = paste("Replicate", i.rep, "failed:", e$message)))
  })
}

# =============================================================================
# Load Population Data
# =============================================================================
cat("\n============================================================\n")
cat("Loading population data...\n")
cat("============================================================\n")

load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_GoodOverlap_AllinOne_0118_2025

# Extract first dataset
population <- data_sets[[1]]
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "y"] <- "Y"
names(population)[names(population) == "y0"] <- "Y0"
names(population)[names(population) == "y1"] <- "Y1"
for (i in 1:6) {
  names(population)[names(population) == paste0("x", i)] <- paste0("X", i)
}

# Parameters
n_reps <- 100     # Number of simulation replicates
n_sample <- 5000  # Sample size
M_values <- c(5)  # Only M=5
B <- 200          # Bootstrap iterations
alpha <- 0.05     # Significance level

# Calculate true population PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("\nTrue Population PATE:", round(true_pate, 4), "\n")

# =============================================================================
# Main Simulation Loop
# =============================================================================
start_time <- Sys.time()

cat("\n============================================================\n")
cat("Running MisCor Scenario (100 replications)\n")
cat("PS uses interaction:", FALSE, "\n")
cat("PG uses interaction:", TRUE, "\n")
cat("============================================================\n")

# Setup parallel processing
n_cores <- 20
batch_size <- 5

cat("\nParallel processing setup:\n")
cat("  Cores:", n_cores, "\n")
cat("  Batch size:", batch_size, "\n")
cat("  Total replicates:", n_reps, "\n")

cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

# Run simulations in parallel
all_results <- foreach(i = 1:n_reps,
                       .combine = 'list',
                       .multicombine = TRUE,
                       .maxcombine = batch_size,
                       .errorhandling = 'pass') %dopar% {
  
  gc()
  run_single_replicate(i, population, true_pate, n_sample, M_values, B, alpha)
}

stopCluster(cl)

# =============================================================================
# Process Results
# =============================================================================
cat("\n============================================================\n")
cat("Processing results...\n")
cat("============================================================\n")

# Extract results for M=5
summary_data <- list()

for (i in 1:length(all_results)) {
  if (!is.null(all_results[[i]]) && !is.null(all_results[[i]]$M5)) {
    rep_results <- all_results[[i]]$M5
    
    for (method in names(rep_results)) {
      if (!is.null(rep_results[[method]]) && is.null(rep_results[[method]]$error)) {
        summary_data[[length(summary_data) + 1]] <- data.frame(
          Replicate = i,
          M = 5,
          Method = method,
          Estimate = rep_results[[method]]$estimate,
          SE = rep_results[[method]]$se,
          CI_Lower = rep_results[[method]]$ci_lower,
          CI_Upper = rep_results[[method]]$ci_upper,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

if (length(summary_data) > 0) {
  summary_data <- bind_rows(summary_data)
  
  # Calculate summary statistics
  summary_stats <- summary_data %>%
    group_by(Method) %>%
    summarise(
      Mean_Estimate = mean(Estimate, na.rm = TRUE),
      Bias = mean(Estimate - true_pate, na.rm = TRUE),
      Mean_SE = mean(SE, na.rm = TRUE),
      Empirical_SD = sd(Estimate, na.rm = TRUE),
      Relative_Bias = (mean(Estimate, na.rm = TRUE) - true_pate) / true_pate,
      Relative_Efficiency = NA,  # Will calculate after
      Coverage = mean(CI_Lower <= true_pate & CI_Upper >= true_pate, na.rm = TRUE),
      CI_Width = mean(CI_Upper - CI_Lower, na.rm = TRUE),
      .groups = 'drop'
    )
  
  # Calculate relative efficiency
  ps_var <- summary_stats$Empirical_SD[summary_stats$Method == "ps_unweighted"]^2
  if (length(ps_var) > 0) {
    summary_stats$Relative_Efficiency <- ps_var / (summary_stats$Empirical_SD^2)
  }
  
  # Clean method names
  summary_stats$Method <- case_when(
    summary_stats$Method == "dsm_unweighted" ~ "DSM (Unweighted)",
    summary_stats$Method == "pg_unweighted" ~ "PG (Unweighted)",
    summary_stats$Method == "ps_unweighted" ~ "PS (Unweighted)",
    summary_stats$Method == "ps_weighted" ~ "PS Full (Survey-Weighted)",
    summary_stats$Method == "wdsm_multinomial" ~ "WDSM (Multinomial Bootstrap)",
    TRUE ~ summary_stats$Method
  )
  
  # Display results
  cat("\nSummary Statistics (MisCor, M=5):\n")
  print(summary_stats)
  
  # Save results
  save(all_results, summary_data, summary_stats, true_pate, n_reps, n_sample, M_values, B,
       file = "pate_retrospective_comparison_results_mccleary.RData")
  
  write.csv(summary_data, "summary_data_MisCor.csv", row.names = FALSE)
  write.csv(summary_stats, "summary_stats_MisCor.csv", row.names = FALSE)
}

end_time <- Sys.time()
cat("\n============================================================\n")
cat("Simulation completed!\n")
cat("Total runtime:", format(end_time - start_time), "\n")
cat("============================================================\n")
