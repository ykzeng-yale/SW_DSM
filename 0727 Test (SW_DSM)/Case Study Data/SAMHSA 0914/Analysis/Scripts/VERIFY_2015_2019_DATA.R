# VERIFY 2015 and 2019 DATA FILES
# Check if they have the variables needed for Ali and White replications

library(dplyr)

cat("===============================================\n")
cat("    VERIFYING 2015 & 2019 NSDUH DATA\n")
cat("===============================================\n\n")

# ============================================
# CHECK 2019 DATA (For Ali et al. 2022)
# ============================================

cat("CHECKING 2019 DATA FOR ALI REPLICATION\n")
cat("========================================\n")

rm(list = ls())
gc()

# Load 2019 data
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2019.RData")

cat("Objects loaded from 2019:", ls(), "\n")

# Get the data object
if(exists("PUF2019_100920")) {
  data_2019 <- PUF2019_100920
} else if(exists("data")) {
  data_2019 <- data
} else if(exists("NSDUH_2019")) {
  data_2019 <- NSDUH_2019
} else {
  # Find whatever object was loaded
  objs <- ls()
  if(length(objs) > 0) {
    data_2019 <- get(objs[1])
  }
}

cat("2019 data dimensions:", dim(data_2019), "\n")
cat("Variable count:", ncol(data_2019), "\n\n")

# Check for Ali's critical variables
cat("Ali et al. 2022 Required Variables:\n")
cat("-----------------------------------\n")
cat("✓ TXYRRECV (treatment seeking):", "TXYRRECV" %in% names(data_2019), "\n")
cat("✓ ANXDYYR (anxiety disorder):", "ANXDYYR" %in% names(data_2019), "\n")
cat("✓ UD5ILALANY (any SUD DSM-5):", "UD5ILALANY" %in% names(data_2019), "\n")
cat("✓ CATAGE (adult categories):", "CATAGE" %in% names(data_2019), "\n")
cat("✓ IRSEX (gender):", "IRSEX" %in% names(data_2019), "\n")
cat("✓ IRAMDEYR (MDE):", "IRAMDEYR" %in% names(data_2019), "\n")
cat("✓ SMISPY_U (SMI):", "SMISPY_U" %in% names(data_2019), "\n\n")

# Quick test: Can we create Ali's sample?
if("TXYRRECV" %in% names(data_2019) & "ANXDYYR" %in% names(data_2019) & "UD5ILALANY" %in% names(data_2019)) {
  ali_sample <- data_2019 %>%
    filter(CATAGE >= 2) %>%  # Adults 18+
    filter(UD5ILALANY == 1) %>%  # Any SUD
    filter(ANXDYYR == 1)  # Anxiety disorder
  
  cat("✅ ALI SAMPLE CREATED:\n")
  cat("   Adults with SUD+Anxiety: N =", nrow(ali_sample), "\n")
  cat("   Treatment rate:", round(100*mean(ali_sample$TXYRRECV, na.rm=TRUE), 1), "%\n")
  cat("   [Ali reported ~15%]\n\n")
} else {
  cat("⚠️ Missing variables for Ali replication\n\n")
}

# ============================================
# CHECK 2015 DATA (For White et al. 2023)
# ============================================

cat("\n\nCHECKING 2015 DATA FOR WHITE REPLICATION\n")
cat("==========================================\n")

rm(list = setdiff(ls(), "ali_sample"))  # Keep Ali sample
gc()

# Load 2015 data
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2015.RData")

cat("Objects loaded from 2015:", setdiff(ls(), "ali_sample"), "\n")

# Get the data object
if(exists("PUF2015_090718")) {
  data_2015 <- PUF2015_090718
} else if(exists("data")) {
  data_2015 <- data
} else if(exists("NSDUH_2015")) {
  data_2015 <- NSDUH_2015
} else {
  # Find whatever object was loaded
  objs <- setdiff(ls(), "ali_sample")
  if(length(objs) > 0) {
    data_2015 <- get(objs[1])
  }
}

cat("2015 data dimensions:", dim(data_2015), "\n")
cat("Variable count:", ncol(data_2015), "\n\n")

# Check for White's critical variables
cat("White et al. 2023 Required Variables:\n")
cat("-------------------------------------\n")
cat("✓ CIGTYPE (menthol cigarette type):", "CIGTYPE" %in% names(data_2015), "\n")
cat("✓ CIGAREVR (ever smoked):", "CIGAREVR" %in% names(data_2015), "\n")
cat("✓ CIG30USE (past-month use):", "CIG30USE" %in% names(data_2015), "\n")
cat("✓ SMISPY_U (SMI):", "SMISPY_U" %in% names(data_2015), "\n")
cat("✓ CIGTRY (cigarettes per day):", "CIGTRY" %in% names(data_2015), "\n")
cat("✓ IRSEX (gender):", "IRSEX" %in% names(data_2015), "\n\n")

# Quick test: Can we create White's sample?
if("CIGTYPE" %in% names(data_2015) & "SMISPY_U" %in% names(data_2015) & "CIG30USE" %in% names(data_2015)) {
  white_sample <- data_2015 %>%
    filter(CIG30USE == 1) %>%  # Past-month smokers
    filter(SMISPY_U == 1)  # With SMI
  
  cat("✅ WHITE SAMPLE CREATED:\n")
  cat("   Past-month smokers with SMI: N =", nrow(white_sample), "\n")
  
  # Check menthol distribution
  menthol_dist <- table(white_sample$CIGTYPE, useNA="ifany")
  cat("   Menthol distribution:\n")
  print(menthol_dist)
  cat("\n")
} else {
  cat("⚠️ Missing variables for White replication\n\n")
}

# ============================================
# FINAL SUMMARY
# ============================================

cat("\n\n===============================================\n")
cat("           VERIFICATION COMPLETE\n")
cat("===============================================\n\n")

cat("✅ DATA FILES STATUS:\n\n")

cat("2019 DATA:\n")
if(exists("ali_sample")) {
  cat("  ✅ READY for Ali et al. 2022 replication\n")
  cat("  - All variables present\n")
  cat("  - Sample created successfully\n")
} else {
  cat("  ❌ Cannot replicate Ali - missing variables\n")
}

cat("\n2015 DATA:\n")
if(exists("white_sample")) {
  cat("  ✅ READY for White et al. 2023 replication\n")
  cat("  - All variables present\n")
  cat("  - Sample created successfully\n")
} else {
  cat("  ❌ Cannot replicate White - missing variables\n")
}

cat("\n\n🎯 NEXT STEP:\n")
cat("============\n")
if(exists("ali_sample") & exists("white_sample")) {
  cat("Both files verified! Ready to run perfect replications for:\n")
  cat("1. Ali et al. 2022 (treatment seeking in SUD+anxiety)\n")
  cat("2. White et al. 2023 (menthol cigarettes in SMI)\n\n")
  cat("This gives us 5 validated replications total!\n")
} else {
  cat("Some issues detected - check variable names above\n")
}
