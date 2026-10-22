***************************************
***		03 VAR Model Forecast		***
***************************************

/* COMMENTS (replace the prompts with your own notes)
	- Purpose: estimate a six-variable VAR, forecast inflation, and study how
	  inflation responds to a policy rate shock.
	- Inputs / Outputs: final_merged.dta in; lag-selection table (tex) and
	  stability, forecast, impulse response and variance decomposition graphs (pdf) out.
	- Requirements: esttab (from the estout package, ssc install estout).
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

/* COMMENTS
	- Which criterion is used (SBIC) and what the others say (AIC prefers more lags).
	- Trade-off: with six variables each extra lag adds 36 coefficients, so a short
	  lag length keeps the model parsimonious on a sample of about 100 quarters.
	- The var command below hard-codes lags(1), the SBIC choice in the table; update
	  it if the data or sample change.
*/
varsoc `var_list', maxlag(6)
matrix model_lagsel = r(stats)
esttab matrix(model_lagsel) using "$tables/varsoc_model.tex", replace

// 3. MODEL SPECIFICATION

/* COMMENTS
	- Variable ordering: the ordering matters for orthogonalised impulse responses
	  (Cholesky decomposition). Explain why policy rate is placed after inflation
	  and output (it reacts to them within the quarter) and before breakeven.
	- Stability: the eigenvalue graph checks that all roots lie inside the unit
	  circle, which is required for the forecasts and impulse responses to be valid.
	  (The file is named unit_root.pdf; say what it shows.)
*/

// preserve/restore: fcast adds forecast periods to the dataset
preserve
var `var_list', lags(1)

varstable, graph
graph export "$figures/unit_root.pdf", replace

// 4. FORECAST

/* COMMENTS
	- Forecast horizon: 8 quarters (2 years) ahead, and the start date.
	- Say whether the forecast is conditional on anything, and how to read the
	  confidence bands.
	- Possible caveat: no out-of-sample evaluation in this file.
*/
fcast compute f_, step(8)
fcast graph f_ifl_trim
graph export "$figures/ifl_trim_forecast.pdf", replace

// 5. IMPULSE RESPONSES AND VARIANCE DECOMPOSITION

/* COMMENTS
	- Shock: a one standard deviation orthogonalised policy rate shock.
	- Interpretation: direction and timing of the inflation response over 8 quarters
	  (e.g. does inflation fall? does a price puzzle appear?).
	- Variance decomposition: what share of inflation forecast error variance each
	  shock explains.
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
