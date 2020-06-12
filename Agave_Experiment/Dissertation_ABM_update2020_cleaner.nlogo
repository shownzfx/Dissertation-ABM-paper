extensions [csv profiler]


breed [orgs org]
breed [solutions solution]
breed [FTAoffices FTAoffice]

undirected-link-breed [org-sol-links org-sol-link]
undirected-link-breed [org-sameReg-links org-sameReg-link]
undirected-link-breed [org-diffReg-links org-diffReg-link]
undirected-link-breed [FTAoffice-org-links FTAoffice-org-link]

globals [regionDiv totalLackMotivation
         totalOptOpen totalInsufBoost totalNoSolution totalDisasterOpts totalUtilizedDisasterOpts
          totalUtilizedOpts totalNeededOpts sufficientCap totalUtilized totalAlreadyAdapted
          totalOrgOpts totalUtilizedOrgOpt totalNonEligibleDisasterOpt logFile
         BS-output totalFunding fundAvailable]

patches-own [patchRegion]
solutions-own [efficacy cost adaptation? ]; solutions include both non-adaptation and adaptation measures
FTAoffices-own [projectInventory]



orgs-own [
  agencyID
  region
  diffRegionNeighbors
  partner
  insufBoost?
  target-patches
  extremeWeatherProb
  disasterProb
  extremeWeatherThreshold
  disasterThreshold
  extremeWeather? ; boolean whether the weather is extreme
  weatherIntensityExp ; document an org's weatherIntensity over 200 years to find the norm and extremes
  diaster?
  weatherIntensity
  solEfficacy
  anticipatedMitigation
  FTARegion
  declarationRate
  declared?
  postponed?
  knownSolutions
  targetSolCost
  search-adaptation?
  missedOpts
  utilizedOpportunity?
  insufBoost?
  not-found?
  knownSolFromOffice
  regionalNeighbors
  capacity ;used to decide if orgs have sufficient capacity to implement solutions
  originalCapacity
  regionIntensityMean
  impactPerTick
  impactExp
  copingLimit
  pastWeatherIntensity
  worstWeatherIntensity
  expectedEWProb
  riskPerception
  riskTolerance
  opportunities
  opportunity-open?
  used-disasterOpt?
  orgOpts
  disasterOpts
  current-solution
  targetSolution
  targetSolCost
  coping-change?
  adaptation-change?
  disaster? ; whether happened disater or not
  satisfied?
  solution-ready?
  previousImpact
  open-orgOpportunity?
  lack-motivation?
  regionEWProbMean
  regionDisaterProbMean
  filterEW
]


to setup
  ca
;  profiler:start
;  set logFile (word "log" (random 100000) ".txt")

  set-default-shape solutions "box"
  set fundAvailable startingFund
  set totalLackMotivation 0
  set totalInsufBoost 0
  set totalOptOpen 0
  set totalNoSolution 0
  set totalDisasterOpts 0
  set totalUtilizedOpts 0
  set totalNeededOpts 0
  set totalUtilizedDisasterOpts 0
  set sufficientCap 0
  set totalFunding 0
  import-orgs
  setup-orgs

  if randomOrgOpt?  ; whether to set up orgOpts at the model setup, otherwise Opportunities need to be generated based on EW
  [setup-orgOpportunities]
  distribute-orgs
  setup-regionalRiskThreshold
  setup-FTARegion
  setup-solutions
; record-weather-norm  ; only use it when not using hard coded threshold values for weather intensity
  setup-network


    reset-ticks

end



to import-orgs
  file-open "Transit agencies ABM clean noHeader_062020.csv"
  while [not file-at-end?]
  [
    let row csv:from-row file-read-line
    create-orgs  1 [
      set agencyID item 0 row
      set capacity item 1 row + 1.57 ; -1.57 is the min capacity
      if enoughCap?
      [set capacity capacity + 10]
      set originalCapacity capacity
      set region item 2 row
      set FTARegion item 4 row
      set declarationRate (item 5 row + random-float 0.02 ) * (1 / 24) ;
      set extremeWeatherProb item 6 row
      set expectedEWprob extremeWeatherProb
      set disasterProb item 7 row
      set extremeWeatherThreshold item 8 row
      set disasterThreshold item 9 row
      set worstWeatherIntensity item 10 row

      If extremeWeatherProb < disasterProb [
         print "extremeWeatherProb is smaller than disasterProb"
      ]
    ]
 ]

  file-close
end




