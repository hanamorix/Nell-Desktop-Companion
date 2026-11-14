-- Measured checks for the faces (Task 7). Prints one line per check; every count should read 0 unless noted.
-- Global REF (optional): an .aseprite whose frame 1 the master's frame 1 must equal (the accepted Task 6 master).
if not EYE_SPEC then dofile(app.fs.joinPath(app.fs.filePath(debug.getinfo(1, "S").source:gsub("^@", "")), "cfg.lua")) end
local pc = app.pixelColor
local spr = app.activeSprite
if not spr or spr.filename ~= MASTER then spr = app.open(MASTER) end
local function tagFrame(n) for _, t in ipairs(spr.tags) do if t.name == n then return t.fromFrame.frameNumber end end end
local function inRect(x, y, r) return x >= r[1] and y >= r[2] and x < r[1] + r[3] and y < r[2] + r[4] end
local function comp(s, f) local im = Image(128, 128, ColorMode.RGB); im:drawSprite(s, f); return im end
-- every face:* tag and eyes:closed must cover exactly one frame
local bad = {}
for _, t in ipairs(spr.tags) do if t.name:match("^face:") or t.name == "eyes:closed" then
  if t.fromFrame.frameNumber ~= t.toFrame.frameNumber then bad[#bad + 1] = string.format("%s %d-%d", t.name, t.fromFrame.frameNumber, t.toFrame.frameNumber) end end end
print("multi-frame face/eyes tags: " .. (#bad == 0 and "0" or table.concat(bad, ", ")))
assert(#bad == 0, "face/eyes tags must be one frame each")
local idle = comp(spr, tagFrame("face:idle"))
if REF then local r = app.open(REF); local a = comp(r, 1); r:close(); local n = 0
  for y = 0, 127 do for x = 0, 127 do if a:getPixel(x, y) ~= idle:getPixel(x, y) then n = n + 1 end end end
  print("idle frame vs accepted master: " .. n .. " px differ") end
local pl; for _, l in ipairs(spr.layers) do if l.name == "eyes" then pl = l end end
local pcel = pl:cel(tagFrame("eyes:closed"))
local inPatch = {}
for y = 0, pcel.image.height - 1 do for x = 0, pcel.image.width - 1 do
  if pc.rgbaA(pcel.image:getPixel(x, y)) > 0 then inPatch[(y + pcel.position.y) * 128 + x + pcel.position.x] = true end end end
local nOther = 0
for _, c in ipairs(spr.cels) do if c.frameNumber == tagFrame("eyes:closed") and c.layer ~= pl then nOther = nOther + 1 end end
print("eyes:closed frame: other cels " .. nOther .. ", patch px " .. (function() local k = 0 for _ in pairs(inPatch) do k = k + 1 end return k end)())
local SOFT = {[pc.rgba(0xF5,0xD4,0xC9,255)] = true, [pc.rgba(0x62,0x2C,0x36,255)] = true, [pc.rgba(0xCF,0x7D,0x8B,255)] = true}
local function inLens(x, y) for _, r in ipairs(RIM_SPEC) do local dx, dy = (x + 0.5 - r.cx) / (r.rx - 2), (y + 0.5 - r.cy) / (r.ry - 2); if dx*dx + dy*dy <= 1 then return true end end return false end
-- allowed colours: the accepted master's palette plus Plum Night tokens
local OK = {}
for it in idle:pixels() do OK[it()] = true end
local tok = io.open(app.fs.joinPath(app.fs.filePath(app.fs.filePath(SPRITES)), "concept-nell-design-system", "tokens.json")); local tn = 0
if tok then for h in tok:read("a"):gmatch('"#(%x%x%x%x%x%x)"') do OK[pc.rgba(tonumber(h:sub(1,2),16), tonumber(h:sub(3,4),16), tonumber(h:sub(5,6),16), 255)] = true; tn = tn + 1 end tok:close() end
print("allowed colours: master + " .. tn .. " token values")
for _, t in ipairs(spr.tags) do local name = t.name:match("^face:(.+)") if name then
  local f = t.fromFrame.frameNumber; local im = comp(spr, f)
  local outside, ring, partial, stray, hidden, over = 0, 0, 0, {}, 0, {}
  local x0, y0, x1, y1 = 999, 999, -1, -1
  for y = 0, 127 do for x = 0, 127 do
    local a, b = idle:getPixel(x, y), im:getPixel(x, y)
    local al = pc.rgbaA(b); if al ~= 0 and al ~= 255 then partial = partial + 1 end
    if al > 0 and not OK[b] then stray[string.format("#%02X%02X%02X", pc.rgbaR(b), pc.rgbaG(b), pc.rgbaB(b))] = true end
    if a ~= b then
      if not inRect(x, y, FACE) then outside = outside + 1
      elseif x == FACE[1] or y == FACE[2] or x == FACE[1] + FACE[3] - 1 or y == FACE[2] + FACE[4] - 1 then ring = ring + 1 end
      if not inPatch[y * 128 + x] then x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y) end
    end
    -- a change outside the patch that paints over something other than skin, mouth or forehead pink (rims, outlines, hair)
    if a ~= b and not inPatch[y * 128 + x] and not SOFT[a] then over[#over + 1] = x .. "," .. y end
    -- an eye change the blink cannot hide: differs from idle inside a lens but outside the patch
    if a ~= b and not inPatch[y * 128 + x] and inLens(x, y) then hidden = hidden + 1 end
  end end
  local s = {} for k in pairs(stray) do s[#s + 1] = k end
  print(string.format("%-10s frame %d | outside face rect %d | on rect edge %d | eye changes outside patch %d | partial alpha %d | stray colours %s | changes outside patch: %s | over non-skin %d %s",
    name, f, outside, ring, hidden, partial, #s == 0 and "none" or table.concat(s, " "), x1 < 0 and "none" or string.format("x %d-%d, y %d-%d", x0, x1, y0, y1), #over, table.concat(over, " ")))
end end
