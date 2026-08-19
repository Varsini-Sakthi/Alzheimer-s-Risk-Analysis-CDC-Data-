## ============================================================================
## 00_generate_synthetic_brfss_data.R
##
## PURPOSE
##   Generates a synthetic, respondent-level dataset that reproduces the
##   structure, covariates, and published marginal prevalence rates of the
##   CDC BRFSS "Cognitive Decline" optional module (2015-2020 pooled years).
##
##   IMPORTANT / METHODOLOGICAL DISCLOSURE:
##   CDC does not release identifiable BRFSS microdata through open,
##   unauthenticated channels usable in this environment. Rather than
##   fabricate an unlabeled dataset, this script builds a calibrated
##   simulation: a known logistic data-generating process (DGP) is used to
##   produce respondent records whose MARGINAL prevalence rates are
##   anchored to figures published by CDC / MMWR for the real Cognitive
##   Decline module, specifically:
##     - Overall SCD prevalence, adults 45+, 2015-2016 pooled: 11.2%
##       (Taylor et al., MMWR 2018;67:753-757)
##     - SCD prevalence among adults living alone: 13.8%
##     - SCD prevalence among adults with >=1 chronic disease: 15.2%
##     - National SCD prevalence, 2019-2020: ~1 in 10 (10.0-11.0%)
##       (pooled 2015-2020 trend, CDC Healthy Aging Program)
##     - ~50.6% of respondents with SCD report SCD-related functional
##       limitation
##     - <50% of respondents with SCD report discussing symptoms with a
##       health care provider
##   Effect directions and relative magnitudes for covariates (age,
##   depression, diabetes, hypertension, education, income, social
##   isolation, physical inactivity, smoking, hearing loss) are drawn from
##   the published epidemiological literature on modifiable Alzheimer's/
##   dementia risk factors (Omura et al. 2022; Town et al. 2024; Livingston
##   et al. Lancet Commission 2020). This mirrors standard practice for
##   methods teaching / portfolio work when raw restricted microdata is
##   unavailable, and is disclosed explicitly here and in the final report's
##   Limitations section.
##
## OUTPUT
##   ../outputs/tables/brfss_scd_synthetic_2015_2020.csv
## ============================================================================

## NOTE: run this script from the project root directory, e.g.:
##   cd alzheimers-risk-project
##   Rscript data/00_generate_synthetic_brfss_data.R
## All paths below are relative to the project root.

set.seed(2026)

n_per_year <- 7500
years      <- 2015:2020
N          <- n_per_year * length(years)

states <- c("AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN",
            "IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV",
            "NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN",
            "TX","UT","VT","VA","WA","WV","WI","WY","DC")

# --- demographic draws --------------------------------------------------
year   <- rep(years, each = n_per_year)
state  <- sample(states, N, replace = TRUE)

age_group <- sample(c("45-54","55-64","65-74","75+"), N, replace = TRUE,
                     prob = c(0.30, 0.32, 0.24, 0.14))
age_mid   <- c("45-54" = 49.5, "55-64" = 59.5, "65-74" = 69.5, "75+" = 80)[age_group]

sex <- sample(c("Female","Male"), N, replace = TRUE, prob = c(0.54, 0.46))

race_ethnicity <- sample(
  c("White","Black","Hispanic","Asian","AIAN","Multiracial","Other"), N,
  replace = TRUE, prob = c(0.62, 0.12, 0.14, 0.05, 0.02, 0.03, 0.02))

education <- sample(
  c("Less than HS","HS graduate","Some college","College graduate+"), N,
  replace = TRUE, prob = c(0.10, 0.27, 0.31, 0.32))

income <- sample(
  c("<$25,000","$25,000-$49,999","$50,000-$74,999","$75,000+"), N,
  replace = TRUE, prob = c(0.22, 0.28, 0.20, 0.30))

living_alone <- rbinom(N, 1, ifelse(age_group == "75+", 0.34,
                          ifelse(age_group == "65-74", 0.27, 0.18)))

has_coverage <- rbinom(N, 1, 0.93)

# --- health status / behaviors -------------------------------------------
diabetes      <- rbinom(N, 1, 0.14 + 0.05 * (age_group %in% c("65-74","75+")))
hypertension  <- rbinom(N, 1, 0.32 + 0.14 * (age_group %in% c("65-74","75+")))
obesity       <- rbinom(N, 1, 0.31)
heart_disease <- rbinom(N, 1, 0.06 + 0.10 * (age_group %in% c("65-74","75+")))
stroke_hx     <- rbinom(N, 1, 0.03 + 0.05 * (age_group == "75+"))
depression    <- rbinom(N, 1, 0.18 + 0.05 * living_alone)
hearing_loss  <- rbinom(N, 1, 0.08 + 0.18 * (age_group %in% c("65-74","75+")))

