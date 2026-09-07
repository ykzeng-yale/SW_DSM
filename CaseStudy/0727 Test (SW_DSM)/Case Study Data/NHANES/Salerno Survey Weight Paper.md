# What's the Weight? Estimating Controlled Outcome Differences in Complex Surveys for Health Disparities Research * 

Stephen Salerno<br>Public Health Sciences, Biostatistics<br>Fred Hutchinson Cancer Center<br>Seattle, WA<br>ssalerno@fredhutch.org

Emily K. Roberts<br>Department of Biostatistics<br>University of Iowa<br>Iowa City, IA<br>emily-roberts-1@uiowa.edu

Belinda L. Needham<br>Department of Epidemiology<br>University of Michigan<br>Ann Arbor, MI<br>needhamb@umich.edu

Tyler H. McCormick<br>Department of Statistics<br>Department of Sociology<br>University of Washington<br>Seattle, WA<br>tylermc@uw.edu

Bhramar Mukherjee<br>Department of Biostatistics<br>Department of Epidemiology<br>University of Michigan<br>Ann Arbor, MI<br>bhramar@umich.edu

Xu Shi<br>Department of Biostatistics<br>University of Michigan<br>Ann Arbor, MI<br>shixu@umich.edu


#### Abstract

A basic descriptive question in statistics often asks whether there are differences in mean outcomes between groups based on levels of a discrete covariate (e.g., racial disparities in health outcomes). However, when this categorical covariate of interest is correlated with other factors related to the outcome, direct comparisons may lead to biased estimates and invalid inferential conclusions without appropriate adjustment. Propensity score methods are broadly employed with observational data as a tool to achieve covariate balance, but how to implement them in complex surveys is less studied - in particular, when the survey weights depend on the group variable under comparison. In this work, we focus on a specific example when sample selection depends on race. We propose identification formulas to properly estimate the average controlled difference (ACD) in outcomes between Black and White individuals, with appropriate weighting for covariate imbalance across the two racial groups and generalizability. Via extensive simulation, we show that our proposed methods outperform traditional analytic approaches in terms of bias, mean squared error, and coverage when estimating the ACD for our setting of interest. We are motivated by the interplay between race and social determinants of health when estimating racial differences in telomere length using data from the National Health and Nutrition Examination Survey (NHANES). The NHANES sampling scheme depends on self-reported race. We build a propensity for race to properly adjust for other social determinants while characterizing the controlled effect of race on telomere length. We find that evidence of racial differences in telomere length between Black and White individuals attenuates after accounting for confounding by socioeconomic factors and after utilizing appropriate propensity score and survey weighting techniques. Software to implement these methods and code to reproduce our results can be found in the R package svycdiff at https://github.com/salernos/svycdiff.


Keywords Controlled Outcome Differences $\cdot$ Propensity Scores $\cdot$ Complex Surveys $\cdot$ NHANES $\cdot$ Racial Disparities

[^0]
## 1 Introduction

There is a deep and broad literature in the United States (US) documenting racial disparities along multiple socioeconomic axes (e.g., income, education; see Needham et al., 2013, Rehkopf and Needham, 2019; Zota and VanNoy, 2021). These dimensions are, of course, not independent, making it difficult to separate the variation in outcomes associated with race from differences attributable to other sources. Self-identified race, as measured in many studies, is a complex composite of biology and lived experiences, making it impossible to disentangle the two without additional data (e.g., genetic ancestry). Propensity scores are commonly used in causal inference, but they are also applicable under weaker assumptions to study such differences among groups by balancing complex correlates across these groups (Stuart et al., 2011; Lim et al., 2018; Zeng et al., 2021). While previous work has shown that propensity scores can be used to study racial disparities (see Li and $\mathrm{Li}, 2023$ ), a gap remains in determining the ideal practice when the sampling design is complex. Specifically, surveys are the backbone of such observational research, but, especially as response rates decline and costs rise, they almost always involve complex designs and non-response patterns. Of particular interest is when the design probability of selection into the survey sample depends on the comparison variable of interest, such as race. In more traditional causal inference terminology, these sensitive variables may be analogous to 'treatment' or 'exposure' variables. However, unlike in randomized trials, which are often viewed as the gold standard to estimate controlled outcome differences (Zabor et al., 2020), certain observational scenarios preclude randomizing individuals to a particular experimental condition due to moral or biological restrictions. These include practical examples such as the timing of transplant waitlisting or the inability to 'assign' race to an individual (Peng et al., 2017, Li and Li , 2023). Our paper addresses this knowledge gap by proposing a strategy for incorporating survey weights from complex survey designs with propensity score methods to achieve covariate balance among heterogeneous groups, such as race.
Given the complex relationship between race, socioeconomic status (SES), and the porous collection of such data in the United States, the ability to make definitive statements on race differences in health outcomes is immensely challenging ( Li and $\mathrm{Li}, 2023$ ). Observational data can offer a wealth of information, however, many observational studies have their limitations in terms of confounding, covariate imbalance, and a lack of representation for generalizing results (Imai and Ratkovic, 2013; Pattanayak et al., 2011). Nationally representative surveys provide the opportunity to study individuals from a range of socioeconomic and cultural backgrounds using techniques such as stratified and clustered sampling methods, however researchers must consider the additional challenge of generalizing results outside the context of the sample. Such generalizations of group differences falter unless we adjust our comparison groups so that we have have similar levels of other covariates that are correlated with the comparison group and outcome of interest. This adjustment, which we term covariate balance can be accomplished a number of ways. In this paper, we use propensity scores. Rosenbaum and Rubin (1983) originally proposed propensity scores as a method of contrasting the conditional probability of experimental group assignment while adjusting for baseline covariates (Rosenbaum and Rubin, 1983). In a typical causal framework, the ability to reduce biases due to confounding by balancing covariate differences is a task that relies on several assumptions, namely (1) strong exchangeability of the treatment/exposure, (2) positivity of the treatment/exposure, and (3) stable unit treatment value. When transporting to a different sample or generalizing to a larger target population, we also require (4) strong selection exchangeability and (5) selection positivity. Rather than interpreting the difference in the observed outcomes as a causal effect, we seek to estimate a controlled descriptive comparison to adjust for differences in covariates between groups. Thus, we leverage propensity scores to compute what Li et al. (2013) call an average controlled difference (ACD). This quantity accounts for associations between variables of interest under weaker assumptions - positivity (1) and (5) and weak selection exchangeability (4) - but does not render a causal interpretation to the estimated group differences. While we later show that our proposed methods also target a causal quantity such as the population average treatment effect (PATE) under stronger assumptions, we do not require this for validity of our proposed estimation procedure, as one or more of these assumptions may be violated in observational data settings - particularly when measuring racial differences in health outcomes. We will later present an auxiliary example where we illustrate PATE estimation for an environmental exposure.
To further complicate things in the study of health disparities, it is often the case that the population characteristics of interest, such as race, are factors that influence the probability of being selected into the sample. For instance, the sampling mechanism for the National Health and Nutrition Examination Survey (NHANES) is partially determined by race and indicators of socioeconomic status. For example, NHANES oversamples non-Hispanic Black individuals and those individuals at or below 130\% of the poverty level (Curtin et al., 2012). Previous studies have discussed using propensity score methods for analyzing complex survey data (Austin and Stuart, 2015, Lee et al., 2011, DuGoff et al., 2014, Fuentes et al., 2022), however, not when sample selection depends on race (or other variables commonly used for comparing outcome differences). For example, Rossen and Talih (2014) used propensity scores to assess disparities in weight among US children and adolescents from 2001 to 2010 with data from NHANES. However, there was not consensus on how to appropriately incorporate survey weights at the propensity score estimation stage.
There are several challenges in the problem we consider that are distinct from a traditional PATE estimation problem. A key assumption and function of the propensity score, traditionally, is conditional independence of the outcome and
comparison group of interest conditional on the propensity score or any balancing score. Due to the complex nature of these relationships, it is not immediately clear which variables should be conditioned on in the propensity score versus the downstream outcome model. Second, it is often useful to express the research question and corresponding dependencies in terms of conceptual diagrams or directed acyclic graphs (such as Figure 1). In estimating the ACD, we include diagrams to demonstrate associations between the variables of interest. However, given the nature of the variables considered, we caution against interpreting these relationships as causal. If considering these diagrams broadly and even causally, in some instances it would be possible to open backdoor pathways when conditioning on selection into the survey, allowing for the possibility of violating assumptions that causal conclusions rely on. Addressing this in practice often relies on multi-stage modeling techniques such as inverse probability weighting (IPW) or direct standardization via 'g-methods' (see Richardson and Rotnitzky, 2014, for a more detailed history).

In this paper, we introduce a strategy for incorporating sampling mechanisms, such as survey weights, and propensity scores to make statements on the controlled difference in outcomes when an individual's probability of selection depends on the group membership variable of interest (herein, race; see Figure 1). We explore how the proposed methods compare to current analytic strategies. Our motivation comes from a research question addressing the relationship between race, SES, and telomere length, a biomarker for health measured in a particular nationally representative survey (NHANES). The remainder of this manuscript is structured as follows. Section 2 reviews related work in this area. Section 3 introduces and justifies our proposed methods for estimating the quantity of interest, which we will refer to as the ACD in the spirit of Li and Li (2023), and discusses differences with other common approaches. Section 4 provides simulation studies to support our recommendations. Section 5 introduces the data motivating this work and provides results for this example. We close with a summary discussion of the concepts outlined here and some final recommendations to researchers who may be working under similar considerations.

![](https://cdn.mathpix.com/cropped/2025_09_15_96e7ab9e33e3f2aa73edg-03.jpg?height=527&width=1608&top_left_y=1108&top_left_x=195)
Figure 1: Conceptual diagrams. (A) Assumed variable relationships: $S=$ sample selection indicator; $A=$ group membership variable of interest; $X=$ covariates; $Y=$ observed outcome. (B) Conceptual diagram for our motivating data example: SES = Socioeconomic Status. (C) Directed acyclic graph for our auxiliary data example.

## 2 Related Work

To our knowledge, Zanutto (2006) and DuGoff et al. (2014) were among the first to discuss propensity score methods as an important tool for addressing confounding in observational studies that may include survey weights. Both authors suggest that, intuitively, since the purpose of incorporating propensity scores is to achieve in-sample balance rather than in the population, weighting the propensity score by the survey weight is unnecessary (Zanutto, 2006, DuGoff et al., 2014). The authors also recommend including survey weights as covariates in the propensity model, drawing a parallel between this intuition to the recommendation by Lumley (2011) of including these covariates to account for non-response in surveys (Lumley, 2011). However, this simple inclusion is often problematic in practice, as it may lead to separation in the data or large biases (Ridgeway et al., 2015). DuGoff et al. (2014) also addressed limitations regarding how to handle extreme weights, model misspecification, nonlinear propensity score estimation, and additional covariates in the models. Unfortunately, these recommendations are largely based on intuition, necessitating more rigorous arguments of consistency and conditional independence.

Subsequently, Ridgeway et al. (2015) began to formalize the discussion of propensity score analysis for complex survey designs. The authors demonstrated through proof and simulation that not appropriately accounting for the selection mechanism can potentially lead to biased estimates. A natural question is in what stages of the analysis (i.e., the
propensity score and/or outcome model stage) should the survey weights be included? The authors recommended that researchers use survey weights in both stages of the based on their results. However, the simulation results pertaining to our scenario are inconclusive as to which approach achieves the lowest bias, and the derivations of consistency are not specific to this scenario. Further, they consider situations with only the population average treatment effect on the treated (PATT) as their target estimand (Ridgeway et al., 2015).
Similarly, others have addressed the task of combining causal inference and survey methodology. Austin et al. (2018), for example, focused primarily on propensity score matching techniques in simulation. However, these results did not provide a clear answer with respect to which method of estimating the propensity score model, survey-weighted or not, was best. Dong et al. (2020) explored the performance of different propensity and outcome weighted models and suggested the use of survey weights at both stages, though they concluded the estimates from different strategies were not statistically different in their data example. Lenis et al. (2018) further studied the causal inference framework for estimating population versus sample effects and explored the impact of non-response mechanisms with matching techniques. Their simulation setting followed that of Austin et al. (2018) and conclude that the degree of misspecification impacted their analysis results and population balance. In our setting, the sample selection weights are supplied by NHANES, however the true sample selection mechanism is unknown. Further, there are many SES variables collected in the survey, which are potential covariates in selection and propensity score models. Here, considerations as to the limited degrees of freedom in the modeling process with the addition of survey weights, strata, and PSU's may be especially important. Lastly, race is part of the selection mechanism in the NHANES design, which complicates the relationships underlying our motivating research question.

## 3 Methods

### 3.1 Notation

Let $Y$ denote our observed outcome, here telomere length. Our goal is to estimate the de-confounded, or controlled difference in mean telomere length between non-Hispanic White and non-Hispanic Black-identifying individuals in the United States. To that end, let $\mathcal{A}$ be the discrete set of potential comparison groups of interest, such that $a \in \mathcal{A}$ denotes a specific group. We are interested in comparing the values of $Y$ across levels of $A$. Our motivating analysis departs from the traditional causal literature in that $\mathcal{A}$ represents race, with $a=1$ denoting Black race and $a=0$ denoting White race, rather than a potential 'treatment', per se (see Li and $\mathrm{Li}, 2023$, for further discussion on using propensity scores for racial disparities analysis). Given the nature of our variables, and race in particular, this contrast of interest will primarily be viewed as a controlled comparison of the observed outcomes after balancing the two groups with respect to potential confounding variables ( Li et al., 2013; Li and $\mathrm{Li}, 2023$ ). As the lived experience of Black and White individuals differs significantly in terms of social determinants of health, we believe a controlled descriptive comparison can help inform the dynamics of these complex relationships ( Li and $\mathrm{Li}, 2023$ ). While race may not be interpreted as a modifiable treatment, we conceptualize race as an important construct worthy of study. Moreover, the methods described herein are equally applicable in settings where a participant's sample selection is dependent on a treatment condition or exposure status in a more traditional causal inference framework (see Section 3.2 for more details).

Our observed data, $\mathcal{D}=\left\{\left(Y_{i}, A_{i}, X_{i}, S_{i}=1\right) ; i=1, \ldots, n\right\}$, consist of $n$ independently and identically distributed copies of ( $Y, A, X, S$ ) sampled from a population distribution, $\mathcal{P}$, of $N$ individuals where $Y$ is the observed outcome, $A$ is a participant's group membership, $X$ is a $p$-dimensional vector of covariates, and $S$ is an indicator for being selected into the sample. In our motivating example, $\operatorname{Pr}\left(S_{i}=1\right)$ is known for each individual $i$ in the super population through the explicit NHANES sampling design. There is also the possibility of having missing outcome values among sampled individuals, but this situation will not be explored here and is instead left to future work. Further, our assumed variable relationships are given in Figure 1 Here, we can see that our outcome ( $Y$ ), the variable of interest ( $A$ ), and the sample selection indicator ( $S$ ) all depend on a particular set of covariates ( $X$ ), and sample selection also depends on race.

### 3.2 Proposed Estimators

We are interested in drawing inference about the super population of individuals from which we have selected our study participants. Here, the targets of inference are the conditional outcome means, i.e., $\mathbb{E}[Y \mid A=a, X]$ for $a \in \mathcal{A}$ and their expected difference over $X$, i.e.,

$$
\begin{equation*}
\mathrm{ACD}=\mathbb{E}_{X}[\mathbb{E}[Y \mid A=1, X]-\mathbb{E}[Y \mid A=0, X]] . \tag{1}
\end{equation*}
$$

Our goal is to estimate the individual group specific conditional means, of which ACD is the difference. We make the following assumptions:

What's the Weight?
(i) Positivity: $\operatorname{Pr}(A=a \mid X=x)>0 \forall a \in \mathcal{A}$ and every $x$ such that $f_{X}(x)>0$
(ii) Positivity of Sample Selection: $\operatorname{Pr}(S=1 \mid A=a, X=x)>0$ for every $a, x$ such that $f_{A, X}(a, x)>0$
(iii) Weak Selection Exchangeability: $\mathbb{E}[Y \mid A=a, X]=\mathbb{E}[Y \mid A=a, S=1, X]$

We require (i) and (ii) to ensure that our observed data functional, denoted in the next section by $\mu(a)$, is well defined. Condition (iii) allows us to generalize the conditional mean of the outcome from the study sample to the target population. This assumption is less stringent than exchangeability in distribution (i.e, $Y \perp S \mid A, X$ ), as it does not require the entire conditional distribution of the outcomes to be independent of selection, only their conditional expectations. Depending on the factorization of the joint probability of being sampled ( $S=1$ ) and belonging to a particular group ( $A=a$ ), we propose three formulas, which can be estimated using either outcome model-based estimators (i.e., g-computation) or inverse probability weighted estimators:

$$
\begin{align*}
& \mathbb{E}_{X}\left[\left.\mathbb{E}[Y \mid A=a, S=1, X] \cdot \frac{\operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right],  \tag{2}\\
& \mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid A=a, X) \operatorname{Pr}(A=a \mid X)} \right\rvert\, S=1\right],  \tag{3}\\
& \mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(A=a \mid S=1, X) \operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right] . \tag{4}
\end{align*}
$$

