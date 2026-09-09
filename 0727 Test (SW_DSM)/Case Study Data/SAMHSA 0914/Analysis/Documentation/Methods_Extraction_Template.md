# Publication Methods Extraction Template

**Use this template for each candidate publication to assess replicability**

---

## Publication Information

**Citation**: [Full citation]  
**Authors**: [List authors]  
**Journal**: [Journal name]  
**Year**: [Publication year]  
**DOI/Link**: [URL if available]  
**NSDUH Year(s) Used**: [e.g., 2019, 2015-2019 pooled]

---

## Initial Screening

**Uses NSDUH Public Use File?** ☐ Yes ☐ No ☐ Unclear  
**Uses Causal Inference Methods?** ☐ Yes ☐ No ☐ Unclear  
**Methods Section Detail Level**: ☐ Excellent ☐ Good ☐ Fair ☐ Poor  
**Proceed with Full Extraction?** ☐ Yes ☐ No

---

## Research Question

**Primary Research Question**: [Exact wording if possible]

**Treatment/Exposure**: [What is being compared?]

**Outcome(s)**: [Primary and secondary outcomes]

**Population**: [Who is being studied?]

**Study Design**: [Cross-sectional, retrospective cohort, etc.]

---

## Sample Selection

### Inclusion Criteria
1. [List each criterion]
2. 
3. 

### Exclusion Criteria
1. [List each criterion]
2. 
3. 

### Age Restrictions
- Age range: [e.g., 18-25, 12+, etc.]
- Specific age variable used: [e.g., CATAG7, AGE2, etc.]

### Final Analytic Sample Size
- N total: [Number]
- N treatment/exposed: [Number]
- N control/unexposed: [Number]

---

## Variable Definitions

### Treatment/Exposure Variable
- **Variable name(s)**: [Exact NSDUH variable name(s)]
- **Coding**: [How was it operationalized?]
- **Categories**: [Binary? Ordinal? Categories?]
- **Example**: Past year marijuana use (MRJFLAG=1 vs MRJFLAG=0)

### Primary Outcome Variable
- **Variable name(s)**: [Exact NSDUH variable name(s)]
- **Coding**: [How was it measured?]
- **Type**: ☐ Binary ☐ Continuous ☐ Count ☐ Ordinal
- **Example**: Major depressive episode (MDEIMPY=1 vs MDEIMPY=2)

### Covariates/Confounders

| Covariate Name | NSDUH Variable | Coding | Missing Data Handling |
|----------------|----------------|--------|----------------------|
| Age | [e.g., CATAG7] | [e.g., 7 categories] | [e.g., No missing] |
| Sex | | | |
| Race/Ethnicity | | | |
| Education | | | |
| Income | | | |
| [Add rows] | | | |

**Total number of covariates**: [Number]

---

## Missing Data Handling

**Overall approach**: [Complete case? Multiple imputation? Weighted?]

**Variables with missing data**:
1. [Variable name]: [% missing] → [How handled?]
2. 
3. 

**Final sample after handling missing data**: [N]

---

## Survey Weights

**Were survey weights used?** ☐ Yes ☐ No ☐ Unclear

**If YES:**
- **Weight variable used**: [e.g., ANALWT2_C]
- **Variance estimation method**: [e.g., Taylor series, BRR, jackknife]
- **Strata variable**: [e.g., VESTR_C]
- **Cluster/PSU variable**: [e.g., VEREP]
- **Software used for weighted analysis**: [e.g., survey package in R, SAS PROC SURVEYMEANS]

**If NO:**
- **Rationale given**: [If any]

---

## Statistical Methods

### Primary Analysis Method
**Method**: [e.g., Propensity Score Matching, Logistic Regression, IPW]

**Detailed Description**:
- Algorithm: [e.g., 1:1 nearest neighbor matching with caliper 0.2 SD]
- Propensity score model: [If applicable - list all variables]
- Outcome model: [If applicable - list all variables]
- Standard error estimation: [e.g., Robust, bootstrapped, survey-adjusted]

