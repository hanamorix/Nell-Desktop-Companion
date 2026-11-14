-- Measured checks for the body loops (Task 8). Prints one line per check; asserts the hard rules.
-- Run after body.lua:  dofile([[<repo>/artwork/sprites/scripts/body_check.lua]])
local SCRIPTS_DIR = app.fs.filePath(debug.getinfo(1, "S").source:gsub("^@", ""))
if not EYE_SPEC then dofile(app.fs.joinPath(SCRIPTS_DIR, "cfg.lua")) end
dofile(app.fs.joinPath(SCRIPTS_DIR, "slicekeys.lua"))
local pc = app.pixelColor
local spr = app.activeSprite
if not spr or spr.filename ~= MASTER then spr = app.open(MASTER) end
local OUTLINE = pc.rgba(0x12, 0x0D, 0x0E, 255)
local function comp(f) local im = Image(128, 128, ColorMode.RGB); im:drawSprite(spr, f); return im end
local function tag(n) for _, t in ipairs(spr.tags) do if t.name == n then return t end end end
local function a(v) return pc.rgbaA(v) end
local fails = {}
local function check(ok, msg) if not ok then fails[#fails + 1] = msg end end

-- tags: frames 1-9 keep one-frame face/eyes tags; body tags are ranges after them
print("tags (1-based):")
for _, t in ipairs(spr.tags) do print(string.format("  %-14s %2d-%2d %s", t.name, t.fromFrame.frameNumber, t.toFrame.frameNumber, t.data or "")) end
for _, t in ipairs(spr.tags) do if t.name:match("^face:") or t.name == "eyes:closed" then
  check(t.fromFrame.frameNumber == t.toFrame.frameNumber and t.toFrame.frameNumber <= 9, t.name .. " not a single frame in 1-9") end end

-- slice keys straight from the file (the Lua API only shows one key)
local KEYS = SLICE_KEYS(spr.filename, {__readonly = true})
local function key(name, f)   -- f is 1-based; the key in force is the last one at or before it
  local best; for _, k in ipairs(KEYS[name]) do if k[1] <= f - 1 then best = k end end
  return {best[2], best[3], best[4], best[5]}
end

local F1 = comp(1)
-- frame 1's face rect must be fully opaque, or the pasted face would carry holes
local holesInFace = 0
for y = FACE[2], FACE[2] + FACE[4] - 1 do for x = FACE[1], FACE[1] + FACE[3] - 1 do if a(F1:getPixel(x, y)) == 0 then holesInFace = holesInFace + 1 end end end
print("frame 1 face rect transparent px: " .. holesInFace); check(holesInFace == 0, "face rect has holes")

local OKCOL = {}
for f = 1, 9 do for it in comp(f):pixels() do OKCOL[it()] = true end end
local function edgeBad(im)   -- silhouette pixels (opaque with a transparent 4-neighbour or on the canvas edge) that aren't outline
  local n = 0
  for y = 0, 127 do for x = 0, 127 do local v = im:getPixel(x, y)
    if a(v) > 0 and v ~= OUTLINE then
      for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do local xx, yy = x + d[1], y + d[2]
        if xx < 0 or yy < 0 or xx > 127 or yy > 127 or a(im:getPixel(xx, yy)) == 0 then n = n + 1 break end end
    end end end
  return n
end
local function enclosed(im)   -- transparent pixels not reachable from the canvas border
  local seen, stack, n = {}, {}, 0
  for i = 0, 127 do for _, p in ipairs({{i,0},{i,127},{0,i},{127,i}}) do stack[#stack + 1] = p end end
  while #stack > 0 do local p = table.remove(stack); local x, y = p[1], p[2]; local k = y * 128 + x
    if x >= 0 and y >= 0 and x < 128 and y < 128 and not seen[k] and a(im:getPixel(x, y)) == 0 then seen[k] = true
      stack[#stack + 1] = {x+1,y}; stack[#stack + 1] = {x-1,y}; stack[#stack + 1] = {x,y+1}; stack[#stack + 1] = {x,y-1} end end
  for y = 0, 127 do for x = 0, 127 do if a(im:getPixel(x, y)) == 0 and not seen[y * 128 + x] then n = n + 1 end end end
  return n
end
local edge1, encl1 = edgeBad(F1), enclosed(F1)
print(string.format("frame 1: silhouette px not #120D0E %d, enclosed transparent px %d", edge1, encl1))

-- faces 1-8 cut at the frame-1 face rect, and the closed-eye patch
local FACEIMG = {}
for f = 1, 8 do FACEIMG[f] = comp(f) end
local eyesLayer; for _, l in ipairs(spr.layers) do if l.name == "eyes" then eyesLayer = l end end
local pcel = eyesLayer:cel(tag("eyes:closed").fromFrame.frameNumber)

-- hand pixels the lid hides (at or left of its edge, at either height) are left out: the lid shows there
local lap1 = Image(128, 128, ColorMode.RGB); for _, l in ipairs(spr.layers) do if l.name == "laptop" then lap1:drawImage(l:cel(1).image, l:cel(1).position) end end
local hands, hidden = {}, 0
for i, h in ipairs(HANDS) do local list = {}
  for r, row in ipairs(h.rows) do for c = 1, #row do if row:sub(c, c) ~= "." then local x, y = h.x + c - 1, h.y + r - 1
    if x > LID_EDGE(lap1, y) and x > LID_EDGE(lap1, y - 1) then list[#list + 1] = {x, y, F1:getPixel(x, y)} else hidden = hidden + 1 end end end end
  hands[i] = list end
print("hand px behind the lid (not compared): " .. hidden)
local function handAt(im, i, dy) local bad = 0
  for _, q in ipairs(hands[i]) do if im:getPixel(q[1], q[2] + dy) ~= q[3] then bad = bad + 1 end end; return bad end

local POSE = {}   -- tag name -> {data, frames} from cfg.lua
for _, loop in ipairs(BODY_LOOPS) do POSE[loop.tag] = loop end
local propsLayer; for _, l in ipairs(spr.layers) do if l.name == "props" then propsLayer = l end end
local function faceImg(name, closed)   -- composite of a face frame, optionally with the closed-eye patch
  local im = comp(tag("face:" .. name).fromFrame.frameNumber)
  if closed then im:drawImage(pcel.image, pcel.position) end
  return im
end
print("per frame: duration | face key | enclosed | silhouette not outline | stray colours | partial alpha | hands (L,R dy) | idle-face paste diff (drawn faces: drawn-face diff) | worst face ring seam | closed-eye paste outside eyes key | emoji rect opaque")
for _, t in ipairs(spr.tags) do if t.name:match("^body:") or t.name:match("^between:") then
  local loop = POSE[t.name]; assert(loop and #loop.frames == t.toFrame.frameNumber - t.fromFrame.frameNumber + 1 and loop.data == t.data, "tag " .. t.name .. " differs from cfg")
  local drawn = (t.data or ""):match("face=drawn") ~= nil
  for f = t.fromFrame.frameNumber, t.toFrame.frameNumber do
    local p = loop.frames[f - t.fromFrame.frameNumber + 1]
    local im = comp(f)
    local fk, ek, mk = key("face", f), key("eyes", f), key("emoji", f)
    local dy = fk[2] - FACE[2]
    check(fk[1] == FACE[1] and fk[3] == FACE[3] and fk[4] == FACE[4] and dy == -(p.h or 0), "face key " .. f)
    check(ek[2] - EYES[2] == dy and mk[2] - EMOJI[2] == dy and ek[1] == EYES[1] and mk[1] == EMOJI[1], "eyes/emoji key not following face " .. f)
    local stray, partial = 0, 0
    for it in im:pixels() do local v = it(); if a(v) > 0 and not OKCOL[v] then stray = stray + 1 end; if a(v) > 0 and a(v) < 255 then partial = partial + 1 end end
    -- hands: each must sit exactly at dy 0 or -1
    local hs = {}
    for i = 1, 2 do if i == 1 and p.arm then hs[i] = "arm" elseif handAt(im, i, 0) == 0 then hs[i] = "0" elseif handAt(im, i, -1) == 0 then hs[i] = "-1" else hs[i] = "X" end end
    check(hs[1] ~= "X" and hs[2] ~= "X", "hand not an exact copy on frame " .. f)
    -- seam: paste each face's rect at this frame's face key
    local idleDiff, worstRing = 0, 0
    local props = Image(128, 128, ColorMode.RGB); local pc2 = propsLayer:cel(f); if pc2 then props:drawImage(pc2.image, pc2.position) end
    if drawn then   -- the drawn face must be that face (closed if asked) translated to the key, except under the raised hand
      local want = faceImg(p.face, p.eyes == "closed")
      for y = 0, FACE[4] - 1 do for x = 0, FACE[3] - 1 do
        if a(props:getPixel(fk[1] + x, fk[2] + y)) == 0 and want:getPixel(FACE[1] + x, FACE[2] + y) ~= im:getPixel(fk[1] + x, fk[2] + y) then idleDiff = idleDiff + 1 end end end
    end
    for ff = 1, drawn and 0 or 8 do local ring = 0
      for y = 0, FACE[4] - 1 do for x = 0, FACE[3] - 1 do
        local v = FACEIMG[ff]:getPixel(FACE[1] + x, FACE[2] + y)
        local w = im:getPixel(fk[1] + x, fk[2] + y)
        if v ~= w then
          if ff == 1 then idleDiff = idleDiff + 1 end
          if x == 0 or y == 0 or x == FACE[3] - 1 or y == FACE[4] - 1 then ring = ring + 1 end
        end
      end end
      worstRing = math.max(worstRing, ring)
    end
    -- closed-eye patch at the eyes key: every patch pixel must land inside the eyes key rect and on the face it closes
    local outside = 0
    for it in pcel.image:pixels() do if not drawn and a(it()) > 0 then
      local x, y = it.x + pcel.position.x - EYES[1] + ek[1], it.y + pcel.position.y - EYES[2] + ek[2]
      if x < ek[1] or y < ek[2] or x >= ek[1] + ek[3] or y >= ek[2] + ek[4] then outside = outside + 1 end
      -- the patch replaces eye pixels; the pixel it covers must be the same as frame 1 under the unshifted patch
      if im:getPixel(x, y) ~= F1:getPixel(x - ek[1] + EYES[1], y - ek[2] + EYES[2]) then outside = outside + 1 end
    end end
    local emojiOpaque = 0
    for y = mk[2] - 1, mk[2] + mk[4] do for x = mk[1] - 1, mk[1] + mk[3] do if a(im:getPixel(x, y)) > 0 then emojiOpaque = emojiOpaque + 1 end end end
    local encl, eb = enclosed(im), edgeBad(im)
    print(string.format("  %-12s f%2d %4dms | %2d,%2d | %d | %d | %d | %d | %s,%s | %d | %d | %d | %d",
      t.name, f, math.floor(spr.frames[f].duration * 1000 + 0.5), fk[1], fk[2], encl, eb, stray, partial, hs[1], hs[2], idleDiff, worstRing, outside, emojiOpaque))
    check(encl <= encl1 and eb <= edge1 and stray == 0 and partial == 0, "frame " .. f .. " holes/outline/colour")
    check(idleDiff == 0 and worstRing == 0 and outside == 0 and emojiOpaque == 0, "frame " .. f .. " seam/patch/emoji")
  end
end end

-- statics: chair, desk and laptop composites match frame 1 except where a hand moved or a hole was filled
local function layerImg(n, f) for _, l in ipairs(spr.layers) do if l.name == n then
  local im = Image(128, 128, ColorMode.RGB); local c = l:cel(f); if c then im:drawImage(c.image, c.position) end; return im end end end
for _, n in ipairs({"chair", "desk", "laptop"}) do
  local base, total, list = layerImg(n, 1), 0, {}
  for _, t in ipairs(spr.tags) do if t.name:match("^body:") or t.name:match("^between:") then for f = t.fromFrame.frameNumber, t.toFrame.frameNumber do
    local im = layerImg(n, f)
    for y = 0, 127 do for x = 0, 127 do local u, v = base:getPixel(x, y), im:getPixel(x, y)
      if u ~= v then total = total + 1
        if a(u) > 0 and a(v) > 0 then list[#list + 1] = string.format("f%d(%d,%d)", f, x, y) end end end end
  end end end
  print(string.format("static %-6s px differing from frame 1 (cuts, fills): %d; recoloured visible px: %d %s", n, total, #list, table.concat(list, " ")))
  check(#list == 0, n .. " recoloured")
end

print(#fails == 0 and "ALL CHECKS PASS" or ("FAIL: " .. table.concat(fails, "; ")))
