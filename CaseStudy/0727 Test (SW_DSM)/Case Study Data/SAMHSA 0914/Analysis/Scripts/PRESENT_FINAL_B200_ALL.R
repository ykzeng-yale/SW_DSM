#!/usr/bin/env Rscript

ar <- readRDS('Analysis/Results/ALL_10_FULL_DATA_B200_FINAL.rds')

cat('\n================================================================\n')
cat('FINAL RESULTS: ALL 10 QUESTIONS (FULL DATA, B=200)\n')
cat('================================================================\n\n')

questions <- list(
  list(n=1, t='Gender → Alcohol (days/year)'),
  list(n=2, t='Gender → Marijuana (days/month)'),
  list(n=3, t='Employment → Alcohol (days/year)'),
  list(n=4, t='Age → Marijuana (days/month)'),
  list(n=5, t='Education → Alcohol (days/year)'),
  list(n=7, t='Black vs White → Alcohol (days/year)'),
  list(n=10, t='Hispanic vs White → Alcohol (days/year)'),
  list(n=11, t='Gender → Binge (days/month)'),
  list(n=12, t='Urban vs Rural → Alcohol (days/year)'),
  list(n=13, t='Income → Marijuana (days/month)')
)

for(i in 1:10) {
  q <- questions[[i]]
  r <- ar[[i]]
  
  cat(sprintf('Q%d: %s\n', q$n, q$t))
  cat('Method                   | Estimate |   SE   | 95% CI\n')
  cat('-------------------------|----------|--------|-----------------\n')
  
  methods <- c('WDSM (M=5, weighted)', 'DSM (M=1, unweighted)', 
               'PSM (M=1, unweighted)', 'PGM (M=1, unweighted)', 'PS Full (weighted)')
  
  for(j in 1:5) {
    if(!is.null(r[[j]]) && length(r[[j]]) >= 4 && !is.na(r[[j]][[1]])) {
      cat(sprintf('%-24s | %8.2f | %6.2f | [%7.2f,%7.2f]\n',
                  methods[j], r[[j]][[1]], r[[j]][[2]], r[[j]][[3]], r[[j]][[4]]))
    } else {
      cat(sprintf('%-24s | FAILED\n', methods[j]))
    }
  }
  cat('\n')
}

cat('================================================================\n')
cat('STATUS: All 10 questions run with FULL DATA (no sampling)\n')
cat('Bootstrap: B=200 | Survey weights: ANALWT2_C1\n')
cat('================================================================\n')
"
