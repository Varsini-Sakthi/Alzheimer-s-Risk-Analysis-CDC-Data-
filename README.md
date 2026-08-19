# Predicting Risk of Subjective Cognitive Decline (SCD)
### A Multivariable Logistic Regression Analysis of Six Years of CDC BRFSS Cognitive Decline Module Data (2015–2020)

**Healthcare Data Analyst Portfolio Project | R | Logistic Regression | Population Health Risk Stratification**

---

## Overview

This project applies multivariable logistic regression in **R** to six years (2015–2020) of respondent-level
data structured on the CDC's **Behavioral Risk Factor Surveillance System (BRFSS) Cognitive Decline module**
to identify independent predictors of **subjective cognitive decline (SCD)** — a self-reported early warning
sign of Alzheimer's disease and related dementias — and to translate the model into an actionable population
risk-stratification tool with concrete public health recommendations.

**Read the full report:** [`report/Alzheimers_SCD_Risk_Analysis_Report.docx`](report/Alzheimers_SCD_Risk_Analysis_Report.docx)

## ⚠️ Data disclosure

CDC does not distribute identifiable BRFSS microdata through open, unauthenticated channels. This project uses
a **calibrated simulation**: a defined logistic data-generating process produces respondent records whose
*marginal prevalence rates* are anchored to figures published in the peer-reviewed and CDC MMWR literature for
the real Cognitive Decline module (11.2% overall SCD prevalence 2015–16, 13.8% among adults living alone, 15.2%
among adults with chronic disease, etc. — see `data/00_generate_synthetic_brfss_data.R` for full citations and
calibration targets). Every statistical method, diagnostic, and line of downstream code is identical to what
would be applied to authentic microdata obtained under a CDC data use agreement. This is disclosed prominently
in the report itself (Section 2.1) — this is a methods/skills demonstration, not a substitute for peer-reviewed
epidemiological findings.

## Key results

| Metric | Value |
|---|---|
| Analytic sample | N = 43,436 adults, 45+, pooled 2015–2020 |
| Overall SCD prevalence | 12.5% |
| Test-set AUC | 0.711 |
| 10-fold CV AUC | 0.687 ± 0.01 |
| Brier score | 0.102 |
| Top modifiable risk factor (PAR%) | Depression — 11.8% of population SCD burden |
| High/Very-High risk tier | 31.2% of population, 6× the SCD rate of the Low tier |

## Repository structure

```
alzheimers-risk-project/
├── data/
│   ├── 00_generate_synthetic_brfss_data.R    # calibrated dataset construction (documented sources)
│   └── brfss_scd_synthetic_2015_2020.csv     # generated respondent-level dataset
├── scripts/
│   ├── 01_data_cleaning.R                    # missingness, encoding, feature engineering
│   ├── 02_exploratory_analysis.R             # Table 1, chi-square tests, Figures 1-3
│   ├── 03_logistic_regression_model.R        # AIC selection, VIF, odds ratios, Figure 4
│   ├── 04_model_diagnostics_validation.R     # ROC/AUC, cross-validation, calibration, Figures 5-6
│   └── 05_risk_stratification_recommendations.R  # risk tiers, PAR analysis, Figures 7-8
├── outputs/
│   ├── figures/    # all 8 generated PNG figures
│   └── tables/     # all generated CSV tables + saved R model objects
└── report/
    ├── Alzheimers_SCD_Risk_Analysis_Report.docx   # full 19-page technical report
    └── build_report.js                            # report generation script
```

## Reproducing the analysis

Requires R (base installation only — no third-party packages):

```bash
Rscript data/00_generate_synthetic_brfss_data.R
Rscript scripts/01_data_cleaning.R
Rscript scripts/02_exploratory_analysis.R
Rscript scripts/03_logistic_regression_model.R
Rscript scripts/04_model_diagnostics_validation.R
Rscript scripts/05_risk_stratification_recommendations.R
```

All ROC/AUC and VIF diagnostics are implemented from first principles (no `pROC`, `car`, `dplyr`, or `ggplot2`),
so the pipeline runs on any standard R installation.

## Methods summary

- **Design:** Pooled cross-sectional, 2015–2020
- **Outcome:** Subjective cognitive decline (binary, BRFSS-defined)
- **Predictors:** Demographics, chronic disease burden, and modifiable behavioral/social risk factors
- **Model:** Multivariable logistic regression, backward AIC selection, 75/25 train/test split, 10-fold CV
- **Validation:** ROC/AUC, Brier score, decile calibration, VIF multicollinearity screening
- **Translation:** 4-tier risk stratification + Population Attributable Risk (PAR%) analysis for modifiable factors

## Skills demonstrated

Logistic regression & GLM diagnostics · epidemiological study design · missing data handling · model selection
(AIC) · cross-validation · ROC/calibration analysis · population attributable risk · public-health translation
of statistical findings · reproducible R programming without third-party dependencies.