to setup-orgs
  ask orgs [
    set color white
    set shape "circle"
    set size 0.6
    set not-found? false
    set copingLimit 0
    set anticipatedMitigation 0
    set Opportunities []
    set orgOpts []
    set disasterOpts []
    set insufBoost? false
    set missedOpts []
    set opportunity-open? false
    set lack-motivation? false
    set knownSolFromOffice []
    set satisfied? true
    set utilizedOpportunity? false
    set search-adaptation? false
    set targetSolCost 0
    set used-disasterOpt? false
    set declared? false
    set coping-change? false
    set adaptation-change? false
    set extremeWeather? false
    set disaster? false
    set postponed? false
    set solution-ready? false
    set targetSolution nobody
    set pastWeatherIntensity []
    set open-orgOpportunity? false
    set filterEW [] ;

    set riskPerception (worstWeatherIntensity -  solEfficacy) * expectedEWprob
    if riskPerception < 0 [print "risk perception <0 "  set riskPerception 0]

  ]

  ask FTAoffices [
    set projectInventory []
  ]
end


to setup-orgOpportunities
  if orgOptGen = "allRandom"
  [
     ask orgs [
       repeat random numOpts [
         let n random 1000 ; 1000 ticks
         set orgOpts sentence n orgOpts
         set Opportunities remove-duplicates orgOpts
       ]
     ]
  ]

    if orgOptGen = "controlNum"
  [
     ask orgs [
       repeat numOpts[
         let n random 1000 ; 1000 ticks
         set orgOpts sentence n orgOpts
         set Opportunities remove-duplicates orgOpts
       ]
     ]
  ]


  if orgOptGen = "diffused"
  [
    ask orgs [
    let n 0
    while [n <= 1000] [
       let OpportunityTick random  100 + n
       if OpportunityTick <= 1000
       [set orgOpts remove-duplicates (sentence orgOpts OpportunityTick)]
       set Opportunities remove-duplicates orgOpts
       set n n + 100
    ]
   ]
  ]


  if orgOptGen = "concentrated"
  [
    ask orgs [
       let n random 800
       let x 0
       while [ x <= 90][
        let OpportunityTick n +  x + random 10
        set orgOpts remove-duplicates (sentence orgOpts OpportunityTick)
        set x x + 10
        ]
     ]
  ]

  if orgOptGen = "twoOpportunities"
  [
     ask orgs [
      let n random 100
      set orgOpts sentence n orgOpts
      let m random 100 + 900
      set orgOpts sentence m orgOpts
    ]
  ]

    if orgOptGen = "oneOpportunity"
  [
     ask orgs [
      let n random 1000
      set orgOpts sentence n orgOpts
    ]
  ]



end


to distribute-orgs  ; distribute orgs to 4 census region, with similar weather profile
  ask patches [if pxcor >= -0.05 and pxcor <= 0.05 [set pcolor grey]]
  ask patches [if pycor >= -0.05 and pycor <= 0.05 [set pcolor grey]]

  ask patches with [pxcor <=  16 and pxcor > 0.1 and pycor > 0.1] [set patchRegion "northeast"]
  ask patches with [pxcor <= 16 and pxcor > 0.1 and pycor < -0.1] [set patchRegion "south"  ]
  ask patches with [pxcor >= -16 and pxcor <= -0.1 and pycor >= 0.1] [set patchRegion "west" ]
  ask patches with [pxcor >= -16 and pxcor <= -0.1 and pycor < -0.1] [set patchRegion "midwest" ]

  ask patch 8 8 [set plabel "NE"]
  ask patch 8 -8 [set plabel "South"]
  ask patch -8 8 [set plabel "West"]
  ask patch -8 -8 [set plabel "MW"]


  (foreach ["northeast" "midwest" "south" "west"] [  ; distribute orgs to desginated areas
    x -> ask orgs with [region = x][
      set target-patches patches with [patchRegion = x]
    ]
  ])

ask orgs [  ; one org per patch
    if target-patches != nobody [
     move-to one-of target-patches
      while [any? other turtles-here][
        move-to one-of target-patches
      ]
    ]
  ]

end

to setup-regionalRiskThreshold

  ifelse randomRiskThresh?

  [riskThreshold-byRegion]
  [ask orgs [set riskTolerance 0]]


end


