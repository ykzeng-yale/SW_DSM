# Load and preprocess population data BEFORE loading packages
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
raw_pop <- SuperPopGen_GoodOverlap_AllinOne_0118_2025[[1]]
population <- data.frame(
  X1 = raw_pop$x1, X2 = raw_pop$x2, X3 = raw_pop$x3,
  X4 = raw_pop$x4, X5 = raw_pop$x5, X6 = raw_pop$x6,
  A = raw_pop$z, Y_0 = raw_pop$y0, Y_1 = raw_pop$y1, Y_obs = raw_pop$y,
  Cluster = raw_pop$Cluster, Strata = raw_pop$Strata,
  S = rep(1L, nrow(raw_pop))
)
rm(raw_pop, SuperPopGen_GoodOverlap_AllinOne_0118_2025)
gc()
true_patt <- mean(population$Y_1[population$A == 1]) - mean(population$Y_0[population$A == 1])
cat("True PATT:", round(true_patt, 4), "\n")
cat("Population preprocessed: n =", nrow(population), "True PATE =", 
    round(mean(population$Y_1) - mean(population$Y_0), 4), "\n")

# Now source the comparison script which expects population object
source("compare_methods_patt_retrospective.R")
