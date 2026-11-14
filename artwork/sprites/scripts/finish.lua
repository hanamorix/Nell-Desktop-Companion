-- details (drawstrings, cat logo, laptop shadow), then fill enclosed holes and add a 1 px outline outside every light silhouette edge
local pc = app.pixelColor
local spr = app.activeSprite
local function hex(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local OUTC = hex("#120D0E")
local order, IMG = {}, {}
for i, l in ipairs(spr.layers) do order[i] = l.name; local c = l:cel(1); local im = Image(128,128,ColorMode.RGB); if c then im:drawImage(c.image, c.position) end; IMG[l.name] = im end
local function rows(img, x0, y0, rs, lg) for r, row in ipairs(rs) do for c = 1, #row do local col = lg[row:sub(c,c)]; if col then img:drawPixel(x0+c-1, y0+r-1, col) end end end end
-- drawstrings on the hoodie
for _, sx in ipairs(STRINGS) do
  for y = 75, 84 do IMG.body:drawPixel(sx, y, hex("#AEABAC")) end
  for y = 85, 87 do IMG.body:drawPixel(sx, y, hex("#64595B")) end
  IMG.body:drawPixel(sx + 1, 76, hex("#261A22"))
end
-- cat logo on the lid back
rows(IMG.laptop, LOGO.x, LOGO.y, LOGO.rows, {C = hex("#483942"), L = hex("#554141")})
-- shadow of the laptop and arms on the desk top
for _, p in ipairs(DESK_SHADOW) do for x = p[1], p[2] do if pc.rgbaA(IMG.desk:getPixel(x, p[3])) > 0 and IMG.desk:getPixel(x, p[3]) == hex("#614B49") then IMG.desk:drawPixel(x, p[3], hex("#4A3532")) end end end
-- composite helpers
local function top(x, y) for i = #order, 1, -1 do local c = IMG[order[i]]:getPixel(x, y); if pc.rgbaA(c) > 0 then return order[i], c end end end
-- 1. enclosed holes -> outline colour on the top neighbouring layer
local outside, q = {}, {}
local function push(x, y) local k = y*128+x; if not outside[k] and not top(x, y) then outside[k] = true; q[#q+1] = k end end
for i = 0, 127 do push(i, 0); push(i, 127); push(0, i); push(127, i) end
local h = 1
while h <= #q do local k = q[h]; h = h + 1; local x, y = k % 128, k // 128
  if x > 0 then push(x-1, y) end; if x < 127 then push(x+1, y) end; if y > 0 then push(x, y-1) end; if y < 127 then push(x, y+1) end end
local holes = 0
for y = 0, 127 do for x = 0, 127 do if not top(x, y) and not outside[y*128+x] then
  local best
  for _, d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do local n = top(x+d[1], y+d[2]); if n then best = n end end
  if best then IMG[best]:drawPixel(x, y, OUTC); holes = holes + 1 end
end end end
-- (the silhouette outline is redrawn by outline.lua)
for _, l in ipairs(spr.layers) do local c = l:cel(1); if c then c.image, c.position = IMG[l.name], Point(0,0) else spr:newCel(l, 1, IMG[l.name], Point(0,0)) end end
spr:saveAs(spr.filename)
print("holes", holes)
