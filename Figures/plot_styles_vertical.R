# Rendering functions retained from the original figures; no data loading or result filtering.
# ggplot2 3.5+ exposes one guide box per position. Older cowplot selects the
# first (often empty) box, so select the requested bottom legend explicitly.
wdsm_bottom_legend <- function(plot) {
  g <- ggplot2::ggplotGrob(plot)
  name <- if ("guide-box-bottom" %in% g$layout$name) "guide-box-bottom" else "guide-box"
  index <- which(g$layout$name == name)
  if (length(index) != 1L) stop("Expected exactly one bottom method legend")
  legend <- g$grobs[[index]]
  if (!inherits(legend, "gtable") || !any(legend$layout$name == "guides"))
    stop("Bottom method legend is empty; refusing to save an unlabeled figure")
  legend
}

method_colors <- c("PSM"="#4E79A7","PGM"="#F28E2B","DSM"="#7B2D8E","SW-PSM"="#E15759","WDSM"="#59A14F")
method_shapes <- c(PSM=16, PGM=15, DSM=17, "SW-PSM"=18, WDSM=8)
method_sizes  <- c(PSM=4.2, PGM=3.5, DSM=3.5, "SW-PSM"=4.5, WDSM=5)
method_lwd    <- c(PSM=0.7, PGM=0.7, DSM=0.7, "SW-PSM"=0.7, WDSM=1.5)
method_alpha  <- c(PSM=0.6, PGM=0.6, DSM=0.6, "SW-PSM"=0.6, WDSM=0.95)
method_stroke <- c(PSM=0.7, PGM=0.7, DSM=0.7, "SW-PSM"=0.7, WDSM=1.2)

row_defs <- list(
  list(est="PATE", ov="Good Overlap"),
  list(est="PATE", ov="Poor Overlap"),
  list(est="PATT", ov="Good Overlap"),
  list(est="PATT", ov="Poor Overlap")
)

make_p <- function(d, metric, hline=NULL, show_x=FALSE) {
  p <- ggplot(d, aes(x=Scenario, y=.data[[metric]], color=Method, shape=Method, group=Method)) +
    geom_line(aes(linewidth=Method, alpha=Method)) +
    geom_point(aes(size=Method, stroke=Method)) +
    scale_color_manual(values=method_colors) +
    scale_shape_manual(values=method_shapes) +
    scale_size_manual(values=method_sizes) +
    scale_linewidth_manual(values=method_lwd) +
    scale_alpha_manual(values=method_alpha) +
    scale_discrete_manual("stroke", values=method_stroke) +
    scale_y_continuous(expand=expansion(mult=c(0.05,0.12))) +
    labs(x=NULL, y=NULL) +
    theme_bw(base_size=12) +
    theme(axis.text.y=element_text(size=11, face="bold"),
          panel.grid.minor=element_blank(), panel.grid.major.x=element_blank(),
          legend.position="none",
          plot.margin=margin(3,6,3,3))
  if (!is.null(hline)) p <- p + geom_hline(yintercept=hline, linetype="dashed", color="grey40", linewidth=0.5)
  if (show_x) {
    p <- p + theme(axis.text.x=element_text(size=11, face="bold"))
  } else {
    p <- p + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
  }
  p
}

