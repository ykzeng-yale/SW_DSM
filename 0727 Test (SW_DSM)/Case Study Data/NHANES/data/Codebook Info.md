Variable Labels for NHANES 2007-2018 Dataset

seqn = respondent id number

bmxwt (weight in kg)

bmxht (height in cm)

bmxbmi (BMI)

bmxhip (hip circumference in cm)

bmxwaist (waist circumference in cm)

month_fu - Person months of follow up

year = survey year

eligstat
1 = Eligible
2 = Under 18, not available for public
3 = ineligible


heartmort (died of heart disease versus not)
0 = No
1 = Yes

cvamort (died of cerebrovascular accident versus not)
0 = No
1= Yes

mortstat (final mortality status)
0 = Assumed alive
1 = Assumed deceased


heartattack (ever had heart attack)
0 = No
1 = Yes

stroke (ever had stroke)
0 = No
1 = Yes

chd (ever had coronary heart disease)
0 = No 
1 = Yes

chf (ever had congestive heart failure)
0 = No
1 = Yes

hypertension/hypertension2 
0 = No
1 = Yes
*hypertenion2 is among people who are eligible in the mortality dataset

smokestatus/smokestatus2:
0 = Non-smoke
1 = Current or former smoker
*smokestatus2 is among people who are eligible in the mortality dataset

diabetesdx
0 = None or Borderline Diabetes
1 = Yes

diabetesdx2
0 = None
1 = Yes or Borderline Diabetes

highchol (high cholesterol)
0 = No
1 = Yes

race1:
1 "Non-Hispanic White" 
2 "Non-Hispanic Black" 
3 "Hispanic" 
4 "Other Race"

education 
1 "Less than high school" 
2 "High school graduate" 
3 "Some college" 
4 "College graduate and above"

education2 
0 "Missing" 
1 "Less than high school" 
2 "High school graduate"
3 "Some college" 
4 "College graduate and above"

female
0 = Male
1 = Female

pregnant
0 = No
1 = Yes

usborn
0 = Born outside of the US
1 = US-born

pir (poverty to income ratio)
0 "Less than 1.00" 
1 "1.00-1.99" 
2 "2.00-2.99" 
3 "3.00-3.99" 
4 "4.00-4.99" 
5 "5.00+"

pir2 
0 "Missing" 
1 "Less than 1.00"
2 "1.00-1.99" 
3 "2.00-2.99" 
4 "3.00-3.99" 
5 "4.00-4.99" 
6 "5.00+"

sleepcat (hours of sleep)
1 "Less than 7 Hours" 
2 "7 to 9 Hours" 
3 "10 hours or more"

mvpa_cat
0 = "More than 150 minutes per week"
1 = "Less than 150 minutes per week"


mvpa_week2 = minutes of moderate to vigorous physical activity per week
dashscore = DASH diet score


Mortality/adiposity code: 09/28/2025

bmxbmi
Type: Numeric
Definition: Body Mass Index (kg/m²).
Use: Obesity defined as ≥30.
Output: Included.

bmxwaist
Type: Numeric
Definition: Waist circumference (cm).
Use: Thresholds for IDF and NHLBI.
Output: Included.

bmxht
Type: Numeric
Definition: Standing height (cm).
Use: Waist-to-Height Ratio.
Output: Included.

bmxhip
Type: Numeric
Definition: Hip circumference (cm).
Use: Waist-to-Hip Ratio.
Output: Included.

ridageyr
Type: Integer
Definition: Age in years.
Use: Restricted to adults (≥18).
Output: Included.

riagendr
Type: Integer (1=Male, 2=Female)
Definition: Sex.
Use: Cutoffs for WC, WHR, DXA.
Output: Included.

ridreth3
Type: Integer
Definition: Race/ethnicity.
Use: IDF WC cutoffs (Asian vs non-Asian).
Output: Included.

DXDTOPF
Type: Numeric
Definition: Total body fat % (DXA).
Use: Male ≥30%, Female ≥42%.
Output: Included.

For all variables below, row = NA if input is NA.

