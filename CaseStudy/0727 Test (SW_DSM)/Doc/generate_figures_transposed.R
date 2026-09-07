library(ggplot2); library(dplyr); library(gridExtra); library(grid); library(cowplot)

pate_dir <- "Results"; patt_dir <- "Results_PATT"
safe_extract <- function(x) { if(is.null(x)) NA else if(is.list(x)&&length(x)>0) x[[1]] else x }

build_df <- function(sampling_prefix) {
  rows_list <- list()
  for (estimand in c("PATE","PATT")) {
    rdir <- if(estimand=="PATE") pate_dir else patt_dir
    for (overlap in c("Good Overlap","Poor Overlap")) {
      o_file <- gsub(" ","",overlap)
      fname <- paste0(sampling_prefix,"_",o_file,"_CorCor_M135_1000rep.RData")
      if (!file.exists(file.path(rdir,fname))) { cat("  Skip:",fname,"\n"); next }
      load(file.path(rdir,fname)); tp <- true_pate; psm_var <- NULL
      for (scenario in c("CorCor","MisCor","CorMis","MisMis")) {
        load(file.path(rdir, paste0(sampling_prefix,"_",o_file,"_",scenario,"_M135_1000rep.RData")))
        valid <- all_results[sapply(all_results, function(x) !is.null(x))]
        key <- paste0(scenario,"_M5")
        results <- lapply(valid, function(x) x[[key]])
        results <- results[!sapply(results,is.null)]
        if (scenario=="CorCor") {
          e_psm <- as.numeric(sapply(results, function(x) safe_extract(x$ps_unweighted$estimate)))
          psm_var <- var(e_psm[!is.na(e_psm)])
        }
        for (m_name in c("PSM","PGM","DSM","SW-PSM","WDSM")) {
          m_code <- c(PSM="ps_unweighted",PGM="pg_unweighted",DSM="dsm_unweighted",
                      "SW-PSM"="ps_weighted",WDSM="wdsm_multinomial")[[m_name]]
          ests <- as.numeric(sapply(results, function(x) safe_extract(x[[m_code]]$estimate)))
          ci_lo <- as.numeric(sapply(results, function(x) safe_extract(x[[m_code]]$ci_lower)))
          ci_hi <- as.numeric(sapply(results, function(x) safe_extract(x[[m_code]]$ci_upper)))
          ests <- ests[!is.na(ests)]; ci_lo <- ci_lo[!is.na(ci_lo)]; ci_hi <- ci_hi[!is.na(ci_hi)]
          if (length(ests)>5) {
            rows_list[[length(rows_list)+1]] <- data.frame(
              Estimand=estimand, Overlap=overlap,
              Scenario=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis")[match(scenario,c("CorCor","MisCor","CorMis","MisMis"))],
              Method=m_name,
              Bias=abs((mean(ests)-tp)/abs(tp)*100),
              RelEff=psm_var/var(ests),
              Coverage=mean(ci_lo<=tp & ci_hi>=tp)*100,
              stringsAsFactors=FALSE)
          }
        }
      }
    }
  }
  do.call(rbind, rows_list)
}

method_colors <- c("PSM"="#4E79A7","PGM"="#F28E2B","DSM"="#7B2D8E","SW-PSM"="#E15759","WDSM"="#59A14F")
method_shapes <- c(PSM=16, PGM=15, DSM=17, "SW-PSM"=18, WDSM=8)
method_sizes  <- c(PSM=4.2, PGM=3.5, DSM=3.5, "SW-PSM"=4.5, WDSM=5)
method_lwd    <- c(PSM=0.7, PGM=0.7, DSM=0.7, "SW-PSM"=0.7, WDSM=1.5)
method_alpha  <- c(PSM=0.6, PGM=0.6, DSM=0.6, "SW-PSM"=0.6, WDSM=0.95)
method_stroke <- c(PSM=0.7, PGM=0.7, DSM=0.7, "SW-PSM"=0.7, WDSM=1.2)

filled_shapes <- c(PSM=16, PGM=15, DSM=17, "SW-PSM"=18, WDSM=8)
hollow_shapes <- c(PSM=1, PGM=0, DSM=2, "SW-PSM"=5, WDSM=8)

col_defs <- list(
  list(est="PATE", ov="Good Overlap"),
  list(est="PATE", ov="Poor Overlap"),
  list(est="PATT", ov="Good Overlap"),
  list(est="PATT", ov="Poor Overlap")
)
col_labels <- c("PATE\nGood Overlap","PATE\nPoor Overlap","PATT\nGood Overlap","PATT\nPoor Overlap")
col_bg <- c("white","#EBEBEB","white","#EBEBEB")
row_metrics <- c("Bias","RelEff","Coverage")
row_metric_labels <- c("Relative\nBias (%)","Relative\nEfficiency","Coverage\n(%)")

