-- face/eyes layers own exactly their slice rects: stray pixels outside them move to the head layer
local pc = app.pixelColor
local spr = app.activeSprite
local IMG, CEL = {}, {}
for _, l in ipairs(spr.layers) do local c = l:cel(1); local im = Image(128,128,ColorMode.RGB); if c then im:drawImage(c.image, c.position) end; IMG[l.name], CEL[l.name] = im, c end
local moved = 0
for n, r in pairs({face = FACE, eyes = EYES}) do
  for y = 0, 127 do for x = 0, 127 do local c = IMG[n]:getPixel(x, y)
    if pc.rgbaA(c) > 0 and not (x >= r[1] and y >= r[2] and x < r[1]+r[3] and y < r[2]+r[4]) then
      IMG.head:drawPixel(x, y, c); IMG[n]:drawPixel(x, y, pc.rgba(0,0,0,0)); moved = moved + 1 end
  end end
end
-- body pixels hidden under the desk or laptop below the desk line are junk fragments
for y = 104, 127 do for x = 0, 127 do if pc.rgbaA(IMG.body:getPixel(x, y)) > 0 and (pc.rgbaA(IMG.desk:getPixel(x, y)) > 0 or pc.rgbaA(IMG.laptop:getPixel(x, y)) > 0) then IMG.body:drawPixel(x, y, pc.rgba(0,0,0,0)) end end end
for _, l in ipairs(spr.layers) do local c = l:cel(1); if c then c.image, c.position = IMG[l.name], Point(0,0) end end
-- slices
for _, s in ipairs(spr.slices) do end
local have = {}; for _, s in ipairs(spr.slices) do have[s.name] = s end
for name, r in pairs({face = FACE, eyes = EYES, emoji = EMOJI, paper = PAPER}) do
  local s = have[name] or spr:newSlice(Rectangle(r[1], r[2], r[3], r[4]))
  s.name = name; s.bounds = Rectangle(r[1], r[2], r[3], r[4])
end
spr:saveAs(spr.filename)
print("moved", moved, "slices", #spr.slices)