WaistHeight_Ratio = bmxwaist / bmxht

Elevated_WHR = 1 if WaistHeight_Ratio ≥0.5, else 0

Elevated_DEXA = Sex-specific body fat cutoffs
Male: ≥30%; Female: ≥42%

Elevated_IDF = IDF WC thresholds
Asian men ≥90, Asian women ≥80; Non-Asian men ≥94, women ≥80

Elevated_NHLBI = NHLBI WC thresholds
Men >102, Women >88

Elevated_WHRWC = 1 if both Elevated_WHR and Elevated_NHLBI == 1

Elevated_USBMI = 1 if BMI ≥30

Elevated_BMIWC = 1 if both Elevated_USBMI and Elevated_NHLBI == 1

Elevated_BMIWHR = 1 if both Elevated_USBMI and Elevated_WHR == 1

LCC = Composite obesity indicator
1 if any of Elevated_DEXA, Elevated_WHRWC, Elevated_BMIWC == 1. Final code forces missing to 0.

WH_ratio = bmxwaist / bmxhip

Elevated_WH = Sex-specific WHR cutoffs
Male ≥0.90, Female ≥0.85




/*
NHANES SMURF Data Recoding and Combination
Purpose: To recode each dataset separately in order to combine them later
Need to make sure that our coding is aligned with previous work
AHA Essential 8 Components:
SMURFS: smoking, hypertension, diabetes, cholesterol
Demographic Factors: Age, education, poverty index, income, race
Mental Health (PHQ2)
AHA Essential 8:
1. DASH DIET - 
2. PHYSICAL ACTIVITY
3. SMOKING (A SMURF)
4. SLEEP HEALTH 
5. BMI
6. BLOOD LIPIDS (A SMURF)
7. BLOOD GLUCOSE (A SMURF)
8. BP SCORE (A SMURF)
*/

**# Changing Working Directory and Opening Up Datasets
cd "C:\Users\abacong\Box\Adrian Bacong's Files\NHIS and NHANES SMURF Project\Data"

*2003-2004
use "2003-2004 NHANES Full Data.dta", replace
save "2003-2004 NHANES Full Data.dta", replace

*2005-2006
use "2005-2006 NHANES Full Data.dta", replace
save "2005-2006 NHANES Full Data.dta", replace

*2007-2008
use "2007-2008 NHANES Full Data.dta", replace
save "2007-2008 NHANES Full Data.dta", replace

*2009-2010
use "2009-2010 NHANES Full Data.dta", replace
save "2009-2010 NHANES Full Data.dta", replace

*2011-2012
use "2011-2012 NHANES Full Data.dta", replace
save "2011-2012 NHANES Full Data.dta", replace

*2013-2014
use "2013-2014 NHANES Full Data.dta", replace
save "2013-2014 NHANES Full Data.dta", replace

*2015-2016
use "2015-2016 NHANES Full Data.dta", replace
save "2015-2016 NHANES Full Data.dta", replace

*2017-2018
use "2017-2018 NHANES Full Data.dta", replace
save "2017-2018 NHANES Full Data.dta", replace

**#Heart Disease Conditions
*Heart Attack - Done
gen heartattack = mcq160e 
recode heartattack (2=0) (7 9 = .)

*Stroke - Done
gen stroke = mcq160f 
recode stroke (2=0) (7 9 = .)

*Coronary Heart Disease - Done
gen chd = mcq160c 
recode chd (2=0) (7 9=.)

*Congestive Heart Failure - Done
gen chf = mcq160b 
recode chf (2=0) (7 9 = .)


**# SMURF Coding (Smoking, hypertension, diabetes, cholesterol)

*Hypertension - Done
gen hypertension = bpq020 
recode hypertension (2 = 0) (9=.)

gen hypertension2 = hypertension if eligstat ==1
replace hypertension2 = 0 if hypertension ==. & eligstat ==1

*Diabetes - Done
gen diabetesdx = diq010
recode diabetesdx (2 3 = 0) (7 9 = .)

gen diabetesdx2 = diq010
recode diabetesdx2 (2=0) (3=1) (7 9 = .)