We will refer to the methods for estimating Equations (2), (3), and (4) as Outcome Modeling and Direct Standardization (OM), Inverse Probability Weighting 1 (IPW1), and Inverse Probability Weighting 2 (IPW2), respectively. For additional details on this derivation, see Appendix A.1.
The assumptions required to estimate the ACD are relatively weaker than those required to identify a causal quantity. Figure 1, Panel (C) gives an example directed acyclic graph (DAG) where a causal target may be warranted, such as the case where $A$ is an environmental exposure, like lead, which can also alter telomere length. We provide a supplementary analysis in which we estimate the causal effect of lead exposure on telomere length for illustration, as a practitioner may also be interested in such causally interpretable estimated differences. If the group variable under study is a treatment or exposure, we show under stronger assumptions that Formulas (2) - (4) can equivalently target the population potential outcome means, denoted by $\mathbb{E}\left[Y^{a}\right] \forall a \in \mathcal{A}$. Along with the previous assumptions, the following conditions,
(iii*) Weak Selection Exchangeability for Potential Outcomes: $\mathbb{E}\left[Y^{a} \mid A=a, X\right]=\mathbb{E}\left[Y^{a} \mid A=a, S=1, X\right]$
(iv) Stable Unit Treatment Value Assumption (SUTVA): $Y_{i}=Y_{i}^{a}$ for all observations $i=1, \ldots, n$ and for all $A_{i}=a \in \mathcal{A}$.
(v) Weak Exchangeability: $\mathbb{E}\left[Y^{a} \mid X\right]=\mathbb{E}\left[Y^{a} \mid A=a, X\right]$,
are sufficient to identify $\mathbb{E}\left[Y^{a}\right]$. The additional SUTVA assumption underpins the existence of the counterfactual outcomes, $Y^{a}$. The compact representation in (iv) captures two aspects of SUTVA - no interference, which states that the $i$ th observation's outcome is unaffected by the treatment of other observations and consistency, which states that the potential outcome is well-defined for each treatment level, a (Rubin, 1980). The weak exchangeability assumption allows us to represent the conditional distribution of the unobserved potential outcome using that of the observed potential outcome. As before, we only require a weaker version of this assumption, though strong exchangeability, i.e., $Y^{a} \perp A \mid X$, is often assumed. For additional details and the full identification proof, see Appendix A.2. This is thematically similar to Dahabreh et al. (2020), who study the generalization of causal inferences from individuals in randomized trials. The authors also differentiate between mean exchangeability in $A$ for the randomized population and mean exchangeability in $S$ for the target population in the context of randomized trials.

### 3.3 Comparisons to Existing Approaches

The three formulas derived above differ from standard, existing approaches that one might take in practice, which warrants some brief discussion here. Table 1 compares our proposed approaches to such existing methods. As shown, there are two sources of bias if our assumed conceptual diagram holds - bias from covariate imbalance between comparison groups (referred to herein as confounding bias) and unequal selection induced by the design of the complex survey (referred to herein as selection bias), which impacts the generalizability of our within-sample results to a larger, target population. Existing approaches may incorporate either or both balancing and/or generalizability weights
to account for these two sources of bias, however if either are foregone, then we expect to obtain biased estimates of our target quantity of interest. For instance, the estimated (unadjusted) effect of race can be either exaggerated or attenuated depending on the direction of the true association between the confounders (e.g., SES), race, and the outcome in simple regression (Approach 1 in Table 1, Williams et al., 2019). Multiple regression (Approach 2) further adjusts for covariates, but unless the outcome model includes the appropriate interaction terms, this approach will suffer from confounding bias as well (Rao, 1971). With inverse probability weighting (Approach 3), the race-covariate relationship is modeled, rather than the covariate-outcome relationship, foregoing the need to specify any race $\times$ covariate interactions (Mansournia and Altman, 2016). However, with all three of these approaches, the target of inference is the within-sample difference in outcomes, which cannot be generalized to a larger population if a probability sample was taken (Shi et al., 2023, Degtiar and Rose, 2023). Survey-weighted regression (Approach 4) accounts for selection bias by accounting for how many individuals in the population that one individual in the sample represents (Lumley and Scott, 2017), allowing for generalizability, but these results will be biased if there is covariate imbalance in the sample (DuGoff et al., 2014, Ridgeway et al., 2015).

Table 1: Comparison of existing approaches for analysis to our proposed approach. Dashes denote that the model/weight is not used.
| Approach |  | Model |  |  | Weight |  |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
|  |  | Outcome | Propensity | Selection | Balancing | Generalizability |
| Existing Approaches |  |  |  |  |  |  |
| 1 | Simple Regression | $\mathbb{E}[Y \mid A, S=1]$ | - | - | - | - |
| 2 | Multiple Regression | $\mathbb{E}[Y \mid A, X, S=1]$ | - | - | - | - |
| 3 | IPTW Estimator | $A Y$ | $\operatorname{Pr}(A=1 \mid X, S=1)$ | - | $\operatorname{Pr}(A=1 \mid X, S=1)^{-1}$ | - |
| 4 | Survey-Weighted Multiple Regression | $\mathbb{E}[Y \mid A, X]$ | - | $\operatorname{Pr}(S=1 \mid A, X)$ | - | $\operatorname{Pr}(S=1 \mid A, X)^{-1}$ |
| 5 | IPTW Multiple Regression | $\mathbb{E}[Y \mid A, X, S=1]$ | $\operatorname{Pr}(A=1 \mid X, S=1)$ | - | $\operatorname{Pr}(A=1 \mid X, S=1)^{-1}$ | - |
| 6 | IPTW + Survey-Weighted Multiple Regression | $\mathbb{E}[Y \mid A, X]$ | $\operatorname{Pr}(A=1 \mid X, S=1)$ | $\operatorname{Pr}(S=1 \mid A, X)$ | $\operatorname{Pr}(A=1 \mid X, S=1)^{-1}$ | $\operatorname{Pr}(S=1 \mid A, X)^{-1}$ |
| 7 | Weighted IPTW + Survey-Weighted Multiple Regression | $\mathbb{E}[Y \mid A, X]$ | $\operatorname{Pr}(A=1 \mid X)$ | $\operatorname{Pr}(S=1 \mid A, X)$ | $\operatorname{Pr}(A=1 \mid X)^{-1}$ | $\operatorname{Pr}(S=1 \mid A, X)^{-1}$ |
| 8 | Naïve G-Computation | $\mathbb{E}[Y \mid A, X, S=1]$ | - | $\operatorname{Pr}(S=1 \mid A, X)$ | - | $\operatorname{Pr}(S=1 \mid A, X)^{-1}$ |
| Proposed Approaches |  |  |  |  |  |  |
| 9 | Outcome Modeling and Direct Standardization | $\mathbb{E}[Y \mid A, X, S=1]$ | - | $\operatorname{Pr}(S=1 \mid X)$ | - | $\operatorname{Pr}(S=1 \mid X)^{-1}$ |
| 10 | Inverse Probability Weighting 1 | $A Y$ | $\operatorname{Pr}(A=1 \mid X)$ | $\operatorname{Pr}(S=1 \mid A, X)$ | $\operatorname{Pr}(A=1 \mid X)^{-1}$ | $\operatorname{Pr}(S=1 \mid A, X)^{-1}$ |
| 11 | Inverse Probability Weighting 2 | $A Y$ | $\operatorname{Pr}(A=1 \mid X, S=1)$ | $\operatorname{Pr}(S=1 \mid X)$ | $\operatorname{Pr}(A=1 \mid X, S=1)^{-1}$ | $\operatorname{Pr}(S=1 \mid X)^{-1}$ |


IPTW = Inverse Probability of Treatment Weighting
$\operatorname{Pr}(S=1 \mid X)=\operatorname{Pr}(S=1 \mid A=1, X) \operatorname{Pr}(A=1 \mid X)+\operatorname{Pr}(S=1 \mid A=0, X) \operatorname{Pr}(A=0 \mid X)$

A more principled approach would be one that accounts for both confounding and selection bias, as given by Approaches 6 and 7, which utilize a combination of propensity score and survey weighting. These approaches are advocated for by Zanutto (2006); DuGoff et al. (2014) and Ridgeway et al. (2015), respectively, and may be viewed as current analytic standard since they suggest simple survey-weighted generalizations of the usual use of IPTW, either at the first (propensity model) and/or second (outcome model) stage. Though it may seem that either simple extension addresses both sources of bias, there has been little theoretical justification of how weighting one or multiple models within IPTW accomplishes both tasks. This is also true of the 'naive g-computation' approach (Approach 8) we study, which weights the predicted conditional expectation for each individual's outcome and comparison group/race by their survey contribution. Additionally, propensity scores are often seen as in-sample balancing scores (Zanutto, 2006; DuGoff et al., 2014). From this perspective, their generalizability (and corresponding selection bias correction based on survey weights) is often ignored. Survey-weighting both the propensity score and outcome model is reasonable (Ridgeway et al. 2015), however directly combining survey-weighted IPWs and survey weights in a second stage outcome regression may also lead to biased results if additional correction is not made. In our research question, we have an intersecting consideration of both selection and confounding bias; thus, neither source of bias should be disregarded.
From a practical standpoint, one question at hand is: "should we implement survey-weighted propensity score estimation in IPTW or not". Our analytic results show that for estimation of the ACD, the propensity score does not have to be survey-weighted. We see this in Equations (3) and (4), which differ with respect to the factorization of the joint distribution into propensity and survey weight models. If the propensity score is not survey-weighted, based on Equation (4), we need $\operatorname{Pr}(S=1 \mid X)$, i.e., one may need to marginalize $\operatorname{Pr}(S=1 \mid A, X)$ over the group membership variable, $A$. If survey weights are included in the propensity score estimation, then we must know $\operatorname{Pr}(S=1 \mid A, X)$, i.e., the probability of selection conditional on each level of the group membership variable and the covariates.

What's the Weight?

Moreover, our proposed approaches carry additional differences amongst themselves, and prove to be useful in different settings. Formula (2), outcome modeling and direct standardization (OM), requires individual-level data on $X$, or knowledge of $f_{X}(x)$, as an outcome regression, $g_{a}(X)$, is fit in practice. Formulas (3) and (4), IPW1 and IPW2, do not require estimation of an outcome model and may be the best options depending on how much information is available in practice. We view IPW1 and IPW2 as simple corrections to what one might do in practice, namely the traditional inverse probability of treatment weighted (IPTW) estimator, and thus may be a better starting point for an analysis of this type as they additionally account for selection bias. Further, IPW1 and IPW2 do not assume additivity, and thus may be more robust if the outcome model for (2) is misspecified. However, while OM, IPW1, and IPW2 are all consistent, OM is most efficient if correctly specified. Thus, depending on the availability of the data or the ability to estimate certain key quantities, a researcher may prefer one approach over the others.

Regarding the incorporation of propensity and sample selection weights into the analysis, our weights are not the same as those in the traditional g-computation or IPTW frameworks. We derived a new estimator with weights both for within-sample inference and for generalizability to our target population. Specifically, note the term $\operatorname{Pr}(S=1 \mid X)$ in the denominators of Formulas (2) and (4). If selection does not depend on $A$, then identification reduces to the standard proof for the IPTW identification formula. However, in our setting, selection depends on the participant's self-reported race. Thus, we need the following decomposition to calculate $\operatorname{Pr}(S=1 \mid X)$ :

$$
\operatorname{Pr}(S=1 \mid X)=\operatorname{Pr}(S=1 \mid A=1, X) \operatorname{Pr}(A=1 \mid X)+\operatorname{Pr}(S=1 \mid A=0, X) \operatorname{Pr}(A=0 \mid X) .
$$

As with OM, IPW2 requires that the probability of selection be marginalized over $A$, i.e., $\operatorname{Pr}(S=1 \mid X)$, and that the propensity model be fit without the incorporation of selection weights, i.e., $\operatorname{Pr}(A=a \mid S=1, X)$. IPW1 requires the selection mechanism be known (e.g., in the case of survey weights), conditional on $A$, i.e., $\operatorname{Pr}(S=1 \mid A=a, X)$, and that a survey-weighted propensity model be fit, i.e., $\operatorname{Pr}(A=a \mid X)$. The key difference here comes with respect to how the joint propensity and selection mechanisms are factorized.

### 3.4 Estimation

To estimate the ACD based on the three formulas presented above (OM, IPW1, and IPW2), we propose the following. For OM, define the functional

