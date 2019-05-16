version 14
set more off
clear
  quietly log
log using lacombe-intro.txt, text replace

/*	***************************************************************	*/
/* 	Author:		Scott LaCombe										*/
/*	Date:		January 2018											*/
/*  File:		lacombe-intro.do	       		 		*/						*/
/*	Purpose:	Clean CCES data and merge in institutional data		*/
/*	Input files: CCES_2016.dta					*/
/*				statecodes.dta, state_innovate.dta					*/
/* Output files: mkdata-long.dta									*/
/*	***************************************************************	*/

///check working directory, set to right place if needed
/// try to avoid filepaths that are too long, makes replication hard
/// read in dataset from 
use "CCES_2016", clear


/* white/non-white variables */
/// remember, variable name should also signify a 1
tab race, m
recode race (1=1 "White") (2/8=0 "Non-white"), gen(white)
recode race (1=0 "Non-black") (2=1 "Black") (3/8=0), gen(black)
recode race (3=1 "Latino") (1/2=0 "Non-Latino") (4/8=0), gen(latino)
replace latino=1 if hispanic==1
tab latino, m
tab white, m
tab black, m
tab latino, m


/* male/female */
tab gender, missing
recode gender (1=1 "Male") (2=0 "Female"), gen(male)
tab male, m

/* age */
sum birthyr
gen age= 2016-birthyr
sum age


/// income - missing values recode to 0, change value labels 
tab faminc
/// need to recode several values
tab faminc, nolabel
recode faminc (1=1 "Less than $10,000") (2=2 "$10,000-$19,999") ///
(3=3 "$20,000-$29,999")(4=4 "$30,000-$39,999") (5=5 "$40,000-$49,999") ///
 (6=6 "$50,000- $59,999") (7=7 "$60,000-$69,999") (8=8 "$70,000- $79,999") ///
 (9=9 "$80,000-$99,999") (10=10 "$100,000-$119,999") (11=11 "$120,000-$149,999") (12=12 "$150,000 or more") (13/32=12) (97=.), gen(income)
recode income .=0
tab income


/* partisanship */
tab pid3, m
recode pid3 (1=1 "Democrat") (2=3 "Republican") (3/5=2 "Independent"), gen(republicanid)
tab republicanid
recode republicanid (1=1 "Democrat") (2/3=0 "Non-Democrat"), gen(dem)
recode republicanid (2=1 "Independent") (1=0 "Partisan") (3=0), gen(ind)
recode republicanid (1=0 "Non-Republican") (2=0) (3=1 "Republican"), gen(rep)
tab dem, m
tab rep, m
tab ind, m

/* strong and weak partisans */
recode pid7 (1=3 "Strong Partisan") (2=2 "Weak Partisan") (3=1 "Leaner") (4=0 "Ind") (5=3) (6=2) (7=1) (8=0), gen(partystr)
tab partystr
/// voting
tab votereg
recode votereg (1=1 "Registered") (2/3=0 "Not Registered"), gen(vote_reg)
tab vote_reg

tab CC16_364, m
recode CC16_364 (1=1 "Voted") (2/5=0 "No Vote"), gen(vote)
tab vote
recode vote .=0

/// 2012 vote
/// again, unless certain, we will say they are a no
tab CC16_316, m
recode CC16_316 (4=1 "Voted") (1/3=0 "No Vote"), gen(vote2012)
tab vote2012, m
recode vote2012 .=0
/* ideology */
tab ideo5, missing
tab ideo5, nolabel
recode ideo5 (1/2=1 "Liberal") (3=2 "Moderate") (4/5=3 "Conservative") (6=2) (.=2), gen(conserveid)
tab conserveid, missing
 /* marital status */
tab marstat, m

recode marstat (1=1 "married") (2/6=0 "not-married") (.=0), gen(married)
tab married, m
/*education */
tab educ, m
tab educ, nolabel

