version 14
set more off
clear
  quietly log
log using lacombe-intro.txt, text replace

/*	***************************************************************	*/
/* 	Author:		Scott LaCombe										*/
/*	Date:		January 2018											*/
/*  File:		lacombe-intro2.do	       		 		*/						*/
/*	Purpose:	Modeling and Data Visualiation		*/
/*	Input files: lacombe_cces					*/
/*	***************************************************************	*/

///check working directory, set to right place if needed
/// try to avoid filepaths that are too long, makes replication hard
/// read in dataset from 

/// obviously, change the name to whatever you're cleaned up data was yesterday

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

/// helpful visualizations

hist income, discrete percent norm

hist age, norm percent

/// let's model turnout, multiple ways to show
logit vote married income educ latino male black age republicanid conserveid ///
employed [pw=commonweight_vv]
estimates store m1

/// standard table
esttab m1, b(3) compress ///
		se label replace cells(b(fmt(4) star) noommited ///
		se(par)) starlevels(* .01) rename([adoption]_cons constant) ///
		varwidth(30) mlabels(, none) collabels(, none) eqlabels(, none) ///
		interaction(X) nobaselevels
		
/// lets try it in LaTEX now
/// open up this file in notepad, then copy and past to your favorite latex editor
esttab m1 using lacombe-first.tex, b(3) compress ///
		se label replace cells(b(fmt(4) star) noommited ///
		se(par)) starlevels(* .01) rename([adoption]_cons constant) ///
		varwidth(30) mlabels(Vote) collabels(, none) eqlabels(, none) ///
		interaction(X) nobaselevels
		
/// other way to visualize model
ssc install coefplot, replace

coefplot m1, xline(0) title(Modeling Turnout in 2016 Election) xtitle("Coefficient Estimate")

/// we don't care about the constant that much, so maybe just include a footnote 
/// in latex and omit it from coef plot, that way we can see differences more
coefplot m1, xline(0) title(Modeling Turnout in 2016 Election) xtitle("Coefficient Estimate") drop(_cons)

/// lets get a bit fancier and compare states
estimates drop _all

logit vote married income educ latino male black age republicanid conserveid ///
employed if state=="IA"[pw=commonweight_vv]
estimates store m1


logit vote married income educ latino male black age republicanid conserveid ///
employed if state=="MO"[pw=commonweight_vv]
estimates store m2


coefplot (m1, label(Iowa)) (m2, label(Missouri)), xline(0) ///
xtitle("Coefficient Estimate") title(Modeling Turnout in 2016 Election) ///
 drop(_cons)
 
 
 /// back to interactions
 estimates drop _all
 logit vote i.married##c.age
 
estimates store m1
margins married, at(age=(18(10)78))
marginsplot, name(prob, replace) title(Effect of Age by Marital Status) ytitle(Probability of Voting)  recastci(rarea) 
graph export prob.pdf, as(pdf) replace
margins, dydx(married) at(age=(18(10)78))
marginsplot, name(dydx, replace) title(Effect of Marriage on the Probability of Voting by Age) ///
ytitle(Probability Voting)  recastci(rarea) yline(0)

/// let's move to latex, see how to make nicer models


/// if we have time' lets go back to looking at how to deal with missing cases
/// in other ways

recode faminc (1=1 "Less than $10,000") (2=2 "$10,000-$19,999") ///
(3=3 "$20,000-$29,999")(4=4 "$30,000-$39,999") (5=5 "$40,000-$49,999") ///
 (6=6 "$50,000- $59,999") (7=7 "$60,000-$69,999") (8=8 "$70,000- $79,999") ///
 (9=9 "$80,000-$99,999") (10=10 "$100,000-$119,999") ///
 (11=11 "$120,000-$149,999") (12=12 "$150,000 or more") (13/32=12) ///
 (97=.), gen(income2)
recode income2 .=0

gen miss_inc=1 if income2==0 
recode miss_inc .=0


/// we have now accounted for the missing cases without assuming anything about them
logit vote married income2 educ latino male black age republicanid conserveid ///
employed miss_inc [pw=commonweight_vv]