$$
\mu(a)=\mathbb{E}\left[\left.\mathbb{E}[Y \mid A=a, S=1, X] \frac{\operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right]
$$

We denote the estimator for the expectation of the outcome, $\mathbb{E}[Y \mid A=a, S=1, X]$, by $\hat{g}_{a}(X)$. In practice, $\hat{g}_{a}(X)$ can be estimated, for example, using a standard parametric outcome model with a finite-dimensional parameter vector. Our outcome model-based estimator for $\mu(a)$ is given by

$$
\begin{equation*}
\hat{\mu}_{\mathrm{OM}}(a)=\frac{1}{n} \sum_{i=1}^{n} \hat{g}_{a}\left(X_{i}\right) \frac{\operatorname{Pr}\left(S_{i}=1\right)}{\operatorname{Pr}\left(S_{i}=1 \mid X_{i}\right)} \tag{5}
\end{equation*}
$$

When the outcome model is correctly specified, then $\hat{g}_{a}(X) \xrightarrow[p]{\rightarrow} \mathbb{E}[Y \mid A=a, S=1, X]$, leading to the result that $\hat{\mu}_{\mathrm{OM}}(a) \underset{p}{\rightarrow} \mu(a)$ for $a \in \mathcal{A}$. Alternatively, IPW1 and IPW2 rely on inverse probability (IP) weighting to control for confounding (Horvitz and Thompson, 1952). Let $\hat{e}_{a}(X)$ for $a \in \mathcal{A}$ denote the within-sample propensity model for a given comparison group, which provides an estimator for $\operatorname{Pr}(A=a \mid S=1, X)$. Similarly, let $\hat{e}_{a}^{w}(X)$ denote the survey-weighted estimator of $\operatorname{Pr}(A=a \mid X)$. These are both estimable, as we assume a probability sample with known survey weights. A common approach may be to model the propensity via logistic regression, though many non-parametric approaches have been proposed (e.g., Lee et al., 2010). Depending on how we factorize the joint probability of sample selection and group membership, we can write out the IP weighting estimator as either

$$
\begin{align*}
& \hat{\mu}_{\mathrm{IPW} 1}(a)=\frac{1}{n} \sum_{i=1}^{n} \frac{I\left(A_{i}=a\right) Y_{i} \operatorname{Pr}\left(S_{i}=1\right)}{\hat{e}_{a}^{w}\left(X_{i}\right) \operatorname{Pr}\left(S_{i}=1 \mid A_{i}=a, X_{i}\right)} \quad \text { or }  \tag{6}\\
& \hat{\mu}_{\mathrm{IPW} 2}(a)=\frac{1}{n} \sum_{i=1}^{n} \frac{I(\mathcal{A}=a) Y_{i} \operatorname{Pr}\left(S_{i}=1\right)}{\hat{e}_{a}\left(X_{i}\right) \operatorname{Pr}\left(S_{i}=1 \mid X_{i}\right)} \tag{7}
\end{align*}
$$

If the propensity model is correctly specified, then we have that $\hat{e}_{a}^{w}(X) \operatorname{Pr}(S=1 \mid A=a, X) \xrightarrow[p]{\rightarrow} \operatorname{Pr}(S=1, A=a \mid X$ ) and $\hat{e}_{a}(X) \operatorname{Pr}(S=1 \mid X) \xrightarrow[p]{\rightarrow} \operatorname{Pr}(S=1, A=a \mid X)$, leading to $\hat{\mu}_{\mathrm{IPW} 1}(a)$ and $\hat{\mu}_{\mathrm{IPW} 2}(a)$ being consistent.

### 3.4.1 Estimation of Uncertain Sample Selection or Non-Probability Samples

Lastly, throughout this work we focus on the setting where the sample arises from a known probability survey design. That is, we know $\operatorname{Pr}(S=1 \mid A, X)$. In practice, however, even if sample selection weights are given, we still may not know the form of the true sample selection mechanism with respect to the comparison groups and the potential confounding variables. In this situation, we may model the survey weights via a beta generalized linear model, as proposed in Elliot (2009). Further, in non-probability samples such as those arising from the study of electronic health records, we must purely model $\operatorname{Pr}(S=1 \mid A, X)$ (e.g., through beta or simplex regression; Kundu et al., 2023; Salvatore et al., 2024). In these settings, for the estimation procedure outlined above we can replace $\operatorname{Pr}(S=1 \mid A, X)$, the probability of being selected into the sample, conditional on $A$ and $X$, by a consistent estimator, $\hat{\pi}(A, X)$. Further, we can replace $\operatorname{Pr}(S=1 \mid X)$, the sample selection probability marginalized over $A$, by $\hat{\pi}(X)$, and $\operatorname{Pr}(S=1)$ by its estimate, $\hat{\pi}=n / N$. Our asymptotic results still hold in that if the propensity and selection models are both correctly specified, then we have that $\hat{e}_{a}^{w}(X) \hat{\pi}(A, X) \xrightarrow[p]{\rightarrow} \operatorname{Pr}(S=1, A=a \mid X)$ and $\hat{e}_{a}(X) \hat{\pi}(X) \xrightarrow[p]{\rightarrow} \operatorname{Pr}(S=1, A=a \mid X)$, again leading to $\hat{\mu}_{\text {IPW1 }}(a)$ and $\hat{\mu}_{\text {IPW2 }}(a)$ being consistent estimators of $\mu(a)$.

### 3.5 Inference

Inference on our target, the ACD, can be carried out analytically via Taylor expansion, accounting for all variation, or numerically via the general theory from M-estimation (Stefanski and Boos, 2002). This states that the asymptotic variance of our proposed estimator can be consistently estimated using the empirical sandwich estimator, under certain regularity conditions, as the coefficients from the propensity and outcome models, and the ACD estimator, can be expressed as solutions to a set of unbiased estimating equations, $\rho\left(Y_{i}, X_{i}\right)$, where ( $Y_{i}, X_{i}$ ) is sampled from the true distribution, $\mathcal{P}$ (Boos et al., 2013). Specifically, we minimize $\sum_{i=1}^{n} \rho\left(Y_{i}, X_{i}\right)$ by differentiating $\rho$ and solving $\sum_{i=1}^{n} \psi\left(Y_{i}, X_{i}\right)=0$, where $\psi(Y, X)=\partial \rho(Y, X) / \partial Y$ is the partial derivative of $\rho(Y, X)$. Let $\theta(\mathcal{P})$ denote the parameter vector arising from the series of estimating equations in our procedure, which contains the propensity model, the outcome model, the selection model (if in 3.4.1), and our estimand (i.e., the ACD ). Let $\theta\left(\hat{\mathcal{P}_{n}}\right)$ denote an estimator for $\theta(\mathcal{P}) . \theta\left(\hat{\mathcal{P}_{n}}\right)$ is said to have an influence function, $\phi$, if it can be expressed as $\theta(\mathcal{P})=\theta\left(\hat{\mathcal{P}_{n}}\right)+\frac{1}{n} \sum_{i=1}^{n} \phi\left(Y_{i}, X_{i} ; \hat{\mathcal{P}}_{n}\right)+ o_{p}(1 / \sqrt{n})$, where $\hat{\mathcal{P}}_{n}$ is the empirical distribution, $\phi$ is a mean zero function with finite variance, and $o_{p}(\cdot) \xrightarrow[p]{ } 0$. As the influence function of an M-estimator is proportional to $\psi$,

$$
\phi(Y, X, \theta, \mathcal{P})=M^{-1} \psi[Y, X, \theta(\mathcal{P})]
$$

where

$$
M=-\int_{\mathcal{Y}}\left(\frac{\partial \psi(Y, X, \theta)}{\partial \theta}\right)_{\theta(\mathcal{P})} d \mathcal{P}(Y, X)
$$

is the Jacobian matrix of the estimating equations (Huber, 1996). Using numerical optimization, the covariance matrix of the estimated parameters, $\hat{V}(\hat{\theta})$, including the ACD estimator, is given by

$$
\begin{equation*}
\hat{V}(\hat{\theta})=\sum_{i=1}^{n} \phi_{i}(Y, X, \hat{\theta}, \mathcal{P}) \phi_{i}(Y, X, \hat{\theta}, \mathcal{P})^{\prime} \tag{8}
\end{equation*}
$$

where $\phi_{i}(Y, X, \hat{\theta}, \mathcal{P})$ is the empirical evaluation of the $m \times 1$ vector of the $i$ th observation's values of the influence function for $\hat{\theta}$ by replacing the unknown parameters with sample estimates.

### 3.5.1 Inference in Stratified, Clustered Multi-Stage Survey Samples

NHANES employs a complex stratified, clustered sampling design. While bias incurred from the differential sample selection probabilities (encoded in the survey weights) is accounted for in the estimation procedure, inference is affected by the fact that individuals within strata and primary sampling units (PSUs) are correlated. To account for this, we modify this linearized variance estimator, known as the robust or sandwich estimator outside of survey-based analysis, by summing the contributions of the $i$ th individual ( $i=1, \ldots, n_{j}$ ), nested in the $j$ th primary sampling unit (PSU; $j=1, \ldots, J_{k}$ ), nested in the $k$ th sampling stratum ( $k=1, \ldots, K$ ). Thus, the estimated covariance matrix

What's the Weight?
for our parameters is expressed in terms of the variability of the between PSU-level sums of the first order Taylor approximations within the sampling strata. This becomes

$$
\begin{equation*}
\sum_{k=1}^{K} \frac{J_{k}}{J_{k}-1} \sum_{j=1}^{J_{k}}\left\{\phi_{\cdot j k}(y, \hat{\theta}, \mathcal{P})-\bar{\phi}_{\cdot \cdot k}(y, \hat{\theta}, \mathcal{P})\right\}\left\{\phi_{\cdot j k}(y, \hat{\theta}, \mathcal{P})-\bar{\phi}_{\cdot \cdot k}(y, \hat{\theta}, \mathcal{P})\right\}^{\prime} \tag{9}
\end{equation*}
$$

where $K$ and $J_{k}$ are the number of strata and number of PSUs within the $k$ th stratum, respectively, $\phi_{\cdot j k}(y, \hat{\theta}, \mathcal{P})= \sum_{i=1}^{n_{j}} \phi_{i j k}(y, \hat{\theta}, \mathcal{P})$ is the sum of the influence function contributions among individuals in the $j$ th cluster, and $\bar{\phi}_{\cdot \cdot k}(y, \hat{\theta}, \mathcal{P})=\frac{1}{J_{k}} \sum_{j=1}^{J_{k}} \phi_{\cdot j k}$ is the "average" influence function value within the $k$ th stratum. Software for these methods can be found in the R package svycdiff at https://github.com/salernos/svycdiff, in addition to the code and data necessary to reproduce the simulation studies and data analysis described below.

## 4 Simulation Studies

We conduct a series of simulation studies to better understand the finite sample performance of our proposed estimators, as compared to approaches typically used in practice. Based on the simulation studies conducted in DuGoff et al. (2014) and Ridgeway et al. (2015), we extend this work in several important ways. First, we have our proposed estimators, which represent novel alternatives to various combinations of weighting schemes outlined in Table 1 . Second, we have varied the set of associations in our data to systematically include or exclude associations between $A, X$, and $S$ in our data generating mechanism to understand how certain relationships impact our estimation and inference. The purpose of the overall simulation study is to quantify the bias and variance associated with the use of our proposed approach, as compared to the various weighting schemes which may be currently employed.

### 4.1 Data Generation

As in DuGoff et al. (2014) and Ridgeway et al. (2015), let $X$ denote a normally-distributed covariate which relates to our outcome, $Y$, race, $A$, and sample selection indicator, $S$. We generate population-level data with $X \sim \mathcal{N}(1,1)$ for a super population of $N=100,000$ individuals from which we repeatedly take samples. We then generate the remaining data from three models:

1. Propensity Model: $\operatorname{Pr}(A \mid X)=\operatorname{logit}^{-1}\left(\tau_{0}+\tau_{X} X\right)$,
2. Sample Selection Model: $\operatorname{Pr}(S \mid A, X)=\operatorname{logit}^{-1}\left(\beta_{0}+\beta_{A} A+\beta_{X} X+\varepsilon_{S}\right) ; \varepsilon_{S} \sim \mathcal{N}(0,0.1)$,
3. Outcome Model: $f(Y \mid A, X)$,
where logit ${ }^{-1}(u)=[1+\exp \{-u\}]^{-1}$ is the inverse logit function and we add a small amount of noise to the generation of the sample selection indicator to model this variable in our later procedure. From these models, we simulate the binary variable of interest, $A \mid X \sim \operatorname{Bin}[N, \operatorname{Pr}(A \mid X)]$, the sample selection indicator, $S \mid A, X \sim \operatorname{Bin}[N, \operatorname{Pr}(S \mid A, X)]$, and sample selection weights, $\omega_{S}=\operatorname{Pr}^{-1}(S \mid A, X)$. In simulating the outcome $Y$, we consider a heterogeneous treatment effect which varies with $X$, such that

$$
Y=\gamma_{0}+\gamma_{X} X+\gamma_{A} A+\gamma_{A X} A X+\varepsilon_{O}
$$

where $\varepsilon_{O} \sim \mathcal{N}(0,1)$. We consider eight simulation settings, over which we vary the coefficients $\tau_{X}, \beta_{A}$, and $\beta_{X}$, corresponding to the parameters in the true propensity and selection models (see Figure $2 \mathrm{a}-\mathrm{b}$ ), where each setting corresponds to a progressively more complex relationship among the variables. Across all simulation settings, we fixed $\tau_{0}=-1, \beta_{0}=-4.5, \gamma_{0}=1, \gamma_{A}=1, \gamma_{X}=1$, and $\gamma_{A X}=0.1$. Within each setting, we drew 200 sub-samples based on our simulated sample selection indicator, $S$. We fit the various combinations of approaches listed in Figure 2 Our target quantity of interest was the ACD. We compared the percent bias, mean squared error (MSE), and coverage probability at a significance level of 0.05 for each method.

### 4.2 Results

Results from our simulation studies are given in Figure 2 - -d and Supplemental Table B1. Here, we discuss these results in the context of each simulation setting, where the data are generated to vary what sources of bias we expect to encounter when estimating the ACD .

### 4.2.1 Settings 1 and 3: No Bias Expected

In Settings 1 and 3, there is neither confounding nor selection bias in the data generating mechanism. Setting 1 provides a fair comparison across all the methods considered, as both the group propensity, $\operatorname{Pr}(A \mid X)$, and sample selection probabilities, $\operatorname{Pr}(S \mid A, X)$, were generated independent of any covariates. As shown, all of the methods except for the naive g-computation approach perform comparably in this setting with respect to the percent bias of the ACD estimator. Specifically, the percent bias among the three proposed estimators ranged from $0.499-0.647 \%$, as compared to $0.166-0.538 \%$ among the existing methods (excluding the naive g-computation), suggesting that all of the methods considered accurately estimate the average controlled difference. This is expected, as the methods which do not account for confounding or selection bias are correctly specified, and the methods that do are unencumbered by the additional weights. The proposed approaches also had among the lowest MSEs, ranging from 0.475-0.480, as compared to 0.482-1.103 among the existing approaches. Lastly, across 200 independent replications, the proposed methods had coverage rates of $92.0-92.5 \%$, as compared to $87.5-93.0 \%$ for the existing methods. Similarly, in Setting 3, where selection depends on $A$ but neither selection nor $A$ depend on $X$, all methods tend to perform well. Here, we see that the percent bias for the proposed methods ranged from 0.217-1.497\%, on par with the other methods ( $0.138-0.417 \%$ ). Mean squared errors ranged from 0.219-0.243 for the proposed methods, similar to MSEs of 0.222-0.547 among the existing methods. Further, all of the methods had nominal coverage rates of 94.5-99.0\%.

### 4.2.2 Setting 2 and 4: Confounding Bias Expected

In Settings 2 and 4, we generate $A$ conditional on $X$, with selection further being dependent on $A$ in Setting 4. In these settings, we now expect there to be confounding bias, as $\operatorname{Pr}(A \mid X)$ is no longer uniform over the range of $X$ values. As such, we see that all methods which account for both $A$ and $X$ tend to perform comparatively well, whereas the simple linear regression (SLR) of $Y$ on $A$ performs poorly due to confounding bias in $X$. Specifically, we see that the percent bias in the SLR estimator has increased from 0.138-0.166\% in Settings 1 and 3 to $78.249-79.480 \%$ in Settings 2 and 4, whereas the other estimators (including the proposed methods) still see biases ranging in magnitude from $0.977-2.778 \%$ in Setting 2 and $0.210-1.526 \%$ in Setting 4. We further see an increase in MSE for the SLR estimator, with values ranging from 75.408-75.638, while the MSE for the other existing methods (0.404-1.176) and the proposed estimators (0.362-1.220) remained low. Once again, the coverage probabilities for the proposed (92.5-94.5\%) and other existing (88.5-94.0\%) remained at the nominal level, whereas the SLR did not cover the true ACD (0\%).

### 4.2.3 Settings 5 and 7: Selection Bias Expected

In Settings 5 and 7, we now generate $S$ conditional on $X$, with selection further being dependent on $A$ in Setting 7. Here, we now expect there to be selection bias induced by the $S \mid X$ relationship. In Setting 5, the percent bias among the existing approaches ranges from 9.182-9.544\%, while the bias among the proposed methods ranges from $0.302-1.252 \%$, demonstrating empirically that the proposed estimators are unbiased for the target ACD. Moreover, these results persist in Setting 7, with the percent bias among the existing approaches (3.992-6.809\%) being higher than the proposed approaches (0.172-2.322\%). Similar patterns can be seen when comparing the MSEs of the existing approaches (1.135-1.311 in Setting 5 and 0.587-0.663 in Setting 7) to those proposed in this work (0.236-0.325 in Setting 5 and 0.135-0.265 in Setting 7). Further, only the proposed methods achieved the nominal coverage rate (93.5-95.5\% in Setting 5 and 91.0-97.0\% in Setting 7), while the other methods show coverage ranging from 9.0-36.5\% and 19.0-80.5\% in Settings 5 and 7, respectively.

### 4.2.4 Settings 6 and 8: Both Confounding and Selection Bias Expected

Lastly, Settings 6 and 8 represent the most complex scenarios of confounding and selection bias, with Setting 8 mirroring the conceptual diagram for our motivating data. In this setting, our proposed estimators outperform all current approaches with respect to the percent bias, MSE, and coverage for estimating the ACD. In particular, percent bias among existing approaches ranges from 7.847-82.816\% in Setting 6 and 6.226-73.914\% in Setting 8, whereas the bias among the proposed estimators ranges from $0.633-1.514 \%$ and $1.083-1.115 \%$, respectively. This is expected as, the proposed methods have the correct balancing and generalizability weights under these settings, whereas the existing approaches fail to incorporate one or both weights, or fail to incorporate them correctly into the form of the estimator. The proposed approaches again had the lowest MSEs, ranging from 0.131-0.540 across both settings, as compared to $0.927-82.577$ for the existing approaches. Lastly, the proposed approaches achieve nominal coverage $(93.5-97.0 \%$ across both settings), whereas the existing methods do not ( $0-83.5 \%$ ). For full results, see Supplemental Table B1.

### 4.3 Sensitivity Analysis

In a sensitivity analysis, we study our proposed approaches under increasing model misspecification by introducing effect heterogeneity. Specifically, we systematically included larger interactions of race and covariates, where we varied $\gamma_{A X} \in\{0,0.01,0.05,0.1,0.5\}$. We estimate IPW1 and IPW2 as is, and we fit two versions of OM where we (1) correctly specify versus (2) misspecify the outcome model by not including the interaction term present in the data generating mechanism. Here we seek to assess the robustness of these approaches against the oracle estimator. The results from this analysis show that overall, all methods tend to perform well in terms of the bias, MSE, and coverage of the estimator, with OM performing acceptably under moderate misspecification. In particular, for $\gamma_{A X} \in\{0,0.01,0.05,0.1\}$, the method with the misspecified outcome model attained nominal coverage (ranging from 93.5-96.5\%), with biases below 0.05\% (0.008-0.028) and comparable MSEs to the other methods (0.001-0.003). However this approach incurs bias as treatment heterogeneity becomes more evident. Specifically, for the setting in which $\gamma_{A X}=0.5$, we see that the bias increases to $0.14 \%$ and the method does not cover the true ACD. These results suggest that the IPTW-type estimators (IPW1 and IPW2), which do not assume additivity, may be more robust. Full simulation results are presented in Supplemental Table B2.

### 4.4 Summary Takeaways

In summary, the simulation settings described above are designed to vary the associations between $Y, A, X$, and $S$ with increasing complexity, in order to introduce either/both confounding and/or selection bias into the data generating mechanism. In settings with neither confounding nor selection bias, all existing and proposed methods perform comparably well, estimating the ACD with low bias and MSE, and nominal coverage. In settings of confounding bias (without selection bias), the methods which account for both $A$ and $X$, namely all of the multiple regression and IPTW-based estimators, tend to perform comparatively well, whereas methods that only model $A$ suffer from high bias and negligible coverage. When $X$ is introduced into the generation of either/both $S$ and $A$, that is, when selection or selection + confounding bias exists, we see that standard analytic approaches lead to biased estimates and do not attain nominal coverage, whereas the proposed methods perform empirically well, supporting theoretical results derived in the previous section. Lastly, our sensitivity analysis reveals that the proposed methods which rely on contrasts and inverse probability weighting, rather than outcome modeling and direct standardization, are more robust to misspecification, particularly as the degree of effect heterogeneity between the groups of interest increases.

## 5 NHANES: Race, SES, and Telomere Length

We now turn our attention to our motivating example, which comes from the National Health and Nutrition Examination Survey (NHANES). NHANES is a nationally representative survey sample collected by the Centers for Disease Control, which contains a wealth of demographic, dietary, physical examination, laboratory, and questionnaire data on individuals. Our variable of interest is the survey participant's self-reported race. Racial groups are categories of people treated as a social entity by virtue of physical characteristics. While an individual's race is often self-reported, racial groups may represent commonalities such as geographic origin, genetic ancestry, cultural norms and traditions, social history, or current social circumstances (Williams et al., 2010). From a statistical perspective, race is often a proxy for other sources of shared variation which must be accounted for when making inferential statements. We focus on non-Hispanic participants who self-identify as Black or White as, particularly in the US, it is known that Black individuals tend to have poorer health outcomes than White individuals due to structural inequalities (Arias and Xu, 2022).

### 5.1 Motivating Question

Telomeres are regions of DNA at the ends of chromosomes that protect against cellular aging and senescence (Lin et al., 2016). Telomere shortening is associated with disease incidence and a variety of health outcomes (Shammas, 2011). Variation in telomere lengths is attributable to age and shortening during mitosis, in addition to genetics, social history, exposure to environmental contaminants, and psycho-social stressors (Jiang et al., 2007, Blackburn et al., 2015). Paradoxically, Black individuals typically have longer telomeres than White individuals (Needham et al., 2013; Venkateswaran et al., 2024), with plausible explanations citing leukocyte cell composition, population stratification, or genetic differences (Freedman et al., 1997; Lin et al., 2016; Hansen et al., 2016). Others posit that environmental exposures associated with longer telomere length underlie this so-called 'race effect', as these exposures differ significantly between Blacks and Whites (Needham et al., 2020; Roberts et al., 2022). Further, studies have found telomere length to be comparable between Black and White individuals in socio-economically homogeneous populations (Geronimus et al., 2015), calling into question purely genetic explanations. Our motivating question is this: if we could hypothetically balance socioeconomic status (SES; $X$ ) between Black and White individuals ( $A$ ) in a nationally representative sample ( $S$ ), would we still see significant Black/White differences in telomere length ( $Y$ )?

![](https://cdn.mathpix.com/cropped/2025_09_15_96e7ab9e33e3f2aa73edg-12.jpg?height=1124&width=2239&top_left_y=294&top_left_x=252)
Figure 2: Simulation setup and results. Columns denote each of eight simulation settings. The top row gives the assumed relationships between variables for each setting. The second row gives the parameter settings for each data generating mechanism. The third row gives the average percent bias and Monte Carlo standard errors for each method across 200 simulation replicates. The fourth row gives the coverage probabilities for each method.

N

### 5.2 NHANES Sampling Design

The stratified, clustered sampling design of the NHANES survey is designed to over-represent Black individuals and underrepresented groups in particular, to achieve a more nationally representative sample. Namely, NHANES samples in four stages. In the first stage, primary sampling units (PSUs; i.e., counties) are selected. Counties are stratified and selected with probability proportional to their weighted average population counts, where the weights give a higher probability of selection to counties with a higher proportion of underrepresented subgroups (e.g., certain age groups, marginalized racial groups, lower-income households). In the second stage, the PSUs are further divided (e.g., into city blocks) and sub-sampled, and in the third stage, households are sampled from these sample segments. Again, households within segments that have a greater proportion of underrepresented age, ethnic, or income groups are given additional weight for being selected. Lastly, individuals within households are sampled according to designated age-sex-race/ethnicity screening subdomains. This complex sampling scheme motivates our proposed methods, as sample selection depends on self-reported race and potential confounders (i.e., socioeconomic status).

### 5.3 Study Sample

The 1999-2002 NHANES waves consisted of 7,839 participants with recorded laboratory measures, representing our survey sample ( $S=1$ ). Our primary endpoint, $Y$, was the log-transformed mean ratio of an individual's telomere length to a standard reference DNA sample across all leukocyte cell types (mean T/S). Telomere length was assayed via quantitative polymerase chain reaction (PCR; Cawthon, 2002; Needham et al., 2013). We focus on the 1999-2002 NHANES waves, as they featured 4-year adjusted survey weights designed for aggregating data across cohorts. Among the initial 7,839 participants, 5,308 (67.7\%) self-identified as either non-Hispanic White or non-Hispanic Black, the levels of our group variable $A$. Excluding those participants without our outcome of interest, our final analytic sample contained 5,298 Non-Hispanic White or Non-Hispanic Black identifying participants with measured telomere length. As discussed previously, race was our variable of interest. We further adjusted our models for study participant age, sex, and blood cell composition, including complete blood count and five part differential consisting of the proportion of neutrophils, eosinophils, basophils, lymphocytes, and monocytes, to account for known differences in these factors (Freedman et al., 1997), as well as twelve indicators of SES, collectively representing our confounding variables $X$. Ten of these, namely marital status, education level, household income, insurance status, Special Supplemental Nutrition Program for Women, Infants, and Children (WIC) usage, household size, home ownership, home type, food security status, and an individual's poverty income ratio (PIR), were extracted directly from the NHANES demographic and occupation questionnaires. Occupation category was constructed by mapping occupation group codes in the NHANES 1999-2002 occupation questionnaire to the national statistics socioeconomic job classifications, and employment status was derived from three occupational measures: type of work done last week, hours worked last week at all jobs, and main reason for not working last week (Rehkopf et al., 2008; Rose et al., 2005). In later modeling, we perform complete case analysis on $n=5,270$ participants after removing 28 individuals without measured blood composition.

Descriptive statistics for our analytic sample are presented in Table 2, both overall and stratified by self-reported race. As shown, non-Hispanic Black participants had a median telomere length (mean T/S ratio) of 1.05 (i.e., 0.05 times longer than the standard reference DNA), as compared to non-Hispanic White participants with a median telomere length of 0.98 . With respect to the identified socioeconomic characteristics, non-Hispanic Black versus White participants differed significantly across all 12 SES indicators, with Black participants having lower educational attainment, lower household income, and lower home ownership rates, as well as higher food insecurity and WIC utilization rates, larger household sizes, and a higher proportion uninsured, unemployed, and below the federal poverty line. Further, a higher proportion of Black participants reported not working or working in low blue collar occupations, a higher proportion reported being widowed, divorced, or separated, and a higher proportion reported residing in apartments, all of which suggest lower socio-economic status (Rose et al., 2005). Based on these factors, we then calculated propensity scores with race as the outcome using unweighted and survey-weighted logistic regressions. The results from these models fit are given in supplementary Table C 1 . The propensity scores from these models were then carried forward to our later outcome models in order to estimate the ACD of telomere length by race.

### 5.4 Results

We compared our proposed approaches to six methods that one might consider in practice, each of which successively increase in their respective adjustments for potential confounding and selection bias. Namely, we fit a multiple linear regression (Approach 2 in Table 1) of log-transformed telomere length on race, age, sex, the blood composition variables, and the socioeconomic indicators, not accounting for the potential confounding or selection bias in the study. We then fit a survey-weighted multiple regression ((Approach 4), and inverse probability of treatment weighted (IPTW) multiple regression (Approach 5), a regression weighted by the product of the within sample propensity score weights and the survey weights (Approach 6), and a regression weighted by the product of the survey-weighted propensity score
weights and the survey weights (Approach 7), not unlike our simulation study. We omitted the oracle regression, simple linear regression, and the naive g-computation methods, as they were not applicable (as with the oracle regression) or inadvisable (as with the simple linear regression and naive g-computation). For the proposed methods, standard errors for the ACD were calculated via Equation (9), whereas for the existing methods, we calculate either model-based or design-based standard errors where appropriate.
ACD estimates and corresponding 95\% confidence intervals across the various analytic approaches are presented in Table 3 below. In general, the ACD estimates across different analytic strategies tend to attenuate in magnitude as we made more appropriate adjustments for confounding and selection bias. For example, the multiple linear regression had an ACD estimate of 0.0265 , corresponding to approximately a $2.7 \%$ longer telomere length, on average, among non-Hispanic Black individuals as compared to non-Hispanic White individuals, adjusting for all other factors ( $95 \%$ CI: 0.0106-0.0423). In contrast the ACD point estimates from our proposed approaches varied from 0.0132 (IPW2) to 0.0176 (OM), though these average controlled differences were not statistically different from zero. These results suggest that there is a strong confounding relationship between SES and race. Moreover, the methods which properly incorporated the NHANES stratified, clustered design tended to have more conservative standard error estimates than those which did not, as evidenced by the wider confidence intervals (Table 3).
These results align with our analytic and simulation results in two important ways. Firstly, we show analytically that if our conceptual diagram holds, the proposed approaches will lead to consistent estimates of the ACD, whereas methods which do not account for confounding and/or the sampling design appropriately will incur bias in estimating the ACD. This is further evidenced in our simulations, which show that the ACD is overestimated, on average, in the settings which closely reflect our assumed conceptual diagram for these data. The ACD estimates for the proposed approaches are roughly $50 \%$ those of the existing approaches. Secondly, the methods which respect the complex survey design tend to have wider confidence intervals, appropriately, as individuals within sampling units are correlated.

### 5.5 Supplementary Analysis: Lead Exposure, SES and Telomere Length in NHANES

In a supplementary analysis, we present a different example from NHANES which may be amenable to a causal interpretation (in the sense that counterfactual/potential outcomes and plausibly changing exposures are more meaningful). To illustrate how the proposed methods can, under stronger assumptions, identify the average difference in potential outcome means (population average treatment effect; PATE), we study the effect of exposure to a particular environmental contaminant, lead, on telomere length (Zota et al., 2015). Lead exposure is associated with negative health outcomes, such as cardiovascular and kidney diseases (Navas-Acien et al., 2007, 2009), and biological markers of oxidative stress and inflammation (Lin et al., 2016). Recent works suggest that lead exposure may be associated with telomere shortening (Lin et al., 2016, Wu et al., 2012; Zota et al., 2015), however, evidence from these studies is mixed and depends on the analytic strategy. Thus, further exploring the estimated effect of lead exposure on telomere length with our proposed approaches may be of interest.
Blood lead levels were measured at the CDC's National Center for Environmental Health (Atlanta, Georgia) using a simultaneous multi-element atomic absorption spectrometer (SIMAA 6000; PerkinElmer, Norwalk, Connecticut) with Zeeman background correction (Centers for Disease Control and Prevention, 2001a b). The limits of detection (LOD) were $0.3 \mu \mathrm{~g} / \mathrm{dL}$ for blood lead, with < 1\% of study participants having blood lead concentrations below the LOD. Among these patients, we imputed their blood lead concentrations by LOD divided by the square root of 2 (Hornung and Reed, 1990). To define our exposure, we dichotomized LOD-imputed blood lead concentrations at the median $\mu \mathrm{g} / \mathrm{dL}$ to study the difference in potential outcome means between 'higher' and 'lower' exposure groups.
We repeated our analysis above, treating the dichotomized lead variable as our exposure $(A)$. As before, we fit a propensity score for lead exposure conditional on the twelve socioeconomic indicators ( $X$ ) described above. We further included self-reported race using two strategies - first as a precision covariate along with age and blood composition (i.e., not in $X$ ) and second, in a sensitivity analysis, as a part of our confounders, $X$. The results of this analysis are presented in Supplementary Table C2. While the point estimates and findings differed across methods, we found a significant exposure effect for both the traditional and proposed IPW estimators, with an estimated 3.3-5.0\% reduction in telomere length. For the remaining methods, including the proposed outcome modeling estimator, we failed to reject the null hypothesis. Further, there were no appreciable differences in these estimates or the corresponding conclusions regarding significance when comparing our results with versus without including self-reported race in the propensity model (where applicable).

What's the Weight?

Table 2: Characteristics of the $n=5,270$ non-Hispanic Black and non-Hispanic White National Health and Nutrition Examination Survey (NHANES) participants in our analytic sample; overall and stratified by self-reported race. Descriptive statistics are reported as median (IQR) for continuous measures or number (\%) for categorical measures. $P$ values denote the univariate tests of significance (Wilcoxon rank sum test, Pearson's Chi-squared test, or Fisher's exact test) comparing the distribution of each measure among non-Hispanic Black versus non-Hispanic White participants.
| Characteristic | Overall, $\mathrm{N}=$ 5,298 ${ }^{1}$ | Non-Hispanic White, $\mathrm{N}=3,965^{1}$ | Non-Hispanic Black, $\mathrm{N}=1,333{ }^{1}$ | pvalue ${ }^{2}$ |
| :--- | :--- | :--- | :--- | :--- |
| Telomere Length, Mean T/S | 1.00 (0.84, 1.18) | 0.98 (0.83, 1.16) | 1.05 (0.88, 1.25) | <0.001 |
| Age, Years | $50(35,67)$ | $52(35,70)$ | $45(34,62)$ | <0.001 |
| Sex |  |  |  | 0.4 |
| Male | 2,574 (49\%) | 1,939 (49\%) | 635 (48\%) |  |
| Female | 2,724 (51\%) | 2,026 (51\%) | 698 (52\%) |  |
| Education |  |  |  |  |
| High School or GED | 2,621 (49\%) | 1,790 (45\%) | 831 (62\%) |  |
| Some College | 1,448 (27\%) | 1,102 (28\%) | 346 (26\%) |  |
| College Graduate | 1,222 (23\%) | 1,068 (27\%) | 154 (12\%) |  |
| Refused/Unknown | 7 (0.1\%) | 5 (0.1\%) | 2 (0.2\%) |  |
| Marital Status |  |  |  | <0.001 |
| Never Married | 754 (14\%) | 436 (11\%) | 318 (24\%) |  |
| Widowed/Divorced/Separated | 1,157 (22\%) | 775 (20\%) | 382 (29\%) |  |
| Married/Living with Partner | 3,144 (59\%) | 2,574 (65\%) | 570 (43\%) |  |
| Refused/Unknown | 243 (4.6\%) | 180 (4.5\%) | 63 (4.7\%) |  |
| Household Size |  |  |  | <0.001 |
| 1 Person | 882 (17\%) | 663 (17\%) | 219 (16\%) |  |
| 2 People | 1,903 (36\%) | 1,587 (40\%) | 316 (24\%) |  |
| 3 People | 997 (19\%) | 720 (18\%) | 277 (21\%) |  |
| 4 People | 775 (15\%) | 551 (14\%) | 224 (17\%) |  |
| 5+ People | 741 (14\%) | 444 (11\%) | 297 (22\%) |  |
| Home Ownership |  |  |  | <0.001 |
| Does Not Own Home | 1,551 (29\%) | 924 (23\%) | 627 (47\%) |  |
| Owns Home | 3,706 (70\%) | 3,011 (76\%) | 695 (52\%) |  |
| Refused/Unknown | 41 (0.8\%) | 30 (0.8\%) | 11 (0.8\%) |  |
| Home Type |  |  |  | <0.001 |
| Family Home Detached | 3,361 (63\%) | 2,681 (68\%) | 680 (51\%) |  |
| Family Home Attached | 464 (8.8\%) | 332 (8.4\%) | 132 (9.9\%) |  |
| Apartment | 938 (18\%) | 527 (13\%) | 411 (31\%) |  |
| Other | 493 (9.3\%) | 395 (10.0\%) | 98 (7.4\%) |  |
| Refused/Unknown | 42 (0.8\%) | 30 (0.8\%) | 12 (0.9\%) |  |
| Household Income |  |  |  | <0.001 |
| \$0 - \$20,000 | 1,076 (20\%) | 715 (18\%) | 361 (27\%) |  |
| \$20,000 - \$35,000 | 971 (18\%) | 682 (17\%) | 289 (22\%) |  |
| \$35,000 - \$55,000 | 935 (18\%) | 723 (18\%) | 212 (16\%) |  |
| \$55,000 - \$75,000 | 609 (11\%) | 506 (13\%) | 103 (7.7\%) |  |
| \$75,000+ | 1,140 (22\%) | 979 (25\%) | 161 (12\%) |  |
| Refused/Unknown | 567 (11\%) | 360 (9.1\%) | 207 (16\%) |  |
| Poverty-Income Ratio |  |  |  | <0.001 |
| < 1.3 | 1,055 (20\%) | 643 (16\%) | 412 (31\%) |  |
| $1.3 \leq$ PIR < 3.5 | 1,841 (35\%) | 1,348 (34\%) | 493 (37\%) |  |
| $\geq 3.5$ | 1,954 (37\%) | 1,672 (42\%) | 282 (21\%) |  |
| Refused/Unknown | 448 (8.5\%) | 302 (7.6\%) | 146 (11\%) |  |
| Employment Status |  |  |  | 0.001 |
| Full-Time | 932 (18\%) | 677 (17\%) | 255 (19\%) |  |
| Part-Time | 272 (5.1\%) | 206 (5.2\%) | 66 (5.0\%) |  |
| Retired | 602 (11\%) | 485 (12\%) | 117 (8.8\%) |  |
| Not Working | 398 (7.5\%) | 262 (6.6\%) | 136 (10\%) |  |
| Refused/Unknown | 3,094 (58\%) | 2,335 (59\%) | 759 (57\%) |  |
| Occupation Category |  |  |  | <0.001 |


| No Work | 53 (1.0\%) | 30 (0.8\%) | 23 (1.7\%) |  |
| :--- | :--- | :--- | :--- | :--- |
| Low Blue Collar | 690 (13\%) | 451 (11\%) | 239 (18\%) |  |
| High Blue Collar | 250 (4.7\%) | 196 (4.9\%) | 54 (4.1\%) |  |
| Low White Collar | 490 (9.2\%) | 362 (9.1\%) | 128 (9.6\%) |  |
| High White Collar | 644 (12\%) | 543 (14\%) | 101 (7.6\%) |  |
| Refused/Unknown | 3,171 (60\%) | 2,383 (60\%) | 788 (59\%) |  |
| Insurance Status |  |  |  | <0.001 |
| Not Insured | 681 (13\%) | 430 (11\%) | 251 (19\%) |  |
| Insured | 4,569 (86\%) | 3,503 (88\%) | 1,066 (80\%) |  |
| Refused/Unknown | 48 (0.9\%) | 32 (0.8\%) | 16 (1.2\%) |  |
| Food Security Status |  |  |  | <0.001 |
| Food Secure | 4,397 (83\%) | 3,443 (87\%) | 954 (72\%) |  |
| Marginally Food Secure | 272 (5.1\%) | 144 (3.6\%) | 128 (9.6\%) |  |
| Food Insecure | 428 (8.1\%) | 238 (6.0\%) | 190 (14\%) |  |
| Refused/Unknown | 201 (3.8\%) | 140 (3.5\%) | 61 (4.6\%) |  |
| WIC Utilization |  |  |  | <0.001 |
| No WIC | 4,919 (93\%) | 3,775 (95\%) | 1,144 (86\%) |  |
| Received WIC | 366 (6.9\%) | 185 (4.7\%) | 181 (14\%) |  |
| Refused/Unknown | 13 (0.2\%) | 5 (0.1\%) | 8 (0.6\%) |  |
| White Blood Cell Count, SI | 6.90 (5.60, 8.40) | 7.10 (5.90, 8.60) | 6.30 (5.10, 7.60) | <0.001 |
| Unknown | 2 | 1 | 1 |  |
| Lymphocytes, \% | $29(23,35)$ | $28(23,33)$ | $34(28,41)$ | <0.001 |
| Unknown | 28 | 19 | 9 |  |
| Monocytes, \% | 8.10 (6.80, 9.58) | 8.00 (6.80, 9.40) | 8.40 (6.90, 9.90) | <0.001 |
| Unknown | 28 | 19 | 9 |  |
| Segmented Neutrophils, \% | $59(53,65)$ | $61(55,66)$ | $54(46,61)$ | <0.001 |
| Unknown | 28 | 19 | 9 |  |
| Eosinophils, \% | 2.30 (1.50, 3.50) | 2.30 (1.50, 3.50) | 2.30 (1.40, 3.50) | 0.14 |
| Unknown | 28 | 19 | 9 |  |
| Basophils, \% | 0.60 (0.40, 0.80) | 0.60 (0.40, 0.90) | 0.60 (0.40, 0.80) | 0.2 |
| Unknown | 28 | 19 | 9 |  |

${ }^{l}$ Median (IQR); n (\%)
${ }^{2}$ Wilcoxon rank sum test; Pearson's Chi-squared test; Fisher's exact test

Table 3: Average controlled difference (ACD) estimates and corresponding 95\% confidence intervals across various analytic approaches for the comparison of effect of race (non-Hispanic Black versus non-Hispanic White participants) on log-transformed telomere length among $n=5,270$ participants in the National Health and Nutrition Examination Survey (NHANES). IPTW: Inverse Probability of Treatment Weighting.
| Method | ACD Estimate | 95\% Confidence Interval |
| :--- | :--- | :--- |
| Multiple Regression | 0.0265 | 0.0106, 0.0423 |
| IPTW Estimator | 0.0263 | 0.0080, 0.0446 |
| Survey-Weighted Multiple Regression | 0.0298 | -0.0012, 0.0607 |
| IPTW Multiple Regression | 0.0181 | 0.0052, 0.0311 |
| IPTW + Survey-Weighted Multiple Regression | 0.0219 | -0.0090, 0.0527 |
| Weighted IPTW + Survey-Weighted Multiple Regression | 0.0186 | -0.0127, 0.0499 |
| Outcome Modeling and Direct Standardization | 0.0176 | -0.0030, 0.0381 |
| Inverse Probability Weighting 1 | 0.0150 | -0.0151, 0.0451 |
| Inverse Probability Weighting 2 | 0.0132 | -0.0081, 0.0345 |


## 6 Discussion

There is a growing literature considering the use of propensity score weighting techniques in complex survey design settings. However, a consensus has not been reached for the setting we consider in this manuscript. Notably, propensity score methods have been developed and used primarily for simple random samples. When analyzing results from more complicated sampling schemes, such as the NHANES clustered, stratified multi-stage sample, one must make the distinction between the population and the sample as the target of inference (Heckman and Vytlacil, 2001). This distinction between the target populations and target estimands are important as researchers must be clear in their inferential statements at both the propensity score model and outcome model stages in their analysis. Further, this article examines a particular consideration for drawing inference in which sample selection depends on the group variable of interest, motivated from a social epidemiology question regarding racial disparity and socioeconomic confounding in health outcomes. Our analytic and numeric results suggest that, in settings where our assumed structure among the variables holds, our proposed methods minimize the bias in estimating the target average controlled difference and achieve nominal coverage rates, as compared to standard analysis methods.
We believe that the context of studying racial disparities presents these particularities in such a way that should be rigorously studied for best practice recommendations, as racial disparities are important and of increasing relevance in scientific research. Moreover the assumed notion of 'race' itself warrants discussion. If the scientific question under study seeks to understand the biological underpinnings of a so-called 'race effect,' say due to differences in genetic ancestry, then we cannot posit a causal counterfactual framework, as 'race' cannot be manipulated or thought of as a 'cause.' However, if race is measured as a social construct, we can then discuss altering racialization as a lived experience (Marcellesi, 2013). In our motivating example, we are interested in studying differences in telomere length between non-Hispanic Black and non-Hispanic White individuals. We find that evidence of racial differences in telomere length between Black and White individuals attenuates after accounting for available socioeconomic status variables in NHANES and after utilizing appropriate propensity score and survey weighting techniques. Among our proposed methods, we estimated the ACD in telomere length to be between $1.32 \%$ and $1.76 \%$, though we failed to detect a statistically significant difference. This contrasts with the results from other potential approaches, which varied from $1.81 \%$ to $3.0 \%$ in this study. Needham et al. (2013) estimated $4.8 \%$ longer telomeres in Black individuals, on average, adjusting for education, income, health behavior, and body mass index. Needham et al. (2020) and Roberts et al. (2022) also suggested evidence of social and environmental factors playing a role in racial disparities in telomere length. Taken together, our proposed method contributes to the collection of strategies that can investigate the role of social determinants of health on disparities, and in particular through the use of nationally representative survey data.
Though we focus on a particular research question and methods for propensity scores within the frame of complex survey designs, these concepts readily extend to other settings where observational data are collected via an underlying sample selection mechanism. More broadly, this type of problem is important to study to ensure research does not exacerbate health inequities through inadequate consideration of confounding and biases due to non-representative selection into databases. In particular, other large-scale databases, such as electronic medical records, provide valuable insights into real-world data but may be subject to their own selection biases. Areas of interest for future work include electronic health records data with unknown sample selection probabilities, non-Gaussian outcomes, and more complex questions that may include affect heterogeneity. Several conceptual questions about the in-sample or population generalizable propensity score have not yet been reconciled in the literature. Further, causal principles related to this work may be extended to more complex relational diagrams or sampling designs. For instance, as certain biomedical data become inexpensive and easy to collect, but other endpoints are not, a natural question is whether this framework can be extended to two-stage sampling or sequential designs. Lastly, we can formally expand on the utility of the proposed method by proposing a doubly robust, augmented inverse probability weighted estimator.

In conclusion, this work outlines approaches and novel estimands for using propensity score and survey weights in tandem to study controlled outcome differences when the groups under comparison influence sample selection. Though the conceptual diagram for this study is rather specific, this setup is common to many settings of health disparities research. That is, our proposed methods and investigation to estimate the ACD follow a motivating health disparities research question in which the sampling scheme and corresponding survey weights depend on the target of the propensity score model. We fill this gap in the literature by providing recommendation on the form of the appropriate estimators in this setting and provide analytic and numeric evidence of their properties. We have shown that when sample selection depends on the comparison groups of interest and/or potential confounders, we must use the direct standardization or propensity weighting strategies outlined here, rather than standard analytic approaches. It is our hope that this work will not only further our understanding of appropriate survey design considerations in this framework, but also make the task of analyzing such data in similar settings more accessible to researchers.

## Acknowledgments

We thank Dr. Yajuan Si for helpful discussions on this topic. This work was supported in part by NIH/NIGMS R35 GM144128 and the Fred Hutchinson Cancer Center J. Orin Edson Foundation Endowed Chair (SS), NIH/NIMH DP2MH122405, R01HD107015, and P2C HD042828 (THM), NSF DMS 1712933 and NIH/NCI UG3-CA267907 (BM), and NIH/NIGMS R01GM139926 (XS).

## References

E. Arias and J. Xu. United states life tables, 2019. National Vital Statistics Reports: From the Centers for Disease Control and Prevention, National Center for Health Statistics, National Vital Statistics System, 70(19):1-59, 2022.
P. C. Austin and E. A. Stuart. Moving towards best practice when using inverse probability of treatment weighting (iptw) using the propensity score to estimate causal treatment effects in observational studies. Statistics in medicine, 34(28):3661-3679, 2015.
P. C. Austin, N. Jembere, and M. Chiu. Propensity score matching and complex surveys. Statistical methods in medical research, 27(4):1240-1257, 2018.
E. H. Blackburn, E. S. Epel, and J. Lin. Human telomere biology: a contributory and interactive factor in aging, disease risks, and protection. Science, 350(6265):1193-1198, 2015.
D. D. Boos, L. A. Stefanski, et al. Essential statistical inference. Springer, 2013.
R. M. Cawthon. Telomere measurement by quantitative pcr. Nucleic acids research, 30(10):e47-e47, 2002.

Centers for Disease Control and Prevention. Laboratory Procedure Manual: Blood Cadmium and Lead, NHANES 1999-2000. Atlanta, GA, 2001a. Method No. 1090A/02-OD.
Centers for Disease Control and Prevention. Laboratory Procedure Manual: Blood Cadmium and Lead, NHANES 2001-2002. Atlanta, GA, 2001b. Method No. 1090A/02-OD.
L. R. Curtin, L. K. Mohadjer, S. M. Dohrmann, J. M. Montaquila, D. Kruszan-Moran, L. B. Mirel, M. D. Carroll, R. Hirsch, S. Schober, and C. L. Johnson. The national health and nutrition examination survey: Sample design, 1999-2006. Vital and health statistics, 2(155):1-39, 2012.
I. J. Dahabreh, S. E. Robertson, J. A. Steingrimsson, E. A. Stuart, and M. A. Hernan. Extending inferences from a randomized trial to a new target population. Statistics in medicine, 39(14):1999-2014, 2020.
I. Degtiar and S. Rose. A review of generalizability and transportability. Annual Review of Statistics and Its Application, 10:501-524, 2023.
N. Dong, E. A. Stuart, D. Lenis, and T. Quynh Nguyen. Using propensity score analysis of survey data to estimate population average treatment effects: A case study comparing different methods. Evaluation review, 44(1):84-108, 2020.
E. H. DuGoff, M. Schuler, and E. A. Stuart. Generalizing observational study results: applying propensity score methods to complex surveys. Health services research, 49(1):284-303, 2014.
M. R. Elliot. Combining data from probability and non-probability samples using pseudo-weights. Survey Practice, 2 (6), 2009.
D. S. Freedman, L. Gates, W. D. Flanders, O. W. Van Assendelft, J. J. Barboriak, M. R. Joesoef, and T. Byers. Black/white differences in leukocyte subpopulations in men. International journal of epidemiology, 26(4):757-764, 1997.
A. Fuentes, O. Lüdtke, and A. Robitzsch. Causal inference with multilevel data: A comparison of different propensity score weighting approaches. Multivariate Behavioral Research, 57(6):916-939, 2022.
A. T. Geronimus, J. A. Pearson, E. Linnenbringer, A. J. Schulz, A. G. Reyes, E. S. Epel, J. Lin, and E. H. Blackburn. Race-ethnicity, poverty, urban stressors, and telomere length in a detroit community-based sample. Journal of health and social behavior, 56(2):199-224, 2015.
M. E. Hansen, S. C. Hunt, R. C. Stone, K. Horvath, U. Herbig, A. Ranciaro, J. Hirbo, W. Beggs, A. P. Reiner, J. G. Wilson, et al. Shorter telomere length in europeans than in africans due to polygenetic adaptation. Human molecular genetics, 25(11):2324-2330, 2016.
J. J. Heckman and E. J. Vytlacil. Instrumental variables, selection models, and tight bounds on the average treatment effect. In Econometric Evaluation of Labour Market Policies, pages 1-15. Springer, 2001.
R. W. Hornung and L. D. Reed. Estimation of average concentration in the presence of nondetectable values. Applied occupational and environmental hygiene, 5(1):46-51, 1990.

What's the Weight?
D. G. Horvitz and D. J. Thompson. A generalization of sampling without replacement from a finite universe. Journal of the American statistical Association, 47(260):663-685, 1952.
P. J. Huber. Robust statistical procedures. SIAM, 1996.
K. Imai and M. Ratkovic. Estimating treatment effect heterogeneity in randomized program evaluation. The Annals of Applied Statistics, 7(1):443-470, 2013. doi: 10.1214/12-AOAS593. URL https://doi.org/10.1214/ 12-AOAS593.
H. Jiang, Z. Ju, and K. Rudolph. Telomere shortening and ageing. Zeitschrift für Gerontologie und Geriatrie, 40(5): 314-324, 2007.
R. Kundu, X. Shi, J. Morrison, J. Barrett, and B. Mukherjee. A framework for understanding selection bias in real-world healthcare data. arXiv preprint arXiv:2304.04652, 2023.
B. K. Lee, J. Lessler, and E. A. Stuart. Improving propensity score weighting using machine learning. Statistics in medicine, 29(3):337-346, 2010.
B. K. Lee, J. Lessler, and E. A. Stuart. Weight trimming and propensity score weighting. PloS one, 6(3):e18174, 2011.
D. Lenis, B. Ackerman, and E. A. Stuart. Measuring model misspecification: application to propensity score methods with complex survey data. Computational statistics \& data analysis, 128:48-57, 2018.
F. Li and F. Li. Using propensity scores for racial disparities analysis. Observational Studies, 9(1):59-68, 2023.
F. Li, A. M. Zaslavsky, and M. B. Landrum. Propensity score weighting with multilevel data. Statistics in medicine, 32 (19):3373-3387, 2013.
J. Lim, R. Walley, J. Yuan, J. Liu, A. Dabral, N. Best, A. Grieve, L. Hampson, J. Wolfram, P. Woodward, et al. Minimizing patient burden through the use of historical subject-level data in innovative confirmatory clinical trials: review of methods and opportunities. Therapeutic innovation \& regulatory science, 52:546-559, 2018.
J. Lin, J. Cheon, R. Brown, M. Coccia, E. Puterman, K. Aschbacher, E. Sinclair, E. Epel, and E. H. Blackburn. Systematic and cell type-specific telomere length changes in subsets of lymphocytes. Journal of immunology research, 2016, 2016.
T. Lumley. Complex surveys: a guide to analysis using R. John Wiley \& Sons, 2011.
T. Lumley and A. Scott. Fitting regression models to survey data. Statistical Science, pages 265-278, 2017.
M. A. Mansournia and D. G. Altman. Inverse probability weighting. Bmj, 352, 2016.
A. Marcellesi. Is race a cause? Philosophy of Science, 80(5):650-659, 2013.
A. Navas-Acien, E. Guallar, E. K. Silbergeld, and S. J. Rothenberg. Lead exposure and cardiovascular disease-a systematic review. Environmental health perspectives, 115(3):472-482, 2007.
A. Navas-Acien, M. Tellez-Plaza, E. Guallar, P. Muntner, E. Silbergeld, B. Jaar, and V. Weaver. Blood cadmium and lead and chronic kidney disease in us adults: a joint analysis. American journal of epidemiology, 170(9):1156-1164, 2009.
B. L. Needham, N. Adler, S. Gregorich, D. Rehkopf, J. Lin, E. H. Blackburn, and E. S. Epel. Socioeconomic status, health behavior, and leukocyte telomere length in the national health and nutrition examination survey, 1999-2002. Social science \& medicine, 85:1-8, 2013.
B. L. Needham, S. Salerno, E. Roberts, J. Boss, K. L. Allgood, and B. Mukherjee. Do black/white differences in telomere length depend on socioeconomic status? Biodemography and social biology, 65(4):287-312, 2020.
C. W. Pattanayak, D. B. Rubin, and E. R. Zell. Propensity score methods for creating covariate balance in observational studies. Revista Española de Cardiología (English Edition), 64(10):897-903, 2011.
D. M. Peng, Q. Qu, N. McDonald, S. A. Hollander, D. Bernstein, K. Maeda, B. D. Kaufman, D. N. Rosenthal, D. B. McElhinney, and C. S. Almond. Impact of the 18th birthday on waitlist outcomes among young adults listed for heart transplant: A regression discontinuity analysis. The Journal of Heart and Lung Transplantation, 36(11):1185-1191, 2017.
P. Rao. Some notes on misspecification in multiple regressions. The American Statistician, 25(5):37-39, 1971.
D. H. Rehkopf and B. L. Needham. The impact of race and ethnicity in the social epigenomic regulation of disease. In Nutritional Epigenomics, pages 51-65. Elsevier, 2019.
D. H. Rehkopf, L. F. Berkman, B. Coull, and N. Krieger. The non-linear risk of mortality by income level in a healthy population: Us national health and nutrition examination survey mortality follow-up cohort, 1988-2001. BMC Public Health, 8(1):1-11, 2008.
T. Richardson and A. Rotnitzky. Causal etiology of the research of james m. robins. Statistical Science, 29(4):459-484, 2014.
G. Ridgeway, S. A. Kovalchik, B. A. Griffin, and M. U. Kabeto. Propensity score analysis with survey weighted data. Journal of causal inference, 3(2):237-249, 2015.
E. K. Roberts, J. Boss, B. Mukherjee, S. Salerno, A. Zota, and B. L. Needham. Persistent organic pollutant exposure contributes to black/white differences in leukocyte telomere length in the national health and nutrition examination survey. Scientific Reports, 12(1):19960, 2022.
D. Rose, D. J. Pevalin, and K. O'Reilly. The National Statistics Socio-economic Classification: origins, development and use. Palgrave Macmillan, 2005.
P. R. Rosenbaum and D. B. Rubin. The central role of the propensity score in observational studies for causal effects. Biometrika, 70(1):41-55, 1983.
L. M. Rossen and M. Talih. Social determinants of disparities in weight among us children and adolescents. Annals of epidemiology, 24(10):705-713, 2014.
D. B. Rubin. Randomization analysis of experimental data: The fisher randomization test comment. Journal of the American statistical association, 75(371):591-593, 1980.
D. B. Rubin. Causal inference using potential outcomes: Design, modeling, decisions. Journal of the American Statistical Association, 100(469):322-331, 2005.
M. Salvatore, R. Kundu, X. Shi, C. R. Friese, S. Lee, L. G. Fritsche, A. M. Mondul, D. A. Hanauer, C. L. Pearce, and B. Mukherjee. To weight or not to weight? studying the effect of selection bias in three large ehr-linked biobanks. medRxiv, pages 2024-02, 2024.
M. A. Shammas. Telomeres, lifestyle, cancer, and aging. Current opinion in clinical nutrition and metabolic care, 14 (1):28, 2011.
X. Shi, Z. Pan, and W. Miao. Data integration in causal inference. Wiley Interdisciplinary Reviews: Computational Statistics, 15(1):e1581, 2023.
L. A. Stefanski and D. D. Boos. The calculus of m-estimation. The American Statistician, 56(1):29-38, 2002.
E. A. Stuart, S. R. Cole, C. P. Bradshaw, and P. J. Leaf. The use of propensity scores to assess the generalizability of results from randomized trials. Journal of the Royal Statistical Society Series A: Statistics in Society, 174(2): 369-386, 2011.
A. Venkateswaran, A. Sankar, A. G. Chandrasekhar, and T. H. McCormick. Robustly estimating heterogeneity in factorial data using rashomon partitions. arXiv preprint arXiv:2404.02141, 2024.
D. R. Williams, S. A. Mohammed, J. Leavell, and C. Collins. Race, socioeconomic status, and health: complexities, ongoing challenges, and research opportunities. Annals of the new York Academy of Sciences, 1186(1):69-101, 2010.
M. N. Williams, C. A. G. Grajales, and D. Kurkiewicz. Assumptions of multiple regression: Correcting two misconceptions. Practical Assessment, Research, and Evaluation, 18(1):11, 2019.
Y. Wu, Y. Liu, N. Ni, B. Bao, C. Zhang, and L. Lu. High lead exposure is associated with telomere length shortening in chinese battery manufacturing plant workers. Occupational and environmental medicine, 69(8):557-563, 2012.
E. C. Zabor, A. M. Kaizer, and B. P. Hobbs. Randomized controlled trials. Chest, 158(1):S79-S87, 2020.
E. L. Zanutto. A comparison of propensity score and linear regression analysis of complex survey data. Journal of data Science, 4(1):67-91, 2006.
S. Zeng, F. Li, R. Wang, and F. Li. Propensity score weighting for covariate adjustment in randomized clinical trials. Statistics in medicine, 40(4):842-858, 2021.
A. R. Zota and B. N. VanNoy. Integrating intersectionality into the exposome paradigm: a novel approach to racial inequities in uterine fibroids. American Journal of Public Health, 111(1):104-109, 2021.
A. R. Zota, B. L. Needham, E. H. Blackburn, J. Lin, S. K. Park, D. H. Rehkopf, and E. S. Epel. Associations of cadmium and lead exposure with leukocyte telomere length: findings from national health and nutrition examination survey, 1999-2002. American journal of epidemiology, 181(2):127-136, 2015.

What's the Weight?

## A Additional Analytic Results

## A. 1 Average Controlled Difference

The assumptions required to estimate the averaged controlled difference (ACD) are relatively weaker than those required to identify the causal potential outcome means (see below). In particular, the following assumptions are sufficient for showing that our functionals (2), (3), and (4) in the main text estimate the ACD:
(i) Positivity: $\operatorname{Pr}(A=a \mid X=x)>0 \forall a \in \mathcal{A}$ and every $x$ such that $f_{X}(x)>0$
(ii) Positivity of Sample Selection: $\operatorname{Pr}(S=1 \mid A=a, X=x)>0$ for every $a, x$ such that $f_{A, X}(a, x)>0$
(iii) Mean (Weak) Generalizability (Selection Exchangeability): $\mathbb{E}[Y \mid A=a, X]=\mathbb{E}[Y \mid A=a, S=1, X]$, that is, selection bias comes from $A, X$. This is implied by, but does not imply, strong generalizability (in distribution), $Y \perp S \mid A, X$.

We proceed by deriving the estimators in Equations (2), (3), and (4) from the main text below. We define the ACD as

$$
\mathrm{ACD}=\mathbb{E}_{X}[\mathbb{E}[Y \mid A=1, X]-\mathbb{E}[Y \mid A=0, X]]
$$

## Outcome Modeling and Direct Standardization

Under assumptions (i) - (iii), we show that the observed data functional, $\mu(a)$, given by

$$
\mu(a)=\mathbb{E}_{X}\left[\left.\mathbb{E}[Y \mid A=a, S=1, X] \frac{\operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right]
$$

can be used to estimate the ACD. Assumptions (i) and (ii) come in to ensure that $\mu(a)$ is well defined. Focusing on $\mathbb{E}_{X}[\mathbb{E}[Y \mid A=a, X]]$, we have that

$$
\begin{align*}
\mathbb{E}_{X}[\mathbb{E}[Y \mid A=a, X]] & \stackrel{(i i i)}{=} \mathbb{E}_{X}[\mathbb{E}[Y \mid A=a, S=1, X]] \\
& =\int_{\mathcal{X}} m(x) f(x) d x ; \quad \text { where } m(x)=\mathbb{E}[Y \mid A=a, S=1, X=x] \\
& =\int_{\mathcal{X}} m(x) f(x) \frac{f(x \mid S=1)}{f(x \mid S=1)} d x \\
& =\int_{\mathcal{X}} m(x) f(x \mid S=1) \frac{f(x) / 1}{\operatorname{Pr}(S=1 \mid X) f(x) / \operatorname{Pr}(S=1)} d x ; \quad \text { by Bayes' rule } \\
& =\int_{\mathcal{X}} m(x) f(x \mid S=1) \frac{\operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid X)} d x \\
& =\mathbb{E}_{X}\left[\left.\mathbb{E}[Y \mid A=a, S=1, X] \cdot \frac{\operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right] \tag{MainEq.2}
\end{align*}
$$

## Inverse Probability Weighting

Under assumptions (i) - (iii), we further show that the observed data functionals for our inverse probability weighted estimators, given by

$$
\begin{aligned}
& \mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid A=a, X) \operatorname{Pr}(A=a \mid X)} \right\rvert\, S=1\right] \\
& \mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(A=a \mid S=1, X) \operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right]
\end{aligned}
$$

also estimate $\mathbb{E}_{X}[\mathbb{E}[Y \mid A=a, X]]$. Let $C=A \times S=\mathbb{I}(A=1, S=1)$, that is,

$$
C= \begin{cases}1 ; & A=a, S=1 \\ 0 ; & S=0 \text { or } A \neq a, S=1\end{cases}
$$

so that

$$
\begin{align*}
\mathbb{E}_{X}[\mathbb{E}[Y \mid A=a, X]] & \stackrel{(i i i)}{=} \mathbb{E}_{X}[\mathbb{E}[Y \mid A=a, S=1, X]] \\
& =\mathbb{E}_{X}\left[\frac{C \times Y}{\operatorname{Pr}(C=1 \mid X)}\right] ; \quad \text { following the traditional IPW proof } \\
& =\mathbb{E}_{X}\left[\frac{A \times S \times Y}{\operatorname{Pr}(A=a, S=1 \mid X)}\right] ; \quad \text { by definition of } C \\
& =\mathbb{E}_{X}\left[\left.\frac{A \times 1 \times Y}{\operatorname{Pr}(A=a, S=1 \mid X)} \right\rvert\, S=1\right] \times \operatorname{Pr}(S=1)+0 \\
& =\mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(A=a, S=1 \mid X)} \right\rvert\, S=1\right] \\
& =\mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid A=a, X) \operatorname{Pr}(A=a \mid X)} \right\rvert\, S=1\right] \tag{MainEq.3}
\end{align*}
$$