to riskThreshold-byRegion

  let regionalMean1 sentence (meanRiskThreshold + 0.10) (meanRiskThreshold + 0.2)  ; threshold for northeast and midwest
  let regionalMean2 sentence (meanRiskThreshold + 0) (meanRiskThreshold + 0.3) ; threshold for south and west, south has the lowest and west has highest
  let regionalMeanTolerance sentence regionalMean1 regionalMean2

  (foreach ["northeast" "midwest" "south" "west"] regionalMeanTolerance
    [
      [x meanThreshold] ->
      ask orgs with [region = x] [
        set riskTolerance random-normal meanThreshold 0.1
        if riskTolerance < 0 [set riskTolerance 0.1]
      ]
    ])
end


to setup-FTARegion
  let FTARegions map [x -> word "FTA Region" x] n-values 11 [ i -> i]
  set FTARegions but-first FTARegions

  (foreach FTARegions [
    x ->
    let FTAorgs orgs with [FTARegion = x]
    ask [patch-here] of one-of FTAorgs [
      sprout-FTAoffices 1 [
        set shape "house"
        set size 1.8
        set color brown
        avoid-edges
        create-FTAoffice-org-links-with FTAorgs [hide-link]
      ]
    ]
  ])

end

to setup-solutions ; every turtle begins with a solution
  ask orgs [
    ask patch-here [
       sprout-solutions 1
      [
         set color green
         set adaptation? false  ; the default solutions are routine ones, not adaptation-based
         set efficacy 0.05 + random-float 0.95; for coping solutions
         set size efficacy / 2.5
         set adaptation? false
         let my-org orgs-here
         create-org-sol-links-with my-org [hide-link]
         ask my-org [set current-solution myself]
         set cost sum [capacity] of my-org - 0.01 ; set in a way such that all orgs can afford coping changes
         if cost < 0 [set cost 0.01]
         fd 0.5
      ]
    ]
    set solEfficacy [efficacy] of current-solution

  ]

  ask n-of 30 patches with [not any? turtles-here and pcolor != grey][
    sprout-solutions 1 [
      set color green ; adaptation are set blue
      set efficacy 2 + random-float 2 ;weatherIntensity ranges from approximately  2 to 5
      set cost random-float adaptationCost + 3.5
      set size efficacy / 2.5
      set adaptation? true
    ]
  ]

end

to record-weather-norm ; only activated when not using the hard coded weather parameters on the following attributes
  ask orgs [
      set weatherIntensityExp record-severity-experience
      set disasterProb regionDisaterProbMean
      set extremeWeatherProb regionEWProbMean
      set expectedEWprob extremeWeatherProb
      set extremeWeatherThreshold  item (ceiling simulateMonths * regionEWProbMean) weatherIntensityExp
      set disasterThreshold  item (ceiling simulateMonths * regionDisaterProbMean) weatherIntensityExp
      set worstWeatherIntensity item (ceiling simulateMonths * (0.05 + random-float 0.03)) weatherIntensityExp ; typically plan for 92% of the weather risks
      if disasterThreshold  < worstWeatherIntensity [print "disasterThreshold  < worstWeatherIntensity"]
      if extremeWeatherThreshold  > worstWeatherIntensity [print "extremeWeatherThreshold  < worstWeatherIntensity"]

  ]
end



to-report record-severity-experience
  let time 0
  let severity []
  let impactRecord[]
  set-weatherIntensityMean-byRegion
  while [time < simulateMonths][  ; base weather pattern on 200 year experience
    let severityPerTick log-normal regionIntensityMean  0.2;
    set severity sentence severity severityPerTick
    set time time + 1
  ]
  set severity sort-by > severity
  report severity
end


to set-weatherIntensityMean-byRegion ; four log-normal distribution, four cutoffs for EW, four cutoffs for disasters
  let regionIntensityMeanList sentence (sentence (5 + 0.5) (5 ))  (sentence (5 + 1) (5 - 0.5)) ; northest midwest south west
  let regionEWProbMeanlist sentence (sentence (0.120) (0.107 ))  (sentence (0.125) (0.080))
  let regionDisasterProbMeanList sentence (sentence (0.06) (0.05 ))  (sentence (0.065) (0.045))

 (foreach ["northeast" "midwest" "south" "west"]  regionIntensityMeanList regionEWProbMeanlist  regionDisasterProbMeanList
    [
      [a b c d ] ->
      ask orgs with [region = a] [
        set regionIntensityMean b
        set regionEWProbMean  c
        set regionDisaterProbMean d
    ]
  ])
end


to setup-network

  ask orgs [
    set regionalNeighbors other orgs with [region = [region] of myself]
    set diffRegionNeighbors other orgs with [region != [region] of myself]

    let sameRegCandidates n-of 2 regionalNeighbors
    create-org-sameReg-links-with sameRegCandidates [hide-link]

    let diffRegCandidates n-of 1 diffRegionNeighbors
    create-org-diffReg-links-with diffRegCandidates [hide-link]
  ]

