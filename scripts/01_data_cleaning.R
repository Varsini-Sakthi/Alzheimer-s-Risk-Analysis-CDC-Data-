## ============================================================================
## 01_data_cleaning.R
## Loads raw synthetic BRFSS SCD file, handles missingness, encodes factors,
## engineers derived variables, and writes an analysis-ready dataset.
## ============================================================================

## NOTE: run this script from the project root directory, e.g.:
##   cd alzheimers-risk-project
##   Rscript scripts/01_data_cleaning.R
## All paths below are relative to the project root.

df <- read.csv("data/brfss_scd_synthetic_2015_2020.csv", stringsAsFactors = FALSE)

cat("========== RAW DATA SUMMARY ==========\n")
cat("N respondents:", nrow(df), "\n")
cat("Survey years:", paste(range(df$survey_year), collapse = "-"), "\n")
cat("States/territories:", length(unique(df$state)), "\n\n")

cat("Missingness by column (%):\n")
miss <- sort(round(colMeans(is.na(df)) * 100, 2), decreasing = TRUE)
print(miss[miss > 0])

## --- Missing data handling -------------------------------------------------
## Missingness here is <5% per field and unrelated to the outcome by
## construction (MCAR) - complete-case analysis is appropriate and is the
## approach documented in the CDC MMWR SCD analyses. For income (an ordinal
## covariate used in modeling) we retain a "Missing" category rather than
## drop rows, to avoid discarding otherwise-complete records - a standard
## BRFSS analytic convention for categorical survey items.
df$income_bracket[is.na(df$income_bracket)] <- "Missing"
df <- df[!is.na(df$hearing_loss) & !is.na(df$sleep_lt7hrs), ]

cat("\nN after complete-case restriction on binary items:", nrow(df), "\n")

## --- Factor encoding --------------------------------------------------------
df$age_group       <- factor(df$age_group, levels = c("45-54","55-64","65-74","75+"))
df$sex             <- factor(df$sex, levels = c("Male","Female"))
df$race_ethnicity  <- factor(df$race_ethnicity,
                        levels = c("White","Black","Hispanic","Asian","AIAN","Multiracial","Other"))
df$education       <- factor(df$education,
                        levels = c("Less than HS","HS graduate","Some college","College graduate+"))
df$income_bracket  <- factor(df$income_bracket,
                        levels = c("<$25,000","$25,000-$49,999","$50,000-$74,999","$75,000+","Missing"))

## --- Derived / engineered variables ----------------------------------------
df$age_group <- relevel(df$age_group, ref = "45-54")
df$education <- relevel(df$education, ref = "College graduate+")   # highest educ as reference
df$income_bracket <- relevel(df$income_bracket, ref = "$75,000+")

df$comorbidity_burden <- factor(
  ifelse(df$chronic_disease_count == 0, "0",
  ifelse(df$chronic_disease_count == 1, "1",
  ifelse(df$chronic_disease_count == 2, "2", "3+"))),
  levels = c("0","1","2","3+"))

df$modifiable_risk_score <- with(df,
  depression + current_smoker + physically_inactive + social_isolation +
  binge_drinking + sleep_lt7hrs + hearing_loss)

df$outcome <- df$subjective_cognitive_decline   # explicit modeling alias

write.csv(df, "outputs/tables/analysis_ready_data.csv", row.names = FALSE)
saveRDS(df, "outputs/tables/analysis_ready_data.rds")

cat("\nFinal analysis-ready N:", nrow(df), "\n")
cat("Outcome prevalence:", round(mean(df$outcome) * 100, 2), "%\n")
cat("Saved: outputs/tables/analysis_ready_data.csv (+ .rds)\n")
