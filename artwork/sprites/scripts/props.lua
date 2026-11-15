-- Paper stacks and emoji icons (Task 9): appends one frame per item after the last body/between frame, so frames and
-- tags before it keep their indices. Each item is drawn on the props layer at its slice rect (PAPER, EMOJI in cfg.lua)
-- and nothing else has a cel on these frames. One-frame tags: paper:1..paper:5, then emoji:<name> in priority order.
-- Slice keys: the paper slice's single key is set to PAPER (rounds 2 and 3 moved it); the emoji keys are not touched. On these
-- frames the keys in force are PAPER and emoji (28,14), asserted below.
-- Safe to re-run: paper:* / emoji:* tags and every frame after the last other tag are rebuilt.
local SCRIPTS_DIR = app.fs.filePath(debug.getinfo(1, "S").source:gsub("^@", ""))
if not EYE_SPEC then dofile(app.fs.joinPath(SCRIPTS_DIR, "cfg.lua")) end
dofile(app.fs.joinPath(SCRIPTS_DIR, "slicekeys.lua"))
local pc = app.pixelColor
-- open fresh from disk: a save from an in-memory sprite that predates a slicekeys.lua patch drops the per-frame keys
for _, s in ipairs(app.sprites) do if s.filename == MASTER then s:close() end end
local spr = app.open(MASTER)
local ORDER = {}; for i, s in ipairs(spr.slices) do ORDER[i] = s.name end
local function hex(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local INK = {}; for k, v in pairs(PROP_INK) do INK[k] = hex(v) end
local function rows(img, x, y, rs)
  for r, row in ipairs(rs) do for c = 1, #row do local ch = row:sub(c, c)
    if ch == "_" then img:drawPixel(x + c - 1, y + r - 1, pc.rgba(0, 0, 0, 0))
    elseif ch ~= "." then img:drawPixel(x + c - 1, y + r - 1, assert(INK[ch], "no ink " .. ch)) end end end
end

-- paper:k as a PAPER-sized image: the first k bundles of PAPER_TOWER (cfg.lua)
function PAPER_IMAGE(k)
  local img, b, y = Image(PAPER[3], PAPER[4], ColorMode.RGB), PAPER_TOWER, PAPER_BASE
  local function row(a, z, mid, edge) local t = {}
    for x = 0, PAPER[3] - 1 do t[#t + 1] = (x == a or x == z) and "K" or (x > a and x < z - 1) and mid or x == z - 1 and edge or "." end
    rows(img, 0, y, {table.concat(t)}) end
  rows(img, b[1][1] + 1, y + 1, {string.rep("H", b[1][2] - b[1][1])})   -- desk shadow
  rows(img, b[1][1], y, {string.rep("K", b[1][2] - b[1][1] + 1)})       -- base
  local tops = {}
  for i = 1, k do for j = #PAPER_PAGES, 1, -1 do y = y - 1; row(b[i][1], b[i][2], PAPER_PAGES[j], "A") end; tops[i] = y end
  local t = b[k]
  y = y - 1; row(t[1], t[2], "C", "C"); y = y - 1; row(t[1], t[2], "W", "W")   -- top face, snow back edge
  rows(img, t[1] + 1, y - 1, {string.rep("K", t[2] - t[1] - 1)})
  for i = 1, k do local e = b[i].extra; if e then rows(img, b[i][1] + e[1], tops[i] + e[2], e[3]) end end
  if k >= PAPER_DOGEAR.from then rows(img, t[2] - #PAPER_DOGEAR.rows[1] + 1, y - 1, PAPER_DOGEAR.rows) end
  return img
end
function EMOJI_IMAGE(e)
  assert(#e.rows == EMOJI[4], e.name .. ": rows")
  for _, r in ipairs(e.rows) do assert(#r == EMOJI[3], e.name .. ": row width") end
  local img = Image(EMOJI[3], EMOJI[4], ColorMode.RGB); rows(img, 0, 0, e.rows); return img
end

local ITEMS = {}
for i = 1, #PAPER_TOWER do ITEMS[#ITEMS + 1] = {tag = "paper:" .. i, img = PAPER_IMAGE(i), at = PAPER} end
for _, e in ipairs(EMOJI_ART) do ITEMS[#ITEMS + 1] = {tag = "emoji:" .. e.name, img = EMOJI_IMAGE(e), at = EMOJI} end

local props; for _, l in ipairs(spr.layers) do if l.name == "props" then props = l end end
local base
app.transaction(function()
  for i = #spr.tags, 1, -1 do local n = spr.tags[i].name; if n:match("^paper:") or n:match("^emoji:") then spr:deleteTag(spr.tags[i]) end end
  local keep = {}; base = 0
  for _, t in ipairs(spr.tags) do base = math.max(base, t.toFrame.frameNumber); keep[#keep + 1] = {t, t.fromFrame.frameNumber, t.toFrame.frameNumber} end
  while #spr.frames > base do spr:deleteFrame(#spr.frames) end
  -- the paper slice has a single key (frame 0); setting bounds rewrites exactly that key
  for _, sl in ipairs(spr.slices) do if sl.name == "paper" then sl.bounds = Rectangle(PAPER[1], PAPER[2], PAPER[3], PAPER[4]) end end
  for _, it in ipairs(ITEMS) do
    local fr = spr:newEmptyFrame(#spr.frames + 1); fr.duration = 0.1
    spr:newCel(props, fr, it.img, Point(it.at[1], it.at[2])); it.frame = fr.frameNumber
  end
  -- new frames stretch any tag that ended on the last frame (between:sleeping-idle): pin the earlier tags back
  for _, e in ipairs(keep) do e[1].fromFrame = spr.frames[e[2]]; e[1].toFrame = spr.frames[e[3]] end
  for _, it in ipairs(ITEMS) do local t = spr:newTag(it.frame, it.frame); t.name = it.tag end
end)
spr:saveAs(spr.filename); spr:close(); spr = app.open(MASTER)
local function sameOrder() for i, s in ipairs(spr.slices) do if s.name ~= ORDER[i] then return false end end return true end
-- an open+save reverses the slice order in the file (keys are kept); one more round trip restores the order
if not sameOrder() then spr:saveAs(spr.filename); spr:close(); spr = app.open(MASTER) end
assert(sameOrder(), "slice order changed")
-- the keys in force on the new frames must be the cfg rects the art was drawn at
local K = SLICE_KEYS(MASTER, {__readonly = true})
for _, it in ipairs(ITEMS) do local n = it.at == PAPER and "paper" or "emoji"; local best
  for _, k in ipairs(K[n]) do if k[1] <= it.frame - 1 then best = k end end
  assert(best[2] == it.at[1] and best[3] == it.at[2] and best[4] == it.at[3] and best[5] == it.at[4], it.tag .. ": slice key in force differs")
end
-- checks against every earlier frame, as the app draws them (items over the whole body frame)
local function owner(f, x, y) local o
  for _, l in ipairs(spr.layers) do local c = l:cel(f)
    if c then local cx, cy = x - c.position.x, y - c.position.y
      if cx >= 0 and cy >= 0 and cx < c.image.width and cy < c.image.height and pc.rgbaA(c.image:getPixel(cx, cy)) > 0 then o = l.name end end end
  return o end
local function keyAt(n, f) local best; for _, k in ipairs(K[n]) do if k[1] <= f - 1 then best = k end end; return best end
local function inR(x, y, r, m) return x >= r[2] - m and y >= r[3] - m and x < r[2] + r[4] + m and y < r[3] + r[5] + m end
-- paper is on the desk in front of her, so it may cover hoodie, hair, sleeves and chair, but never: the face and emoji
-- rects at the frame's keys (emoji with a 1 px margin), the typing hands (with their 1 px lift), the laptop, the z
-- (with its 1 px plate) or the typing sparks. Emoji may cover nothing of hers (body, head, face, eyes, props).
local NOPE = {}
for _, h in ipairs(HANDS) do NOPE[#NOPE + 1] = {0, h.x, h.y - 1, #h.rows[1], #h.rows + 1} end
for _, z in pairs(ZZ) do NOPE[#NOPE + 1] = {0, z.x - 1, z.y - 1, #z.rows[1] + 2, #z.rows + 2} end
for _, fx in pairs(TYPING_FX) do for _, q in ipairs(fx) do NOPE[#NOPE + 1] = {0, q[1], q[2], 1, 1} end end
local SHE = {body = true, head = true, face = true, eyes = true, props = true}
local POSES = {}; for _, n in ipairs({"body:idle", "body:typing", "body:yawning", "body:sleeping"}) do
  for _, t in ipairs(spr.tags) do if t.name == n then POSES[t.fromFrame.frameNumber] = n:sub(6) end end end
PROP_CHECK, PAPER_OVER = {}, {}
for _, it in ipairs(ITEMS) do local bad, paper = 0, it.at == PAPER; local most = {}
  for f = 1, base do local at, fk, ek, over = keyAt(paper and "paper" or "emoji", f), keyAt("face", f), keyAt("emoji", f), {}
    for y = 0, it.img.height - 1 do for x = 0, it.img.width - 1 do if pc.rgbaA(it.img:getPixel(x, y)) > 0 then
      local X, Y = at[2] + x, at[3] + y; local o = owner(f, X, Y)
      if paper then
        local no = o == "laptop" or inR(X, Y, fk, 0) or inR(X, Y, ek, 1)
        for _, r in ipairs(NOPE) do no = no or inR(X, Y, r, 0) end
        if no then bad = bad + 1 elseif o and o ~= "desk" then over[o] = (over[o] or 0) + 1 end
      elseif SHE[o] then bad = bad + 1 end end end end
    for n, v in pairs(over) do most[n] = math.max(most[n] or 0, v) end
    if paper and POSES[f] then local l = {}; for _, n in ipairs({"body", "head", "props", "chair"}) do l[#l + 1] = n .. " " .. (over[n] or 0) end
      PAPER_OVER[#PAPER_OVER + 1] = string.format("%s %-8s %s", it.tag, POSES[f], table.concat(l, ", ")) end
  end
  if paper then local l = {}; for _, n in ipairs({"body", "head", "face", "eyes", "props", "chair"}) do l[#l + 1] = n .. " " .. (most[n] or 0) end
    PAPER_OVER[#PAPER_OVER + 1] = string.format("%s %-8s %s", it.tag, "max", table.concat(l, ", ")) end
  PROP_CHECK[#PROP_CHECK + 1] = string.format("%s forbidden=%d", it.tag, bad)
  assert(bad == 0, it.tag .. " covers something it must not on some frame")
end
local desk; for _, l in ipairs(spr.layers) do if l.name == "desk" then desk = l:cel(1) end end
for i, it in ipairs(ITEMS) do if it.at == PAPER then
  for y = PAPER_BASE, PAPER_BASE + 1 do for x = 0, PAPER[3] - 1 do if pc.rgbaA(it.img:getPixel(x, y)) > 0 then
    assert(pc.rgbaA(desk.image:getPixel(PAPER[1] + x - desk.position.x, PAPER[2] + y - desk.position.y)) > 0, it.tag .. " base off the desk") end end end end end
if PROPS_VERBOSE then print(table.concat(PAPER_OVER, "\n")) end
print(table.concat(PROP_CHECK, " | "))
print(string.format("props ok: %d frames (%d-%d, 1-based)", #ITEMS, ITEMS[1].frame, ITEMS[#ITEMS].frame))
