extensions [csv]

breed [orgs org]
breed [solutions solution]
breed [FTAoffices FTAoffice]

undirected-link-breed [org-sol-links org-sol-link]
undirected-link-breed [org-sameReg-links org-sameReg-link]
undirected-link-breed [org-diffReg-links org-diffReg-link]
undirected-link-breed [FTAoffice-org-links FTAoffice-org-link]

globals [strategies regionDiv tempXcor tempYcor tempXcorList tempYcorList totalWindowMissed
         totalWindowOpen totalInsufBoost totalNoSolution totalDisasterWindows
          totalUtilizedWindows totalNeededWidows sufficientCap totalUtilizedDisasterWindows logFile
         BS-output]

patches-own [patchRegion]
solutions-own [efficacy cost adaptation? ]; solutions include both non-adaptation and adaptation measures
FTAoffices-own [projectInventory]



orgs-own [
  agencyID
  region
  leader?
  diffRegionNeighbors
  partner
  insufBoost?
  target-patches
  extremeWeatherProb
  disasterFreq
  disasterProb
  extremeWeatherThreshold
  disasterThreshold
  extremeWeather? ; boolean whether the weather is extreme
  severityMax
  weatherSeverityExp ; document an org's weatherSeverity over 200 years to find the norm and extremes
  diaster?
  weatherSeverity
  solEfficacy
  originalEfficacy
  maxCopingEfficacy
  FTARegion
  passRate
  declarationRate
  declared?
  postponed?
  knownSolutions
  search-adaptation?
  missedWindows
  utilizedWindow?
  insufBoost?
  insufBoostTicks
  knownSolFromOffice
  regional-leader?
  regionalNeighbors
  resilience  ; higher resilience means lower impact on agencies in extreme weather
  capacity ;used to decide if orgs have sufficient capacity to implement solutions
  originalCapacity
  extremeWeatherFreq
  impactPerTick
  impactExp
  copingLimit
;  freqImpactExp ; cumulative
  weatherSeverityImpactExp
  weatherImpactExp
  expectedBadWeatherSeverity
  innovation-ready?
  copingChangeTicks
  extremeWeatherSeverity
  crossRiskThresholdTicks
  expectedEWProb
  expectedImpact
  riskPerceptionThreshold
  windows
  window-open?
  window-missed?
  used-disasterWindow?
  orgWindows
  disasterWindows
  current-solution
  targetSolution
  not-found?
  coping-change?
  adaptation-change?
  adaptTicks
  adaptNum
  disaster? ; whether happened disater or not
  satisfied?
  solution-ready?
  no-solAttached?
  currentAspiration
  previousAspiration
  currentAspiration
  currentImpact
  previousImpact
  referenceGroup
  normalizedImpact
  originalExpectedImpact
  originalRiskPerceptionThreshold
]


to setup
  ca
  if random-seed_.
  [random-seed 100]

;  set logFile (word "log" (random 100000) ".txt")


  set strategies ["routine" "adaptation"]
  set-default-shape solutions "box"
  set totalWindowMissed 0
  set totalInsufBoost 0
  set totalWindowOpen 0
  set totalNoSolution 0
  set totalDisasterWindows 0
  set totalUtilizedWindows 0
  set totalNeededWidows 0
  set totalUtilizedDisasterWindows 0
  set sufficientCap 0
  import-orgs
  setup-orgs
  setup-windows
  distribute-orgs
  setup-regionalRiskThreshold
  setup-FTARegion
  setup-solutions
;  record-weather-norm
  setup-network

    reset-ticks
end



