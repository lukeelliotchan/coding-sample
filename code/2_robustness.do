***********************************
***		02 Data Robustness		***
***********************************

/* 
	- Check that each series is stationary before it enters the VAR, key assumption
	- Inputs: final_merged.dat from 1_cleaning.do
	- Outputs: figures and tables for data robustness
		- Variable time-series plots (pdf)
		- Variable lag-selection tables (tex)
		- Dickey-Fuller test table (tex)
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

/*
	- Stationarity is necessary for VARs, otherwise you can have spurious results
	- Procedure per variable: (1) plot the series, (2) choose the lag length by SBIC,
	  (3) run the augmented Dickey-Fuller test with that many lags, with and without
	  a trend.
	- SBIC is used to keep the model parsimonious
	- Reading output, null is a unit root, so large negative Zt rejects it
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
