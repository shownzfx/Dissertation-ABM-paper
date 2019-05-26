
library(nlexperiment)
nl_netlogo_path("/packages/7x/netlogo/6.0.2/app")  #to netlogo installation on AGAVE
setwd("/home/fzhang59/dev/Dissertation-ABM-paper")
module_file_path =  "/home/fzhang59/dev/Dissertation-ABM-paper/Dissertation_ABM_0526.nlogo"

#experiment

experiment <- nl_experiment(
  model_file = module_file_path,
  repetitions = 10,
  iterations = 720,
  
  param_values = list(
    meanRIskThreshold = seq(0.3,0.5,0.1),
    scanningRange = seq(1,6,2),
    numWindows = seq(0,8,2),
    badImpact = 0.08,
    impactReductionRate = seq(0.1,0.3,0.05),
    maxCopingReduction = c(0, 0.20,0.30, 0.40),
    adaptationCost = 6.5,
    capBoost = seq(0, 3,1),
    simTicks = 720
  ),
  run_measures = measures(
    copingNum = "count orgs with [coping-change?]",
    adaptNum = "count orgs with [adaptation-change?]"
    # disasterWindows="[disasterWindows] of orgs",
    # orgWindows="[orgWindows] of orgs"
  ),
  agents_step = list(
    orgs = agent_set(
      vars = c("adaptation-change?", "coping-change?", "riskPerceptionThreshold", "expectedImpact", "solEfficacy","window-open?","window-missed?","insufBoost?","originalCapacity"),
      agents = "orgs")
  ),
  mapping = nl_default_mapping
)
# cbind(experiment$mapping)  #check parameter names mapping

result1 <- nl_run(experiment, parallel = T)
save.image("output.RData")