or

$$
\begin{equation*}
=\mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(A=a \mid S=1, X) \operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right], \tag{MainEq.4}
\end{equation*}
$$

where again, the observed data functionals are well defined under (i) and (ii).

## A. 2 Identification of the Potential Outcome Means

Though not applicable to our motivating research question, in many scenarios the group membership variable of interest is a 'treatment' or 'exposure' in the more traditional sense, and we seek to target a causal quantity. To that end, we can adopt a counterfactual framework and, under stronger assumptions, show that the proposed estimators equivalently identify such a parameter. We introduce some additional notation below.

Take $Y^{a}$ to be the random variable representing the potential counterfactual outcome within each group (Rubin, 2005). That is, despite only observing one outcome per individual, we know that each study participant had two potential outcomes - the outcome that would be observed if the individual was in comparison group $a=0$, denoted by $Y^{0}$, and the potential outcome that would be observed if the participant instead was in comparison group $a=1$, denoted by $Y^{1}$. By considering an individual's potential outcome values based on their observed and counterfactual group membership, an inherent missing data problem arises. Importantly, there are two layers to the missingness mechanism in our setup. Firstly, we observe no data when $S=0$. Secondly, due to the missingness of counterfactual values, we cannot fully observe all potential outcomes, $Y^{a}$. Further, as before, $\mathbb{E}\left[Y^{a}\right] \neq \mathbb{E}\left[Y^{a} \mid S=1\right]$ in general, as the sampled study participants may not be representative of the larger target population. We can, however, make assumptions to estimate the unobserved, counterfactual outcome in the population. With the assumptions of the previous section, the following additional conditions are sufficient to identify the population potential outcome means, $\mathbb{E}\left[Y^{a}\right] \forall a \in \mathcal{A}$ :
(iii*) Weak Selection Exchangeability for Potential Outcomes: $\mathbb{E}\left[Y^{a} \mid A=a, X\right]=\mathbb{E}\left[Y^{a} \mid A=a, S=1, X\right]$, that is, selection bias comes from $A, X$. This is implied by, but does not imply, strong generalizability (in distribution), $Y^{a} \perp S \mid A, X$.
(iv) Stable Unit Treatment Value (SUTVA): $Y_{i}=Y_{i}^{a}$ for all observations $i=1, \ldots, n$ and for all $A_{i}=a \in \mathcal{A}$.
(v) Mean (Weak) Exchangeability: $\mathbb{E}\left[Y^{a} \mid X\right]=\mathbb{E}\left[Y^{a} \mid A=a, X\right]$, that is, confounding bias comes from $X$. This is implied by, but does not imply, strong exchangeability, i.e., $Y^{a} \perp A \mid X$.

