# R script to properly fix the retrospective sampling in all comparison scripts

# Define the correct retrospective sampling function as a string
correct_function <- '# Function to perform retrospective sampling (CORRECTED from SW_PSW-main)
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Coefficients for sample selection model (from SW_PSW-main)
  c0 <- log(n_sample/N / (1 - n_sample/N))  # Base probability
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)  # Treatment effect on sampling
  
  # Calculate sampling probabilities based on covariates and treatment
  formula_S <- c0 + delta_z_in_s * population$A + 
               c1 * population$X1 + c2 * population$X2 +
               c3 * population$X3 + c4 * population$X4 + 
               c5 * population$X5 + c6 * population$X6
  
  # Expit transformation for probabilities
  prob_S <- exp(formula_S) / (1 + exp(formula_S))
  population$Prob <- prob_S
  
  # Sample units based on probabilities
  population$S <- rbinom(N, 1, prob_S)
  sample_data <- population[population$S == 1, ]
  
  # Calculate survey weights as inverse of sampling probability
  sample_data$survey_weight <- 1 / sample_data$Prob
  
  return(sample_data)
}'

# Process each scenario
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

for (scenario in scenarios) {
  cat("Processing", scenario, "scenario...\n")
  
  # Read the existing file
  file_path <- paste0("PATE Retrospective Pooroverlap M135 ", scenario, 
                      " GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R")
  
  if (file.exists(file_path)) {
    # Read the entire file
    lines <- readLines(file_path)
    
    # Find where the retrospective_sample function starts and ends
    start_idx <- which(grepl("retrospective_sample <- function", lines))[1] - 1
    
    # Find the closing brace for the function (accounting for nested braces)
    if (!is.na(start_idx)) {
      brace_count <- 0
      end_idx <- start_idx
      in_function <- FALSE
      
      for (i in start_idx:length(lines)) {
        if (grepl("retrospective_sample <- function", lines[i])) {
          in_function <- TRUE
        }
        
        if (in_function) {
          # Count opening braces
          brace_count <- brace_count + length(gregexpr("\\{", lines[i])[[1]])
          if (gregexpr("\\{", lines[i])[[1]][1] == -1) {
            brace_count <- brace_count - 1  # Correct for no match case
          }
          
          # Count closing braces
          brace_count <- brace_count - length(gregexpr("\\}", lines[i])[[1]])
          if (gregexpr("\\}", lines[i])[[1]][1] == -1) {
            brace_count <- brace_count + 1  # Correct for no match case
          }
          
          if (in_function && brace_count == 0 && grepl("\\}", lines[i])) {
            end_idx <- i
            break
          }
        }
      }
      
      # Replace the function
      if (end_idx > start_idx) {
        # Create new file content
        new_lines <- c(
          lines[1:(start_idx-1)],
          strsplit(correct_function, "\n")[[1]],
          lines[(end_idx+1):length(lines)]
        )
        
        # Write back to file
        writeLines(new_lines, file_path)
        cat("✅ Updated", file_path, "\n")
      } else {
        cat("⚠️ Could not find function boundaries in", file_path, "\n")
      }
    } else {
      cat("⚠️ Could not find retrospective_sample function in", file_path, "\n")
    }
  } else {
    cat("⚠️ File not found:", file_path, "\n")
  }
}

cat("\nAll scripts updated with correct retrospective sampling!\n")
