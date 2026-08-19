## ============================================================================
## 04_model_diagnostics_validation.R
## Out-of-sample validation: ROC/AUC (hand-computed, base R), calibration,
## Brier score, confusion matrix at clinically-motivated thresholds, and
## 10-fold cross-validated AUC for stability.
## ============================================================================

## NOTE: run this script from the project root directory, e.g.:
##   cd alzheimers-risk-project
##   Rscript scripts/04_model_diagnostics_validation.R
## All paths below are relative to the project root.

model <- readRDS("outputs/tables/final_logistic_model.rds")
split <- readRDS("outputs/tables/train_test_split.rds")
train <- split$train; test <- split$test

test$pred_prob <- predict(model, newdata = test, type = "response")

## --- Manual ROC curve + AUC (trapezoidal rule) ------------------------------
compute_roc <- function(probs, labels) {
  thresholds <- sort(unique(c(0, probs, 1)), decreasing = TRUE)
  sens <- spec <- numeric(length(thresholds))
  P <- sum(labels == 1); N <- sum(labels == 0)
  for (i in seq_along(thresholds)) {
    pred <- probs >= thresholds[i]
    tp <- sum(pred == 1 & labels == 1); fp <- sum(pred == 1 & labels == 0)
    sens[i] <- tp / P; spec[i] <- 1 - (fp / N)
  }
  fpr <- 1 - spec
  ord <- order(fpr)
  auc <- sum(diff(fpr[ord]) * (sens[ord][-1] + sens[ord][-length(sens[ord])]) / 2)
  list(fpr = fpr[ord], tpr = sens[ord], auc = auc)
}
roc <- compute_roc(test$pred_prob, test$outcome)
cat("Test-set AUC:", round(roc$auc, 4), "\n")

## --- 10-fold cross-validated AUC on training data (stability check) -------
set.seed(7)
k <- 10
folds <- sample(rep(1:k, length.out = nrow(train)))
cv_auc <- numeric(k)
model_formula <- formula(model)
for (i in 1:k) {
  cv_train <- train[folds != i, ]; cv_valid <- train[folds == i, ]
  m <- glm(model_formula, data = cv_train, family = binomial)
  p <- predict(m, newdata = cv_valid, type = "response")
  cv_auc[i] <- compute_roc(p, cv_valid$outcome)$auc
}
cat("10-fold CV AUC: mean =", round(mean(cv_auc), 4), " SD =", round(sd(cv_auc), 4), "\n")
cat("CV fold AUCs:", round(cv_auc, 3), "\n")

## --- Brier score & calibration ---------------------------------------------
brier <- mean((test$pred_prob - test$outcome)^2)
cat("Brier score:", round(brier, 4), "\n")

test$risk_decile <- cut(test$pred_prob, breaks = quantile(test$pred_prob, probs = seq(0,1,0.1)),
                         include.lowest = TRUE, labels = FALSE)
calib <- aggregate(cbind(observed = outcome, predicted = pred_prob) ~ risk_decile, test, mean)
write.csv(calib, "outputs/tables/calibration_by_decile.csv", row.names = FALSE)
cat("\nCalibration by risk decile:\n"); print(calib)

## --- Confusion matrix at Youden-optimal threshold --------------------------
thresholds <- seq(0.01, 0.5, by = 0.005)
youden <- sapply(thresholds, function(t) {
  pred <- test$pred_prob >= t
  sens <- sum(pred==1 & test$outcome==1) / sum(test$outcome==1)
  spec <- sum(pred==0 & test$outcome==0) / sum(test$outcome==0)
  sens + spec - 1
})
best_t <- thresholds[which.max(youden)]
pred_class <- as.integer(test$pred_prob >= best_t)
cm <- table(Predicted = pred_class, Actual = test$outcome)
sens <- cm["1","1"] / sum(cm[,"1"]); spec <- cm["0","0"] / sum(cm[,"0"])
ppv  <- cm["1","1"] / sum(cm["1",]); npv  <- cm["0","0"] / sum(cm["0",])
cat("\nYouden-optimal threshold:", round(best_t, 3), "\n")
cat("Confusion matrix:\n"); print(cm)
cat("Sensitivity:", round(sens,3), " Specificity:", round(spec,3),
    " PPV:", round(ppv,3), " NPV:", round(npv,3), "\n")

perf <- data.frame(Metric = c("Test AUC","CV AUC (mean)","CV AUC (SD)","Brier Score",
                               "Optimal Threshold","Sensitivity","Specificity","PPV","NPV"),
                    Value = round(c(roc$auc, mean(cv_auc), sd(cv_auc), brier, best_t, sens, spec, ppv, npv), 4))
write.csv(perf, "outputs/tables/model_performance_summary.csv", row.names = FALSE)

## --- Figure 5: ROC curve ----------------------------------------------------
png("outputs/figures/fig5_roc_curve.png", width = 1100, height = 1000, res = 170)
par(mar = c(5, 5, 3, 2))
plot(roc$fpr, roc$tpr, type = "l", lwd = 3, col = "#2C5F7C",
     xlab = "False Positive Rate (1 - Specificity)", ylab = "True Positive Rate (Sensitivity)",
     main = paste0("ROC Curve - Test Set\nAUC = ", round(roc$auc, 3)), cex.main = 1, font.main = 1)
abline(0, 1, lty = 2, col = "gray50")
grid(col = "#E5E5E5")
dev.off()

## --- Figure 6: calibration plot --------------------------------------------
png("outputs/figures/fig6_calibration_plot.png", width = 1100, height = 1000, res = 170)
par(mar = c(5, 5, 3, 2))
plot(calib$predicted*100, calib$observed*100, pch = 19, col = "#2C5F7C", cex = 1.4,
     xlab = "Mean Predicted Risk (%)", ylab = "Observed SCD Prevalence (%)",
     main = "Calibration Plot (10 Risk Deciles)", cex.main = 1, font.main = 1,
     xlim = c(0, max(calib$predicted, calib$observed)*100*1.1),
     ylim = c(0, max(calib$predicted, calib$observed)*100*1.1))
abline(0, 1, lty = 2, col = "#C1502E", lwd = 1.5)
grid(col = "#E5E5E5")
dev.off()

cat("\nFigures 5-6 (ROC, calibration) written. Diagnostics complete.\n")
