options(scipen = 999) #fix scientific notation

library(tidyverse)

#read and merge train and test sets to create features
data <- read.csv("train.csv", header = T, stringsAsFactors = F)
data1 <- read.csv("test.csv", header = T, stringsAsFactors = F)
data1$Survived <- NA
data <- bind_rows(data, data1)
rm(data1)

#get total family size
data$fam_size <- data$Parch + data$SibSp

#Exract title - which already contains age and sex
#with no missing data: unique titles for men, women, boys, girls
data <- data %>% mutate(title = case_when(grepl("Mr\\.", data$Name)~"Mr",
                                  grepl("Don\\.", data$Name)~"Mr",
                                  grepl("Mrs\\.", data$Name)~"Mrs",
                                  grepl("Mme\\.", data$Name)~"Mrs",
                                  grepl("Dona\\.", data$Name)~"Mrs",
                                  grepl("Countess\\.", data$Name)~"Mrs",
                                  grepl("Miss", data$Name)~"Miss",
                                  grepl("Mlle\\.", data$Name)~"Miss",
                                  grepl("Master\\.", data$Name)~"Master",
                                  TRUE~"Other"
                                  ))

#fix reference classes
data$Sex <- relevel(factor(data$Sex), ref = "male")
data$title <- relevel(factor(data$title), ref = "Mr")
data$Pclass <- factor(data$Pclass)
data$Pclass <- relevel(data$Pclass, ref = "3")

#travelling alone?
data$alone <- ifelse(data$fam_size == 0,1,0)

#See if anyone with the same last name is a know survivor
data$last_name <- str_extract(data$Name,"[:upper:]{1}[:lower:]{1,}.{0,},")

length(unique(data$last_name))

#Did anyone with the same last name, travelling from the same port 
#on the same ticket survive?
data$anyone_surv <- NA

for (i in 1:nrow(data))
{data[i,18] <- 
data %>% dplyr::filter(last_name == data[i,16] & Name != data[i,4] & Embarked == data[i,12] & Fare == data[i,10]) %>% 
  summarise(max(Survived, na.rm = T))
}
data$anyone_surv[data$anyone_surv==-Inf] <- "Unknown"

data <- data %>% 
  mutate(anyone_surv = ifelse(alone == 1&anyone_surv=="Unknown",0,anyone_surv))

data$anyone_surv <- factor(data$anyone_surv)

#count of family survivors
data$count_surv <- NA

for (i in 1:nrow(data))
{data[i,19] <- 
  data %>% dplyr::filter(last_name == data[i,16] & Name != data[i,4] &
                           Embarked == data[i,12] & Fare == data[i,10] &
                           Survived == 1) %>% 
  summarise(n())
}

table(data$anyone_surv, data$count_surv)

#select data for modeling
model <- data %>% select(Survived, Pclass, Age_nona, Age_sq, Sex,
                alone, anyone_surv, count_surv, title)
model$Survived <- factor(model$Survived)
model$Pclass <- factor(model$Pclass)

train <- model[is.na(model$Survived)==F,]
test <- model[is.na(model$Survived)==T,]

#some EDA
#class and title have non-additive relatinship with survival. 
#Young boys and girls all survive in 
#class 1 and 2, so do married women
#men  barely survive anywhere
train %>% group_by(Pclass, title) %>% summarise(Perc_surv = sum(Survived)/n()) %>%
ggplot(., aes(x = Pclass, y = Perc_surv)) + geom_col() +
  facet_grid(title ~ .) + coord_flip()

#same for whether someone's travelling alone
#women survive alone, men a bit more likely survive with families
train %>% group_by(alone, title) %>% summarise(Perc_surv = sum(Survived)/n()) %>%
  ggplot(., aes(x = alone, y = Perc_surv)) + geom_col() +
  facet_grid(title ~ .) + coord_flip()

#use interaction terms to capture this non-linearity
#Since there are some rare combinations of factors (few boys in 1st class),
#using corss-validation will produce samples with some combinations missing
table(train$Pclass, train$title)

#using a logistic regression without cross-validation
#extra bump in predicted probability if travellign with a konds survivor
glm1 <- glm(Survived ~ Pclass*title + alone*title + count_surv, data = train,
            family = "binomial")
summary(glm1)

test$Survived <- predict(glm1,test, type = "response")
test$Survived <- round(test$Survived,0)

#select predictions and bind with passenger ids
result6 <- test %>% select(1)
bind_cols(data$PassengerId[is.na(data$Survived)],result6) %>%
  setNames(c("PassengerId","Survived")) %>%
write.csv(., "result6.csv", row.names = F)