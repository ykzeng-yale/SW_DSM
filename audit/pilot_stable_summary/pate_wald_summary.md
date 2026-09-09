# Corrected PATE Wald rerun: PILOT COMPLETE FOR THE REQUESTED SCOPE

Scope: 16 of 16 cells; 5 requested sample replications per cell; M = 1, 3, 5; B = 200; nominal coverage = 95.0%.

Record completeness: TRUE. Historical point-estimate agreement within 1e-8: FALSE. Declared point-revision policy passed: TRUE. Full 16-cell, 1000-replication production matrix finalized: FALSE.

Every accepted estimate has all requested finite bootstrap draws. The draws reproduce the B-divisor standard error and the centered Wald endpoints. Record identities and configurations match their manifest; configuration and runtime hashes were checked. Source-code and population hashes are recorded lineage identifiers; this summary does not independently re-read unavailable HPC source/data files.

Coverage and its estimated binomial Monte Carlo standard error use only successful validated estimates, with the denominator shown. Failed, invalid, or missing records remain explicit and prevent finalization. Empirical SD uses successful point estimates. Completed means a readable, validated record with an estimator outcome, including numerical failure; corrupted/unverifiable records are integrity failures.

Old stored coverage and old-SE Wald coverage are historical diagnostics. The old-SE calculation changes endpoints only and does not repair the historical replication formula. The CSV includes both all available historical replications and the same replication-index subset as this run. Historical comparator methods are not recomputed or combined into a common-run result.

Historical point comparisons use the same replication index. For the explicitly declared stable_ps_20260909 revision with weighted_logistic_zero_start_convergence_checked, point differences are retained as nonblocking diagnostics of the intentional numerical correction. Acceptance additionally requires a converged point propensity fit and all B converged bootstrap propensity fits, zero_coefficients_raw_weights initialization, and finite normalized scores no greater than their positive recorded tolerance, which must be at most 1e-7. Undeclared legacy runs retain the historical point-agreement gate; unknown or incomplete revision declarations are rejected. Matching points alone does not prove identical sampled IDs or full historical execution lineage; bootstrap streams in this rerun are explicitly new.

| Cell | M | Success / expected | Numerical / integrity / missing | Corrected coverage (n) | MCSE | Mean SE | Empirical SD | Old stored / old-SE Wald (same indices) | Point mismatches / paired |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Retrospective_GoodOverlap_CorCor | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.059 | 0.042 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_CorCor | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.057 | 0.046 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_CorCor | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.055 | 0.042 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_MisCor | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.060 | 0.030 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_MisCor | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.057 | 0.040 | 100.0% / 80.0% | 5 / 5 |
| Retrospective_GoodOverlap_MisCor | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.055 | 0.038 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_CorMis | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.071 | 0.048 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_CorMis | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.067 | 0.029 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_CorMis | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.067 | 0.030 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_MisMis | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.075 | 0.065 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_MisMis | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.069 | 0.055 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_GoodOverlap_MisMis | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.071 | 0.060 | 100.0% / 100.0% | 5 / 5 |
| Retrospective_PoorOverlap_CorCor | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.139 | 0.160 | 100.0% / 80.0% | 0 / 5 |
| Retrospective_PoorOverlap_CorCor | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.123 | 0.129 | 100.0% / 100.0% | 0 / 5 |
| Retrospective_PoorOverlap_CorCor | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.120 | 0.124 | 80.0% / 100.0% | 0 / 5 |
| Retrospective_PoorOverlap_MisCor | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.143 | 0.147 | 100.0% / 80.0% | 0 / 5 |
| Retrospective_PoorOverlap_MisCor | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.125 | 0.118 | 100.0% / 100.0% | 0 / 5 |
| Retrospective_PoorOverlap_MisCor | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.120 | 0.107 | 80.0% / 100.0% | 0 / 5 |
| Retrospective_PoorOverlap_CorMis | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.172 | 0.140 | 100.0% / 80.0% | 0 / 5 |
| Retrospective_PoorOverlap_CorMis | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.141 | 0.102 | 100.0% / 100.0% | 0 / 5 |
| Retrospective_PoorOverlap_CorMis | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.142 | 0.094 | 100.0% / 100.0% | 0 / 5 |
| Retrospective_PoorOverlap_MisMis | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.183 | 0.154 | 100.0% / 100.0% | 0 / 5 |
| Retrospective_PoorOverlap_MisMis | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.153 | 0.141 | 100.0% / 100.0% | 0 / 5 |
| Retrospective_PoorOverlap_MisMis | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.156 | 0.106 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_CorCor | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.058 | 0.062 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_CorCor | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.055 | 0.055 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_CorCor | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.056 | 0.049 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_MisCor | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.058 | 0.051 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_MisCor | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.055 | 0.048 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_MisCor | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.056 | 0.050 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_CorMis | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.068 | 0.037 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_CorMis | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.064 | 0.049 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_CorMis | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.065 | 0.049 | 100.0% / 100.0% | 0 / 5 |
| Prospective_GoodOverlap_MisMis | 1 | 5 / 5 | 0 / 0 / 0 | 80.0% (5) | 17.9% | 0.070 | 0.058 | 100.0% / 80.0% | 0 / 5 |
| Prospective_GoodOverlap_MisMis | 3 | 5 / 5 | 0 / 0 / 0 | 80.0% (5) | 17.9% | 0.069 | 0.061 | 60.0% / 80.0% | 0 / 5 |
| Prospective_GoodOverlap_MisMis | 5 | 5 / 5 | 0 / 0 / 0 | 80.0% (5) | 17.9% | 0.069 | 0.059 | 80.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_CorCor | 1 | 5 / 5 | 0 / 0 / 0 | 80.0% (5) | 17.9% | 0.144 | 0.193 | 100.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_CorCor | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.147 | 0.174 | 100.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_CorCor | 5 | 5 / 5 | 0 / 0 / 0 | 80.0% (5) | 17.9% | 0.131 | 0.170 | 100.0% / 100.0% | 0 / 5 |
| Prospective_PoorOverlap_MisCor | 1 | 5 / 5 | 0 / 0 / 0 | 80.0% (5) | 17.9% | 0.146 | 0.204 | 100.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_MisCor | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.148 | 0.171 | 100.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_MisCor | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.133 | 0.170 | 100.0% / 100.0% | 0 / 5 |
| Prospective_PoorOverlap_CorMis | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.170 | 0.200 | 100.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_CorMis | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.150 | 0.179 | 100.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_CorMis | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.141 | 0.175 | 100.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_MisMis | 1 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.178 | 0.190 | 80.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_MisMis | 3 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.155 | 0.191 | 80.0% / 80.0% | 0 / 5 |
| Prospective_PoorOverlap_MisMis | 5 | 5 / 5 | 0 / 0 / 0 | 100.0% (5) | 0.0% | 0.146 | 0.183 | 80.0% / 100.0% | 0 / 5 |

Audit ledger: 0 blocking issues and 60 nonblocking declared point-change diagnostics. See pate_wald_issues.csv. Full numerical metrics, denominators, bias, widths, point deltas, and propensity-score residual maxima are in pate_wald_summary.csv.
Per-record comparisons, including failures and missing records, are in pate_wald_paired.csv.

This is a pilot diagnostic. It is not a replacement for the manuscript's 1000-replication simulation results.
