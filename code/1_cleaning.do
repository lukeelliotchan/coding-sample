**************************************
**		01 Cleaning & Merging		**
**************************************

/* 
- This do file cleans, transforms, and merges raw data into a single quartlery data set
- Inputs: datasets collected from the Bank of Canada or StatsCanada
	- gdp_growth.csv: Gross domestic product (GDP) at basic prices, by industry, monthly, growth rates - StatsCanada
	- commodity_index.csv: Bank of Canada Commodity price index, monthly - Bank of Canada
	- laborforce.csv: Canadian Labour Force Survey seasonally adjusted, monthly - StatsCanada
	- inflation.csv: Key inflation indicators and the target range, monthly - Bank of Canada
	- target_policy_rate.csv: Overnight rate target (end of month) and Overnight rate - Bank of Canada
	- bond_yields_breakeven.csv: Long-term benchmark bond yields and Canadian real return bond yields - Bank of Canada Valet API
- Outputs: final_merged.dta for testing, analysis, and forecasting
*/

clear all
set more off

// 0. Set File Directories

global data			"../2_Data"
global dta			"$data/dta"

// 1. Import and Clean Datasets

/* 
	- Every series is converted into a quarterly date and collapsed into quarterly averages
	- Rates are kept in decimla rather than percent for consistency across datasets
*/

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

// Commodity Prices //
import delimited "$data/commodity_index", clear varnames(21)
gen qdate = qofd(date(date, "YMD"))
format qdate %tq

gen ln_growth = ln(mbcpi/mbcpi[_n-1])
collapse (sum) ln_growth, by(qdate)
gen com_growth = exp(ln_growth) - 1

keep qdate com_growth
save "$dta/com_growth.dta", replace

// Unemployment //
import delimited "$data/laborforce", clear varnames(1)
keep if vector == "v2062815"
gen qdate = qofd(dofm(monthly(ref_date, "YM")))
format qdate %tq

rename value unemp_rate
replace unemp_rate = unemp_rate/100
collapse (mean) unemp_rate, by(qdate)

save "$dta/unemp_rate.dta", replace

// Inflation Rate //
import delimited "$data/inflation", clear varnames(1)
keep if vector == "v108785715"
gen qdate = qofd(dofm(monthly(ref_date, "YM")))
format qdate %tq

rename value ifl_trim
replace ifl_trim = ifl_trim/100
collapse (mean) ifl_trim, by(qdate)

save "$dta/ifl_trim.dta", replace

// Policy Rate //
import delimited "$data/target_policy_rate", clear varnames(9)
gen qdate = qofd(date(date, "YMD"))
format qdate %tq

rename static_atable_v39079 pol_rate
destring pol_rate, replace force
replace pol_rate = pol_rate/100

collapse (mean) pol_rate, by(qdate)
save "$dta/pol_rate.dta", replace

// Breakeven Inflation //
import delimited "$data/bond_yields_breakeven", clear varnames(10)
gen qdate = qofd(date(date, "YMD"))
format qdate %tq

ds date qdate, not
local nominal : word 1 of `r(varlist)'
local real    : word 2 of `r(varlist)'
rename `nominal' nom_yld
rename `real' rrb_yld
destring nom_yld rrb_yld, replace force

gen breakeven = (nom_yld - rrb_yld)/100
collapse (mean) breakeven, by(qdate)

save "$dta/breakeven.dta", replace

// 2. MERGE DATASETS

/* 
	- Merge key: qdate with one observation per quarter in every file
	- Sample window: from 2000q4 to 2026q2, the first quarter with data for all
	  six series; last quarter available).
*/

use "$dta/output_gap.dta", clear
foreach var in com_growth unemp_rate pol_rate ifl_trim breakeven {
	merge 1:1 qdate using "$dta/`var'.dta", nogenerate
}
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
