# ============================================================================
# INDUSTRIAL FAULT DETECTION - Poboljšana verzija
# ============================================================================
# Ovaj skript implementira kompletan ML pipeline za detekciju industrijskih 
# kvarova koristeći različite algoritme mašinskog učenja.
# ============================================================================

# ----------------------------------------------------------------------------
# SEKCIJA 1: UČITAVANJE BIBLIOTEKA
# ----------------------------------------------------------------------------
# Uklanjanje duplikata i učitavanje samo potrebnih biblioteka
library(tidyverse)      # Uključuje dplyr, ggplot2, readr, itd.
library(caret)          # Za treniranje i evaluaciju modela
library(randomForest)   # Za Random Forest algoritam
library(pROC)           # Za ROC i AUC metrike
library(smotefamily)    # Za SMOTE balansiranje klasa
library(nnet)           # Za multinomijalnu logističku regresiju
library(patchwork)      # Za kombinovanje ggplot grafikona

# Postavljanje opcija
options(encoding = "UTF-8")
options(warn = -1)      # Sakrivanje upozorenja tokom izvršavanja (opciono)

# ----------------------------------------------------------------------------
# SEKCIJA 2: UČITAVANJE PODATAKA
# ----------------------------------------------------------------------------
cat(paste0(rep("=", 80), collapse = ""), "\n")
cat("UČITAVANJE PODATAKA\n")
cat(paste0(rep("=", 80), collapse = ""), "\n")

dataset_path <- "./dataset/Industrial_fault_detection.csv"
dataset <- read.csv(dataset_path, stringsAsFactors = FALSE)

cat(sprintf("Dataset uspešno učitan: %d redova, %d kolona\n", 
            nrow(dataset), ncol(dataset)))

# ----------------------------------------------------------------------------
# SEKCIJA 3: EKSPLORATIVNA ANALIZA PODATAKA (EDA)
# ----------------------------------------------------------------------------
cat("\n", paste0(rep("=", 80), collapse = ""), "\n")
cat("EKSPLORATIVNA ANALIZA PODATAKA\n")
cat(paste0(rep("=", 80), collapse = ""), "\n")

# 3.1 Osnovne informacije o datasetu
cat("\n--- Osnovne informacije ---\n")
cat(sprintf("Dimenzije: %d x %d\n", nrow(dataset), ncol(dataset)))
cat(sprintf("Duplikati: %d\n", sum(duplicated(dataset))))
cat(sprintf("Nedostajuće vrednosti: %d\n", sum(is.na(dataset))))

# Provera potpuno praznih redova
zero_rows <- which(rowSums(dataset == 0) == ncol(dataset))
cat(sprintf("Potpuno prazni redovi: %d\n", length(zero_rows)))

# 3.2 Definicija osnovnih senzora
base_sensors <- c("Temperature", "Vibration", "Pressure", 
                  "Flow_Rate", "Current", "Voltage")

# 3.3 Analiza ciljne varijable (Fault_Type)
cat("\n--- Analiza Fault_Type ---\n")

# Pretvaranje u faktor pre analize za bolje labele
dataset$Fault_Type <- factor(
  dataset$Fault_Type,
  levels = c("0", "1", "2", "3"),
  labels = c("Normal", "Overheating", "Leakage", "Power_Fluctuation")
)

fault_table <- table(dataset$Fault_Type)
fault_prop <- prop.table(fault_table)
print(fault_table)
print(round(fault_prop * 100, 2))

# Vizuelizacija distribucije klasa
freq_df <- data.frame(
  Fault_Type = names(fault_table),
  Freq = as.numeric(fault_table),
  Perc = round(as.numeric(fault_prop) * 100, 1)
)

plot_distribution <- ggplot(freq_df, aes(x = Fault_Type, y = Freq, fill = Fault_Type)) +
  geom_col() +
  geom_text(aes(label = paste0(Perc, "%")), vjust = -0.3, size = 4) +
  labs(title = "Distribucija klasa (u procentima)", 
       x = "Tip kvara", 
       y = "Broj posmatranja") +
  ylim(0, max(freq_df$Freq) * 1.15) +
  theme_minimal() +
  theme(legend.position = "none")
