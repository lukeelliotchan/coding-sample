***************************************
***		03 VAR Model Forecast		***
***************************************

clear all
set more off

// 0. Set File Directories

global BoC			"~/Desktop/BoC"
global data			"$BoC/Summer/2_Data"
global tables		"$BoC/Summer/4_Output/Tables"
global figures		"$BoC/Summer/4_Output/Figures"

// 1. Import Datasets

use "$data/final_merged.dta", clear

local var_list output_gap com_growth unemp_rate ifl_trim pol_rate breakeven

foreach var of local var_list {
	replace `var' = `var' * 100
}

// 2. OPTIMAL LAG SELECTION

varsoc output_gap com_growth unemp_rate ifl_trim pol_rate breakeven, maxlag(6) 
matrix model_lagsel = r(stats)
esttab matrix(model_lagsel) using "$tables/varsoc_model.tex", replace


// 3. MODEL SPECIFICATION

preserve
var output_gap com_growth unemp_rate ifl_trim pol_rate breakeven, lags(1) 

varstable, graph
graph export "$figures/unit_root.pdf", replace

fcast compute f_, step(8)
fcast graph f_ifl_trim
graph export "$figures/ifl_trim_forecast.pdf", replace

irf create model, set(m4airfs, replace) step(8)

irf graph oirf, impulse(pol_rate) response(ifl_trim) ///
	title("Response of Inflation to a Policy Hike") ///
	ytitle("Percentage Points") xtitle("Quarters after Shock") ///
	ciopts(color(navy%20) lcolor(navy%40)) ///
	subtitle("") note("") ///
	name(irf_pol_ifl, replace)
graph export "$figures/irf_pol_ifl_model.pdf", replace

irf graph fevd, impulse(output_gap com_growth unemp_rate ifl_trim pol_rate breakeven) response(output_gap com_growth unemp_rate ifl_trim pol_rate breakeven)
graph export "$figures/irf_fevd_model.pdf", replace

restore