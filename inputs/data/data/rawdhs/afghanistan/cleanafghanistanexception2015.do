/*Note: this program processes the raw data from the 2015 Afghanistan DHS. This 
has the Standard DHS format.*/

*input dataset: AFIR70DT.dta
*output dataset: afghanistanexception2015.dta

*open and describe raw dataset
use b* v* mm* using AFIR70FL.DTA,clear

*woman-level variables
d v*
gen caseid = _n
label var caseid "person identifier"
ren v000 surveycode
ren v001 cluster
ren v002 hhnumber
ren v003 womanid
ren v005 smpwt
ren v007 year
replace year=2015
ren v012 age
ren v010 yob
replace yob=yob+621 /*afghanistan's calendar is 621 years behind*/
gen rural=v102-1
label var rural "rural residence"
gen child_rur = (v103==3) if v103<9
label var child_rur "rural residence in childhood"

ren v190 assetcat
label define aclab 1 "poorest" 2 "poorer" 3 "middle" 4 "rich" 5 "richer"
label value assetcat aclab
label var assetcat "household asset score quintile"
ren v191 assetindex
label var assetindex "household asset pca score"

ren v113 water
recode water (10/19=1) (20/89=0) (90/.=.)
label var water "piped water"
ren v116 toilet
recode toilet (10/19=1) (20/89=0) (90/.=.)
label var water "flush toilet"
recode v119-v125 (7=.)
ren v119 electricity
ren v120 radio
ren v121 tele
ren v122 fridge
ren v123 bike
ren v124 moto
ren v125 car
ren v127 floor
recode floor (10/19=0) (20/89=1) (90/.=.)
label var floor "improved floor"
ren v128 wall
recode wall (10/29=0) (30/89=1) (90/.=.)
label var wall "improved wall"
ren v129 roof
recode roof (10/19=0) (20/89=1) (90/.=.)
label var roof "improved roof"
ren v133 edyrs
replace edyrs=. if edyrs>=90 /*recode all values of education above 90 to missing (.)*/ 
gen nevermar = 0 /*only ever-married women were sampled*/
label var nevermar "never married"
ren v511 agemar
ren v212 agebirth
ren v201 evborn
egen evborn_m = rowtotal(v202 v204 v206)
replace evborn_m = 0 if evborn==0 /*no kids*/
label var evborn_m "sons ever born"
egen evborn_f =  rowtotal(v203 v205 v207)
replace evborn_f = 0 if evborn==0 /*no kids*/
label var evborn_f "daughters ever born"
ren v206 evdied_m
ren v207 evdied_f
recode evdied_m evdied_f (.=0)
ren v437 weight
ren v438 height
ren v445 bmi
ren v715 husb_edyrs
replace husb_edyrs=. if husb_edyrs>=90
ren v730 husb_age
drop v*

*child-level variables: keep twin status, month of birth, year of birth, sex, survival, age at death
d b*
**loops to rename variables (need two loops because need leading zeros for 1-9 but not 10-20)
forvalues i=1/9 {
  ren bord_0`i' ch_bord_`i'
  ren b0_0`i' ch_twin_`i'
  replace ch_twin_`i'=1 if (ch_twin_`i' != 0)&(ch_twin_`i'<.)
  ren b1_0`i' ch_mob_`i'
  recode ch_mob_`i' (1=4)(2=5)(3=6)(4=7)(5=8)(6=9)(7=10)(8=11)(9=12)(10=1)(11=2)(12=3) /*convert to gregorian months*/
  ren b2_0`i' ch_yob_`i'
  replace ch_yob_`i'=ch_yob_`i'+621 /*afghanistan's calendar is 621 years behind*/
  gen ch_male_`i' = 2-b4_0`i'
  label var ch_male_`i' "child is male"
  gen ch_dead_`i' = 1-b5_0`i'
  label var ch_dead_`i' "child is dead"
  ren b7_0`i' ch_agedeath_`i'
  replace ch_agedeath_`i' = . if ch_agedeath_`i'>900 /*missing code*/
  ren b8_0`i' ch_age_`i'
}
forvalues i=10/20 {
  ren bord_`i' ch_bord_`i'
  ren b0_`i' ch_twin_`i'
  replace ch_twin_`i'=1 if (ch_twin_`i' != 0)&(ch_twin_`i'<.)
  ren b1_`i' ch_mob_`i'
  recode ch_mob_`i' (1=4)(2=5)(3=6)(4=7)(5=8)(6=9)(7=10)(8=11)(9=12)(10=1)(11=2)(12=3) /*convert to gregorian months*/
  ren b2_`i' ch_yob_`i'
  replace ch_yob_`i'=ch_yob_`i'+621 /*afghanistan's calendar is 621 years behind*/
  gen ch_male_`i' = 2-b4_`i'
  label var ch_male_`i' "child is male"
  gen ch_dead_`i' = 1-b5_`i'
  label var ch_dead_`i' "child is dead"
  ren b7_`i' ch_agedeath_`i'
  replace ch_agedeath_`i' = . if ch_agedeath_`i'>900 /*missing code*/
  ren b8_`i' ch_age_`i'
}
drop bidx* b3_* b9_* b10_* b11_* b12_* b13_* b15_* b16_* b4_* b5_* 

