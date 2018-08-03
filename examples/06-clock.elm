import Html exposing (Html, div, p, text, button)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick, onMouseDown)
import Svg exposing (svg, circle, line, rect, defs, linearGradient, stop)
import Svg.Attributes exposing (viewBox, height, width, cx, cy, r, fill, id, x, y, x1, x2, y1, y2, stroke, offset)
-- import Css exposing (..)
import Time exposing (Time, second)
import Mouse
-- import Keyboard
import Random
import Random.Float exposing (normal)
import Debug exposing (log)

      -- , svg [ viewBox "0 0 100 100", width "300px" ]
      --   [ circle [ cx "50", cy "50", r "45", fill "#0B79CE" ] []
      --   , line [ x1 "50", y1 "50", x2 "90", y2 "90", stroke "#023963" ] []

main : Program Never Model Msg
main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }
    
    
-- Types

type alias RiskEvent =
  {
    event_type: String,
    event_weight: Float
  }
  
-- Funcs

tripScore: List RiskEvent -> Int -> Float -> Float
tripScore risk_events tripInSecs distAdjustCoeff =
  let
    weights = List.map (\e -> e.event_weight) risk_events
  in
    let sum = List.foldr (+) 0.0 weights
    in (e ^ ( -sum / (toFloat tripInSecs * distAdjustCoeff) )) * 100
    
    
updateDriverScore: Float -> Float -> Float -> Float -> Float -> Float
updateDriverScore oldScore newScore tripDistInKm movingAvgCoeff maxAlpha =
  let
    alpha = Basics.min (movingAvgCoeff * (logBase e (tripDistInKm + e))) maxAlpha
  in
    log (String.concat ["alpha ",  (toString alpha)])
    log (String.concat ["dist log ",  (toString (logBase e (tripDistInKm + e)))])
    log (String.concat ["new ",  (toString ((1 - alpha) * oldScore + alpha * newScore))])
    (1 - alpha) * oldScore + alpha * newScore


-- DriverScore

distanceAdjustmentCoefficient = 0.0023
movingAverageCoefficient = 0.015
maximumAverageCoefficient = 0.2

baseDuration = 1800 -- 30min
baseKm = 50 -- 50km

driverScore: Float -> List RiskEvent -> Float
driverScore oldScore riskEvents =
  let
    tripS = tripScore riskEvents baseDuration distanceAdjustmentCoefficient
  in
    log (String.concat ["ts ", (toString tripS)])
    updateDriverScore oldScore tripS baseKm movingAverageCoefficient maximumAverageCoefficient


highAcc = RiskEvent "HardAcc" 1.0
midAcc = RiskEvent "MidAcc" 0.415
lowAcc = RiskEvent "LowAcc" 0.125

-- MODEL


type alias Model =
  { time: Time
  , driverSkill: Float
  , randValue: Float
  , riskEvent: String
  , randGauss: Float
  , score: Float
  , x: Int
  , y: Int
  }

init : (Model, Cmd Msg)
init =
  (
    { time = 0
    , driverSkill = 50.0
    , randValue = 0.0
    , riskEvent = "Nothing"
    , score = 50.0
    , randGauss = -1.0
    , x = 0
    , y = 0
    }
  , Cmd.none
  )

riskEvents =
  [ (0.1040, "hardBreak35")
  , (0.1250, "fastAcc35")
  , (0.2023, "hardBreak45")
  , (0.2665, "speedyTurn")
  , (0.4050, "hardBreak55")
  , (0.4157, "fastAcc45")
  , (1.0000, "fastAcc55")
  ]

gaussStdDev = 0.1

slider =
  { x0 = 0
  , y0 = 500
  , x1 = 800
  , y1 = 600
  }



-- UPDATE


type Msg
  = Tick Time
  | IncrementSkill
  | DecrementSkill
  | Rand Time
  | NewValue Float
  | RandRE
  | NewRE Float
  | IncrementScore
  | DecrementScore
  | Position Int Int


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Tick newTime ->
      ( { model | time = newTime }, Cmd.none)
    DecrementSkill ->
      ( { model | driverSkill = updateSkill model -1 }, Cmd.none )
    IncrementSkill ->
      ( { model | driverSkill = updateSkill model 1 }, Cmd.none )
    Rand newTime ->
      ( model, Random.generate NewValue (Random.float 0.0 1.0) )
    NewValue newFloat ->
      ( { model | randValue = newFloat }, Cmd.none )
    RandRE ->
      ( model, Random.generate NewRE (normal (model.driverSkill / 100.0) gaussStdDev) )
    NewRE newFloat ->
      ( { model | riskEvent = getRE newFloat, randGauss = newFloat }, Cmd.none )
    IncrementScore ->
      ( { model | score = driverScore model.score [lowAcc] }, Cmd.none )
    DecrementScore ->
      ( { model | score = driverScore model.score [lowAcc, highAcc, highAcc, highAcc] }, Cmd.none )
    Position x y ->
      ( updateSkillFromSlider model x y, Cmd.none )


