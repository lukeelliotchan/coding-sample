**************************************
**		01 Cleaning & Merging		**
**************************************

clear all
set more off

// 0. Set File Directories

global data			"../2_Data"
global dta			"$data/dta"

// 1. Import and Clean Datasets

// Output Gap //
import delimited "$data/gdp_growth", clear varnames(1)
keep if vector == "v65201210"
gen qdate = qofd(dofm(monthly(ref_date, "YM")))
format qdate %tq

collapse (mean) value, by(qdate)
tsset qdate
gen ln_gdp = ln(value)
tsfilter hp output_gap = ln_gdp, smooth(1600)

keep qdate output_gap
save "$dta/output_gap.dta", replace
clear

// Commodity Prices //
import delimited "$data/commodity_index", clear varnames (21)
gen qdate = qofd(dofm(mofd(date(date, "YMD"))))
format qdate %tq

gen com = (mbcpi/mbcpi[_n-1] - 1) * 100
gen g = 1 + com/100
by qdate, sort: egen com_growth = total(ln(g))
replace com_growth = (exp(com_growth) - 1)
collapse (mean) com_growth, by(qdate)

keep qdate com_growth
save "$dta/com_growth.dta", replace
clear

// Unemployment //
import delimited "$data/laborforce", clear varnames(1)
keep if vector == "v2062815"
gen qdate = qofd(dofm(monthly(ref_date, "YM")))
format qdate %tq

rename value unemp_rate
replace unemp_rate = unemp_rate/100
collapse (mean) unemp_rate, by(qdate)

keep qdate unemp_rate
save "$dta/unemp_rate.dta", replace

// Inflation Rate //
import delimited "$data/inflation", clear varnames(1)
keep if vector == "v108785715"
gen qdate = qofd(dofm(monthly(ref_date, "YM")))
format qdate %tq

rename value ifl_trim
replace ifl_trim = ifl_trim/100
collapse (mean) ifl_trim, by(qdate)

keep qdate ifl_trim
save "$dta/ifl_trim.dta", replace
clear

// Policy Rate //
import delimited "$data/target_policy_rate", clear varnames(9)
gen qdate = qofd(dofm(mofd(date(date, "YMD"))))
format qdate %tq

rename static_atable_v39079 pol_rate
destring pol_rate, replace force
replace pol_rate = pol_rate/100

collapse (mean) pol_rate, by(qdate)
save "$dta/pol_rate.dta", replace
clear

// Breakeven Inflation //
import delimited "$data/bond_yields_breakeven", clear varnames(10)

gen ddate = date(date, "YMD")
format ddate %td

ds date ddate, not
local nominal : word 1 of `r(varlist)'
local real    : word 2 of `r(varlist)'
rename `nominal' nom_yld
rename `real' rrb_yld
destring nom_yld rrb_yld, replace force

gen breakeven = nom_yld - rrb_yld
replace breakeven = breakeven/100

gen qdate = qofd(dofm(mofd(ddate)))
format qdate %tq
collapse (mean) breakeven, by(qdate)

save "$dta/breakeven.dta", replace
clear

// 2. MERGE DATASETS

use "$dta/output_gap.dta", clear
merge 1:1 qdate using "$dta/com_growth.dta"
drop _merge
merge 1:1 qdate using "$dta/unemp_rate.dta"
drop _merge
merge 1:1 qdate using "$dta/pol_rate.dta"
drop _merge
merge 1:1 qdate using "$dta/ifl_trim.dta"
drop _merge
merge 1:1 qdate using "$dta/breakeven.dta"
drop _merge
tsset qdate

keep if qdate >= tq(2000q4)
keep if qdate <= tq(2026q2)

label variable qdate			"Quarter"
label variable output_gap		"Gap"
label variable com_growth		"Commodities"
label variable unemp_rate		"Unemployment"
label variable ifl_trim			"Inflation"
label variable pol_rate			"Policy Rate"
label variable breakeven		"Breakeven"

save "$data/final_merged.dta", replace
