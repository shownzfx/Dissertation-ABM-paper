#EW model experiments


# Windows
library(nlexperiment)
nl_netlogo_path("C:/Program Files/NetLogo 6.0.2/app")  #to netlogo installation on windows
nl_netlogo_path()
setwd("C:/Users/shown/Documents/GitHub/EW-model")
module_file_path = "C:/Users/shown/Documents/GitHub/EW-model/EW draft 1.nlogo"

# AGAVE
library(nlexperiment)
nl_netlogo_path("/packages/7x/netlogo/6.0.2/app")  #to netlogo installation
nl_netlogo_path()
setwd("/home/fzhang59/dev/EW-model")
module_file_path = "/home/fzhang59/dev/EW-model/EW draft 1.nlogo"

experiment <- nl_experiment(
  model_file = module_file_path,
  iterations = 120,
  repetitions = 100,
  
  param_values = nl_param_oat(
    intensityThreshold = c(0,0.5,1),
    orgBudget = c(0,4000,2000)
    repairRatio=c(0,1,0.5),
    extremeWeatherDamage=c(0,20,10),
    adaptThreshold=c(0,10,5),
    maxPrevention=c(0,20,10),
    damageRatioThreshold=c(0,0.3,0.15),
    interval=c(0,48,24),
    numMonths = c(0,48,24),
    chooseStrategy= c("rememberFrequency","rememberCumDamage","rememberSevereDamage",
                      "riskPerception","doNothing"),
    riskPerceptionThreshold=c(0,150,75)
  ),
  # mapping = c(
  #   intensity_threshold="intensity-threshold",
  #   org_budget="org-budget"
  # ),
  # step_measures = measures(
  #  mean_damage = "mean [currentDamage] of serviceArea",
  #  mean_preventionPerTick="mean [prevention] of serviceArea"
  # ),
  
  run_measures=measures(
    mean_infra="mean [infraQuality] of serviceArea",
    org_repair_budget="[orgRepairBudget] of orgs",
    org_vulnerability = "[orgVulnerability] of orgs",
    repair_cost="sum [repairCost] of serviceArea",
    extreme_weather_frequency="extremeWeatherFreq",
    prevention="mean [prevention] of serviceArea", 
    damage="mean [damagePerTick] of serviceArea",
    NumAdapt="sum [adaptTime] of orgs",
  ),
  
  step_measures=measures(
    step_infraQuality="mean [infraQuality] of serviceArea",
    step_orgVul= "[orgVulnerability] of orgs",
    whetherAdapt="[whetherAdapt] of orgs",
    step_prevention="mean [prevention] of serviceArea", 
    step_repair_cost="sum [repairCost] of serviceArea",
    step_meanDamage= "mean [damagePerTick] of serviceArea"
    
  )
)



results<-nl_run(experiment,parallel = T,print_progress = T)
results_backup <- results
write.csv(results1,"nlexperiment results.csv")




results1<-nl_get_result(results)
summary(results1)
head(results1)



aggregate(results1,by=list(results1$run_id),FUN=mean)

library(purrr)
library(dplyr)
library(ggplot2)

distinct(results1,intensityThreshold)




ggplot(results1,aes(x=factor(extremeWeatherDamage),y=mean_infra))  +
  geom_boxplot()  #sig. difference

ggplot(results1,aes(x=factor(maxPrevention),y=mean_infra))  +
  geom_boxplot() #sensitive to maxPrevention when maxPrevention is bigger than 5


ggplot(results1,aes(x=factor(intensityThreshold),y=mean_infra))  +
  geom_boxplot() #not too much difference unless intensity threshold is very high > 0.8



#examine effect of damage on mean_infra conditioned on prevention
ggplot(results1,aes(x=factor(extremeWeatherDamage),y=mean_infra))  +
  geom_boxplot()+
  facet_wrap(~factor(maxPrevention))  #interesting figure, how to deal with the so many variations

ggplot(results1,aes(x=factor(repairRatio),y=mean_infra))  +
  geom_boxplot()  #not sentitive to repairRatio; might because the maxBudget is only 500, very small


ggplot(results1,aes(x=factor(orgBudget),y=mean_infra))+
 geom_boxplot() +
  facet_wrap(~factor(intensityThreshold)) #still not sensitive to intensityThreshold unless at the

ggplot(results1,aes(x=factor(intensityThreshold),y=mean_infra))+
  geom_boxplot() #not very sentitive to threshold


ggplot(results1,aes(extreme_weather_frequency,mean_infra))+
  geom_point(aes(color=orgBudget)) +
  scale_color_gradient(low="red", high="green") 
# not very distinct pattern on budget, budget is low


ggplot(results1,aes(extreme_weather_frequency,mean_infra))+
  geom_point(aes(color=prevention)) + scale_color_gradient(low="red", high="green") 
#pattern on prevention becomes more clearer

ggplot(results1,aes(extreme_weather_frequency,mean_infra))+
  geom_point(aes(color=extremeWeatherDamage)) + 
  scale_color_gradient(low="red", high="green") 
#patter on damage also clear

#------------------adaptation------------

ggplot(results1,aes(x=factor(adaptThreshold),y=prevention))+
  geom_boxplot()#prevention is not sensitive to adaptThreshold when threshold is smaller than 15


ggplot(results1,aes(x=factor(adaptThreshold),y=mean_infra))+
  geom_boxplot() #adaptThreshold does not matter to infra quality, why?

ggplot(results1,aes(x=factor(adaptThreshold),y=mean_infra))+
  geom_boxplot()+
  facet_grid(~extremeWeatherDamage) #when accounting for extremeweatherDamage, it becomes sensitive