*sibling-level variables
d mm*
rename mmc1 numsibs
replace numsibs =. if numsibs>=90
gen b_order = mmc2+1
replace b_order = 1 if numsibs==0
replace b_order =. if b_order>=99 /*missing code*/
label var b_order "self-reported birth order of resp."

**initialize variables to count all siblings
gen msibs_o = 0
label var msibs_o "older male siblings"
gen fsibs_o = 0
label var fsibs_o "older female siblings"
gen msibs_tw = 0
label var msibs_tw "male siblings born in same year"
gen fsibs_tw = 0
label var fsibs_tw "female siblings born in same year"
gen msibs_y = 0
label var msibs_y "younger male siblings"
gen fsibs_y = 0
label var fsibs_y "younger female siblings"
gen msibs_dk = 0
label var msibs_dk "male siblings w/ unknown yob"
gen fsibs_dk = 0
label var fsibs_dk "female siblings w/ unknown yob"

**initialize variables to count deceased siblings
***under 1 mortality
gen u1_msibs_o = 0
label var u1_msibs_o "older males dead before 1"
gen u1_fsibs_o = 0
label var u1_fsibs_o "older females dead before 1"
gen u1_msibs_tw = 0
label var u1_msibs_tw "males same yob dead before 1"
gen u1_fsibs_tw = 0
label var u1_fsibs_tw "females same yob dead before 1r"
gen u1_msibs_y = 0
label var u1_msibs_y "younger males dead before 1"
gen u1_fsibs_y = 0
label var u1_fsibs_y "younger females dead before 1"
gen u1_msibs_dk = 0
label var u1_msibs_dk "males unknown yob dead before 1"
gen u1_fsibs_dk = 0
label var u1_fsibs_dk "females unknown yob dead before 1"
***under 5 mortality
gen u5_msibs_o = 0
label var u5_msibs_o "older males dead before 5"
gen u5_fsibs_o = 0
label var u5_fsibs_o "older females dead before 5"
gen u5_msibs_tw = 0
label var u5_msibs_tw "males same yob dead before 5"
gen u5_fsibs_tw = 0
label var u5_fsibs_tw "females same yob dead before 5"
gen u5_msibs_y = 0
label var u5_msibs_y "younger males dead before 5"
gen u5_fsibs_y = 0
label var u5_fsibs_y "younger females dead before 5"
gen u5_msibs_dk = 0
label var u5_msibs_dk "males unknown yob dead before 5"
gen u5_fsibs_dk = 0
label var u5_fsibs_dk "females unknown yob dead before 5"

**initialize variables to count siblings with unknown survival status (alive/dead AND age at death)
gen miss_msibs_o = 0
label var miss_msibs_o "older males missing survival"
gen miss_fsibs_o = 0
label var miss_fsibs_o "older females missing survival"
gen miss_msibs_tw = 0
label var miss_msibs_tw "males same yob missing survival"
gen miss_fsibs_tw = 0
label var miss_fsibs_tw "females same yob missing survival"
gen miss_msibs_y = 0
label var miss_msibs_y "younger males missing survival"
gen miss_fsibs_y = 0
label var miss_fsibs_y "younger females missing survival"
gen miss_msibs_dk = 0
label var miss_msibs_dk "males unknown yob missing survival"
gen miss_fsibs_dk = 0
label var miss_fsibs_dk "females unknown yob missing survival"

