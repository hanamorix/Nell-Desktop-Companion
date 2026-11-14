-- Body loops and in-betweens (Task 8): appends every BODY_LOOPS entry (cfg.lua) after frame 9 (eyes:closed), so frames
-- 1-9 keep their indices and tags. Every body frame is built from frame 1 (the accepted master, idle face):
--  * breath: the body layer above BREATH_Y lifts 1 px (row BREATH_Y is doubled, inside the hoodie); the head, face and
--    eyes layers follow 1 px. The face rect sits wholly above BREATH_Y, so the face moves as a rigid translation.
--    The left hair tips that rest on the lid stay put (HAIR_X, HAIR_Y) and the hair stretches 1 px above them.
--  * typing: a hand lifts 1 px as an exact copy of the round-3 drawing; the laptop is cut under its new footprint and
--    the keyboard deck is restored where it was (DECK).
--  * slump: the same shift downwards (c/h = -1).
--  * drawn faces (face=drawn tags): the face and eyes cels come from that face's frame, optionally closed (eyes:closed).
--  * yawn arm: the left keyboard hand leaves the keys (deck restored) and a raised arm is drawn on props (ARMS).
--  * a move must not open holes in the partitioned layers: any pixel opaque on frame 1 but transparent now is filled
--    from the pixel it came from (below for a lift, above for a slump), on the layer that owns that pixel (FILL).
--  Chair, desk and laptop never move. Slice keys for face, eyes and emoji are written per body frame (slicekeys.lua).
-- Safe to re-run: frames 10.. and body:* / between:* tags are rebuilt. Re-running faces.lua deletes these frames; run this after it.
local SCRIPTS_DIR = app.fs.filePath(debug.getinfo(1, "S").source:gsub("^@", ""))
if not EYE_SPEC then dofile(app.fs.joinPath(SCRIPTS_DIR, "cfg.lua")) end
dofile(app.fs.joinPath(SCRIPTS_DIR, "slicekeys.lua"))
local pc = app.pixelColor
local spr = app.activeSprite
if not spr or spr.filename ~= MASTER then spr = app.open(MASTER) end
local function hex(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local CLEAR = pc.rgba(0, 0, 0, 0)

BASE_FRAMES = 9          -- face:idle .. face:awe, eyes:closed
BREATH_Y = 90            -- rows above this lift; the doubled row is plain hoodie, above both hands' cuffs (y 93, 95)
-- keyboard deck under the hands: plain deck grey, with the y 103 key row (2 px keys, 1 px gaps) right of the
-- round-3 patch at (67,103)
local DECK_G, DECK_K = hex("#64595B"), hex("#3F3039")
local function DECK(x, y) if y == 103 and x >= 69 and x % 3 ~= 0 then return DECK_K end return DECK_G end
-- under the left hand (only uncovered when the arm is raised): the deck's back edge, then a key row at y 99
-- continuing the key pair visible at (60-61,99)
local function DECK_L(x, y)
  if (y == 93 and x <= 57) or (y == 94 and x >= 58) then return hex("#120D0E") end
  if y == 99 and x >= 51 and x % 3 ~= 2 then return DECK_K end   -- whole keys only (48-49 is half under the lid)
  return DECK_G
end

-- reset to the 9 face/eyes frames
for i = #spr.tags, 1, -1 do local n = spr.tags[i].name; if n:match("^body:") or n:match("^between:") then spr:deleteTag(spr.tags[i]) end end
while #spr.frames > BASE_FRAMES do spr:deleteFrame(#spr.frames) end

local LAYERS, BY = {}, {}
for _, l in ipairs(spr.layers) do LAYERS[#LAYERS + 1] = l; BY[l.name] = l end
local BASE = {}
for _, l in ipairs(LAYERS) do local im = Image(128, 128, ColorMode.RGB); local c = l:cel(1)
  if c then im:drawImage(c.image, c.position) end; BASE[l.name] = im end
local function comp(imgs) local im = Image(128, 128, ColorMode.RGB)
  for _, l in ipairs(LAYERS) do im:drawImage(imgs[l.name], Point(0, 0)) end; return im end
local COMP1 = comp(BASE)
local LID = {}; for y = 0, 127 do LID[y] = LID_EDGE(BASE.laptop, y) end   -- the lid stays in front of the left hand

BODY_XMIN = 40           -- the body layer also owns a lid outline pixel at (9,83); only her body (x >= 40) breathes
-- the left hair tips rest on the lid's top edge: below HAIR_Y (x <= HAIR_X) the hair stays put and stretches 1 px
HAIR_X, HAIR_Y = 50, 72
-- d = +1 lifts the rows above the limit 1 px (the limit row is doubled), d = -1 drops them 1 px (the row just above
-- the limit is lost), d = 0 copies
local function lift(img, d, xmin, ylim)
  local out = img:clone()
  if d == 0 then return out end
  for x = xmin or 0, 127 do local yl = ylim and ylim(x) or BREATH_Y
    for y = 0, yl - 1 do out:drawPixel(x, y, (y + d >= 0) and img:getPixel(x, y + d) or CLEAR) end end
  return out
end
-- where the lifted hood's right edge meets the static chair outline, close the silhouette outline (layer, x, y, colour)
HEAD_UP_PATCHES = {{"head", 114, 61, "#120D0E"}, {"head", 121, 67, "#120D0E"}}
local function hairY(x) return x <= HAIR_X and HAIR_Y or BREATH_Y end

-- the hands' pixels, read from frame 1's body layer at the round-3 positions in cfg.lua
HAND_PX = {}
for i, h in ipairs(HANDS) do local list = {}
  for r, row in ipairs(h.rows) do for c = 1, #row do if row:sub(c, c) ~= "." then
    local x, y = h.x + c - 1, h.y + r - 1; list[#list + 1] = {x, y, BASE.body:getPixel(x, y)} end end end
  HAND_PX[i] = list
end

local FRONT = {"desk", "laptop", "head", "face", "eyes", "props"}   -- layers drawn over body
local function frameOf(tagName) for _, t in ipairs(spr.tags) do if t.name == tagName then return t.fromFrame.frameNumber end end end
local function layerImg(name, f) local im = Image(128, 128, ColorMode.RGB); local c = BY[name]:cel(f); if c then im:drawImage(c.image, c.position) end; return im end
local CLOSED = layerImg("eyes", frameOf("eyes:closed"))
-- the raised arm (props): the accepted left-hand drawing flipped upright, on a shaded sleeve; nothing is drawn over the lid
local HAND_LG = {K = hex("#120D0E"), S = hex("#F5D4C9"), B = hex("#F4B6AC"), D = hex("#D5A3A2"), R = hex("#B47D83")}
local SLEEVE = {K = hex("#120D0E"), hi = hex("#483942"), mid = hex("#3F3039"), lo = hex("#261A22"), cuff = hex("#372931")}
local function drawArm(a, put)
  for y = a.top, a.bot do local t = (y - a.top) / (a.bot - a.top)
    local xl = math.floor(a.xl[1] + (a.xl[2] - a.xl[1]) * t + 0.5); local xr = math.floor(a.xr[1] + (a.xr[2] - a.xr[1]) * t + 0.5)
    for x = xl, xr do local col
      if x == xl or x == xr or y == a.top or y == a.bot then col = SLEEVE.K
      elseif y <= a.top + 2 then col = SLEEVE.cuff
      elseif y == a.top + 3 then col = SLEEVE.lo
      elseif x <= xl + 2 then col = SLEEVE.hi   -- lit from the top left
      elseif x >= xr - 1 then col = SLEEVE.lo
      else col = SLEEVE.mid end
      put(x, y, col)
    end
  end
  local rows = HANDS[1].rows
  for r = 1, #rows do local row = rows[#rows + 1 - r]
    local c0, c1 = row:find("[^.]"), #row - row:reverse():find("[^.]") + 1
    for c = c0, c1 do put(a.hand[1] + c - 1, a.hand[2] + r - 1, HAND_LG[row:sub(c, c)] or HAND_LG.K) end end   -- fingertip gaps: outline
end
local log = {}
local function pose(p)
  local im = {}
  for _, l in ipairs(LAYERS) do im[l.name] = BASE[l.name]:clone() end
  local c0, h0 = p.c or 0, p.h or 0
  im.body = lift(BASE.body, c0, BODY_XMIN)
  local faceF = p.face and frameOf("face:" .. p.face)
  local src = {head = BASE.head, face = faceF and layerImg("face", faceF) or BASE.face, eyes = faceF and layerImg("eyes", faceF) or BASE.eyes}
  if p.eyes == "closed" then src.eyes = src.eyes:clone(); src.eyes:drawImage(CLOSED, Point(0, 0)) end
  for _, n in ipairs({"head", "face", "eyes"}) do im[n] = lift(src[n], h0, 0, hairY) end
  for i, up in ipairs({p.l or 0, p.r or 0}) do if up == 1 then
    local new = {}
    for _, q in ipairs(HAND_PX[i]) do new[q[2] * 128 + q[1] - 128] = q[3] end
    for _, q in ipairs(HAND_PX[i]) do im.body:drawPixel(q[1], q[2], CLEAR) end
    for k, v in pairs(new) do local x, y = k % 128, k // 128
      im.body:drawPixel(x, y, v)
      for _, n in ipairs(FRONT) do
        if n == "desk" or (n == "laptop" and x > LID[y]) then im[n]:drawPixel(x, y, CLEAR)
        elseif n == "laptop" then -- behind the lid: hidden, nothing to cut
        else assert(pc.rgbaA(im[n]:getPixel(x, y)) == 0, "hand under " .. n .. " at " .. x .. "," .. y) end
      end
    end
    for _, q in ipairs(HAND_PX[i]) do if not new[q[2] * 128 + q[1]] and q[1] > LID[q[2]] then im.laptop:drawPixel(q[1], q[2], DECK(q[1], q[2])) end end
  end end
  if p.arm then   -- the left hand leaves the keys: the deck shows where it was (the lid still covers its own part)
    for _, q in ipairs(HAND_PX[1]) do im.body:drawPixel(q[1], q[2], CLEAR)
      if q[1] > LID[q[2]] then im.laptop:drawPixel(q[1], q[2], DECK_L(q[1], q[2])) end end
  end
  -- FILL: holes the move opened, from the topmost opaque pixel at the source (below for a lift, above for a slump),
  -- on that pixel's own layer, nearest the source first. A hole is a pixel opaque on frame 1, transparent now, whose
  -- source pixel was opaque on frame 1 too; if the source was background, the moved silhouette uncovers background.
  local dir = (c0 ~= 0) and c0 or h0
  local fills = 0
  if dir ~= 0 then
    local sy = dir > 0 and 1 or -1
    local y0, y1, step = 126, 1, -1
    if dir < 0 then y0, y1, step = 1, 126, 1 end
    for y = y0, y1, step do for x = 0, 127 do
      if pc.rgbaA(COMP1:getPixel(x, y)) > 0 and pc.rgbaA(COMP1:getPixel(x, y + sy)) > 0 then
        local any = false
        for _, l in ipairs(LAYERS) do if pc.rgbaA(im[l.name]:getPixel(x, y)) > 0 then any = true break end end
        if not any then
          for i = #LAYERS, 1, -1 do local n = LAYERS[i].name; local v = im[n]:getPixel(x, y + sy)
            if pc.rgbaA(v) > 0 then im[n]:drawPixel(x, y, v); fills = fills + 1; log[#log + 1] = string.format("%s(%d,%d)", n, x, y); break end end
        end
      end
    end end
  end
  if h0 == 1 then for _, q in ipairs(HEAD_UP_PATCHES) do im[q[1]]:drawPixel(q[2], q[3], hex(q[4])) end end
  for _, q in ipairs(p.fx and TYPING_FX[p.fx] or {}) do im.props:drawPixel(q[1], q[2], hex(q[3])) end   -- typing sparks (props layer)
  -- the raised arm (props, over everything but the lid); drawn before ORPHANS so slivers along its edges are cleaned
  if p.arm then drawArm(ARMS[p.arm], function(x, y, v)
    if not (pc.rgbaA(BASE.laptop:getPixel(x, y)) > 0 and x <= LID[y]) then im.props:drawPixel(x, y, v) end end) end
  -- ORPHANS: where body and head move apart (lag frames) single pixels can lose every same-coloured neighbour.
  -- Any orphan that frame 1 doesn't already have (at the same spot or one above or below) takes its neighbours'
  -- majority colour, on the layer that shows it (body or head only: chair, desk and laptop never change).
  -- Hand pixels and the face rect (any key) are never touched.
  local c = comp(im)
  local function orphan(img, x, y) local v = img:getPixel(x, y); if pc.rgbaA(v) == 0 then return false end
    for dy = -1, 1 do for dx = -1, 1 do if (dx ~= 0 or dy ~= 0) and img:getPixel(x + dx, y + dy) == v then return false end end end
    return true end
  local hand = {}
  for i, up in ipairs({p.l or 0, p.r or 0}) do for _, q in ipairs(HAND_PX[i]) do hand[(q[2] - up) * 128 + q[1]] = true end end
  local down = (dir < 0) and 1 or 0   -- a slumped frame's face rect and frame-1 orphans sit 1 px lower
  local function keep(x, y) return hand[y * 128 + x] or (x >= FACE[1] and y >= FACE[2] - 1 and x < FACE[1] + FACE[3] and y < FACE[2] + FACE[4] + down) end
  for y = 1, 126 do for x = 1, 126 do
    if not keep(x, y) and orphan(c, x, y) and not orphan(COMP1, x, y) and not orphan(COMP1, x, y + 1) and not (down == 1 and orphan(COMP1, x, y - 1)) then
      local n, best, bn = {}, nil, 0
      for dy = -1, 1 do for dx = -1, 1 do local v = c:getPixel(x + dx, y + dy)
        if (dx ~= 0 or dy ~= 0) and pc.rgbaA(v) > 0 then n[v] = (n[v] or 0) + 1; if n[v] > bn then best, bn = v, n[v] end end end end
      for i = #LAYERS, 1, -1 do local nm = LAYERS[i].name
        if pc.rgbaA(im[nm]:getPixel(x, y)) > 0 then
          if nm == "body" or nm == "head" then im[nm]:drawPixel(x, y, best); log[#log + 1] = string.format("orphan %s(%d,%d)", nm, x, y) end
          break end end
    end
  end end
  return im, fills
end

local function trimmed(img)
  local r = img:shrinkBounds(); if r.width == 0 then return nil end
  local out = Image(r.width, r.height, ColorMode.RGB); out:drawImage(img, Point(-r.x, -r.y)); return out, Point(r.x, r.y)
end

local KEYS = {face = {{0, FACE[1], FACE[2], FACE[3], FACE[4]}}, eyes = {{0, EYES[1], EYES[2], EYES[3], EYES[4]}},
              emoji = {{0, EMOJI[1], EMOJI[2], EMOJI[3], EMOJI[4]}}}
local faceTags = {}
for _, t in ipairs(spr.tags) do faceTags[#faceTags + 1] = {t, t.fromFrame.frameNumber, t.toFrame.frameNumber} end
local fillReport = {}
app.transaction(function()
  for _, loop in ipairs(BODY_LOOPS) do
    loop.first = #spr.frames + 1
    for k, p in ipairs(loop.frames) do
      local im, fills = pose(p)
      local fr = spr:newEmptyFrame(#spr.frames + 1)
      fr.duration = p.d / 1000
      for _, l in ipairs(LAYERS) do local img, pos = trimmed(im[l.name]); if img then spr:newCel(l, fr, img, pos) end end
      local dy = -(p.h or 0)
      for n, r in pairs({face = FACE, eyes = EYES, emoji = EMOJI}) do
        table.insert(KEYS[n], {fr.frameNumber - 1, r[1], r[2] + dy, r[3], r[4]}) end
      fillReport[#fillReport + 1] = string.format("%s %d: %d fills", loop.tag, k - 1, fills)
    end
    loop.last = #spr.frames
  end
  -- new frames stretch any tag that ended on the last frame (eyes:closed): pin the earlier tags back
  for _, e in ipairs(faceTags) do e[1].fromFrame = spr.frames[e[2]]; e[1].toFrame = spr.frames[e[3]] end
  for _, loop in ipairs(BODY_LOOPS) do
    local t = spr:newTag(loop.first, loop.last); t.name = loop.tag; t.data = loop.data
  end
end)
spr:saveAs(spr.filename)
spr:close()
-- read first: every slice's frame-0 key must parse back as cfg.lua has it before anything is rewritten
local before = SLICE_KEYS(MASTER, {__readonly = true})
for n, r in pairs({face = FACE, eyes = EYES, emoji = EMOJI, paper = PAPER}) do local b = before[n][1]
  assert(b[1] == 0 and b[2] == r[1] and b[3] == r[2] and b[4] == r[3] and b[5] == r[4], "slice " .. n .. " frame-0 key differs from cfg") end
SLICE_KEYS(MASTER, KEYS)
spr = app.open(MASTER)
print("body ok", table.concat(fillReport, " | "))
if BODY_VERBOSE then print("fills: " .. table.concat(log, " ")) end