print(plot_distribution)

# 3.4 Histogrami osnovnih senzora
cat("\n--- Generisanje histograma osnovnih senzora ---\n")
sensor_plots <- lapply(base_sensors, function(var) {
  ggplot(dataset, aes_string(x = var)) +
    geom_histogram(color = "black", fill = "lightblue", bins = 30, alpha = 0.7) +
    labs(title = paste("Histogram:", var), x = var, y = "Frekvencija") +
    theme_minimal()
})
combined_histograms <- wrap_plots(sensor_plots, ncol = 3)
print(combined_histograms)

# 3.5 Boxplotovi senzora u odnosu na Fault_Type
cat("\n--- Generisanje boxplotova u odnosu na Fault_Type ---\n")
boxplot_plots <- lapply(base_sensors, function(var) {
  ggplot(dataset, aes_string(x = "Fault_Type", y = var, fill = "Fault_Type")) +
    geom_boxplot(alpha = 0.7) +
    labs(title = paste(var, "po tipu kvara"), x = "Tip kvara", y = var) +
    theme_minimal() +
    theme(legend.position = "none")
})
combined_boxplots <- wrap_plots(boxplot_plots, ncol = 3)
print(combined_boxplots)

# 3.6 Provera fizički nelogičnih vrednosti
cat("\n--- Provera fizički nelogičnih vrednosti ---\n")
invalid_temp <- which(dataset$Temperature <= 0)
invalid_pressure <- which(dataset$Pressure <= 0)
invalid_voltage <- which(dataset$Voltage <= 0)
invalid_flow <- which(dataset$Flow_Rate < 0)
invalid_current <- which(dataset$Current < 0)

invalid_rows <- unique(c(invalid_temp, invalid_pressure, invalid_voltage, 
                         invalid_flow, invalid_current))
cat(sprintf("Redovi sa nelogičnim vrednostima: %d\n", length(invalid_rows)))

# 3.7 Analiza FFT kolona
fft_cols <- grep("FFT", names(dataset), value = TRUE)
cat(sprintf("\nBroj FFT kolona: %d\n", length(fft_cols)))

# ----------------------------------------------------------------------------
# SEKCIJA 4: PREPROCESIRANJE PODATAKA
# ----------------------------------------------------------------------------
cat("\n", paste0(rep("=", 80), collapse = ""), "\n")
cat("PREPROCESIRANJE PODATAKA\n")
cat(paste0(rep("=", 80), collapse = ""), "\n")

# 4.1 Verifikacija Fault_Type faktora
cat("\n--- Verifikacija Fault_Type faktora ---\n")
cat("Fault_Type je faktor sa labelima:\n")
print(levels(dataset$Fault_Type))

# 4.2 Kreiranje novih feature-a (feature engineering)
cat("\n--- Kreiranje novih feature-a ---\n")
dataset <- dataset %>%
  mutate(
    # Prosečna vrednost svih osnovnih senzora
    Avg_Sensor = rowMeans(select(., all_of(base_sensors)), na.rm = TRUE),
    
    # Odnos protoka i pritiska (korisno za detekciju Leakage)
    Ratio_Flow_Pressure = Flow_Rate / (Pressure + 1e-10),  # Dodajemo malu vrednost da izbegnemo deljenje sa 0
    
    # Odnos struje i napona (korisno za detekciju Power Fluctuation)
    Ratio_Current_Voltage = Current / (Voltage + 1e-10),
    
    # Standardna devijacija osnovnih senzora (pokazuje varijabilnost)
    SD_Sensor = apply(select(., all_of(base_sensors)), 1, sd, na.rm = TRUE),
    
    # Maksimalna vrednost osnovnih senzora
    Max_Sensor = apply(select(., all_of(base_sensors)), 1, max, na.rm = TRUE),
    
    # Minimalna vrednost osnovnih senzora
    Min_Sensor = apply(select(., all_of(base_sensors)), 1, min, na.rm = TRUE)
  )
cat("Dodato 6 novih feature-a\n")