make_figure <- function(df, title_text, outname, outdir="Figures") {
  df$Method <- factor(df$Method, levels=c("PSM","PGM","DSM","SW-PSM","WDSM"))
  df$Scenario <- factor(df$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))

  panel_grobs <- list()
  for (i in 1:4) {
    d <- df %>% filter(Estimand==row_defs[[i]]$est, Overlap==row_defs[[i]]$ov)
    show_x <- (i == 4)
    panel_grobs[[(i-1)*3+1]] <- ggplotGrob(make_p(d, "Bias", hline=0, show_x=show_x))
    panel_grobs[[(i-1)*3+2]] <- ggplotGrob(make_p(d, "RelEff", hline=1, show_x=show_x))
    panel_grobs[[(i-1)*3+3]] <- ggplotGrob(make_p(d, "Coverage", hline=95, show_x=show_x))
  }

  row_labels <- c("PATE\nGood Overlap","PATE\nPoor Overlap","PATT\nGood Overlap","PATT\nPoor Overlap")
  row_bg <- c("white","#EBEBEB","white","#EBEBEB")
  row_label_grobs <- lapply(1:4, function(i) {
    ggplotGrob(ggplot() +
      annotate("text", x=0.5, y=0.5, label=row_labels[i], fontface="bold", size=5.5, lineheight=1.15) +
      theme_void() + theme(plot.background=element_rect(fill=row_bg[i], color=NA)))
  })

  col_titles <- c("Abs. Relative Bias (%)","Relative Efficiency","Coverage (%)")
  col_header_grobs <- lapply(col_titles, function(t) {
    ggplotGrob(ggplot() + annotate("text", x=0.5, y=0.5, label=t, fontface="bold", size=5.5) + theme_void())
  })

  xlab_grob <- ggplotGrob(ggplot() +
    annotate("text", x=0.5, y=0.5, label="Model Specification", fontface="bold", size=5) + theme_void())

  leg_df <- data.frame(
    x=rep(1:4, 5), y=rep(1:5, each=4),
    Method=factor(rep(levels(df$Method), each=4), levels=levels(df$Method))
  )
  leg_p <- ggplot(leg_df, aes(x=x, y=y, color=Method, shape=Method, size=Method, linewidth=Method)) +
    geom_line() + geom_point(stroke=0.8) +
    scale_color_manual(values=method_colors) +
    scale_shape_manual(values=method_shapes) +
    scale_size_manual(values=c(PSM=4.2, PGM=3.5, DSM=3.5, "SW-PSM"=4.5, WDSM=5.5)) +
    scale_linewidth_manual(values=c(PSM=0.6, PGM=0.6, DSM=0.6, "SW-PSM"=0.6, WDSM=1.5)) +
    guides(color=guide_legend(nrow=1, title=NULL,
      override.aes=list(shape=method_shapes, size=c(4.2,3.5,3.5,4.5,5.5),
                        linewidth=c(0.6,0.6,0.6,0.6,1.5), stroke=c(0.5,0.5,0.5,0.5,1.0))),
      shape="none", size="none", linewidth="none") +
    theme_void() + theme(legend.position="bottom", legend.text=element_text(size=14, face="bold"),
      legend.title=element_blank(), legend.key.width=unit(2.2,"cm"),
      legend.spacing.x=unit(0.6,"cm"), legend.key.height=unit(1.2,"cm"))
  leg_grob <- wdsm_bottom_legend(leg_p)

  layout_mat <- rbind(
    c(NA, 1, 2, 3),
    c(4, 5, 6, 7),
    c(8, 9, 10, 11),
    c(12, 13, 14, 15),
    c(16, 17, 18, 19),
    c(NA, 20, 20, 20),
    c(21, 21, 21, 21)
  )

  grob_list <- c(
    col_header_grobs,
    list(row_label_grobs[[1]]), panel_grobs[1:3],
    list(row_label_grobs[[2]]), panel_grobs[4:6],
    list(row_label_grobs[[3]]), panel_grobs[7:9],
    list(row_label_grobs[[4]]), panel_grobs[10:12],
    list(xlab_grob),
    list(leg_grob)
  )

  g <- arrangeGrob(grobs=grob_list, layout_matrix=layout_mat,
                   widths=unit.c(unit(1.8, "in"), unit(c(1, 1, 1), "null")),
                   heights=unit(c(0.4, 3, 3, 3, 3, 0.3, 0.6), "null"),
                   top=textGrob(title_text, gp=gpar(fontsize=18, fontface="bold")))

  ggsave(paste0(outdir,"/png/",outname,".png"), g, width=13, height=14.5, dpi=300, bg="white")
  ggsave(paste0(outdir,"/pdf/",outname,".pdf"), g, width=13, height=14.5)
  cat("Saved:", outdir, "/", outname, "\n")
}

## Dot-only version: no lines, hollow for unaffected method-scenario combos
# PSM/SW-PSM use only PS → unaffected by PG misspec → hollow when PG is "Mis" (Cor|Mis, Mis|Mis)
# PGM uses only PG → unaffected by PS misspec → hollow when PS is "Mis" (Mis|Cor, Mis|Mis)
# DSM/WDSM use both → always affected → always filled