# 
# ggplot(results2,aes(extreme_weather_frequency,mean_infra))+
#   geom_point(aes(color=repairRatio, size =1/intensityThreshold)) +scale_color_gradient(low="green", high="red")
# 
# 


#experiment 2 with less combinations
experiment2 <- nl_experiment(
  model_file = module_file_path,
  iterations = 120,
  repetitions = 100,
  
  param_values = list(

    chooseStrategy=c("rememberFrequency","rememberCumDamage","riskPerception",
                       "rememberSevereDamage","doNothing"),
    
    intensityThreshold = seq(0,1,0.2),   
    orgBudget = seq(0,3000,1000),
    repairRatio=seq(),
    
    extremeWeatherDamage=c(0,5,10),
    adaptThreshold=seq(0,10,5),
    maxPrevention=seq(0,10,5),
    adaptCostPerUnit=c(1,2),
    cumDamageRatioThreshold=c(0,5,8,10),
    damageRatioThreshold=c(0,0.1,0.25,0.5),
    numMonths=c(0,12,24,36),
    interval=c(0,11,23,35)
    
  ),
  
  mapping=nl_default_mapping,
  
  step_measures = measures(
    mean_infra_perTick="mean [infraQuality] of serviceArea",
    mean_damage_perTick = "mean [currentDamage] of serviceArea",
    mean_preventionPerTick="mean [prevention] of serviceArea"
  ),

  run_measures=measures(
    mean_infra="mean [infraQuality] of serviceArea",
    org_repair_budget="[orgRepairBudget] of orgs",
    org_vulnerability = "mean [infraVulnerability] of serviceArea",
    repair_cost="sum [repairCost] of serviceArea",
    extreme_weather_frequency="extremeWeatherFreq",
    prevention="mean [prevention] of serviceArea",
    damage="mean [currentDamage] of serviceArea"
  )
)


results2_lessCombinations<-nl_run(experiment2,print_progress = T,parallel = T)
results2<-nl_get_result(results2_lessCombinations)
dim(results2)
summary(results2)

results2_step<-nl_get_step_result(results2_lessCombinations)
dim(results2_step)


#examine effect of damage on mean_infra conditioned on prevention
ggplot(results2,aes(x=factor(extremeWeatherDamage),y=mean_infra))  +
  geom_boxplot()+
  facet_wrap(~factor(maxPrevention))  #interesting figure, how to deal with the so many variations

ggplot(results2,aes(x=factor(repairRatio),y=mean_infra))  +
  geom_boxplot()  #not sentitive to repairRatio; might because the maxBudget is only 500, very small

results2 %>% filter(orgBudget==2000) %>% 
  ggplot(aes(x=factor(repairRatio),y=mean_infra))  +
  geom_boxplot()

results2 %>% filter(orgBudget==2000) %>% 
  group_by(repairRatio) %>% summarise(meanInfra=mean(mean_infra))
  

ggplot(results2,aes(x=factor(orgBudget),y=mean_infra))  +
  geom_boxplot() 


ggplot(results2,aes(x=factor(orgBudget),y=mean_infra))+
  geom_boxplot() +
  facet_wrap(~factor(intensityThreshold)) #still not sensitive to intensityThreshold unless at the

ggplot(results2,aes(x=factor(intensityThreshold),y=mean_infra))+
  geom_boxplot() #not very sentitive to threshold


ggplot(results2,aes(extreme_weather_frequency,mean_infra))+
  geom_jitter(aes(color=orgBudget),alpha=0.5,size=1) +
  scale_color_gradient(low="red", high="green") 
# not very distinct pattern on budget, budget is low


ggplot(results2,aes(extreme_weather_frequency,mean_infra))+
  geom_jitter(aes(color=prevention),alpha=0.5,size=1) + scale_color_gradient(low="red", high="green") 
#pattern on prevention becomes more clearer

ggplot(results2,aes(extreme_weather_frequency,mean_infra))+
  geom_point(aes(color=extremeWeatherDamage)) + 
  scale_color_gradient(low="green", high="red") 
#patter on damage also clear

#------------------adaptation------------

ggplot(results2,aes(x=factor(adaptThreshold),y=prevention))+
  geom_boxplot()#prevention is not sensitive to adaptThreshold when threshold is smaller than 15


ggplot(results2,aes(x=factor(adaptThreshold),y=mean_infra))+
  geom_boxplot() #adaptThreshold does not matter to infra quality, why?

ggplot(results2,aes(x=factor(adaptThreshold),y=mean_infra))+
  geom_boxplot()+
  facet_grid(~extremeWeatherDamage) #when accounting for extremeweatherDamage, it becomes sensitive



#-------------adaptation----------
library(ggplot2)
library(dplyr)
ggplot(results2,aes(x=factor(adaptThreshold),y=prevention))+
  geom_boxplot()#prevention is not sensitive to adaptThreshold when threshold is smaller than 15
results2 %>% 
  filter(orgBudget==2000 & intensityThreshold >=0.8) %>% 
  group_by(adaptThreshold) %>% summarise(meanPrevention= mean(prevention),meanInfra=mean(mean_infra))



ggplot(results2,aes(x=factor(adaptThreshold),y=mean_infra))+
  geom_boxplot() #adaptThreshold does not matter to infra quality, why?

ggplot(results2,aes(x=factor(adaptThreshold),y=mean_infra))+
  geom_boxplot()+
  facet_grid(~extremeWeatherDamage) #when accounting for extremeweatherDamage, it becomes sensitive

#-----------------------step measures----------------------------

