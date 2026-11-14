-- crop concept frame 1, flood-fill the baked checkerboard from the border, write an opaque 384x384 source on flat #f0f0f0 plus a mask
local pc = app.pixelColor
local s = app.open(SRC)
local im = Image(s.width, s.height, ColorMode.RGB); im:drawSprite(s, 1)
local FW, FH = 390, 395
local function isbg(c)
  local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
  local mx, mn = math.max(r,g,b), math.min(r,g,b)
  return pc.rgbaA(c) < 20 or (mn > 205 and mx - mn < 18)
end
local bg, q = {}, {}
local function push(x, y) local k = y*FW+x; if not bg[k] and isbg(im:getPixel(x,y)) then bg[k] = true; q[#q+1] = k end end
for x = 0, FW-1 do push(x, 0); push(x, FH-1) end
for y = 0, FH-1 do push(0, y); push(FW-1, y) end
local h = 1
while h <= #q do local k = q[h]; h = h + 1; local x, y = k % FW, k // FW
  if x > 0 then push(x-1,y) end; if x < FW-1 then push(x+1,y) end; if y > 0 then push(x,y-1) end; if y < FH-1 then push(x,y+1) end end
local x0, y0, x1, y1 = 1e9, 1e9, -1, -1
for y = 0, FH-1 do for x = 0, FW-1 do if not bg[y*FW+x] then
  x0, y0, x1, y1 = math.min(x0,x), math.min(y0,y), math.max(x1,x), math.max(y1,y) end end end
print("bbox", x0, y0, x1, y1, "w", x1-x0+1, "h", y1-y0+1)
if OX then
  local o = Image(384, 384, ColorMode.RGB)
  local m = Image(384, 384, ColorMode.RGB)
  for y = 0, 383 do for x = 0, 383 do
    local sx, sy = x + OX, y + OY
    local inb = sx >= 0 and sy >= 0 and sx < FW and sy < FH
    local isb = (not inb) or bg[sy*FW+sx]
    if isb then o:drawPixel(x, y, pc.rgba(240,240,240,255)); m:drawPixel(x,y,pc.rgba(0,0,0,255))
    else local c = im:getPixel(sx, sy); o:drawPixel(x, y, pc.rgba(pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c),255)); m:drawPixel(x,y,pc.rgba(255,255,255,255)) end
  end end
  o:saveAs(OUT .. "src.png"); m:saveAs(OUT .. "mask.png")
  print("saved")
end
