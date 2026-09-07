# Verify we can load each file and check the years

library(dplyr)

# Test 1: Load 2021-2023
cat("Loading 2021-2023 data...\n")
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")
cat("- Years available:", unique(data$YEAR), "\n")
cat("- Total N:", nrow(data), "\n")
cat("- Variable count:", ncol(data), "\n\n")

# Check for key variables needed for replications
cat("Checking for Moore 2025 variables (2021-2023):\n")
cat("- STDANYYR (STI):", "STDANYYR" %in% names(data), "\n")
cat("- SPDPSTYR (SPD):", "SPDPSTYR" %in% names(data), "\n")
cat("- UD5ILALANY (SUD):", "UD5ILALANY" %in% names(data), "\n\n")

# Store 2021-2023 data
data_2021_2023 <- data

# Test 2: Load 2020
cat("Loading 2020 data...\n")
rm(data)
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2020.Rdata")
cat("- Years available:", unique(data$YEAR), "\n")
cat("- Total N:", nrow(data), "\n\n")

# Test 3: Try 2002-2019 with memory management
cat("Attempting 2002-2019 (3.2GB file)...\n")
rm(data)
gc()

# Load in chunks if possible
tryCatch({
  load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2002_2019.RData")
  
  # If successful, check contents
  cat("SUCCESS! 2002-2019 loaded\n")
  cat("- Years available:", unique(data$YEAR), "\n")
  cat("- Total N:", format(nrow(data), big.mark=","), "\n")
  cat("- Variable count:", ncol(data), "\n\n")
  
  # Check for White 2023 variables (2012-2018)
  data_2012_2018 <- data %>% filter(YEAR >= 2012 & YEAR <= 2018)
  cat("\nChecking for White 2023 variables (2012-2018 subset):\n")
  cat("- N in 2012-2018:", format(nrow(data_2012_2018), big.mark=","), "\n")
  cat("- CIGTYPE (menthol):", "CIGTYPE" %in% names(data_2012_2018), "\n")
  cat("- CIGAREVR (ever smoked):", "CIGAREVR" %in% names(data_2012_2018), "\n")
  cat("- CIG30USE (past month):", "CIG30USE" %in% names(data_2012_2018), "\n")
  cat("- SMISPY_U (SMI):", "SMISPY_U" %in% names(data_2012_2018), "\n")
  
  # Check for Ali 2022 variables (2019)
  data_2019 <- data %>% filter(YEAR == 2019)
  cat("\nChecking for Ali 2022 variables (2019):\n")
  cat("- N in 2019:", format(nrow(data_2019), big.mark=","), "\n")
  cat("- TXYRRECV (treatment):", "TXYRRECV" %in% names(data_2019), "\n")
  cat("- UD5ILALANY (any SUD):", "UD5ILALANY" %in% names(data_2019), "\n")
  cat("- ANXDYYR (anxiety):", "ANXDYYR" %in% names(data_2019), "\n")
  
  # Check for Waddell variables (2002-2019 pooled)
  cat("\nChecking for Waddell 2021 variables (2002-2019):\n")
  cat("- IRALCYR (alcohol use):", "IRALCYR" %in% names(data), "\n")
  cat("- IRMRJYR (cannabis use):", "IRMRJYR" %in% names(data), "\n")
  cat("- ALCUD (AUD):", "ALCUD" %in% names(data), "\n")
  cat("- MRJUD (CUD):", "MRJUD" %in% names(data), "\n")
  
  # If no ALCUD/MRJUD, check alternatives
  if(!"ALCUD" %in% names(data)) {
    cat("  Alternative AUD vars: ABODALC =", "ABODALC" %in% names(data), 
        ", DEPDALC =", "DEPDALC" %in% names(data), "\n")
  }
  if(!"MRJUD" %in% names(data)) {
    cat("  Alternative CUD vars: ABODMRJ =", "ABODMRJ" %in% names(data),
        ", DEPDMRJ =", "DEPDMRJ" %in% names(data), "\n")
  }
  
}, error = function(e) {
  cat("ERROR loading 2002-2019:", e$message, "\n")
  cat("This file may be too large for available memory\n")
  cat("Consider loading specific years instead\n")
})
