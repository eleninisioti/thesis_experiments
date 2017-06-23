# Trains model for predicting decay of nnet.

# --- set up ---
rm(list=ls())
setwd("thesis_experiments")
source("HPP_train/math_tools/boot_pi.R")
library(caret)
set.seed(1)
library(tikzDevice)

# --- define functions ---
RMSE <- function(x,y) {
  sqrt( sum( (x - y)^2 , na.rm = TRUE ) / length(x) )
}

# --- load data---
training_data                <- read.csv("HPP_train/predict_size/training.csv",
                                         header = TRUE, sep=",", stringsAsFactors=FALSE)
training_data$hasNumeric     <- NULL
training_data$hasCategorical <- NULL
training_data$X              <- NULL

# --- scale data ---
x                                       <- scale(training_data[,-c(ncol(training_data))])
means                                   <- attr(x, "scaled:center")
scales                                  <- attr(x, "scaled:scale")
training_data[,-c(ncol(training_data))] <- scale(training_data[,-c(ncol(training_data))])


# --- evaluate model ---
fitControl <- trainControl(## 10-fold CV
  method = "repeatedcv",
  number = 10,
  repeats = 1
)
predictions_with_confidence <- list()
root_error                  <- c()
metafeatures                <- training_data
for(i in seq(1, nrow(metafeatures))) {
  trainData      <- metafeatures[-c(i),]
  testData       <- metafeatures[i,]
  testClass      <- testData[, "Class"]
  testData$Class <- NULL
  trained_model  <- caret::train(log10(Class) ~ ., data = trainData,
                                 method = "svmRadial", 
                                 trControl=fitControl, keep.inbag = TRUE)
  predictions    <- boot_pi(model = trained_model, pdata = testData, n = 50, p = 0.98)
  predictions_with_confidence[[i]] <- predictions
  root_error     <- append(root_error, RMSE(predictions, testClass))
}
mean_root_error <- mean(root_error)

# --- plot confidence intervals for testing files ---
test_class                       <- metafeatures$Class  
y                                <- unlist(lapply(predictions_with_confidence, function(x) x[1]))
x                                <- seq_along(y)
ci_low                           <- (unlist(lapply(predictions_with_confidence, function(x) x[2])))
ci_high                          <- (unlist(lapply(predictions_with_confidence, function(x) x[3])))

tikz('HPP_train/predict_size/intervals.tex', standAlone = TRUE, width=5, height=5)
plot(y, ylim = c(min(c(test_class,ci_low))-0.01, max(c(test_class, ci_high))+0.01))
points(test_class, col="red")
arrows(x, ci_low, x, ci_high, code=3, angle=90, length=0.05)
dev.off()

# --- save workspace
save(list = ls(all.names = TRUE), file = "HPP_train/predict_size/workspace.RData", envir = .GlobalEnv)

# --- train and store model and parameters ---
model   <- caret::train(log10(Class) ~ ., data = training_data,
                        method = "svmRadial", 
                        trControl=fitControl)
save(model, file = "HPP_train/predict_size/model.RData")
model_p <- data.frame(metafeatures = metafeatures, means = means, scales = scales,
                      n_boot = 50 , percentage  = 0.95, enableLog = 1, step = 1, count = 1)
write.csv(model_p, "HPP_train/predict_size/model_parameters.csv")