# ========== LINES ==========
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
          legend.position="none", plot.margin=margin(3,6,3,3))
  if (!is.null(hline)) p <- p + geom_hline(yintercept=hline, linetype="dashed", color="grey40", linewidth=0.5)
  if (show_x) {
    p <- p + theme(axis.text.x=element_text(size=11, face="bold"))
  } else {
    p <- p + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
  }
  p
}

make_figure_T <- function(df, title_text, outname, outdir) {
  df$Method <- factor(df$Method, levels=c("PSM","PGM","DSM","SW-PSM","WDSM"))
  df$Scenario <- factor(df$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))

  # 3 rows (metrics) x 4 cols (estimand/overlap)
  panel_grobs <- list()
  for (r in 1:3) {
    metric <- row_metrics[r]
    hline <- if(metric=="Coverage") 95 else if(metric=="RelEff") 1 else 0
    for (c in 1:4) {
      d <- df %>% filter(Estimand==col_defs[[c]]$est, Overlap==col_defs[[c]]$ov)
      show_x <- (r == 3)
      panel_grobs[[(r-1)*4+c]] <- ggplotGrob(make_p(d, metric, hline=hline, show_x=show_x))
    }
  }

  col_header_grobs <- lapply(1:4, function(i) {
    ggplotGrob(ggplot() + annotate("text", x=0.5, y=0.5, label=col_labels[i],
      fontface="bold", size=5, lineheight=1.1) +
      theme_void() + theme(plot.background=element_rect(fill=col_bg[i], color=NA)))
  })

  row_label_grobs <- lapply(row_metric_labels, function(t) {
    ggplotGrob(ggplot() + annotate("text", x=0.5, y=0.5, label=t,
      fontface="bold", size=5, lineheight=1.1) + theme_void())
  })

  xlab_grob <- ggplotGrob(ggplot() +
    annotate("text", x=0.5, y=0.5, label="Model Specification", fontface="bold", size=5) + theme_void())

  leg_df <- data.frame(x=rep(1:4,5), y=rep(1:5,each=4),
    Method=factor(rep(levels(df$Method),each=4), levels=levels(df$Method)))
  leg_p <- ggplot(leg_df, aes(x=x,y=y,color=Method,shape=Method,size=Method,linewidth=Method)) +
    geom_line() + geom_point(stroke=0.8) +
    scale_color_manual(values=method_colors) + scale_shape_manual(values=method_shapes) +
    scale_size_manual(values=c(PSM=3,PGM=3,DSM=3,"SW-PSM"=3.5,WDSM=5)) +
    scale_linewidth_manual(values=c(PSM=0.6,PGM=0.6,DSM=0.6,"SW-PSM"=0.6,WDSM=1.5)) +
    guides(color=guide_legend(nrow=1,title=NULL,
      override.aes=list(shape=method_shapes,size=c(4.2,3.5,3.5,4.5,5.5),
        linewidth=c(0.6,0.6,0.6,0.6,1.5),stroke=c(0.5,0.5,0.5,0.5,1.0))),
      shape="none",size="none",linewidth="none") +
    theme_void() + theme(legend.position="bottom",legend.text=element_text(size=14,face="bold"),
      legend.title=element_blank(),legend.key.width=unit(2.2,"cm"),
      legend.spacing.x=unit(0.6,"cm"),legend.key.height=unit(1.2,"cm"))
  leg_grob <- cowplot::get_legend(leg_p)

  title_grob <- ggplotGrob(ggplot() +
    annotate("text", x=0.5, y=0.5, label=title_text, fontface="bold", size=6.5) + theme_void())

  layout_mat <- rbind(
    c(NA,22,22,22,22),
    c(NA, 1, 2, 3, 4),
    c(5, 6, 7, 8, 9),
    c(10,11,12,13,14),
    c(15,16,17,18,19),
    c(NA,20,20,20,20),
    c(21,21,21,21,21)
  )
  grob_list <- c(
    col_header_grobs,
    list(row_label_grobs[[1]]), panel_grobs[1:4],
    list(row_label_grobs[[2]]), panel_grobs[5:8],
    list(row_label_grobs[[3]]), panel_grobs[9:12],
    list(xlab_grob), list(leg_grob), list(title_grob)
  )
  g <- arrangeGrob(grobs=grob_list, layout_matrix=layout_mat,
    widths=unit(c(1.1,3,3,3,3),"null"),
    heights=unit(c(0.35,0.5,3,3,3,0.3,0.6),"null"))
  ggsave(paste0(outdir,"/png/",outname,".png"), g, width=16, height=12, dpi=300, bg="white")
  ggsave(paste0(outdir,"/pdf/",outname,".pdf"), g, width=16, height=12)
  cat("Saved:", outname, "\n")
}

