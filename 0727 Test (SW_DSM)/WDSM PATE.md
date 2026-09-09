
# Weighted Double-Score Matching (WDSM) — PATE Version

## 1 High-level workflow

```mermaid
graph TD
  A[Input data  (Y, Z, X, S, weights)] --> B[Fit scores  (PS + prognostic)]
  B --> C[Construct matching sets on Vz = (e, Ψz)]
  C --> D[Impute missing Y(z) with weighted NN]
  D --> E[Raw WDSM estimator  τ_raw]
  E --> F[Bias-correction  τ_bc]
  F --> G[Variance  (plug-in & weighted bootstrap)]
  G --> H[Output:  τ_raw, τ_bc, var, matches, diagnostics]
```

* **Prospective survey** single weight vector $w_i$.
* **Retrospective survey** two weight vectors $w_{1,i},w_{0,i}$ & two sample sizes $n_1,n_0$.

---

## 2 Detailed pseudocode (R-style)

> **Conventions**
>
> * CAPS = objects users must supply.
> * lower\_case = objects created inside the routine.
> * Functions prefixed `intern_` are helpers; exported API sits in `wdsm()`.

### 2.1 Top-level wrapper

```r
wdsm <- function(data,
                 y, z, x, s,
                 weights,          # named vector; see design argument
                 design = c("prospective", "retrospective"),
                 M = 1,
                 bias_correction = TRUE,
                 distance = c("euclidean","mahalanobis"),
                 bootstrap_rep = 500,
                 seed = 1) {

  assert_inputs(...)
  set.seed(seed)

  ## 1. Construct survey design object
  des <- build_design(data, s, weights, design)

  ## 2. First-stage score fits (propensity + two outcome models)
  scores <- intern_fit_scores(des, y, z, x)

  ## 3. Build 2-D matching points V1, V0
  v_points <- intern_build_V(scores)

  ## 4. k-NN search with replacement
  nbrs <- intern_match_neighbors(v_points, z, M, distance)

  ## 5. Impute missing potential outcomes
  Yhat <- intern_impute_Y(data[[y]], z, nbrs, weights, design)

  ## 6. Compute τ_raw (and τ_bc if requested)
  tau_raw <- intern_tau_raw(data, z, y, Yhat, nbrs, weights, design, M)
  tau_bc  <- if (bias_correction)
               intern_tau_bc(data, z, y, Yhat, nbrs, scores, weights, design, M)
             else NA_real_

  ## 7. Variance
  var_plugin  <- intern_var_plugin(data, z, y, scores, nbrs, weights, design, M)
  var_boot    <- intern_var_boot(data, z, y, x, s, weights, design,
                                 M, bias_correction, bootstrap_rep, distance)

  ## 8. Return
  list(tau_raw   = tau_raw,
       tau_bc    = tau_bc,
       var_plugin = var_plugin,
       var_boot   = var_boot,
       matches    = nbrs,
       scores     = scores)
}
```

### 2.2 Helper modules

<details>
<summary>intern_fit_scores()</summary>

```r
intern_fit_scores <- function(des, y, z, x) {
  # A. propensity
  ps_fit <- survey::svyglm(as.formula(paste(z,"~",paste(x,collapse="+"))),
                           design = des, family = quasibinomial())
  e_hat  <- fitted(ps_fit, type = "response")

  # B. outcomes – fit separately in Z==1 and Z==0 groups
  mu1_fit <- survey::svyglm(as.formula(paste(y,"~",paste(x,collapse="+"))),
                            subset = des$variables[[z]] == 1,
                            design = des)
  mu0_fit <- survey::svyglm(as.formula(paste(y,"~",paste(x,collapse="+"))),
                            subset = des$variables[[z]] == 0,
                            design = des)

  Psi1_hat <- predict(mu1_fit, newdata = des$variables)
  Psi0_hat <- predict(mu0_fit, newdata = des$variables)

  list(e = e_hat, Psi1 = Psi1_hat, Psi0 = Psi0_hat,
       ps_fit = ps_fit, mu1_fit = mu1_fit, mu0_fit = mu0_fit)
}
```