end

to-report lottery-winner  ; not used in this model; but can use it when creating networks using preferential attachment
  let pick1 random-float sum [capacity] of regionalNeighbors
  let pick2 random-float sum [capacity] of diffRegionNeighbors
  let winner1 nobody
  let winner2 nobody
  ask regionalNeighbors [
    if winner1 = nobody
    [ifelse capacity > pick1
      [set winner1 self]
      [set pick1 pick1 - capacity ]
    ]
  ]

  ask diffRegionNeighbors [
    if winner2 = nobody
    [ifelse capacity > pick2
      [set winner2 self ]
      [set pick2 pick2 - capacity  ]
    ]
  ]
report list winner1 winner2
end



to go
;  profile:start

  set logFile (word "start " ticks)
  if not randomOrgOpt? [generate-orgOpportunities] ; alternative ways to distribute opportunities
  check-weather  ;unless otherwise indicated, the go procedures apply to orgs
  update-riskPerception
  Opportunities-byDeclaration
  determine-satisfaction
  search-solution
  check-capacity
  check-Opportunity
  FTAcheck-adaptation ; this is the FTAoffice procedure;

  ask orgs [
    set extremeWeather? false
    set disaster? false
    set declared? false
    if worstWeatherIntensity < riskPerception [
      print "warning: expected weather severity smaller than expected impact"
    ]
    if riskPerception < 0 [
      print "warining: riskPerception smaller than 0"
    ]
  ]

  tick
;  profiler:start
;  print profiler:report
; if ticks >= simTicks [stop]
end



to-report update-Opportunities
  let udpatedOpportunities [] ;
  repeat random numOpts [
    let updatedOpportunity random (simTicks + ticks)
    set udpatedOpportunities remove-duplicates (sentence updatedOpportunity Opportunities)
  ]
  report udpatedOpportunities
end


to check-weather
  ask orgs [
    set weatherIntensity log-normal 5 0.2 ; did not rescale
    set pastWeatherIntensity fput (list ticks weatherIntensity) pastWeatherIntensity
    if length pastWeatherIntensity > memory
    [set pastWeatherIntensity sublist pastWeatherIntensity 0 min (list length pastWeatherIntensity memory)] ; keep only the first n elements defined by length of memory

    ifelse weatherIntensity >= extremeWeatherThreshold ; here to adjust the influence from others on risk perception
    [
      set extremeWeather? true
      ifelse weatherIntensity < disasterThreshold
      [ set disaster? false
        set expectedEWProb expectedEWProb + 0.01
        set expectedEWProb expectedEWProb * (1 + 0.05 + random-float 0.05 )
      ]
      [
        set expectedEWProb expectedEWProb * (1 + 0.25 + random-float 0.05)  ;for disaster
        set disaster? true
        if random-float 1 < declarationRate [set declared? true]
      ]
    ]
    [set extremeWeather? false]


  if not extremeWeather?
  [ set expectedEWProb expectedEWProb * (1 -  EWProbDecay )] ; extremeweatherevent did not happen, then expectedprob decrease


     if expectedEWProb >= 0.25 [set expectedEWProb  0.25] ; upper limit of expected prob
     if expectedEWProb <= 0.01 [set expectedEWProb 0.01] ; bottom limit of expected prob
  ]
end


to generate-orgOpportunities
  ask orgs [
    set filterEW (map [i -> (item 1 i >= extremeWeatherThreshold)] pastWeatherIntensity) ; find weahter intensity bigger than EW
    ifelse member? true filterEW
      [ifelse random-float 1 < increaseChance ;prob of opportunities after events
         [open-orgOpportunity]
         [set open-orgOpportunity? false]]
      [ifelse random-float 1 < randomChance  ; prob of opportunities far away from events
       [open-orgOpportunity]
      [set open-orgOpportunity? false]]
  ]
end

to open-orgOpportunity
  set orgOpts sentence ticks orgOpts
  set open-orgOpportunity? true
end


to Opportunities-byDeclaration
  ask orgs [
      ifelse declared? [
      set disasterOpts fput ticks disasterOpts
      set Opportunities remove-duplicates (sentence disasterOpts orgOpts)
    ]
    [set Opportunities orgOpts]
  ]
end


to update-riskPerception
  ask orgs [
    set impactPerTick ifelse-value (weatherIntensity - solEfficacy < 0 ) [0] [weatherIntensity - solEfficacy]

    set riskPerception (worstWeatherIntensity - solEfficacy ) * expectedEWProb
  ]

