-- Builds the small icon masters (nell-icon-32.aseprite, nell-icon-16.aseprite). Box-averaging the 128 px art
-- down to these sizes turns her face to mush, so they are hand-pixelled simplifications in her own colours:
-- the same tile recipe and moon drawn natively at that size, and her hood, ears, fringe and glasses.
local here = app.fs.filePath((debug.getinfo(1, "S").source:gsub("^@", "")))
local pc = app.pixelColor
local function hex(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local PN = {outline=hex"#120d0e", p900=hex"#1a1214", p800=hex"#261a22", p700=hex"#3f3039", pink=hex"#ec9394",
            wine=hex"#622c36", berry=hex"#a74f5e"}
-- her colours, from nell-master's idle frame
local LEGEND = {K="#120d0e", H="#483942", h="#261a22", R="#614b49", r="#3d2926", C="#f5d4c9", c="#d5a3a2",
                E="#ec9394", e="#a74f5e", W="#f7f0ed", g="#aeabac"}

local function build(o)
  local N, T0, TS, R = o.n, o.t0, o.ts, o.r
  local function inTile(x, y)
    if x < T0 or y < T0 or x >= T0 + TS or y >= T0 + TS then return false end
    local cx = (x < T0 + R) and (T0 + R) or ((x >= T0 + TS - R) and (T0 + TS - R) or nil)
    local cy = (y < T0 + R) and (T0 + R) or ((y >= T0 + TS - R) and (T0 + TS - R) or nil)
    if not (cx and cy) then return true end
    local dx, dy = x + 0.5 - cx, y + 0.5 - cy
    return dx * dx + dy * dy <= R * R
  end
  local function isOutline(x, y)
    return inTile(x, y) and not (inTile(x-1, y) and inTile(x+1, y) and inTile(x, y-1) and inTile(x, y+1))
  end
  local img = Image(N, N, ColorMode.RGB)
  for y = 0, N - 1 do for x = 0, N - 1 do
    local c
    if isOutline(x, y) then c = PN.outline
    elseif inTile(x, y) then
      if isOutline(x, y - 1) and y <= T0 + 1 then c = PN.pink
      elseif isOutline(x, y + 1) then c = PN.p800
      else
        c = PN.p700
        if o.moon then
          local d = (x + 0.5 - o.moon[1])^2 + (y + 0.5 - o.moon[2])^2
          if d <= o.moon[3]^2 then c = d <= (o.moon[3] - 1)^2 and PN.wine or PN.berry end
        end
      end
    elseif inTile(x, y - 1) then c = PN.p900
    end
    if c then img:drawPixel(x, y, c) end
  end end
  for j, row in ipairs(o.rows) do
    assert(#row == #o.rows[1], "row " .. j .. " is " .. #row .. " wide")
    for i = 1, #row do
      local ch, x, y = row:sub(i, i), o.x + i - 1, o.y + j - 1
      if LEGEND[ch] and inTile(x, y) and not isOutline(x, y) then img:drawPixel(x, y, hex(LEGEND[ch])) end
    end
  end
  local spr = Sprite(N, N, ColorMode.RGB)
  spr.layers[1].name = "icon"
  spr:newCel(spr.layers[1], 1, img, Point(0, 0))
  spr:saveAs(app.fs.joinPath(here, "nell-icon-" .. N .. ".aseprite"))
  print("saved " .. N)
end

build{n=32, t0=3, ts=26, r=6, moon={16, 15, 12}, x=4, y=4, rows={
"........................",
"........................",
"....K..............K....",
"...KHK............KhK...",
"...KHHK..........KHhK...",
"...KHHHKKKKKKKKKKHHhK...",
"..KHHHHHHHHHHHHHHHHhhK..",
"..KHHHHrrrrrrrrrrHHhhK..",
"..KHHrrRRRRRRRRRRrrhhK..",
"..KHrRRRRRRRRRRRRRRrhK..",
"..KHrRRRrRRRRRRrRRRrhK..",
"..KHrRKKKKRCCRKKKKRrhK..",
"..KHrKCWECKKKKCWECKrhK..",
"..KHrKCEeCKCCKCEeCKrhK..",
"..KhrKCEECKCCKCEECKrhK..",
"..KhrRKKKKCCCCKKKKRrhK..",
"..KhrRcCCCCKKCCCCcRrhK..",
"...KhrRccCCCCCCccRrhK...",
"...KhhrRKccccccKRrhhK...",
"..KhhhhrRKKKKKKRrhhhhK..",
".KhhhhhrrhHHHHhrrhhhhhK.",
"KhhhhhhrrhgHHghrrhhhhhhK",
"KhhhhhhhhhgHHghhhhhhhhhK",
"KhhhhhhhhhgHHghhhhhhhhhK",
}}

build{n=16, t0=1, ts=14, r=3, moon={8, 6, 5.5}, x=2, y=2, rows={
"............",
".K........K.",
".KK......KK.",
".KHKKKKKKhK.",
".KHrRRRRrhK.",
".KrRCRRCRrK.",
".KKKKCCKKKK.",
".KWEKCCKWEK.",
".KEeKCCKEeK.",
".rKKCCCCKKr.",
".hrcCCCCcrh.",
"hhhrccccrhhh",
}}
