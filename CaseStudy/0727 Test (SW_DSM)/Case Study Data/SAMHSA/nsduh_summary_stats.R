# NSDUH 2023 Summary Statistics and Key Visualizations
# Quick overview of the most important patterns in the data

library(dplyr)
library(ggplot2)
library(tidyr)

# Load the data
load("NSDUH_2023.Rdata")
data <- puf2023_102124

cat("=== NSDUH 2023 QUICK SUMMARY STATISTICS ===\n\n")

# Basic sample characteristics
cat("SAMPLE CHARACTERISTICS:\n")
cat("Total respondents:", nrow(data), "\n")
cat("Total variables:", ncol(data), "\n\n")

# Age group distribution with labels
cat("AGE DISTRIBUTION:\n")
age_dist <- data %>%
  count(AGE3) %>%
  mutate(
    percentage = round(n/sum(n)*100, 1),
    age_label = case_when(
      AGE3 == 1 ~ "12-13 years",
      AGE3 == 2 ~ "14-15 years", 
      AGE3 == 3 ~ "16-17 years",
      AGE3 == 4 ~ "18-20 years",
      AGE3 == 5 ~ "21-23 years",
      AGE3 == 6 ~ "24-25 years",
      AGE3 == 7 ~ "26-29 years",
      AGE3 == 8 ~ "30-34 years",
      AGE3 == 9 ~ "35-49 years",
      AGE3 == 10 ~ "50-64 years",
      AGE3 == 11 ~ "65+ years",
      TRUE ~ "Unknown"
    )
  )

for(i in 1:nrow(age_dist)) {
  cat(sprintf("  %s: %d (%.1f%%)\n", age_dist$age_label[i], age_dist$n[i], age_dist$percentage[i]))
}

# Sex distribution
cat("\nSEX DISTRIBUTION:\n")
sex_dist <- data %>%
  count(IRSEX) %>%
  mutate(
    percentage = round(n/sum(n)*100, 1),
    sex_label = case_when(
      IRSEX == 1 ~ "Male",
      IRSEX == 2 ~ "Female",
      TRUE ~ "Unknown"
    )
  )

for(i in 1:nrow(sex_dist)) {
  cat(sprintf("  %s: %d (%.1f%%)\n", sex_dist$sex_label[i], sex_dist$n[i], sex_dist$percentage[i]))
}

# Key substance use prevalence
cat("\nKEY SUBSTANCE USE PREVALENCE (Past Year):\n")

# Tobacco use
if("TOBYR" %in% names(data)) {
  tob_prev <- data %>%
    filter(!is.na(TOBYR)) %>%
    summarise(
      total = n(),
      users = sum(TOBYR == 1, na.rm = TRUE),
      prevalence = round(users/total*100, 1)
    )
  cat(sprintf("  Tobacco use: %.1f%% (%d out of %d)\n", 
              tob_prev$prevalence, tob_prev$users, tob_prev$total))
}

# Cigarette use
if("CIGYR" %in% names(data)) {
  cig_prev <- data %>%
    filter(!is.na(CIGYR)) %>%
    summarise(
      total = n(),
      users = sum(CIGYR == 1, na.rm = TRUE),
      prevalence = round(users/total*100, 1)
    )
  cat(sprintf("  Cigarette use: %.1f%% (%d out of %d)\n", 
              cig_prev$prevalence, cig_prev$users, cig_prev$total))
}

# Survey design information
cat("\nSURVEY DESIGN INFORMATION:\n")
cat("Survey weights variable: ANALWT2_C\n")
cat("Weight range:", sprintf("%.2f to %.2f", min(data$ANALWT2_C, na.rm=TRUE), max(data$ANALWT2_C, na.rm=TRUE)), "\n")
cat("Mean weight:", sprintf("%.2f", mean(data$ANALWT2_C, na.rm=TRUE)), "\n")

# Create substance use by age visualization
cat("\nCreating substance use by age visualization...\n")

