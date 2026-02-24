# Učitavanje biblioteka
library(tidyverse)
library(ggplot2)
library(reshape2)
library(dplyr)
library(readr)
library(scales)
library(caret)        # Za treniranje i evaluaciju
library(randomForest) # Za Random Forest
library(pROC)         # Za ROC i AUC
library(ROSE)         # Za balansiranje klasa
library(nnet)         # Za multinomijalnu logističku regresiju
library(patchwork)

options(encoding = "UTF-8")

# Učitavanje podataka
dataset <- read.csv("./dataset/Industrial_fault_detection.csv", stringsAsFactors = FALSE)

# Osnovna EDA (iz originala)
head(dataset)
str(dataset)
summary(dataset)
tail(dataset)
dim(dataset)
sum(duplicated(dataset))
zero_rows <- which(rowSums(dataset == 0) == ncol(dataset))
length(zero_rows)  # Trebalo bi da bude 0

# Summary osnovnih senzora
summary(dataset[, c("Temperature", "Vibration", "Pressure", "Flow_Rate", "Current", "Voltage")])

# Histogrami osnovnih senzora
base_sensors <- c("Temperature", "Vibration", "Pressure", "Flow_Rate", "Current", "Voltage")
plots <- lapply(base_sensors, function(v) {
  ggplot(dataset, aes_string(x = v)) +
    geom_histogram(color = "black", fill = "lightblue", bins = 30) +
    labs(title = paste("Histogram of", v), x = v, y = "Frequency")
})
wrap_plots(plots, ncol = 2)

# Summary FFT kolona
fft_cols <- grep("FFT", names(dataset), value = TRUE)
summary(dataset[, fft_cols])

# Učestalost Fault_Type
table(dataset$Fault_Type)
prop.table(table(dataset$Fault_Type))

# Grafikon učestalosti
freq <- as.data.frame(table(dataset$Fault_Type))
freq$perc <- round(freq$Freq / sum(freq$Freq) * 100, 1)
ggplot(freq, aes(x = Var1, y = Freq)) +
  geom_col(fill = "darkorange") +
  geom_text(aes(label = paste0(perc, "%")), vjust = -0.3, size = 4) +
  labs(title = "Učestalost klasa (u procentima)", x = "Fault_Type", y = "Broj posmatranja") +
  ylim(0, max(freq$Freq) * 1.15) +
  theme_minimal()

# Provera fizičkih nelogičnih vrednosti
which(dataset$Temperature <= 0 | dataset$Pressure <= 0 | dataset$Voltage <= 0 | 
        dataset$Flow_Rate < 0 | dataset$Current < 0)

# Boxplotovi u odnosu na Fault_Type
boxplot(Temperature ~ Fault_Type, data=dataset, col="lightgreen")
boxplot(Pressure ~ Fault_Type, data=dataset, col="lightgreen")
boxplot(Flow_Rate ~ Fault_Type, data=dataset, col="lightgreen")
boxplot(Current ~ Fault_Type, data=dataset, col="lightgreen")
boxplot(Voltage ~ Fault_Type, data=dataset, col="lightgreen")
boxplot(Vibration ~ Fault_Type, data=dataset, col="lightgreen")

# Pretvaranje Fault_Type u faktor
dataset$Fault_Type <- factor(
  dataset$Fault_Type,
  levels = c("0", "1", "2", "3"),
  labels = c("Normal", "Overheating", "Leakage", "Power_Fluctuation")
)
###NOVO

# Kreiranje novih karakteristika za bolje modelovanje
dataset <- dataset %>%
  mutate(
    Avg_Sensor = rowMeans(select(., Temperature, Vibration, Pressure, Flow_Rate, Current, Voltage)),  # Prosečan senzor
    Ratio_Flow_Pressure = Flow_Rate / Pressure,  # Odnos protoka i pritiska (korisno za Leakage)
    Ratio_Current_Voltage = Current / Voltage    # Odnos struje i napona (za Power Fluctuation)
  )

Obrada nedostajućih vrednosti (nema ih, ali za svaki slučaj)
dataset <- na.omit(dataset)

#Skaliranje numeričkih promenljivih (centriranje i skaliranje)
num_cols <- sapply(dataset, is.numeric)
preProc <- preProcess(dataset[, num_cols], method = c("center", "scale"))
dataset[, num_cols] <- predict(preProc, dataset[, num_cols])

#Balansiranje klasa zbog disbalansa (oversampling manjinskih klasa koristeći ROSE)
balanced_data <- ROSE(Fault_Type ~ ., data = dataset, seed = 123)$data


library(smotefamily)

smote_out <- SMOTE(
  X = dataset[, base_sensors],
  target = dataset$Fault_Type,
  K = 5
)

balanced_data <- smote_out$data
balanced_data$Fault_Type <- as.factor(balanced_data$class)
balanced_data$class <- NULL


#Podela na train i test set (80% train, 20% test)
set.seed(123)
trainIndex <- createDataPartition(balanced_data$Fault_Type, p = 0.8, list = FALSE)
train_data <- balanced_data[trainIndex, ]
test_data <- balanced_data[-trainIndex, ]

#Izgradnja Random Forest modela
rf_model <- randomForest(Fault_Type ~ ., data = train_data, ntree = 100, importance = TRUE)

# Predikcije i evaluacija
rf_pred <- predict(rf_model, test_data)
rf_prob <- predict(rf_model, test_data, type = "prob")  # Za ROC

# Confusion matrix i tačnost
confusionMatrix(rf_pred, test_data$Fault_Type)

# ROC i AUC za multi-class (one-vs-all prosečan AUC)
roc_multi <- multiclass.roc(test_data$Fault_Type, rf_prob)
auc(roc_multi)  # Ispis AUC

# Vizuelizacija ROC (prosečna kriva)
plot(roc_multi$rocs[[1]])
for(i in 2:length(roc_multi$rocs)) lines(roc_multi$rocs[[i]])

# Važnost atributa
varImpPlot(rf_model)

# Dodatni model za poređenje - Multinomijalna logistička regresija
log_model <- multinom(Fault_Type ~ ., data = train_data)
log_pred <- predict(log_model, test_data)
confusionMatrix(log_pred, test_data$Fault_Type)

# Poređenje tačnosti modela
rf_acc <- confusionMatrix(rf_pred, test_data$Fault_Type)$overall['Accuracy']
log_acc <- confusionMatrix(log_pred, test_data$Fault_Type)$overall['Accuracy']
cat("Random Forest Accuracy:", rf_acc, "\n")
cat("Multinomial Logistic Regression Accuracy:", log_acc, "\n")