# 4.3 Uklanjanje nedostajućih vrednosti
cat("\n--- Obrada nedostajućih vrednosti ---\n")
rows_before <- nrow(dataset)
dataset <- na.omit(dataset)
rows_after <- nrow(dataset)
cat(sprintf("Redova pre: %d, posle: %d (uklonjeno: %d)\n", 
            rows_before, rows_after, rows_before - rows_after))

# 4.4 Identifikacija numeričkih kolona (isključujući Fault_Type)
numeric_cols <- names(dataset)[sapply(dataset, is.numeric)]
feature_cols <- setdiff(numeric_cols, "Fault_Type")  # Uklanjamo Fault_Type iz feature-a
cat(sprintf("\nBroj numeričkih feature-a: %d\n", length(feature_cols)))

# 4.5 Podela na train i test PRE skaliranja (važno za pravilno skaliranje!)
cat("\n--- Podela na train i test set ---\n")
set.seed(123)
trainIndex <- createDataPartition(dataset$Fault_Type, p = 0.8, list = FALSE)
train_data_raw <- dataset[trainIndex, ]
test_data_raw <- dataset[-trainIndex, ]

cat(sprintf("Train set: %d redova (%.1f%%)\n", 
            nrow(train_data_raw), nrow(train_data_raw)/nrow(dataset)*100))
cat(sprintf("Test set: %d redova (%.1f%%)\n", 
            nrow(test_data_raw), nrow(test_data_raw)/nrow(dataset)*100))

# 4.6 Skaliranje numeričkih feature-a (samo na train setu, pa primena na test)
cat("\n--- Skaliranje feature-a (centriranje i standardizacija) ---\n")
preProc <- preProcess(train_data_raw[, feature_cols], 
                      method = c("center", "scale"))

# Primena skaliranja
train_data_scaled <- train_data_raw
train_data_scaled[, feature_cols] <- predict(preProc, train_data_raw[, feature_cols])

test_data_scaled <- test_data_raw
test_data_scaled[, feature_cols] <- predict(preProc, test_data_raw[, feature_cols])

cat("Skaliranje završeno\n")

# 4.7 Balansiranje klasa koristeći SMOTE (samo na train setu!)
cat("\n--- Balansiranje klasa koristeći SMOTE ---\n")
cat("Distribucija klasa PRE balansiranja:\n")
print(table(train_data_scaled$Fault_Type))

# Priprema podataka za SMOTE
X_train <- train_data_scaled[, feature_cols]
y_train <- train_data_scaled$Fault_Type

# Primena SMOTE
smote_result <- SMOTE(X = X_train, target = y_train, K = 5)

# Kreiranje balansiranog train seta
balanced_train <- smote_result$data
# Konverzija klase u faktor sa pravim nivoima
balanced_train$Fault_Type <- factor(
  balanced_train$class,
  levels = levels(y_train),
  labels = levels(y_train)
)
balanced_train$class <- NULL

cat("\nDistribucija klasa POSLE balansiranja:\n")
print(table(balanced_train$Fault_Type))

# Finalni train i test setovi
train_data <- balanced_train
test_data <- test_data_scaled

# ----------------------------------------------------------------------------
# SEKCIJA 5: IZGRADNJA I TRENIRANJE MODELA
# ----------------------------------------------------------------------------
cat("\n", paste0(rep("=", 80), collapse = ""), "\n")
cat("IZGRADNJA I TRENIRANJE MODELA\n")
cat(paste0(rep("=", 80), collapse = ""), "\n")

# 5.1 Random Forest Model
cat("\n--- Treniranje Random Forest modela ---\n")
set.seed(123)
rf_model <- randomForest(
  Fault_Type ~ ., 
  data = train_data, 
  ntree = 200,           # Povećan broj stabala za bolju tačnost
  mtry = sqrt(ncol(train_data) - 1),  # Optimalan mtry za klasifikaciju
  importance = TRUE,
  do.trace = 50
)
cat("Random Forest model treniran\n")

