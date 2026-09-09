#!/usr/bin/env Rscript

ar <- readRDS('Analysis/Results/ALL_10_FULL_DATA_B50.rds')

cat('\n================================================================\n')
cat('CORRECTED RESULTS: ALL 10 QUESTIONS (FULL DATA, B=50)\n')
cat('================================================================\n')
cat('Fixed: Using full data (no stratified sampling)\n')
cat('Survey weights properly applied\n')
cat('================================================================\n\n')

questions <- list(
  list(n=1, title='Gender → Alcohol (days/year)', idx=1),
  list(n=2, title='Gender → Marijuana (days/month)', idx=2),
  list(n=3, title='Employment → Alcohol (days/year)', idx=3),
  list(n=4, title='Age → Marijuana (days/month)', idx=4),
  list(n=5, title='Education → Alcohol (days/year)', idx=5),
  list(n=7, title='Black vs White → Alcohol (days/year)', idx=6),
  list(n=10, title='Hispanic vs White → Alcohol (days/year)', idx=7),
  list(n=11, title='Gender → Binge (days/month)', idx=8),
  list(n=12, title='Urban vs Rural → Alcohol (days/year)', idx=9),
  list(n=13, title='Income → Marijuana (days/month)', idx=10)
)

for(q in questions) {
  r <- ar[[q$idx]]
  cat(sprintf('Q%d: %s\n', q$n, q$title))
  cat('Method                   | Estimate |   SE   | 95% CI\n')
  cat('-------------------------|----------|--------|-----------------\n')
  
  methods <- c('WDSM (M=5, weighted)', 'DSM (M=1, unweighted)', 'PSM (M=1, unweighted)', 
               'PGM (M=1, unweighted)', 'PS Full (weighted)')
  
  for(i in 1:5) {
    if(!is.na(r[[i]][[1]])) {
      cat(sprintf('%-24s | %8.2f | %6.2f | [%7.2f,%7.2f]\n', 
                  methods[i], r[[i]][[1]], r[[i]][[2]], r[[i]][[3]], r[[i]][[4]]))
    } else {
      cat(sprintf('%-24s | %8s | %6s | %15s\n', methods[i], 'FAILED', '---', '---'))
    }
  }
  cat('\n')
}

cat('================================================================\n')
cat('Note: B=200 version running in background for final results\n')
cat('================================================================\n')
"
