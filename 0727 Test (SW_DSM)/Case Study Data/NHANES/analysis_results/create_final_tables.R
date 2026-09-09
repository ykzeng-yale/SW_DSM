################################################################################
# Create Final Results Tables in Multiple Formats
################################################################################

# Clear workspace
rm(list = ls())

# Load required libraries
library(knitr)
library(kableExtra)

# ==============================================================================
# TABLE 1: Race Analysis Results
# ==============================================================================

race_table <- data.frame(
  Method = c("Unweighted Double Score Matching (DSM)",
             "Survey-Weighted PS Full Matching",
             "Weighted Double Score Matching (WDSM)"),
  `ACD Estimate` = c(0.0232, -0.0321, 0.0156),
  `95% Confidence Interval` = c("0.0022, 0.0443", 
                                "-0.0572, -0.0069", 
                                "-0.0033, 0.0393"),
  check.names = FALSE
)

# ==============================================================================
# TABLE 2: Lead Exposure Analysis Results
# ==============================================================================

lead_table <- data.frame(
  Method = c("Unweighted Double Score Matching (DSM)",
             "Survey-Weighted PS Full Matching",
             "Weighted Double Score Matching (WDSM)"),
  `PATE Estimate` = c(-0.0014, -0.0109, -0.0033),
  `95% Confidence Interval` = c("-0.0176, 0.0148",
                                "-0.0300, 0.0083",
                                "-0.0215, 0.0152"),
  check.names = FALSE
)

# ==============================================================================
# Save as CSV files
# ==============================================================================

write.csv(race_table, "analysis_results/Table1_Race_Analysis.csv", row.names = FALSE)
write.csv(lead_table, "analysis_results/Table2_Lead_Analysis.csv", row.names = FALSE)

# ==============================================================================
# Create LaTeX tables
# ==============================================================================

# Table 1: Race Analysis
latex_table1 <- kable(race_table, format = "latex", booktabs = TRUE,
                      caption = "Average controlled difference (ACD) estimates and corresponding 95\\% confidence intervals across various analytic approaches for the comparison of effect of race (non-Hispanic Black versus non-Hispanic White participants) on log-transformed telomere length among n = 5,270 participants in the National Health and Nutrition Examination Survey (NHANES).",
                      label = "tab:race_analysis") %>%
  kable_styling(latex_options = c("striped", "hold_position"),
                full_width = FALSE) %>%
  column_spec(1, width = "7cm") %>%
  column_spec(2, width = "3cm") %>%
  column_spec(3, width = "4cm")

# Table 2: Lead Analysis
latex_table2 <- kable(lead_table, format = "latex", booktabs = TRUE,
                      caption = "Population average treatment effect (PATE) estimates and corresponding 95\\% confidence intervals across various analytic approaches for the effect of lead exposure (dichotomized at median) on log-transformed telomere length among n = 5,267 participants in the National Health and Nutrition Examination Survey (NHANES).",
                      label = "tab:lead_analysis") %>%
  kable_styling(latex_options = c("striped", "hold_position"),
                full_width = FALSE) %>%
  column_spec(1, width = "7cm") %>%
  column_spec(2, width = "3cm") %>%
  column_spec(3, width = "4cm")

# Save LaTeX tables
writeLines(as.character(latex_table1), "analysis_results/Table1_Race_Analysis.tex")
writeLines(as.character(latex_table2), "analysis_results/Table2_Lead_Analysis.tex")

# ==============================================================================
# Create HTML tables for presentation
# ==============================================================================

# HTML Table 1
html_table1 <- kable(race_table, format = "html", 
                     caption = "Table 1: Race Analysis - ACD Estimates") %>%
  kable_styling(bootstrap_options = c("striped", "hover", "condensed", "responsive"),
                full_width = FALSE) %>%
  column_spec(1, bold = TRUE, width = "300px") %>%
  column_spec(2, width = "120px") %>%
  column_spec(3, width = "180px")

# HTML Table 2
html_table2 <- kable(lead_table, format = "html",
                     caption = "Table 2: Lead Exposure Analysis - PATE Estimates") %>%
  kable_styling(bootstrap_options = c("striped", "hover", "condensed", "responsive"),
                full_width = FALSE) %>%
  column_spec(1, bold = TRUE, width = "300px") %>%
  column_spec(2, width = "120px") %>%
  column_spec(3, width = "180px")

# Save HTML tables
writeLines(as.character(html_table1), "analysis_results/Table1_Race_Analysis.html")
writeLines(as.character(html_table2), "analysis_results/Table2_Lead_Analysis.html")

# ==============================================================================
# Print formatted tables to console
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("TABLE 1: RACE ANALYSIS RESULTS\n")
cat("================================================================================\n")
print(race_table, row.names = FALSE)

cat("\n")
cat("================================================================================\n")
cat("TABLE 2: LEAD EXPOSURE ANALYSIS RESULTS\n")
cat("================================================================================\n")
print(lead_table, row.names = FALSE)

# ==============================================================================
# Create combined comparison table
# ==============================================================================

comparison_table <- data.frame(
  Analysis = c(rep("Race (Black vs White)", 3),
               rep("Lead Exposure (High vs Low)", 3)),
  Method = rep(c("Unweighted DSM", "Survey-Weighted PS Full", "WDSM"), 2),
  Estimate = c(0.0232, -0.0321, 0.0156, -0.0014, -0.0109, -0.0033),
  CI_Lower = c(0.0022, -0.0572, -0.0033, -0.0176, -0.0300, -0.0215),
  CI_Upper = c(0.0443, -0.0069, 0.0393, 0.0148, 0.0083, 0.0152),
  Significant = c("Yes", "Yes", "No", "No", "No", "No"),
  `Percent Change` = c("2.35%", "-3.15%", "1.58%", "-0.14%", "-1.08%", "-0.33%"),
  check.names = FALSE
)

write.csv(comparison_table, "analysis_results/Combined_Comparison_Results.csv", row.names = FALSE)

cat("\n")
cat("================================================================================\n")
cat("COMBINED COMPARISON TABLE\n")
cat("================================================================================\n")
print(comparison_table, row.names = FALSE)

cat("\n=== Tables saved in multiple formats ===\n")
cat("CSV files:\n")
cat("  - analysis_results/Table1_Race_Analysis.csv\n")
cat("  - analysis_results/Table2_Lead_Analysis.csv\n")
cat("  - analysis_results/Combined_Comparison_Results.csv\n")
cat("\nLaTeX files:\n")
cat("  - analysis_results/Table1_Race_Analysis.tex\n")
cat("  - analysis_results/Table2_Lead_Analysis.tex\n")
cat("\nHTML files:\n")
cat("  - analysis_results/Table1_Race_Analysis.html\n")
cat("  - analysis_results/Table2_Lead_Analysis.html\n")
cat("\nMarkdown file:\n")
cat("  - analysis_results/Final_Results_Tables.md\n")



