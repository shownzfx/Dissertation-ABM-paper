extensions [csv]

breed [orgs org]
breed [solutions solution]
breed [opportunities opportunity]
breed [FTAoffices FTAoffice]

undirected-link-breed [org-sol-links org-sol-link]
undirected-link-breed [org-sameReg-links org-sameReg-link]
undirected-link-breed [org-diffReg-links org-diffReg-link]
undirected-link-breed [FTAoffice-org-links FTAoffice-org-link]

globals [strategies regionDiv tempXcor tempYcor tempXcorList tempYcorList  ]


patches-own [patchRegion]
solutions-own [efficacy cost to-opportunity adaptation?]; solutions include both non-adaptation and adaptation measures
FTAoffices-own []


opportunities-own [chance]


orgs-own [
  region
  leader?
  diffRegionNeighbors
  partner
  target-patches
  extremeWeatherProb
  disasterFreq
  disasterProb
  extremeWeatherThreshold diasterThreshold
  extremeWeather? ; boolean whether the weather is extreme
  severityMax
  weatherSeverityExp ; document an org's weatherSeverity over 200 years to find the norm and extremes
  diaster?
  weatherSeverity
  solEfficacy
  originalEfficacy
  maxCopingEfficacy
  copingChangeNum
  FTARegion
  passRate
  declarationRate
  declared?
  postponed?
  search-adaptation?
  missedWindows
  insufBoost
  regional-leader?
  regionalNeighbors
  resilience  ; higher resilience means lower impact on agencies in extreme weather
  capacity ;used to decide if orgs have sufficient capacity to implement solutions
  originalCapacity
  extremeWeatherFreq
  impactPerTick
  impactExp
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
  changeEvents
;  neighborsWithDisaster otherInfExp  riskPerceptionfromExp riskPerceptionFromOthers
;  riskPerceptionfromAll  ; risk perceptiom from agency's own exp and from watching their neighbors
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
]

to setup
  ca
  if random-seed?
  [random-seed 100]

  set strategies ["routine" "adaptation"]
  set-default-shape solutions "box"
  import-orgs
  setup-orgs
  setup-windows
  distribute-orgs
  setup-regionalRiskThreshold
  setup-FTARegion
  setup-solutions
  record-weather-norm
;  setup-leaders
  setup-sameRegNetwork
;  setup-diffRegNetwork


;  repeat orgMemory [
;    check-weather
;    update-weatherExp
;  ]
    reset-ticks
end