gen diabetes2 = diabetesdx if eligstat ==1
replace diabetes2 = 0 if diabetesdx ==. & eligstat ==1

*High Cholesterol - Done
gen highchol = bpq080 
recode highchol (2=0) (7 9 = .)

gen highchol2 = highchol if eligstat ==1
replace highchol2 = 0 if highchol ==. & eligstat ==1

*Smoking - Done
gen smokestatus = .
replace smokestatus = 0 if smq020 == 2 //Non-smoker 
replace smokestatus = 1 if smq020 == 1 // Current or former smoker

gen smokestatus2 = smokestatus if eligstat ==1
replace smokestatus2 = 0 if smokestatus ==. & eligstat ==1

**# Demographics Factors
*Age, education, poverty index, income, race 

gen age = ridageyr

gen adult = 0
replace adult = 1 if age >= 18 & age <.

*Gender - Done
gen female = 0
replace female = 1 if riagendr ==2 

*Pregant
gen pregnant = ridexprg 
recode pregnant (2/3=0) 

*Race - Done
gen race1 = ridreth1 
recode race1 (3=1) (4=2) (1 2 = 3) (5=4)
lab def race1 1 "Non-Hispanic White" 2 "Non-Hispanic Black" 3 "Hispanic" 4 "Other Race"
lab val race1 race1 

lab def education 1 "Less than high school" 2 "High school graduate" 3 "Some college" 4 "College graduate and above"
gen education = dmdeduc2 
recode education (1/2=1) (3=2) (4=3) (5=4) (7/9=.)
lab val education education

gen college = education
recode college (1/3=0) (4=1)

gen nocollege = education
recode nocollege (1/3=1) (4=0)

gen education2 = education 
recode education2 (.=0)
lab def education2 0 "Missing" 1 "Less than high school" 2 "High school graduate" 3 "Some college" 4 "College graduate and above"
lab val education2 education2 

*Nativity
gen usborn = dmdborn 
recode usborn (2/3=0)


*Poverty or Income
gen pir = . 
replace pir = 0 if indfmpir < 1 // Less than 1
replace pir = 1 if indfmpir >=1 & indfmpir < 2 //1.00-1.99
replace pir = 2 if indfmpir >=2 & indfmpir < 3 //2.00-2.99
replace pir = 3 if indfmpir >=3 & indfmpir < 4 //3.00-3.99
replace pir = 4 if indfmpir >=4 & indfmpir < 5 //4.00-4.99
replace pir = 5 if indfmpir >=5 & indfmpir < . //5.00+
lab def pir 0 "Less than 1.00" 1 "1.00-1.99" 2 "2.00-2.99" 3 "3.00-3.99" 4 "4.00-4.99" 5 "5.00+"
lab val pir pir
lab var pir "Family Income to Poverty Ratio"

gen lowpir = pir 
recode lowpir (0=1) (1/5=0)
lab var lowpir "PIR Less than 1"

gen pir2 = pir + 1
recode pir2 (.=0)
lab def pir2 0 "Missing" 1 "Less than 1.00" 2 "1.00-1.99" 3 "2.00-2.99" 4 "3.00-3.99" 5 "4.00-4.99" 6 "5.00+"
lab val pir2 pir2 

*Income (check for later years)
/*
*2005-2006
gen lowincome = indfminc
lab def lowincome 0 "Family Income $45k+" 1 "Family Income < $45k" 2 "Missing"
recode lowincome (1/7=1) (8/11 = 0) (12 13 = 1) (77/99 = 2) (. = 2)
lab val lowincome lowincome 
*/

gen lowincome = indfmin2 
lab def lowincome 0 "Family Income $45k+" 1 "Family Income < $45k" 2 "Missing"
recode lowincome (1/7=1) (8/11 = 0) (12 13 = 1) (14/15 = 0) (77/99 = 2) (. = 2)
lab val lowincome lowincome 


