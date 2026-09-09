# Test loading the large NSDUH data files

# First try the 2021-2023 file (smaller, 101MB)
cat("Trying to load 2021-2023 data (101MB)...\n")
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")
cat("Success! Objects loaded:", ls(), "\n")
cat("Dimensions:", dim(NSDUH_2021_2023), "\n")

# Check years available
if(exists("NSDUH_2021_2023")) {
  years <- unique(NSDUH_2021_2023$YEAR)
  cat("Years in 2021-2023 file:", years, "\n\n")
}

# Now try the 2020 file
cat("Trying to load 2020 data (251MB)...\n")
rm(list=ls())  # Clear workspace
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2020.Rdata")
cat("Success! Objects loaded:", ls(), "\n")

# Now try the large 2002-2019 file (3.2GB) - this might take a while
cat("\nTrying to load 2002-2019 data (3.2GB - this may take a minute)...\n")
rm(list=ls())  # Clear workspace
gc()  # Garbage collection to free memory

# Try with explicit environment
env2019 <- new.env()
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2002_2019.RData", envir = env2019)
cat("Objects in 2002-2019 file:", ls(envir = env2019), "\n")

# Get the actual object name and assign it
obj_names <- ls(envir = env2019)
if(length(obj_names) > 0) {
  data_2019 <- get(obj_names[1], envir = env2019)
  cat("Loaded object with dimensions:", dim(data_2019), "\n")
  cat("Variable names (first 20):", head(names(data_2019), 20), "\n")
  
  # Check years
  if("YEAR" %in% names(data_2019)) {
    cat("Years available:", unique(data_2019$YEAR), "\n")
  }
}