to import-orgs
  file-open "Transit agencies ABM_noHeader.csv"
  while [not file-at-end?]
  [
    let row csv:from-row file-read-line
    create-orgs  1 [
      set capacity item 2 row
      set capacity capacity - (- 1.57) ; -1.57 is the min capacity
      set originalCapacity capacity
      set region item 3 row
      set disasterProb item 6 row
      set passRate item 7 row
      set declarationRate item 14 row
      set FTARegion item 10 row
      set extremeWeatherProb item 12 row + random-float 0.02
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
    set extremeWeatherFreq 0
    set copingChangeNum 0
;    set resilience 2 + random-float 1 ;resilience is the ax magnitude of disturbances that can be tolerated before incurring impacts, can be negative
;    set initialResilience resilience
;    set searchCost 0
    set solution-ready? false
    set not-found? false
    set changeEvents []
    set insufBoost []
    set crossRiskThresholdTicks []
    set missedWindows []
    set adaptTicks []
    set satisfied? true
    set regional-leader? false
    set search-adaptation? false
    set adaptNum 0
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
    set copingChangeTicks []
  ]
end


to setup-windows
  ask orgs [
    repeat random numWindows [
      let changeEvent random 1000
      set changeEvents fput changeEvent changeEvents
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
  let regionalMean1 sentence (meanRiskThreshold + 0.10) (meanRiskThreshold + 0.2)  ; threshold for northeast and midwest
  let regionalMean2 sentence (meanRiskThreshold + 0) (meanRiskThreshold + 0.3) ; threshold for south and west, south has the lowest and west has highest
  let regionalMean sentence regionalMean1 regionalMean2


  (foreach ["northeast" "midwest" "south" "west"] regionalMean
    [
      [x meanThreshold] ->
      ask turtles with [region = x] [
        set riskPerceptionThreshold random-normal meanThreshold 0.1
        if riskPerceptionThreshold < 0 [set riskPerceptionThreshold 0.01]
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
         set to-opportunity nobody
         set adaptation? false  ; the default solutions are routine ones, not adaptation-based
         set efficacy 0.05 + random-float (1 - 0.05); for coping solutions
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
      set color cyan ; adaptation are set blue
      set cost random-float adaptionCost + 2
      set efficacy 1.5 + random-float 2 ;weatherseverity ranges from approximately  4 to 6
      set size efficacy / 3.2
      set adaptation? true
    ]
  ]

end




to record-weather-norm
  ask orgs [
      set weatherSeverityImpactExp record-severity-experience extremeWeatherProb  solEfficacy; determine weather severity norm based on 200 years timeline, functions are put at the end
      set weatherSeverityExp item 0  weatherSeverityImpactExp ; record of weather severity
      set weatherImpactExp item 1 weatherSeverityImpactExp ; record of impact on orgs based on weather severity, org resiience and solution efficacy
      set extremeWeatherThreshold  item (ceiling simulateMonths * extremeWeatherProb) weatherSeverityExp
      set diasterThreshold  item (ceiling simulateMonths * disasterProb) weatherSeverityExp
      set expectedEWprob extremeWeatherProb
      set expectedBadWeatherSeverity item (ceiling simulateMonths * badImpact) weatherImpactExp
      set expectedImpact (expectedBadWeatherSeverity -  solEfficacy) * extremeWeatherProb
      if expectedImpact < 0 [set expectedImpact 0.1]
      let expectedDamage expectedBadWeatherSeverity  ; note here it does not multiple the EWprob
      set maxCopingEfficacy expectedBadWeatherSeverity - (1 - maxCopingReduction) * expectedDamage ; the maximum risk reduction coping measures can acheive
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


to setup-sameRegNetwork

  ask orgs [
    set regionalNeighbors other orgs with [region = [region] of myself]
    set diffRegionNeighbors other orgs with [region != [region] of myself]

    repeat 2 [ ; all orgs have at least two regional partners
      let candidate1 lottery-winner  ; candidate is a list of regionPartner diffRegPartner
      if item 0 candidate1 != nobody [
        create-org-sameReg-link-with item 0 candidate1 [hide-link]
        ]
      ]

      let candidate2 lottery-winner
      if item 1 candidate2 != nobody [
         create-org-diffReg-link-with item 1 candidate2 [hide-link]
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
  check-weather
  expect-impact
  determine-windows
  search-solution
  check-window
  ;wait-for-scheduledPlan
  ask orgs [
    set extremeWeather? false
    set disaster? false
    set declared? false
    set satisfied? true
    set capacity originalCapacity
;    if color = yellow [set color white]
    if expectedBadWeatherSeverity < expectedImpact [
      print "warning: expected weather severity smaller than expected impact"
    ]
    if expectedImpact < 0 [
      print "warining: expectedImpact smaller than 0"
    ]
    if expectedImpact > riskPerceptionThreshold [set satisfied? false]
  ]

  tick

;  if ticks > 360 [stop]

end

to check-weather
  ask orgs [
    let tempSeverity log-normal 5 extremeWeatherProb
    set weatherSeverity tempSeverity ; did not rescale
    ifelse weatherSeverity < extremeWeatherThreshold
    [set expectedEWProb expectedEWProb * (1 - (0.01 + random-float 0.01))] ; extremeweatherevent did not happen, then expectedprob decrease
    [
      set extremeWeather? true
      set extremeWeatherFreq extremeWeatherFreq + 1
      ifelse weatherSeverity < diasterThreshold
      [set expectedEWProb expectedEWProb * (1 + 0.05 + random-float 0.05 )]
      [
        set expectedEWProb expectedEWProb * (1 + 0.25 + random-float 0.05)
        set disaster? true
        if random-float 1 < declarationRate [set declared? true]
        set disasterFreq disasterFreq + 1
      ]
    ]
     if expectedEWProb >= 0.25 [set expectedEWProb  0.25] ; disaster more strongly enhance expected EW prob
     if expectedEWProb <= 0.01 [set expectedEWProb 0.01]
  ]

end

to expect-impact
  ask orgs [
    set impactPerTick ifelse-value (weatherSeverity - solEfficacy < 0 ) [0] [weatherSeverity - solEfficacy]

    set expectedImpact (expectedBadWeatherSeverity - solEfficacy ) * expectedEWProb

    if resilience-decay?[
      if impactPertick > 0 [ ; if impacted by weather, resilience goes down
      set resilience resilience * (0.9998 + random-float 0.00009)
      if resilience < 1 [set resilience 1]
      ]
    ]
  ]
end

to determine-windows
  ask orgs [
      if declared? [
      set changeEvents fput ticks changeEvents
      set changeEvents remove-duplicates changeEvents
    ]
  ]
end


to search-solution
  ask orgs with [not solution-ready?][ ; only orgs with no alternative solution are looking
    if expectedImpact > riskPerceptionThreshold [
      let currentImpact expectedBadWeatherSeverity -  solEfficacy  ; note here it does not multiply the expectedEWProb
      if currentImpact < 0 [set currentImpact 0]

      if currentImpact > 0 [
         let targetSolEfficacy calculate-target-efficacy solEfficacy currentImpact expectedBadWeatherSeverity  (random-float impactReductionRate  + 0.05)
         ifelse targetSolEfficacy <= maxCopingEfficacy
      [
        ask current-solution [set efficacy targetSolEfficacy]
        set solEfficacy [efficacy] of current-solution
        set copingChangeNum copingChangeNum + 1
        set copingChangeTicks fput ticks copingChangeTicks
        set coping-change? true
      ][
        set search-adaptation? true
        search-adaptation
        ]
      ]
    ]
  ]
end

to search-adaptation
  ifelse trigger-network?
  [assess-thruNetwork]
  [assess-allSolutions]

  if targetSolution != nobody
  [
    ifelse capacity < [cost] of targetSolution
   [
     set postponed? true
     set solution-ready? true
     set color red
   ][
     implement-adaptation
    ]
  ]

end


to assess-allSolutions
   let mySolEfficacy [efficacy] of current-solution
   let adaptationPool solutions with [adaptation? and efficacy > mySolEfficacy]
   if any? adaptationPool
   [set targetSolution one-of adaptationPool with-max [efficacy]]

end

to assess-thruNetwork
  let scanningPatches patches in-radius scanningRange
  let currentSolEfficacy [efficacy] of current-solution
  let knownSolutions (solutions-on scanningPatches) with [adaptation?]
  ifelse any? knownSolutions
  [set targetSolution one-of knownSolutions]
  [
    set targetSolution nobody
    set color yellow
    set not-found? true
  ]


end

to implement-adaptation
    set adaptTicks fput ticks adaptTicks
    set adaptation-change? true

    set solEfficacy [efficacy] of targetSolution
    remove-links-between self current-solution
    set current-solution targetSolution
    create-org-sol-link-with targetSolution [set color grey]
    set targetSolution nobody
    set solution-ready? false
    set postponed? false
end


;to search-solution
;  let targetOrgs ifelse-value allow-multipleChanges?
;  [orgs with [not innovation-ready?]]
;  [orgs with [not innovation-ready? and length copingChangeTicks = 0 ]]
;
;  ask targetOrgs [
;    if expectedImpact > riskPerceptionThreshold [
;      set satisfied? false
;      set crossRiskThresholdTicks fput ticks crossRiskThresholdTicks
;      let myneighbors (turtle-set org-sameReg-link-neighbors  org-diffReg-link-neighbors)
;      let known-solutions (turtle-set [org-sol-link-neighbors] of myneighbors)
;      let my-solution current-solution
;      let better-solutions known-solutions with [efficacy > [efficacy] of my-solution]
;
;      ifelse any? better-solutions
;      [
;  ;        set targetSolution ifelse-value (random-float 1 <= 0.5) [one-of better-solutions][one-of better-solutions with-max [efficacy]]
;          set targetSolution one-of better-solutions
;          set current-solution targetSolution
;          remove-links-between self current-solution
;          create-org-sol-link-with targetSolution [set color grey]
;          set coping-change? true
;          ;set color blue
;          set copingChangeTicks fput ticks copingChangeTicks
;      ]
;      [
;        set innovation-ready? true
;      ]
;    ]
;  ]
;end


to check-window
  if open-windows?[
    ask orgs with [postponed? and member? ticks changeEvents][
      set capacity capacity * (1  + random-float capBoost)
      ifelse expectedImpact > riskPerceptionThreshold [
        ifelse capacity >= [cost] of targetSolution
        [implement-adaptation]
        [set insufBoost fput ticks insufBoost]
      ][
        set missedWindows fput ticks missedWindows
      ]
    ]
  ]
end





;to search-solution
; ask orgs with [riskPerceptionSum > riskPerceptionThreshold and color != blue] [
;     set satisfied? false
;
;     let myneighbors (turtle-set org-sameReg-link-neighbors  org-diffReg-link-neighbors)
;     let known-solutions (turtle-set [org-sol-link-neighbors] of myneighbors)
;     let my-solution current-solution
;     let better-solutions known-solutions with [efficacy > [efficacy] of my-solution  ]
;
;     ifelse any? better-solutions
;     [
;        set targetSolution ifelse-value (random-float 1 <= 0.5) [one-of better-solutions][one-of solutions with-max [efficacy]] ; half of the chance to find best available solution
;        let previous-solution current-solution
;        remove-links-between self previous-solution
;        create-org-sol-link-with targetSolution [set color grey]
;        if random-float 1 <= 0.90
;       [set current-solution targetSolution  ; there are 90% chance to implement coping change if found one
;        set coping-change? true
;        set color blue
;        set copingChangeTicks fput ticks copingChangeTicks
;;         set satisfied? true
;
;         ]
;     ][
;     ;  innovate-adaptation  ; if not found better solution, the innovate
;     ]
; ]
;
;end



to-report  calculate-target-efficacy [org-solEfficacy org-impact org-weatherSeverity  org-reductionRate]
 let orgDesiredImpact org-impact * (1 - org-reductionRate)
 let org-target-efficacy (org-weatherSeverity - orgDesiredImpact )
 if org-target-efficacy < 0 [print "warning: org target efficacy is smaller than 0"]
 report org-target-efficacy

end


to remove-links-between [one-org one-sol]
    ask my-links with [other-end = one-sol][die]
end
to-report frequency [an-item a-list]
  report length (filter [i -> i = an-item] a-list)
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
@#$#@#$#@
GRAPHICS-WINDOW
210
10
564
365
-1
-1
10.5
1
25
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
-5
10
58
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
597
10
797
160
#crossThreshold
Time
riskPerception
0.0
100.0
0.15
0.3
true
true
"" ""
PENS
"crossThre" 1.0 0 -15040220 true "" "plot count orgs with [expectedImpact > riskPerceptionThreshold]"

SLIDER
5
95
177
128
scanningRange
scanningRange
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
5
130
177
163
innoRate
innoRate
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
5
205
177
238
simulateMonths
simulateMonths
0
3600
1215.0
1
1
NIL
HORIZONTAL

PLOT
805
10
1005
160
#Adopters
NIL
NIL
0.0
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
305
380
372
425
coping
count orgs with [copingChangeNum > 0]
0
1
11

PLOT
1235
10
1435
160
maxThreshold
NIL
NIL
0.0
10.0
0.0
0.3
true
true
"" ""
PENS
"riskPer" 1.0 0 -15040220 true "" "plot [expectedImpact] of one-of orgs with-max [riskPerceptionThreshold]"
"Thresh" 1.0 0 -10873583 true "" "plot [riskPerceptionThreshold] of one-of orgs with-max [riskPerceptionThreshold]"

MONITOR
385
380
447
425
unhappy
count orgs with [not satisfied?]
0
1
11

MONITOR
220
380
297
425
crossThresh
count orgs with [expectedImpact > riskPerceptionThreshold]
0
1
11

PLOT
1240
160
1440
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
"Threshold" 1.0 0 -5298144 true "" "plot sum  [riskperceptionthreshold] of orgs with-max [extremeWeatherProb]"

PLOT
1245
320
1445
470
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
"threshold" 1.0 0 -8053223 true "" "plot  [riskPerceptionThreshold] of one-of orgs with-max [originalEfficacy]"

SWITCH
10
440
142
473
random-seed?
random-seed?
1
1
-1000

PLOT
1030
10
1230
160
minThreshold
NIL
NIL
0.0
10.0
0.0
0.2
true
true
"" ""
PENS
"riskPer" 1.0 0 -15040220 true "" "plot [expectedImpact] of one-of orgs with-min [riskPerceptionThreshold]"
"Thresh" 1.0 0 -10873583 true "" "plot [riskPerceptionThreshold] of one-of orgs with-min [riskPerceptionThreshold]"

PLOT
1035
165
1235
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
"pen-1" 1.0 0 -8053223 true "" "plot sum [riskPerceptionThreshold] of orgs with-min [extremeweatherprob]"

PLOT
1040
320
1240
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
"default" 1.0 0 -14439633 true "" "plot sum [expectedImpact] of orgs with-min [originalEfficacy]"
"pen-1" 1.0 0 -8053223 true "" "plot sum [riskperceptionthreshold] of orgs with-min [originalEfficacy]"

SLIDER
10
245
182
278
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
5
285
185
318
impactReductionRate
impactReductionRate
0
0.2
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
5
60
177
93
meanRiskThreshold
meanRiskThreshold
0
1
0.77
0.01
1
NIL
HORIZONTAL

SLIDER
5
325
177
358
maxCopingReduction
maxCopingReduction
0
0.5
0.33
0.01
1
NIL
HORIZONTAL

SLIDER
5
365
177
398
adaptionCost
adaptionCost
0
10
2.7
0.1
1
NIL
HORIZONTAL

MONITOR
305
430
362
475
adapted
count orgs with [adaptation-change?]
0
1
11

MONITOR
225
430
287
475
postpone
count orgs with [postponed?]
0
1
11

SLIDER
5
165
177
198
numWindows
numWindows
0
10
5.0
1
1
NIL
HORIZONTAL

SWITCH
10
515
147
548
open-windows?
open-windows?
0
1
-1000

MONITOR
470
380
527
425
minImp
min [expectedImpact] of orgs
2
1
11

SLIDER
5
405
177
438
capBoost
capBoost
0
5
5.0
0.1
1
NIL
HORIZONTAL

SWITCH
5
475
152
508
resilience-decay?
resilience-decay?
1
1
-1000

SWITCH
160
510
307
543
trigger-network?
trigger-network?
0
1
-1000

MONITOR
385
430
447
475
notFound
count orgs with [not-found?]
0
1
11

MONITOR
385
480
467
525
noFoundada
count orgs with [not-found? and [adaptation?] of current-solution]
0
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
