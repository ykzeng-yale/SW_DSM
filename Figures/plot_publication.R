# Horizontal simulation-figure layouts; input data are supplied by the caller.
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

filled_shapes <- c(PSM=16, PGM=15, DSM=17, "SW-PSM"=18, WDSM=8)

col_defs <- list(
  list(est="PATE", ov="Good Overlap"),
  list(est="PATE", ov="Poor Overlap"),
  list(est="PATT", ov="Good Overlap"),
  list(est="PATT", ov="Poor Overlap")
)
col_labels <- c("PATE\nGood Overlap","PATE\nPoor Overlap","PATT\nGood Overlap","PATT\nPoor Overlap")
col_bg <- c("white","#EBEBEB","white","#EBEBEB")
row_metrics <- c("Bias","RelEff","Coverage")
row_metric_labels <- c("Absolute\nRelative\nBias (%)","Relative\nEfficiency","Coverage\n(%)")

add_affected <- function(df) {
  df$Affected <- TRUE
  df$Affected[df$Method %in% c("PSM","SW-PSM") & df$Scenario %in% c("Cor|Mis","Mis|Mis")] <- FALSE
  df$Affected[df$Method == "PGM" & df$Scenario %in% c("Mis|Cor","Mis|Mis")] <- FALSE
  df
}

make_p_dots <- function(d, metric, hline=NULL, show_x=FALSE) {
  d$Scenario <- factor(d$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))
  d$pt_shape <- filled_shapes[as.character(d$Method)]
  dot_sizes <- c(PSM=5, PGM=4.5, DSM=4.5, "SW-PSM"=5.2, WDSM=6)
  d$pt_size <- dot_sizes[as.character(d$Method)]
  d$pt_alpha <- ifelse(!d$Affected, 0.2, ifelse(d$Method=="WDSM", 1.0, 0.85))
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
  if (show_x) p <- p + theme(axis.text.x=element_text(size=11, face="bold"))
  else p <- p + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
  p
}

make_figure_dots_hollow_T <- function(df, title_text, outname, outdir) {
  df$Method <- factor(df$Method, levels=c("PSM","PGM","DSM","SW-PSM","WDSM"))
  df$Scenario <- factor(df$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))
  df <- add_affected(df)
  panel_grobs <- list()
  for (r in 1:3) {
    metric <- row_metrics[r]; hline <- if(metric=="Coverage") 95 else if(metric=="RelEff") 1 else 0
    for (c in 1:4) {
      d <- df %>% filter(Estimand==col_defs[[c]]$est, Overlap==col_defs[[c]]$ov)
      panel_grobs[[(r-1)*4+c]] <- ggplotGrob(make_p_dots(d, metric, hline=hline, show_x=(r==3)))
    }
  }
  col_header_grobs <- lapply(1:4, function(i) {
    ggplotGrob(ggplot() + annotate("text",x=0.5,y=0.5,label=col_labels[i],fontface="bold",size=4.2,lineheight=1.1) +
      theme_void() + theme(plot.background=element_rect(fill=col_bg[i],color=NA)))
  })
  row_label_grobs <- lapply(row_metric_labels, function(t) {
    ggplotGrob(ggplot() + annotate("text",x=0.5,y=0.5,label=t,fontface="bold",size=4.2,lineheight=1.1) + theme_void())
  })
  xlab_grob <- ggplotGrob(ggplot() + annotate("text",x=0.5,y=0.5,label="Model Specification",fontface="bold",size=4.5) + theme_void())
  leg_df <- data.frame(x=1:5, y=1, Method=factor(levels(df$Method), levels=levels(df$Method)))
  leg_p <- ggplot(leg_df, aes(x=x,y=y,color=Method,shape=Method)) +
    geom_point(size=c(5,4.5,4.5,5.2,6.5), stroke=c(0.8,0.7,0.7,0.8,1.5)) +
    scale_color_manual(values=method_colors) + scale_shape_manual(values=filled_shapes) +
    guides(color=guide_legend(nrow=1,title=NULL,
      override.aes=list(shape=filled_shapes,size=c(4,4,4,4.5,6),stroke=c(0.6,0.6,0.6,0.6,1.5))),shape="none") +
    theme_void() + theme(legend.position="bottom",legend.text=element_text(size=14,face="bold"),
      legend.title=element_blank(),legend.key.width=unit(1.5,"cm"),legend.spacing.x=unit(0.3,"cm"))
  leg_grob <- wdsm_bottom_legend(leg_p)
  note_grob <- ggplotGrob(ggplot() +
    annotate("text",x=0.5,y=0.5,label="Faded = method unaffected by that misspecification (uses only one score)",
      size=3.5,fontface="italic",color="grey35") + theme_void())
  title_grob <- ggplotGrob(ggplot() +
    annotate("text", x=0.5, y=0.5, label=title_text, fontface="bold", size=6.5) + theme_void())
  layout_mat <- rbind(c(NA,23,23,23,23), c(NA,1,2,3,4), c(5,6,7,8,9), c(10,11,12,13,14), c(15,16,17,18,19),
    c(NA,20,20,20,20), c(21,21,21,21,21), c(22,22,22,22,22))
  grob_list <- c(col_header_grobs, list(row_label_grobs[[1]]), panel_grobs[1:4],
    list(row_label_grobs[[2]]), panel_grobs[5:8], list(row_label_grobs[[3]]), panel_grobs[9:12],
    list(xlab_grob), list(leg_grob), list(note_grob), list(title_grob))
  g <- arrangeGrob(grobs=grob_list, layout_matrix=layout_mat,
    widths=unit(c(1.1,3,3,3,3),"null"), heights=unit(c(0.35,0.5,3,3,3,0.3,0.6,0.25),"null"))
  ggsave(file.path(outdir, paste0(outname,".png")), g, width=16, height=12.5, dpi=300, bg="white")
  ggsave(file.path(outdir, paste0(outname,".pdf")), g, width=16, height=12.5)
  cat("Saved:", outname, "\n")
}
