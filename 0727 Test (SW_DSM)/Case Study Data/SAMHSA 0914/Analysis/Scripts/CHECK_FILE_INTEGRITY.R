# Check file integrity and try different loading methods

cat("========================================\n")
cat("CHECKING DATA FILE INTEGRITY\n")
cat("========================================\n\n")

# First check file info
file_path <- "/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2002_2019.RData"

cat("File exists:", file.exists(file_path), "\n")
cat("File size:", file.size(file_path) / 1024^3, "GB\n")
cat("File info:\n")
file.info(file_path)[c("size", "mtime")] |> print()

# Try loading with different methods
cat("\n\nMethod 1: Check what's inside without loading fully\n")
cat("=========================================\n")

# List objects in the file without loading them
tryCatch({
  # This tells us object names without loading
  obj_names <- load(file_path, verbose = TRUE, envir = new.env())
  cat("Objects in file:", obj_names, "\n\n")
}, error = function(e) {
  cat("Error:", e$message, "\n")
})

# Try the 2020 file which worked
cat("\n\nChecking 2020 file (which worked):\n")
cat("====================================\n")
rm(list = ls())
gc()

load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2020.Rdata")
cat("Objects loaded from 2020:", ls(), "\n")

if(exists("NSDUH_2020")) {
  cat("NSDUH_2020 dimensions:", dim(NSDUH_2020), "\n")
  cat("Year in data:", unique(NSDUH_2020$YEAR), "\n")
  
  # Check for Ali's variables in 2020
  cat("\nChecking Ali 2022 variables in 2020 data:\n")
  cat("- TXYRRECV:", "TXYRRECV" %in% names(NSDUH_2020), "\n")
  
  # Check for treatment variables
  tx_vars <- names(NSDUH_2020)[grep("TX|TREAT", names(NSDUH_2020))]
  cat("\nTreatment-related variables in 2020:\n")
  if(length(tx_vars) > 0) {
    print(head(tx_vars, 20))
  } else {
    cat("No TX/TREAT variables found\n")
  }
}

# Now try the 2021-2023 file
cat("\n\nChecking 2021-2023 file:\n")
cat("=========================\n")
rm(list = ls())
gc()

load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")
cat("Objects loaded:", ls(), "\n")

if(exists("data")) {
  cat("Data dimensions:", dim(data), "\n")
  cat("Years:", unique(data$YEAR), "\n")
  
  # Can we do Waddell with 2021-2023?
  cat("\nChecking Waddell variables in 2021-2023:\n")
  cat("- IRALCYR:", "IRALCYR" %in% names(data), "\n")
  cat("- IRMRJYR:", "IRMRJYR" %in% names(data), "\n")
  cat("- IRPYUD5ALC (AUD):", "IRPYUD5ALC" %in% names(data), "\n")
  cat("- IRPYUD5MRJ (CUD):", "IRPYUD5MRJ" %in% names(data), "\n")
}

cat("\n\n========================================\n")
cat("ALTERNATIVE SOLUTION\n")
cat("========================================\n\n")

cat("Since 2002-2019 file won't load, we can:\n\n")

cat("1. Use 2020 data for any 2020-specific analysis\n")
cat("2. Use 2021-2023 for Waddell (partial replication)\n")
cat("3. Request the data in smaller chunks:\n")
cat("   - 2002-2010 separately\n")
cat("   - 2011-2019 separately\n")
cat("4. Or work with what we have validated\n\n")

cat("The file may be:\n")
cat("- Too large for available RAM\n")
cat("- Corrupted during download\n")
cat("- Saved in an incompatible R version\n\n")

cat("Recommendation: Proceed with our 3 validated replications\n")
cat("We have sufficient diversity in causal questions!\n")
