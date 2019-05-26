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
  agencyID
  region
  leader?
  partner
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
  perceivedControl
  s-index ; strategy index for each org, two strategies to choose from [routine, adaptation]
  FTARegion
  passRate
  declarationRate
  regional-leader?
  resilience  ; higher resilience means lower impact on agencies in extreme weather
  capacity ;used to decide if orgs have sufficient capacity to implement solutions
  extremeWeatherFreq
  impactPerTick
  impactExp
  freqImpact  ; per tick
  freqImpactExp ; cumulative
  otherInfExp
  neighborsWithDisaster
  satisfied?
  innovation?
  incrementalChangeTicks
  extremeWeatherSeverity
  crossRiskThresholdTicks
  riskPerception
  riskPerceptionThreshold
  riskPerceptionExp ; doc risk perception for each extreme events
  probExp ; document all weather exp regardless of intensity
  riskPerceptionSum
  riskPerceptionfromExp
  riskPerceptionFromOthers
  adapt
  riskPerceptionfromAll  ; risk perceptiom from agency's own exp and from watching their neighbors
  disasterMemoryCounter
  current-solution
  target-solution
  incremental-change?
  adaptation-change?
  disaster? ; whether happened disater or not
  solution-ready?
  postpone? ; whether orgs postpone taking actions
]

to setup
  ca
  set-histogram-num-bars 20
;  set meanRiskThreshold 0.25
;  set sdRiskThreshold 0.05
  set strategies ["routine" "adaptation"]
  set-default-shape solutions "box"
  import-orgs
  distribute-orgs
  setup-orgs
  setup-FTARegion
  setup-solutions
  setup-innovation
  setup-leaders
  setup-sameRegNetwork
  setup-diffRegNetwork


  reset-ticks

;  repeat orgMemory [
;    check-weather
;    update-weatherExp
;  ]
end

to import-orgs
  file-open "Transit agencies ABM_noHeader.csv"
  while [not file-at-end?]
  [
    let row csv:from-row file-read-line
    create-orgs  1 [
      set capacity item 2 row
      set capacity capacity + 0.25
      set region item 3 row
      set disasterProb item 6 row
      set passRate item 7 row
      set declarationRate item 14 row
      set FTARegion item 10 row
      set extremeWeatherProb item 12 row
      If extremeWeatherProb < disasterProb [
        print "extremeWeatherProb is smaller than disasterProb"
      ]

      set weatherSeverityExp record-severity-experience extremeWeatherProb ; determine weather severity norm based on 200 years timeline, functions are put at the end
      set severityMax max weatherSeverityExp
      set extremeWeatherThreshold  item (ceiling 2400 * extremeWeatherProb) weatherSeverityExp
      set disasterThreshold  item (ceiling 2400 * disasterProb) weatherSeverityExp
    ]
 ]

  file-close
end


to distribute-orgs  ; distribute orgs to 4 census region, with similar weather profile
  ask patches [if pxcor >= -0.05 and pxcor <= 0.05 [set pcolor grey]]
  ask patches [if pycor >= -0.05 and pycor <= 0.05 [set pcolor grey]]

  ask patches with [pxcor <=  16 and pxcor > 0.05 and pycor >= 0.05][set patchRegion "northeast"]
  ask patches with [pxcor >= -16 and pxcor <= -0.1 and pycor >= 0.1] [set patchRegion "west" ]
  ask patches with [pxcor <= 16 and pxcor > 0.1 and pycor < -0.1] [set patchRegion "south"  ]
  ask patches with [pxcor >= -16 and pxcor <= -0.1 and pycor < -0.1] [set patchRegion "midwest" ]

  (foreach ["northeast" "midwest" "south" "west"] [
    x -> ask orgs with [region = x][
      set target-patches patches with [patchRegion = x]
    ]
  ])

ask orgs [
    if target-patches != nobody [
     move-to one-of target-patches
      while [any? other turtles-here][
        move-to one-of target-patches
      ]
    ]
  ]

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
        set size 1.7
        set color yellow
        avoid-edges
        create-FTAoffice-org-links-with FTAorgs [hide-link]
      ]
    ]
  ])


end

