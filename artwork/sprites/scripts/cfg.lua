-- Settings for the nell-master pipeline. Paths are derived from this file's location (artwork/sprites/scripts/).
local here = debug.getinfo(1, "S").source:gsub("^@", "")
SCRIPTS = app.fs.filePath(here)
local SP = app.fs.pathSeparator
SPRITES = app.fs.filePath(SCRIPTS)
D = app.fs.joinPath(SCRIPTS, "work") .. SP                                  -- regenerated intermediates (git-ignored)
SRC = app.fs.joinPath(app.fs.filePath(SPRITES), "concept", "nell-typing-4frames.png")
MASTER = app.fs.joinPath(SPRITES, "nell-master.aseprite")
REV = app.fs.joinPath(SPRITES, "review") .. SP
OUT = D; OX, OY = 1, 5                 -- prep.lua: frame-1 crop offset in the concept strip
LINE_T, OUT_L = 55, 33                 -- still2.lua: line threshold, outline brightness cut
LAPTOP={{6,74},{44,78},{47,97},{80,101},{83,107},{52,113},{15,108}}
CHAIR={{107,64},{126,62},{126,106},{109,106}}
DESK_Y=104
RAMPS={plum={"#261A22","#372931","#3F3039","#483942"}, hair={"#231917","#332321","#432E2B","#4A3532","#614B49"},
 chair={"#1A1214","#261A22","#2F232B"}, desk={"#281C1A","#3D2926","#4A3532","#614B49"},
 laptopnear={"#64595B","#82686C","#554141","#483942","#3F3039","#261A22","#9C797E"}}
