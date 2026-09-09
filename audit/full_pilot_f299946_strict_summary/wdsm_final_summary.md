# Final WDSM rerun: PILOT COMPLETE

Required matrix: 32 cells × 7 methods × 5 sample replications; B=200. Validated successes: 1120/1120.

Blocking ledger entries: 0. Allowed fractional-weight SWPSM warnings: 0.

WDSM retains every requested bootstrap draw and uses the B divisor. DSM, PGM, and PSM retain every requested draw and use sample variance with divisor B-1. SWPSM uses its subclass-cluster sandwich/delta-method variance. Every accepted confidence interval is a centered normal Wald interval.

Manifests, per-record identities, numerical configurations, R/package hashes, sampling/method seeds, finite results, all retained draws, WDSM propensity convergence, and score-equation tolerances were checked. Ordered sample IDs, sample seeds, and treatment counts must agree across PATE/PATT and all scenarios for each design/overlap/replication. Population targets must agree within each estimand/overlap. Configuration/runtime hashes account for the original RDS writer version. Source and population hashes are retained as lineage identifiers; unavailable HPC source/data files are not silently treated as re-read locally.

The only allowed warning is the exact SWPSM fractional-weight binomial warning listed in the ledger. Every other warning prevents publication finalization. Comparator rank-deficient-lm counts are retained as diagnostics; emitted unreviewed warnings still block finalization.

Relative efficiency is the Monte Carlo variance of PSM under CorCor divided by the variance of each method, within the same estimand, sampling design, and overlap. Signed bias is mean estimate minus truth; absolute bias is its absolute value. Coverage MCSE is sqrt(p(1-p)/N). No statistic uses a silently reduced finite-only subset.

All requested records passed. The 224-row wdsm_final_metrics.csv is available.

This is a five-replication pilot diagnostic, not a replacement for the 1000-replication manuscript results.
