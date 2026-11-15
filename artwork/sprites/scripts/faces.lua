-- Faces (Task 7): frame 1 is the accepted idle face. Every other face is built from it by changing only
-- the eye interiors (inside the shared eye footprint), the mouth box and small extras, so the face rectangle's
-- edges, fringe and glasses rims match by construction and every face shares one eye position.
-- Adds frames + tags face:<name> and a last frame eyes:closed that holds ONLY the closed-eye patch on the eyes
-- layer (transparent outside the footprint; draw it over any face). Safe to re-run: frames 2.. and tags are rebuilt.
-- Run after the master is built (run_all.lua does), or alone:  dofile([[<repo>/artwork/sprites/scripts/faces.lua]])
if not EYE_SPEC then dofile(app.fs.joinPath(app.fs.filePath(debug.getinfo(1, "S").source:gsub("^@", "")), "cfg.lua")) end
local pc = app.pixelColor
local spr = app.activeSprite
if not spr or spr.filename ~= MASTER then spr = app.open(MASTER) end
local function hex(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local function layer(n) for _, l in ipairs(spr.layers) do if l.name == n then return l end end end
local function inE(x, y, cx, cy, rx, ry) local dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry; return dx*dx + dy*dy <= 1 end
local function inRect(x, y, r) return x >= r[1] and y >= r[2] and x < r[1] + r[3] and y < r[2] + r[4] end

-- reset to the single idle frame
-- body:*, between:*, paper:* and emoji:* tags go too: their frames (10..) are deleted here, so run body.lua and props.lua after this script (run_all.lua does)
for i = #spr.tags, 1, -1 do local n = spr.tags[i].name; if n:match("^face:") or n == "eyes:closed" or n:match("^body:") or n:match("^between:") or n:match("^paper:") or n:match("^emoji:") then spr:deleteTag(spr.tags[i]) end end
while #spr.frames > 1 do spr:deleteFrame(#spr.frames) end

local LF, LE = layer("face"), layer("eyes")
local BASE = Image(128, 128, ColorMode.RGB)
BASE:drawImage(LF:cel(1).image, LF:cel(1).position); BASE:drawImage(LE:cel(1).image, LE:cel(1).position)

local C = {K=hex("#120D0E"), LID=hex("#F2CDC1"), CREASE=hex("#D5A3A2"), LLID=hex("#B47D83"), Q=hex("#F7F0ED"), P=hex("#E4D8D6"),
  V=hex("#622C36"), W=hex("#A16774"), T=hex("#CF7D8B"), X=hex("#EC9394"), A=hex("#531721"), SKIN=hex("#F5D4C9"),
  BL=hex("#6F8FD0"), BLD=hex("#3E5C9E"), CREAM=hex("#FFF4EC"), PINK=hex("#F4B6AC"), BROW=hex("#A74F5E")}

-- eye geometry from EYE_SPEC: per column, the sclera's top and bottom rows
local EX = {}
for i, e in ipairs(EYE_SPEC) do
  local g = {e = e, cols = {}, x0 = math.huge, x1 = -math.huge}
  for x = math.floor(e.sx - e.srx - 1), math.ceil(e.sx + e.srx + 1) do
    local top, bot
    for y = math.floor(e.sy - e.sry - 1), math.ceil(e.sy + e.sry + 1) do if inE(x, y, e.sx, e.sy, e.srx, e.sry) then top = top or y; bot = y end end
    if top then g.cols[x] = {top = top, bot = bot}; g.x0 = math.min(g.x0, x); g.x1 = math.max(g.x1, x) end
  end
  EX[i] = g
end
-- the shared eye footprint: lash rows (top-1, top) .. lower lid row (bot+1) of every sclera column
local FP = {}
for _, g in ipairs(EX) do for x, c in pairs(g.cols) do for y = c.top - 1, c.bot + 1 do FP[y * 128 + x] = true end end end
local function inFP(x, y) return FP[y * 128 + x] == true end

local function rows(img, x, y, rs, legend) for r, row in ipairs(rs) do for c = 1, #row do local v = legend[row:sub(c, c)]; if v then img:drawPixel(x + c - 1, y + r - 1, v) end end end end
local function px(img, list, col) for _, p in ipairs(list) do img:drawPixel(p[1], p[2], col) end end

-- upper lid: U(i, x) is the lid's lash bottom row; rows above it inside the footprint become lid skin
local function upperLid(img, U)
  for i, g in ipairs(EX) do for x, c in pairs(g.cols) do
    local u = U(i, x, c); if u and u > c.top then u = math.min(u, c.bot)
      for y = c.top - 1, u - 2 do img:drawPixel(x, y, C.CREASE) end
      img:drawPixel(x, u - 1, C.K); img:drawPixel(x, u, C.K)
    end
  end end
end

-- iris: clear the old iris to sclera, then draw a new one (scale s, offset dx, dy); keeps lash and lid pixels
local IRIS = {[C.V]=true, [C.W]=true, [C.T]=true, [C.X]=true, [C.A]=true}
local function sclera(e, x, y) return (x + 0.5 > e.sx + e.srx * 0.45 and y + 0.5 > e.sy) and C.P or C.Q end
local function iris(img, s, dx, dy, opt)
  opt = opt or {}
  for i, g in ipairs(EX) do local e = g.e
    for x, c in pairs(g.cols) do for y = c.top, c.bot do if IRIS[img:getPixel(x, y)] then img:drawPixel(x, y, sclera(e, x, y)) end end end
    local ix, iy, rx, ry = e.ix + dx, e.iy + dy, e.irx * s, e.iry * s
    local function inI(x, y) return inE(x, y, ix, iy, rx, ry) end
    for x, c in pairs(g.cols) do for y = c.top, c.bot do
      local v = img:getPixel(x, y)
      if inI(x, y) and (v == C.Q or v == C.P) then
        local ring = not (inI(x-1, y) and inI(x+1, y) and inI(x, y-1) and inI(x, y+1))
        local col = C.T
        if ring then col = C.V elseif y + 0.5 < iy - ry * 0.3 then col = C.W elseif y + 0.5 > iy + ry * 0.45 then col = C.X end
        img:drawPixel(x, y, col)
      end
    end end
    local p = (opt.pupil or {})[i]; if p then px(img, p, C.A) end
    local gl = (opt.glint or {})[i]; if gl then px(img, gl, C.Q) end
  end
end

-- closed eye: lid skin over the whole footprint, a shallow lash curve low in the eye, the lower lid line kept
local function closed(img)
  for i, g in ipairs(EX) do local e = g.e
    local outerLeft = (i == 1)               -- left eye's outer corner is on the left, right eye's on the right
    for x, c in pairs(g.cols) do
      for y = c.top - 1, c.bot do img:drawPixel(x, y, y == c.top - 1 and C.CREASE or C.LID) end
      img:drawPixel(x, c.bot + 1, C.LLID)
      local t = (x + 0.5 - e.sx) / e.srx
      local ly = math.floor(e.sy + e.sry * 0.55 * (1 - t * t))
      img:drawPixel(x, ly, C.K)
      if math.abs(t) < 0.5 then img:drawPixel(x, ly - 1, C.K) end
    end
    local xo = outerLeft and g.x0 or g.x1          -- outer-corner flick, one pixel up and out
    img:drawPixel(xo, math.floor(e.sy) - 1, C.K)
  end
end

-- FACES: each entry edits a copy of the idle rectangle. Mouth box is cleared to skin first when `mouth` is set.
local MOUTH_BOX = {56, 59, 12, 6}   -- skin only: x 68 is the right rim's outer ring
-- sad's big teardrops (round 4, replacing the round 2-3 rivers): one classic drop per eye on the cheek just under
-- the lens's lower inner corner (rims left whole), plus tears welling over the lower lid at that corner.
-- D dark-blue outline, B blue body, W snow highlight. The welling sits in the footprint, so a blink hides it; the drops stay.
SAD_DROPS = {
  {x = 54, y = 59, rows = {"..D..", ".DWD.", "DWBBD", "DWBBD", "DBBBD", ".DDD."}},   -- left: x 54-58, y 59-64
  {x = 69, y = 63, rows = {"..D..", ".DWD.", "DWBBD", "DBBBD", ".DDD."}},            -- right: x 69-73, y 63-67
}
SAD_WELL = {{54,55},{55,55},{72,58},{73,58}}
local ML = {V = C.V, O = C.A, T = C.X}
local FACES = {
  {name = "idle"},
  {name = "intent",
   lid = function(i, x, c) if i == 1 then return x <= 52 and 47 or 48 else return x <= 75 and 50 or 49 end end,
   extra = function(img) px(img, {{54,39},{55,40},{56,40},{57,41}}, C.BROW); px(img, {{71,42},{72,41},{73,41},{74,40},{75,40}}, C.BROW) end},
  {name = "exhausted",
   lid = function(i, x, c) return i == 1 and 50 or 53 end,
   mouth = {x = 60, y = 61, rows = {"V.V.V", ".V.V."}},
   extra = function(img)   -- tired: shaded lower white and a darker lower lid (eye bags)
     for i, g in ipairs(EX) do for x, c in pairs(g.cols) do local t = (x + 0.5 - g.e.sx) / g.e.srx
       if math.abs(t) < 0.8 and img:getPixel(x, c.bot) == C.Q then img:drawPixel(x, c.bot, C.P) end; img:drawPixel(x, c.bot + 1, C.W) end end
     px(img, {{57,55},{54,56}}, C.W)   -- the two lower-lid ends just outside the footprint join the bags
   end},
  {name = "happy", iris = {0.85, 0, 0, {pupil = {{{54,52}}, {{75,54}}}, glint = {{{53,50}}, {{74,52}}}}},
   mouth = {x = 59, y = 61, rows = {"VVVVVVV", "VOOOOOV", ".VTTTV.", "..VVV.."}},
   extra = function(img) rows(img, 52, 60, {".PPP.", "PXXXP"}, {P = C.PINK, X = C.X}); rows(img, 68, 63, {".PPP.", "PXXXP"}, {P = C.PINK, X = C.X}) end},
  {name = "smile", iris = {0.75, -1, 0, {pupil = {{{53,52}}, {{74,54}}}, glint = {{{52,50}}, {{73,52}}}}},
   mouth = {x = 58, y = 60, rows = {"V.......V", ".V..V..V.", "..VV.VV.."}},
   extra = function(img) rows(img, 52, 60, {".PP.", "PXXP", ".PP."}, {P = C.PINK, X = C.X}); rows(img, 69, 63, {".PP.", "PXXP"}, {P = C.PINK, X = C.X}) end},
  {name = "sad", iris = {0.7, 0, 0, {pupil = {{{54,52}}, {{75,54}}}, glint = {{{53,50}}, {{74,52}}}}},
   mouth = {x = 60, y = 61, rows = {".VVV.", "V...V"}},
   extra = function(img)
     for i, g in ipairs(EX) do for x, c in pairs(g.cols) do local t = (x + 0.5 - g.e.sx) / g.e.srx
       if math.abs(t) < 0.7 then img:drawPixel(x, c.bot, C.BL) end end end
     px(img, {{52,55},{76,58}}, C.CREAM)
     px(img, SAD_WELL, C.BL)
     for _, d in ipairs(SAD_DROPS) do rows(img, d.x, d.y, d.rows, {D = C.BLD, B = C.BL, W = C.CREAM}) end
     px(img, {{58,38},{57,38},{56,39},{55,39}}, C.BROW); px(img, {{71,40},{72,40},{73,41},{74,41}}, C.BROW)
   end},
  {name = "scared", iris = {0.45, 0, 0, {pupil = {{{54,52}}, {{75,54}}}}},
   mouth = {x = 59, y = 61, rows = {".V.V.V.", "V.V.V.V"}},
   extra = function(img)
     for y = 37, 43 do for x = 52, 77 do if x % 2 == 0 and img:getPixel(x, y) == C.T then img:drawPixel(x, y, C.W) end end end
     rows(img, 54, 60, {".D.", "DBD", "DWD", ".D."}, {D = C.BLD, B = C.BL, W = C.CREAM})
   end},
  {name = "awe", iris = {1.12, 0, 0, {pupil = {{{54,52}}, {{75,53},{76,53},{75,54},{76,54}}},
     glint = {{{53,49},{52,50},{53,50},{54,50},{53,51},{55,54}}, {{73,50},{72,51},{73,51},{74,51},{73,52},{78,56}}}}},
   mouth = {x = 60, y = 61, rows = {".VV.", "VTTV", ".VV."}},
   extra = function(img) rows(img, 52, 60, {".PP.", "PXXP"}, {P = C.PINK, X = C.X}); rows(img, 69, 63, {".PP.", "PXXP"}, {P = C.PINK, X = C.X}) end},
}

local function build(f)
  local img = BASE:clone()
  if f.lid then upperLid(img, f.lid) end
  if f.iris then iris(img, f.iris[1], f.iris[2], f.iris[3], f.iris[4]) end
  if f.mouth then
    for y = MOUTH_BOX[2], MOUTH_BOX[2] + MOUTH_BOX[4] - 1 do for x = MOUTH_BOX[1], MOUTH_BOX[1] + MOUTH_BOX[3] - 1 do img:drawPixel(x, y, C.SKIN) end end
    rows(img, f.mouth.x, f.mouth.y, f.mouth.rows, ML)
  end
  if f.extra then f.extra(img) end
  for _, p in ipairs(FACE_PATCHES and FACE_PATCHES[f.name] or {}) do rows(img, p.x, p.y, p.rows, p.legend) end
  return img
end

-- split a 128x128 face image into the face layer (face rect minus eyes rect) and the eyes layer (eyes rect)
local function split(img)
  local fi, ei = Image(FACE[3], FACE[4], ColorMode.RGB), Image(EYES[3], EYES[4], ColorMode.RGB)
  for y = FACE[2], FACE[2] + FACE[4] - 1 do for x = FACE[1], FACE[1] + FACE[3] - 1 do
    local v = img:getPixel(x, y)
    if inRect(x, y, EYES) then ei:drawPixel(x - EYES[1], y - EYES[2], v) else fi:drawPixel(x - FACE[1], y - FACE[2], v) end
  end end
  return fi, ei
end

app.transaction(function()
  for n, f in ipairs(FACES) do
    if n > 1 then
      local fr = spr:newEmptyFrame(n)
      for _, l in ipairs(spr.layers) do local c = l:cel(1)
        if c and l ~= LF and l ~= LE then spr:newCel(l, fr, c.image:clone(), c.position) end end
      local fi, ei = split(build(f))
      spr:newCel(LF, fr, fi, Point(FACE[1], FACE[2])); spr:newCel(LE, fr, ei, Point(EYES[1], EYES[2]))
    end
  end
  -- eyes:closed: only the patch, on the eyes layer, transparent outside the footprint
  local n = #FACES + 1
  local fr = spr:newEmptyFrame(n)
  local full = Image(128, 128, ColorMode.RGB); closed(full)
  local patch = Image(EYES[3], EYES[4], ColorMode.RGB)
  for y = EYES[2], EYES[2] + EYES[4] - 1 do for x = EYES[1], EYES[1] + EYES[3] - 1 do
    if inFP(x, y) then patch:drawPixel(x - EYES[1], y - EYES[2], full:getPixel(x, y)) end end end
  spr:newCel(LE, fr, patch, Point(EYES[1], EYES[2]))
  -- tags only after every frame exists: a new frame would stretch any tag ending on the last frame
  for i, f in ipairs(FACES) do local t = spr:newTag(i, i); t.name = "face:" .. f.name end
  local t = spr:newTag(n, n); t.name = "eyes:closed"
end)

-- palette: every colour used on any frame (frame 1's 31 first, in their existing order)
local seen, cols = {}, {}
local pal = spr.palettes[1]
for i = 1, #pal - 1 do local c = pal:getColor(i); local v = pc.rgba(c.red, c.green, c.blue, 255); if not seen[v] then seen[v] = true; cols[#cols + 1] = v end end
for f = 1, #spr.frames do local im = Image(128, 128, ColorMode.RGB); im:drawSprite(spr, f)
  for it in im:pixels() do local v = it(); if pc.rgbaA(v) > 0 and not seen[v] then seen[v] = true; cols[#cols + 1] = v end end end
local np = Palette(#cols + 1); np:setColor(0, Color{r=0, g=0, b=0, a=0})
for i, v in ipairs(cols) do np:setColor(i, Color{r=pc.rgbaR(v), g=pc.rgbaG(v), b=pc.rgbaB(v)}) end
spr:setPalette(np)
spr:saveAs(spr.filename)
FACE_NAMES = {} for i, f in ipairs(FACES) do FACE_NAMES[i] = f.name end
print("faces ok", #FACES, "frames", #spr.frames, "palette", #cols)