QUANT={plum={0.12,0.45,0.85}, hair={0.12,0.35,0.72,0.93}, chair={0.3,0.75}, desk={0.1,0.3,0.55}}
FACEPAL={"#F5D4C9","#F2CDC1","#F4B6AC","#D5A3A2","#E4D8D6","#F7F0ED","#EC9394","#CF7D8B","#B47D83","#A74F5E","#833C47","#622C36","#531721","#AF9295","#9C797E","#82686C","#7D5257","#A16774","#DE7379","#CD636D","#64595B","#554141","#AEABAC"}
FACEBOX={42,36,48,34}
OUTN="still3"
HEAD={{28,0},{127,0},{127,62},{108,64},{108,77},{92,77},{84,67},{46,68},{40,74},{28,74}}
FACE={42,36,48,35}
EYES={44,44,45,19}
-- hands (round 3): the round-1 drawing, unchanged pixel for pixel; only moved onto the keyboard
-- (right hand +3 px right of round 1). Left hand: +4 px in round 3; Task 8 round 2 moved it 3 px back left so the lid
-- (drawn in front of it, see LID_EDGE) hides its outer edge, at the user's request.
HANDS={
 {x=47,y=93,rows={"....KKKKKK.....","..KKSSSSSSKK...",".KSSSSSSSSSBK..",".KSSRSSRSSRBBK.",".KSSRSSRSSRBDK.","KSSRSSRSSRSBDK.","KSSRSSRSSRBDK..","KBBKBBKBBKDK...",".KK.KK.KK.K...."}},
 {x=65,y=95,rows={".....KKKKKK.....","...KKSSSSSSKK...","..KBSSSSSSSSSK..",".KDBSRSSRSSRSSK.","KDDKSRSSRSSRSSK.","KDKSRSSRSSRSSK..",".KKSRSSRSSRSBK..","..KBKBBKBBKBBK..","...K.KK.KK.KK..."}},
}
EYE_SPEC={
 {sx=52.5, sy=51, srx=5, sry=4.6, ix=54, iy=51.5, irx=3.1, iry=4.2, pupil={{54,51},{54,52}}, glint={{52,49}}, flick={{46,48},{58,47}}},
 {sx=77.5, sy=53.5, srx=7.6, sry=5.6, ix=75.5, iy=53.5, irx=4.1, iry=5.2, pupil={{75,53},{76,53},{75,54},{76,54}}, glint={{73,51},{74,51},{73,52}}, flick={{69,49},{86,50},{87,51}}},
}
RIM_SPEC={
 {cx=52, cy=50.5, rx=8.2, ry=8.6, glare={{47,45},{48,44}}},
 {cx=77.5, cy=53.5, rx=11, ry=10.6, glare={{70,47},{71,46},{72,45}}},
}
BRIDGE={{61,50},{62,50},{63,50},{64,51},{65,51},{66,51},{43,48},{42,48},{89,52}}
MOUTH={x=59,y=61,rows={"V..V..V",".VV.VV."}}
MOUTH_CLEAR={56,59,13,5}
STRINGS={63,70}
LOGO={x=24,y=88,rows={"C...C","CC.CC","CCCCC","CCCCC",".CCC."}}
DESK_SHADOW={{84,106,104}}
ORPH_SKIP={{49,93,13,9},{65,95,16,9},{58,60,9,4}} -- plus the sclera ellipses of EYE_SPEC (orphans.lua)
EMOJI={28,14,16,16}
PAPER={102,92,20,16}
-- round 2 hand touch-ups (after the automatic outline pass): lid edge bump, desk right top corner
PATCHES={
 {layer="body", x=7, y=82, rows={".x","xx",".x"}, legend={x="#00000000"}},
 {layer="eyes", x=60, y=52, rows={".P.",".P.",".P.","BBB"}, legend={P="#CF7D8B", B="#F4B6AC"}},
 {layer="eyes", x=57, y=52, rows={"I"}, legend={I="#554141"}},
 {layer="eyes", x=66, y=55, rows={"...S","....","K...",".K.."}, legend={S="#F2CDC1", K="#120D0E"}},
 {layer="head", x=63, y=88, rows={"P"}, legend={P="#372931"}},
 -- round 3: key pixels peeking between the round-1 fingertips become plain deck grey
 {layer="laptop", x=50, y=101, rows={"G..G..G..G.....G"}, legend={G="#64595B"}},
 {layer="laptop", x=67, y=103, rows={"G"}, legend={G="#64595B"}},
 {layer="chair", x=124, y=104, rows={"x.",".x"}, legend={x="#00000000"}},
 {layer="desk", x=124, y=106, rows={"B"}, legend={B="#614B49"}},
 -- Task 8 round 2 (left hand 3 px left): the sleeve pixel left beside the hand's top and a lone key fragment uncovered right of it
 {layer="body", x=57, y=93, rows={"P"}, legend={P="#372931"}},
 {layer="laptop", x=60, y=101, rows={"G"}, legend={G="#64595B"}},
}
-- The lid's right edge: per row, the first outline pixel of the laptop layer at x >= 40. Laptop pixels at or left of
-- it are the lid, which stays in front of the left hand (hands.lua and body.lua never cut them).
function LID_EDGE(img, y) for x = 40, 60 do if img:getPixel(x, y) == app.pixelColor.rgba(0x12, 0x0D, 0x0E, 255) then return x end end return -1 end
-- body loops (Task 8, body.lua)
-- one entry per frame: c = chest (body layer) and h = head (head, face, eyes) offset in px, +1 up (breath, lean back),
-- -1 down (slump); l / r = left / right hand up 1; fx = typing sparks (TYPING_FX); face = the face drawn in (a face:*
-- tag; default the idle face, which the app covers with its pasted face); eyes = "closed" (the eyes:closed patch);
-- arm = the raised left arm (ARMS); d = duration in ms (multiples of a 1/12 s tick).
-- tag = the tag name; data = its user data: rest = the two resting frames as offsets from the tag's first frame,
-- face=drawn = the face is part of the frames (the app skips its face and blink overlays on that tag).
BODY_LOOPS = {
  {tag = "body:idle", data = "rest=0,4", frames = {   -- two breaths of 2.5 s: hold, chest leads, head follows, chest falls first
    {d = 1000}, {c = 1, d = 250}, {c = 1, h = 1, d = 1000}, {h = 1, d = 250},
    {d = 1000}, {c = 1, d = 250}, {c = 1, h = 1, d = 1000}, {h = 1, d = 250}}},
  {tag = "body:typing", data = "rest=0,2", frames = { -- hands alternate on a 167 ms beat; one breath per 1.33 s loop
    {d = 167}, {l = 1, d = 167, fx = "Rt"}, {d = 167}, {c = 1, r = 1, d = 167, fx = "Lt"},
    {c = 1, h = 1, d = 167, fx = "Rt"}, {c = 1, h = 1, l = 1, d = 167, fx = "Ro"}, {h = 1, d = 167, fx = "Lt"}, {r = 1, d = 167, fx = "Lo"}}},
  -- yawning (4.67 s): a slumped sleepy breath, then one yawn: the left hand rises to her mouth, eyes squeeze shut,
  -- she leans back, and the hand comes down again. Rests (0, 4) are the same slumped pose.
  {tag = "body:yawning", data = "rest=0,4 face=drawn", frames = {
    {c = -1, h = -1, face = "exhausted", d = 917},
    {h = -1, face = "exhausted", d = 250},
    {face = "exhausted", d = 917},
    {c = -1, face = "exhausted", d = 250},
    {c = -1, h = -1, face = "exhausted", d = 583},
    {arm = "mid", face = "exhausted", d = 250},
    {c = 1, h = 1, arm = "mouth", face = "exhausted", eyes = "closed", d = 1250},
    {arm = "mid", face = "exhausted", d = 250}}},
  -- in-betweens: the face changes behind a drawn blink (typing rest -> blink -> chest drops -> yawning rest, and back)
  {tag = "between:typing-yawning", data = "face=drawn", frames = {
    {face = "exhausted", eyes = "closed", d = 167}, {c = -1, face = "exhausted", d = 250}}},
  {tag = "between:yawning-typing", data = "face=drawn", frames = {
    {h = -1, face = "exhausted", d = 250}, {face = "exhausted", eyes = "closed", d = 167}}},
}
-- the raised left arm for the yawn (props layer, never over the lid): the accepted left-hand rows flipped upright at
-- hand = {x, y} (9 rows; the gaps between the fingertips are closed with outline), on a sleeve from the cuff (top) down
-- to the elbow behind the lid (bot); xl / xr = the sleeve's left and right outline x at top and bottom
ARMS = {   -- the cuff starts on the wrist row (the hand's last row), one pixel wider than the wrist on each side
  mid   = {hand = {49, 75}, top = 83, bot = 94, xl = {52, 44}, xr = {59, 59}},
  mouth = {hand = {52, 58}, top = 66, bot = 94, xl = {55, 40}, xr = {62, 59}},
}
-- typing sparks (fx above): tap ticks at the top corners of the hand that is down (t), then the same ticks flying out
-- one step (o). 3 px ticks, cream with a pink-400 outer tip; resting frames (0, 2) have none.
TYPING_FX = {
  Lt = {{50, 92, "#FFF4EC"}, {49, 91, "#FFF4EC"}, {48, 90, "#F4B6AC"}, {57, 92, "#FFF4EC"}, {58, 91, "#FFF4EC"}, {59, 90, "#F4B6AC"}},
  Lo = {{48, 89, "#F4B6AC"}, {60, 89, "#F4B6AC"}},
  Rt = {{68, 93, "#FFF4EC"}, {67, 92, "#FFF4EC"}, {66, 91, "#F4B6AC"}, {77, 93, "#FFF4EC"}, {78, 92, "#FFF4EC"}, {79, 91, "#F4B6AC"}},
  Ro = {{65, 90, "#F4B6AC"}, {80, 90, "#F4B6AC"}},
}
