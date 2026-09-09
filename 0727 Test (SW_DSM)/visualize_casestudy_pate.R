library(ggplot2)
library(gridExtra)
library(grid)

# ================================================================
# Combined Case Study Figure (2 sub-panels, matching reference)
#   (a) NSDUH: Early marijuana use → mental health  [5 methods, 2 outcomes]
#   (b) NHANES: Short sleep → HbA1c                 [7 methods, 1 outcome]
# ================================================================

# --- Unified colour palette ---
all_colors <- c(
  "PSM (1:1)"  = "#ED7D31",
  "PGM (1:1)"  = "#E8A435",
  "DSM (1:1)"  = "#4472C4",
  "SW-PS Full" = "#70AD47",
  "WDSM (1:1)" = "#C39BD3",
  "WDSM (1:3)" = "#9B59B6",
  "WDSM (1:5)" = "#6C3483"
)

all_shapes <- c(
  "PSM (1:1)"  = 15,
  "PGM (1:1)"  = 16,
  "DSM (1:1)"  = 17,
  "SW-PS Full" = 18,
  "WDSM (1:1)" = 15,
  "WDSM (1:3)" = 16,
  "WDSM (1:5)" = 17
)

# ----------------------------------------------------------------
# Panel (a): NSDUH — Marijuana → Mental Health
# 5 methods × 2 outcomes on x-axis (AMIPY, SMIPY)
# ----------------------------------------------------------------
df_nsduh <- data.frame(
  Method = rep(c("PSM (1:1)", "PGM (1:1)", "DSM (1:1)",
                 "SW-PS Full", "WDSM (1:5)"), 2),
  Outcome = c(rep("AMIPY", 5), rep("SMIPY", 5)),
  Estimate = c(0.0902, 0.0997, 0.0849, 0.0434, 0.0668,
               0.0159, 0.0200, 0.0173, -0.0064, 0.0187),
  CI_Lower = c(0.0328, 0.0473, 0.0283, -0.0533, -0.0014,
               -0.0128, -0.0045, -0.0085, -0.0432, -0.0139),
  CI_Upper = c(0.1477, 0.1521, 0.1415, 0.1400, 0.1351,
               0.0445, 0.0446, 0.0431, 0.0304, 0.0514)
)

df_nsduh$Method <- factor(df_nsduh$Method,
                          levels = c("PSM (1:1)", "PGM (1:1)", "DSM (1:1)",
                                     "SW-PS Full", "WDSM (1:5)"))
df_nsduh$Outcome <- factor(df_nsduh$Outcome, levels = c("AMIPY", "SMIPY"))

nsduh_cols   <- all_colors[levels(df_nsduh$Method)]
nsduh_shapes <- all_shapes[levels(df_nsduh$Method)]

p_nsduh <- ggplot(df_nsduh,
                  aes(x = Outcome, y = Estimate,
                      colour = Method, shape = Method)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.35) +
  geom_pointrange(aes(ymin = CI_Lower, ymax = CI_Upper),
                  position = position_dodge(width = 0.55),
                  size = 0.7, linewidth = 0.45) +
  scale_colour_manual(values = nsduh_cols,   name = "Estimator") +
  scale_shape_manual(values  = nsduh_shapes, name = "Estimator") +
  scale_y_continuous(expand = expansion(mult = 0.06)) +
  labs(y = "Estimated Average Treatment Effect & 95% CI",
       x = NULL) +
  theme_bw(base_size = 11) +
  theme(
    panel.grid.minor    = element_blank(),
    panel.grid.major.x  = element_blank(),
    axis.text.x         = element_text(face = "bold", size = 10),
    axis.title.y        = element_text(size = 9),
    panel.border        = element_rect(colour = "black", linewidth = 0.4),
    legend.position     = c(0.98, 0.98),
    legend.justification = c(1, 1),
    legend.background   = element_rect(fill = alpha("white", 0.85), colour = NA),
    legend.title        = element_text(face = "bold", size = 8.5),
    legend.text         = element_text(size = 7.5),
    legend.key.size     = unit(0.65, "lines"),
    legend.margin       = margin(2, 4, 2, 4),
    plot.margin         = margin(6, 4, 4, 4)
  )

