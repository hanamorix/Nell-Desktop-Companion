-- Clean the black (#120d0e) outlines:
-- 1. peel the converted silhouette outline (up to 2 px thick) where it lies on a coloured fill;
-- 2. smooth the silhouette: drop 1 px spurs stuck to a body, fill 1 px notches;
-- 3. redraw one 1 px outline outside every coloured silhouette pixel (4-neighbours, so diagonal steps stay single);
-- 4. inside head/body/chair: turn tiny #120d0e specks (<= 3 px) and L-corners of interior lines into the darkest neighbouring tone.
local pc = app.pixelColor
local spr = app.activeSprite
local function hex(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local K, CLEAR = hex("#120D0E"), pc.rgba(0,0,0,0)
local order, IMG = {}, {}
for i, l in ipairs(spr.layers) do order[i] = l.name; local c = l:cel(1); local im = Image(128,128,ColorMode.RGB); if c then im:drawImage(c.image, c.position) end; IMG[l.name] = im end
local function top(x, y) if x < 0 or y < 0 or x > 127 or y > 127 then return nil end
  for i = #order, 1, -1 do local c = IMG[order[i]]:getPixel(x, y); if pc.rgbaA(c) > 0 then return order[i], c end end end
local N4 = {{-1,0},{1,0},{0,-1},{0,1}}
local outside
local function flood()
  outside = {}; local q = {}
  local function push(x, y) local k = y*128+x; if not outside[k] and not top(x, y) then outside[k] = true; q[#q+1] = k end end
  for i = 0, 127 do push(i, 0); push(i, 127); push(0, i); push(127, i) end
  local h = 1
  while h <= #q do local k = q[h]; h = h + 1; local x, y = k % 128, k // 128
    if x > 0 then push(x-1, y) end; if x < 127 then push(x+1, y) end; if y > 0 then push(x, y-1) end; if y < 127 then push(x, y+1) end end
end
local function isOut(x, y) return x < 0 or y < 0 or x > 127 or y > 127 or outside[y*128+x] end
local function skip(x, y) for _, b in ipairs(ORPH_SKIP) do if x >= b[1] and y >= b[2] and x < b[1]+b[3] and y < b[2]+b[4] then return true end end end
-- 1. peel
local peeled = 0
for pass = 1, 2 do
  flood(); local kill = {}
  for y = 0, 127 do for x = 0, 127 do local n, c = top(x, y)
    if n and c == K then
      local touchOut, onFill = false, false
      for _, d in ipairs(N4) do local nx, ny = x+d[1], y+d[2]
        if isOut(nx, ny) then touchOut = true else local _, nc = top(nx, ny); if nc and nc ~= K then onFill = true end end end
      if touchOut and onFill then kill[#kill+1] = {x, y, n} end
    end end end
  for _, k in ipairs(kill) do IMG[k[3]]:drawPixel(k[1], k[2], CLEAR) end
  peeled = peeled + #kill
end
-- 2. smooth
local spurs, notches = 0, 0
for pass = 1, 2 do
  flood()
  local function coreN(x, y) local c = 0; for _, d in ipairs(N4) do if top(x+d[1], y+d[2]) then c = c + 1 end end; return c end
  local kill, fill = {}, {}
  for y = 0, 127 do for x = 0, 127 do local n = top(x, y)
    if n and not skip(x, y) and n ~= "desk" and n ~= "laptop" then
      if coreN(x, y) == 1 then -- spur: only when attached to a body, not the tip of a thin strand
        for _, d in ipairs(N4) do local nx, ny = x+d[1], y+d[2]; if top(nx, ny) and coreN(nx, ny) >= 3 then kill[#kill+1] = {x, y, n} end end
      end
    elseif not n and outside[y*128+x] then
      local cnt, best = 0, {}
      for _, d in ipairs(N4) do local nn, nc = top(x+d[1], y+d[2]); if nn then cnt = cnt + 1; best[#best+1] = {nn, nc} end end
      if cnt >= 3 then local b = best[1]; for _, e in ipairs(best) do if e[2] ~= K then b = e end end; fill[#fill+1] = {x, y, b[1], b[2]} end
    end
  end end
  for _, k in ipairs(kill) do IMG[k[3]]:drawPixel(k[1], k[2], CLEAR) end
  for _, f in ipairs(fill) do IMG[f[3]]:drawPixel(f[1], f[2], f[4]) end
  spurs, notches = spurs + #kill, notches + #fill
end
-- 3. one outline outside coloured silhouette pixels
flood()
local adds = {}
for y = 0, 127 do for x = 0, 127 do if outside[y*128+x] then
  for _, d in ipairs(N4) do local n, c = top(x+d[1], y+d[2]); if n and c ~= K then adds[#adds+1] = {x, y, n}; break end end
end end end
for _, a in ipairs(adds) do IMG[a[3]]:drawPixel(a[1], a[2], K) end
-- 3b. doubled outline: a silhouette #120d0e pixel with no coloured 4-neighbour, whose #120d0e neighbours all sit on a fill, is redundant
-- (thin all-black hair wisps are kept: their neighbours are wisp pixels, not fill-edge pixels)
flood()
local function coloured(x, y) local n, c = top(x, y); return n and c ~= K end
local function onFillK(x, y) local _, c = top(x, y); if c ~= K then return false end
  for _, d in ipairs(N4) do if coloured(x+d[1], y+d[2]) then return true end end; return false end
local doubles = {}
for y = 0, 127 do for x = 0, 127 do local n, c = top(x, y)
  if n and c == K then
    local out, col, kn, kfill = false, false, 0, 0
    for _, d in ipairs(N4) do local nx, ny = x+d[1], y+d[2]
      if isOut(nx, ny) then out = true elseif coloured(nx, ny) then col = true
      else kn = kn + 1; if onFillK(nx, ny) then kfill = kfill + 1 end end end
    if out and not col and kn >= 1 and kfill == kn then doubles[#doubles+1] = {x, y, n} end
  end
end end
for _, d in ipairs(doubles) do IMG[d[3]]:drawPixel(d[1], d[2], CLEAR) end
-- 4. interior specks and L-corners (head, body, chair only)
flood()
local INNER = {head = true, body = true, chair = true}
local function interiorK(x, y) local n, c = top(x, y); if not (n and INNER[n] and c == K and not skip(x, y)) then return false end
  for _, d in ipairs(N4) do if isOut(x+d[1], y+d[2]) then return false end end; return true end
local function darkest(x, y)
  local best, bl
  for dy = -1, 1 do for dx = -1, 1 do local _, c = top(x+dx, y+dy)
    if c and c ~= K then local l = 3*pc.rgbaR(c) + 6*pc.rgbaG(c) + pc.rgbaB(c); if not bl or l < bl then best, bl = c, l end end end end
  return best
end
local seen, specks = {}, 0
for y = 0, 127 do for x = 0, 127 do if interiorK(x, y) and not seen[y*128+x] then
  local comp, q, h, touches = {}, {{x, y}}, 1, false
  seen[y*128+x] = true
  while h <= #q do local p = q[h]; h = h + 1; comp[#comp+1] = p
    for dy = -1, 1 do for dx = -1, 1 do local nx, ny = p[1]+dx, p[2]+dy
      local _, c = top(nx, ny)
      if c == K and not seen[ny*128+nx] then
        if interiorK(nx, ny) then seen[ny*128+nx] = true; q[#q+1] = {nx, ny} else touches = true end
      end end end
  end
  if #comp <= 3 and not touches then
    for _, p in ipairs(comp) do local n = top(p[1], p[2]); local c = darkest(p[1], p[2]); if c then IMG[n]:drawPixel(p[1], p[2], c); specks = specks + 1 end end
  end
end end end
local ls = 0
for y = 1, 126 do for x = 1, 126 do if interiorK(x, y) then
  local function k(dx, dy) local _, c = top(x+dx, y+dy); return c == K end
  local cnt = 0; for dy = -1, 1 do for dx = -1, 1 do if (dx ~= 0 or dy ~= 0) and k(dx, dy) then cnt = cnt + 1 end end end
  for _, h in ipairs({-1, 1}) do for _, v in ipairs({-1, 1}) do
    if cnt == 2 and k(h, 0) and k(0, v) and not k(h, v) then local n = top(x, y); local c = darkest(x, y); if c then IMG[n]:drawPixel(x, y, c); ls = ls + 1 end end
  end end
end end end
-- 5. selective interior lines, as in the reference: black lines inside hair become hair-dark #231917, inside the hood/hoodie/chair plum-900 #1A1214
local HAIRC, PLUMC = {}, {}
for _, h in ipairs({"#231917","#332321","#432E2B","#4A3532","#614B49"}) do HAIRC[hex(h)] = true end
for _, h in ipairs({"#261A22","#372931","#3F3039","#483942","#2F232B","#1A1214"}) do PLUMC[hex(h)] = true end
local soft = {}
for y = 1, 126 do for x = 1, 126 do if interiorK(x, y) then
  local nh, np = 0, 0
  for dy = -1, 1 do for dx = -1, 1 do local _, c = top(x+dx, y+dy); if c then if HAIRC[c] then nh = nh + 1 elseif PLUMC[c] then np = np + 1 end end end end
  if nh + np > 0 then soft[#soft+1] = {x, y, top(x, y), nh >= np and hex("#231917") or hex("#1A1214")} end
end end end
for _, p in ipairs(soft) do IMG[p[3]]:drawPixel(p[1], p[2], p[4]) end
print("interior lines softened", #soft)
for _, l in ipairs(spr.layers) do local c = l:cel(1); if c then c.image, c.position = IMG[l.name], Point(0,0) else spr:newCel(l, 1, IMG[l.name], Point(0,0)) end end
spr:saveAs(spr.filename)
print("outline: peeled", peeled, "doubles", #doubles, "spurs", spurs, "notches", notches, "outline px", #adds, "specks", specks, "L-corners", ls)
