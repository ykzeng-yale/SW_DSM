

# PATT-WDSM Implementation Guide (v1.1, 2025-06-15)

---

## 0   Notation recap (minimal)

| symbol                                                | meaning                                                                       |
| ----------------------------------------------------- | ----------------------------------------------------------------------------- |
| $S_i$                                                 | survey-selection indicator (=1 in sample)                                     |
| $Z_i$                                                 | treatment indicator (1 = treated)                                             |
| $w_i,\;w_{1,i},w_{0,i}$                               | survey weights (prospective) or treatment-specific weights (retrospective)    |
| $e_{\text{sp}}(X_i)$                                  | survey-propensity score                                                       |
| $\Psi_0(X_i)$                                         | control prognostic score                                                      |
| $V_0(X_i)=\bigl(e_{\text{sp}}(X_i),\Psi_0(X_i)\bigr)$ |                                                                               |
| $\mathcal J_{V_0,i}$                                  | indices of the $M$ nearest control matches to treated unit $i$ in $V_0$-space |

---

## 1   High-level workflow

```
1.  Prepare data & initial inputs
    ├─ choose sampling_design ∈ {prospective, retrospective}
    ├─ pick M (no. of matches) and distance metric on V0
    └─ user supplies: Y, Z, X, S, survey weights

2.  Estimate double scores
    ├─ fit e_sp(X)   (weighted logistic or any SuperLearner)
    └─ fit Psi0(X)   (weighted regression on controls)

3.  Construct matching sets 𝓙_{V0,i} for every treated unit

4.  Compute raw PATT-WDSM estimate
5.  Compute bias-corrected PATT-WDSM estimate (optional but recommended)

6.  Variance estimation
    ├─ analytical sandwich variance (plug-in)
    └─ multiplier bootstrap or rescaled bootstrap

7.  Output: point estimate, SE, CI, diagnostic summaries
```

---

## 2   Pseudocode (R-flavoured)

```r
patt_wdsm <- function(data,                    # data.frame with Y, Z, X..., S, weights
                      sampling_design = c("prospective","retrospective"),
                      M = 5,
                      distance = "mahalanobis",
                      bias_correct = TRUE,
                      B_boot = 999) {

  ## 1. Parse & check ---------------------------------------------------------
  sd <- match.arg(sampling_design)
  with(data, stopifnot(all(Z %in% c(0,1)), all(S %in% c(0,1))))
  
  ## 2. Double-score estimation ----------------------------------------------
  e_hat   <- fit_propensity(X, S, Z, weights, sd)          # returns vector length n
  psi0_hat<- fit_prognostic(X, Y, S, Z, weights, sd)      # fitted on controls
  
  V0      <- cbind(e_hat, psi0_hat)                       # n×2 matrix
  
  ## 3. Matching --------------------------------------------------------------
  match_list <- knn_match(V0, Z, S, weights, M, distance) # list of length n_treated
                                                          # each element: integer vector of control indices
  
  ## 4. Raw estimator ---------------------------------------------------------
  tau_raw <- wdsm_raw(data, match_list, e_hat, psi0_hat, sd)
  
  ## 5. Bias correction -------------------------------------------------------
  tau_hat <- if (bias_correct) {
               wdsm_bias_corrected(data, match_list, psi0_hat, sd)
             } else tau_raw
  
  ## 6. Variance --------------------------------------------------------------
  var_ana <- wdsm_variance(data, match_list, e_hat, psi0_hat, sd)
  se_ana  <- sqrt(var_ana / sum(data$S * data$Z))         # scale by n1 (prospective) or n1^w (retrospective)
  
  se_boot <- wdsm_bootstrap(data, match_list, psi0_hat, sd, B = B_boot)
  
  list(point      = tau_hat,
       se_analyt  = se_ana,
       se_boot    = se_boot,
       ci_95      = tau_hat + c(-1,1)*1.96*se_ana,
       matches    = match_list)
}
```

<details><summary><strong>Helper signatures</strong></summary>

```r
fit_propensity(X, S, Z, w, sd)       -> numeric(n)
fit_prognostic(X, Y, S, Z, w, sd)    -> numeric(n)
knn_match(V0, Z, S, w, M, distance)  -> list(length = n_treated)
wdsm_raw(df, match_list, e_hat, psi0_hat, sd)            -> scalar
wdsm_bias_corrected(df, match_list, psi0_hat, sd)        -> scalar
wdsm_variance(df, match_list, e_hat, psi0_hat, sd)       -> scalar
wdsm_bootstrap(df, match_list, psi0_hat, sd, B)          -> numeric
```

</details>

---

## 3   Mathematical details (copy-friendly)

### 3.1 Point estimators (PATT)

| design            | raw WDSM                                                                                                                                                                       | bias-corrected WDSM                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| **prospective**   | $\displaystyle \hat\tau^{\text{raw}}_{P}=\frac{1}{n_1^{w}}\sum_{i}S_iw_iZ_i\Bigl[Y_i-\frac{\sum_{j\in\mathcal J_{i}}w_jY_j}{\sum_{j\in\mathcal J_{i}}w_j}\Bigr]$               | $\displaystyle \hat\tau^{bc}_{P}=\frac{1}{n_1^{w}}\sum_{i}S_iw_iZ_i\bigl[Y_i-\hat\mu_0(X_i)\bigr]$       |
| **retrospective** | $\displaystyle \hat\tau^{\text{raw}}_{R}=\frac{1}{n_1^{w,R}}\sum_{i}S_iw_{1,i}Z_i\Bigl[Y_i-\frac{\sum_{j\in\mathcal J_{i}}w_{0,j}Y_j}{\sum_{j\in\mathcal J_{i}}w_{0,j}}\Bigr]$ | $\displaystyle \hat\tau^{bc}_{R}=\frac{1}{n_1^{w,R}}\sum_{i}S_iw_{1,i}Z_i\bigl[Y_i-\hat\mu_0(X_i)\bigr]$ |