to avoid-edges
  while [[pcolor] of patch-here = grey ][fd 1 ]

end


to setup-orgs

  ask orgs [
    set agencyID who
    set color white
    set shape "circle"
    set size 0.6
    set riskPerception 0 ; risk perception for each tick
    set extremeWeatherFreq 0
    set otherInfExp []
    set perceivedControl 0
    set resilience random-normal 0 1 ;resilience is the ax magnitude of disturbances that can be tolerated before incurring impacts, can be negative
;    set riskPerceptionThreshold random-normal 0.25 0.05
    set riskPerceptionThreshold random-normal meanRiskThreshold sdRiskThreshold
    if  riskPerceptionThreshold < 0 [set riskPerceptionThreshold 0]
    set crossRiskThresholdTicks []
    set satisfied? true
    set regional-leader? false
    set impactExp[]
    set probExp[]
    set freqImpact [] ; list of freq and impact per tick
    set freqImpactExp [] ; list of freq and impact over time
    set riskPerceptionExp []
    set riskPerceptionSum 0  ; cumulative risk perception
    set adapt 0
    set leader? false
    set incremental-change? false
    set adaptation-change? false
    set s-index 0  ; start with routine solutions
    set extremeWeather? false
    set disaster? false
    set disasterMemoryCounter 0
    set riskPerceptionFromOthers 0
    set solution-ready? false
    set postpone? false
    set innovation? false
    set target-solution nobody
    set incrementalChangeTicks []
  ]



end

to setup-solutions ; every turtle begins with a solution
  ask orgs [
    ask patch-here [
       sprout-solutions 1
      [
         set color green
;         set size 0.6
         set to-opportunity nobody
         set adaptation? false  ; the default solutions are routine ones, not adaptation-based
         set-efficacy-cost
         let my-org orgs-here
         create-org-sol-links-with my-org [hide-link]
         ask my-org [set current-solution myself]
      ]
    ]
  ]

end


to set-efficacy-cost
  set efficacy random-normal 0 1; for incremental solutions
  set adaptation? false
  set cost 0.05 + random-float (0.95 - 0.05) ; the same with capacity ranging from 0.05 to 0.95
  set size  efficacy  ; for vis purpose only
  if size > 1.2 [set size 1.2]
  avoid-edges
end


to setup-leaders  ; this procedure sets up regional leaders
   (foreach ["northeast" "midwest" "south" "west"]
    [
      x -> let regionLeader max-n-of 2 (orgs with [region = x]) [capacity]  ; each region has two leaders
      ask regionLeader [set leader? true]
    ])

end


to setup-sameRegNetwork

   (foreach ["northeast" "midwest" "south" "west"]
    [
      x -> set regionDiv x
      ask max-n-of 5 orgs with [region = x][capacity][set regional-leader? true]
      ask orgs with [region = x] [
        repeat 1 [
          create-org-sameReg-link-with find-regionalPartner [hide-link]
        ]
      ]
    ])
end


to-report find-regionalPartner
  ifelse random-float 1 < 0.6
  [set partner one-of orgs with [region = regionDiv and regional-leader?]]
  [set partner one-of orgs with [region = regionDiv and not regional-leader?]]

  while [self = partner][
    set partner find-regionalPartner
  ]
  report partner
end


to setup-diffRegNetwork
  (foreach ["northeast" "midwest" "south" "west"][
    x -> set regionDiv x
    ask orgs with [region = x][
      create-org-diffReg-link-with find-outsidePartner [hide-link]
    ]
  ])
end

to-report find-outsidePartner
  ifelse random-float 1 < 0.6
  [set partner one-of orgs with [region != regionDiv and regional-leader?]]
  [set partner one-of orgs with [region != regionDiv and not regional-leader?]]

  while [self = partner][
    set partner find-regionalPartner
  ]
  report partner
end



to go
  check-weather
  update-weatherExp ; update what the history of EW freq and impact
;  update-problem
  perceive-risk-from-exp ; update risk perception based on freq and impact
  update-riskExp-from-others ; update the neighbors' disaster exp
  perceive-risk-from-others ; update risk perception base on others' disaster exp
  total-riskPerception
  search-solution
  ;wait-for-scheduledPlan
  ask orgs [
    set extremeWeather? false
    set disaster? false
  ]

  tick

