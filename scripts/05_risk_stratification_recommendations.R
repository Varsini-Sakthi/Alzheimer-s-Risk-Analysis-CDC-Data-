## ============================================================================
## 05_risk_stratification_recommendations.R
## Applies the validated model to stratify the full population into
## actionable risk tiers and quantifies state-level high-risk burden to
## support public health resource allocation.
## ============================================================================

## NOTE: run this script from the project root directory, e.g.:
##   cd alzheimers-risk-project
##   Rscript scripts/05_risk_stratification_recommendations.R
## All paths below are relative to the project root.

model <- readRDS("outputs/tables/final_logistic_model.rds")
df <- readRDS("outputs/tables/analysis_ready_data.rds")

df$predicted_risk <- predict(model, newdata = df, type = "response")

## --- Risk tiers (thresholds informed by decile calibration in script 04) --
df$risk_tier <- cut(df$predicted_risk,
                     breaks = c(-Inf, 0.07, 0.14, 0.22, Inf),
                     labels = c("Low", "Moderate", "High", "Very High"))

tier_summary <- aggregate(outcome ~ risk_tier, df, function(x) c(n = length(x), rate = mean(x)))
tier_tab <- data.frame(
  Risk_Tier = tier_summary$risk_tier,
  N = tier_summary$outcome[,"n"],
  Pct_of_Population = round(tier_summary$outcome[,"n"] / nrow(df) * 100, 1),
  Observed_SCD_Rate_Pct = round(tier_summary$outcome[,"rate"] * 100, 1)
)
write.csv(tier_tab, "outputs/tables/risk_tier_summary.csv", row.names = FALSE)
cat("========== RISK TIER SUMMARY ==========\n"); print(tier_tab)

## --- State-level high-risk burden -------------------------------------------
state_summary <- aggregate(cbind(high_risk = as.integer(risk_tier %in% c("High","Very High")),
                                  n = rep(1, nrow(df))) ~ state, df, sum)
state_summary$pct_high_risk <- round(state_summary$high_risk / state_summary$n * 100, 1)
state_summary <- state_summary[order(-state_summary$pct_high_risk), ]
write.csv(state_summary, "outputs/tables/state_high_risk_burden.csv", row.names = FALSE)
cat("\n========== TOP 10 STATES BY SHARE OF SAMPLE IN HIGH/VERY-HIGH RISK TIER ==========\n")
print(head(state_summary[, c("state","n","high_risk","pct_high_risk")], 10))

## --- Figure 7: risk tier distribution and top-10 state burden -------------
png("outputs/figures/fig7_risk_tiers_and_states.png", width = 1700, height = 950, res = 170)
par(mfrow = c(1, 2), mar = c(5, 5, 3, 1))
cols <- c("#8FBF9F", "#E8C468", "#DB8A3B", "#C1502E")
bp <- barplot(tier_tab$Pct_of_Population, names.arg = tier_tab$Risk_Tier, col = cols, border = NA,
        ylab = "Share of Population (%)", main = "Population by Predicted Risk Tier",
        ylim = c(0, max(tier_tab$Pct_of_Population)*1.25), cex.main = 0.9, font.main = 1)
text(bp, tier_tab$Pct_of_Population, labels = paste0(tier_tab$Pct_of_Population,"%"), pos = 3, cex = 0.85)

top10 <- head(state_summary, 10)
bp2 <- barplot(rev(top10$pct_high_risk), names.arg = rev(top10$state), horiz = TRUE, las = 1,
        col = "#2C5F7C", border = NA, xlab = "% of Adults 45+ in High/Very-High Risk Tier",
        main = "Top 10 States: High-Risk Population Share", cex.main = 0.9, font.main = 1,
        xlim = c(0, max(top10$pct_high_risk)*1.2))
dev.off()

## --- Population Attributable Risk (PAR) for top modifiable factors --------
## PAR% = prevalence_exposed * (OR-1) / (prevalence_exposed * (OR-1) + 1)
or_table <- read.csv("outputs/tables/odds_ratios.csv")
compute_par <- function(varname, or_term) {
  p_exp <- mean(df[[varname]], na.rm = TRUE)
  or <- or_table$OddsRatio[or_table$Term == or_term]
  if (length(or) == 0) return(NA)
  par_pct <- p_exp * (or - 1) / (p_exp * (or - 1) + 1) * 100
  round(par_pct, 1)
}
par_table <- data.frame(
  Modifiable_Factor = c("Depression", "Physical inactivity", "Current smoking",
                         "Social isolation", "Insufficient sleep (<7 hrs)", "Hearing loss (untreated)"),
  Prevalence_Pct = round(c(mean(df$depression), mean(df$physically_inactive), mean(df$current_smoker),
                            mean(df$social_isolation), mean(df$sleep_lt7hrs, na.rm=TRUE), mean(df$hearing_loss, na.rm=TRUE))*100, 1),
  Adjusted_OR = c(or_table$OddsRatio[or_table$Term=="depression"],
                   or_table$OddsRatio[or_table$Term=="physically_inactive"],
                   or_table$OddsRatio[or_table$Term=="current_smoker"],
                   or_table$OddsRatio[or_table$Term=="social_isolation"],
                   or_table$OddsRatio[or_table$Term=="sleep_lt7hrs"],
                   or_table$OddsRatio[or_table$Term=="hearing_loss"]),
  Population_Attributable_Risk_Pct = c(
    compute_par("depression","depression"), compute_par("physically_inactive","physically_inactive"),
    compute_par("current_smoker","current_smoker"), compute_par("social_isolation","social_isolation"),
    compute_par("sleep_lt7hrs","sleep_lt7hrs"), compute_par("hearing_loss","hearing_loss"))
)
par_table <- par_table[order(-par_table$Population_Attributable_Risk_Pct), ]
write.csv(par_table, "outputs/tables/population_attributable_risk.csv", row.names = FALSE)
cat("\n========== POPULATION ATTRIBUTABLE RISK - MODIFIABLE FACTORS ==========\n")
print(par_table)

## --- Figure 8: PAR chart ----------------------------------------------------
png("outputs/figures/fig8_population_attributable_risk.png", width = 1400, height = 950, res = 170)
par(mar = c(5, 16, 3, 2))
bp3 <- barplot(rev(par_table$Population_Attributable_Risk_Pct), names.arg = rev(par_table$Modifiable_Factor),
        horiz = TRUE, las = 1, col = "#2C5F7C", border = NA,
        xlab = "Population Attributable Risk (%)",
        main = "Estimated Share of SCD Cases Attributable to\nModifiable Risk Factors (Individually)",
        cex.main = 0.95, font.main = 1, xlim = c(0, max(par_table$Population_Attributable_Risk_Pct)*1.3))
text(rev(par_table$Population_Attributable_Risk_Pct), bp3, labels = paste0(rev(par_table$Population_Attributable_Risk_Pct),"%"), pos = 4, cex = 0.85)
dev.off()

saveRDS(df, "outputs/tables/scored_population.rds")
cat("\nRisk stratification complete. Figures 7-8 written.\n")