*Depression Score
tab dpq010 year //2005 to 2017
recode dpq* (7/9 = .)
gen Depression_Score = dpq010+dpq020+dpq030+dpq040+dpq050+dpq060+dpq070+dpq080+dpq090
recode Depression_Score (0/9 = 0) (10/27 = 100), generate(Depression_Indicator)

*PHQ2
gen phq2score = dpq020 + dpq010 
gen phq2_cat = phq2score 
recode phq2_cat (0/2=0) (3/6=1)
lab def phq2_cat 0 "PHQ2 < 3" 1 "PHQ2 3+"
lab val phq2_cat phq2_cat

**# Health Behaviors
*Sleep
*tab sld012 year //2015 2017
*tab sld010h year //2005 to 2013

*Sleep Cat for 2005-2013
gen sleepcat = . 
replace sleepcat = 1 if  sld010h < 7 

replace sleepcat = 2 if sld010h >= 7 & sld010h < 10 
replace sleepcat = 3 if sld010h >= 10 & sld010h < 77 

lab def sleepcat 1 "Less than 7 Hours" 2 "7 to 9 Hours" 3 "10 hours or more"
lab val sleepcat sleepcat 

*Sleep Cat for 2015-2017
gen sleepcat = . 
replace sleepcat = 1 if sld012 < 7 
replace sleepcat = 2 if sld012 >= 7 & sld012 < 10
replace sleepcat = 3 if sld012 >=10 & sld012 < 77
lab def sleepcat 1 "Less than 7 Hours" 2 "7 to 9 Hours" 3 "10 hours or more"
lab val sleepcat sleepcat 

gen poorsleep = sleepcat 
recode poorsleep (2/3=0) 

*Physical Acitivity
/*
Relevant Variables
paq605 - vigorous work activity, 1= yes, 2 - no, 7 and 9 are refused and don't know
paq610 - days of vigorous work, 1-7, 77/99 are rfused or don't know, based on paq605
pad615 - minutes of vigorous work 7777 to 9999 are missing

paq620 - moderate work activity
paq625 - number of days of moderate work
pad630 - minutes of moderate intensity work

paq635 - walk or bike
paq640 - number of days walk or bicycle
pad645 - minutes walk/bicycle 

scheme is to do multiply number of days by number of minutes, assuming that they do it.
It may be easier to just do recreational physiacal activities 
paq650 - 1 yes, 2 no, 7 9 refused and don't know
paq655 - days of vigorous physical activity
pad660 - minutes vigorous recreational activity

paq665 - moderate recreational activities
paq670 - days moderate recreational activities
pad675 - minutes moderate recreational acitivites

*/

*Vigorous Recreational Acitivity
gen vpa = paq650 
recode vpa (2=0) (7/9=.)

gen daysvpa = paq655 
recode daysvpa (77/99 = .)

gen minvpa = pad660 
recode minvpa (7777/9999=.)

gen vpa_week = daysvpa*minvpa if vpa ==1
replace vpa_week = 0 if vpa ==0 

*Moderate Recreational Activity
gen mpa = paq665 
recode mpa (2=0) (7/9=.)

gen daysmpa = paq670 
recode daysmpa (77/99 = .)

gen minmpa = pad675
recode minmpa (7777/9999=.)

gen mpa_week = daysmpa*minmpa if mpa ==1
replace mpa_week = 0 if mpa ==0 

*Moderate to Vigorous PA Per Week 
gen mvpa_week = mpa_week + vpa_week
egen mvpa_week2 = rowtotal(mpa_week vpa_week) if mpa_week !=. | vpa_week != . //this is the correct one.

*BMI
gen bmi = bmxbmi
lab var bmi "Measured BMI"

*Alcohol

*2005-2015
gen alcoholstatus = .
replace alcoholstatus = 0 if alq110 ==2  & alq101 ==2 //Never Drinker (2003-2015)
replace alcoholstatus = 1 if alq110 ==1 //current or former drinker (1999-2015)
replace alcoholstatus = 1 if alq101 ==1 //current of former drinkers
tab alcoholstatus //really low numbers...

