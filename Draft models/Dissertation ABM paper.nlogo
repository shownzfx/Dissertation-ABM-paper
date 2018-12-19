breed [orgs org]
breed [solutions solution]
breed [opportunities opportunity]
breed [problems problem]

patches-own [region]
solutions-own [efficiency  cost to-opportunity adaptation to-organization solutionID ]; only a small portion of solutions are adaptation-based
opportunities-own [chance]
problems-own [difficulty to-organization] ;problem difficulty bigger and more complex as extreme weather exp grows
orgs-own [
  agencyID
  weatherIntensity
  resilience  ; higher resilience means lower impact on agencies in extreme weather
  capacity ;used to decide if orgs have sufficient capacity to implement solutions
  extremeWeatherFreq
  impactPerTick
  impactExp
  riskPerception
  riskPerceptionExp ; doc risk perception for each extreme events
  weatherExp ; document all weather exp regardless of intensity
  riskPerceptionSum
  to-solution
  adapt
]
links-own [category] ; orgs create links with orgs in the same region and also orgs in other regions (two types of links)


to setup
  ca
  setup-regions
  setup-orgs
;  setup-orgNetwork
  setup-solutions

  reset-ticks
end


to setup-regions
  ask patches [if pxcor >= -0.05 and pxcor <= 0.05 [set pcolor grey]]
  ask patches [if pycor >= -0.05 and pycor <= 0.05 [set pcolor grey]]

  ask n-of 30 patches with [pxcor <=  16 and pxcor > 0.05 and pycor >= 0.05] [sprout-orgs 1 [set region "Northeast"]]
  ask n-of 45 patches with [pxcor >= -16 and pxcor <= -0.1 and pycor >= 0.1] [sprout-orgs 1 [set region "West"]]
  ask n-of 65 patches with [pxcor <= 16 and pxcor > 0.1 and pycor < -0.1] [sprout-orgs 1 [set region "South"]]
  ask n-of 59 patches with [pxcor >= -16 and pxcor <= -0.1 and pycor < -0.1] [sprout-orgs 1 [set region "Midwest"]]
end

to setup-orgs

  ask orgs [
    set agencyID who
    set color white
    set size 0.6
    set shape "circle"
    set capacity random-normal 2 1; the mean for adaptation cost is 5, so that more than half cannot implement adaptation solutions
    set riskPerception 0 ; risk perception for each tick
    set extremeWeatherFreq 0
    set resilience random maxResilience
    set weatherIntensity 0
    set impactExp[]
    set weatherExp[]
    set riskPerceptionExp []
    set riskPerceptionSum 0  ; cumulative risk perception
    set adapt 0
    set to-solution nobody
  ]

end


to setup-orgNetwork ; orgs in the four regions generate networks with orgs in the same and in the different regions

  (foreach ["Northeast" "Midwest" "South" "West"]
    [
      x -> ask turtles with [region = x ] [
      create-links-with n-of random 12 other turtles with [region = x]
      [set category "sameRegion" hide-link]

      create-links-with n-of 8 other turtles with [region != x]
      [set category "diffRegion" hide-link]
     ]
   ])

end

to setup-solutions
  set-default-shape solutions "box"
  create-solutions initial_num_solutions [
    setxy random-xcor random-ycor
    if [pxcor] of patch-here = 0 or [pycor] of patch-here = 0
    [setxy random-xcor random-ycor] ; avoid placement on the division lines
    set to-opportunity nobody
    set to-organization nobody
    ifelse random-float 1 <= 0.2
    [set adaptation 1] ; dummy code adaptation
    [set adaptation 0]  ; only 20% solutions are adaptation-based
    set-cost-and-color
  ]

end

to set-cost-and-color
    ifelse random-float 1 <= 0.2
      [
        set adaptation 1
        set cost random-normal 5 2
        set efficiency random-normal 2 1
        set color green
        set size efficiency / 1.5
      ][
        set adaptation 0
        set cost random-normal 1 1
        set efficiency random-normal 0 1
        set color magenta
        set size efficiency / 1.5
      ]
