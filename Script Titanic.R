options(scipen = 999) #fix scientific notation
setwd("...")#enter wd

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

#See if anyone with the same last name is a known survivor, if so - how many
data$count_surv <- NA

for (i in 1:nrow(data))
{data[i,"count_surv"] <- 
  data %>% dplyr::filter(last_name == data[i,"last_name"] & Name != data[i,"Name"] &
                           Embarked == data[i,"Embarked"] & Fare == data[i,"Fare"] &
                           Survived == 1) %>% 
  summarise(n())
}


#select data for modeling
model <- data %>% select(Survived, Pclass, Sex,
                alone, count_surv, title)
model$Pclass <- factor(model$Pclass, levels = c(1,2,3))
model$alone <- factor(model$alone, levels = c(0,1))

train <- model[is.na(model$Survived)==F,]
test <- model[is.na(model$Survived)==T,]

#some EDA
#class and title have non-additive relationship with survival. 
#Young boys and girls all survive in 
#class 1 and 2, so do married women
#men  barely survive anywhere
train %>% group_by(Pclass, title) %>% summarise(Perc_surv = sum(Survived)/n()) %>%
ggplot(., aes(x = Pclass, y = Perc_surv, fill = Pclass)) + geom_col() + 
  ylab("Percent Survivors") +
  xlab("Class") +
  facet_grid(title ~ .) + coord_flip() + theme_bw() +
  theme(legend.position = "none")
ggsave("title.png", device = "png", width = 4.5, height = 6)


#same for whether someone's travelling alone
#women survive alone, men a bit more likely survive with families
train %>% group_by(alone, title) %>% summarise(Perc_surv = sum(Survived)/n()) %>%
  ggplot(., aes(x = alone, y = Perc_surv, fill = alone)) + geom_col() +
  facet_grid(title ~ .) + coord_flip() +   ylab("Percent Survivors") +
  xlab("Travelling alone") + theme_bw() +
  theme(legend.position = "none")
ggsave("alone.png", device = "png", width = 4.5, height = 6)


#observations are not independent
#if people you're travelling with survived, you are more likely to have survived too
train %>% group_by(count_surv) %>% summarise(Perc_surv = sum(Survived)/n()) %>%
  ggplot(., aes(x = count_surv, y= Perc_surv, fill = "fill")) + geom_col() + 
  theme_bw() + ylab("Percent Survivors") + 
  xlab("N of known surviving group members") + theme(legend.position = "none")
ggsave("N of surviving members", device = "png", width = 4.5, height = 3)

#use interaction terms to capture this non-linearity
#Since there are some rare combinations of factors (few boys in 1st class),
#using cross-validation will produce samples with some combinations missing
table(train$Pclass, train$title)

#using a logistic regression without cross-validation
#extra bump in predicted probability if travelling with a known survivor
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