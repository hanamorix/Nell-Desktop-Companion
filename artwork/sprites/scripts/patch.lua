-- Hand touch-ups applied last (PATCHES in cfg.lua): rows of characters per layer, like draw_rows; "." leaves a pixel alone.
local pc = app.pixelColor
local spr = app.activeSprite
local function col(h) if #h == 9 then return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), tonumber(h:sub(8,9),16)) end
  return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local n = 0
for _, p in ipairs(PATCHES or {}) do
  local layer; for _, l in ipairs(spr.layers) do if l.name == p.layer then layer = l end end
  local cel = layer:cel(1); local im = Image(128,128,ColorMode.RGB); im:drawImage(cel.image, cel.position)
  for r, row in ipairs(p.rows) do for c = 1, #row do local h = p.legend[row:sub(c,c)]
    if h then im:drawPixel(p.x + c - 1, p.y + r - 1, col(h)); n = n + 1 end end end
  cel.image, cel.position = im, Point(0,0)
end
spr:saveAs(spr.filename)
print("patched px", n)