end

to go
  check-weather
  problems-occur  ; problems are created the first time when org experiences an EW
  perceive-risk
  problems-grow  ; happens after problems already created



  tick
end

to check-weather

  ask orgs with [region = "Northeast" or region = "Midwest"] [
    set weatherIntensity random-float 1
    if weatherIntensity  >= 0.75 [  ; the threshold 0.5 is drawn from the survey data
      set extremeWeatherFreq extremeWeatherFreq + 1
      take-impact
      ]
    ]
  ask orgs with [region = "South"][
     set weatherIntensity random-float 1
     if weatherIntensity >= 0.8 [
      set extremeWeatherFreq extremeWeatherFreq + 1
      take-impact
    ]
  ]
  ask orgs with [region = "West"] [
    set weatherIntensity random-float 1
    if weatherIntensity  >= 0.9 [
      set extremeWeatherFreq extremeWeatherFreq + 1
      take-impact
    ]
  ]

  ask orgs [set weatherExp fput weatherIntensity weatherExp] ; all orgs document the exp

end

to take-impact
  let weatherImpact random extremeWeatherDamage
  ifelse resilience >= weatherImpact
  [set impactPerTick 0]
  [set impactPerTick weatherImpact - resilience]

  set impactExp fput impactPertick impactExp  ; document each impact including when impact is 0 (having same length with weatherExp)

end

to perceive-risk ; (orgs procedure)
  ask orgs [
    set riskPerception impactPerTick * 0.257
    set riskPerceptionExp fput riskPerception riskPerceptionExp
    if length riskPerceptionExp > memory ; how long does the org memory last
    [set riskPerceptionExp remove-item (length riskPerceptionExp - 1) riskPerceptionExp]; if exceeds memory, then remove the oldest event

    set riskPerceptionSum sum riskPerceptionExp
    if riskPerceptionSum >  perceptionThreshold [ ; right now threshold is set as a slider, later will change it to a random var
    look-for-solutions
    ]
  ]

end

to look-for-solutions  ; turtle procedures
  let strategy one-of [1 2 3 4]
  if strategy = 1 [search-nearby]
  if strategy = 2 [search-regionNeighbors]
  if strategy = 3 [search-network]
  if strategy = 4 [innovate]

end


to search-nearby
;  print "search-nearby"
  let nearbySolutions solutions in-radius scanningRange ; scanningRange is slider
  if any? nearbySolutions [ ; how to calclulate if they have enough capacity to implement the solution
;    print "two"
    let chosenSolution one-of nearbySolutions
    print word "chosenSolution = " chosenSolution
    ask chosenSolution [set to-organization self] ; identify which org the solution is attached to
;    print "three"
    set to-solution chosenSolution ; identify which solution the org is attaching
  ]
   print "search-nearby done"
;    if capacity > [cost] of chosenSolution and capacity * [efficiency] of chosenSolution > [difficulty] of [link-neighbors] of myself
;             ; FX: How to model how they eval the efficiency of the solution when they might not know
;      [
;        ask ([link-neighbors] of myself) with [category = "problem"]
;        [set color blue] ; solved problem
;        if [adaptation] of chosenSolution = 1 [set adapt 1] ; if the solution is "adaptation-based", code adapt from 0 to 1
;      ]

end

to search-regionNeighbors ; turtle procedure
  let sameRegionNrbs [other-end] of (my-links with [category = "sameRegion"])
  set sameRegionNrbs orgs with [member? self sameRegionNrbs]; convert list to agentset

;  let sameRegionLinks my-links with [category = "sameRegion"]
;  let sameRegionNrbs link-neighbors with [any? my-links with [member? self sameRegionLinks]]
    if any? sameRegionNrbs [
      let chosenSameRegionNbr one-of sameRegionNrbs
      let nbrSolution [to-solution] of chosenSameRegionNbr
      if nbrSolution != nobody [
        set to-solution nbrSolution
      ]
    ]
