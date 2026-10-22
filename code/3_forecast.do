***************************************
***		03 VAR Model Forecast		***
***************************************

/*
	- Estimate a six-variable VAR, forecast inflation, and study how
	  inflation responds to a policy rate shock.
	- Inputs: final_merged.dta, lag-selection and stability
	- Outputs: VAR Model specifications and forecasting
		- VAR Model Lag Selection Table (pdf)
		- VAR Model Stability, Unit Root Test (pdf)
		- VAR Model Inflation Forecast (pdf)
		- VAR Model Impulse Response Function (pdf)
		- VAR Model Forecast Error Variance Decomposition (pdf)
*/

clear all
set more off

// 0. Set File Directories

global data			"../2_Data"
global tables		"../4_Output/Tables"
global figures		"../4_Output/Figures"

// 1. Import Datasets

use "$data/final_merged.dta", clear

local var_list output_gap com_growth unemp_rate ifl_trim pol_rate breakeven

// Rescale from decimals to percent so results read in percentage points
foreach var of local var_list {
	replace `var' = `var' * 100
}

// 2. OPTIMAL LAG SELECTION

varsoc `var_list', maxlag(6)
matrix model_lagsel = r(stats)
esttab matrix(model_lagsel) using "$tables/varsoc_model.tex", replace

// 3. MODEL SPECIFICATION

// preserve/restore: fcast adds forecast periods to the dataset

preserve
var `var_list', lags(1)

varstable, graph
graph export "$figures/unit_root.pdf", replace

// 4. FORECAST

/* 
	- Forecast horizon is 8 quarters (2 years) ahead of the start date
	- No out-of-sample evaluation or rolling window test
*/

fcast compute f_, step(8)
fcast graph f_ifl_trim
graph export "$figures/ifl_trim_forecast.pdf", replace

// 5. IMPULSE RESPONSES AND VARIANCE DECOMPOSITION

/* 
	- Tests a one standard deviation orthogonalised policy rate shock
	- Inflation falls within the quarter to policy shocks
*/

irf create model, set(m4airfs, replace) step(8)

irf graph oirf, impulse(pol_rate) response(ifl_trim) ///
	title("Response of Inflation to a Policy Hike") ///
	ytitle("Percentage Points") xtitle("Quarters after Shock") ///
	ciopts(color(navy%20) lcolor(navy%40)) ///
	subtitle("") note("") ///
	name(irf_pol_ifl, replace)
graph export "$figures/irf_pol_ifl_model.pdf", replace

irf graph fevd
graph export "$figures/irf_fevd_model.pdf", replace

restore
