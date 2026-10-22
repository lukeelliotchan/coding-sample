***********************************
***		02 Data Robustness		***
***********************************

/* COMMENTS (replace the prompts with your own notes)
	- Purpose: check that each series is stationary before it enters the VAR.
	- Inputs / Outputs: final_merged.dta in; time-series plots (pdf) and lag-selection
	  and Dickey-Fuller tables (tex) out.
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

// 2. Stationarity Checks

/* COMMENTS
	- Why stationarity matters: a VAR in levels needs stationary variables, and
	  non-stationary series can give spurious relationships.
	- Procedure per variable: (1) plot the series, (2) choose the lag length by SBIC,
	  (3) run the augmented Dickey-Fuller test with that many lags, with and without
	  a trend.
	- Why SBIC (it penalises extra lags more heavily than AIC, so it picks a
	  smaller model).
	- How to read the table: null is a unit root, so a large negative Zt (small
	  p-value) rejects it. The pvalue column is for the no-trend test.
	- Results: which series are borderline (e.g. inflation and breakeven fail to
	  reject at 5%) and what you did about it.
*/

matrix dfuller_results = J(1, 5, .)
matrix colnames dfuller_results = lags N Zt Zt_trend pvalue
local rownames ""

foreach var of local var_list {

	tsline `var'
	graph export "$figures/`var'_tsline.pdf", replace

	varsoc `var', maxlag(6)
	matrix `var'_lagsel = r(stats)
	esttab matrix(`var'_lagsel) using "$tables/varsoc_`var'.tex", replace

	// Pick the SBIC-optimal lag (SBIC is the last column of the table)
	local sbiccol = colsof(`var'_lagsel)
	local best_lag = 0
	local best_val = `var'_lagsel[1, `sbiccol']
	forvalues i = 2/`=rowsof(`var'_lagsel)' {
		if `var'_lagsel[`i', `sbiccol'] < `best_val' {
			local best_val = `var'_lagsel[`i', `sbiccol']
			local best_lag = `i' - 1
		}
	}

	// Dickey-Fuller, no trend
	dfuller `var', lags(`best_lag')
	local N  = r(N)
	local Zt = r(Zt)
	local pval = r(p)

	// Dickey-Fuller, with trend
	dfuller `var', lags(`best_lag') trend
	local Zt_trend = r(Zt)

	matrix dfuller_results = dfuller_results \ (`best_lag', `N', `Zt', `Zt_trend', `pval')
	local rownames "`rownames' `var'"
}

// Drop the placeholder first row
matrix dfuller_results = dfuller_results[2..., 1...]
matrix rownames dfuller_results = `rownames'
matrix list dfuller_results

esttab matrix(dfuller_results) using "$tables/dfuller_results.tex", replace
