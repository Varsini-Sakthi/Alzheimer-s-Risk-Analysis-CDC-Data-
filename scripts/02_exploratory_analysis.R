## ============================================================================
## 02_exploratory_analysis.R
## Descriptive epidemiology: prevalence trends, subgroup rates, bivariate
## association testing, and Table 1 (demographic characteristics).
## ============================================================================

## NOTE: run this script from the project root directory, e.g.:
##   cd alzheimers-risk-project
##   Rscript scripts/02_exploratory_analysis.R
## All paths below are relative to the project root.

df <- readRDS("outputs/tables/analysis_ready_data.rds")

col_primary <- "#2C5F7C"; col_accent <- "#C1502E"; col_grid <- "#E5E5E5"

## --- Table 1: characteristics by SCD status --------------------------------
make_row <- function(varname, label) {
  tab <- table(df[[varname]], df$outcome)
  props <- prop.table(tab, 1)[, "1"] * 100
  data.frame(Variable = label, Level = rownames(tab),
             N = as.integer(rowSums(tab)),
             SCD_Prevalence_Pct = round(props, 1))
}
table1 <- do.call(rbind, list(
  make_row("age_group", "Age group"),
  make_row("sex", "Sex"),
  make_row("race_ethnicity", "Race/Ethnicity"),
  make_row("education", "Education"),
  make_row("income_bracket", "Income"),
  make_row("comorbidity_burden", "Chronic condition count")
))
write.csv(table1, "outputs/tables/table1_descriptive.csv", row.names = FALSE)
cat("Table 1 written.\n"); print(table1)

## --- Chi-square tests of association ---------------------------------------
vars <- c("age_group","sex","race_ethnicity","education","income_bracket",
          "living_alone","diabetes","hypertension","heart_disease","stroke_history",
          "depression","hearing_loss","current_smoker","physically_inactive",
          "social_isolation","comorbidity_burden")
chi_results <- data.frame(Variable = character(), ChiSq = numeric(), df = integer(), p_value = character())
for (v in vars) {
  t <- table(df[[v]], df$outcome)
  test <- suppressWarnings(chisq.test(t))
  chi_results <- rbind(chi_results, data.frame(
    Variable = v, ChiSq = round(unname(test$statistic), 1), df = unname(test$parameter),
    p_value = ifelse(test$p.value < 0.001, "<0.001", formatC(test$p.value, digits = 3, format = "f"))))
}
write.csv(chi_results, "outputs/tables/bivariate_chisq_tests.csv", row.names = FALSE)
cat("\nBivariate chi-square tests:\n"); print(chi_results)

## --- Figure 1: SCD prevalence trend by year --------------------------------
yr_prev <- aggregate(outcome ~ survey_year, df, mean)
png("outputs/figures/fig1_prevalence_trend.png", width = 1400, height = 950, res = 170)
par(mar = c(4.5, 5, 3, 2))
plot(yr_prev$survey_year, yr_prev$outcome * 100, type = "o", pch = 19, lwd = 2.5,
     col = col_primary, cex = 1.4, xlab = "Survey Year",
     ylab = "SCD Prevalence (%)",
     main = "Subjective Cognitive Decline Prevalence, 2015-2020\n(Adults 45+, CDC BRFSS Cognitive Decline Module - calibrated simulation)",
     ylim = c(0, max(yr_prev$outcome * 100) * 1.3), xaxt = "n", cex.main = 0.95, font.main = 1)
axis(1, at = yr_prev$survey_year)
abline(h = pretty(c(0, max(yr_prev$outcome*100))), col = col_grid, lty = 3)
abline(h = 11.2, col = col_accent, lty = 2, lwd = 1.5)
text(2017.5, 11.2, "CDC 2015-16 published rate: 11.2%", col = col_accent, cex = 0.75, pos = 3)
dev.off()

## --- Figure 2: prevalence by age and comorbidity burden --------------------
age_prev <- aggregate(outcome ~ age_group, df, mean)
png("outputs/figures/fig2_prevalence_by_age_comorbidity.png", width = 1600, height = 950, res = 170)
par(mfrow = c(1, 2), mar = c(5, 5, 3, 1))
bp <- barplot(age_prev$outcome * 100, names.arg = age_prev$age_group, col = col_primary,
        ylab = "SCD Prevalence (%)", xlab = "Age Group", main = "By Age Group",
        ylim = c(0, max(age_prev$outcome*100)*1.25), border = NA, cex.main = 0.95, font.main = 1)
text(bp, age_prev$outcome*100, labels = paste0(round(age_prev$outcome*100,1),"%"), pos = 3, cex = 0.85)

cm_prev <- aggregate(outcome ~ comorbidity_burden, df, mean)
bp2 <- barplot(cm_prev$outcome * 100, names.arg = cm_prev$comorbidity_burden, col = col_accent,
        ylab = "SCD Prevalence (%)", xlab = "Number of Chronic Conditions", main = "By Comorbidity Burden",
        ylim = c(0, max(cm_prev$outcome*100)*1.25), border = NA, cex.main = 0.95, font.main = 1)
text(bp2, cm_prev$outcome*100, labels = paste0(round(cm_prev$outcome*100,1),"%"), pos = 3, cex = 0.85)
dev.off()

## --- Figure 3: prevalence by race/ethnicity and living arrangement --------
re_prev <- aggregate(outcome ~ race_ethnicity, df, mean)
re_prev <- re_prev[order(-re_prev$outcome), ]
png("outputs/figures/fig3_prevalence_by_race_living.png", width = 1600, height = 950, res = 170)
par(mfrow = c(1, 2), mar = c(7, 5, 3, 1))
bp3 <- barplot(re_prev$outcome * 100, names.arg = re_prev$race_ethnicity, col = col_primary,
        ylab = "SCD Prevalence (%)", las = 2, main = "By Race/Ethnicity",
        ylim = c(0, max(re_prev$outcome*100)*1.25), border = NA, cex.main = 0.95, font.main = 1)
text(bp3, re_prev$outcome*100, labels = paste0(round(re_prev$outcome*100,1),"%"), pos = 3, cex = 0.8)

la_prev <- aggregate(outcome ~ living_alone, df, mean)
bp4 <- barplot(la_prev$outcome * 100, names.arg = c("Lives with\nothers","Lives\nalone"),
        col = col_accent, ylab = "SCD Prevalence (%)", main = "By Living Arrangement",
        ylim = c(0, max(la_prev$outcome*100)*1.25), border = NA, cex.main = 0.95, font.main = 1)
text(bp4, la_prev$outcome*100, labels = paste0(round(la_prev$outcome*100,1),"%"), pos = 3, cex = 0.85)
dev.off()

cat("\nFigures 1-3 written to outputs/figures/\n")
