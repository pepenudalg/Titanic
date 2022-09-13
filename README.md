# Titanic
Simple Top 4% solution to Kaggle Titanic competition based on 4 features: Title (e.g. Mr, Mrs etc.), Passenger Class, whether someone is travelling alone, and other known survivors from the group.

Title is highly informative, as it contains the information about socially-meaningful age and gender distinctions and is available for every passenger.
Title and class are not linearly related to survival probability: almost all boys and women survive in classes 1 and 2. Only some men surivive in Class 1.

<img src="https://user-images.githubusercontent.com/12826695/190009594-f34cefd6-8882-46d1-8f6a-08b397838271.png" data-canonical-src="https://user-images.githubusercontent.com/12826695/190009594-f34cefd6-8882-46d1-8f6a-08b397838271.png" width="450" height="600" />

Title also interacts with the number of passengers in the group. Men are slightly more likely survive if they are travelling with families, women are more likely to survive if they are travelling alone.

<img src="https://user-images.githubusercontent.com/12826695/190010691-6a9ae3c2-38ba-46dd-abce-6dff92712843.png" data-canonical-src="https://user-images.githubusercontent.com/12826695/190010691-6a9ae3c2-38ba-46dd-abce-6dff92712843.png" width="450" height="600" />

Finally, we can leverage the fact the observations are not independent: passengers are more likely to have survived if there are other known survivors that have the same last name and embarked in the same port, and paid the same fare.

<img src="https://user-images.githubusercontent.com/12826695/190011145-358af904-731b-4064-bad9-f533ffa0c7a0.png" data-canonical-src="https://user-images.githubusercontent.com/12826695/190011145-358af904-731b-4064-bad9-f533ffa0c7a0.png" width="450" height="300" />

We combine these features in a simple logistic regression with interaction terms and achieve accuracy > 0.8