### Propensity Score Specification (if applicable)
**Model form**: 
```
Treatment ~ [list all covariates + any interactions]
```

**Link function**: ☐ Logit ☐ Probit ☐ Other: ________

**Assessment of overlap**: ☐ Yes (described) ☐ No ☐ Unclear

**Balance checking**: ☐ Yes (described) ☐ No ☐ Unclear

### Matching Details (if applicable)
- **Matching algorithm**: [e.g., nearest neighbor, optimal, full]
- **Matching ratio**: [e.g., 1:1, 1:k, full]
- **Caliper**: [e.g., 0.2 SD of logit PS]
- **Replacement**: ☐ With ☐ Without
- **Common support restriction**: ☐ Yes ☐ No

### Outcome Analysis
**Estimand**: ☐ ATE ☐ ATT ☐ Other: ________

**Model type**: [e.g., Logistic regression, Linear regression, None (simple mean difference)]

**Outcome model specification**:
```
Outcome ~ Treatment + [any covariates in outcome model]
```

**Confidence interval construction**: [e.g., Wald, Bootstrap, Survey-adjusted]

---

## Main Results Reported

### Primary Effect Estimate
- **Effect measure**: [e.g., OR, RR, Risk Difference, Mean Difference]
- **Point estimate**: [Value]
- **95% CI**: [Lower, Upper]
- **P-value**: [Value or <0.05, etc.]
- **Sample size for this analysis**: [N]

### Secondary/Subgroup Results (if relevant for replication)
1. 
2. 
3. 

---

## Additional Analyses

**Sensitivity analyses performed**: 
1. [e.g., Different PS model specifications]
2. [e.g., Alternative outcome definitions]
3. 

**Subgroup analyses performed**:
1. [e.g., By age group]
2. [e.g., By sex]
3. 

---

## Replicability Assessment

### Required Information Available?

| Requirement | Available? | Notes |
|-------------|------------|-------|
| NSDUH year(s) specified | ☐ Yes ☐ No | |
| Exact variable names | ☐ Yes ☐ No | |
| Sample selection criteria | ☐ Yes ☐ No | |
| Complete covariate list | ☐ Yes ☐ No | |
| Missing data handling | ☐ Yes ☐ No | |
| Survey weight specification | ☐ Yes ☐ No | |
| Statistical method details | ☐ Yes ☐ No | |
| Effect estimates + CIs | ☐ Yes ☐ No | |
| Sample sizes | ☐ Yes ☐ No | |

### Overall Replicability Rating
☐ **Excellent** - All information available, can replicate exactly  
☐ **Good** - Most information available, minimal assumptions needed  
☐ **Fair** - Some information available, moderate assumptions needed  
☐ **Poor** - Limited information, many assumptions needed  
☐ **Insufficient** - Cannot replicate with confidence

### Specific Challenges/Uncertainties
1. [List any ambiguities or unclear aspects]
2. 
3. 

---

## Replication Plan

**Can we replicate with NSDUH 2023?** ☐ Yes ☐ Maybe ☐ No

**If NO or MAYBE, why?**
- ☐ Different NSDUH year - variables may have changed
- ☐ Missing variable definitions
- ☐ Unclear sample selection
- ☐ Unclear statistical methods
- ☐ Other: ___________

**If YES or MAYBE, what's needed?**
1. [List specific steps]
2. 
3. 

**Priority for replication**: ☐ High ☐ Medium ☐ Low

**Estimated time to replicate**: ☐ 1 day ☐ 2-3 days ☐ 1 week ☐ >1 week

---

## Notes

**Additional observations**:
[Any other relevant notes about the paper, methods, or replication considerations]

**Questions to resolve**:
1. [List any questions you need to answer before attempting replication]
2. 
3. 

**Related papers to check**:
1. [Any papers cited that might provide more methodological detail]
2. 
3. 

---

**Template completed by**: [Your name]  
**Date**: [Date]  
**Status**: ☐ Screening only ☐ Full extraction ☐ Replication attempted ☐ Replication complete



