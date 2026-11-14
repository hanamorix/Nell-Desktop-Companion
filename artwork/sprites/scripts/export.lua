-- set the palette to the used colours, then write the 1x PNG and the 2x nearest-neighbour PNG, both on transparent
local pc = app.pixelColor
local spr = app.activeSprite
local comp = Image(128, 128, ColorMode.RGB); comp:drawSprite(spr, 1)
local seen, cols = {}, {}
for it in comp:pixels() do local v = it(); if pc.rgbaA(v) > 0 and not seen[v] then seen[v] = true; cols[#cols+1] = v end end
table.sort(cols, function(a, b) return (3*pc.rgbaR(a)+6*pc.rgbaG(a)+pc.rgbaB(a)) < (3*pc.rgbaR(b)+6*pc.rgbaG(b)+pc.rgbaB(b)) end)
local pal = Palette(#cols + 1); pal:setColor(0, Color{r=0, g=0, b=0, a=0})
for i, v in ipairs(cols) do pal:setColor(i, Color{r=pc.rgbaR(v), g=pc.rgbaG(v), b=pc.rgbaB(v)}) end
spr:setPalette(pal)
spr:saveAs(spr.filename)
local alphaBad = 0
for it in comp:pixels() do local a = pc.rgbaA(it()); if a ~= 0 and a ~= 255 then alphaBad = alphaBad + 1 end end
local function save(img, path) local s = Sprite(img.width, img.height, ColorMode.RGB); s.cels[1].image = img; s:saveAs(path); s:close() end
local R = ROUND or "r4"
save(comp, REV .. "master-" .. R .. "-1x.png")
-- 2x nearest-neighbour on a transparent background (rounds up to r3 also wrote -light/-dark versions on solid colours)
local big = Image(256, 256, ColorMode.RGB)
for y = 0, 255 do for x = 0, 255 do big:drawPixel(x, y, comp:getPixel(x // 2, y // 2)) end end
save(big, REV .. "master-" .. R .. "-2x.png")
print("palette", #cols, "partial-alpha px", alphaBad)
