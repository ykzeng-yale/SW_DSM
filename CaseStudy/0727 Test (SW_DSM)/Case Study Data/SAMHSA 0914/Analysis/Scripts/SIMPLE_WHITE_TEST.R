# SIMPLE TEST FOR WHITE 2015

library(dplyr)
library(survey)

load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2015.RData")
data_2015 <- PUF2015_021518

# Check what insurance variables exist
insurance_vars <- names(data_2015)[grep("insur|cover|medicaid|private", names(data_2015), ignore.case=TRUE)]
cat("Insurance variables:\n")
print(insurance_vars)

# Check abod variables
abod_vars <- names(data_2015)[grep("^abod", names(data_2015), ignore.case=TRUE)]
cat("\nAbuse variables:\n")
print(abod_vars)

# Check their values
cat("\nSample values:\n")
if("irinsur4" %in% names(data_2015)) {
  cat("irinsur4 exists\n")
  print(table(data_2015$irinsur4[1:100]))
}

# Try uppercase
if("IRINSUR4" %in% names(data_2015)) {
  cat("IRINSUR4 exists\n")
}

# Check some common variables
cat("\nChecking common health insurance variables:\n")
for(var in c("irmedicr", "irmcdchp", "irprvhlt", "irchmpus", "irtrist", "irvapat", "irinsur4")) {
  if(var %in% names(data_2015)) {
    cat(var, "exists - values:", unique(data_2015[[var]])[1:5], "\n")
  }
}