*Here $n_1^{w}   =\sum_i S_i w_i Z_i$ and
$n_1^{w,R}= \sum_i S_i w_{1,i} Z_i$.*

### 3.2 Analytical variance with **estimated** scores

Let

$$
\underbrace{\phi_i}_{\text{IF}} \;=\;
\Bigl\{Z_i w_i\,[Y_i-\mu_1(X_i)] - (1-Z_i)w_i\,\tilde{\mathcal K}_i\,[Y_i-\mu_0(X_i)] + Z_i w_i[\tau(X_i)-\tau_{\text{PATT}}]\Bigr\}/n_1^{w}
$$

for the *oracle* influence function (prospective; adapt $w_i\rightarrow w_{1,i},w_{0,i}$ retro- spectively).  Denote

* $U_i = w_i\psi(Y_i,Z_i,X_i;\theta_0)$ the score contribution for $\theta=(\alpha,\beta_0)$;
* $\Sigma_U   = n^{-1}\sum_i U_iU_i^{\!\top}$ ;
* $\Gamma_\theta = \partial_\theta\operatorname E[U_i]\big|_{\theta_0}$.

The **asymptotic variance** of $\hat\tau^{bc}$ is

$$
\boxed{\; \hat V_{\text{ana}}=
        \hat V_{\text{oracle}}
      - \hat\gamma_1^{\!\top}\,\hat\Sigma_U^{-1}\,\hat\gamma_1
      + \hat\gamma_2^{\!\top}\,\hat\Sigma_{\theta}\,\hat\gamma_2 \;}
$$

with

* $\hat V_{\text{oracle}} = \frac1{n^2}\sum_i \hat\phi_i^{\,2}$ ;
* $\hat\gamma_1 = \frac1n\sum_i \hat\phi_i U_i$ ;
* $\hat\Sigma_{\theta}= \Gamma_\theta^{-1}\Sigma_U\,\Gamma_\theta^{-T}$ ;
* $\hat\gamma_2 = \partial_\theta \hat\tau^{bc}(\theta)\big|_{\hat\theta}$.

Implement by **plug-in**: evaluate all pieces at $\hat\theta=(\hat\alpha,\hat\beta_0)$, $\hat\mu_0,\hat e_{\text{sp}}$.

The **standard error** is

$$
\text{SE}_{\text{ana}}=\sqrt{\hat V_{\text{ana}} }.
$$

### 3.3 Bootstrap variance (recommended)

1. Draw $B$ bootstrap samples **at the PSU or cluster level** if survey design requires; otherwise simple resample $(S_i,Y_i,Z_i,X_i,w_{(\cdot)})$ with replacement.
2. Re-run the full estimator in each sample → $\hat\tau^{bc\,(b)}$.
3. Compute

$$
\text{SE}_{\text{boot}}=\sqrt{\frac{1}{B-1}\sum_{b=1}^{B}\bigl(\hat\tau^{bc\,(b)}-\bar\tau_{\!B}\bigr)^2},
\qquad
\bar\tau_{\!B}=B^{-1}\sum_b\hat\tau^{bc\,(b)}.
$$

For high-leverage weights, use *multiplier* weights (e.g. Bayesian bootstrap with Exp(1) multipliers) instead of resampling.

### 3.4 Small supporting formulas

* **Matching counts**

$$
\tilde{\mathcal K}_j
  =\sum_{i:Z_i=1} S_i w_i\,
    \frac{\mathbf 1\bigl(j\in\mathcal J_{V_0,i}\bigr)}
         {\sum_{l\in\mathcal J_{V_0,i}} w_l}
  \qquad(\text{prospective})
$$

and the obvious $w_{1,i},w_{0,j}$ replacements in retrospective.

* **Propensity & prognostic fits (canonical choices)**

```r
# e_sp (logistic)
glm.fit(x = X[S==1, ], y = Z[S==1], family = binomial(), weights = weights[S==1])

# Psi0 (survey-weighted OLS or SuperLearner on controls)
survey::svyglm(Y ~ splines::ns(X, df=4), design = svydesign(ids = ~1,
                                                            weights = ~weights,
                                                            data = subset(data, S==1 & Z==0)))
```

* **Distance for matching**
  Default Mahalanobis on $V_0$ with robust covariance of controls.

---

## 4   Checklist before coding

* [ ] Decide prospective vs retrospective interface (flag `sampling_design`)
* [ ] Provide user hooks for *any* e-score / prognostic algorithm
* [ ] Validate support overlap (warnings if $\max\hat e_{\text{sp}}=1$ or $\min\hat e=0$)
* [ ] Diagnostics: reuse counts, balance tables in $V_0$, percentile of $\|\Delta V_0\|$
* [ ] Optionally expose bias-only term to quantify M-dependence

That’s it—everything else is ordinary data wrangling.  Happy coding!