to import-orgs
  file-open "Transit agencies ABM_noHeader.csv"
  while [not file-at-end?]
  [
    let row csv:from-row file-read-line
    create-orgs  1 [
      set agencyID item 0 row
      set capacity item 2 row
      set capacity capacity - (- 1.57) ; -1.57 is the min capacity
      set originalCapacity capacity
      set region item 3 row
      set disasterProb item 6 row + random-float 0.02
      set passRate (item 7 row + random-float 0.02 ) * (1 / 24)
      set declarationRate item 14 row
      set FTARegion item 10 row
      set extremeWeatherProb item 12 row + random-float 0.05
      set extremeWeatherThreshold item 15 row
      set disasterThreshold item 16 row
      set expectedBadWeatherSeverity item 17 row
;
      set expectedEWprob extremeWeatherProb
      set expectedImpact (expectedBadWeatherSeverity -  solEfficacy) * expectedEWprob
      if expectedImpact < 0 [set expectedImpact 0.1]
      set maxcopingefficacy 0
      set maxCopingEfficacy  maxCopingReduction * expectedBadWeatherSeverity  ; the maximum risk reduction coping measures can acheive,do not multiple ewprob
      If extremeWeatherProb < disasterProb [
         print "extremeWeatherProb is smaller than disasterProb"
         set extremeWeatherProb disasterProb + 0.005
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
    set extremeWeatherFreq 0

;    set resilience 2 + random-float 1 ;resilience is the ax magnitude of disturbances that can be tolerated before incurring impacts, can be negative
;    set initialResilience resilience
    set not-found? false
    set copingLimit 0
    set windows []
    set orgWindows []
    set disasterWindows []
    set insufBoostTicks []
    set insufBoost? false
    set crossRiskThresholdTicks []
    set missedWindows []
    set window-open? false
    set window-missed? false
    set adaptTicks []
    set knownSolFromOffice []
    set satisfied? true
    set utilizedWindow? false
    set regional-leader? false
    set search-adaptation? false
    set adaptNum 0
    set used-disasterWindow? false
    set leader? false
    set declared? false
    set coping-change? false
    set adaptation-change? false
    set extremeWeather? false
    set disaster? false
    set postponed? false
    set solution-ready? false
    set innovation-ready? false
    set targetSolution nobody
    set no-solAttached? true
    set copingChangeTicks []


  ]

  ask FTAoffices [
    set projectInventory []
  ]
end


to setup-windows
  ask orgs [
    repeat random numWindows [
      let n random 1000 ; 1000 ticks
      set orgWindows sentence n orgWindows
      set windows remove-duplicates orgwindows
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
  ifelse random-riskThresh_.
  [ask orgs [set riskPerceptionThreshold random-normal meanRiskThreshold 0.1]]
  [riskThreshold-byRegion]


  ask orgs [
    set currentAspiration riskPerceptionThreshold
    set originalRiskPerceptionThreshold riskPerceptionThreshold
  ]
end


to riskThreshold-byRegion

  let regionalMean1 sentence (meanRiskThreshold + 0.10) (meanRiskThreshold + 0.2)  ; threshold for northeast and midwest
  let regionalMean2 sentence (meanRiskThreshold + 0) (meanRiskThreshold + 0.3) ; threshold for south and west, south has the lowest and west has highest
  let regionalMean sentence regionalMean1 regionalMean2

  (foreach ["northeast" "midwest" "south" "west"] regionalMean
    [
      [x meanThreshold] ->
      ask orgs with [region = x] [
        set riskPerceptionThreshold random-normal meanThreshold 0.1
        if riskPerceptionThreshold < 0 [set riskPerceptionThreshold 0.1]
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
         set size efficacy
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
    set originalEfficacy solEfficacy
  ]

  ask n-of 30 patches with [not any? turtles-here and pcolor != grey][
    sprout-solutions 1 [
      set color green ; adaptation are set blue
      set efficacy 1.5 + random-float 2 ;weatherseverity ranges from approximately  3 to 6
      set cost random-float adaptationCost + 2
      set size efficacy / 2.5
      set adaptation? true
    ]
  ]

end

to record-weather-norm ; only activated when not using the hard coded weather parameters on the following attributes
  ask orgs [
      set weatherSeverityImpactExp record-severity-experience extremeWeatherProb  solEfficacy; determine weather severity norm based on 200 years timeline, functions are put at the end
      set weatherSeverityExp item 0  weatherSeverityImpactExp ; record of weather severity
      set weatherImpactExp item 1 weatherSeverityImpactExp ; record of impact on orgs based on weather severity, org resiience and solution efficacy
      set extremeWeatherThreshold  item (ceiling simulateMonths * extremeWeatherProb) weatherSeverityExp
      set disasterThreshold  item (ceiling simulateMonths * disasterProb) weatherSeverityExp
      set expectedEWprob extremeWeatherProb
      set expectedBadWeatherSeverity item (ceiling simulateMonths * badImpact) weatherImpactExp
      set expectedImpact (expectedBadWeatherSeverity -  solEfficacy) * expectedEWprob
      ;if expectedImpact < 0  [set expectedImpact 0.1]
      if expectedImpact < originalExpectedImpact [set expectedImpact 0.1]
      set maxCopingEfficacy  maxCopingReduction * expectedBadWeatherSeverity ; the maximum risk reduction coping measures can acheive
  ]
end

to-report record-severity-experience [ewProb org-solEfficacy ]
  let time 0
  let severity []
  let impactRecord[]
  let severityImpactExp []
  while [time < simulateMonths][  ; base weather pattern on 200 year experience
    let severityPerTick log-normal 5 ewProb ;
    set severity sentence severity severityPerTick
    let myImpact SeverityPerTick -  org-solEfficacy
    if myImpact < 0 [ set myImpact 0]
    set impactRecord sentence myImpact impactRecord
    set time time + 1
  ]
  set severity sort-by > severity
  set impactRecord sort-by > impactRecord
  set severityImpactExp list severity ImpactRecord
  report severityImpactExp
end


to setup-network

  ask orgs [
    set regionalNeighbors other orgs with [region = [region] of myself]
    set diffRegionNeighbors other orgs with [region != [region] of myself]

    repeat minNeighbor [ ; all orgs have at least one regional partners
      let candidate1 lottery-winner  ; candidate is a list of orgs from the same region
      if item 0 candidate1 != nobody [
        create-org-sameReg-link-with item 0 candidate1 [hide-link]
        ]
      ]

    repeat minNeighbor [  ;candidate is a list of orgs from different regions
      let candidate2 lottery-winner
      if item 1 candidate2 != nobody [
         create-org-diffReg-link-with item 1 candidate2 [hide-link]
      ]
    ]
  ]

end

to-report lottery-winner
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
  set logFile (word "start " ticks)
  check-weather  ;unless otherwise indicated, the go procedures apply to orgs
  expect-impact
  windows-byDeclaration
  determine-satisfaction
  search-solution
  check-implementation
  check-window
  FTAcheck-adaptation ; this is the FTAoffice procedure;
  if changeAspiration = 1[
    update-aspiration
  ]


  ask orgs [
    set extremeWeather? false
    set disaster? false
    set declared? false
    set capacity originalCapacity
    set extremeWeatherProb extremeWeatherProb * (1 + random-float 0.0001); probability increases over time
;    set disasterProb disasterProb * (1 + random-float 0.0001)
    if expectedBadWeatherSeverity < expectedImpact [
      print "warning: expected weather severity smaller than expected impact"
    ]
    if expectedImpact < 0 [
      print "warining: expectedImpact smaller than 0"
    ]
  ]

  write-logFile
  tick


;  if ticks mod simTicks = 0 [
;  ask orgs [
;    set orgWindows update-windows
;    set windows orgWindows
;  ]
; ]

 ;if ticks >= simTicks [stop]
end

to write-logFile
  file-open "test logfile.txt"
  file-write word "end ticks " ticks
  file-close
end

to update-aspiration  ; do not use org's performance in the function
;  let minImpactPerTick min [impactPerTick] of orgs
;  let maxImpactPerTick max [impactPerTick] of orgs
;  ask orgs[
;    set normalizedImpact (impactPertick - minImpactPerTick) / maxImpactPerTick
;    set previousImpact normalizedImpact
;    set previousAspiration currentAspiration
;  ]
  ask orgs [
    set previousAspiration currentAspiration
  ]
  ask orgs [
    if impactPerTick > 0 [
     set referenceGroup orgs with [(extremeWeather?) and (region = [region] of myself) and (impactPerTick < [impactPerTick] of myself)]
     if any? referenceGroup [
     let referenceAspiration mean [previousAspiration] of referenceGroup
     set currentAspiration (b1 * previousAspiration + (1 - b1) * referenceAspiration)
;     set currentAspiration (b1 * normalizedImpact + b2 * previousAspiration + b3 * referenceAspiration)
     set riskPerceptionThreshold currentAspiration
      ]
    ]
 ]
end



to-report update-windows
  let udpatedWindows [] ;spelling
  repeat random numWindows [
    let updatedWindow random (simTicks + ticks)
    set udpatedWindows remove-duplicates (sentence updatedWindow windows)
  ]
  report udpatedWindows
end


to check-weather
  ask orgs [
    set weatherSeverity log-normal 5 extremeWeatherProb ; did not rescale
    ifelse weatherSeverity >= extremeWeatherThreshold ; here to adjust the influence from others on risk perception
    [
      set extremeWeather? true
      ifelse weatherSeverity < disasterThreshold
      [ set disaster? false
        set expectedEWProb expectedEWProb * (1 + 0.05 + random-float 0.05 )] ;for EW
      [
        set expectedEWProb expectedEWProb * (1 + 0.25 + random-float 0.05)  ;for disaster
        set disaster? true
        set disasterFreq disasterFreq + 1
        if random-float 1 < passRate [set declared? true]
      ]
    ]
    [set extremeWeather? false]


  if not extremeWeather?
  [
    ifelse othersInf?
    [
      if (any? org-sameReg-link-neighbors with [disaster?]) and (random-float 1 < 0.1)
      [set expectedEWProb expectedEWProb * (1 + random-float 0.005)]
    ]
    [set expectedEWProb expectedEWProb * (1 - (EWProbDecay + random-float 0.001))] ; extremeweatherevent did not happen, then expectedprob decrease
  ]

     if expectedEWProb >= 0.25 [set expectedEWProb  0.25] ; upper limit of expected prob
     if expectedEWProb <= 0.01 [set expectedEWProb 0.01] ; bottom limit of expected prob
  ]
end


to windows-byDeclaration
  ask orgs [
      if declared? [
      set disasterWindows fput ticks disasterWindows
      set windows remove-duplicates (sentence disasterWindows orgwindows)
    ]
  ]
end


to expect-impact
  ask orgs [
    set impactPerTick ifelse-value (weatherSeverity - solEfficacy < 0 ) [0] [weatherSeverity - solEfficacy]

    set originalExpectedImpact (expectedBadWeatherSeverity - solEfficacy ) * expectedEWProb
    set expectedImpact originalExpectedImpact

    if resilience-decay_.[
      if impactPerTick > 0 [ ; if impacted by weather, resilience goes down
      set resilience resilience * (0.9998 + random-float 0.00009)
      if resilience < 1 [set resilience 1]
      ]
    ]
  ]
end



to determine-satisfaction
  ask orgs [;only orgs with no alternative solution are looking
    ifelse expectedImpact > riskPerceptionThreshold
    [set satisfied? false]
    [set satisfied? true]
  ]

end
to search-solution
  ask orgs with [not satisfied? and not adaptation-change?][
    if not solution-ready? [ ; coping
      let currentExpectedImpact expectedBadWeatherSeverity -  solEfficacy  ; note here it does not multiply the expectedEWProb
      let targetSolEfficacy calculate-target-efficacy solEfficacy impactPerTick expectedBadWeatherSeverity  (random-float impactReductionRate + 0.10)
      ifelse (targetSolEfficacy < maxCopingEfficacy) and (copingLimit < 1) ; limit coping to once only to speed up
    [
         ask current-solution [set efficacy targetSolEfficacy]
         set solEfficacy [efficacy] of current-solution
         set copingChangeTicks fput ticks copingChangeTicks
         set coping-change? true
         set copingLimit 1 + copingLimit
   ][
         set search-adaptation? true
         search-adaptation
      ]
    ]
  ]
end

to-report  calculate-target-efficacy [org-solEfficacy org-weatherSeverity  org-impact  org-reductionRate]
  let org-target-efficacy org-impact * org-reductionRate + org-solEfficacy
  report org-target-efficacy
end


to search-adaptation
  ifelse trigger-network_.
  [assess-thruNetwork]
  [assess-allSolutions]

  if targetSolution != nobody
  [set solution-ready? true]

end

to check-implementation
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


to check-window
  if open-windows_.[
    ask orgs with [not adaptation-change?]
    [
      ifelse not member? ticks windows
      [
        set window-open? false
        set window-missed? false
      ]

      [
       set window-open? true
       set totalWindowOpen totalWindowOpen + 1

       if member? ticks disasterWindows
       [set totalDisasterWindows totalDisasterWindows + 1]

      ifelse expectedImpact <= riskPerceptionThreshold
      [
        set window-missed? true
        set TotalWindowMissed TotalWindowMissed + 1
      ]
      [
        ifelse postponed?
        [ boost-capacity]
        [set totalNoSolution totalNoSolution + 1 ]
      ]
    ]
   ]
 ]
end

to boost-capacity
   set capacity capacity * (1  + random-float capBoost)
   ifelse declared? ; limitations about how to use fund from declaration
  [if random-float 1 < 0.2 [adaptation-discretion]]
  [adaptation-discretion]
end

to adaptation-discretion

   ifelse capacity >= [cost] of targetSolution
     [
      set insufBoost? false
      implement-adaptation
      if not adaptation-change?
      [
        set adaptation-change? true
        set totalNeededWidows totalNeededWidows  + 1
      ]
      set utilizedWindow? true
      set totalUtilizedWindows totalUtilizedWindows + 1 ; note orgs can adapt more than once
      ifelse member? ticks disasterWindows [
        set totalUtilizedDisasterWindows totalUtilizedDisasterWindows + 1
        set used-disasterWindow? true
      ][
        set used-disasterWindow? false
      ]
    ]

    [
      set insufBoostTicks fput ticks insufBoostTicks
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

  if officeRole = 1
  [set knownSolutions (turtle-set knownSolutions1 knownSolutions2 knownSolutions3 knownSolFromOffice)]

  if officeRole = 0
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
    set adaptTicks fput ticks adaptTicks
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

to-report save-BSoutput  ; save BS output from command line
  let filename BS-output
  file-open filename

  ;headers
  let text-out (sentence ",numWindows,meanRiskThreshold, adaptedNum")
  file-type text-out
  file-print ""

  ;print dat
  set text-out (sentence ","meanRiskThreshold","numWindows","count orgs with [adaptation-change?]",")
  file-type text-out
  file-print ""


  file-close
  report "table output done"
end

to-report save-BSoutput1
  let filename BS-output
  file-open filename
  file-write meanRiskThreshold
  file-write numWindows
  file-write (count orgs with [adaptation-change?])
  file-close
  report "use csv done"
end



to write-variables
  file-open "DissertationABM hard coded weather parameters.txt"
  foreach sort orgs [
    x ->
    ask x [
      file-write agencyid
      file-write disasterProb
      file-write passRate
      file-write extremeWeatherThreshold
      file-write disasterThreshold
      file-write expectedBadWeatherSeverity
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

PLOT
1120
10
1320
160
riskThreshold
Time
riskPerception
1.0
100.0
0.6
0.8
true
true
"" ""
PENS
"originalTh" 1.0 0 -15040220 true "" "plot mean [originalRiskPerceptionThreshold] of orgs"
"currentTh" 1.0 0 -5298144 true "" "plot mean [riskPerceptionThreshold] of orgs"

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
3600
1169.0
1
1
NIL
HORIZONTAL

PLOT
1328
10
1528
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

MONITOR
100
450
167
495
coping
count orgs with [length copingChangeTicks > 0]
0
1
11

MONITOR
0
465
77
510
crossThresh
count orgs with [expectedImpact > riskPerceptionThreshold]
0
1
11

PLOT
1325
315
1525
465
maxOriginalEfficacy
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
"NE" 1.0 0 -15040220 true "" "plot  [expectedImpact] of one-of orgs with-max [originalEfficacy]"
"threshold" 1.0 0 -8053223 true "" "plot  [originalRiskperceptionthreshold] of one-of orgs with-max [originalEfficacy]"
"asp" 1.0 0 -16777216 true "" "plot sum [currentAspiration] of orgs with-max [originalEfficacy]"

SWITCH
955
15
1092
48
random-seed_.
random-seed_.
1
1
-1000

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
"default" 1.0 0 -14439633 true "" "plot sum [expectedImpact] of orgs with-min [extremeweatherprob]"
"percept" 1.0 0 -8053223 true "" "plot sum [originalRiskPerceptionThreshold] of orgs with-min [extremeweatherprob]"
"asp" 1.0 0 -14737633 true "" "plot sum [currentAspiration] of orgs with-min [extremeweatherprob]"

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
"riskPer" 1.0 0 -14439633 true "" "plot sum [expectedImpact] of orgs with-min [originalEfficacy]"
"Thresh" 1.0 0 -8053223 true "" "plot sum [originalRiskperceptionthreshold] of orgs with-min [originalEfficacy]"
"pen-2" 1.0 0 -16777216 true "" "plot sum [currentAspiration] of orgs  with-min [originalEfficacy]"

SLIDER
5
140
155
173
badImpact
badImpact
0
0.50
0.08
0.01
1
NIL
HORIZONTAL

SLIDER
160
140
310
173
impactReductionRate
impactReductionRate
0
0.4
0.25
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
1
0.8
0.01
1
NIL
HORIZONTAL

SLIDER
5
180
155
213
maxCopingReduction
maxCopingReduction
0
0.5
0.4
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
7
6.5
0.1
1
NIL
HORIZONTAL

MONITOR
365
445
422
490
adapted
count orgs with [adaptation-change?]
0
1
11

MONITOR
295
440
357
485
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
numWindows
numWindows
0
20
10.0
1
1
NIL
HORIZONTAL

SWITCH
955
95
1102
128
open-windows_.
open-windows_.
1
1
-1000

MONITOR
535
445
597
490
insuBoost
totalInsufBoost
0
1
11

SLIDER
5
215
155
248
capBoost
capBoost
0
10
2.0
0.1
1
NIL
HORIZONTAL

SWITCH
955
60
1107
93
resilience-decay_.
resilience-decay_.
1
1
-1000

SWITCH
955
135
1107
168
trigger-network_.
trigger-network_.
0
1
-1000

MONITOR
425
445
487
490
notFound
count orgs with [not-found?]
0
1
11

SWITCH
955
175
1122
208
random-riskThresh_.
random-riskThresh_.
1
1
-1000

SWITCH
955
215
1065
248
othersInf?
othersInf?
1
1
-1000

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

MONITOR
210
455
267
500
#missed
TotalWindowMissed
0
1
11

MONITOR
605
445
662
490
#open
totalWindowOpen
0
1
11

MONITOR
535
495
592
540
#noSol
totalNoSolution
0
1
11

MONITOR
595
495
652
540
ready
count orgs with [solution-ready?]
0
1
11

MONITOR
665
445
727
490
#declare
totalDisasterWindows
0
1
11

MONITOR
655
495
712
540
#used
totalUtilizedWindows
0
1
11

MONITOR
720
495
782
540
#Needed
totalNeededWidows
0
1
11

MONITOR
730
445
785
490
notNeed
sufficientCap
0
1
11

MONITOR
785
495
867
540
usedDisaster
totalUtilizedDisasterWindows
0
1
11

MONITOR
790
445
852
490
#disWind
count orgs with [used-disasterWindow?]
0
1
11

SLIDER
5
250
155
283
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
"RiskPer" 1.0 0 -14439633 true "" "plot sum [expectedImpact] of  orgs with-max [extremeWeatherProb]"
"Threshold" 1.0 0 -5298144 true "" "plot sum  [originalRiskperceptionthreshold] of orgs with-max [extremeWeatherProb]"
"asp" 1.0 0 -16777216 true "" "plot sum [currentAspiration] of orgs with-max [extremeWeatherProb]"

MONITOR
995
445
1067
490
diasterOrg
count orgs with [disaster?]
0
1
11

MONITOR
870
495
952
540
expectedEW
[expectedEWprob] of org 1
3
1
11

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
5
290
97
323
b1
b1
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
5
325
97
358
b2
b2
0
1
0.57
0.01
1
NIL
HORIZONTAL

SLIDER
5
360
97
393
b3
b3
0
1
0.25
0.01
1
NIL
HORIZONTAL

MONITOR
385
490
447
535
meanAsp
mean [currentAspiration] of orgs
3
1
11

CHOOSER
955
340
1102
385
reference
reference
"sameRegion" "betterPerformer"
1

MONITOR
300
490
362
535
normImp
mean [normalizedImpact] of orgs
3
1
11

SLIDER
160
285
310
318
referTime
referTime
0
36
12.0
1
1
NIL
HORIZONTAL

CHOOSER
960
250
1098
295
officeRole
officeRole
1 0
0

CHOOSER
960
295
1098
340
changeAspiration
changeAspiration
1 0
1

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
  <experiment name="adaptation" repetitions="10" runMetricsEveryStep="false">
    <setup>setup
set BS-output "adaptationTest.csv"</setup>
    <go>go</go>
    <exitCondition>ticks &gt; 1</exitCondition>
    <metric>count orgs with [coping-change?]</metric>
    <metric>count orgs with [adaptation-change?]</metric>
    <metric>totalInsufBoost</metric>
    <metric>totalDisasterWindows</metric>
    <metric>totalwindowMissed</metric>
    <metric>totalWindowOpen</metric>
    <metric>totalNoSolution</metric>
    <metric>totalUtilizedWindows</metric>
    <metric>totalNeededWidows</metric>
    <metric>sufficientCap</metric>
    <metric>totalUtilizedDisasterWindows</metric>
    <steppedValueSet variable="meanRiskThreshold" first="0.4" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="badImpact">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numWindows">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxCopingReduction">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="6.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="open-windows_.">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changeAspiration">
      <value value="0"/>
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="EWProbDecay" first="0" step="0.01" last="0.03"/>
  </experiment>
  <experiment name="test" repetitions="1" runMetricsEveryStep="false">
    <setup>reset-ticks
setup
set BS-output "test.csv"</setup>
    <go>go</go>
    <exitCondition>ticks = 100</exitCondition>
    <metric>save-BSoutput</metric>
    <enumeratedValueSet variable="meanRiskThreshold">
      <value value="0.4"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scanningRange">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="badImpact">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numWindows">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impactReductionRate">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxCopingReduction">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adaptationCost">
      <value value="6.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capBoost">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simTicks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minNeighbor">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="officeRole">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="open-windows_.">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changeAspiration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EWProbDecay">
      <value value="0.02"/>
      <value value="0.03"/>
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