**loops to count siblings (need two loops because need leading zeros for 1-9 but not 10-20)
forvalues i=1/9 {
  gen sib_male_`i' = mm1_0`i'==1 if mm1_0`i'<8
  label var sib_male_`i' "sex of sibling"
  replace mm4_0`i' = mm4_0`i'+255 /*cmc correction for afghanistan*/
  gen sib_yob_`i' = floor((mm4_0`i'+12*1900)/12) /*mm4 is in cmc format, where cmc = 12*year + month - 12*1900*/
  label var sib_yob_`i' "sibling year of birth"
  gen sib_dead_`i' = mm2_0`i'==0 if mm2_0`i'<3
  label var sib_dead_`i' "sibling is dead"
  gen sib_agedeath_`i' = mm7_0`i' if mm7_0`i'<95
  replace mm8_0`i'=mm8_0`i'+255 /*cmc correction for afghanistan*/
  replace sib_agedeath_`i' = floor((mm8_0`i'-mm4_0`i')/12) if sib_agedeath_`i'==. /*if missing age at death, generate it from dates at birth/death*/
  label var sib_agedeath_`i' "sibling age at death"
 
  replace msibs_o = msibs_o + 1 if (sib_male_`i'==1)&(sib_yob_`i'<yob)
  replace fsibs_o = fsibs_o + 1 if (sib_male_`i'==0)&(sib_yob_`i'<yob)
  replace msibs_tw = msibs_tw + 1 if (sib_male_`i'==1)&(sib_yob_`i'==yob)
  replace fsibs_tw = fsibs_tw + 1 if (sib_male_`i'==0)&(sib_yob_`i'==yob)
  replace msibs_y = msibs_y + 1 if (sib_male_`i'==1)&(sib_yob_`i'>yob&sib_yob_`i'<.)
  replace fsibs_y = fsibs_y + 1 if (sib_male_`i'==0)&(sib_yob_`i'>yob&sib_yob_`i'<.)
  replace msibs_dk = msibs_dk + 1 if (sib_male_`i'==1)&(sib_yob_`i'==.)
  replace fsibs_dk = fsibs_dk + 1 if (sib_male_`i'==0)&(sib_yob_`i'==.)
 
  replace u1_msibs_o = u1_msibs_o + 1 if (sib_male_`i'==1)&(sib_yob_`i'<yob)&(sib_agedeath_`i'==0)
  replace u1_fsibs_o = u1_fsibs_o + 1 if (sib_male_`i'==0)&(sib_yob_`i'<yob)&(sib_agedeath_`i'==0)
  replace u1_msibs_tw = u1_msibs_tw + 1 if (sib_male_`i'==1)&(sib_yob_`i'==yob)&(sib_agedeath_`i'==0)
  replace u1_fsibs_tw = u1_fsibs_tw + 1 if (sib_male_`i'==0)&(sib_yob_`i'==yob)&(sib_agedeath_`i'==0)
  replace u1_msibs_y = u1_msibs_y + 1 if (sib_male_`i'==1)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_agedeath_`i'==0)
  replace u1_fsibs_y = u1_fsibs_y + 1 if (sib_male_`i'==0)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_agedeath_`i'==0)
  replace u1_msibs_dk = u1_msibs_dk + 1 if (sib_male_`i'==1)&(sib_yob_`i'==.)&(sib_agedeath_`i'==0)
  replace u1_fsibs_dk = u1_fsibs_dk + 1 if (sib_male_`i'==0)&(sib_yob_`i'==.)&(sib_agedeath_`i'==0)
  
  replace u5_msibs_o = u5_msibs_o + 1 if (sib_male_`i'==1)&(sib_yob_`i'<yob)&(sib_agedeath_`i'<5)
  replace u5_fsibs_o = u5_fsibs_o + 1 if (sib_male_`i'==0)&(sib_yob_`i'<yob)&(sib_agedeath_`i'<5)
  replace u5_msibs_tw = u5_msibs_tw + 1 if (sib_male_`i'==1)&(sib_yob_`i'==yob)&(sib_agedeath_`i'<5)
  replace u5_fsibs_tw = u5_fsibs_tw + 1 if (sib_male_`i'==0)&(sib_yob_`i'==yob)&(sib_agedeath_`i'<5)
  replace u5_msibs_y = u5_msibs_y + 1 if (sib_male_`i'==1)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_agedeath_`i'<5)
  replace u5_fsibs_y = u5_fsibs_y + 1 if (sib_male_`i'==0)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_agedeath_`i'<5)
  replace u5_msibs_dk = u5_msibs_dk + 1 if (sib_male_`i'==1)&(sib_yob_`i'==.)&(sib_agedeath_`i'<5)
  replace u5_fsibs_dk = u5_fsibs_dk + 1 if (sib_male_`i'==0)&(sib_yob_`i'==.)&(sib_agedeath_`i'<5)
 
  replace miss_msibs_o = miss_msibs_o + 1 if (sib_male_`i'==1)&(sib_yob_`i'<yob)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_fsibs_o = miss_fsibs_o + 1 if (sib_male_`i'==0)&(sib_yob_`i'<yob)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_msibs_tw = miss_msibs_tw + 1 if (sib_male_`i'==1)&(sib_yob_`i'==yob)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_fsibs_tw = miss_fsibs_tw + 1 if (sib_male_`i'==0)&(sib_yob_`i'==yob)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_msibs_y = miss_msibs_y + 1 if (sib_male_`i'==1)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_fsibs_y = miss_fsibs_y + 1 if (sib_male_`i'==0)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_msibs_dk = miss_msibs_dk + 1 if (sib_male_`i'==1)&(sib_yob_`i'==.)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_fsibs_dk = miss_fsibs_dk + 1 if (sib_male_`i'==0)&(sib_yob_`i'==.)&(sib_dead_`i'==.|(sib_dead_`i'==1&sib_agedeath_`i'==.))
  }
forvalues i=10/20 {
  capture{ /*use the capture command because not all surveys go up to 20 siblings*/
  gen sib_male_`i' = mm1_`i'==1 if mm1_`i'<8
  label var sib_male_`i' "sex of sibling"
  replace mm4_`i'=mm4_`i'+255 /*cmc correction for afghanistan*/
  gen sib_yob_`i' = floor((mm4_`i'+12*1900)/12) /*mm4 is in cmc format, where cmc = 12*year + month - 12*1900*/
  label var sib_yob_`i' "sibling year of birth"
  gen sib_dead_`i' = mm2_`i'==0 if mm2_`i'<3
  label var sib_dead_`i' "sibling is dead"
  gen sib_agedeath_`i' = mm7_`i' if mm7_`i'<95
  replace mm8_`i'=mm8_`i'+255 /*cmc correction for afghanistan*/
  replace sib_agedeath_`i' = floor((mm8_`i'-mm4_`i')/12) if sib_agedeath_`i'==. /*if missing age at death, generate it from dates at birth/death*/
  label var sib_agedeath_`i' "sibling age at death"
 
  replace msibs_o = msibs_o + 1 if (sib_male_`i'==1)&(sib_yob_`i'<yob)
  replace fsibs_o = fsibs_o + 1 if (sib_male_`i'==0)&(sib_yob_`i'<yob)
  replace msibs_tw = msibs_tw + 1 if (sib_male_`i'==1)&(sib_yob_`i'==yob)
  replace fsibs_tw = fsibs_tw + 1 if (sib_male_`i'==0)&(sib_yob_`i'==yob)
  replace msibs_y = msibs_y + 1 if (sib_male_`i'==1)&(sib_yob_`i'>yob&sib_yob_`i'<.)
  replace fsibs_y = fsibs_y + 1 if (sib_male_`i'==0)&(sib_yob_`i'>yob&sib_yob_`i'<.)
  replace msibs_dk = msibs_dk + 1 if (sib_male_`i'==1)&(sib_yob_`i'==.)
  replace fsibs_dk = fsibs_dk + 1 if (sib_male_`i'==0)&(sib_yob_`i'==.)
 
  replace u1_msibs_o = u1_msibs_o + 1 if (sib_male_`i'==1)&(sib_yob_`i'<yob)&(sib_agedeath_`i'==0)
  replace u1_fsibs_o = u1_fsibs_o + 1 if (sib_male_`i'==0)&(sib_yob_`i'<yob)&(sib_agedeath_`i'==0)
  replace u1_msibs_tw = u1_msibs_tw + 1 if (sib_male_`i'==1)&(sib_yob_`i'==yob)&(sib_agedeath_`i'==0)
  replace u1_fsibs_tw = u1_fsibs_tw + 1 if (sib_male_`i'==0)&(sib_yob_`i'==yob)&(sib_agedeath_`i'==0)
  replace u1_msibs_y = u1_msibs_y + 1 if (sib_male_`i'==1)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_agedeath_`i'==0)
  replace u1_fsibs_y = u1_fsibs_y + 1 if (sib_male_`i'==0)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_agedeath_`i'==0)
  replace u1_msibs_dk = u1_msibs_dk + 1 if (sib_male_`i'==1)&(sib_yob_`i'==.)&(sib_agedeath_`i'==0)
  replace u1_fsibs_dk = u1_fsibs_dk + 1 if (sib_male_`i'==0)&(sib_yob_`i'==.)&(sib_agedeath_`i'==0)
  
  replace u5_msibs_o = u5_msibs_o + 1 if (sib_male_`i'==1)&(sib_yob_`i'<yob)&(sib_agedeath_`i'<5)
  replace u5_fsibs_o = u5_fsibs_o + 1 if (sib_male_`i'==0)&(sib_yob_`i'<yob)&(sib_agedeath_`i'<5)
  replace u5_msibs_tw = u5_msibs_tw + 1 if (sib_male_`i'==1)&(sib_yob_`i'==yob)&(sib_agedeath_`i'<5)
  replace u5_fsibs_tw = u5_fsibs_tw + 1 if (sib_male_`i'==0)&(sib_yob_`i'==yob)&(sib_agedeath_`i'<5)
  replace u5_msibs_y = u5_msibs_y + 1 if (sib_male_`i'==1)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_agedeath_`i'<5)
  replace u5_fsibs_y = u5_fsibs_y + 1 if (sib_male_`i'==0)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_agedeath_`i'<5)
  replace u5_msibs_dk = u5_msibs_dk + 1 if (sib_male_`i'==1)&(sib_yob_`i'==.)&(sib_agedeath_`i'<5)
  replace u5_fsibs_dk = u5_fsibs_dk + 1 if (sib_male_`i'==0)&(sib_yob_`i'==.)&(sib_agedeath_`i'<5)
 
  replace miss_msibs_o = miss_msibs_o + 1 if (sib_male_`i'==1)&(sib_yob_`i'<yob)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_fsibs_o = miss_fsibs_o + 1 if (sib_male_`i'==0)&(sib_yob_`i'<yob)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_msibs_tw = miss_msibs_tw + 1 if (sib_male_`i'==1)&(sib_yob_`i'==yob)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_fsibs_tw = miss_fsibs_tw + 1 if (sib_male_`i'==0)&(sib_yob_`i'==yob)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_msibs_y = miss_msibs_y + 1 if (sib_male_`i'==1)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_fsibs_y = miss_fsibs_y + 1 if (sib_male_`i'==0)&(sib_yob_`i'>yob)&(sib_yob_`i'<.)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_msibs_dk = miss_msibs_dk + 1 if (sib_male_`i'==1)&(sib_yob_`i'==.)&(sib_dead_`i'==.|(sib_dead_`i'==1)&(sib_agedeath_`i'==.))
  replace miss_fsibs_dk = miss_fsibs_dk + 1 if (sib_male_`i'==0)&(sib_yob_`i'==.)&(sib_dead_`i'==.|(sib_dead_`i'==1&sib_agedeath_`i'==.))
  }
  }
  
  
***
* Merge in respondent's coresident mom ID variable
*** 
preserve
use AFIR70FL.DTA,clear
d v*
drop caseid
gen momcaseid = _n
label var momcaseid "person identifier"


*Rename variable
rename v000 surveycode //survey code
rename v001 cluster //cluster id
rename v002 hhnumber // hhid
rename v003 momid //person id 
	
*Some datasets have a small number of duplicates - drop them
duplicates drop surveycode cluster hhnumber momid, force

forvalues i=1/9 {
  ren b16_0`i' womanid_`i'
}
forvalues i=10/20 {
  capture {/*use the capture command because not all surveys go up to 20 kids*/
  ren b16_`i' womanid_`i'
}
}

keep surveycode cluster hhnumber momid momcaseid womanid_*

*Reshape into birth-level data to get the merge IDs for the children in the PR 
reshape long womanid_, i(momcaseid) j(mom_ch_num)
rename womanid_ womanid

drop if womanid == 0 | missing(womanid) // drop missing values

*Some datasets have a small number of duplicates - drop them
duplicates drop surveycode cluster hhnumber womanid, force
drop mom_ch_num

tempfile mergedat
save `mergedat'
restore

merge 1:1 surveycode cluster hhnumber womanid using `mergedat'
drop if _merge == 2
drop _merge 



  
*drop variables, reorder, and save
drop mm* b6* b1* b2*
drop sib_* /*if we want to add info on individual siblings back into the dataset, take out this line*/
 
order surveycode caseid smpwt year cluster hhnumber womanid momid momcaseid rural child_rur yob age edyrs weight height bmi nevermar agemar agebirth husb_age husb_edyrs ///
      evborn* evdied* ch_* numsibs b_order msibs_o-fsibs_dk u1* u5* miss*
	  
save afghanistanexception2015.dta,replace