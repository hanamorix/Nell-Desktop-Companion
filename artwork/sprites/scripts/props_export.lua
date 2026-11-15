-- Review exports for the paper stacks and emoji (Task 9), composited the way the app draws them: the body frame, then
-- the paper stack at the frame's paper slice key, then the emoji at its emoji key. Transparent backgrounds, no smoothing.
-- PROPS_EXPORTS (global) maps each export to its review round, written as REV/props-<round>-<name>. Default: the
-- accepted round-3 paper ("paper", "paper-grow") and the round-4 emoji sheet ("emoji"); also "emoji-pop".
local SCRIPTS_DIR = app.fs.filePath(debug.getinfo(1, "S").source:gsub("^@", ""))
if not EYE_SPEC then dofile(app.fs.joinPath(SCRIPTS_DIR, "cfg.lua")) end
dofile(app.fs.joinPath(SCRIPTS_DIR, "slicekeys.lua"))
local WANT = PROPS_EXPORTS or {paper = "r3", ["paper-grow"] = "r3", emoji = "r4"}
local pc = app.pixelColor
local spr = app.activeSprite
if not spr or spr.filename ~= MASTER then spr = app.open(MASTER) end
local CLEAR = pc.rgba(0, 0, 0, 0)
local function tag(n) for _, t in ipairs(spr.tags) do if t.name == n then return t end end end
local KEYS = SLICE_KEYS(spr.filename, {__readonly = true})
local function key(name, f) local best; for _, k in ipairs(KEYS[name]) do if k[1] <= f - 1 then best = k end end; return best end
local function comp(f) local im = Image(128, 128, ColorMode.RGB); im:drawSprite(spr, f); return im end
-- an item's art, cut from its frame at the slice rect it was drawn at
local function item(n, r) local im, out = comp(tag(n).fromFrame.frameNumber), Image(r[3], r[4], ColorMode.RGB)
  out:drawImage(im, Point(-r[1], -r[2])); return out end
