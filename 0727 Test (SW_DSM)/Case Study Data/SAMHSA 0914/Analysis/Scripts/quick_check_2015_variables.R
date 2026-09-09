# Quick check to find demographic variables in 2015 data

load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2015.RData")
data_2015 <- PUF2015_021518

cat("SEARCHING FOR DEMOGRAPHIC VARIABLES IN 2015:\n")
cat("============================================\n\n")

# Race/ethnicity
cat("Race/Ethnicity variables:\n")
race_vars <- names(data_2015)[grep("race|ethn|hisp", names(data_2015), ignore.case=TRUE)]
print(race_vars)

# Education  
cat("\nEducation variables:\n")
edu_vars <- names(data_2015)[grep("edu|school|grade", names(data_2015), ignore.case=TRUE)]
print(head(edu_vars, 10))

# Income/Poverty
cat("\nIncome/Poverty variables:\n")
inc_vars <- names(data_2015)[grep("inc|pov|fam", names(data_2015), ignore.case=TRUE)]
print(head(inc_vars, 10))

# Employment
cat("\nEmployment variables:\n")
emp_vars <- names(data_2015)[grep("work|empl|job", names(data_2015), ignore.case=TRUE)]
print(head(emp_vars, 10))

# Check if these specific ones exist
cat("\n\nCHECKING SPECIFIC VARIABLES:\n")
cat("newrace2:", "newrace2" %in% names(data_2015), "\n")
cat("NEWRACE2:", "NEWRACE2" %in% names(data_2015), "\n")
cat("eduhighcat:", "eduhighcat" %in% names(data_2015), "\n")
cat("irwrkstat:", "irwrkstat" %in% names(data_2015), "\n")
cat("income:", "income" %in% names(data_2015), "\n")
cat("irfamin:", "irfamin" %in% names(data_2015), "\n")