This is thematically similar to Dahabreh et al. (2020), who study the generalization of causal inferences from individuals in randomized trials. The authors also differentiate between conditional exchangeability in the mean over $A$ in a randomized population and conditional exchangeability in the mean over $S$ in the context of randomized trials.

What's the Weight?

## Outcome Modeling and Direct Standardization

Under assumptions (i) - (v), we show that the observed data functional, $\mu(a)$, identifies the potential outcome mean in the target population, $\mathbb{E}\left[Y^{a}\right]$, where

$$
\mu(a)=\mathbb{E}_{X}\left[\left.\mathbb{E}[Y \mid A=a, S=1, X] \frac{\operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right]
$$

As before, $\mu(a)$ is well defined under (i) and (ii). The SUTVA, or consistency, assumption underpins the existence of the counterfactual outcomes, $Y^{a}$. The compact representation in (iv) captures two aspects of SUTVA - 'no interference,' which states that the $i$ th observation's outcome is unaffected by the treatment of other observations and 'no hidden variation,' which states that the potential outcome is well-defined for each treatment level, $a$. To identify $\mathbb{E}\left[Y^{a}\right]$, we have that

$$
\begin{align*}
\mathbb{E}\left[Y^{a}\right] & =\mathbb{E}_{X}\left[\mathbb{E}\left[Y^{a} \mid X\right]\right] ; \quad \text { by law of total expectation } \\
& \stackrel{(v)}{=} \mathbb{E}_{X}\left[\mathbb{E}\left[Y^{a} \mid A=a, X\right]\right] \\
& \stackrel{(i i i *)}{=} \mathbb{E}_{X}\left[\mathbb{E}\left[Y^{a} \mid A=a, S=1, X\right]\right] \\
& \stackrel{(i v)}{=} \mathbb{E}_{X}[\mathbb{E}[Y \mid A=a, S=1, X]] \\
& =\int_{\mathcal{X}} m(x) f(x) d x ; \quad \text { where } m(x)=\mathbb{E}[Y \mid A=a, S=1, X=x] \\
& =\int_{\mathcal{X}} m(x) f(x) \frac{f(x \mid S=1)}{f(x \mid S=1)} d x \\
& =\int_{\mathcal{X}} m(x) f(x \mid S=1) \frac{f(x) / 1}{\operatorname{Pr}(S=1 \mid X) f(x) / \operatorname{Pr}(S=1)} d x ; \quad \text { by Bayes' rule } \\
& =\int_{\mathcal{X}} m(x) f(x \mid S=1) \frac{\operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid X)} d x \\
& =\mathbb{E}_{X}\left[\left.\mathbb{E}[Y \mid A=a, S=1, X] \cdot \frac{\operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right] \tag{MainEq.2}
\end{align*}
$$

## Inverse Probability Weighting

Under assumptions (i) - (v), we further show that the observed data functionals for our inverse probability weighted estimators, given by

$$
\begin{aligned}
& \mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid A=a, X) \operatorname{Pr}(A=a \mid X)} \right\rvert\, S=1\right] \\
& \mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(A=a \mid S=1, X) \operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right]
\end{aligned}
$$

