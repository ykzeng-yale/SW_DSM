#!/usr/bin/env Rscript
source("R/wdsm_ties.R")
checks <- 0L
check <- function(x, label) { if (!isTRUE(x)) stop(label); checks <<- checks + 1L }
# Identical-score cell: independent recipients must not share a fixed first-M set.
A <- c(rep(0, 60), rep(1, 600)); D <- matrix(0, length(A), 2L)
set.seed(91); before <- .Random.seed; kind <- RNGkind()
random <- wdsm_make_matches(A, D, M = 5L, estimand = "PATT", tie_seed = 719L)
check(identical(before, .Random.seed) && identical(kind, RNGkind()), "Preserve caller RNG")
check(identical(random, wdsm_make_matches(A, D, M=5L, estimand="PATT", tie_seed=719L)), "Reproduce explicit seed")
different <- wdsm_make_matches(A, D, M=5L, estimand="PATT", tie_seed=720L)
check(!identical(random$matches_0, different$matches_0), "Different tie seed changes selection")
selected <- random$matches_0[A == 1]
check(all(vapply(selected, length, integer(1)) == 5L), "Keep exactly M distinct donors")
check(all(vapply(selected, function(x) !anyDuplicated(x), logical(1))), "No within-recipient replacement")
check(length(unique(vapply(selected, paste, collapse=",", character(1)))) > 500L,
      "Recipient-specific allocation varies across an identical-score cell")
usage <- tabulate(unlist(selected), nbins=60)
check(all(usage > 20) && all(usage < 85), "Uniform selection spreads reuse across the donor pool")
legacy <- wdsm_make_matches(A,D,M=5L,estimand="PATT",tie_rule="row_order")
check(all(vapply(legacy$matches_0[A==1], identical, logical(1), 1:5)), "Legacy diagnostic exactly exposes first-M concentration")
check(random$tie_diagnostics$arms[["0"]]$boundary_tie_recipients == 600L, "Count all allocation-relevant ties")
# One closer donor plus four tied at the boundary: retain the closer donor and
# sample just the one needed boundary donor; exclude the farther candidates.
A <- c(rep(0,7),rep(1,600)); D<-cbind(c(0,1,-1,1,-1,3,4,rep(0,600)),0)
x<-wdsm_make_matches(A,D,M=2L,estimand="PATT",tie_seed=901L,tie_tolerance=0)
check(all(vapply(x$matches_0[A==1], function(j) 1L %in% j && sum(j %in% 2:5)==1L && !any(j %in% 6:7),logical(1))), "Retain strictly closer donors and exclude farther donors")
frequency<-tabulate(unlist(x$matches_0[A==1]),7)[2:5]
check(all(frequency>100 & frequency<200), "Uniform boundary selection only")
# No allocation-relevant ties: the new and old choices coincide for both arms.
A<-rep(0:1,each=8);D<-cbind(seq_along(A)^1.37,seq_along(A)^.61)
for(M in c(1L,3L,5L))for(est in c("PATE","PATT")){
 a<-wdsm_make_matches(A,D,D,M,est,tie_seed=11L)
 b<-wdsm_make_matches(A,D,D,M,est,tie_rule="row_order")
 check(identical(a$matches_0,b$matches_0)&&identical(a$matches_1,b$matches_1),paste("No-tie parity",M,est))
}
# Restore absent seeds and nondefault generators, including the error path.
RNGkind("L'Ecuyer-CMRG");set.seed(4);before<-.Random.seed;kind<-RNGkind()
invisible(wdsm_make_matches(A,D,D,3));check(identical(before,.Random.seed)&&identical(kind,RNGkind()),"Restore nondefault generator")
tryCatch(wdsm_make_matches(A,D[-1,],D,3),error=function(e)NULL)
check(identical(before,.Random.seed)&&identical(kind,RNGkind()),"Restore RNG on invalid scores")
rm('.Random.seed',envir=.GlobalEnv);invisible(wdsm_make_matches(A,D,D,3))
check(!exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE),"Restore absent caller seed")
cat("PASS:",checks,"independent tie-allocation and RNG checks.\n")
