
library(nlexperiment)
nl_netlogo_path("/packages/7x/netlogo/6.0.2/app")  #to netlogo installation on AGAVE
setwd("/home/fzhang59/dev/Dissertation-ABM-paper")
module_file_path =  "/home/fzhang59/dev/Dissertation-ABM-paper/Dissertation_ABM_0527_QuickerVersion.nlogo"


#try windows
# nl_netlogo_path("C:/Program Files/NetLogo 6.0.2/app")
# setwd("C:/Z-Work/Dissertation/Data and analysis/Dissertation ABM paper")
# module_file_pathWindows <- "C:/Z-Work/Dissertation/Data and analysis/Dissertation ABM paper/Dissertation_ABM_0526_QuickerVersion.nlogo"


experiment <- nl_experiment(
  model_file = module_file_path,
  repetitions =10,
  random_seed = 1:10,
  iterations =1000,
  
  param_values = nl_param_oat(
    n=10,
    meanRIskThreshold = 0.4,
    scanningRange = 4,
    numWindows = c(0,4,10),
    badImpact = 0.08,
    impactReductionRate =0.25,
    maxCopingReduction = 0.40,
    adaptationCost = 6.5,
    capBoost = c(0, 3,5),
    simTicks = 1000
  ),
  
  run_measures = measures(
    copingNum = "count orgs with [coping-change?]",
    adaptNum = "count orgs with [adaptation-change?]",
    insufBoost ="totalInsufBoost",
    windowMissed="totalwindowMissed",
    windowoOpen="totalWindowOpen",
    noSolution="totalNoSolution",
    disasterWindows="totalDisasterWindows",
    riskPerceptionThreshold="[riskPerceptionThreshold] of orgs"
  ),
  step_measures = measures(
    sCoping="count orgs with [coping-change?]",
    sAdapt="count orgs with [adaptation-change?]",
    sNotFound="count orgs with [not-found?]",
    SInsufBoost="count orgs with [insufBoost?]",
    sWindowOpen="count orgs with [window-open?]",
    sWindowMissed="count orgs with [window-missed?]",
    sHappy="count orgs with [expectedImpact > riskPerceptionThreshold]"
  ),
  # eval_criteria = criteria(
  #   meanAdaptNum=mean(step$sAdapt),
  #   stdAdaptNum=sd(step$sAdapt),
  #   meanCopingNum=mean(step$sCoping),
  #   sdCopingnum=sd(step$sCoping)
  # ),
  # agents_step = list(
  #   orgs = agent_set(
  #     vars = c("adaptation-change?", "coping-change?", "riskPerceptionThreshold", "expectedImpact", "solEfficacy","window-open?","window-missed?","insufBoost?","originalCapacity"),
  #     agents = "orgs")
  # ),
  mapping = nl_default_mapping 
)


result <- nl_run(experiment,parallel = T)

# runData<-nl_get_run_result(result)
# stepData<-nl_get_step_result(result)
# write.csv(runData,"Run measures 0527.csv")
# write.csv(stepData,"Step measures 0527.csv")

save.image("output_quicker_Parallel_10Runs.RData")