also identify the potential outcome mean in the target population, $\mathbb{E}\left[Y^{a}\right]$. Let $C=A \times S=\mathbb{I}(A=1, S=1)$, that is,

$$
C= \begin{cases}1 ; & A=a, S=1 \\ 0 ; & S=0 \text { or } A \neq a, S=1\end{cases}
$$

so that

$$
\begin{align*}
\mathbb{E}\left[Y^{a}\right] & =\mathbb{E}_{X}\left[\mathbb{E}\left[Y^{a} \mid X\right]\right] ; \quad \text { by law of total expectation } \\
& \stackrel{(v)}{=} \mathbb{E}_{X}\left[\mathbb{E}\left[Y^{a} \mid A=a, X\right]\right] \\
& \stackrel{(i i i)}{=} \mathbb{E}_{X}\left[\mathbb{E}\left[Y^{a} \mid A=a, S=1, X\right]\right] \\
& \stackrel{(i v)}{=} \mathbb{E}_{X}[\mathbb{E}[Y \mid A=a, S=1, X]] \\
& =\mathbb{E}_{X}\left[\frac{C \times Y}{\operatorname{Pr}(C=1 \mid X)}\right] ; \quad \text { following the traditional IPW proof } \\
& =\mathbb{E}_{X}\left[\frac{A \times S \times Y}{\operatorname{Pr}(A=a, S=1 \mid X)}\right] ; \quad \text { by definition of } C \\
& =\mathbb{E}_{X}\left[\left.\frac{A \times 1 \times Y}{\operatorname{Pr}(A=a, S=1 \mid X)} \right\rvert\, S=1\right] \times \operatorname{Pr}(S=1)+0 \\
& =\mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(A=a, S=1 \mid X)} \right\rvert\, S=1\right] \\
& =\mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(S=1 \mid A=a, X) \operatorname{Pr}(A=a \mid X)} \right\rvert\, S=1\right]  \tag{MainEq.3}\\
& \text { or } \\
& =\mathbb{E}_{X}\left[\left.\frac{A Y \operatorname{Pr}(S=1)}{\operatorname{Pr}(A=a \mid S=1, X) \operatorname{Pr}(S=1 \mid X)} \right\rvert\, S=1\right] \tag{MainEq.4}
\end{align*}
$$