end

to search-network
  let myNbrs [other-end] of (my-links with [category != "problem"])
  set myNbrs orgs with [member? self myNbrs]
  if any? myNbrs [
    let chosenNbr one-of myNbrs
    let nbrSolution [to-solution] of chosenNbr
    if nbrSolution != nobody [
      set to-solution nbrSolution
    ]
  ]
end

to innovate
  if random-float 1 < 0.2 [
    ask patch-here [
      sprout-solutions 1 [
      set solutionID who
      set color green
      set efficiency random-normal 0 1
      set to-organization myself
      set size efficiency
      set-cost-and-color
      set to-organization self
      ]
    ]
    set to-solution solutions with [who = solutionID]
  ]
end

;to perceive-risk
;  let preWeatherExp sublist weatherExp 0 min (list interval length weatherExp) ; subset the list by the timeframe user defined for memory
;  let preWeatherImp sublist impactExp 0 min (list interval length impactExp)
;  let extremeFreqImpact [] ; docs both freq and impacts in a list
;  let riskPerceptionSum ; risk perception updates
;
;  (foreach preWeatherExp preWeatherImp [
;    [a b]->
;    let freqDamage list a b
;    set freqDamage fput 1 freqDamage


to problems-occur  ; kick off organization's risk percpetion to sensing the problem
  ask orgs with [extremeWeatherFreq = 1 and not any? link-neighbors] [
    let id agencyID
    let a impactPerTick ; create var a to be used by patch-here to assess to generate difficulty level
    ask patch-here [
      sprout-problems 1 [
        set shape "square"
        set color red
        set difficulty random-float a ; the level of difficulty depends on the impact from each event
        set size 0.6
        set to-organization self
        create-links-with orgs with [agencyID = id]
        [set color red set category "problem"]
      ]
    ]

    ask link-neighbors [
      fd 1  ; to separate problem from agents a little bit for visualization
      if [pxcor] of patch-here = 0 or [pycor] of patch-here = 0 [
     ;   rt 180
      ]
    ]
  ]
end

to problems-grow ; how do I operationalize problem; how does problem grow: it cannot grow forever. Does there need to be some decay?
  ask orgs [
    let problem-links my-links with [category = "problem"]
    let problem-neighbors link-neighbors with [any? my-links with [member? self problem-links]]
    if any? problem-neighbors and extremeWeatherFreq > 1 [  ; after problem is generated, the problem grows with each extreme events (i.e. vulnearblity goes up)
        let coef weatherIntensity
        ask problem-neighbors [
        set difficulty difficulty + coef ^ ( ln (0.01 + 1)) ; problems grow non-linearly as experiencing more EW; problems grows unchecked until adaptation
        ]
      ]
    ]

end








@#$#@#$#@
GRAPHICS-WINDOW
210
10
548
349
-1
-1
10.0
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
40.0
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
EW frequency
Time
Freq
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -5298144 true "" "plot mean [extremeWeatherFreq] of orgs\n"
"pen-1" 1.0 0 -15040220 true "" "plot mean [riskPerceptionSum] of orgs"

MONITOR
214
362
280
407
Mean Diff
mean [difficulty] of problems
2
1
11

MONITOR
286
363
345
408
Max Diff
max [difficulty] of problems
2
1
11

MONITOR
355
365
412
410
Min Diff
min [difficulty] of problems
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
20
11.0
1
1
NIL
HORIZONTAL

SLIDER
5
195
175
228
extremeWeatherDamage
extremeWeatherDamage
0
20
10.0
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
0
48
24.0
1
1
NIL
HORIZONTAL

MONITOR
485
385
597
430
riskPerceptionSum
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
5.0
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
5.0
1
1
NIL
HORIZONTAL

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