/*employed */
tab employ, m
recode employ (1/2=1 "Employed") (3/9=0 "Not Employed") (.=0), gen(employed)
tab employed, m
 /*tobit imputed income */
 // we are telling stata we censored the data on the left side (put missing as 0)
 tobit income educ married employed white latino ///
 age male [aw=commonweight_vv], ll(0)
 predict yhat
 replace income=yhat if income==0
 /// tab isn't great here, so many values
 /// you can now decide if you want to have this semi continous measure, or round
 replace income=round(income)
 
sum income

/// I want to merge in data on state innovativeness, but my dataset is labeled 
/// by state name, and CCES uses state fips
/// rename variable so I can merge in other forms of labeling states ///
rename inputstate state_fips
merge m:1 state_fips using "statecodes.dta"
browse if _merg==2
/// dropping these cases, US territories
drop if _merge==2
drop _merge

/// now we have the right variables, lets merge
merge m:1 statenam using "state_innovate.dta"

/// again, look why some didn't merge
/// do we care about DC for the project, in this case no, so I drop
drop if _merge==2
drop _merge
/// if working with really big datasets, you can drop variables you dont
/// care about, saves time/space
/// save dataset, separate do-file for analysis normally
save lacombe-cces, replace

/************* Models and Visualization **********************/

use lacombe-cces, clear

label variable income "Income"
label variable educ "Education"
label variable married "Married"
label variable age "Age"
label variable male "Male"
label variable black "Black"
label variable latino "Latino"
label variable republicanid "Republicanism"
label variable conserveid "Conservatism"
label variable employed "Employed"



logit vote married income educ latino male black age republicanid conserveid ///
employed [pw=commonweight_vv]
estimates store m1

coefplot m1, xline(0) title(Modeling Turnout in 2016 Election) 
/// we don't care about the constant that much, so maybe just include a footnote 
/// in latex and omit it from coef plot, that way we can see differences more
coefplot m1, xline(0) title(Modeling Turnout in 2016 Election) drop(_cons)

/// histograms can help for some too

hist income
/// state thinks its continous, two ways to get around it
hist income, scheme(s2color) bin(12) percent
hist income, discrete

/// lets try interactions and margins
logit vote income educ male i.married##c.age black latino republicanid conserveid ///
employed  [pw=commonweight_vv]
estimates store m1

/// make models look nice
esttab m1, b(3) compress ///
		se label replace cells(b(fmt(4) star) noommited ///
		se(par)) starlevels(* .01) rename([adoption]_cons constant) ///
		varwidth(30) mlabels(, none) collabels(, none) eqlabels(, none) ///
		interaction(X) nobaselevels
/// need to add variable labels

esttab m1, b(3) compress ///
		se label replace cells(b(fmt(4) star) noommited ///
		se(par)) starlevels(* .01) rename([adoption]_cons constant) ///
		varwidth(30) mlabels(, none) collabels(, none) eqlabels(, none) ///
		interaction(X) nobaselevels
/// too speed up analysis, we will only keep Iowa and Missouri 
//// for the models, margins can take a while
/// note you should never plot predict probs for insigificant interaction
logit vote income educ male i.married##c.age black latino republicanid conserveid ///
employed if state=="IA" [pw=commonweight_vv] 
estimates store Iowa
margins married, at(age=(18(10)78))
marginsplot, name(Iowa, replace) title(Iowa) ytitle(Probability of Voting)  recastci(rarea) 
margins, dydx(married) at(age=(18(10)78))
marginsplot, name(dydxIowa, replace) title(Effect of Marriage on the Probability of Voting by Age) ///
ytitle(Probability Voting)  recastci(rarea) yline(0)

logit vote income educ male i.married##c.age black latino republicanid conserveid ///
employed if state=="MO" [pw=commonweight_vv] 
estimates store Missouri
margins married, at(age=(18(10)78))
marginsplot, name(Missouri, replace) ytitle(Probability of Voting) title(Missouri) recastci(rarea) 

graph combine Iowa Missouri, ycommon


esttab Iowa Missouri, b(3) compress ///
		se label replace cells(b(fmt(4) star) noommited ///
		se(par)) starlevels(* .01) rename([adoption]_cons constant) ///
		varwidth(30) mlabels(Iowa Missouri) collabels(, none) eqlabels(, none) ///
		interaction(X) nobaselevels
		
log close