</details>

<details>
<summary>intern_build_V()</summary>

```r
intern_build_V <- function(scores) {
  ## standardise each column before distance search
  V1 <- scale(cbind(scores$e, scores$Psi1))
  V0 <- scale(cbind(scores$e, scores$Psi0))
  list(V1 = V1, V0 = V0)
}
```

</details>

<details>
<summary>intern_match_neighbors()</summary>

```r
intern_match_neighbors <- function(v_points, z, M, distance) {

  treated_ids  <- which(z == 1)
  control_ids  <- which(z == 0)

  nn_treated <- FNN::get.knnx(data = v_points$V1[treated_ids, ],
                              query = v_points$V1[control_ids, ], k = M)$nn.index
  nn_control <- FNN::get.knnx(data = v_points$V0[control_ids, ],
                              query = v_points$V0[treated_ids, ], k = M)$nn.index

  ## store matches as list(i -> integer vector of indices)
  matches1 <- split(treated_ids[nn_treated], rep(control_ids, each = M))
  matches0 <- split(control_ids[nn_control], rep(treated_ids, each = M))

  list(to_treated = matches1,  # each control gets M treated neighbours (for Y(1) imputation)
       to_control = matches0)  # each treated gets M control neighbours (for Y(0) imputation)
}
```

</details>

<details>
<summary>intern_impute_Y()</summary>

```r
intern_impute_Y <- function(y_vec, z, nbrs, weights, design) {

  N <- length(y_vec)
  Yhat1 <- Yhat0 <- numeric(N)

  # impute control units' Y(1)
  for (cid in names(nbrs$to_treated)) {
    idx   <- as.integer(cid)
    mates <- nbrs$to_treated[[cid]]
    wj    <- weights[mates]   # prospective => same; retrospective => w1 for treated mates
    Yhat1[idx] <- sum(wj * y_vec[mates]) / sum(wj)
  }

  # impute treated units' Y(0)
  for (tid in names(nbrs$to_control)) {
    idx   <- as.integer(tid)
    mates <- nbrs$to_control[[tid]]
    wj    <- weights[mates]   # prospective => same; retrospective => w0 for control mates
    Yhat0[idx] <- sum(wj * y_vec[mates]) / sum(wj)
  }

  ## For own-arm units the observed Y is retained
  Yhat1[z==1] <- y_vec[z==1]
  Yhat0[z==0] <- y_vec[z==0]
  list(Y1 = Yhat1, Y0 = Yhat0)
}
```

</details>

<details>
<summary>intern_tau_raw()</summary>

```r
intern_tau_raw <- function(data, z, y, Yhat, nbrs, weights, design, M){
  if (design=="prospective") {
    w      <- weights
    denom1 <- sum(w * (z==1) * data$S)
    denom0 <- sum(w * (z==0) * data$S)

    K1 <- reuse_count(nbrs$to_treated, length(z))   # times unit reused as match
    K0 <- reuse_count(nbrs$to_control, length(z))

    mu1 <- sum(w * (z==1) * data$S * Yhat$Y1 * (1 + K1/M)) / denom1
    mu0 <- sum(w * (z==0) * data$S * Yhat$Y0 * (1 + K0/M)) / denom0
    return(mu1 - mu0)
  } else {
    w1 <- weights$w1 ; w0 <- weights$w0
    S  <- data$S
    denom1 <- sum(S * w1 * (z==1))
    denom0 <- sum(S * w0 * (z==0))

    K1 <- reuse_count(nbrs$to_treated, length(z))
    K0 <- reuse_count(nbrs$to_control, length(z))

    mu1 <- sum(S * w1 * (z==1) * Yhat$Y1 * (1 + (denom1/denom0)*K1/M)) / denom1
    mu0 <- sum(S * w0 * (z==0) * Yhat$Y0 * (1 + (denom0/denom1)*K0/M)) / denom0
    return(mu1 - mu0)
  }
}
```

