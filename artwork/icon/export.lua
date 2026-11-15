-- Exports the icon: nell-icon-1024.png, AppIcon.iconset (all ten sizes) and preview.png. Run after icon.lua
-- and small.lua; then `iconutil -c icns artwork/icon/AppIcon.iconset -o Sources/Nell/Resources/AppIcon.icns`.
-- Every size is one of the three natives (128, 32, 16) scaled by a whole number, nearest-neighbour only.
local here = app.fs.filePath((debug.getinfo(1, "S").source:gsub("^@", "")))
local function flat(name)
  local spr = app.open(app.fs.joinPath(here, name))
  local img = Image(spr.width, spr.height, ColorMode.RGB)
  img:drawSprite(spr, 1)
  spr:close()
  return img
end
local function scaled(src, k)
  local out = Image(src.width * k, src.height * k, ColorMode.RGB)
  for y = 0, out.height - 1 do for x = 0, out.width - 1 do out:drawPixel(x, y, src:getPixel(x // k, y // k)) end end
  return out
end
local N128, N32, N16 = flat("nell-icon.aseprite"), flat("nell-icon-32.aseprite"), flat("nell-icon-16.aseprite")

scaled(N128, 8):saveAs(app.fs.joinPath(here, "nell-icon-1024.png"))
local set = app.fs.joinPath(here, "AppIcon.iconset")
app.fs.makeDirectory(set)
for _, e in ipairs{
  {"icon_16x16", N16, 1}, {"icon_16x16@2x", N32, 1}, {"icon_32x32", N32, 1}, {"icon_32x32@2x", N32, 2},
  {"icon_128x128", N128, 1}, {"icon_128x128@2x", N128, 2}, {"icon_256x256", N128, 2},
  {"icon_256x256@2x", N128, 4}, {"icon_512x512", N128, 4}, {"icon_512x512@2x", N128, 8}} do
  scaled(e[2], e[3]):saveAs(app.fs.joinPath(set, e[1] .. ".png"))
end

-- preview: 16, 32, 128 and 512 at actual size, plus the 16 and 32 blown up x4 to judge their pixels,
-- on a light and a dark background
local shots = {{N16, 1}, {N32, 1}, {N128, 1}, {N128, 4}, {N16, 4}, {N32, 4}}
local PAD, ROWH = 32, 512 + 64
local W = PAD
for _, s in ipairs(shots) do W = W + s[1].width * s[2] + PAD end
local sheet = Image(W, ROWH * 2, ColorMode.RGB)
local pc = app.pixelColor
for row, bg in ipairs{pc.rgba(236, 236, 236, 255), pc.rgba(30, 30, 30, 255)} do
  local y0 = (row - 1) * ROWH
  for y = y0, y0 + ROWH - 1 do for x = 0, W - 1 do sheet:drawPixel(x, y, bg) end end
  local x = PAD
  for _, s in ipairs(shots) do
    local img = scaled(s[1], s[2])
    sheet:drawImage(img, Point(x, y0 + (ROWH - img.height) // 2), 255, BlendMode.NORMAL)
    x = x + img.width + PAD
  end
end
sheet:saveAs(app.fs.joinPath(here, "preview.png"))
print("exported")