end



to determine-satisfaction
  ask orgs [;only orgs with no alternative solution are looking
    ifelse riskPerception > riskTolerance
    [set satisfied? false]
    [set satisfied? true]
  ]

end
to search-solution
  ask orgs with [not satisfied? and not adaptation-change?][
    if not solution-ready? [ ; coping
      let currentRiskPerception worstWeatherIntensity -  solEfficacy  ; note here it does not multiply the expectedEWProb
      let targetSolEfficacy (random-float impactReductionRate + 0.1) * worstWeatherIntensity
      set anticipatedMitigation anticipatedMitigation + targetSolEfficacy

      ifelse anticipatedMitigation  <= (0.5 * worstWeatherIntensity)   [
        ask current-solution [set efficacy targetSolEfficacy]
        set solEfficacy [efficacy] of current-solution
        set coping-change? true
      ]
      [
        set search-adaptation? true
        search-adaptation
      ]
    ]
  ]


end


to search-adaptation
  ifelse triggerNetwork?; whether orgs can assess all solutions
  [assess-thruNetwork]
  [assess-allSolutions]

  if targetSolution != nobody
  [set solution-ready? true
  set targetSolCost [cost] of targetSolution]

end

to check-capacity
  ask orgs with [not satisfied? and solution-ready? and not adaptation-change?][
    ifelse capacity < [cost] of targetSolution
    [
      set postponed? true
      set color red
    ]
    [
      implement-adaptation
      set adaptation-change? true
      set sufficientCap sufficientCap + 1
    ]
  ]

end


to check-Opportunity ; opportunities came by whether orgs need them for adaptation or not; but orgs with insufficient capacity will need to use for adaptation
  if openOpt? [
    ask orgs [
      ifelse not member? ticks Opportunities
      [
        set capacity originalCapacity
        set opportunity-open? false
      ]

      [
        set opportunity-open? true
        boost-capacity ; extra capacity is added whether orgs are planning on adaptation or not
        set totalOptOpen totalOptOpen + 1
        access-opportunity

        if member? ticks disasterOpts
        [set totalDisasterOpts totalDisasterOpts + 1 ]

        if member? ticks orgOpts
        [set totalOrgOpts totalOrgOpts + 1]
      ]

    ]
  ]
end


to access-opportunity
    ifelse (not adaptation-change?) [
       ifelse riskPerception <= riskTolerance
      [
        set lack-motivation? true
        set totalLackMotivation totalLackMotivation + 1
      ]
      [
        set lack-motivation? false
        ifelse postponed?
        [use-funding]
        [set totalNoSolution totalNoSolution + 1 ]
      ]
    ]
    [set totalAlreadyAdapted totalAlreadyAdapted + 1 ]
end


to use-funding

  ifelse member? ticks disasterOpts ; limitations about how to use fund from declaration
  [
    ifelse random-float 1 < disasterUti
    [use-for-adaptation]
    [set totalNonEligibleDisasterOpt totalNonEligibleDisasterOpt + 1]
  ]
  [use-for-adaptation]
end

to boost-capacity
  ifelse limitedFund?
  [
    if fundAvailable >= originalCapacity * capBoost
    [
      set capacity originalCapacity * (1 + capBoost)
      set totalFunding totalFunding + originalCapacity * capBoost
      set fundAvailable fundAvailable - originalCapacity * capBoost
    ]
  ]

 [
  ifelse randomBoost?
  [set capacity originalCapacity * (1  + random-float capBoost)]
  [set capacity originalCapacity * (1 + capBoost)]
  set totalFunding originalCapacity * capBoost  + totalFunding
 ]


end


to use-for-adaptation

   ifelse capacity >= [cost] of targetSolution
     [
      set insufBoost? false
      implement-adaptation

      set adaptation-change? true
      set totalNeededOpts totalNeededOpts  + 1
      set utilizedOpportunity? true

      set totalUtilizedOpts totalUtilizedOpts + 1 ; note orgs can adapt more than once

      if member? ticks disasterOpts
      [set totalUtilizedDisasterOpts totalUtilizedDisasterOpts + 1]


      if member? ticks orgOpts
      [set totalUtilizedOrgOpt totalUtilizedOrgOpt + 1]
    ]
    [
      set insufBoost? true
      set totalInsufBoost totalInsufBoost + 1
   ]
end

