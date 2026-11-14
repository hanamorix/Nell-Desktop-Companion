-- Build nell-master.aseprite: split still3 into chair/body/head/face/eyes by material + region; draw desk and laptop as clean shapes.
local pc = app.pixelColor
local function hex(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local OUT = hex("#120D0E")
local SHADOW = hex("#261A22")
local st = app.open(D .. "still3.aseprite"); local art = Image(128,128,ColorMode.RGB); art:drawSprite(st, 1)
local ms = app.open(D .. "still3_mat.png"); local mat = Image(128,128,ColorMode.RGB); mat:drawSprite(ms, 1)
local function inPoly(px, py, poly)
  local inside, j = false, #poly
  for i = 1, #poly do local xi, yi, xj, yj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
    if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then inside = not inside end; j = i end
  return inside
end
local function inRect(x, y, r) return x >= r[1] and y >= r[2] and x < r[1]+r[3] and y < r[2]+r[4] end
local names = {"chair","body","desk","laptop","head","face","eyes","props"}
local spr = Sprite(128, 128, ColorMode.RGB)
local L, IM = {}, {}
spr.layers[1].name = names[1]; L[1] = spr.layers[1]
for i = 2, #names do L[i] = spr:newLayer(); L[i].name = names[i] end
for i = 1, #names do IM[names[i]] = Image(128, 128, ColorMode.RGB) end
-- material code from the colour map
local function m(x, y) local c = mat:getPixel(x, y); if pc.rgbaA(c) == 0 then return nil end
  local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
  if r == 0 and g == 0 and b == 0 then return "out" elseif b == 255 and r == 0 then return "laptop" elseif r == 255 and g == 128 then return "desk"
  elseif r == 255 and b == 255 then return "face" elseif r == 128 and g == 64 then return "hair" elseif g == 255 then return "chair" else return "plum" end end
-- 1. character + chair from the still (desk and laptop are redrawn below)
for y = 0, 127 do for x = 0, 127 do
  local mm = m(x, y)
  if mm == "laptop" and y < 104 and x >= 40 then IM.body:drawPixel(x, y, SHADOW) end -- old laptop area: hoodie shadow behind the new laptop
  if mm and mm ~= "desk" and mm ~= "laptop" and y < 112 then -- nothing of Nell or the chair shows below the desk top
    local px, py = x + 0.5, y + 0.5
    local dst
    if inRect(x, y, EYES) then dst = "eyes"
    elseif inRect(x, y, FACE) then dst = "face"
    elseif inPoly(px, py, CHAIR) and (mm == "chair" or mm == "out") then dst = "chair"
    elseif (mm == "hair" or inPoly(px, py, HEAD)) and y < 103 then dst = "head"
    else dst = "body" end
    -- outline pixels below the desk top line belonged to desk/laptop edges: drop them
    local keep = true
    if mm == "out" then -- outline that only borders the old desk/laptop belongs to the redrawn shapes: drop it
      local own = false
      for dy = -1, 1 do for dx = -1, 1 do local nx, ny = x + dx, y + dy
        if nx >= 0 and ny >= 0 and nx < 128 and ny < 128 then local n = m(nx, ny); if n and n ~= "out" and n ~= "desk" and n ~= "laptop" then own = true end end end end
      keep = own
    end
    -- hands are redrawn by hand: the converted hand area becomes hoodie shadow on body, nothing on head
    if y >= 91 and y <= 104 and x >= 44 and x <= 82 and (mm == "face" or mm == "hair") then dst, keep = "body", "shadow" end
    if keep == "shadow" then IM.body:drawPixel(x, y, SHADOW) elseif keep then IM[dst]:drawPixel(x, y, art:getPixel(x, y)) end
  end
end end
-- 2. desk
local DK = IM.desk
local C = {top = hex("#614B49"), edge = hex("#4A3532"), front = hex("#3D2926"), dark = hex("#281C1A")}
local function yb(x) return 105 - math.floor((x - 3) * 2 / 121 + 0.5) end
-- slab with pixel-rounded corners: per column, the top/bottom are inset near both ends (stepped, no AA)
local TOPIN, BOTIN = {5, 3, 2, 1}, {3, 1}
local function slab(x) -- returns top (outline row) and bottom (outline row) of the slab at column x, or nil
  if x < 2 or x > 125 then return nil end
  local d = math.min(x - 2, 125 - x)
  return yb(x) - 1 + (TOPIN[d + 1] or 0), 117 - (BOTIN[d + 1] or 0)
end
local function inSlab(x, y) local t, b = slab(x); return t and y >= t and y <= b end
for x = 2, 125 do local t, b = slab(x)
  for y = t, b do
    local c
    if not (inSlab(x-1, y) and inSlab(x+1, y) and inSlab(x, y-1) and inSlab(x, y+1)) then c = OUT
    elseif y <= 110 then c = C.top elseif y == 111 then c = C.edge else c = C.front end
    DK:drawPixel(x, y, c)
  end
end
local function leg(x0, x1, y1, back)
  for y = 117, y1 do
    DK:drawPixel(x0 - 1, y, OUT); DK:drawPixel(x1 + 1, y, OUT)
    for x = x0, x1 do
      local c = C.front
      if back then c = (x == x0) and C.front or C.dark
      else if x == x0 then c = C.edge elseif x >= x1 - 1 then c = C.dark end end
      if y == 117 then c = C.dark end -- shadow under the desk top
      DK:drawPixel(x, y, c)
    end
  end
  for x = x0 - 1, x1 + 1 do DK:drawPixel(x, y1 + 1, OUT) end
  DK:drawPixel(x0 - 1, y1 + 1, pc.rgba(0,0,0,0)); DK:drawPixel(x1 + 1, y1 + 1, pc.rgba(0,0,0,0)) -- round the foot corners
end
leg(8, 13, 125, false); leg(25, 29, 122, true); leg(103, 108, 125, false); leg(116, 120, 122, true)
-- 3. laptop
local LP = IM.laptop
local function fillPoly(img, poly, col) for y = 0, 127 do for x = 0, 127 do if inPoly(x + 0.5, y + 0.5, poly) then img:drawPixel(x, y, col) end end end end
local function ring(img, poly, col) -- 1 px outline outside the polygon (4-neighbours)
  for y = 0, 127 do for x = 0, 127 do if not inPoly(x + 0.5, y + 0.5, poly) then
    if inPoly(x + 1.5, y + 0.5, poly) or inPoly(x - 0.5, y + 0.5, poly) or inPoly(x + 0.5, y + 1.5, poly) or inPoly(x + 0.5, y - 0.5, poly) then img:drawPixel(x, y, col) end end end end
end
-- base first (deck, its front face, and the strip under the lid that meets the lid at the hinge), lid over it
local DECK = {{46, 93}, {80, 98}, {83, 104}, {51, 109}}
local DECKF = {{51, 109}, {83, 104}, {83, 106}, {51, 111}}
local STRIP = {{16, 105}, {50, 108}, {51, 111}, {16, 108}}
fillPoly(LP, STRIP, hex("#3F3039"))
fillPoly(LP, DECKF, hex("#3F3039"))
fillPoly(LP, DECK, hex("#64595B"))
local function inBase(x, y) return inPoly(x, y, DECK) or inPoly(x, y, DECKF) or inPoly(x, y, STRIP) end
for y = 0, 127 do for x = 0, 127 do if not inBase(x + 0.5, y + 0.5) and (inBase(x + 1.5, y + 0.5) or inBase(x - 0.5, y + 0.5) or inBase(x + 0.5, y + 1.5) or inBase(x + 0.5, y - 0.5)) then LP:drawPixel(x, y, OUT) end end end
-- keys
for y = 96, 108 do for x = 48, 82 do
  -- 2 px dark keys with 1 px gaps on every other row (no single-pixel dots)
  if inPoly(x + 0.5, y + 0.5, {{49, 96}, {78, 100}, {80, 103}, {52, 107}}) and y % 2 == 1 and (x + y // 2) % 3 ~= 0 then LP:drawPixel(x, y, hex("#3F3039")) end
end end
local LID = {{7, 73}, {43, 77}, {50, 108}, {16, 105}}
fillPoly(LP, LID, hex("#64595B"))
-- lit rim along top and left edge, shadow along bottom and right
for y = 0, 127 do for x = 0, 127 do if inPoly(x + 0.5, y + 0.5, LID) then
  if not inPoly(x + 0.5, y - 0.5, LID) or not inPoly(x - 0.5, y + 0.5, LID) then LP:drawPixel(x, y, hex("#82686C"))
  elseif not inPoly(x + 0.5, y + 1.5, LID) or not inPoly(x + 1.5, y + 0.5, LID) then LP:drawPixel(x, y, hex("#554141")) end
end end end
ring(LP, LID, OUT)
spr:saveAs(D .. "build_tmp.aseprite")
for i = 1, #names do spr:newCel(L[i], 1, IM[names[i]], Point(0, 0)) end
spr:saveAs(MASTER)
print("ok")
