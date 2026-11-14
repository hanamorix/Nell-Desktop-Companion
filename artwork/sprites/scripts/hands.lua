-- draw both hands on body and clear the laptop under them (layers are a partition)
local pc = app.pixelColor
local spr = app.activeSprite
local function hex(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local LG = {K = hex("#120D0E"), S = hex("#F5D4C9"), B = hex("#F4B6AC"), D = hex("#D5A3A2"), R = hex("#B47D83"), O = hex("#622C36"), L = hex("#483942"), H = hex("#3F3039"), U = hex("#261A22")}
local function layer(n) for _, l in ipairs(spr.layers) do if l.name == n then return l end end end
local body, lap, desk = layer("body"):cel(1), layer("laptop"):cel(1), layer("desk"):cel(1)
local bi, li = Image(128,128,ColorMode.RGB), Image(128,128,ColorMode.RGB)
local di = Image(128,128,ColorMode.RGB)
bi:drawImage(body.image, body.position); li:drawImage(lap.image, lap.position); di:drawImage(desk.image, desk.position)
local lid = {}; for y = 0, 127 do lid[y] = LID_EDGE(li, y) end
for _, h in ipairs(HANDS) do
  for r, row in ipairs(h.rows) do for c = 1, #row do local ch = row:sub(c, c)
    if LG[ch] then local x, y = h.x + c - 1, h.y + r - 1; bi:drawPixel(x, y, LG[ch]); di:drawPixel(x, y, pc.rgba(0,0,0,0)) -- layers in front of body are cut under the hands,
      if x > lid[y] then li:drawPixel(x, y, pc.rgba(0,0,0,0)) end end                                                       -- except the lid, which hides the left hand's edge
  end end
end
body.image, body.position = bi, Point(0,0)
lap.image, lap.position = li, Point(0,0)
desk.image, desk.position = di, Point(0,0)
spr:saveAs(spr.filename)
print("hands ok")