;  if ticks > 240 [stop]

end

to check-weather
  ask orgs [
    let tempSeverity log-normal 1 extremeWeatherProb
    set weatherSeverity tempSeverity ; did not rescale
;    if tempSeverity > severityMax [set severityMax tempSeverity]
;    set weatherSeverity tempSeverity / severityMax ; scaling severity within 0 and 1
    if weatherSeverity > extremeWeatherThreshold [
      set extremeWeather? true
      set extremeWeatherFreq extremeWeatherFreq + 1
      if tempSeverity > disasterThreshold [
        set disaster? true
        set disasterFreq disasterFreq + 1
      ]
      take-impact
    ]
  ]

end

to take-impact
  let sol-efficacy sum [efficacy] of org-sol-link-neighbors
  let effectiveIncrementalChange filter [x -> ticks - x < 60] incrementalChangeTicks
  if not empty? effectiveIncrementalChange [
    set perceivedControl sum (map [ x ->  random-float 0.5 ] effectiveIncrementalChange)
    ]

  ifelse sol-efficacy * resilience + perceivedControl  >= weatherSeverity ; impact is jointly decided by efficacy of org solution and weather severity
  [set impactPerTick 0]
  [set impactPerTick weatherSeverity - (sol-efficacy * resilience + perceivedControl)]

end


to update-weatherExp
  ask orgs [
    if extremeWeather?[
      set freqImpact (list 1 impactPerTick ticks)
      set impactExp fput freqImpact ImpactExp
    ]
    if (not empty? impactExp) and (ticks > orgMemory) [  ;can only remember risk within the institutional memory
      set impactExp filter [x -> ticks - item 2 x < orgMemory] impactExp
    ]
  ]
end

to perceive-risk-from-exp
  ask orgs [
    set riskPerceptionfromExp 0
    let riskPerceptionUpdate sum (map [x -> item 0 x * 0.194 + item 1 x * 0.257 + random-normal 0 0.01] impactExp)
    set riskPerceptionfromExp riskPerceptionfromExp + riskPerceptionUpdate
    set riskPerceptionfromExp riskPerceptionfromExp  * 0.1
  ]

end


to update-riskExp-from-others
  ask orgs [
    set neighborsWithDisaster org-sameReg-link-neighbors with [disaster?]
    if any? neighborsWithDisaster[
      set neighborsWithDisaster (list neighborsWithDisaster)
      let disasterInfluence (map [x -> (sentence x  ([impactPerTick] of x) ticks)] neighborsWithDisaster)
      if not empty? disasterInfluence [
        set otherInfExp sentence disasterInfluence otherInfExp
      ]
;      set otherInfExp filter [x -> not empty? x] otherInfExp
    ]
  ]

  filter-othersInf  ; filter influence of others based on the memory length

end



to filter-othersInf
  ask orgs [
    if not empty? otherInfExp [
      if ticks > orgMemory [
        set otherInfExp filter [x -> ticks - item 2 x < orgMemory  ] otherInfExp
      ]
    ]
  ]

end

to perceive-risk-from-others
  ask orgs [
    if not empty? otherInfExp [
    set riskPerceptionFromOthers 0
    let riskPerceptionFromOthersUpdate sum ( map [x -> 1 * 0.003 + item 1 x * 0.006 + random-normal 0 0.01] otherInfExp)
    ; the coefficients of freq and impact on risk perception are set as much lower than those from EW orgs directly experienced
    set riskPerceptionFromOthers riskPerceptionFromOthers + riskPerceptionFromOthersUpdate
;    set riskPerceptionFromOthers riskPerceptionFromOthers * 0.1  ; rescale risk perception
    ]

  ]

end

to total-riskPerception
  ask orgs [
    set riskPerceptionSum riskPerceptionFromExp  + riskPerceptionFromOthers
  ]

end

