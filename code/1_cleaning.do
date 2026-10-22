**************************************
**		01 Cleaning & Merging		**
**************************************

/* COMMENTS (replace the prompts with your own notes)
	- Purpose: one line on what this file does (turns raw Bank of Canada / Statistics
	  Canada downloads into one quarterly dataset for the VAR).
	- Inputs: list the raw csv files and which series (vector IDs) are used.
	- Outputs: final_merged.dta (one row per quarter, six variables) plus one
	  intermediate .dta per variable.
	- Requirements: Stata version, and that the do-file is run from its own folder
	  (paths are relative).
*/

clear all
set more off

// 0. Set File Directories

global data			"../2_Data"
global dta			"$data/dta"

// 1. Import and Clean Datasets

/* COMMENTS
	- Common steps: every series is converted to a quarterly date (qdate) and
	  collapsed to a quarterly average, so all six series share one frequency.
	- Units: say why rates are divided by 100 (percent -> decimal).
*/

// Output Gap //
/* COMMENTS
	- Why the gap is estimated (the gap itself is not observed) and why an HP filter
	  with smoothing 1600 (the standard value for quarterly data).
	- Mention that the HP filter is two-sided, so the gap is revised as data arrive
	  and is least reliable at the end of the sample.
*/
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
/* COMMENTS
	- Which index (Bank of Canada commodity price index, total) and its frequency
	  (monthly).
	- Why monthly growth rates are compounded within the quarter to get quarterly
	  growth, rather than averaging the index level.
*/
import delimited "$data/commodity_index", clear varnames(21)
gen qdate = qofd(date(date, "YMD"))
format qdate %tq

gen ln_growth = ln(mbcpi/mbcpi[_n-1])
collapse (sum) ln_growth, by(qdate)
gen com_growth = exp(ln_growth) - 1

keep qdate com_growth
save "$dta/com_growth.dta", replace

// Unemployment //
/* COMMENTS
	- Series used (unemployment rate; seasonally adjusted?) and its source table.
*/
import delimited "$data/laborforce", clear varnames(1)
keep if vector == "v2062815"
gen qdate = qofd(dofm(monthly(ref_date, "YM")))
format qdate %tq

rename value unemp_rate
replace unemp_rate = unemp_rate/100
collapse (mean) unemp_rate, by(qdate)

save "$dta/unemp_rate.dta", replace

// Inflation Rate //
/* COMMENTS
	- Why CPI-trim (a core measure that strips out volatile components) and what
	  the series measures (year-over-year percent change?).
*/
import delimited "$data/inflation", clear varnames(1)
keep if vector == "v108785715"
gen qdate = qofd(dofm(monthly(ref_date, "YM")))
format qdate %tq

rename value ifl_trim
replace ifl_trim = ifl_trim/100
collapse (mean) ifl_trim, by(qdate)

save "$dta/ifl_trim.dta", replace

// Policy Rate //
/* COMMENTS
	- Which rate (the Bank of Canada target for the overnight rate) and why the
	  quarterly mean is used.
	- Why destring with the force option (non-numeric entries become missing).
*/
import delimited "$data/target_policy_rate", clear varnames(9)
gen qdate = qofd(date(date, "YMD"))
format qdate %tq

rename static_atable_v39079 pol_rate
destring pol_rate, replace force
replace pol_rate = pol_rate/100

collapse (mean) pol_rate, by(qdate)
save "$dta/pol_rate.dta", replace

// Breakeven Inflation //
/* COMMENTS
	- Definition: nominal bond yield minus real return bond yield, a market-based
	  measure of expected inflation.
	- Why the two yield columns are picked by position (the csv column names are
	  long and unwieldy).
*/
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

/* COMMENTS
	- Merge key: qdate, one observation per quarter in every file (hence 1:1).
	- Sample window: why 2000q4 to 2026q2 (e.g. first quarter with data for all
	  six series; last quarter available).
	- Missing values: note whether any remain after the merge and how they are
	  handled.
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