# ========== DOTS SOLID ==========
make_p_dots_solid <- function(d, metric, hline=NULL, show_x=FALSE) {
  d$Scenario <- factor(d$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))
  dot_sizes <- c(PSM=5, PGM=4.5, DSM=4.5, "SW-PSM"=5.2, WDSM=6)
  d$pt_size <- dot_sizes[as.character(d$Method)]
  d$pt_alpha <- ifelse(d$Method=="WDSM", 1.0, 0.85)
  d$pt_stroke <- ifelse(d$Method=="WDSM", 1.5, 0.7)
  p <- ggplot(d, aes(x=Scenario, y=.data[[metric]], color=Method, shape=Method)) +
    geom_point(size=d$pt_size, alpha=d$pt_alpha, stroke=d$pt_stroke) +
    scale_color_manual(values=method_colors) + scale_shape_manual(values=filled_shapes) +
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

make_figure_dots_solid_T <- function(df, title_text, outname, outdir) {
  df$Method <- factor(df$Method, levels=c("PSM","PGM","DSM","SW-PSM","WDSM"))
  df$Scenario <- factor(df$Scenario, levels=c("Cor|Cor","Mis|Cor","Cor|Mis","Mis|Mis"))
  panel_grobs <- list()
  for (r in 1:3) {
    metric <- row_metrics[r]; hline <- if(metric=="Coverage") 95 else if(metric=="RelEff") 1 else 0
    for (c in 1:4) {
      d <- df %>% filter(Estimand==col_defs[[c]]$est, Overlap==col_defs[[c]]$ov)
      panel_grobs[[(r-1)*4+c]] <- ggplotGrob(make_p_dots_solid(d, metric, hline=hline, show_x=(r==3)))
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
  leg_grob <- cowplot::get_legend(leg_p)
  title_grob <- ggplotGrob(ggplot() +
    annotate("text", x=0.5, y=0.5, label=title_text, fontface="bold", size=6.5) + theme_void())
  layout_mat <- rbind(c(NA,22,22,22,22), c(NA,1,2,3,4), c(5,6,7,8,9), c(10,11,12,13,14), c(15,16,17,18,19), c(NA,20,20,20,20), c(21,21,21,21,21))
  grob_list <- c(col_header_grobs, list(row_label_grobs[[1]]), panel_grobs[1:4],
    list(row_label_grobs[[2]]), panel_grobs[5:8], list(row_label_grobs[[3]]), panel_grobs[9:12],
    list(xlab_grob), list(leg_grob), list(title_grob))
  g <- arrangeGrob(grobs=grob_list, layout_matrix=layout_mat,
    widths=unit(c(1.1,3,3,3,3),"null"), heights=unit(c(0.35,0.5,3,3,3,0.3,0.6),"null"))
  ggsave(paste0(outdir,"/png/",outname,".png"), g, width=16, height=12.5, dpi=300, bg="white")
  ggsave(paste0(outdir,"/pdf/",outname,".pdf"), g, width=16, height=12.5)
  cat("Saved:", outname, "\n")
}

# ========== DOTS HOLLOW ==========
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
  leg_grob <- cowplot::get_legend(leg_p)
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
  ggsave(paste0(outdir,"/png/",outname,".png"), g, width=16, height=12.5, dpi=300, bg="white")
  ggsave(paste0(outdir,"/pdf/",outname,".pdf"), g, width=16, height=12.5)
  cat("Saved:", outname, "\n")
}

# ========== GENERATE ALL ==========
cat("Building retrospective data...\n")
df_retro <- build_df("Retrospective")
cat("  rows:", nrow(df_retro), "\n")
make_figure_T(df_retro, "Retrospective Sampling", "lines", "Figures/Retrospective/horizontal")
make_figure_dots_solid_T(df_retro, "Retrospective Sampling", "dots_solid", "Figures/Retrospective/horizontal")
make_figure_dots_hollow_T(df_retro, "Retrospective Sampling", "dots_hollow", "Figures/Retrospective/horizontal")

cat("Building prospective data...\n")
df_prosp <- build_df("Prospective")
cat("  rows:", nrow(df_prosp), "\n")
make_figure_T(df_prosp, "Prospective Sampling", "lines", "Figures/Prospective/horizontal")
make_figure_dots_solid_T(df_prosp, "Prospective Sampling", "dots_solid", "Figures/Prospective/horizontal")
make_figure_dots_hollow_T(df_prosp, "Prospective Sampling", "dots_hollow", "Figures/Prospective/horizontal")

cat("All done\n")