to search-solution
  let targetOrgs ifelse-value allow-multipleChanges?
  [orgs with [not innovation?]]
  [orgs with [not innovation? and length incrementalChangeTicks = 0 ]]

  ask targetOrgs [
    if riskPerceptionSum > riskPerceptionThreshold [
      set satisfied? false
      set crossRiskThresholdTicks fput ticks crossRiskThresholdTicks
      let myneighbors (turtle-set org-sameReg-link-neighbors  org-diffReg-link-neighbors)
      let known-solutions (turtle-set [org-sol-link-neighbors] of myneighbors)
      let my-solution current-solution
      let better-solutions known-solutions with [efficacy > [efficacy] of my-solution]

      ifelse any? better-solutions
      [
  ;        set target-solution ifelse-value (random-float 1 <= 0.5) [one-of better-solutions][one-of better-solutions with-max [efficacy]]
          set target-solution one-of better-solutions
          set current-solution target-solution
          remove-links-between self current-solution
          create-org-sol-link-with target-solution [set color grey]
          set incremental-change? true
          set color blue
          set incrementalChangeTicks fput ticks incrementalChangeTicks
      ]
      [
        set innovation? true
      ]
    ]
  ]
end

to-report frequency [an-item a-list]
  report length (filter [i -> i = an-item] a-list)
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
;        set target-solution ifelse-value (random-float 1 <= 0.5) [one-of better-solutions][one-of solutions with-max [efficacy]] ; half of the chance to find best available solution
;        let previous-solution current-solution
;        remove-links-between self previous-solution
;        create-org-sol-link-with target-solution [set color grey]
;        if random-float 1 <= 0.90
;       [set current-solution target-solution  ; there are 90% chance to implement incremental change if found one
;        set incremental-change? true
;        set color blue
;        set incrementalChangeTicks fput ticks incrementalChangeTicks
;;         set satisfied? true
;
;         ]
;     ][
;     ;  innovate-adaptation  ; if not found better solution, the innovate
;     ]
; ]
;
;end

to remove-links-between [one-org one-sol]
    ask my-links with [other-end = one-sol][die]
end

to setup-innovation
  create-solutions 20 [
    set adaptation? true
    set color red
    set cost random-float 0.25 + random-float (1 - 0.25)  ; based on capacity ranging from 0.05 - 0.95, so that about 11% of time, there is adaptation
;    set efficacy 0 random-normal 0 1 ;the routine solution efficacy is set at random-float 0.5; adaptatione efficacy is higher

    while [[pcolor] of patch-here = grey] [
      move-to one-of other patches
    ]
  ]


end

to innovate-adaptation
  if random-float 1 < innoRate [
    if any? solutions with [adaptation?] [
      set target-solution one-of solutions with [adaptation?]
      ifelse capacity >  [cost] of target-solution [ ; so far only about 23% of time, there is enough capacity to bear the cost of adaptation
        remove-links-between self current-solution
        create-org-sol-link-with target-solution [set color red]
        set current-solution target-solution
        set adaptation-change? true
        set satisfied? true
        set color blue
      ][
        set solution-ready? true
        set postpone? true
      ]
    ]
  ]


end

;to wait-for-scheduledPlan
;  ask orgs with [postpone?][
;    if ticks mod 12 = 0 [
;      if random-float 1 < 0.5 [
;        remove-links-between self current-solution
;         create-org-sol-link-with target-solution [set color red]
;         set current-solution target-solution
;         set adaptation-change? true
;         set postpone? false
;         set color blue
;      ]
;    ]
;  ]
;
;end

;to wait-for-disaster
;    ask orgs with [disaster?][
;    if postpone? [
;      let previous-solution current-solution
;      remove-links-between self previous-solution
;      create-org-sol-link-with target-solution
;      set adaptation-change? true
;    ]
;  ]
;
;end

;to update-problem
;  ask orgs [
;     let problemPerEvent map [x -> x *  ( 1 + x) ^ 2 ] impactExp
;     set problem sum problemPerEvent
;     if problem > 10 [set problem 10]  ; so that problem does not get incredibly big
;  ]
;
;end




to-report log-normal [mu sigma]
  let beta ln (1 + ((sigma / 2) / (mu ^ 2)))
  let x exp (random-normal (ln (mu) - (beta / 2)) sqrt beta)
  report x
end