# 5.2 Multinomijalna logistička regresija
cat("\n--- Treniranje Multinomijalne logističke regresije ---\n")
set.seed(123)
log_model <- multinom(Fault_Type ~ ., data = train_data, trace = FALSE)
cat("Multinomijalna logistička regresija trenirana\n")

# ----------------------------------------------------------------------------
# SEKCIJA 6: EVALUACIJA MODELA
# ----------------------------------------------------------------------------
cat("\n", paste0(rep("=", 80), collapse = ""), "\n")
cat("EVALUACIJA MODELA\n")
cat(paste0(rep("=", 80), collapse = ""), "\n")

# 6.1 Predikcije
cat("\n--- Generisanje predikcija ---\n")
rf_pred <- predict(rf_model, test_data)
rf_prob <- predict(rf_model, test_data, type = "prob")

log_pred <- predict(log_model, test_data)
log_prob <- predict(log_model, test_data, type = "prob")

# 6.2 Confusion Matrix i osnovne metrike za Random Forest
cat("\n--- Random Forest - Confusion Matrix ---\n")
rf_cm <- confusionMatrix(rf_pred, test_data$Fault_Type)
print(rf_cm)

# Detaljne metrike po klasama za RF
cat("\n--- Random Forest - Detaljne metrike po klasama ---\n")
rf_metrics <- rf_cm$byClass[, c("Sensitivity", "Specificity", "Precision", "Recall", "F1")]
print(round(rf_metrics, 4))

# 6.3 Confusion Matrix i metrike za Logističku regresiju
cat("\n--- Multinomijalna logistička regresija - Confusion Matrix ---\n")
log_cm <- confusionMatrix(log_pred, test_data$Fault_Type)
print(log_cm)

# Detaljne metrike po klasama za Logističku regresiju
cat("\n--- Multinomijalna logistička regresija - Detaljne metrike po klasama ---\n")
log_metrics <- log_cm$byClass[, c("Sensitivity", "Specificity", "Precision", "Recall", "F1")]
print(round(log_metrics, 4))

# 6.4 Poređenje tačnosti modela
cat("\n--- Poređenje tačnosti modela ---\n")
rf_acc <- rf_cm$overall['Accuracy']
log_acc <- log_cm$overall['Accuracy']

cat(sprintf("Random Forest Accuracy: %.4f (%.2f%%)\n", 
            rf_acc, rf_acc * 100))
cat(sprintf("Multinomial Logistic Regression Accuracy: %.4f (%.2f%%)\n", 
            log_acc, log_acc * 100))

if (rf_acc > log_acc) {
  cat(sprintf("\nNajbolji model: Random Forest (razlika: %.2f%%)\n", 
              (rf_acc - log_acc) * 100))
} else {
  cat(sprintf("\nNajbolji model: Multinomijalna logistička regresija (razlika: %.2f%%)\n", 
              (log_acc - rf_acc) * 100))
}

# 6.5 ROC i AUC analiza za Random Forest
cat("\n--- ROC i AUC analiza (Random Forest) ---\n")
roc_multi <- multiclass.roc(test_data$Fault_Type, rf_prob)
cat(sprintf("Multi-class AUC: %.4f\n", auc(roc_multi)))

# Vizuelizacija ROC krivih za svaku klasu
if (length(roc_multi$rocs) > 0) {
  plot(roc_multi$rocs[[1]], 
       main = "ROC krive po klasama (Random Forest)",
       col = 1, lwd = 2)
  colors <- c("blue", "green", "red", "orange")
  for(i in 2:min(length(roc_multi$rocs), length(colors))) {
    lines(roc_multi$rocs[[i]], col = colors[i], lwd = 2)
  }
  legend("bottomright", 
         legend = levels(test_data$Fault_Type)[1:min(length(roc_multi$rocs), length(colors))],
         col = colors[1:min(length(roc_multi$rocs), length(colors))], 
         lwd = 2)
}

# 6.6 Važnost atributa (Random Forest)
cat("\n--- Važnost atributa (Random Forest) ---\n")
varImpPlot(rf_model, main = "Važnost atributa - Random Forest", 
           type = 1, n.var = min(20, length(feature_cols)))

