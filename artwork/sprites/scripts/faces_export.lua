-- Review exports for the faces (Task 7), composited the way the app draws them:
-- idle body (frame 1), then the face rectangle cut from the face's frame, then (when closed) the eyes:closed patch.
-- Writes REV/faces-<FROUND>-sheet-{light,dark}.png (2x, labelled) and REV/faces-<FROUND>-blinkswap.gif (2x on dark).
-- Also REV/faces-<FROUND>-<CLOSEUP>-closeup.png (the face rectangle at 4x, light and dark side by side).
-- Optional global PREVIEW: also save a 128 px .aseprite with each face open and closed, for close inspection.
if not EYE_SPEC then dofile(app.fs.joinPath(app.fs.filePath(debug.getinfo(1, "S").source:gsub("^@", "")), "cfg.lua")) end
local FR = FROUND or "r4"
local CLOSE = CLOSEUP or "sad"   -- one face alone at 4x, light | dark: REV/faces-<FROUND>-<CLOSEUP>-closeup.png
local pc = app.pixelColor
local spr = app.activeSprite
if not spr or spr.filename ~= MASTER then spr = app.open(MASTER) end
local function tagFrame(n) for _, t in ipairs(spr.tags) do if t.name == n then return t.fromFrame.frameNumber end end end
local function layer(n) for _, l in ipairs(spr.layers) do if l.name == n then return l end end end

local BODY = Image(128, 128, ColorMode.RGB); BODY:drawSprite(spr, 1)
local pcel = layer("eyes"):cel(tagFrame("eyes:closed"))
local function face(name, closed)
  local f = tagFrame("face:" .. name)
  local full = Image(128, 128, ColorMode.RGB); full:drawSprite(spr, f)
  local img = BODY:clone()
  for y = FACE[2], FACE[2] + FACE[4] - 1 do for x = FACE[1], FACE[1] + FACE[3] - 1 do img:drawPixel(x, y, full:getPixel(x, y)) end end
  if closed then img:drawImage(pcel.image, pcel.position) end
  return img
