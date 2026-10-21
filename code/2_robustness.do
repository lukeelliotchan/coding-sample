***********************************
***		02 Data Robustness		***
***********************************

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

matrix dfuller_results = J(1, 5, .)
matrix colnames dfuller_results = lags N Zt Zt_trend pvalue
local rownames ""

foreach var of local var_list {
	
    tsline `var'
    graph export "$figures/`var'_tsline.pdf", replace

    varsoc `var', maxlag(6)
    matrix `var'_lagsel = r(stats)
    esttab matrix(`var'_lagsel) using "$tables/varsoc_`var'.tex", replace

    // Pick the SBIC-optimal lag
    matrix M = `var'_lagsel
    local nrows   = rowsof(M)
    local sbiccol = colsof(M)
    local best_lag = 0
    local best_val = M[1, `sbiccol']
    forvalues i = 2/`nrows' {
        if M[`i', `sbiccol'] < `best_val' & M[`i', `sbiccol'] < . {
            local best_val = M[`i', `sbiccol']
            local best_lag = `i' - 1
        }
    }

    // Dickey-Fuller, no trend
    dfuller `var', lags(`best_lag')
    local N  = r(N)
    local Zt = r(Zt)
    capture local pval = r(p)
    if _rc != 0 local pval = .

    // Dickey-Fuller, with trend
    dfuller `var', lags(`best_lag') trend
    local Zt_trend = r(Zt)

    matrix dfuller_results = dfuller_results \ (`best_lag', `N', `Zt', `Zt_trend', `pval')
    local rownames "`rownames' `var'"
}

matrix dfuller_results = dfuller_results[2...,1...] 
matrix rownames dfuller_results = `rownames'
matrix list dfuller_results

esttab matrix(dfuller_results) using "$tables/dfuller_results.tex", replace