local function scaled(img, k, out, ox, oy)
  for y = 0, img.height * k - 1 do for x = 0, img.width * k - 1 do
    local v = img:getPixel(x // k, y // k); if pc.rgbaA(v) > 0 then out:drawPixel(ox + x, oy + y, v) end end end
end
-- body frame f with an optional face pasted at its face key (as the app does), then an optional paper stack and an
-- optional emoji (dy: whole-pixel pop offset)
local FACES = {}
local function scene(f, paper, emoji, dy, face)
  local im = comp(f)
  if face then FACES[face] = FACES[face] or comp(tag("face:" .. face).fromFrame.frameNumber)
    local k = key("face", f); local src = FACES[face]
    for y = 0, FACE[4] - 1 do for x = 0, FACE[3] - 1 do im:drawPixel(k[2] + x, k[3] + y, src:getPixel(FACE[1] + x, FACE[2] + y)) end end end
  if paper then local k = key("paper", f); im:drawImage(paper, Point(k[2], k[3])) end
  if emoji then local k = key("emoji", f); im:drawImage(emoji, Point(k[2], k[3] + (dy or 0))) end
  return im
end
local IDLE, TYPING, SLEEP = tag("body:idle").fromFrame.frameNumber, tag("body:typing").fromFrame.frameNumber,
  tag("body:sleeping").fromFrame.frameNumber   -- resting frames (offset 0)
local GAP = 16

-- paper: stacks 1-5 at 4x, then each on the idle, typing and sleeping resting frames at 2x
local PAPERS = {}; for i = 1, #PAPER_TOWER do PAPERS[i] = item("paper:" .. i, PAPER) end
if WANT.paper then local rests = {IDLE, TYPING, SLEEP}
  local out = Image(5 * 256 + 4 * GAP, PAPER[4] * 4 + GAP + #rests * (256 + GAP) - GAP, ColorMode.RGB)
  for i, p in ipairs(PAPERS) do local x = (i - 1) * (256 + GAP)
    scaled(p, 4, out, x + (256 - PAPER[3] * 4) // 2, 0)
    for r, f in ipairs(rests) do scaled(scene(f, p), 2, out, x, PAPER[4] * 4 + GAP + (r - 1) * (256 + GAP)) end end
  out:saveAs(REV .. "props-" .. WANT.paper .. "-paper.png")
end
-- emoji: all seven at 4x in priority order, then each beside her on the idle resting frame at 2x, and plug while asleep
local EM = {}; for _, e in ipairs(EMOJI_ART) do EM[e.name] = item("emoji:" .. e.name, EMOJI) end
if WANT.emoji then local out = Image(4 * 256 + 3 * GAP, 64 + GAP + 2 * (256 + GAP) - GAP, ColorMode.RGB)
  local GRID = pc.rgba(0xC4, 0xA9, 0xAB, 255)   -- a faint 16x16 pixel grid behind each icon, so the sizes compare
  for i, e in ipairs(EMOJI_ART) do local x0 = (i - 1) * (64 + GAP)
    for a = 0, 63 do for b = 0, 63 do if a % 4 == 0 or a == 63 or b % 4 == 0 or b == 63 then out:drawPixel(x0 + a, b, GRID) end end end
    scaled(EM[e.name], 4, out, x0, 0) end
  local cells = {}; for _, e in ipairs(EMOJI_ART) do cells[#cells + 1] = scene(IDLE, nil, EM[e.name]) end
  cells[#cells + 1] = scene(SLEEP, nil, EM.plug)
  for i, c in ipairs(cells) do scaled(c, 2, out, ((i - 1) % 4) * (256 + GAP), 64 + GAP + ((i - 1) // 4) * (256 + GAP)) end
  out:saveAs(REV .. "props-" .. WANT.emoji .. "-emoji.png")
end

-- frames = { {img128, seconds}, ... } -> 2x GIF with an exact palette; index 0 is the transparent background
-- (the same writer as body_export.lua)
local function gif(list, path)
  local gs = Sprite(256, 256, ColorMode.RGB)
  local seen, cols = {}, {}
  for i, f in ipairs(list) do
    local fr = i == 1 and gs.frames[1] or gs:newEmptyFrame(i)
    local big = Image(256, 256, ColorMode.RGB); scaled(f[1], 2, big, 0, 0)
    if i == 1 then gs.cels[1].image = big else gs:newCel(gs.layers[1], fr, big, Point(0, 0)) end
    fr.duration = f[2]
    for it in f[1]:pixels() do local v = it(); if pc.rgbaA(v) > 0 and not seen[v] then seen[v] = true; cols[#cols + 1] = v end end
  end
  local gp = Palette(#cols + 1); gp:setColor(0, Color{r = 255, g = 0, b = 255, a = 0})
  for i, v in ipairs(cols) do gp:setColor(i, Color{r = pc.rgbaR(v), g = pc.rgbaG(v), b = pc.rgbaB(v)}) end
  gs:setPalette(gp)
  app.command.ChangePixelFormat{ format = "indexed", dithering = "none" }
  gs.transparentColor = 0
  gs:saveAs(path); gs:close()
end
-- ev = { {from ms, to ms, paper level or nil, emoji name or nil, emoji dy}, ... } covering 0..T: a body loop (default
-- body:idle; face pasted when given) runs on underneath, so GIF frames are cut at every loop frame change and event boundary
local function idleGif(ev, T, path, loopTag, face)
  local idle, loopMs, starts = tag(loopTag or "body:idle"), 0, {}
  for f = idle.fromFrame.frameNumber, idle.toFrame.frameNumber do
    starts[#starts + 1] = {loopMs, f}; loopMs = loopMs + math.floor(spr.frames[f].duration * 1000 + 0.5) end
  local cuts = {}
  for _, e in ipairs(ev) do cuts[e[1]] = true end
  for base = 0, T, loopMs do for _, s in ipairs(starts) do if base + s[1] < T then cuts[base + s[1]] = true end end end
  local ts = {}; for c in pairs(cuts) do ts[#ts + 1] = c end; table.sort(ts)
  local list = {}
  for i, c in ipairs(ts) do local to = ts[i + 1] or T
    local f; for _, s in ipairs(starts) do if s[1] <= c % loopMs then f = s[2] end end
    local e; for _, x in ipairs(ev) do if c >= x[1] and c < x[2] then e = x end end
    list[#list + 1] = {scene(f, e[3] and PAPERS[e[3]], e[4] and EM[e[4]], e[5], face), (to - c) / 1000}
  end
  gif(list, path)
  return #list
end
-- pop GIF: each brief emoji pops in (one 80 ms frame 1 px low), holds, pops out (one 80 ms frame 1 px high), then 1 s
-- with none. The pop itself is app code (Task 10); this only previews a subtle one.
if WANT["emoji-pop"] then
  local POP, SHOW, NONE = 80, 2500, 1000
  local ev, t = {}, 0
  for _, n in ipairs({"heart", "thumbsup", "crying"}) do
    ev[#ev + 1] = {t, t + NONE}; t = t + NONE
    ev[#ev + 1] = {t, t + POP, nil, n, 1}; ev[#ev + 1] = {t + POP, t + SHOW, nil, n, 0}; ev[#ev + 1] = {t + SHOW, t + SHOW + POP, nil, n, -1}
    t = t + SHOW + POP
  end
  print(string.format("props_export: pop gif %d frames, %.2f s", idleGif(ev, t, REV .. "props-" .. WANT["emoji-pop"] .. "-emoji-pop.gif"), t / 1000))
end
-- grow GIF: typing (intent face, as the app shows it) with an empty desk for 1 s, then paper:1 .. paper:5, about 1 s each
-- (cut on the typing loop's 167 ms frames); the app resets to none on /clear or compaction
if WANT["paper-grow"] then
  local STEP = 1002   -- 6 typing frames of 167 ms, so every step starts on a frame boundary
  local ev = {{0, STEP}}; for i = 1, #PAPERS do ev[#ev + 1] = {i * STEP, (i + 1) * STEP, i} end
  local T = (#PAPERS + 1) * STEP
  print(string.format("props_export: grow gif %d frames, %.2f s", idleGif(ev, T, REV .. "props-" .. WANT["paper-grow"] .. "-paper-grow.gif", "body:typing", "intent"), T / 1000))
end