current_smoker <- rbinom(N, 1, 0.15)
binge_drinking <- rbinom(N, 1, 0.13)
physically_inactive <- rbinom(N, 1, 0.24 + 0.08 * (age_group == "75+"))
sleep_lt7hrs   <- rbinom(N, 1, 0.34)

chronic_disease_count <- diabetes + hypertension + heart_disease + stroke_hx + obesity
any_chronic_disease    <- as.integer(chronic_disease_count >= 1)

social_isolation <- rbinom(N, 1, 0.16 + 0.10 * living_alone + 0.05 * depression)
life_dissatisfaction <- rbinom(N, 1, 0.10 + 0.15 * depression + 0.05 * social_isolation)

age_std <- as.numeric(scale(age_mid))
educ_num <- as.integer(factor(education,
                    levels = c("Less than HS","HS graduate","Some college","College graduate+")))
income_num <- as.integer(factor(income,
                    levels = c("<$25,000","$25,000-$49,999","$50,000-$74,999","$75,000+")))

# --- true (known) data-generating logistic model for SCD ------------------
# Coefficients set so the realized sample marginal ~= 11.2% (2015-16),
# drifting toward ~10% by 2019-2020, and subgroup rates approximate the
# CDC-published figures cited above.
year_trend <- (year - 2015) * -0.03            # slight downward secular trend

lp <- -2.45 +
  0.38  * age_std +
  0.55  * depression +
  0.30  * diabetes +
  0.22  * hypertension +
  0.28  * heart_disease +
  0.45  * stroke_hx +
  0.33  * hearing_loss +
  0.30  * social_isolation +
  0.28  * living_alone +
  0.20  * physically_inactive +
  0.18  * current_smoker +
  0.12  * sleep_lt7hrs +
  -0.16 * (educ_num - 1) +
  -0.10 * (income_num - 1) +
  0.10  * (race_ethnicity == "Black") +
  0.14  * (race_ethnicity == "AIAN") +
  0.12  * (race_ethnicity == "Multiracial") +
  0.08  * (race_ethnicity == "Hispanic") +
  0.10  * chronic_disease_count +
  0.16  * any_chronic_disease +
  year_trend +
  rnorm(N, 0, 0.35)                              # unobserved heterogeneity

p_scd <- 1 / (1 + exp(-lp))
SCD <- rbinom(N, 1, p_scd)

# functional limitation and provider discussion, conditional on SCD == 1
functional_limitation <- ifelse(SCD == 1, rbinom(N, 1, 0.44 + 0.10 * (chronic_disease_count >= 2)), 0)
discussed_with_provider <- ifelse(SCD == 1, rbinom(N, 1, 0.38 + 0.10 * has_coverage), 0)

df <- data.frame(
  survey_year = year,
  state = state,
  age_group = age_group,
  sex = sex,
  race_ethnicity = race_ethnicity,
  education = education,
  income_bracket = income,
  living_alone = living_alone,
  has_health_coverage = has_coverage,
  diabetes = diabetes,
  hypertension = hypertension,
  obesity = obesity,
  heart_disease = heart_disease,
  stroke_history = stroke_hx,
  depression = depression,
  hearing_loss = hearing_loss,
  current_smoker = current_smoker,
  binge_drinking = binge_drinking,
  physically_inactive = physically_inactive,
  sleep_lt7hrs = sleep_lt7hrs,
  social_isolation = social_isolation,
  life_dissatisfaction = life_dissatisfaction,
  chronic_disease_count = chronic_disease_count,
  any_chronic_disease = any_chronic_disease,
  subjective_cognitive_decline = SCD,
  scd_functional_limitation = functional_limitation,
  scd_discussed_with_provider = discussed_with_provider
)

# introduce a small amount of realistic item non-response (MCAR-ish) on a
# few self-report fields, to require an explicit missing-data step
introduce_na <- function(x, rate) { x[sample(seq_along(x), floor(length(x) * rate))] <- NA; x }
set.seed(11)
df$income_bracket <- introduce_na(df$income_bracket, 0.04)
df$hearing_loss    <- introduce_na(df$hearing_loss, 0.02)
df$sleep_lt7hrs     <- introduce_na(df$sleep_lt7hrs, 0.015)

out_path <- "data/brfss_scd_synthetic_2015_2020.csv"  
write.csv(df, out_path, row.names = FALSE)

cat("Rows:", nrow(df), " | Overall SCD prevalence:", round(mean(df$subjective_cognitive_decline, na.rm=TRUE)*100,1), "%\n")
cat("SCD prevalence, living alone:   ", round(mean(df$subjective_cognitive_decline[df$living_alone==1])*100,1), "%\n")
cat("SCD prevalence, chronic disease:", round(mean(df$subjective_cognitive_decline[df$any_chronic_disease==1])*100,1), "%\n")
cat("Saved to:", out_path, "\n")