# Prikaz top 15 najvažnijih atributa
importance_df <- data.frame(
  Feature = rownames(rf_model$importance),
  Importance = rf_model$importance[, "MeanDecreaseAccuracy"]
) %>%
  arrange(desc(Importance)) %>%
  head(15)

cat("\nTop 15 najvažnijih atributa:\n")
print(importance_df)

# Vizuelizacija top atributa
plot_importance <- ggplot(importance_df, aes(x = reorder(Feature, Importance), y = Importance)) +
  geom_col(fill = "steelblue", alpha = 0.8) +
  coord_flip() +
  labs(title = "Top 15 najvažnijih atributa (Random Forest)",
       x = "Atribut",
       y = "Važnost (Mean Decrease Accuracy)") +
  theme_minimal()
print(plot_importance)

# ----------------------------------------------------------------------------
# SEKCIJA 7: SAČUVANJE MODELA I REZULTATA
# ----------------------------------------------------------------------------
cat("\n", paste0(rep("=", 80), collapse = ""), "\n")
cat("SAČUVANJE MODELA I REZULTATA\n")
cat(paste0(rep("=", 80), collapse = ""), "\n")

# Kreiranje direktorijuma za rezultate (ako ne postoji)
if (!dir.exists("models")) dir.create("models")
if (!dir.exists("results")) dir.create("results")

# Čuvanje modela
cat("\n--- Čuvanje modela ---\n")
saveRDS(rf_model, "models/rf_model.rds")
saveRDS(log_model, "models/logistic_model.rds")
saveRDS(preProc, "models/preprocessor.rds")
cat("Modeli sačuvani u 'models/' direktorijumu\n")

# Čuvanje rezultata evaluacije
cat("\n--- Čuvanje rezultata ---\n")
results_summary <- list(
  RandomForest = list(
    Accuracy = rf_acc,
    ConfusionMatrix = rf_cm$table,
    Metrics = rf_metrics,
    AUC = as.numeric(auc(roc_multi))
  ),
  LogisticRegression = list(
    Accuracy = log_acc,
    ConfusionMatrix = log_cm$table,
    Metrics = log_metrics
  ),
  FeatureImportance = importance_df
)

saveRDS(results_summary, "results/evaluation_results.rds")
cat("Rezultati sačuvani u 'results/evaluation_results.rds'\n")

# Kreiranje tekstualnog izveštaja
cat("\n--- Kreiranje tekstualnog izveštaja ---\n")
sink("results/model_evaluation_report.txt")
cat(paste0(rep("=", 80), collapse = ""), "\n")
cat("IZVEŠTAJ O EVALUACIJI MODELA\n")
cat(paste0(rep("=", 80), collapse = ""), "\n\n")
cat(sprintf("Datum: %s\n\n", Sys.Date()))
cat(sprintf("Broj feature-a: %d\n", length(feature_cols)))
cat(sprintf("Broj klasa: %d\n", nlevels(test_data$Fault_Type)))
cat("\n--- Random Forest ---\n")
cat(sprintf("Accuracy: %.4f\n", rf_acc))
cat(sprintf("Multi-class AUC: %.4f\n", as.numeric(auc(roc_multi))))
cat("\n--- Multinomijalna logistička regresija ---\n")
cat(sprintf("Accuracy: %.4f\n", log_acc))
sink()

cat("Tekstualni izveštaj sačuvan u 'results/model_evaluation_report.txt'\n")

# ----------------------------------------------------------------------------
# ZAKLJUČAK
# ----------------------------------------------------------------------------
cat("\n", paste0(rep("=", 80), collapse = ""), "\n")
cat("ANALIZA ZAVRŠENA USPEŠNO!\n")
cat(paste0(rep("=", 80), collapse = ""), "\n")
cat("\nSačuvano:\n")
cat("  - Modeli: models/rf_model.rds, models/logistic_model.rds\n")
cat("  - Preprocessor: models/preprocessor.rds\n")
cat("  - Rezultati: results/evaluation_results.rds\n")
cat("  - Izveštaj: results/model_evaluation_report.txt\n")
cat("\n")