*2017
gen alcoholstatus = .
replace alcoholstatus = 0 if alq111 ==2
replace alcoholstatus = 0 if alq111 ==1 & alq121 ==0 //Never drinker 2017
replace alcoholstatus = 1 if alq111 ==1 & alq121 >0 & alq121 <77 //current or former drinker (2017)
tab alcoholstatus //really low numbers...

*Diet
/*
Relevant Variables: dr1tkcal dr1ttfat dr1tprot dr1tsfat dr1tmfat dr1tpfat dr1tchol dr1tfibe dr1tmagn dr1tcalc dr1tpota dr1tsodi
Conversion Citation: https://www.nal.usda.gov/programs/fnic#:~:text=How%20many%20calories%20are%20in,Facts%20label%20on%20food%20packages. 
Carbs = 4 calories per gram
Protein = 4 calories per gram
Fat = 9 calories per gram
*/
*Total Energy
gen totalcal = dr1tkcal

*Total Fat %
gen fatcal = dr1ttfat*9

gen fatpercent = (fatcal/totalcal)*100

gen fatdashcat = .
replace fatdashcat = 1 if fatpercent <=27
replace fatdashcat = 0.5 if fatpercent <=32 & fatpercent >27
replace fatdashcat = 0 if fatpercent >32 & fatpercent <.

*Saturated Fat %
gen satfat = dr1tmfat + dr1tpfat + dr1tsfat 

gen satfatcal = satfat*9

gen satfatpercent = (satfatcal/totalcal)*100

gen satfatdashcat = . 
replace satfatdashcat = 1 if satfatpercent <= 6
replace satfatdashcat = 0.5 if satfatpercent > 6 & satfatpercent <= 11
replace satfatdashcat = 0 if satfatpercent > 11 & satfatpercent < .


*Protein %
gen proteincal = dr1tprot*4

gen proteinpercent = (proteincal/totalcal)*100

gen proteindashcat = .
replace proteindashcat = 1 if proteinpercent >=18 & proteinpercent < .
replace proteindashcat = 0.5 if proteinpercent >=16.5 & proteinpercent <18
replace proteindashcat = 0 if proteinpercent < 16.5

*Cholesterol (needs to be 71.4mg/1000kcal) - dr1tchol 
gen cholesteroldash = (dr1tchol/totalcal)*1000

gen cholesteroldashcat = .
replace cholesteroldashcat = 1 if cholesteroldash <= 71.4 
replace cholesteroldashcat = 0.5 if cholesteroldash > 71.4 & cholesteroldash <= 107.1
replace cholesteroldashcat = 0 if cholesteroldash > 107.1 & cholesteroldash < .

*Fiber 
gen fiberdash = (dr1tfibe/totalcal)*1000

gen fiberdashcat = .
replace fiberdashcat = 1 if fiberdash >= 14.8 & fiberdash < .
replace fiberdashcat = 0.5 if fiberdash >= 9.5 & fiberdash < 14.8
replace fiberdashcat = 0 if fiberdash < 9.5

*Magnesium 
gen magenesiumdash = (dr1tmagn/totalcal)*1000

gen magenesiumdashcat = . 
replace magenesiumdashcat = 1 if magenesiumdash >= 238 & magenesiumdash < .
replace magenesiumdashcat = 0.5 if magenesiumdash >= 158 & magenesiumdash < 238
replace magenesiumdashcat = 0 if magenesiumdash < 158

*Calcium
gen calciumdash = (dr1tcalc/totalcal)*1000

gen calciumdashcat = .
replace calciumdashcat = 1 if calciumdash >= 590 & calciumdash < .
replace calciumdashcat = 0.5 if calciumdash >= 402 & calciumdash < 590
replace calciumdashcat = 0 if calciumdash < 402

*Potassium
gen potassiumdash = (dr1tpota/totalcal)*1000

gen potassiumdashcat = .
replace potassiumdashcat = 1 if potassiumdash >= 2238 & potassiumdash < .
replace potassiumdashcat = 0.5 if potassiumdash >= 1534 & potassiumdash < 2238
replace potassiumdashcat = 0 if potassiumdash < 1534