to assess-allSolutions
   let mySolEfficacy [efficacy] of current-solution
   let adaptationPool solutions with [adaptation? and efficacy > mySolEfficacy ]
   if any? adaptationPool
   [set targetSolution one-of adaptationPool ] ; randomly select one adaptation with better efficacy

end

to assess-thruNetwork
  let scanningPatches patches in-radius ( scanningRange)
  let currentSolEfficacy [efficacy] of current-solution

  let knownSolutions1 (solutions-on scanningPatches) with [adaptation?]
  let knownSolutions2 (turtle-set [current-solution] of org-sameReg-link-neighbors) with [adaptation?]
  let knownSolutions3  (turtle-set [current-solution] of org-diffReg-link-neighbors) with [adaptation?]

  ifelse officeRole?
  [set knownSolutions (turtle-set knownSolutions1 knownSolutions2 knownSolutions3 knownSolFromOffice)]
  [set knownSolutions (turtle-set knownSolutions1 knownSolutions2 knownSolutions3)]


  ifelse any? knownSolutions with [efficacy > currentSolEfficacy]
  [set targetSolution one-of knownSolutions
   set not-found? false]
  [
    set targetSolution nobody
    set not-found? true
    set color violet
  ]
end


to implement-adaptation
    remove-links-between self current-solution
    set current-solution targetSolution
    set solEfficacy [efficacy] of targetSolution
    create-org-sol-link-with targetSolution [set color grey]
    set targetSolution nobody
    set color yellow
    set solution-ready? false
    set postponed? false

end



to FTAcheck-adaptation
  ask FTAoffices[
    set projectInventory (turtle-set [current-solution] of FTAoffice-org-link-neighbors) with [adaptation?]
    ask FTAoffice-org-link-neighbors [
      set knownSolFromOffice [projectInventory] of myself
    ]
  ]
end



to remove-links-between [one-org one-sol]
    ask my-links with [other-end = one-sol][die]
end
to-report frequency [an-item a-list]
  report length (filter [i -> i = an-item] a-list) / length (a-list)
end

to-report minMeanMax [a-list]
  report  (list (min a-list) (mean a-list) (max a-list))
end

to avoid-edges
  while [[pcolor] of patch-here = grey ][
    set heading random 180
    fd 1 ]
end

to-report log-normal [mu sigma]
  let beta ln (1 + ((sigma / 2) / (mu ^ 2)))
  let x exp (random-normal (ln (mu) - (beta / 2)) sqrt beta)
  report x
end



to-report save-BSoutput1
  let filename BS-output
  file-open filename
  file-write meanRiskThreshold
  file-write numOpts
  file-write (count orgs with [adaptation-change?])
  file-close
  report "use csv done"
end



to write-variables ; output variable value to hard code the threshold values for EW, disasters etcs.
  file-open "DissertationABM hard coded weather parameters1.csv"
  foreach sort orgs [
    x ->
    ask x [
      file-write agencyid
      file-write extremeWeatherProb
      file-write disasterProb
      file-write extremeWeatherThreshold
      file-write disasterThreshold
      file-write worstWeatherIntensity
;      file-write declarationRate
    ]
  ]

  file-close

end
@#$#@#$#@
GRAPHICS-WINDOW
385
10
789
415
-1
-1
12.0
1
16
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
5
10
68
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
70
11
133
44
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
139
10
202
43
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
165
60
310
93
scanningRange
scanningRange
0
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
165
100
310
133
simulateMonths
simulateMonths
0
5000
4808.0
1
1
NIL
HORIZONTAL

PLOT
1115
10
1315
160
#Adopters
NIL
NIL
1.0
10.0
0.0
10.0
true
true
"" ""
PENS
"adapted" 1.0 0 -14439633 true "" "plot count orgs with [adaptation-change?]"
"coping" 1.0 0 -5298144 true "" "plot count orgs with [coping-change?]"

PLOT
1120
165
1320
315
minEWProb
NIL
NIL
0.0
10.0
0.0
0.3
true
false
"" ""
PENS
"default" 1.0 0 -14439633 true "" "plot sum [riskPerception] of orgs with-min [extremeweatherprob]"
"percept" 1.0 0 -8053223 true "" "plot sum [RiskTolerance] of orgs with-min [extremeweatherprob]"

PLOT
1120
320
1320
470
minOriginalEfficacy
NIL
NIL
0.0
10.0
0.0
0.3
true
false
"" ""
PENS
"riskPer" 1.0 0 -14439633 true "" "plot  [riskPerception] of org 0\n"
"Thresh" 1.0 0 -8053223 true "" "plot  [riskTolerance] of org 0"

