# Correct retrospective sampling function from SW_PSW-main
# This function implements probability-based sampling with survey weights

retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Coefficients for sample selection model (from SW_PSW-main/Sampling_DependOnTreatment_and_Estimation.R)
  c0 <- log(n_sample/N / (1 - n_sample/N))  # Base probability
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)  # Treatment effect on sampling
  
  # Calculate sampling probabilities based on covariates and treatment
  # Note: Using A for treatment (not z) to match our data structure
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
}
