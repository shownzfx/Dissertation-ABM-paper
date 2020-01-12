library(nlexperiment)

nl_netlogo_path("/packages/7x/netlogo/6.0.2/app")  #to netlogo installation on AGAVE
setwd("/home/fzhang59/dev/Dissertation-ABM-paper/Agave_Experiment")
module_file_path =  "/home/fzhang59/dev/Dissertation-ABM-paper/Agave_Experiment/Dissertation_ABM_0601_experiments with perception and tolerance.nlogo"


# use in windows
# nl_netlogo_path("C:/Program Files/NetLogo 6.0.2/app")
# module_file_pathWindows <- "C:/Z-Work/Dissertation/Data and analysis/Dissertation ABM paper/Agave_Experiment/Dissertation_ABM_0601_experiments with perception and tolerance.nlogo"


experiment <- nl_experiment(
  model_file = module_file_path,
  repetitions =25,
  random_seed = 1:25,
  iterations =1000,
  
  param_values = nl_param_oat(
    n=20,
    meanRIskThreshold = 0.4,
    scanningRange = 4,
    numWindows = c(0,6,10),
    badImpact = 0.08,
    impactReductionRate =0.25,
    maxCopingReduction = 0.40,
    adaptationCost = 6.5,
    capBoost = c(1, 2.5,4),
    simTicks = 1000,
    minNeighbor=c(1,2,4), 
    officeRole =1,
    changeAspiration=1, 
    EWProbDecay=c(0, 0.015,0.030), 
    b1=c(0,0.5,1)
  ),
  
  
  run_measures = measures(
    copingNum = "count orgs with [coping-change?]",
    adaptNum = "count orgs with [adaptation-change?]",
    insufBoost ="totalInsufBoost",
    disasterWindows="totalDisasterWindows",
    windowMissed="totalwindowMissed",
    windowsOpen="totalWindowOpen",
    noSolution="totalNoSolution",
    utilizedWindows="totalUtilizedWindows",
    NeededWidows="totalNeededWidows",
    notNeeded="sufficientCap",
    usedDisasterWindows= "totalUtilizedDisasterWindows"
  )
  # step_measures = measures(
  #   sCoping="count orgs with [coping-change?]",
  #   sAdapt="count orgs with [adaptation-change?]",
  #   sNotFound="count orgs with [not-found?]",
  #   SInsufBoost="count orgs with [insufBoost?]",
  #   sWindowOpen="count orgs with [window-open?]",
  #   sWindowMissed="count orgs with [window-missed?]",
  #   sHappy="count orgs with [expectedImpact > riskPerceptionThreshold]"
  # ),
  # eval_criteria = criteria(
  #   meanAdaptNum=mean(step$sAdapt),
  #   stdAdaptNum=sd(step$sAdapt),
  #   meanCopingNum=mean(sCoping),
  #   sdCopingnum=sd(sCoping)
  # ),
  # agents_step = list(
  #   orgs = agent_set(
  #     vars = c("adaptation-change?", "coping-change?", "riskPerceptionThreshold", "expectedImpact", "solEfficacy","window-open?","window-missed?","insufBoost?","originalCapacity","solution-ready?","utilizedWindow?","sufficientCap", "extremeWeatherProb","originalEfficacy","disasterProb","declarationRate","region","used-disasterWindow?"),
  #     agents = "orgs")
  # ),
  # mapping = nl_default_mapping 
)

result1to25 <- nl_run(experiment,parallel = T)
#dataRun1to25 <-nl_get_run_result(result1to25)
#write.csv(dataRun1to25 ,"output 1_to_25Reps.csv")


save.image("output_1_to_25Reps.RData")