updateSkill : Model -> Float -> Float
updateSkill model i =
  let
    updatedDriverSkill = model.driverSkill + i
  in
    if updatedDriverSkill < 0 then
      0
    else if updatedDriverSkill > 100 then
      100
    else
      updatedDriverSkill


updateSkillFromSlider model x y =
  if x >= slider.x0 && x <= slider.x1
  && y >= slider.y0 && y <= slider.y1 then
    { model | x = x, y = y, driverSkill = x / (toFloat slider.x1) * 100 }
  else
    model


getRE : Float -> String
getRE newFloat =
  let
    re = List.foldr (closest newFloat) (0.1040, "hardBreak35") riskEvents
  in
    Tuple.second re


closest newFloat sofar next =
  let
      minDistSofar =
        newFloat - (Tuple.first sofar)
        |> abs

      distNext =
        newFloat - (Tuple.first next)
        |> abs
  in
      if minDistSofar < distNext then
        sofar
      else
        next




-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ Time.every second Tick
    , Time.every second Rand
    , Mouse.clicks (\{x, y} -> Position x y)
    -- , Mouse.moves (\{x, y} -> Position x y)
    ]



-- VIEW


view : Model -> Html Msg
view model =
  let
    mstyle =
      style
        [ ("position", "relative")
        , ("backgroundColor", "blue")
        , ("height", "100px")
        , ("width", "100px")
        , ("margin", "50px")
        ]
  in
    div []
      [ p [] [ text <| "Model: " ++ toString model ]
      , p [] [ text <| "inSeconds: " ++ (toString <| Basics.round <| Time.inSeconds model.time) ]
      , div []
        [ text <| "Driver Skill " ++ (toString model.driverSkill)
        , button [ onClick IncrementSkill ] [ text "+"]
        , button [ onClick DecrementSkill ] [ text "-"]
      ]
      , div []
        [ text <| "Driver Score " ++ (toString model.score)
        , button [ onClick IncrementScore ] [ text "better"]
        , button [ onClick DecrementScore ] [ text "worse"]
        ]
      , div []
        [ p [] [ text <| "Random " ++ (toString model.randValue) ]
        , p [] [ text <| "Random Gauss: " ++ (toString model.randGauss) ]
        ]
      , div []
        [ text <| "Risk Event: " ++ (toString model.riskEvent)
        , button [ onClick RandRE ] [ text "change"]
        ]
      , div
        [ style
            [ ("position", "fixed")
            , ("top", toString slider.y0 ++ "px")
            , ("width", toString slider.x1 ++ "px")
            , ("height", toString (slider.y1 - slider.y0) ++ "px")
            ]
        ]
        [ svg
          [ viewBox "0 0 100% 30%"
          , width "100%"
          , height "100%"
          ]
          [ defs []
            [ linearGradient [ id "grad1", x1 "0%", y1 "0%", x2 "100%", y2 "0%" ]
              [ stop [ offset "0%", Svg.Attributes.style "stop-color:rgb(255,0,0,0.3);stop-opacity:1" ] []
              , stop [ offset "48%", Svg.Attributes.style "stop-color:rgb(255,255,255,0.3);stop-opacity:1" ] []
              , stop [ offset "52%", Svg.Attributes.style "stop-color:rgb(255,255,255,0.3);stop-opacity:1" ] []
              , stop [ offset "100%", Svg.Attributes.style "stop-color:rgb(0,255,0,0.3);stop-opacity:1" ] []
              ]
            ]
          , rect [ x "0", y "0", width "100%", height "100%", fill "url(#grad1)" ] []
          , line [ x1 "50%", y1 "2%", x2 "50%", y2 "98%", stroke "rgba(0,0,0,0.3)" ] []
          , maybeLine model
          ]
        ]
      ]


maybeLine : Model -> Svg.Svg Msg
maybeLine model =
  line [ x1 <| toString model.x, y1 "2%", x2 <| toString model.x, y2 "98%", stroke "rgba(0,0,0,0.7)" ] []