</details>

> **reuse\_count()** simply tabulates how many times each index appears in the match-lists.

<details>
<summary>intern_tau_bc()</summary>

```r
intern_tau_bc <- function(data, z, y, Yhat, nbrs, scores, weights, design, M){
  # subtract fitted mu_z(V_z) from every Y before calling tau_raw
  resid <- data[[y]] -
           ifelse(z==1, scores$Psi1, scores$Psi0)
  data$resid <- resid
  Yhat_resid <- list(Y1 = Yhat$Y1 - scores$Psi1,
                     Y0 = Yhat$Y0 - scores$Psi0)
  tau_resid  <- intern_tau_raw(data, z, "resid", Yhat_resid,
                               nbrs, weights, design, M)
  tau_bc <- tau_resid + mean(scores$Psi1 - scores$Psi0)
  return(tau_bc)
}
```

</details>

<details>
<summary>intern_var_plugin()</summary>

```r
intern_var_plugin <- function(data, z, y, scores, nbrs, weights, design, M){
  # empirical plug-in version of Theorem A3
  if (design=="prospective") {
    p  <- 1/weights                 # p_i
    K1 <- reuse_count(nbrs$to_treated,  length(z))/M
    K0 <- reuse_count(nbrs$to_control, length(z))/M
    sig1 <- (data[[y]] - scores$Psi1)^2
    sig0 <- (data[[y]] - scores$Psi0)^2

    V <- mean( (1/p) * (
          sig1 * ( z/scores$e + (1-z)*K1 ) +
          sig0 * ((1-z)/(1-scores$e) + z*K0)
         ))
    return(V/ length(z))  # divide by n
  }
  # … analogous retrospective block omitted for brevity
}
```

</details>

<details>
<summary>intern_var_boot()</summary>

```r
intern_var_boot <- function(data, y, z, x, s, weights, design,
                            M, bias_correction, B, distance){

  boot_tau <- numeric(B)
  for (b in seq_len(B)){
    omega <- rmultinom(1, nrow(data), prob = rep(1, nrow(data)))
    data_b  <- data[rep(seq_len(nrow(data)), omega), ]
    weights_b <- weights[rep(seq_len(nrow(data)), omega)]

    # refit scores & rerun matching inside replicate
    des_b   <- build_design(data_b, s, weights_b, design)
    scores_b <- intern_fit_scores(des_b, y, z, x)
    v_pts_b  <- intern_build_V(scores_b)
    nbrs_b   <- intern_match_neighbors(v_pts_b, data_b[[z]], M, distance)
    Yhat_b   <- intern_impute_Y(data_b[[y]], data_b[[z]], nbrs_b,
                                weights_b, design)

    boot_tau[b] <- intern_tau_raw(data_b, data_b[[z]], y, Yhat_b,
                                  nbrs_b, weights_b, design, M)
    if (bias_correction)
       boot_tau[b] <- intern_tau_bc(data_b, data_b[[z]], y, Yhat_b,
                                    nbrs_b, scores_b, weights_b,
                                    design, M)
  }
  var(boot_tau)
}
```

</details>

---

## 3 Mathematical reference for every coding step

### 3.1 Scores

$$
\hat e(X)=P_{\hat\alpha}(Z=1\mid X),\qquad
\hat\Psi_z(X)=E_{\hat\beta_z}[Y\mid Z=z,X].
$$

### 3.2 Matching variable

$$
V_{z}=(\hat e,\;\hat\Psi_z)\in\mathbb R^2.
$$

Distance:

$$
d(i,j)=\sqrt{\sum_{k=1}^2\frac{(V_{z,k,i}-V_{z,k,j})^2}{\widehat{\operatorname{Var}}(V_{z,k})}}.
$$

### 3.3 Imputation

$$
\hat Y_i(z)=
\begin{cases}
Y_i,& Z_i=z,\\[4pt]
\dfrac{\sum_{j\in\mathcal J_{V_z,i}}w_{z,j}Y_j}{\sum_{j\in\mathcal J_{V_z,i}}w_{z,j}},& Z_i\neq z.
\end{cases}
$$

Survey weights

$$
w_{z,i}=
\begin{cases}
w_i,&\text{prospective},\\
w_{z,i},&\text{retrospective}.
\end{cases}
$$

### 3.4 Raw WDSM estimator

*Prospective*

$$
\hat\tau_{\text{raw}}=
\frac{\sum S_iw_iZ_i\hat Y_i(1)(1+K_{1,i}/M)}{\sum S_iw_iZ_i}\;-\;
\frac{\sum S_iw_i(1-Z_i)\hat Y_i(0)(1+K_{0,i}/M)}{\sum S_iw_i(1-Z_i)}.
$$

*Retrospective*

$$
\hat\tau_{\text{raw}}=
\frac{\sum S_iw_{1,i}Z_i\hat Y_i(1)\bigl(1+\tfrac{n_1}{n_0}K_{1,i}/M\bigr)}{\sum S_iw_{1,i}Z_i}
-\frac{\sum S_iw_{0,i}(1-Z_i)\hat Y_i(0)\bigl(1+\tfrac{n_0}{n_1}K_{0,i}/M\bigr)}{\sum S_iw_{0,i}(1-Z_i)}.
$$

$K_{z,i}$ = reuse count of unit $i$ when it belongs to arm $z$.

### 3.5 Bias-corrected estimator

$$
\hat\tau_{\text{bc}}=
\hat\tau_{\text{raw}}(\text{with }Y\to Y-\hat\Psi_{Z})\;+\;
\frac1N\sum_{i=1}^N(\hat\Psi_{1,i}-\hat\Psi_{0,i}).
$$

### 3.6 Plug-in variance (prospective version)

$$
\hat V_{\text{plug}}=\frac1n\sum_{i=1}^n
\frac{1}{\hat p_i}
\Bigl[
\hat\sigma_1^2\Bigl(\frac{Z_i}{\hat e_i}+\frac{(1-Z_i)K_{1,i}}{M}\Bigr)+
\hat\sigma_0^2\Bigl(\frac{1-Z_i}{1-\hat e_i}+\frac{Z_iK_{0,i}}{M}\Bigr)
\Bigr].
$$

Here $\hat\sigma_z^2=(Y_i-\hat\Psi_{z,i})^2$ or from a local variance model.

### 3.7 Weighted bootstrap

For replicate $b$:

1. draw multinomial weights $\omega_i^{(b)}$;
2. refit scores using $(\omega_i^{(b)}w_i)$;
3. recompute $\hat\tau^{(b)}$.

$$
\widehat{\operatorname{Var}}_{\text{boot}}=\frac1{B-1}\sum_{b=1}^B\bigl(\hat\tau^{(b)}-\overline{\hat\tau}\bigr)^2.
$$

---

### 4 External packages you’ll likely call

| Role                   | R package                                      |
| ---------------------- | ---------------------------------------------- |
| Survey-weighted GLM    | **`survey`**                                   |
| k-NN (fast)            | **`FNN`** or **`RANN`**                        |
| Mahalanobis / scaling  | **`stats`**, **`robustbase`**                  |
| Design-based bootstrap | **`boot`** (plain loop is fine for \~500 reps) |

---

*Ready for coding!*  Plug each helper into an R script or an R package skeleton, write a handful of `testthat` specs (bias-zero, coverage 95 %, etc.), and you’ll have a fully-functioning WDSM PATE estimator for both survey designs.
