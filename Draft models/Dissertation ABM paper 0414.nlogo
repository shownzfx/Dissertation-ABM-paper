breed [orgs org]
breed [solutions solution]
breed [opportunities opportunity]

undirected-link-breed [org-sol-links org-sol-link]
undirected-link-breed [org-sameReg-links org-sameReg-link]
undirected-link-breed [org-diffReg-links org-diffReg-link]

globals [strategies]


;patches-own [region]
solutions-own [efficacy  cost to-opportunity adaptation?]; solutions include both non-adaptation and adaptation measures

opportunities-own [chance]


orgs-own [
  agencyID
  leader?
  target-patches
  extremeWeatherProb
  s-index ; strategy index for each org, two strategies to choose from [routine, adaptation]
  problem
  resilience  ; higher resilience means lower impact on agencies in extreme weather
  capacity ;used to decide if orgs have sufficient capacity to implement solutions
  extremeWeatherFreq
  impactPerTick
  impactExp
  freqImpact  ; per tick
  freqImpactExp ; cumulative
  satisfied?
  extremeWeatherSeverity
  extremeWeather? ; boolean whether the weather is extreme
  riskPerception
  riskPerceptionThreshold
  riskPerceptionExp ; doc risk perception for each extreme events
  probExp ; document all weather exp regardless of intensity
  riskPerceptionSum
  riskPerceptionFromOthers
  adapt
  riskPerceptionfromAll  ; risk perceptiom from agency's own exp and from watching their neighbors
  disasterMemoryCounter
  current-solution
  incremental-change?
  adaptation-change?
  disaster? ; whether happened disater or not
  solution-ready?
  postpone? ; whether orgs postpone taking actions
  target-solution
  region
]
links-own [category] ; orgs create links with orgs in the same region and also orgs in other regions (two types of links)

to setup
  ca
  set-histogram-num-bars 20
  set strategies ["routine" "adaptation"]
  set-default-shape solutions "box"
  import-orgs
  distribute-orgs
  setup-orgs
  setup-solutions
  setup-leaders
  setup-orgNetwork


  reset-ticks
end

to import-orgs
  file-open "Transit agencies ABM.csv"
  while [not file-at-end?]
  [
    let row read-from-string (word "[" file-read-line "]")
    print row
    print item 3 row
    create-orgs  1 [
      set capacity item 2 row
      set region item 3 row
    ]
 ]

  file-close
end

to distribute-orgs
  ask patches [if pxcor >= -0.05 and pxcor <= 0.05 [set pcolor grey]]
  ask patches [if pycor >= -0.05 and pycor <= 0.05 [set pcolor grey]]

;  ask n-of 30 patches with [pxcor <=  16 and pxcor > 0.05 and pycor >= 0.05] [sprout-orgs 1 [set region "Northeast"]]
;  ask n-of 45 patches with [pxcor >= -16 and pxcor <= -0.1 and pycor >= 0.1] [sprout-orgs 1 [set region "West"]]
;  ask n-of 65 patches with [pxcor <= 16 and pxcor > 0.1 and pycor < -0.1] [sprout-orgs 1 [set region "South"]]
;  ask n-of 59 patches with [pxcor >= -16 and pxcor <= -0.1 and pycor < -0.1] [sprout-orgs 1 [set region "Midwest"]]

  ask orgs with [region = "Region 1"][ ; northeast
    set target-patches  patches with [pxcor <=  16 and pxcor > 0.05 and pycor >= 0.05]
  ]
  ask orgs with [region = "Region 2"][ ; midwest
    set target-patches patches with [pxcor >= -16 and pxcor <= -0.1 and pycor < -0.1]
  ]
  ask orgs with [region = "Region 3"][ ; south
    set target-patches patches with [pxcor <= 16 and pxcor > 0.1 and pycor < -0.1]
  ]
  ask orgs with [region = "Region 4"][ ; west
    set target-patches patches with [pxcor >= -16 and pxcor <= -0.1 and pycor >= 0.1]
  ]


end

to setup-orgs

  ask orgs [
    set agencyID who
    set color white
    set size 0.6
    set shape "circle"
    set capacity 0.05 + random-float (0.95 - 0.05) ;  ranging from 0.05 to 0.95
    set problem 0
    set riskPerception 0 ; risk perception for each tick
    set extremeWeatherFreq 0
    set resilience random-float maxResilience  ;resilience is the max magnitude of disturbances that can be tolerated before incurring impacts
    set riskPerceptionThreshold 0.2 + random-normal 0 0.5
    set satisfied? true
    set extremeWeatherProb 0
    set extremeWeatherSeverity 0
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
    set target-solution nobody
  ]

end

