# Diagnostic script to check model specifications
library(MASS)

# Load the data
load("PATE Retrospective Pooroverlap M135 CorCor GLM/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_PoorOverlap_AllinOne_0118_2025

# Get the first dataset
population <- data_sets[[1]]
cat("True PATE:", mean(population$y1 - population$y0), "\n")

# Sample 1000 observations for testing
set.seed(123)
sample_idx <- sample(1:nrow(population), 1000)
test_data <- population[sample_idx, ]

# Rename columns
names(test_data)[names(test_data) == "z"] <- "A"
names(test_data)[names(test_data) == "y"] <- "Y"
for (i in 1:6) {
  names(test_data)[names(test_data) == paste0("x", i)] <- paste0("X", i)
}

# Test different model specifications
cat("\n=== Testing Model Specifications ===\n")

# Correct specification (CorCor): Both with interaction
ps_correct <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                  data = test_data, family = binomial())
pg_correct <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                 data = test_data[test_data$A == 0,])

cat("\nCorCor (Both Correct with interaction):\n")
cat("PS AIC:", AIC(ps_correct), "\n")
cat("PG R-squared:", summary(pg_correct)$r.squared, "\n")

# Misspecified PS, Correct PG (MisCor)
ps_mis <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6, 
              data = test_data, family = binomial())
cat("\nMisCor (PS without interaction, PG with):\n")
cat("PS AIC:", AIC(ps_mis), "- Should be worse than correct\n")
cat("PS AIC difference:", AIC(ps_mis) - AIC(ps_correct), "\n")

# Check what the comparison script should be doing
cat("\n=== Scenario Logic Check ===\n")
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

for (scenario in scenarios) {
  use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
  use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
  
  cat("\nScenario:", scenario, "\n")
  cat("  PS should have interaction:", use_interaction_ps, "\n")
  cat("  PG should have interaction:", use_interaction_pg, "\n")
}

# Check DSM logic issue
cat("\n=== DSM Logic Issue ===\n")
cat("Current DSM code only includes interaction when BOTH use_interaction_ps AND use_interaction_pg are TRUE\n")
cat("This means DSM only uses interaction in CorCor scenario\n")
cat("But DSM should handle PS and PG models SEPARATELY!\n")

# Check the actual performance issue
cat("\n=== Key Issue Identified ===\n")
cat("1. DSM is incorrectly handling model specifications\n")
cat("2. The unweighted methods may not be using the correct X matrices\n")
cat("3. For CorCor, all methods should use X1:X2 interaction in their models\n")
cat("4. WDSM gets the flags but other methods might not be implementing them correctly\n")