add_affected <- function(df) {
  df$Affected <- TRUE
  df$Affected[df$Method %in% c("PSM","SW-PSM") & df$Scenario %in% c("Cor|Mis","Mis|Mis")] <- FALSE
  df$Affected[df$Method == "PGM" & df$Scenario %in% c("Mis|Cor","Mis|Mis")] <- FALSE
  df
}

filled_shapes <- c(PSM=16, PGM=15, DSM=17, "SW-PSM"=18, WDSM=8)
hollow_shapes <- c(PSM=1, PGM=0, DSM=2, "SW-PSM"=5, WDSM=8)

make_p_dots <- function(d, metric, hline=NULL, show_x=FALSE) {
  d$Scenario <- factor(d$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))

  d$pt_shape <- filled_shapes[as.character(d$Method)]
  dot_sizes <- c(PSM=5, PGM=4.5, DSM=4.5, "SW-PSM"=5.2, WDSM=6)
  d$pt_size <- dot_sizes[as.character(d$Method)]
  d$pt_alpha <- ifelse(!d$Affected, 0.2,
    ifelse(d$Method=="WDSM", 1.0, 0.85))
  d$pt_stroke <- ifelse(d$Method=="WDSM", 1.5, 0.8)

  p <- ggplot(d, aes(x=Scenario, y=.data[[metric]], color=Method)) +
    geom_point(shape=d$pt_shape, size=d$pt_size, alpha=d$pt_alpha, stroke=d$pt_stroke) +
    scale_color_manual(values=method_colors) +
    scale_y_continuous(expand=expansion(mult=c(0.05,0.12))) +
    labs(x=NULL, y=NULL) +
    theme_bw(base_size=12) +
    theme(axis.text.y=element_text(size=11, face="bold"),
          panel.grid.minor=element_blank(), panel.grid.major.x=element_blank(),
          legend.position="none", plot.margin=margin(3,6,3,3))

  if (!is.null(hline)) p <- p + geom_hline(yintercept=hline, linetype="dashed", color="grey40", linewidth=0.5)
  if (show_x) {
    p <- p + theme(axis.text.x=element_text(size=11, face="bold"))
  } else {
    p <- p + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
  }
  p
}