to setup-solutions ; every turtle begins with a solution
  ask orgs [
    ask patch-here [
       sprout-solutions 1
      [
         set color green
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
  set efficacy random-float 0.5
  set adaptation? false
  set cost 0.05 + random-float (0.95 - 0.05) ; the same with capacity ranging from 0.05 to 0.95
  set size  efficacy * 2 ; for vis purpose only
end


to setup-leaders  ; this procedure sets up regional leaders
   (foreach ["Northeast" "Midwest" "South" "West"]
    [
      x -> let regionLeader max-n-of 2 (orgs with [region = x]) [capacity]  ; each region has two leaders
      ask regionLeader [set leader? true]
    ])

end

to setup-orgNetwork ; orgs in the four regions generate networks with orgs in the same and in the different regions

  (foreach ["Northeast" "Midwest" "South" "West"]
    [
      x -> ask orgs with [region = x ] [
      create-org-sameReg-links-with n-of random 5 other (orgs with [region = x ]) ; designed so there are more neighbors within than outside the regions
      [set category "sameRegion" hide-link]

      create-org-diffReg-links-with n-of random 3 other (orgs with [region != x ])
      [set category "diffRegion" hide-link]
     ]
   ])

end


;to set-cost-and-color  ;solutions differ in costs (adaptation are more expensive)
;    ifelse random-float 1 <= 0.2
;      [
;        set adaptation 1
;        set cost random-normal 5 2
;        set efficacy 0.05 + random-float  (0.95 - 0.05)
;        set color green
;        set size efficacy / 2
;      ][
;        set adaptation 0
;        set cost random-normal 1 1
;        set efficacy 0.05 + random-float  (0.95 - 0.05)
;        set color magenta
;        set size efficacy / 2
;  ]
;end

to go
  check-weather
  update-weatherExp
  perceive-risk-from-exp ; culmulative based on freq and impact
;  perceive-risk-from-others ; only influenced by others' disasters; haven't figured out if I need this
  search-solution

  ask orgs [
    set extremeWeather? false
    set disaster? false
  ]


  tick

end

to check-weather ; param for frequency of extreme weather comes from the survey
  ask orgs [
    set extremeWeatherProb random-float 1
    if extremeWeatherProb > 0.95 [ ; 5% chance for weather disaster
      set disaster? true
    ]
  ]

  ask orgs with [region = "Northeast" or region = "Midwest"] [
    ifelse extremeWeatherProb  >= 0.75
    [take-impact]  ; the threshold 0.75 is drawn from the survey data
    [set impactPerTick 0]

  ]

  ask orgs with [region = "South"][
     ifelse extremeWeatherProb >= 0.8
     [take-impact]
     [set impactPerTick 0]
  ]
  ask orgs with [region = "West"] [
    ifelse extremeWeatherProb  >= 0.9
    [take-impact]
    [set impactPerTick 0]
  ]
end

to update-weatherExp
  ask orgs [
    set probExp fput extremeWeatherProb probExp
    if length probExp > memory [
      set probExp remove-item (length probExp - 1) probExp
    ]

    set impactExp fput impactPerTick impactExp
    if length impactExp > memory [
      set impactExp remove-item (length impactExp - 1 ) impactExp
    ]
  ]
end

;   (foreach list probExp impactExp [
;      x ->
;      if length x > memory
;      [set x remove-item (length x - 1) x] ; if exceeds memory, then remove the oldest one
;    ])  #this one only creates a copy of probExp impactExp


to take-impact
  set extremeWeather? true
  set extremeWeatherFreq extremeWeatherFreq + 1
  set extremeWeatherSeverity random-float 5
  let sol-efficacy sum [efficacy] of org-sol-link-neighbors
  ifelse sol-efficacy >= extremeWeatherSeverity ; impact is jointly decided by org resilience and weather severity
  [set impactPerTick 0]
  [set impactPerTick extremeWeatherSeverity - sol-efficacy]

end

;to update-problem
;  set problem problem + extremeWeatherSeverity ^ (ln ( extremeWeatherSeverity + 1))  ; problem non-linearly g
;end

to perceive-risk-from-exp
  ask orgs [
   ( foreach probExp impactExp [
      [a b] ->
      set freqImpact (list 1 a b)

     if (item 1 freqImpact > 0.75) and (region = "Northeast" or region = "Midwest")
      [update-riskPerception]

      if (item 1 freqImpact > 0.8) and (region = "South")
      [update-riskPerception]

      if (item 1 freqImpact > 0.9) and (region = "West")
      [update-riskPerception]
    ])
  ]

end

to update-riskPerception
   set riskperceptionSum 0
   let riskPerceptionUpdate (item 0 freqImpact) * 0.2 + (item 2 freqImpact) * 0.26 + random-normal 0 0.01  ; add some random errors
   set riskperceptionSum riskperceptionSum + riskPerceptionUpdate

end

;to perceive-risk-from-others ; the module applies for only one disaster
;  ask orgs [
;    let regionalNeighbors org-sameReg-link-neighbors with [disaster?]
;    if (regionalNeighbors != nobody) and (not disaster?) [ ; when regional neighbors exp diaster, but not the agency itself
;      set disasterMemoryCounter disasterMemory
;      set riskPerceptionFromOthers initialPerception / disasterMemory * disasterMemoryCounter
;      set riskPerceptionfromAll riskPerceptionSum + riskPerceptionFromOthers
;    ]
;  ]
;
;  ask orgs [
;    if disasterMemoryCounter > 0 [
;      set disasterMemoryCounter disasterMemoryCounter - 1
;    ]
;  ]
;end

to search-solution
  ask orgs with [satisfied?] [
    if riskPerceptionSum > riskPerceptionThreshold [
      set satisfied? false
      let myneighbors (turtle-set org-sameReg-link-neighbors  org-diffReg-link-neighbors)
      let known-solutions (turtle-set [org-sol-link-neighbors] of myneighbors)
      let my-solution current-solution
      let better-solutions known-solutions with [efficacy > [efficacy] of my-solution  ]

      ifelse any? better-solutions
       [
         set target-solution one-of better-solutions
         let previous-solution current-solution
         remove-links-between self previous-solution
         create-org-sol-link-with target-solution
         if random-float 1 <= 0.90
        [set current-solution target-solution  ; there are 90% chance to implement incremental change if found one
         set incremental-change? true]
      ][
        innovate  ; if not found better solution, the innovate
      ]
    ]
  ]

end

to remove-links-between [one-org one-sol]
    ask my-links with [other-end = one-sol][die]
end


to innovate
  if random-float 1 < innoRate [
   ask patch-here [
      sprout-solutions 1
      [
        set adaptation? true
        set color red
        set cost 0.5   ; based on capacity ranging from 0.05 - 0.95, so that about 11% of time, there is adaptation
        set efficacy 0.5 + random-float (1.5 - 0.5) ; the routine solution efficacy is set at random-float 0.5; adaptatione efficacy is higher
      ]
    ]

    set target-solution one-of solutions-here with [adaptation?]
    ifelse capacity >  [cost] of target-solution [ ; so far only about 23% of time, there is enough capacity to bear the cost of adaptation
      let previous-solution current-solution
      remove-links-between self previous-solution
      create-org-sol-link-with target-solution
      set current-solution target-solution
      set adaptation-change? true
    ][
      set solution-ready? true
      set postpone? true
      wait-for-opportunity
    ]

  ]

end

to wait-for-opportunity
  ask orgs with [disaster?][
    if solution-ready? [
      let previous-solution current-solution
      remove-links-between self previous-solution
      create-org-sol-link-with target-solution
      set adaptation-change? true
    ]
  ]


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
4
10
67
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

SLIDER
3
104
175
137
initial_num_solutions
initial_num_solutions
0
100
0.0
1
1
NIL
HORIZONTAL

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
rp,impact
Time
Freq
0.0
100.0
0.0
2.0
true
true
"" ""
PENS
"riskPer" 1.0 0 -15040220 true "" "plot mean [riskPerceptionSum] of orgs"
"impact" 1.0 0 -5298144 true "" "plot mean [impactPerTick] of orgs"

MONITOR
230
385
302
430
minRiskPer
min [riskPerceptionSum] of orgs
2
1
11

MONITOR
305
385
382
430
maxRiskPer
max [riskPerceptionSum] of orgs
2
1
11

SLIDER
5
150
175
183
maxResilience
maxResilience
0
10
0.0
1
1
NIL
HORIZONTAL

SLIDER
5
195
177
228
weatherSeverity
weatherSeverity
0
20
0.0
1
1
NIL
HORIZONTAL

SLIDER
5
240
177
273
memory
memory
24
72
26.0
1
1
NIL
HORIZONTAL

MONITOR
390
385
502
430
MeanRiskPer
mean [riskPerceptionSum] of orgs
2
1
11

SLIDER
5
275
177
308
perceptionThreshold
perceptionThreshold
0
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
5
320
177
353
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
230
440
287
485
minImp
min [impactPertick] of orgs
2
1
11

MONITOR
300
440
362
485
meanImp
mean [impactPerTick] of orgs
2
1
11

MONITOR
375
440
432
485
maxImp
max [impactPerTick] of orgs
2
1
11

PLOT
600
220
800
370
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [riskPerceptionSum] of orgs"

SLIDER
0
355
172
388
innoRate
innoRate
0
1
0.7
0.01
1
NIL
HORIZONTAL

MONITOR
445
435
502
480
adapted
count orgs with [adaptation-change? ]
0
1
11

SLIDER
0
390
172
423
disasterMemory
disasterMemory
0
100
36.0
1
1
NIL
HORIZONTAL

SLIDER
5
430
177
463
initialPerception
initialPerception
0
1
0.4
1
1
NIL
HORIZONTAL

MONITOR
550
440
652
485
meanRiskPerALL
mean [riskPerceptionfromAll] of orgs
2
1
11

MONITOR
545
385
622
430
diasterOrgs
count orgs with [disaster?]
0
1
11

MONITOR
660
390
772
435
riskPerFromOthers
mean [riskPerceptionFromOthers] of orgs
2
1
11

PLOT
880
45
1080
195
change
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -13840069 true "" "plot count orgs with [adaptation-change?]"
"pen-1" 1.0 0 -16777216 true "" "plot count orgs with [incremental-change?]"

MONITOR
230
490
297
535
InChange
count orgs with [incremental-change?]
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