end
local function scaled(img, k, bg, out, ox, oy)
  for y = 0, img.height * k - 1 do for x = 0, img.width * k - 1 do
    local v = img:getPixel(x // k, y // k); out:drawPixel(ox + x, oy + y, pc.rgbaA(v) > 0 and v or bg) end end
end
local function save(img, path) local s = Sprite(img.width, img.height, ColorMode.RGB); s.cels[1].image = img; s:saveAs(path); s:close() end

-- 3x5 pixel font for the labels
local G = {
 A={".#.","#.#","###","#.#","#.#"}, C={".##","#..","#..","#..",".##"}, D={"##.","#.#","#.#","#.#","##."}, E={"###","#..","##.","#..","###"},
 F={"###","#..","##.","#..","#.."}, H={"#.#","#.#","###","#.#","#.#"}, I={"###",".#.",".#.",".#.","###"}, L={"#..","#..","#..","#..","###"}, M={"#...#","##.##","#.#.#","#...#","#...#"},
 N={"#..#","##.#","#.##","#..#","#..#"}, O={".#.","#.#","#.#","#.#",".#."}, P={"##.","#.#","##.","#..","#.."}, R={"##.","#.#","##.","#.#","#.#"},
 S={".##","#..",".#.","..#","##."}, T={"###",".#.",".#.",".#.",".#."}, U={"#.#","#.#","#.#","#.#","###"}, W={"#...#","#...#","#.#.#","##.##","#...#"},
 X={"#.#","#.#",".#.","#.#","#.#"}, Y={"#.#","#.#",".#.",".#.",".#."}, [":"]={".","#",".","#","."}, [" "]={"..",".."}, ["("]={".#","#.","#.","#.",".#"}, [")"]={"#.",".#",".#",".#","#."},
}
local function text(out, s, x, y, k, col)
  for ch in s:gmatch(".") do local g = G[ch] or G[" "]
    for r, row in ipairs(g) do for c = 1, #row do if row:sub(c, c) == "#" then
      for yy = 0, k - 1 do for xx = 0, k - 1 do out:drawPixel(x + (c - 1) * k + xx, y + (r - 1) * k + yy, col) end end end end end
    x = x + (#g[1] + 1) * k
  end
end

local CELLS = {{"idle"}, {"intent"}, {"exhausted"}, {"happy"}, {"smile"}, {"sad"}, {"scared"}, {"awe"}, {"idle", true, "EYES:CLOSED (ON IDLE)"}}
local GUT, LAB = 8, 16
local W, H = 3 * 256 + 4 * GUT, 3 * (256 + LAB) + 4 * GUT
for name, th in pairs({light = {pc.rgba(0xe9,0xe4,0xdc,255), pc.rgba(0x2b,0x30,0x44,255)}, dark = {pc.rgba(0x2b,0x30,0x44,255), pc.rgba(0xe9,0xe4,0xdc,255)}}) do
  local out = Image(W, H, ColorMode.RGB); out:clear(th[1])
  for i, c in ipairs(CELLS) do
    local cx, cy = GUT + ((i - 1) % 3) * (256 + GUT), GUT + ((i - 1) // 3) * (256 + LAB + GUT)
    text(out, c[3] or ("FACE:" .. c[1]:upper()), cx, cy + 2, 2, th[2])
    scaled(face(c[1], c[2]), 2, th[1], out, cx, cy + LAB)
  end
  save(out, REV .. "faces-" .. FR .. "-sheet-" .. name .. ".png")
end

-- closeup: the face rectangle of one face at 4x, light then dark
do
  local k, g = 4, 8
  local cw, ch = FACE[3] * k, FACE[4] * k
  local out = Image(2 * cw + 3 * g, ch + 2 * g, ColorMode.RGB); out:clear(pc.rgba(0x80, 0x80, 0x80, 255))
  local img = face(CLOSE, false)
  local crop = Image(FACE[3], FACE[4], ColorMode.RGB); crop:drawImage(img, Point(-FACE[1], -FACE[2]))
  scaled(crop, k, pc.rgba(0xe9,0xe4,0xdc,255), out, g, g)
  scaled(crop, k, pc.rgba(0x2b,0x30,0x44,255), out, 2 * g + cw, g)
  save(out, REV .. "faces-" .. FR .. "-" .. CLOSE .. "-closeup.png")
end

-- blink swap: each change happens the moment the eyes close (as AnimatorTests expects), 120 ms closed, ~1.5 s per face
local ORDER = {"idle", "intent", "happy", "sad", "scared", "smile", "exhausted", "idle"}
local DARK = pc.rgba(0x2b, 0x30, 0x44, 255)
local frames = {}
for i = 1, #ORDER - 1 do
  frames[#frames + 1] = {face(ORDER[i], false), 1.38}
  frames[#frames + 1] = {face(ORDER[i + 1], true), 0.12}
end
local gs = Sprite(256, 256, ColorMode.RGB)
for i, f in ipairs(frames) do
  local fr = i == 1 and gs.frames[1] or gs:newEmptyFrame(i)
  local big = Image(256, 256, ColorMode.RGB); scaled(f[1], 2, DARK, big, 0, 0)
  if i == 1 then gs.cels[1].image = big else gs:newCel(gs.layers[1], fr, big, Point(0, 0)) end
  fr.duration = f[2]
end
-- exact palette with an unused index 0, so no colour (e.g. the #120d0e outline) becomes the GIF's transparent index
local seen, cols = {}, {}
for _, f in ipairs(frames) do for it in f[1]:pixels() do local v = it(); if pc.rgbaA(v) == 0 then v = DARK end; if not seen[v] then seen[v] = true; cols[#cols + 1] = v end end end
seen[DARK] = seen[DARK] or (function() cols[#cols + 1] = DARK; return true end)()
local gp = Palette(#cols + 1); gp:setColor(0, Color{r = 255, g = 0, b = 255, a = 0})
for i, v in ipairs(cols) do gp:setColor(i, Color{r = pc.rgbaR(v), g = pc.rgbaG(v), b = pc.rgbaB(v)}) end
gs:setPalette(gp)
app.command.ChangePixelFormat{ format = "indexed", dithering = "none" }
gs.transparentColor = 0
gs:saveAs(REV .. "faces-" .. FR .. "-blinkswap.gif"); gs:close()

if PREVIEW then
  local ps = Sprite(128, 128, ColorMode.RGB); local n = 0
  for _, nm in ipairs({"idle", "intent", "exhausted", "happy", "smile", "sad", "scared", "awe"}) do for _, cl in ipairs({false, true}) do
    n = n + 1; local fr = n == 1 and ps.frames[1] or ps:newEmptyFrame(n)
    if n == 1 then ps.cels[1].image = face(nm, cl) else ps:newCel(ps.layers[1], fr, face(nm, cl), Point(0, 0)) end
  end end
  ps:saveAs(PREVIEW); ps:close()
end
print("faces export ok", #frames, "gif frames")