# ----------------------------------------------------------------
# Panel (b): NHANES — Short sleep → HbA1c
# 7 methods, single PATE outcome
# ----------------------------------------------------------------
df_nhanes <- data.frame(
  Method = c("PSM (1:1)", "PGM (1:1)", "DSM (1:1)", "SW-PS Full",
             "WDSM (1:1)", "WDSM (1:3)", "WDSM (1:5)"),
  Estimand = rep("PATE", 7),
  Estimate = c(0.052, 0.040, 0.055, 0.047,
               0.101, 0.090, 0.080),
  CI_Lower = c(-0.002, -0.016, -0.016, -0.012,
               0.018,  0.025,  0.035),
  CI_Upper = c(0.105, 0.096, 0.125, 0.105,
               0.195, 0.143, 0.111)
)

df_nhanes$Method <- factor(df_nhanes$Method,
                           levels = c("PSM (1:1)", "PGM (1:1)", "DSM (1:1)",
                                      "SW-PS Full", "WDSM (1:1)",
                                      "WDSM (1:3)", "WDSM (1:5)"))

p_nhanes <- ggplot(df_nhanes,
                   aes(x = Estimand, y = Estimate,
                       colour = Method, shape = Method)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.35) +
  geom_pointrange(aes(ymin = CI_Lower, ymax = CI_Upper),
                  position = position_dodge(width = 0.75),
                  size = 0.7, linewidth = 0.45) +
  scale_colour_manual(values = all_colors, name = "Estimator") +
  scale_shape_manual(values  = all_shapes, name = "Estimator") +
  scale_y_continuous(expand = expansion(mult = 0.06)) +
  coord_cartesian(xlim = c(0.45, 1.55)) +
  labs(y = "Estimated Average Treatment Effect & 95% CI\n(% HbA1c)",
       x = NULL) +
  theme_bw(base_size = 11) +
  theme(
    panel.grid.minor    = element_blank(),
    panel.grid.major.x  = element_blank(),
    axis.text.x         = element_text(face = "bold", size = 10),
    axis.title.y        = element_text(size = 9),
    panel.border        = element_rect(colour = "black", linewidth = 0.4),
    legend.position     = c(0.98, 0.98),
    legend.justification = c(1, 1),
    legend.background   = element_rect(fill = alpha("white", 0.85), colour = NA),
    legend.title        = element_text(face = "bold", size = 8.5),
    legend.text         = element_text(size = 7.5),
    legend.key.size     = unit(0.65, "lines"),
    legend.margin       = margin(2, 4, 2, 4),
    plot.margin         = margin(6, 4, 4, 4)
  )

# ----------------------------------------------------------------
# Combine with panel labels below (matching reference layout)
# ----------------------------------------------------------------
label_a <- textGrob(
  expression(bold("(a) NSDUH: Early marijuana use and mental illness")),
  gp = gpar(fontsize = 10.5))
label_b <- textGrob(
  expression(bold("(b) NHANES: Short sleep duration and HbA1c")),
  gp = gpar(fontsize = 10.5))

combined <- arrangeGrob(
  p_nsduh, p_nhanes,
  label_a, label_b,
  layout_matrix = rbind(c(1, 2),
                        c(3, 4)),
  heights = c(1, 0.06)
)

ggsave("casestudy_combined_pate_figure.pdf", plot = combined,
       width = 11, height = 5.2, bg = "white")
ggsave("casestudy_combined_pate_figure.png", plot = combined,
       width = 11, height = 5.2, dpi = 300, bg = "white")

cat("Combined figure saved as 'casestudy_combined_pate_figure.pdf/.png'\n")
