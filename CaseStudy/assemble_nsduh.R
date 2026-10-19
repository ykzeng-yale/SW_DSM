#!/usr/bin/env Rscript
# Combine the four independently scheduled NSDUH analysis tasks.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=1L)stop("Usage: Rscript CaseStudy/assemble_nsduh.R NSDUH_OUTPUT_DIRECTORY")
input <- normalizePath(args[1L],mustWork=TRUE)
paths <- file.path(input,sprintf("task_%02d.rds",c(3L,4L,14L,15L)))
stopifnot(all(file.exists(paths)))
destination <- file.path(input,"results.csv")
if(file.exists(destination))stop("Refusing to overwrite results.csv")
records <- lapply(paths,readRDS)
stopifnot(all(vapply(records,function(x)identical(x$status,"complete"),logical(1))))
final <- do.call(rbind,lapply(records,`[[`,"summary"))
final <- final[order(match(final$outcome,c("AMIPY","SMIPY")),
  match(final$method,c("PSM","PGM","DSM","SWPSM","WDSM"))),]
rownames(final) <- NULL
stopifnot(nrow(final)==10L,all(final$study=="NSDUH"),all(final$n==17471L),
  all(is.finite(as.matrix(final[c("estimate","SE","lower","upper")]))))
write.csv(final,destination,row.names=FALSE)
cat("Saved ten NSDUH publication estimates to",destination,"\n")