make_figure_dots <- function(df, title_text, outname, outdir="Figures") {
  df$Method <- factor(df$Method, levels=c("PSM","PGM","DSM","SW-PSM","WDSM"))
  df$Scenario <- factor(df$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))
  df <- add_affected(df)

  panel_grobs <- list()
  for (i in 1:4) {
    d <- df %>% filter(Estimand==row_defs[[i]]$est, Overlap==row_defs[[i]]$ov)
    show_x <- (i == 4)
    panel_grobs[[(i-1)*3+1]] <- ggplotGrob(make_p_dots(d, "Bias", hline=0, show_x=show_x))
    panel_grobs[[(i-1)*3+2]] <- ggplotGrob(make_p_dots(d, "RelEff", hline=1, show_x=show_x))
    panel_grobs[[(i-1)*3+3]] <- ggplotGrob(make_p_dots(d, "Coverage", hline=95, show_x=show_x))
  }

  row_labels <- c("PATE\nGood Overlap","PATE\nPoor Overlap","PATT\nGood Overlap","PATT\nPoor Overlap")
  row_bg <- c("white","#EBEBEB","white","#EBEBEB")
  row_label_grobs <- lapply(1:4, function(i) {
    ggplotGrob(ggplot() +
      annotate("text", x=0.5, y=0.5, label=row_labels[i], fontface="bold", size=5.5, lineheight=1.15) +
      theme_void() + theme(plot.background=element_rect(fill=row_bg[i], color=NA)))
  })

  col_titles <- c("Abs. Relative Bias (%)","Relative Efficiency","Coverage (%)")
  col_header_grobs <- lapply(col_titles, function(t) {
    ggplotGrob(ggplot() + annotate("text", x=0.5, y=0.5, label=t, fontface="bold", size=5.5) + theme_void())
  })

  xlab_grob <- ggplotGrob(ggplot() +
    annotate("text", x=0.5, y=0.5, label="Model Specification", fontface="bold", size=5) + theme_void())

  # Legend: two rows - top row filled (affected), bottom row explains hollow (unaffected)
  leg_df <- data.frame(x=1:5, y=1, Method=factor(levels(df$Method), levels=levels(df$Method)))
  leg_p <- ggplot(leg_df, aes(x=x, y=y, color=Method, shape=Method)) +
    geom_point(size=c(5,4.5,4.5,5.2,6.5), stroke=c(0.8,0.7,0.7,0.8,1.5)) +
    scale_color_manual(values=method_colors) +
    scale_shape_manual(values=filled_shapes) +
    guides(color=guide_legend(nrow=1, title=NULL,
      override.aes=list(shape=filled_shapes, size=c(5,4.5,4.5,5.2,6.5), stroke=c(0.8,0.7,0.7,0.8,1.5))),
      shape="none") +
    theme_void() + theme(legend.position="bottom", legend.text=element_text(size=14, face="bold"),
      legend.title=element_blank(), legend.key.width=unit(1.5,"cm"),
      legend.spacing.x=unit(0.3,"cm"), legend.key.height=unit(1.0,"cm"))
  leg_grob <- wdsm_bottom_legend(leg_p)

  note_grob <- ggplotGrob(ggplot() +
    annotate("text", x=0.5, y=0.5,
             label="Faded = method unaffected by that misspecification (uses only one score)",
             size=3.5, fontface="italic", color="grey35") +
    theme_void())

  layout_mat <- rbind(
    c(NA, 1, 2, 3),
    c(4, 5, 6, 7),
    c(8, 9, 10, 11),
    c(12, 13, 14, 15),
    c(16, 17, 18, 19),
    c(NA, 20, 20, 20),
    c(21, 21, 21, 21),
    c(22, 22, 22, 22)
  )

  grob_list <- c(
    col_header_grobs,
    list(row_label_grobs[[1]]), panel_grobs[1:3],
    list(row_label_grobs[[2]]), panel_grobs[4:6],
    list(row_label_grobs[[3]]), panel_grobs[7:9],
    list(row_label_grobs[[4]]), panel_grobs[10:12],
    list(xlab_grob),
    list(leg_grob),
    list(note_grob)
  )

  g <- arrangeGrob(grobs=grob_list, layout_matrix=layout_mat,
                   widths=unit.c(unit(1.8, "in"), unit(c(1, 1, 1), "null")),
                   heights=unit(c(0.4, 3, 3, 3, 3, 0.3, 0.6, 0.25), "null"),
                   top=textGrob(title_text, gp=gpar(fontsize=18, fontface="bold")))

  ggsave(paste0(outdir,"/png/",outname,".png"), g, width=13, height=15, dpi=300, bg="white")
  ggsave(paste0(outdir,"/pdf/",outname,".pdf"), g, width=13, height=15)
  cat("Saved:", outdir, "/", outname, "\n")
}

## Dot-only, all solid (no hollow distinction)
make_p_dots_solid <- function(d, metric, hline=NULL, show_x=FALSE) {
  d$Scenario <- factor(d$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))
  dot_sizes <- c(PSM=5, PGM=4.5, DSM=4.5, "SW-PSM"=5.2, WDSM=6)
  d$pt_size <- dot_sizes[as.character(d$Method)]
  d$pt_alpha <- ifelse(d$Method=="WDSM", 1.0, 0.85)
  d$pt_stroke <- ifelse(d$Method=="WDSM", 1.5, 0.7)

  p <- ggplot(d, aes(x=Scenario, y=.data[[metric]], color=Method, shape=Method)) +
    geom_point(size=d$pt_size, alpha=d$pt_alpha, stroke=d$pt_stroke) +
    scale_color_manual(values=method_colors) +
    scale_shape_manual(values=filled_shapes) +
    scale_y_continuous(expand=expansion(mult=c(0.05,0.12))) +
    labs(x=NULL, y=NULL) +
    theme_bw(base_size=12) +
    theme(axis.text.y=element_text(size=11, face="bold"),
          panel.grid.minor=element_blank(), panel.grid.major.x=element_blank(),
          legend.position="none", plot.margin=margin(3,6,3,3))
  if (!is.null(hline)) p <- p + geom_hline(yintercept=hline, linetype="dashed", color="grey40", linewidth=0.5)
  if (show_x) {
    p <- p + theme(axis.text.x=element_text(size=11, face="bold"))
  } else {
    p <- p + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
  }
  p
}