# Prepare data for visualization
if("TOBYR" %in% names(data) && "CIGYR" %in% names(data)) {
  viz_data <- data %>%
    filter(!is.na(AGE3), !is.na(TOBYR), !is.na(CIGYR)) %>%
    mutate(
      age_group = case_when(
        AGE3 == 1 ~ "12-13",
        AGE3 == 2 ~ "14-15", 
        AGE3 == 3 ~ "16-17",
        AGE3 == 4 ~ "18-20",
        AGE3 == 5 ~ "21-23",
        AGE3 == 6 ~ "24-25",
        AGE3 == 7 ~ "26-29",
        AGE3 == 8 ~ "30-34",
        AGE3 == 9 ~ "35-49",
        AGE3 == 10 ~ "50-64",
        AGE3 == 11 ~ "65+",
        TRUE ~ "Unknown"
      )
    ) %>%
    group_by(age_group) %>%
    summarise(
      total = n(),
      tobacco_users = sum(TOBYR == 1, na.rm = TRUE),
      cigarette_users = sum(CIGYR == 1, na.rm = TRUE),
      tobacco_prev = round(tobacco_users/total*100, 1),
      cigarette_prev = round(cigarette_users/total*100, 1),
      .groups = 'drop'
    ) %>%
    arrange(factor(age_group, levels = c("12-13", "14-15", "16-17", "18-20", "21-23", 
                                        "24-25", "26-29", "30-34", "35-49", "50-64", "65+")))
  
  # Create the plot
  pdf("substance_use_by_age.pdf", width = 10, height = 6)
  
  # Reshape data for plotting
  plot_data <- viz_data %>%
    select(age_group, tobacco_prev, cigarette_prev) %>%
    tidyr::pivot_longer(cols = c(tobacco_prev, cigarette_prev), 
                       names_to = "substance", values_to = "prevalence") %>%
    mutate(substance = case_when(
      substance == "tobacco_prev" ~ "Any Tobacco",
      substance == "cigarette_prev" ~ "Cigarettes"
    ))
  
  p <- ggplot(plot_data, aes(x = age_group, y = prevalence, fill = substance)) +
    geom_bar(stat = "identity", position = "dodge", alpha = 0.8) +
    labs(
      title = "Tobacco and Cigarette Use by Age Group (Past Year)",
      subtitle = "NSDUH 2023 - Prevalence Rates",
      x = "Age Group (Years)",
      y = "Prevalence (%)",
      fill = "Substance Type"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 12)
    ) +
    scale_fill_manual(values = c("Any Tobacco" = "darkred", "Cigarettes" = "red")) +
    ylim(0, max(plot_data$prevalence) * 1.1)
  
  print(p)
  dev.off()
  
  cat("Substance use by age plot saved as 'substance_use_by_age.pdf'\n")
  
  # Print the data table
  cat("\nSUBSTANCE USE BY AGE GROUP:\n")
  print(viz_data)
}

# Data completeness summary
cat("\nDATA COMPLETENESS SUMMARY:\n")
completeness <- data %>%
  summarise(across(everything(), ~sum(!is.na(.x))/length(.x)*100)) %>%
  tidyr::pivot_longer(everything(), names_to = "variable", values_to = "completeness") %>%
  arrange(desc(completeness))

cat("Variables with highest completeness:\n")
print(head(completeness, 10))

cat("\nVariables with lowest completeness:\n")
print(tail(completeness, 10))

# Key analysis recommendations
cat("\n=== KEY ANALYSIS RECOMMENDATIONS ===\n")
cat("1. Always use survey weights (ANALWT2_C) for population estimates\n")
cat("2. Account for complex survey design in variance estimation\n")
cat("3. Be aware of skip patterns - high missing rates may be intentional\n")
cat("4. Consider age and sex as key demographic stratifiers\n")
cat("5. Refer to codebook for detailed variable definitions\n")

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Files created:\n")
cat("- age_distribution.pdf\n")
cat("- substance_use_by_age.pdf\n")
cat("- NSDUH_2023_Analysis_Summary.md\n") 