to-report record-severity-experience[ewProb]
  let time 0
  let severity []
  while [time < 2400][  ; base weather pattern on 200 year experience
    set severity lput (log-normal 1 ewProb) severity
    set time time + 1
  ]
  set severity sort-by > severity
  report severity
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
581
382
-1
-1
11.0
1
10
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
0
10
63
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
75
11
138
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
144
10
207
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
riskPerception
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
"Total" 1.0 0 -15040220 true "" "plot mean [riskPerceptionSum] of orgs"
"Indirect" 1.0 0 -13791810 true "" "plot mean [riskPerceptionFromOthers] of orgs"
"Direct" 1.0 0 -5298144 true "" "plot mean [riskPerceptionFromExp] of orgs"

MONITOR
420
390
492
435
minRiskPer
min [riskPerceptionSum] of orgs
2
1
11

MONITOR
495
390
572
435
maxRiskPer
max [riskPerceptionSum] of orgs
2
1
11

SLIDER
10
70
182
103
orgMemory
orgMemory
24
72
40.0
1
1
NIL
HORIZONTAL

MONITOR
580
390
692
435
MeanRiskPer
mean [riskPerceptionSum] of orgs
2
1
11

SLIDER
10
105
182
138
meanRiskThreshold
meanRiskThreshold
0
1
0.25
0.01
1
NIL
HORIZONTAL

SLIDER
10
180
182
213
scanningRange
scanningRange
0
10
0.0
1
1
NIL
HORIZONTAL

MONITOR
580
440
637
485
minImp
min [impactPertick] of orgs
2
1
11

MONITOR
700
390
762
435
meanImp
mean [impactPerTick] of orgs
2
1
11

MONITOR
645
440
702
485
maxImp
max [impactPerTick] of orgs
2
1
11

PLOT
600
165
800
315
#crossThreshold
NIL
NIL
0.0
8.0
0.0
10.0
true
true
"" ""
PENS
"unhappy" 1.0 0 -5298144 true "" "plot count orgs with [riskPerceptionSum > riskPerceptionThreshold]"

SLIDER
5
215
177
248
innoRate
innoRate
0
1
0.0
0.01
1
NIL
HORIZONTAL

MONITOR
710
440
767
485
adapted
count orgs with [adaptation-change? ]
0
1
11

SLIDER
5
250
177
283
disasterMemory
disasterMemory
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
10
290
182
323
initialInnovation
initialInnovation
0
50
0.0
1
1
NIL
HORIZONTAL

MONITOR
780
395
892
440
riskPerFromOthers
mean [riskPerceptionFromOthers] of orgs
2
1
11

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
"adapt" 1.0 0 -14439633 true "" "plot count orgs with [adaptation-change?]"
"incre" 1.0 0 -8053223 true "" "plot count orgs with [incremental-change?]"
"pen-2" 1.0 0 -16777216 true "" "plot count orgs with [innovation?]"

MONITOR
275
390
342
435
InChange
count orgs with [incremental-change?]
0
1
11

PLOT
805
170
1005
320
trackRiskPerception
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
"pen-0" 1.0 0 -7500403 true "" ""

MONITOR
345
450
412
495
happy
count orgs with [satisfied?]
0
1
11

MONITOR
275
445
337
490
postpone
count orgs with [postpone?]
17
1
11

MONITOR
355
390
417
435
unhappy
count orgs with [not satisfied?]
0
1
11

SLIDER
10
330
182
363
memoryAbtOthers
memoryAbtOthers
0
60
0.0
1
1
NIL
HORIZONTAL

MONITOR
215
445
272
490
#inno
count orgs with [innovation?]
0
1
11

MONITOR
195
390
272
435
crossThresh
count orgs with [riskPerceptionSum > riskPerceptionThreshold]
0
1
11

MONITOR
420
445
497
490
noTargetSol
count orgs with [target-solution = nobody]
0
1
11

MONITOR
770
440
827
485
control
mean [perceivedControl] of orgs
2
1
11

MONITOR
500
445
557
490
inno
count orgs with [innovation?]
0
1
11

SLIDER
10
145
182
178
sdRiskThreshold
sdRiskThreshold
0
1
0.05
0.01
1
NIL
HORIZONTAL

SWITCH
5
370
187
403
allow-multipleChanges?
allow-multipleChanges?
0
1
-1000

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