SLIDER
160
140
310
173
impactReductionRate
impactReductionRate
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
5
60
155
93
meanRiskThreshold
meanRiskThreshold
0
2
0.52
0.01
1
NIL
HORIZONTAL

SLIDER
160
180
310
213
adaptationCost
adaptationCost
0
10
5.0
0.1
1
NIL
HORIZONTAL

MONITOR
405
425
462
470
adapted
count orgs with [adaptation-change?]
0
1
11

MONITOR
465
470
527
515
postpone
count orgs with [postponed?]
0
1
11

SLIDER
5
100
155
133
numOpts
numOpts
0
20
10.0
1
1
NIL
HORIZONTAL

SWITCH
865
10
1012
43
openOpt?
openOpt?
0
1
-1000

MONITOR
565
420
627
465
insuBoost
totalInsufBoost
0
1
11

SLIDER
5
140
155
173
capBoost
capBoost
0
10
4.0
0.1
1
NIL
HORIZONTAL

SWITCH
865
50
1017
83
triggerNetwork?
triggerNetwork?
0
1
-1000

SWITCH
865
90
1032
123
randomRiskThresh?
randomRiskThresh?
0
1
-1000

MONITOR
570
470
627
515
#used
totalUtilizedOpts
0
1
11

MONITOR
465
425
520
470
notNeed
sufficientCap
0
1
11

SLIDER
5
175
155
208
minNeighbor
minNeighbor
0
10
1.0
1
1
NIL
HORIZONTAL

PLOT
1325
160
1525
310
maxEWProb
Time
NIL
0.0
10.0
0.0
0.5
true
true
"" ""
PENS
"RiskPer" 1.0 0 -14439633 true "" "plot sum [riskPerception] of  orgs with-max [extremeWeatherProb]"
"riskThresh" 1.0 0 -5298144 true "" "plot sum [riskTolerance] of orgs with-max [extremeWeatherProb]"

SLIDER
160
250
310
283
EWProbDecay
EWProbDecay
0
0.05
0.03
0.001
1
NIL
HORIZONTAL

SLIDER
155
290
327
323
memory
memory
0
96
48.0
1
1
NIL
HORIZONTAL

SLIDER
155
330
327
363
disasterUti
disasterUti
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
160
215
310
248
simTicks
simTicks
0
3000
1000.0
10
1
NIL
HORIZONTAL

SWITCH
865
130
982
163
officeRole?
officeRole?
0
1
-1000

SWITCH
865
175
1037
208
randomOrgOpt?
randomOrgOpt?
1
1
-1000

SLIDER
155
365
327
398
increaseChance
increaseChance
0
1
2.0E-4
0.01
1
NIL
HORIZONTAL

SWITCH
865
210
997
243
randomBoost?
randomBoost?
0
1
-1000

MONITOR
400
470
457
515
fundAv
fundAvailable
1
1
11

SLIDER
155
400
327
433
startingFund
startingFund
0
100000
10659.0
1
1
NIL
HORIZONTAL

SWITCH
870
250
992
283
limitedFund?
limitedFund?
0
1
-1000

SLIDER
0
215
120
248
reduceWindows
reduceWindows
0
10
0.0
1
1
NIL
HORIZONTAL

SLIDER
0
255
130
288
randomChance
randomChance
0
0.001
2.0E-4
0.00001
1
NIL
HORIZONTAL

CHOOSER
870
340
1008
385
orgOptGen
orgOptGen
"allRandom" "diffused" "concentrated" "controlNum" "twoWindows" "oneWindow"
0

SWITCH
875
295
997
328
enoughCap?
enoughCap?
1
1
-1000

MONITOR
325
440
382
485
riskPer
mean [riskperception] of orgs
2
1
11

MONITOR
630
420
687
465
#opt
totalOptOpen
0
1
11

MONITOR
640
470
737
515
#lackMotivation
totalLackMotivation
0
1
11

MONITOR
760
430
820
475
#noSol
totalNoSolution
0
1
11

MONITOR
760
480
827
525
#adapted
totalAlreadyAdapted
17
1
11