*Sodium 
gen sodiumdash = (dr1tsodi/totalcal)*1000

gen sodiumdashcat = . 
replace sodiumdashcat = 1 if sodiumdash <= 1143
replace sodiumdashcat = 0.5 if sodiumdash > 1143 & sodiumdash <= 1286
replace sodiumdashcat = 0 if sodiumdash > 1286 & sodiumdash < .

*DASH Score
gen dashscore =  satfatdashcat + fatdashcat + proteindashcat + cholesteroldashcat + fiberdashcat + magenesiumdashcat + calciumdashcat + potassiumdashcat +  sodiumdashcat

*Causes of Death
gen heartmort = .
replace heartmort = 0 if eligstat ==1 & mortstat ==0
replace heartmort = 0 if eligstat ==1 & ucod_leading != 1
replace heartmort = 1 if ucod_leading ==1
lab var heartmort "Died of a Heart Attack Versus Other Death"

gen cvamort = . 
replace cvamort = 0 if eligstat==1 & mortstat ==0
replace cvamort = 0 if eligstat ==1 & ucod_leading != 5
replace cvamort = 1 if ucod_leading ==5

**Weights and Follow Up
*Person Months follow Up
clonevar month_fu = permth_int 

*Interview Weights
gen intweight_og = wtint2yr
*gen intweight_7 = wtint2yr/7 //divide by the number of cycles

gen mecweight_og = wtmec2yr 
*gen mecweight_7 = wtmec2yr/7 

**# Reducing the Dataset
/*
Based on the framework and coding, we'll examine the following variables:
seqn eligstat mortstat ucod_leading diabetes hyperten permth_int permth_exm year heartattack stroke chd chf hypertension hypertension2 diabetesdx diabetesdx2 diabetes2 highchol highchol2 smokestatus smokestatus2 age adult female pregnant race1 education college nocollege education2 usborn pir lowpir pir2 lowincome Depression_Score Depression_Indicator phq2score phq2_cat sleepcat alcoholstatus heartmort cvamort month_fu vpa daysvpa minvpa vpa_week mpa daysmpa minmpa mpa_week mvpa_week mvpa_week2 intweight_og mecweight_og bmi fatcal totalcal fatpercent satfat satfatcal satfatpercent proteincal proteinpercent cholesteroldash fiberdash magenesiumdash calciumdash potassiumdash sodiumdash fatdashcat proteindashcat cholesteroldashcat fiberdashcat magenesiumdashcat calciumdashcat sodiumdashcat satfatdashcat potassiumdashcat dashscore sdmvpsu sdmvstra
*/
keep seqn eligstat mortstat ucod_leading diabetes hyperten permth_int permth_exm year heartattack stroke chd chf hypertension hypertension2 diabetesdx diabetesdx2 diabetes2 highchol highchol2 smokestatus smokestatus2 age adult female pregnant race1 education college nocollege education2 usborn pir lowpir pir2 lowincome Depression_Score Depression_Indicator phq2score phq2_cat sleepcat alcoholstatus heartmort cvamort month_fu vpa daysvpa minvpa vpa_week mpa daysmpa minmpa mpa_week mvpa_week mvpa_week2 intweight_og mecweight_og bmi fatcal totalcal fatpercent satfat satfatcal satfatpercent proteincal proteinpercent cholesteroldash fiberdash magenesiumdash calciumdash potassiumdash sodiumdash fatdashcat proteindashcat cholesteroldashcat fiberdashcat magenesiumdashcat calciumdashcat sodiumdashcat satfatdashcat potassiumdashcat dashscore sdmvpsu sdmvstra ucod_leading diabetes hyperten
*save "2007-2008 NHANES Full Data V2.0.dta", replace
*save "2009-2010 NHANES Full Data V2.0.dta", replace
*save "2011-2012 NHANES Full Data V2.0.dta", replace
*save "2013-2014 NHANES Full Data V2.0.dta", replace
*save "2015-2016 NHANES Full Data V2.0.dta", replace 
*save "2017-2018 NHANES Full Data V2.0.dta", replace 

