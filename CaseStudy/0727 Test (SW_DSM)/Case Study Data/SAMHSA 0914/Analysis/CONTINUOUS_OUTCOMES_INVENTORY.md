# NSDUH Continuous Outcomes Inventory for Causal Analysis

**Date**: October 23, 2025  
**Purpose**: Identify all continuous outcome variables suitable for matching methods analysis

---

## ✅ **CRITERIA FOR INCLUSION**

1. **Outcome**: Continuous measure (NOT binary, NOT survival)
2. **Treatment/Exposure**: Binary variable
3. **Data availability**: Sufficient sample size in NSDUH
4. **Research relevance**: Published literature exists or high public health importance

---

## 📊 **CONTINUOUS OUTCOME CATEGORIES IN NSDUH**

### **1. SUBSTANCE USE FREQUENCY (Number of Days)**

#### **Alcohol Use**
- `ALCDAYS` - Past year alcohol use days
- `ALCYDAYS` - Past year alcohol use days (alternative coding)
- `ALCMDAYS` - Past month alcohol use days
- `BNGDRMDAYS` - Past month binge drinking days

#### **Cannabis/Marijuana**
- `MRJYDAYS` - Past year marijuana use days
- `MRJMDAYS` - Past month marijuana use days

#### **Other Drugs**
- `COCYDAYS` - Past year cocaine use days
- `COCMDAYS` - Past month cocaine use days
- `CRKYDAYS` - Past year crack use days
- `CRKMDAYS` - Past month crack use days
- `HERYDAYS` - Past year heroin use days
- `HERMDAYS` - Past month heroin use days

#### **Tobacco**
- `CIGMDAYS` - Past month cigarette use days
- `CGRMDAYS` - Past month cigar use days
- `SMKLSMDAYS` - Past month smokeless tobacco days
- `NICVPMDAYS` - Past month nicotine vaping days

#### **Pain Relievers & Other**
- `ADPSDAYS` - Past year pain reliever misuse days
- `YOPSDAYS` - Past year other prescription drug misuse days

---

### **2. MENTAL HEALTH TREATMENT & SERVICE USE**

- `MHTRTPY` - Mental health treatment past year (count/frequency measure)
- `MHTRTOTHPY` - Other mental health treatment past year

---

### **3. COUNT/FREQUENCY MEASURES**

- `ALCNUMDKPM` - Average number of drinks per day when drinking
- `WRKNUMJOB2` - Number of jobs worked

---

## 🎯 **PROMISING RESEARCH QUESTIONS**

### **HIGH PRIORITY: Days-Based Outcomes**

#### **Research Question 1: Gender Differences in Substance Use Intensity**
- **Outcome**: Days of alcohol/marijuana/cocaine use (past month or year)
- **Treatment**: Binary gender (male vs. female)
- **Rationale**: 
  - Binary outcomes (ever used) miss intensity differences
  - Days used captures severity of use
  - Clinical/treatment relevance

#### **Research Question 2: SUD Diagnosis Effect on Substance Use Frequency**
- **Outcome**: Days of specific drug use
- **Treatment**: Having any SUD diagnosis vs. none
- **Rationale**:
  - Understanding if formal diagnosis relates to use patterns
  - Treatment seeking behavior

#### **Research Question 3: Mental Health Treatment Effect on Substance Use**
- **Outcome**: Days of substance use (alcohol, marijuana, etc.)
- **Treatment**: Received mental health treatment vs. not
- **Rationale**:
  - Co-occurring disorders common
  - Treatment effectiveness

#### **Research Question 4: Insurance Status Effect on Substance Use Patterns**
- **Outcome**: Days of substance use
- **Treatment**: Insured vs. uninsured
- **Rationale**:
  - Healthcare access and substance use
  - Policy implications

#### **Research Question 5: Employment Status and Drinking Intensity**
- **Outcome**: Number of drinks per occasion or binge drinking days
- **Treatment**: Employed vs. unemployed
- **Rationale**:
  - Economic stress and substance use
  - Workplace intervention relevance

---

## 🔍 **NEED TO INVESTIGATE**

### **Questions for Codebook Review**:

1. **K6 Score**: Does NSDUH have the total K6 psychological distress score (0-24 scale)?
   - We have `PSYCHFLAG`, `PSYCHYR`, `PSYCHMON` but need continuous score
   - K6 is a validated continuous measure of mental distress

2. **Depression Scales**: Any PHQ-9 or other depression severity scores?

3. **Anxiety Scales**: Any GAD-7 or anxiety severity measures?

4. **Quality of Life**: Any continuous health status measures?

5. **Pain Scales**: Any pain severity or interference scores?

---

## 📚 **SEARCH STRATEGY FOR PUBLICATIONS**

### **Step 1: NSDUH-Specific Literature**
Search for publications using:
- "NSDUH" + "days of use" + specific drug
- "NSDUH" + "frequency" + "substance use"
- "NSDUH" + "intensity" + substance type
- "NSDUH" + continuous measure name

### **Step 2: Methodological Papers**
Look for papers that:
- Use propensity score matching with continuous outcomes
- Analyze substance use frequency (not just prevalence)
- Examine dose-response relationships

### **Step 3: Public Health Relevance**
Focus on questions with:
- Health equity implications
- Treatment/intervention relevance
- Policy implications
- Gender/racial disparities

---

## 🚀 **NEXT ACTIONS**

1. **Check NSDUH codebook** for K6 total score variable
2. **Web search** for NSDUH publications using continuous outcomes
3. **Review** existing documentation for any identified publications
4. **Create** ranked list of research questions by:
   - Data availability
   - Publication precedent
   - Public health importance
   - Methodological fit

---

## 📋 **PRELIMINARY RANKING (To Be Refined)**

### **Tier 1: Ready to Analyze**
- Gender → Alcohol use days (past month/year)
- Gender → Marijuana use days
- Gender → Binge drinking days
- Employment → Substance use frequency
- Insurance → Substance use frequency

### **Tier 2: Pending Variable Confirmation**
- Treatment → K6 psychological distress score (if available)
- SUD diagnosis → Mental health severity score

### **Tier 3: Exploratory**
- Various binary treatments → Multiple substance frequency outcomes
- Policy-relevant exposures → Use intensity

---

**STATUS**: Inventory complete, now proceeding to literature search and codebook review