MONITOR
830
430
905
475
#nonEligDis
totalNonEligibleDisasterOpt
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="baseline" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalLackMotivation</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="4"/>
      <value value="5"/>
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orgOptGen">
      <value value="&quot;allRandom&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="network" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalDisasterWindows</metric>
    <metric>totalwindowMissed</metric>
    <metric>totalWindowOpen</metric>
    <metric>totalNoSolution</metric>
    <metric>totalUtilizedWindows</metric>
    <metric>totalNeededWidows</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilizedDisasterWindows</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="badImpact">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numWindows">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxCopingReduction">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="open-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="change-aspiration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trigger-network?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-riskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-orgWindows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="othersInf?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="nonRandomWindow" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalDisasterWindows</metric>
    <metric>totalwindowMissed</metric>
    <metric>totalWindowOpen</metric>
    <metric>totalNoSolution</metric>
    <metric>totalUtilizedWindows</metric>
    <metric>totalNeededWidows</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilizedDisasterWindows</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="badImpact">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numWindows">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxCopingReduction">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="5321"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="increaseChance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reduceWindows">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="open-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="change-aspiration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trigger-network?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-riskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-orgWindows?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="decayAndWindow" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalLackMotivation</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="EWProbDecay" first="0" step="0.003" last="0.03"/>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orgOptGen">
      <value value="&quot;concentrated&quot;"/>
      <value value="&quot;diffused&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="increaseChance" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalLackMotivation</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="increaseChance" first="0" step="0.001" last="0.01"/>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomChance">
      <value value="2.0E-4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="zeroOrgWindow" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalDisasterWindows</metric>
    <metric>totalwindowMissed</metric>
    <metric>totalWindowOpen</metric>
    <metric>totalNoSolution</metric>
    <metric>totalUtilizedWindows</metric>
    <metric>totalNeededWidows</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilizedDisasterWindows</metric>
    <metric>totalOrgWindows</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="badImpact">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numWindows">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxCopingReduction">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="EWProbDecay" first="0" step="0.005" last="0.03"/>
    <enumeratedValueSet variable="openWindows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changeAspiration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgWindows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orgWindowGen">
      <value value="&quot;allRandom&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="highTolerance" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalDisasterWindows</metric>
    <metric>totalwindowMissed</metric>
    <metric>totalWindowOpen</metric>
    <metric>totalNoSolution</metric>
    <metric>totalUtilizedWindows</metric>
    <metric>totalNeededWidows</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilizedDisasterWindows</metric>
    <metric>totalOrgWindows</metric>
    <steppedValueSet variable="meanRiskThreshold" first="0.8" step="0.1" last="1.2"/>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="badImpact">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numWindows">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxCopingReduction">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b1">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="EWProbDecay" first="0.012" step="0.003" last="0.03"/>
    <enumeratedValueSet variable="openWindows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changeAspiration?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgWindows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orgWindowGen">
      <value value="&quot;allRandom&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="decayMemory" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="increaseChance">
      <value value="0.01"/>
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="1"/>
      <value value="2"/>
      <value value="6"/>
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="EWProbDecay" first="0" step="0.006" last="0.06"/>
    <enumeratedValueSet variable="randomChance">
      <value value="2.0E-4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="numOpts" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <steppedValueSet variable="numOpts" first="0" step="2" last="20"/>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orgOptGen">
      <value value="&quot;allRandom&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="randomChance" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalLackMotivation</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <steppedValueSet variable="randomChance" first="0" step="1.0E-4" last="0.001"/>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="increaseChanceBase" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalLackMotivation</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="increaseChance">
      <value value="2.0E-4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomChance">
      <value value="2.0E-4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="increaseChance2" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalLackMotivation</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="increaseChance" first="0" step="0.01" last="0.1"/>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomChance">
      <value value="2.0E-4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="zeroTolerance" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalLackMotivation</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orgOptGen">
      <value value="&quot;allRandom&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="zeroDecay" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalLackMotivation</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orgOptGen">
      <value value="&quot;allRandom&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="enoughCap" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalFunding</metric>
    <metric>fundAvailable</metric>
    <metric>totalOptOpen</metric>
    <metric>totalLackMotivation</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalNoSolution</metric>
    <metric>totalAlreadyAdapted</metric>
    <metric>totalNonEligibleDisasterOpt</metric>
    <metric>totalDisasterOpts</metric>
    <metric>totalUtilizedDisasterOpts</metric>
    <metric>totalUtilizedOpts</metric>
    <metric>totalNeededOpts</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilized</metric>
    <metric>totalOrgOpts</metric>
    <metric>totalUtilizedOrgOpt</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numOpts">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="5.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="memory">
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disasterUti">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="startingFund">
      <value value="10652"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="openOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="triggerNetwork?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomRiskThresh?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomOrgOpt?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="randomBoost?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limitedFund?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enoughCap?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orgOptGen">
      <value value="&quot;allRandom&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