**# Combining Datasets
use "2007-2008 NHANES Full Data V2.0.dta"
append using "2009-2010 NHANES Full Data V2.0.dta"
append using "2011-2012 NHANES Full Data V2.0.dta"
append using "2013-2014 NHANES Full Data V2.0.dta"
append using "2015-2016 NHANES Full Data V2.0.dta" 
append using "2017-2018 NHANES Full Data V2.0.dta"
save "2007-2018 NHANES Combined Full Data V1.0.dta", replace
count 

**#Some Last Cleaning
gen intweight_6 = intweight_og/6 //divide by the number of cycles

gen mecweight_6 = mecweight_og/6

gen mvpa_cat = mvpa_week2
recode mvpa_cat (0/149 = 1) (150/6930=0)
lab def mvpa_cat 0 "More than 150 min per week" 1 "Less than 150 min per week"
lab val mvpa_cat mvpa_cat

mvpatterns mortstat year heartattack stroke chd chf hypertension2 diabetesdx2 highchol2 smokestatus2 age female race1 education2 usborn pir2 lowincome phq2_cat sleepcat alcoholstatus heartmort cvamort month_fu mvpa_week2 bmi dashscore if adult ==1

egen miss1 = rowmiss(mortstat year heartattack stroke chd chf hypertension2 diabetesdx2 highchol2 smokestatus2 age female race1 education2 usborn pir2 lowincome phq2_cat sleepcat alcoholstatus heartmort cvamort month_fu mvpa_week2 bmi dashscore) if adult ==1

gen sample1 = miss1 
recode sample1 (0=1) (1/18 = 0)
replace sample1 =. if pregnant ==1 

gen obesity = .
replace obesity = 0 if bmi <30
replace obesity = 1 if bmi >=30 & bmi  < .

save "2007-2018 NHANES Combined Full Data V1.0.dta", replace

**# 20240115 - New Analyses for Paper and Job Talk
use "C:\Users\abacong\Box\Adrian Bacong's Files\NHIS and NHANES SMURF Project\Data\1999-2018 NHANES PREVENT DATA V1.0.dta" //need to do some editing
drop if year < 2007
tab year
save "C:\Users\abacong\Box\Adrian Bacong's Files\NHIS and NHANES SMURF Project\Data\2007-2018 NHANES PREVENT DATA V1.0.dta", replace

clear
cd "C:\Users\abacong\Box\Adrian Bacong's Files\NHIS and NHANES SMURF Project\Data"

use "2007-2018 NHANES Combined Full Data V1.0.dta", replace
merge 1:1 seqn using "C:\Users\abacong\Box\Adrian Bacong's Files\NHIS and NHANES SMURF Project\Data\2007-2018 NHANES PREVENT DATA V1.0.dta"
save "2007-2018 NHANES SMURF Combined Full Data V2.0.dta", replace

egen miss2 = rowmiss(mortstat year heartattack stroke chd chf hypertension2 diabetesdx2 highchol2 smokestatus2 age female race1 education2 usborn pir2 lowincome phq2_cat sleepcat alcoholstatus heartmort cvamort month_fu mvpa_week2 bmi dashscore sbp statin_med htn_med chol_total_mgdl nonhdlc_mgdl egfr hemoa1c) if adult ==1

gen sample2 = miss2 
recode sample2 (0=1) (1/23 = 0)
replace sample2 =. if pregnant ==1 
cd "C:\Users\abacong\Box\Adrian Bacong's Files\NHIS and NHANES SMURF Project\Data"
save "2007-2018 NHANES SMURF Combined Full Data V2.0.dta", replace
//Data as of 20240115

**# 20240317 - Combining in Occupation Data
//Per DHR, should include data on occupation.
//Data created in 20240307 NHANES 1999-2018 Import V2 Document
cd "C:\Users\abacong\Box\Adrian Bacong's Files\NHIS and NHANES SMURF Project\Data"
use "2007-2018 NHANES SMURF Combined Full Data V2.0.dta", replace
drop _merge
merge 1:1 seqn using "2007-2018 NHANES OCQ.dta"
save "2007-2018 NHANES SMURF Combined Full Data V3.0.dta", replace

