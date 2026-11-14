-- Review exports for the body loops (Task 8), composited the way the app draws them: the body frame, then (unless the
-- tag's data says face=drawn) a face rect cut from its face frame and pasted at this frame's face slice key, then (when
-- blinking) the eyes:closed patch at the eyes key. Everything at exactly 2x on a transparent background.
-- BROUND (global, default "r3") names the files REV/body-<BROUND>-<gif>.gif and -frames.png (every body frame).
-- BODY_GIFS (global) picks the GIFs; default {"yawning", "typing-to-yawning"}; also "idle", "typing", "idle-blink".
local SCRIPTS_DIR = app.fs.filePath(debug.getinfo(1, "S").source:gsub("^@", ""))
if not EYE_SPEC then dofile(app.fs.joinPath(SCRIPTS_DIR, "cfg.lua")) end
dofile(app.fs.joinPath(SCRIPTS_DIR, "slicekeys.lua"))
local BR = BROUND or "r3"
local pc = app.pixelColor
local spr = app.activeSprite
if not spr or spr.filename ~= MASTER then spr = app.open(MASTER) end
local CLEAR, INK, LIGHT = pc.rgba(0, 0, 0, 0), pc.rgba(0x12, 0x0D, 0x0E, 255), pc.rgba(0xe9, 0xe4, 0xdc, 255)
local function tag(n) for _, t in ipairs(spr.tags) do if t.name == n then return t end end end
local KEYS = SLICE_KEYS(spr.filename, {__readonly = true})
local function key(name, f) local best; for _, k in ipairs(KEYS[name]) do if k[1] <= f - 1 then best = k end end; return best end
local function comp(f) local im = Image(128, 128, ColorMode.RGB); im:drawSprite(spr, f); return im end

local FACES = {}
local function faceImg(name) FACES[name] = FACES[name] or comp(tag("face:" .. name).fromFrame.frameNumber); return FACES[name] end
local function drawnFace(f) for _, t in ipairs(spr.tags) do
  if f >= t.fromFrame.frameNumber and f <= t.toFrame.frameNumber and (t.data or ""):match("face=drawn") then return true end end end
local eyesLayer; for _, l in ipairs(spr.layers) do if l.name == "eyes" then eyesLayer = l end end
local PATCH = eyesLayer:cel(tag("eyes:closed").fromFrame.frameNumber)
local function app_frame(f, closed, faceName)
  local img = comp(f)
  if drawnFace(f) then return img end
  local fk, src = key("face", f), faceImg(faceName or "idle")
  for y = 0, FACE[4] - 1 do for x = 0, FACE[3] - 1 do img:drawPixel(fk[2] + x, fk[3] + y, src:getPixel(FACE[1] + x, FACE[2] + y)) end end
  if closed then local ek = key("eyes", f); img:drawImage(PATCH.image, Point(PATCH.position.x - EYES[1] + ek[2], PATCH.position.y - EYES[2] + ek[3])) end
  return img
end
local function scaled(img, k, bg, out, ox, oy)
  for y = 0, img.height * k - 1 do for x = 0, img.width * k - 1 do
    local v = img:getPixel(x // k, y // k); out:drawPixel(ox + x, oy + y, pc.rgbaA(v) > 0 and v or bg) end end
end
local function frames(tagName) local t = tag(tagName); local list = {}
  for f = t.fromFrame.frameNumber, t.toFrame.frameNumber do list[#list + 1] = f end; return list end

-- frames = { {img128, seconds}, ... } -> 2x GIF with an exact palette; index 0 is the transparent background
local function gif(list, path)
  local gs = Sprite(256, 256, ColorMode.RGB)
  local seen, cols = {}, {}
  for i, f in ipairs(list) do
    local fr = i == 1 and gs.frames[1] or gs:newEmptyFrame(i)
    local big = Image(256, 256, ColorMode.RGB); scaled(f[1], 2, CLEAR, big, 0, 0)
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

local WANT = {}; for _, n in ipairs(BODY_GIFS or {"yawning", "typing-to-yawning"}) do WANT[n] = true end
local function loopGif(name, tagName, faceName, times)
  if not WANT[name] then return end
  local list = {}
  for _ = 1, times or 1 do for _, f in ipairs(frames(tagName)) do list[#list + 1] = {app_frame(f, false, faceName), spr.frames[f].duration} end end
  gif(list, REV .. "body-" .. BR .. "-" .. name .. ".gif")
end
loopGif("idle", "body:idle")
loopGif("typing", "body:typing")
loopGif("yawning", "body:yawning", nil, 3)

-- idle with one blink: three idle loops (six breaths); the blink (120 ms, as the Animator) splits the second loop's
-- first breath-in hold (head up, so the closed patch is drawn at the moved eyes key)
if WANT["idle-blink"] then local list, idle = {}, frames("body:idle")
  for loop = 1, 3 do for i, f in ipairs(idle) do local d = spr.frames[f].duration
    if loop == 2 and i == 3 then
      local open = (d - 0.12) / 2
      list[#list + 1] = {app_frame(f, false), open}; list[#list + 1] = {app_frame(f, true), 0.12}; list[#list + 1] = {app_frame(f, false), open}
    else list[#list + 1] = {app_frame(f, false), d} end
  end end
  gif(list, REV .. "body-" .. BR .. "-idle-blink.gif")
end

-- typing (intent face, as the app shows it) twice, then at its resting frame 0 the in-between, two yawns, and back:
-- the yawning loop ends on its resting frame 0, the return in-between, then typing again
if WANT["typing-to-yawning"] then local list = {}
  local function add(tagName, faceName, n, upto) local fs = frames(tagName)
    for _ = 1, n do for i, f in ipairs(fs) do if not upto or i <= upto then list[#list + 1] = {app_frame(f, false, faceName), spr.frames[f].duration} end end end end
  add("body:typing", "intent", 2); add("body:typing", "intent", 1, 1)
  add("between:typing-yawning", nil, 1)
  add("body:yawning", nil, 2); add("body:yawning", nil, 1, 1)
  add("between:yawning-typing", nil, 1)
  add("body:typing", "intent", 2)
  gif(list, REV .. "body-" .. BR .. "-typing-to-yawning.gif")
end

-- contact sheet: one row per loop half (4 frames), each cell 2x with a label: loop, offset, parts moved, duration
local G = {
 ["0"]={"###","#.#","#.#","#.#","###"}, ["1"]={".#.","##.",".#.",".#.","###"}, ["2"]={"##.","..#",".#.","#..","###"},
 ["3"]={"##.","..#",".#.","..#","##."}, ["4"]={"#.#","#.#","###","..#","..#"}, ["5"]={"###","#..","##.","..#","##."},
 ["6"]={".##","#..","###","#.#","###"}, ["7"]={"###","..#",".#.",".#.",".#."}, ["8"]={"###","#.#","###","#.#","###"},
 ["9"]={"###","#.#","###","..#","##."},
 C={".##","#..","#..","#..",".##"}, D={"##.","#.#","#.#","#.#","##."}, E={"###","#..","##.","#..","###"},
 G={".##","#..","#.#","#.#",".##"}, H={"#.#","#.#","###","#.#","#.#"}, I={"###",".#.",".#.",".#.","###"},
 L={"#..","#..","#..","#..","###"}, M={"#...#","##.##","#.#.#","#...#","#...#"}, N={"#..#","##.#","#.##","#..#","#..#"},
 P={"##.","#.#","##.","#..","#.."}, R={"##.","#.#","##.","#.#","#.#"}, S={".##","#..",".#.","..#","##."},
 T={"###",".#.",".#.",".#.",".#."}, Y={"#.#","#.#",".#.",".#.",".#."}, [" "]={"..",".."}, ["+"]={"...",".#.","###",".#.","..."},
 A={".#.","#.#","###","#.#","#.#"}, O={".#.","#.#","#.#","#.#",".#."}, U={"#.#","#.#","#.#","#.#","###"},
 W={"#...#","#...#","#.#.#","##.##","#...#"}, ["-"]={"...","...","###","...","..."}, [">"]={"#..",".#.","..#",".#.","#.."},
}
local function text(out, s, x, y, k, col)
  for ch in s:gmatch(".") do local g = G[ch] or G[" "]
    for r, row in ipairs(g) do for c = 1, #row do if row:sub(c, c) == "#" then
      for yy = 0, k - 1 do for xx = 0, k - 1 do out:drawPixel(x + (c - 1) * k + xx, y + (r - 1) * k + yy, col) end end end end end
    x = x + (#g[1] + 1) * k
  end
end
do
  local cells = {}
  local SHORT = {["body:idle"] = "IDLE", ["body:typing"] = "TYPING", ["body:yawning"] = "YAWN",
                 ["between:typing-yawning"] = "T>Y", ["between:yawning-typing"] = "Y>T"}
  local function sgn(v, s) if (v or 0) > 0 then return s .. "+" elseif (v or 0) < 0 then return s .. "-" end end
  for _, loop in ipairs(BODY_LOOPS) do local t = tag(loop.tag)
    local rest = {}; for n in (loop.data:match("rest=([%d,]+)") or ""):gmatch("%d+") do rest[tonumber(n)] = true end
    for k, p in ipairs(loop.frames) do local f = t.fromFrame.frameNumber + k - 1
      local parts = {}
      local cand = {rest[k - 1] and "REST" or false, sgn(p.c, "C") or false, sgn(p.h, "H") or false, p.l == 1 and "L" or false,
                    p.r == 1 and "R" or false, p.arm and p.arm:upper() or false, p.eyes == "closed" and "SHUT" or false}
      for i = 1, #cand do if cand[i] then parts[#parts + 1] = cand[i] end end
      cells[#cells + 1] = {f, string.format("%s %d %s %dMS", SHORT[loop.tag] or loop.tag:upper(), k - 1, table.concat(parts, " "), math.floor(spr.frames[f].duration * 1000 + 0.5))}
    end
  end
  local GUT, LAB, COLS = 8, 16, 4
  local rows = (#cells + COLS - 1) // COLS
  local out = Image(COLS * 256 + (COLS + 1) * GUT, rows * (256 + LAB) + (rows + 1) * GUT, ColorMode.RGB); out:clear(CLEAR)
  for i, c in ipairs(cells) do
    local cx, cy = GUT + ((i - 1) % COLS) * (256 + GUT), GUT + ((i - 1) // COLS) * (256 + LAB + GUT)
    for dy = -1, 1 do for dx = -1, 1 do text(out, c[2], cx + 2 + 2 * dx, cy + 2 + 2 * dy, 2, INK) end end   -- outlined label
    text(out, c[2], cx + 2, cy + 2, 2, LIGHT)
    scaled(app_frame(c[1], false), 2, CLEAR, out, cx, cy + LAB)
  end
  local s = Sprite(out.width, out.height, ColorMode.RGB); s.cels[1].image = out; s:saveAs(REV .. "body-" .. BR .. "-frames.png"); s:close()
end
print("body export ok")
