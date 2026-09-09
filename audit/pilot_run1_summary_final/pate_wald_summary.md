# Corrected PATE Wald rerun: PILOT INCOMPLETE OR FAILED AUDIT

Scope: 16 of 16 cells; 2 requested sample replications per cell; M = 1, 3, 5; B = 200; nominal coverage = 95.0%.

Record completeness: FALSE. Historical point-estimate agreement within 1e-8: TRUE. Full 16-cell, 1000-replication production matrix finalized: FALSE.

Every accepted estimate has all requested finite bootstrap draws. The draws reproduce the B-divisor standard error and the centered Wald endpoints. Record identities and configurations match their manifest; configuration and runtime hashes were checked. Source-code and population hashes are recorded lineage identifiers; this summary does not independently re-read unavailable HPC source/data files.

Coverage and its estimated binomial Monte Carlo standard error use only successful validated estimates, with the denominator shown. Failed, invalid, or missing records remain explicit and prevent finalization. Empirical SD uses successful point estimates. Completed means a readable, validated record with an estimator outcome, including numerical failure; corrupted/unverifiable records are integrity failures.

Old stored coverage and old-SE Wald coverage are historical diagnostics. The old-SE calculation changes endpoints only and does not repair the historical replication formula. The CSV includes both all available historical replications and the same replication-index subset as this run. Historical comparator methods are not recomputed or combined into a common-run result.

The point-estimate gate compares the same historical replication index. Matching points alone does not prove identical sampled IDs or full historical execution lineage; bootstrap streams in this rerun are explicitly new.

| Cell | M | Success / expected | Numerical / integrity / missing | Corrected coverage (n) | MCSE | Mean SE | Empirical SD | Old stored / old-SE Wald (same indices) | Point mismatches / paired |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Retrospective_GoodOverlap_CorCor | 1 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_CorCor | 3 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_CorCor | 5 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_MisCor | 1 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_MisCor | 3 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_MisCor | 5 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_CorMis | 1 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_CorMis | 3 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_CorMis | 5 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_MisMis | 1 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_MisMis | 3 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_GoodOverlap_MisMis | 5 | 0 / 2 | 2 / 0 / 0 | NA (0) | NA | NA | NA | 100.0% / 100.0% | 0 / 0 |
| Retrospective_PoorOverlap_CorCor | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.131 | 0.150 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_CorCor | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.124 | 0.121 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_CorCor | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.120 | 0.120 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_MisCor | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.133 | 0.150 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_MisCor | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.124 | 0.109 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_MisCor | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.121 | 0.095 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_CorMis | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.165 | 0.035 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_CorMis | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.148 | 0.078 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_CorMis | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.141 | 0.067 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_MisMis | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.177 | 0.131 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_MisMis | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.160 | 0.153 | 100.0% / 100.0% | 0 / 2 |
| Retrospective_PoorOverlap_MisMis | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.148 | 0.123 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_CorCor | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.059 | 0.022 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_CorCor | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.055 | 0.044 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_CorCor | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.058 | 0.038 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_MisCor | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.058 | 0.044 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_MisCor | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.055 | 0.041 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_MisCor | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.059 | 0.042 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_CorMis | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.067 | 0.014 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_CorMis | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.064 | 0.019 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_CorMis | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.065 | 0.034 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_MisMis | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.068 | 0.039 | 100.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_MisMis | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.066 | 0.071 | 50.0% / 100.0% | 0 / 2 |
| Prospective_GoodOverlap_MisMis | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.067 | 0.073 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_CorCor | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.151 | 0.035 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_CorCor | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.147 | 0.006 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_CorCor | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.131 | 0.024 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_MisCor | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.152 | 0.034 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_MisCor | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.150 | 0.001 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_MisCor | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.136 | 0.038 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_CorMis | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.145 | 0.095 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_CorMis | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.139 | 0.011 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_CorMis | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.132 | 0.037 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_MisMis | 1 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.141 | 0.023 | 100.0% / 50.0% | 0 / 2 |
| Prospective_PoorOverlap_MisMis | 3 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.139 | 0.049 | 100.0% / 100.0% | 0 / 2 |
| Prospective_PoorOverlap_MisMis | 5 | 2 / 2 | 0 / 0 / 0 | 100.0% (2) | 0.0% | 0.129 | 0.075 | 100.0% / 100.0% | 0 / 2 |

Audit issues: 24. See pate_wald_issues.csv. Full numerical metrics, denominators, bias, widths, and point deltas are in pate_wald_summary.csv.
Per-record comparisons, including failures and missing records, are in pate_wald_paired.csv.

This is a pilot diagnostic. It is not a replacement for the manuscript's 1000-replication simulation results.

Finalization failed. These outputs are an explicitly incomplete or failed audit, even when some finite estimates are available.
