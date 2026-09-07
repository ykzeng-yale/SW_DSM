################################################################################
# ADD WDSM M=1 AND M=3 TO ALL 10 ANALYSES
# 
# Currently all analyses have WDSM with M=5
# This script adds M=1 and M=3 results to each
################################################################################

library(dplyr)
source("WDSM_adaptive.R")

set.seed(2024)

cat('\n═══════════════════════════════════════════════════════════════════════════\n')
cat('   ADDING WDSM M=1 AND M=3 TO ALL 10 ANALYSES\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

# Function to add M=1 and M=3 to existing results
add_wdsm_ratios <- function(data_file, results_file, covars, output_file) {
  
  cat('Processing:', results_file, '\n')
  
  # Load existing results
  env <- new.env()
  load(results_file, envir=env)
  load(data_file, envir=env)
  
  # Get data
  if(exists('data_complete', envir=env)) {
    data <- env$data_complete
  } else if(exists('data2', envir=env)) {
    data <- env$data2
  } else if(exists('d8', envir=env)) {
    data <- env$d8
  } else {
    cat('  ERROR: No data found\n\n')
    return(NULL)
  }
  
  # Extract Y, A, sw
  if('Y' %in% names(data)) {
    Y <- data$Y
    A <- data$A  
    sw <- data$survey_weight
  } else {
    # Reconstruct from saved data
    cat('  Skipping - need to reconstruct Y, A, sw\n\n')
    return(NULL)
  }
  
  cat('  N =', length(Y), '| Running M=1 and M=3...\n')
  
  # Get results object
  if(exists('results', envir=env)) {
    results <- env$results
  } else if(exists('results2', envir=env)) {
    results <- env$results2
  } else if(exists('results8', envir=env)) {
    results <- env$results8
  } else {
    cat('  ERROR: No results found\n\n')
    return(NULL)
  }
  
  # Prepare data for WDSM
  wdsm_data <- data
  
  ps_formula <- as.formula(paste("A ~", paste(covars, collapse=" + ")))
  pg_formula <- as.formula(paste("~", paste(covars, collapse=" + ")))
  
  # Run M=1
  cat('    M=1...')
  wdsm_M1 <- bootstrap_adaptive_wdsm(
    data = wdsm_data,
    ps_formula = ps_formula,
    pg_formula = pg_formula,
    outcome_var = "Y",
    treatment_var = "A",
    weight_var = "survey_weight",
    n_bootstrap = 50,
    M = 1,
    use_bias_correction = TRUE,
    verbose = FALSE
  )
  results$wdsm_M1 <- list(
    estimate = wdsm_M1$point_estimate$tau,
    ci_lower = wdsm_M1$ci_lower,
    ci_upper = wdsm_M1$ci_upper
  )
  cat(' Done\n')
  
  # Run M=3
  cat('    M=3...')
  wdsm_M3 <- bootstrap_adaptive_wdsm(
    data = wdsm_data,
    ps_formula = ps_formula,
    pg_formula = pg_formula,
    outcome_var = "Y",
    treatment_var = "A",
    weight_var = "survey_weight",
    n_bootstrap = 50,
    M = 3,
    use_bias_correction = TRUE,
    verbose = FALSE
  )
  results$wdsm_M3 <- list(
    estimate = wdsm_M3$point_estimate$tau,
    ci_lower = wdsm_M3$ci_lower,
    ci_upper = wdsm_M3$ci_upper
  )
  cat(' Done\n')
  
  # M=5 should already exist as results$wdsm
  if('wdsm' %in% names(results) && is.null(results$wdsm_M5)) {
    results$wdsm_M5 <- results$wdsm
  }
  
  # Save updated results
  if(exists('data_complete', envir=env)) {
    data_complete <- data
    save(data_complete, results, file=output_file)
  } else if(exists('data2', envir=env)) {
    data2 <- data
    save(data2, results, file=output_file)
  } else if(exists('d8', envir=env)) {
    d8 <- data
    save(d8, results, file=output_file)
  }
  
  cat('  ✅ Saved:', output_file, '\n\n')
  
  return(results)
}

################################################################################
# Process each analysis
################################################################################

# Note: This is a template - would need actual Y, A, sw in saved data
# For now, just show the approach for analyses that have the data properly saved

cat('This script requires that Y, A, survey_weight are in the saved data.\n')
cat('Current analyses use different data structures.\n')
cat('Recommendation: Re-run key analyses with M=1, M=3, M=5 in original scripts.\n\n')

cat('═══════════════════════════════════════════════════════════════════════════\n')