**#20240326 - Coding Occupation Type
//Per DHR, need to include occupation type
cd "C:\Users\abacong\Box\Adrian Bacong's Files\NHIS and NHANES SMURF Project\Data"
use  "2007-2018 NHANES SMURF Combined Full Data V3.0.dta", replace
/*
Relevant Variables:
ocd150 - what type of work did you do last week
ocq260 - description of work
ocd390g - kind of work you have done the longest
ocd391 - Industry group code (but only up throgh 2013-2014)
//maybe add in housing too?
*/

lab def ocd150 1 "Working at job or business" 2 "With Job, but not at work" 3 "Looking for work" 4 "Not working" 7 "Refused" 9 "Don't Know", replace
lab val ocd150 ocd150 

lab def ocq260 1 "Employee for Company Wages" 2 "Federal Govt" 3 "State Govt" 4 "Local Govt" 5 "Self-Employed" 6 "No Pay in Family Business/Farm" 77 "Refused" 99 "Don't Know", replace
lab val ocq260 ocq260 

lab def ocd390g 1 "Enter occupation" 2 "Same as current occupation" 3 "Armed Forces" 4 "Never worked" 7 "Refused" 9 "Don't Know"
lab val ocd390g ocd390g

lab def ocq380 1 "Taking care of house/family" 2 "Going to School" 3 "Retired" 4 "Unable to work for health" 5 "On layoff" 6 "Disabled" 7 "Other" 77 "Refused" 99 "Don't Know"
lab val ocq380 ocq380

gen employed = ocd150 
recode employed (1/2 = 1) (4=0) (7/9 = .)
replace employed = 1 if ocd150 == 3 & ocd390g == 1 //looking for work, but current employed
replace employed = 1 if ocd150 == 3 & ocd390g == 3 //looking for work, but in the armed forces
replace employed = 0 if ocd150 == 3 & ocd390g == 4 //looking for work, but never worked
replace employed = 0 if ocd150 == 3 & ocd390g == 7 //looking for work, but refused to answer type of work done longest 

gen worktype = employed
replace worktype = 2 if ocq260 == 2 | ocq260 ==3 | ocq260 ==4 //working for government
replace worktype = 3 if ocq260 == 5 | ocq260 == 6 //self-employed or family business 
lab def worktype 0 "Unemployed" 1 "Employed for Wages" 2 "Government Employee" 3 "Self-Employed/Family Business", replace
lab val worktype worktype


/*gen worktype = .
replace worktype =1 if ocq260 ==1 //working at job or business
replace worktype =2 if ocq260 ==2 | ocq260 ==3 | ocq260 ==4 //government employee
replace worktype =3 if ocq260 ==5 | ocq260 ==6 //Self-Employed/Family business
replace worktype =4 if employed ==0
replace worktype = 1 if employed ==1 & ocd390g ==1 //"enter occupation"
replace worktype = 1 if employed ==1 & ocd390g ==2 //Same as current position
replace worktype = 2 if employed ==1 & ocd390g == 3 //Armed forces with govt employee
replace worktype = 1 if employed ==1  & ocd390g == 7 //refused, but still working
lab def worktype 1 "Working at job/business" 2 "Government Employee" 3 "Self-Employed/Famiy Business" 4 "Unemployed/Retired" 
lab val worktype worktype 
//we'll stick with the employment variable
*/

**# 20240402 - Combining in Housing Data
cd "C:\Users\abacong\Box\Adrian Bacong's Files\NHIS and NHANES SMURF Project\Data"
use "2007-2018 NHANES SMURF Combined Full Data V3.0.dta", replace
drop _merge
merge 1:1 seqn using "2007-2018 NHANES HOQ.dta"
save "2007-2018 NHANES SMURF Combined Full Data V4.0.dta", replace

gen housetype = hoq065
recode housetype (2/3=0) (7/9=.)
lab def housetype 0 "Rent or Other Arrangement" 1 "Owned or Being Bought"
lab val housetype housetype 