where again, the observed data functionals are well defined under (i) and (ii).

## B Additional Simulation Results

Table B1: Simulation results comparing different analytic methods for calculating the population average controlled difference (ACD) for $A$ on $Y$ across different data generating mechanism settings. Results presented are the estimated ACD, percent bias, analytic standard error (SE), Monte Carlo standard error, mean squared error (MSE) and coverage probability over 200 subsamples for each setting
| Method | True ACD | Estimated ACD | Percent Bias | Analytic SE | Monte Carlo SE | MSE | Coverage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Setting 1: $\tau_{X}=0, \beta_{A}=0, \beta_{X}=0$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.096 | 1.101 | 0.471 | 0.068 | 0.069 | 0.477 | 0.925 |
| Simple Regression | 1.096 | 1.098 | 0.166 | 0.097 | 0.105 | 1.103 | 0.930 |
| Multiple Regression | 1.096 | 1.101 | 0.450 | 0.068 | 0.070 | 0.484 | 0.915 |
| IPTW Estimator | 1.096 | 1.101 | 0.475 | 0.068 | 0.070 | 0.484 | 0.920 |
| Survey-Weighted Multiple Regression | 1.096 | 1.102 | 0.536 | 0.068 | 0.069 | 0.481 | 0.930 |
| IPTW Multiple Regression | 1.096 | 1.101 | 0.453 | 0.060 | 0.070 | 0.484 | 0.880 |
| IPTW + Survey-Weighted Multiple Regression | 1.096 | 1.102 | 0.538 | 0.060 | 0.069 | 0.482 | 0.875 |
| Weighted IPTW + Survey-Weighted Multiple Regression | 1.096 | 1.102 | 0.538 | 0.060 | 0.069 | 0.482 | 0.875 |
| Naive G-Computation | 1.096 | 0.992 | -9.478 | 0.030 | 0.102 | 2.111 | 0.290 |
| Outcome Modeling and Direct Standardization | 1.096 | 1.090 | -0.523 | 0.067 | 0.069 | 0.476 | 0.920 |
| Inverse Probability Weighting 1 | 1.096 | 1.089 | -0.647 | 0.068 | 0.069 | 0.480 | 0.925 |
| Inverse Probability Weighting 2 | 1.096 | 1.091 | -0.499 | 0.067 | 0.069 | 0.475 | 0.920 |
| Setting 2: $\tau_{X}=1, \beta_{A}=0, \beta_{X}=0$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.090 | 1.079 | -0.989 | 0.066 | 0.067 | 0.452 | 0.930 |
| Simple Regression | 1.090 | 1.957 | 79.480 | 0.083 | 0.076 | 75.638 | 0.000 |
| Multiple Regression | 1.090 | 1.079 | -0.977 | 0.066 | 0.067 | 0.455 | 0.925 |
| IPTW Estimator | 1.090 | 1.071 | -1.793 | 0.094 | 0.107 | 1.176 | 0.930 |
| Survey-Weighted Multiple Regression | 1.090 | 1.080 | -0.886 | 0.066 | 0.068 | 0.468 | 0.925 |
| IPTW Multiple Regression | 1.090 | 1.077 | -1.246 | 0.060 | 0.069 | 0.490 | 0.885 |
| IPTW + Survey-Weighted Multiple Regression | 1.090 | 1.078 | -1.131 | 0.060 | 0.070 | 0.506 | 0.890 |
| Weighted IPTW + Survey-Weighted Multiple Regression | 1.090 | 1.078 | -1.132 | 0.060 | 0.070 | 0.506 | 0.885 |
| Naive G-Computation | 1.090 | 0.969 | -11.125 | 0.029 | 0.089 | 2.268 | 0.180 |
| Outcome Modeling and Direct Standardization | 1.090 | 1.069 | -1.935 | 0.065 | 0.066 | 0.480 | 0.930 |
| Inverse Probability Weighting 1 | 1.090 | 1.060 | -2.778 | 0.093 | 0.106 | 1.220 | 0.925 |
| Inverse Probability Weighting 2 | 1.090 | 1.060 | -2.742 | 0.093 | 0.106 | 1.204 | 0.925 |
| Setting 3: $\tau_{X}=0, \beta_{A}=1, \beta_{X}=0$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.100 | 1.096 | -0.422 | 0.050 | 0.047 | 0.220 | 0.960 |
| Simple Regression | 1.100 | 1.099 | -0.138 | 0.073 | 0.074 | 0.547 | 0.945 |
| Multiple Regression | 1.100 | 1.096 | -0.418 | 0.050 | 0.047 | 0.223 | 0.965 |
| IPTW Estimator | 1.100 | 1.096 | -0.421 | 0.050 | 0.047 | 0.223 | 0.965 |
| Survey-Weighted Multiple Regression | 1.100 | 1.096 | -0.417 | 0.056 | 0.047 | 0.222 | 0.990 |
| IPTW Multiple Regression | 1.100 | 1.096 | -0.417 | 0.050 | 0.047 | 0.223 | 0.965 |
| IPTW + Survey-Weighted Multiple Regression | 1.100 | 1.096 | -0.416 | 0.056 | 0.047 | 0.222 | 0.990 |


| Weighted IPTW + Survey-Weighted Multiple Regression | 1.100 | 1.096 | -0.417 | 0.050 | 0.047 | 0.222 | 0.970 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Naive G-Computation | 1.100 | 0.998 | -9.341 | 0.025 | 0.073 | 1.589 | 0.230 |
| Outcome Modeling and Direct Standardization | 1.100 | 1.084 | -1.495 | 0.051 | 0.047 | 0.242 | 0.955 |
| Inverse Probability Weighting 1 | 1.100 | 1.098 | -0.217 | 0.051 | 0.047 | 0.219 | 0.965 |
| Inverse Probability Weighting 2 | 1.100 | 1.084 | -1.497 | 0.051 | 0.047 | 0.243 | 0.955 |
| Setting 4: $\tau_{X}=1, \beta_{A}=0, \beta_{X}=1$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.106 | 1.102 | -0.419 | 0.055 | 0.058 | 0.342 | 0.905 |
| Simple Regression | 1.106 | 1.972 | 78.249 | 0.070 | 0.069 | 75.408 | 0.000 |
| Multiple Regression | 1.106 | 1.121 | 1.377 | 0.058 | 0.062 | 0.404 | 0.915 |
| IPTW Estimator | 1.106 | 1.123 | 1.487 | 0.103 | 0.105 | 1.129 | 0.940 |
| Survey-Weighted Multiple Regression | 1.106 | 1.123 | 1.499 | 0.050 | 0.062 | 0.411 | 0.890 |
| IPTW Multiple Regression | 1.106 | 1.116 | 0.923 | 0.044 | 0.065 | 0.426 | 0.830 |
| IPTW + Survey-Weighted Multiple Regression | 1.106 | 1.118 | 1.045 | 0.050 | 0.065 | 0.430 | 0.870 |
| Weighted IPTW + Survey-Weighted Multiple Regression | 1.106 | 1.119 | 1.116 | 0.045 | 0.065 | 0.434 | 0.820 |
| Naive G-Computation | 1.106 | 0.997 | -9.867 | 0.022 | 0.070 | 1.680 | 0.175 |
| Outcome Modeling and Direct Standardization | 1.106 | 1.090 | -1.442 | 0.055 | 0.058 | 0.362 | 0.925 |
| Inverse Probability Weighting 1 | 1.106 | 1.104 | -0.210 | 0.076 | 0.081 | 0.648 | 0.940 |
| Inverse Probability Weighting 2 | 1.106 | 1.089 | -1.526 | 0.081 | 0.083 | 0.706 | 0.945 |
| Setting 5: $\tau_{X}=0, \beta_{A}=0, \beta_{X}=1$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.104 | 1.108 | 0.389 | 0.046 | 0.048 | 0.227 | 0.940 |
| Simple Regression | 1.104 | 1.209 | 9.544 | 0.048 | 0.045 | 1.311 | 0.365 |
| Multiple Regression | 1.104 | 1.205 | 9.214 | 0.034 | 0.032 | 1.135 | 0.110 |
| IPTW Estimator | 1.104 | 1.205 | 9.222 | 0.034 | 0.032 | 1.136 | 0.110 |
| Survey-Weighted Multiple Regression | 1.104 | 1.205 | 9.236 | 0.046 | 0.045 | 1.239 | 0.355 |
| IPTW Multiple Regression | 1.104 | 1.205 | 9.214 | 0.030 | 0.032 | 1.135 | 0.090 |
| IPTW + Survey-Weighted Multiple Regression | 1.104 | 1.205 | 9.209 | 0.041 | 0.045 | 1.235 | 0.270 |
| Weighted IPTW + Survey-Weighted Multiple Regression | 1.104 | 1.205 | 9.182 | 0.040 | 0.045 | 1.225 | 0.265 |
| Naive G-Computation | 1.104 | 1.003 | -9.119 | 0.015 | 0.074 | 1.559 | 0.135 |
| Outcome Modeling and Direct Standardization | 1.104 | 1.090 | -1.252 | 0.048 | 0.047 | 0.236 | 0.935 |
| Inverse Probability Weighting 1 | 1.104 | 1.100 | -0.302 | 0.057 | 0.054 | 0.291 | 0.945 |
| Inverse Probability Weighting 2 | 1.104 | 1.099 | -0.448 | 0.058 | 0.057 | 0.325 | 0.955 |
| Setting 6: $\tau_{X}=1, \beta_{A}=0, \beta_{X}=1$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.096 | 1.096 | -0.018 | 0.041 | 0.042 | 0.176 | 0.935 |
| Simple Regression | 1.096 | 2.004 | 82.816 | 0.044 | 0.043 | 82.577 | 0.000 |
| Multiple Regression | 1.096 | 1.184 | 8.045 | 0.036 | 0.036 | 0.904 | 0.310 |
| IPTW Estimator | 1.096 | 1.222 | 11.486 | 0.058 | 0.054 | 1.874 | 0.440 |
| Survey-Weighted Multiple Regression | 1.096 | 1.189 | 8.485 | 0.044 | 0.059 | 1.207 | 0.425 |
| IPTW Multiple Regression | 1.096 | 1.185 | 8.115 | 0.030 | 0.037 | 0.927 | 0.220 |
| IPTW + Survey-Weighted Multiple Regression | 1.096 | 1.182 | 7.881 | 0.040 | 0.048 | 0.972 | 0.440 |
| Weighted IPTW + Survey-Weighted Multiple Regression | 1.096 | 1.182 | 7.847 | 0.040 | 0.047 | 0.958 | 0.435 |
| Naive G-Computation | 1.096 | 0.999 | -8.879 | 0.015 | 0.065 | 1.370 | 0.130 |
| Outcome Modeling and Direct Standardization | 1.096 | 1.079 | -1.514 | 0.044 | 0.041 | 0.197 | 0.950 |
| Inverse Probability Weighting 1 | 1.096 | 1.083 | -1.209 | 0.066 | 0.072 | 0.540 | 0.940 |


