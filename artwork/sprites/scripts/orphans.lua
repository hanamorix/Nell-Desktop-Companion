-- merge orphan pixels (no same-colour 8-neighbour in the composite) into their closest neighbour colour, on the layer that owns them;
-- skips the eye glints/pupils (eyes layer), the mouth and the hands, which are deliberate 1 px details
local pc = app.pixelColor
local spr = app.activeSprite
local order, IMG = {}, {}
for i, l in ipairs(spr.layers) do order[i] = l.name; local c = l:cel(1); local im = Image(128,128,ColorMode.RGB); if c then im:drawImage(c.image, c.position) end; IMG[l.name] = im end
local function top(x, y) if x < 0 or y < 0 or x > 127 or y > 127 then return nil end
  for i = #order, 1, -1 do local c = IMG[order[i]]:getPixel(x, y); if pc.rgbaA(c) > 0 then return order[i], c end end end
local function d2(a, b) local r, g, bl = pc.rgbaR(a)-pc.rgbaR(b), pc.rgbaG(a)-pc.rgbaG(b), pc.rgbaB(a)-pc.rgbaB(b); return 2*r*r + 4*g*g + 3*bl*bl end
local function skip(x, y, n)
  -- (eye whites, irises, glints and pupils are inside the ORPH_SKIP boxes)
  for _, e in ipairs(EYE_SPEC) do local dx, dy = (x + 0.5 - e.sx) / (e.srx + 0.5), (y + 0.5 - e.sy) / (e.sry + 0.5); if dx*dx + dy*dy <= 1 then return true end end
  for _, b in ipairs(ORPH_SKIP) do if x >= b[1] and y >= b[2] and x < b[1]+b[3] and y < b[2]+b[4] then return true end end
end
local total = 0
for pass = 1, 3 do
  local fixes = {}
  for y = 0, 127 do for x = 0, 127 do local n, c = top(x, y)
    if n and not skip(x, y, n) then
      local same, best, bd = false, nil, math.huge
      for dy = -1, 1 do for dx = -1, 1 do if dx ~= 0 or dy ~= 0 then local nn, nc = top(x+dx, y+dy)
        if nn then if nc == c then same = true end; if nn == n then local d = d2(c, nc); if d < bd then bd, best = d, nc end end end end end end -- replacement only from the same layer
      if not same and best then fixes[#fixes+1] = {x, y, n, best} end
    end
  end end
  for _, f in ipairs(fixes) do IMG[f[3]]:drawPixel(f[1], f[2], f[4]) end
  total = total + #fixes
  if #fixes == 0 then break end
end
for _, l in ipairs(spr.layers) do local c = l:cel(1); if c then c.image, c.position = IMG[l.name], Point(0,0) end end
spr:saveAs(spr.filename)
print("orphans merged", total)
