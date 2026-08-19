## ============================================================================
## 03_logistic_regression_model.R
## Builds, selects, and interprets a multivariable logistic regression model
## predicting subjective cognitive decline (SCD). Includes stepwise AIC
## selection, VIF-style multicollinearity screen, odds ratios with 95% CIs,
## and a forest plot.
## ============================================================================

## NOTE: run this script from the project root directory, e.g.:
##   cd alzheimers-risk-project
##   Rscript scripts/03_logistic_regression_model.R
## All paths below are relative to the project root.

df <- readRDS("outputs/tables/analysis_ready_data.rds")

## --- Train / test split (stratified 75/25) ---------------------------------
set.seed(42)
idx_pos <- which(df$outcome == 1); idx_neg <- which(df$outcome == 0)
train_idx <- c(sample(idx_pos, floor(0.75 * length(idx_pos))),
               sample(idx_neg, floor(0.75 * length(idx_neg))))
train <- df[train_idx, ]
test  <- df[-train_idx, ]
cat("Train N:", nrow(train), " (SCD:", round(mean(train$outcome)*100,1), "%) | ",
    "Test N:", nrow(test), " (SCD:", round(mean(test$outcome)*100,1), "%)\n\n")

## --- Full candidate model ---------------------------------------------------
full_formula <- outcome ~ age_group + sex + race_ethnicity + education + income_bracket +
  living_alone + diabetes + hypertension + heart_disease + stroke_history +
  depression + hearing_loss + current_smoker + binge_drinking +
  physically_inactive + sleep_lt7hrs + social_isolation + factor(survey_year)

full_model <- glm(full_formula, data = train, family = binomial(link = "logit"))

## --- Stepwise selection (AIC, backward) ------------------------------------
step_model <- step(full_model, direction = "backward", trace = 0)
cat("========== FINAL MODEL (post backward-AIC selection) ==========\n")
print(summary(step_model))

## --- Multicollinearity screen (VIF, computed manually via base R) ---------
vif_manual <- function(model) {
  mm <- model.matrix(model)[, -1, drop = FALSE]
  vifs <- sapply(colnames(mm), function(cn) {
    y <- mm[, cn]; X <- mm[, colnames(mm) != cn, drop = FALSE]
    r2 <- summary(lm(y ~ X))$r.squared
    1 / (1 - r2)
  })
  sort(vifs, decreasing = TRUE)
}
vifs <- vif_manual(step_model)
cat("\n========== VARIANCE INFLATION FACTORS (top 10) ==========\n")
print(round(head(vifs, 10), 2))
write.csv(data.frame(term = names(vifs), VIF = round(vifs, 2)),
          "outputs/tables/vif_diagnostics.csv", row.names = FALSE)

## --- Odds ratios with 95% Wald CIs -----------------------------------------
co <- summary(step_model)$coefficients
or_table <- data.frame(
  Term = rownames(co),
  Estimate = round(co[, "Estimate"], 3),
  OddsRatio = round(exp(co[, "Estimate"]), 3),
  CI_Lower = round(exp(co[, "Estimate"] - 1.96 * co[, "Std. Error"]), 3),
  CI_Upper = round(exp(co[, "Estimate"] + 1.96 * co[, "Std. Error"]), 3),
  p_value = ifelse(co[, "Pr(>|z|)"] < 0.001, "<0.001", formatC(co[, "Pr(>|z|)"], digits = 3, format = "f"))
)
or_table <- or_table[or_table$Term != "(Intercept)", ]
write.csv(or_table, "outputs/tables/odds_ratios.csv", row.names = FALSE)
cat("\n========== ODDS RATIOS ==========\n"); print(or_table)

## --- Model fit statistics ---------------------------------------------------
null_model <- glm(outcome ~ 1, data = train, family = binomial)
mcfadden_r2 <- 1 - (logLik(step_model) / logLik(null_model))
cat("\nMcFadden's pseudo-R^2:", round(as.numeric(mcfadden_r2), 4), "\n")
cat("AIC (full):", round(AIC(full_model), 1), " | AIC (selected):", round(AIC(step_model), 1), "\n")
cat("Residual deviance:", round(step_model$deviance,1), "on", step_model$df.residual, "df\n")

## --- Forest plot of top predictors (by |log-OR|, excluding year/state) ----
plot_terms <- or_table[!grepl("survey_year", or_table$Term), ]
plot_terms <- plot_terms[order(abs(log(plot_terms$OddsRatio)), decreasing = TRUE), ][1:15, ]
plot_terms <- plot_terms[order(plot_terms$OddsRatio), ]

png("outputs/figures/fig4_forest_plot_odds_ratios.png", width = 1500, height = 1300, res = 170)
par(mar = c(5, 15, 3, 2))
y_pos <- 1:nrow(plot_terms)
plot(plot_terms$OddsRatio, y_pos, xlim = c(min(plot_terms$CI_Lower)*0.9, max(plot_terms$CI_Upper)*1.05),
     pch = 19, col = "#2C5F7C", cex = 1.3, yaxt = "n", ylab = "",
     xlab = "Adjusted Odds Ratio (95% CI)",
     main = "Top Predictors of Subjective Cognitive Decline\n(Multivariable Logistic Regression)", cex.main = 0.95, font.main = 1)
segments(plot_terms$CI_Lower, y_pos, plot_terms$CI_Upper, y_pos, col = "#2C5F7C", lwd = 2)
abline(v = 1, lty = 2, col = "#C1502E", lwd = 1.5)
axis(2, at = y_pos, labels = gsub("(_|factor\\(survey_year\\))", " ", plot_terms$Term), las = 2, cex.axis = 0.75)
dev.off()

saveRDS(step_model, "outputs/tables/final_logistic_model.rds")
saveRDS(list(train = train, test = test), "outputs/tables/train_test_split.rds")
cat("\nModel object and train/test split saved.\n")