| Inverse Probability Weighting 2 | 1.096 | 1.089 | -0.633 | 0.066 | 0.070 | 0.490 | 0.935 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Setting 7: $\tau_{X}=0, \beta_{A}=1, \beta_{X}=1$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.102 | 1.102 | 0.073 | 0.035 | 0.034 | 0.115 | 0.975 |
| Simple Regression | 1.102 | 1.058 | -3.992 | 0.036 | 0.034 | 0.309 | 0.805 |
| Multiple Regression | 1.102 | 1.175 | 6.701 | 0.026 | 0.025 | 0.605 | 0.190 |
| IPTW Estimator | 1.102 | 1.174 | 6.580 | 0.026 | 0.025 | 0.587 | 0.210 |
| Survey-Weighted Multiple Regression | 1.102 | 1.177 | 6.809 | 0.038 | 0.031 | 0.661 | 0.510 |
| IPTW Multiple Regression | 1.102 | 1.175 | 6.698 | 0.026 | 0.025 | 0.605 | 0.190 |
| IPTW + Survey-Weighted Multiple Regression | 1.102 | 1.176 | 6.793 | 0.037 | 0.032 | 0.663 | 0.455 |
| Weighted IPTW + Survey-Weighted Multiple Regression | 1.102 | 1.177 | 6.808 | 0.034 | 0.031 | 0.658 | 0.385 |
| Naive G-Computation | 1.102 | 1.017 | -7.688 | 0.013 | 0.054 | 1.009 | 0.135 |
| Outcome Modeling and Direct Standardization | 1.102 | 1.086 | -1.405 | 0.038 | 0.033 | 0.135 | 0.970 |
| Inverse Probability Weighting 1 | 1.102 | 1.100 | -0.172 | 0.043 | 0.042 | 0.178 | 0.970 |
| Inverse Probability Weighting 2 | 1.102 | 1.076 | -2.322 | 0.044 | 0.045 | 0.265 | 0.910 |
| Setting 8: $\tau_{X}=1, \beta_{A}=1, \beta_{X}=1$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.104 | 1.101 | -0.209 | 0.034 | 0.033 | 0.106 | 0.970 |
| Simple Regression | 1.104 | 1.919 | 73.914 | 0.040 | 0.037 | 66.681 | 0.000 |
| Multiple Regression | 1.104 | 1.210 | 9.640 | 0.034 | 0.032 | 1.234 | 0.130 |
| IPTW Estimator | 1.104 | 1.172 | 6.226 | 0.070 | 0.066 | 0.904 | 0.835 |
| Survey-Weighted Multiple Regression | 1.104 | 1.200 | 8.727 | 0.033 | 0.063 | 1.321 | 0.300 |
| IPTW Multiple Regression | 1.104 | 1.212 | 9.830 | 0.022 | 0.031 | 1.273 | 0.015 |
| IPTW + Survey-Weighted Multiple Regression | 1.104 | 1.207 | 9.378 | 0.031 | 0.034 | 1.188 | 0.130 |
| Weighted IPTW + Survey-Weighted Multiple Regression | 1.104 | 1.205 | 9.214 | 0.030 | 0.041 | 1.204 | 0.160 |
| Naive G-Computation | 1.104 | 0.986 | -10.660 | 0.011 | 0.053 | 1.669 | 0.040 |
| Outcome Modeling and Direct Standardization | 1.104 | 1.087 | -1.531 | 0.038 | 0.032 | 0.131 | 0.970 |
| Inverse Probability Weighting 1 | 1.104 | 1.115 | 1.015 | 0.050 | 0.051 | 0.274 | 0.950 |
| Inverse Probability Weighting 2 | 1.104 | 1.083 | -1.907 | 0.047 | 0.047 | 0.267 | 0.935 |


Table B2: Sensitivity analysis simulation results comparing the proposed methods to the oracle estimator in terms of bias, mean squared error, and coverage across different treatment heterogeneity levels (size of $\gamma_{A X}$ in the true data generating mechanism. Results are averaged over 200 independent sub-samplings from a super population of 100,000 individuals where all other simulation settings match that of Setting 8 in the main text. Results for OM are presented where the outcome model is correctly specified versus misspecified. ACD: Average Controlled Difference; SE: Standard Error; MSE: Mean Squared Error.
| Method | True ACD | Estimated ACD | Bias | Analytic SE | Monte Carlo SE | MSE | Coverage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Setting 1: $\gamma_{A X}=0$ |  |  |  |  |  |  |  |
| Oracle Estimator | 0.996 | 0.985 | -0.011 | 0.034 | 0.035 | 0.001 | 0.920 |
| Outcome Modeling and Direct Standardization | 0.996 | 0.971 | -0.026 | 0.038 | 0.035 | 0.002 | 0.885 |
| Outcome Modeling and Direct Standardization, Misspecified | 0.996 | 0.968 | -0.028 | 0.034 | 0.030 | 0.002 | 0.900 |
| Inverse Probability Weighting 1 | 0.996 | 0.983 | -0.014 | 0.051 | 0.052 | 0.003 | 0.950 |
| Inverse Probability Weighting 2 | 0.996 | 0.956 | -0.041 | 0.046 | 0.045 | 0.004 | 0.835 |
| Setting 2: $\gamma_{A X}=0.01$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.000 | 0.991 | -0.009 | 0.034 | 0.033 | 0.001 | 0.960 |
| Outcome Modeling and Direct Standardization | 1.000 | 0.976 | -0.024 | 0.038 | 0.032 | 0.002 | 0.940 |
| Outcome Modeling and Direct Standardization, Misspecified | 1.000 | 0.983 | -0.017 | 0.034 | 0.028 | 0.001 | 0.970 |
| Inverse Probability Weighting 1 | 1.000 | 0.992 | -0.008 | 0.050 | 0.052 | 0.003 | 0.935 |
| Inverse Probability Weighting 2 | 1.000 | 0.955 | -0.045 | 0.047 | 0.050 | 0.004 | 0.825 |
| Setting 3: $\gamma_{A X}=0.05$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.050 | 1.051 | 0.001 | 0.034 | 0.030 | 0.001 | 0.970 |
| Outcome Modeling and Direct Standardization | 1.050 | 1.035 | -0.015 | 0.038 | 0.029 | 0.001 | 0.965 |
| Outcome Modeling and Direct Standardization, Misspecified | 1.050 | 1.059 | 0.008 | 0.035 | 0.026 | 0.001 | 0.985 |
| Inverse Probability Weighting 1 | 1.050 | 1.041 | -0.009 | 0.051 | 0.048 | 0.002 | 0.955 |
| Inverse Probability Weighting 2 | 1.050 | 1.012 | -0.037 | 0.046 | 0.043 | 0.003 | 0.870 |
| Setting 4: $\gamma_{A X}=0.1$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.106 | 1.098 | -0.008 | 0.034 | 0.034 | 0.001 | 0.950 |
| Outcome Modeling and Direct Standardization | 1.106 | 1.082 | -0.022 | 0.038 | 0.033 | 0.002 | 0.925 |
| Outcome Modeling and Direct Standardization, Misspecified | 1.106 | 1.130 | 0.021 | 0.036 | 0.030 | 0.001 | 0.930 |
| Inverse Probability Weighting 1 | 1.106 | 1.102 | -0.003 | 0.050 | 0.047 | 0.002 | 0.965 |
| Inverse Probability Weighting 2 | 1.106 | 1.070 | -0.033 | 0.047 | 0.044 | 0.003 | 0.880 |
| Setting 5: $\gamma_{A X}=0.5$ |  |  |  |  |  |  |  |
| Oracle Estimator | 1.501 | 1.489 | -0.008 | 0.035 | 0.031 | 0.001 | 0.960 |
| Outcome Modeling and Direct Standardization | 1.501 | 1.470 | -0.020 | 0.037 | 0.034 | 0.002 | 0.895 |
| Outcome Modeling and Direct Standardization, Misspecified | 1.501 | 1.720 | 0.146 | 0.041 | 0.029 | 0.049 | 0.000 |
| Inverse Probability Weighting 1 | 1.501 | 1.497 | -0.002 | 0.050 | 0.053 | 0.003 | 0.925 |
| Inverse Probability Weighting 2 | 1.501 | 1.467 | -0.023 | 0.048 | 0.047 | 0.003 | 0.900 |


What's the Weight?

## C Additional Data Example Results

## C. 1 Main Analysis of Race, SES, and Telomere Length

Table C1: Results from our (a) unweighted and (b) survey-weighted 'propensity for race' models. Propensity scores were constructed by fitting a logistic regression of self-reported race (Black $=1$, White $=0$ ) on twelve socioeconomic covariates. Results presented are the odds ratios (OR), corresponding 95\% confidence intervals (95\% CI) and $p$-values. Em-dashes (-) denote the reference group.
| Characteristic | a. Unweighted |  |  | b. Survey-Weighted |  |  |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
|  | OR ${ }^{1}$ | 95\% CI ${ }^{1}$ | $\mathbf{p}$-value | OR ${ }^{1}$ | $\mathbf{9 5 \%} \mathbf{C I}^{l}$ | $\mathbf{p}$-value |
| Education |  |  |  |  |  |  |
| High School or GED | - | - |  | - | - |  |
| Some College | 0.75 | 0.64, 0.89 | <0.001 | 0.80 | 0.67, 0.96 | 0.016 |
| College Graduate | 0.49 | 0.39, 0.61 | <0.001 | 0.49 | 0.38, 0.62 | <0.001 |
| Refused/Unknown | 0.96 | 0.12, 5.42 | >0.9 | 0.29 | 0.02, 3.60 | 0.3 |
| Marital Status |  |  |  |  |  |  |
| Never Married | - | - |  | - | - |  |
| Widowed/Divorced/Separated | 0.93 | 0.75, 1.16 | 0.5 | 0.88 | 0.69, 1.12 | 0.3 |
| Married/Living with Partner | 0.43 | 0.35, 0.52 | <0.001 | 0.41 | 0.33, 0.50 | <0.001 |
| Refused/Unknown | 0.70 | 0.49, 1.01 | 0.057 | 0.82 | 0.54, 1.23 | 0.3 |
| Household Size |  |  |  |  |  |  |
| 1 Person | - | - |  | - | - |  |
| 2 People | 1.41 | 1.11, 1.80 | 0.006 | 1.33 | 1.00, 1.77 | 0.049 |
| 3 People | 2.55 | 1.95, 3.33 | <0.001 | 2.27 | 1.66, 3.10 | <0.001 |
| 4 People | 2.51 | 1.88, 3.36 | <0.001 | 2.18 | 1.57, 3.03 | <0.001 |
| 5+ People | 3.90 | 2.87, 5.29 | <0.001 | 3.51 | 2.49, 4.94 | <0.001 |
| Household Income <br> 0 - \$20,000 <br> - <br> - <br> - <br> - |  |  |  |  |  |  |
| \$20,000 - \$35,000 | 1.13 | 0.88, 1.45 | 0.3 | 1.04 | 0.77, 1.41 | 0.8 |
| \$35,000 - \$55,000 | 0.81 | 0.60, 1.10 | 0.2 | 0.72 | 0.51, 1.02 | 0.065 |
| \$55,000 - \$75,000 | 0.70 | 0.49, 1.02 | 0.062 | 0.64 | 0.42, 0.98 | 0.041 |
| \$75,000+ | 0.67 | 0.45, 0.98 | 0.040 | 0.65 | 0.40, 1.04 | 0.069 |
| Refused/Unknown | 1.89 | 1.22, 2.94 | 0.005 | 1.83 | 1.10, 3.04 | 0.020 |
| Poverty-Income Ratio Category <br> < 1.3 <br> - <br> - <br> - <br> - |  |  |  |  |  |  |
| $1.3 \leq$ PIR < 3.5 | 0.96 | 0.76, 1.21 | 0.7 | 0.99 | 0.75, 1.30 | >0.9 |
| $\geq 3.5$ | 0.90 | 0.64, 1.26 | 0.5 | 0.83 | 0.56, 1.24 | 0.4 |
| Refused/Unknown | 0.65 | 0.40, 1.05 | 0.078 | 0.60 | 0.35, 1.03 | 0.062 |
| Employment Status |  |  |  |  |  |  |
| Full-Time | - | - |  | - | - |  |
| Part-Time | 0.77 | 0.54, 1.08 | 0.13 | 0.80 | 0.55, 1.16 | 0.2 |
| Retired | 0.73 | 0.55, 0.97 | 0.034 | 0.74 | 0.54, 1.01 | 0.058 |
| Not Working | 0.84 | 0.62, 1.13 | 0.3 | 0.90 | 0.64, 1.28 | 0.6 |
| Refused/Unknown | 0.68 | 0.45, 1.04 | 0.070 | 1.01 | 0.63, 1.62 | >0.9 |
| Occupation Category |  |  |  |  |  |  |
| No Work | - | - |  | - | - |  |
| Low Blue Collar | 1.11 | 0.57, 2.18 | 0.8 | 1.37 | 0.66, 2.84 | 0.4 |
| High Blue Collar | 0.73 | 0.35, 1.53 | 0.4 | 0.90 | 0.41, 2.00 | 0.8 |
| Low White Collar | 0.87 | 0.44, 1.76 | 0.7 | 1.29 | 0.61, 2.74 | 0.5 |
| High White Collar | 0.73 | 0.36, 1.49 | 0.4 | 1.04 | 0.48, 2.26 | >0.9 |
| Refused/Unknown | 1.12 | 0.53, 2.40 | 0.8 | 1.26 | 0.55, 2.86 | 0.6 |
| WIC Utilization |  |  |  |  |  |  |
| No WIC | - | - |  | - | - |  |
| Received WIC | 1.20 | 0.93, 1.55 | 0.2 | 1.24 | 0.92, 1.68 | 0.2 |
| Refused/Unknown | 2.39 | 0.73, 8.75 | 0.2 | 1.92 | 0.56, 6.59 | 0.3 |
| Food Security Status |  |  |  |  |  |  |


| Food Secure | - | - |  | - | - |  |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Marginally Food Secure | 1.80 | 1.36, 2.38 | <0.001 | 2.18 | 1.59, 2.99 | <0.001 |
| Food Insecure | 1.40 | 1.10, 1.79 | 0.006 | 1.46 | 1.12, 1.92 | 0.006 |
| Refused/Unknown | 1.58 | 1.07, 2.31 | 0.020 | 1.72 | 1.10, 2.69 | 0.017 |
| Home Type |  |  |  |  |  |  |
| Family Home Detached | - | - |  | - | - |  |
| Family Home Attached | 1.46 | 1.14, 1.86 | 0.002 | 1.55 | 1.19, 2.01 | 0.001 |
| Apartment | 2.23 | 1.78, 2.81 | <0.001 | 2.35 | 1.82, 3.04 | <0.001 |
| Other | 0.68 | 0.53, 0.88 | 0.004 | 0.85 | 0.65, 1.11 | 0.2 |
| Refused/Unknown | 1.45 | 0.18, 13.0 | 0.7 | 2.39 | 0.00, 2,519 | 0.8 |
| Home Ownership |  |  |  |  |  |  |
| Does Not Own Home | - | - |  | - | - |  |
| Owns Home | 0.79 | 0.65, 0.97 | 0.023 | 0.77 | 0.63, 0.95 | 0.017 |
| Refused/Unknown | 0.14 | 0.01, 1.23 | 0.090 | 0.04 | 0.00, 128 | 0.4 |
| Insurance Status |  |  |  |  |  |  |
| Not Insured | - | - |  | - | - |  |
| Insured | 1.03 | 0.84, 1.25 | 0.8 | 1.08 | 0.87, 1.34 | 0.5 |
| Refused/Unknown | 2.22 | 0.56, 9.78 | 0.3 | 4.21 | 0.88, 20.2 | 0.072 |

${ }^{1}$ OR = Odds Ratio, CI = Confidence Interval

## C. 2 Supplemental Analysis of Lead Exposure, SES, and Telomere Length

Table C2: Population Average Treatment Effect (PATE) estimates and corresponding 95\% confidence intervals across various analytic approaches for the comparison of effect of lead exposure (high versus low exposure, dichotomized at median $\mu \mathrm{g} / \mathrm{dL}$ ) on log-transformed telomere length among $n=5,267$ participants in the National Health and Nutrition Examination Survey (NHANES). IPTW: Inverse Probability of Treatment Weighting.

| Method | PATE Estimate | 95\% Confidence Interval |
| :--- | :--- | :--- |
| Multiple Regression | 0.0002 | -0.0139, 0.0142 |
| IPTW Estimator | -0.0478 | -0.0800, -0.0156 |
| IPTW Estimator w/ Race in Propensity Model | -0.0504 | -0.0809, -0.0199 |
| Survey-Weighted Multiple Regression | -0.0032 | -0.0229, 0.0165 |
| IPTW Multiple Regression | -0.0024 | -0.0157, 0.0109 |
| IPTW Multiple Regression w/ Race in Propensity Model | -0.0029 | -0.0161, 0.0103 |
| IPTW + Survey-Weighted Multiple Regression | -0.0051 | -0.0250, 0.0149 |
| IPTW + Survey-Weighted Multiple Regression w/ Race in Propensity Model | -0.0053 | -0.0255, 0.0149 |
| Weighted IPTW + Survey-Weighted Multiple Regression | -0.0049 | -0.0253, 0.0155 |
| Weighted IPTW + Survey-Weighted Multiple Regression w/ Race in Propensity Model | -0.0052 | -0.0257, 0.0153 |
| Proposed OM | 0.0001 | -0.0121, 0.0123 |
| Proposed OM w/ Race in Propensity Model | 0.0001 | -0.0121, 0.0123 |
| Proposed IPW1 | -0.0358 | -0.0469, -0.0248 |
| Proposed IPW1 w/ Race in Propensity Model | -0.0368 | -0.0479, -0.0257 |
| Proposed IPW2 | -0.0328 | -0.0433, -0.0223 |
| Proposed IPW2 w/ Race in Propensity Model | -0.0332 | -0.0440, -0.0224 |


[^0]:    ${ }^{*}$ Citation: Authors. Title. Pages.... DOI:000000/11111.