make_figure_dots_solid <- function(df, title_text, outname, outdir="Figures") {
  df$Method <- factor(df$Method, levels=c("PSM","PGM","DSM","SW-PSM","WDSM"))
  df$Scenario <- factor(df$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))

  panel_grobs <- list()
  for (i in 1:4) {
    d <- df %>% filter(Estimand==row_defs[[i]]$est, Overlap==row_defs[[i]]$ov)
    show_x <- (i == 4)
    panel_grobs[[(i-1)*3+1]] <- ggplotGrob(make_p_dots_solid(d, "Bias", hline=0, show_x=show_x))
    panel_grobs[[(i-1)*3+2]] <- ggplotGrob(make_p_dots_solid(d, "RelEff", hline=1, show_x=show_x))
    panel_grobs[[(i-1)*3+3]] <- ggplotGrob(make_p_dots_solid(d, "Coverage", hline=95, show_x=show_x))
  }

  row_labels <- c("PATE\nGood Overlap","PATE\nPoor Overlap","PATT\nGood Overlap","PATT\nPoor Overlap")
  row_bg <- c("white","#EBEBEB","white","#EBEBEB")
  row_label_grobs <- lapply(1:4, function(i) {
    ggplotGrob(ggplot() +
      annotate("text", x=0.5, y=0.5, label=row_labels[i], fontface="bold", size=5.5, lineheight=1.15) +
      theme_void() + theme(plot.background=element_rect(fill=row_bg[i], color=NA)))
  })
  col_titles <- c("Abs. Relative Bias (%)","Relative Efficiency","Coverage (%)")
  col_header_grobs <- lapply(col_titles, function(t) {
    ggplotGrob(ggplot() + annotate("text", x=0.5, y=0.5, label=t, fontface="bold", size=5.5) + theme_void())
  })
  xlab_grob <- ggplotGrob(ggplot() +
    annotate("text", x=0.5, y=0.5, label="Model Specification", fontface="bold", size=5) + theme_void())

  leg_df <- data.frame(x=1:5, y=1, Method=factor(levels(df$Method), levels=levels(df$Method)))
  leg_p <- ggplot(leg_df, aes(x=x, y=y, color=Method, shape=Method)) +
    geom_point(size=c(5,4.5,4.5,5.2,6.5), stroke=c(0.8,0.7,0.7,0.8,1.5)) +
    scale_color_manual(values=method_colors) + scale_shape_manual(values=filled_shapes) +
    guides(color=guide_legend(nrow=1, title=NULL,
      override.aes=list(shape=filled_shapes, size=c(5,4.5,4.5,5.2,6.5), stroke=c(0.8,0.7,0.7,0.8,1.5))),
      shape="none") +
    theme_void() + theme(legend.position="bottom", legend.text=element_text(size=14, face="bold"),
      legend.title=element_blank(), legend.key.width=unit(1.5,"cm"),
      legend.spacing.x=unit(0.3,"cm"), legend.key.height=unit(1.0,"cm"))
  leg_grob <- wdsm_bottom_legend(leg_p)

  layout_mat <- rbind(c(NA,1,2,3), c(4,5,6,7), c(8,9,10,11), c(12,13,14,15), c(16,17,18,19), c(NA,20,20,20), c(21,21,21,21))
  grob_list <- c(col_header_grobs, list(row_label_grobs[[1]]), panel_grobs[1:3],
    list(row_label_grobs[[2]]), panel_grobs[4:6], list(row_label_grobs[[3]]), panel_grobs[7:9],
    list(row_label_grobs[[4]]), panel_grobs[10:12], list(xlab_grob), list(leg_grob))

  g <- arrangeGrob(grobs=grob_list, layout_matrix=layout_mat,
    widths=unit.c(unit(1.8, "in"), unit(c(1, 1, 1), "null")), heights=unit(c(0.4,3,3,3,3,0.3,0.6),"null"),
    top=textGrob(title_text, gp=gpar(fontsize=18, fontface="bold")))
  ggsave(paste0(outdir,"/png/",outname,".png"), g, width=13, height=14.5, dpi=300, bg="white")
  ggsave(paste0(outdir,"/pdf/",outname,".pdf"), g, width=13, height=14.5)
  cat("Saved:", outdir, "/", outname, "\n")
}

