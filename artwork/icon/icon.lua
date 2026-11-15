-- Builds artwork/icon/nell-icon.aseprite: Nell's idle-frame bust (her real pixels, 1:1) on a Plum Night tile.
-- Native 128 px canvas, so the exports are exact nearest-neighbour multiples (x8 = 1024). Run from Aseprite:
--   aseprite -b --script artwork/icon/icon.lua
-- The master is only read, never saved.
local here = app.fs.filePath((debug.getinfo(1, "S").source:gsub("^@", "")))
local ART = app.fs.filePath(here)
local MASTER = app.fs.joinPath(ART, "sprites", "nell-master.aseprite")
local OUT = app.fs.joinPath(here, "nell-icon.aseprite")
local P = ICON or {dx=-8, dy=20, cut=92,             -- cut: master rows below 92 are her hands on the keys
  backing={x=66, y=61, r=44, ring=3, maxY=82, inner="#622c36", outer="#a74f5e"}}  -- the wine moon her ears stand against;
  -- maxY keeps it out of the gap the chair left under her right ear
local DX, DY = P.dx or -8, P.dy or 20              -- where her master pixels land on the icon canvas
local LAYERS = P.layers or {"body", "head", "face", "eyes"}

local function hex(h) return app.pixelColor.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local PN = {outline=hex"#120d0e", p900=hex"#1a1214", p800=hex"#261a22", p700=hex"#3f3039", p600=hex"#483942",
            p500=hex"#64595b", pink=hex"#ec9394"}

-- her idle composite (frame 1 = face:idle on the resting body)
local src = app.open(MASTER)
local bust = Image(src.width, src.height, ColorMode.RGB)
for _, name in ipairs(LAYERS) do
  for _, l in ipairs(src.layers) do
    if l.name == name and l:cel(1) then bust:drawImage(l:cel(1).image, l:cel(1).position) end
  end
end
src:close()

-- macOS grid: 824/1024 tile = 103/128; 104 keeps it even. Corner radius ~22% of the tile.
local N, T0, TS, R = 128, 12, 104, 23
local function inTile(x, y)
  if x < T0 or y < T0 or x >= T0 + TS or y >= T0 + TS then return false end
  local cx = (x < T0 + R) and (T0 + R) or ((x >= T0 + TS - R) and (T0 + TS - R) or nil)
  local cy = (y < T0 + R) and (T0 + R) or ((y >= T0 + TS - R) and (T0 + TS - R) or nil)
  if not (cx and cy) then return true end
  local ddx, ddy = x + 0.5 - cx, y + 0.5 - cy
  return ddx * ddx + ddy * ddy <= R * R
end
local function isOutline(x, y)
  return inTile(x, y) and not (inTile(x-1, y) and inTile(x+1, y) and inTile(x, y-1) and inTile(x, y+1))
end
local function interior(x, y) return inTile(x, y) and not isOutline(x, y) end

local spr = Sprite(N, N, ColorMode.RGB)
local tileLayer = spr.layers[1]; tileLayer.name = "tile"
local tile = Image(N, N, ColorMode.RGB)
for y = 0, N - 1 do for x = 0, N - 1 do
  local c
  if isOutline(x, y) then c = PN.outline
  elseif inTile(x, y) then
    if isOutline(x, y - 1) and y < T0 + 5 then c = PN.pink  -- the interface frame's pink top edge
    elseif isOutline(x, y + 1) then c = PN.p800            -- and its plum-800 bottom bevel
    else c = P.fill and hex(P.fill) or PN.p700 end
  elseif inTile(x, y - 1) then c = PN.p900                -- hard drop, one pixel down, no blur
  end
  if c then tile:drawPixel(x, y, c) end
end end
spr:newCel(tileLayer, 1, tile, Point(0, 0))

if P.backing then                                        -- optional lighter disc behind her head, for contrast
  local back = spr:newLayer(); back.name = "backing"
  local img = Image(N, N, ColorMode.RGB)
  local bx, by, br = P.backing.x, P.backing.y, P.backing.r
  for y = 0, N - 1 do for x = 0, N - 1 do
    local d = (x + 0.5 - bx)^2 + (y + 0.5 - by)^2
    if interior(x, y) and not isOutline(x, y - 1) and d <= br * br and y <= (P.backing.maxY or N) then
      img:drawPixel(x, y, d <= (br - (P.backing.ring or 0))^2 and hex(P.backing.inner or "#483942") or hex(P.backing.outer or "#483942"))
    end
  end end
  spr:newCel(back, 1, img, Point(0, 0))
end

local nellLayer = spr:newLayer(); nellLayer.name = "nell"
local nell = Image(N, N, ColorMode.RGB)
for sy = 0, bust.height - 1 do for sx = 0, bust.width - 1 do
  local px = bust:getPixel(sx, sy)
  local x, y = sx + DX, sy + DY
  if app.pixelColor.rgbaA(px) > 0 and interior(x, y) and (not P.cut or sy <= P.cut) then nell:drawPixel(x, y, px) end
end end
-- drop pieces the crop left floating (a hair strand that crossed the chair): any 8-connected piece under 32 px
local seen = {}
for y = 0, N - 1 do for x = 0, N - 1 do
  local k = y * N + x
  if not seen[k] and app.pixelColor.rgbaA(nell:getPixel(x, y)) > 0 then
    local piece, stack = {}, {k}; seen[k] = true
    while #stack > 0 do
      local c = table.remove(stack); piece[#piece + 1] = c
      local cx, cy = c % N, c // N
      for oy = -1, 1 do for ox = -1, 1 do
        local nx, ny = cx + ox, cy + oy
        local nk = ny * N + nx
        if nx >= 0 and ny >= 0 and nx < N and ny < N and not seen[nk] and app.pixelColor.rgbaA(nell:getPixel(nx, ny)) > 0 then
          seen[nk] = true; stack[#stack + 1] = nk
        end
      end end
    end
    if #piece < 32 then for _, c in ipairs(piece) do nell:drawPixel(c % N, c // N, 0) end end
  end
end end
spr:newCel(nellLayer, 1, nell, Point(0, 0))

spr:saveAs(OUT)
print("saved " .. OUT)
