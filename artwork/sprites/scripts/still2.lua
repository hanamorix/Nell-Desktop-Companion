-- Material-aware still: 3x3 line-preserving shrink of the masked source; each pixel is classed (outline, skin, white, eye, hair, plum, chair, desk, laptop)
-- and plum/hair/chair/desk are posterised onto fixed reference ramps by luminance quantile; then a majority filter per material and an orphan merge.
local pc = app.pixelColor
local function load(p) local s = app.open(p); local im = Image(s.width, s.height, ColorMode.RGB); im:drawSprite(s, 1); return im end
local big, msk = load(D .. "src.png"), load(D .. "mask.png")
local function hex(h) return {tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16)} end
local function d2(a, b) local r, g, bl = a[1]-b[1], a[2]-b[2], a[3]-b[3]; return 2*r*r + 4*g*g + 3*bl*bl end
local function near(c, set) local best, bd = 1, math.huge; for k, p in ipairs(set) do local d = d2(c, p); if d < bd then bd, best = d, k end end; return set[best] end
local function lum(c) return (3*c[1]+6*c[2]+c[3])/10 end
local RAMP = {}; for k, v in pairs(RAMPS) do RAMP[k] = {}; for i, h in ipairs(v) do RAMP[k][i] = hex(h) end end
local FACE = {}; for _, h in ipairs(FACEPAL) do FACE[#FACE+1] = hex(h) end
local OUTL = hex("#120D0E")
local W = 128
local mat, col, L = {}, {}, {}
local function inPoly(px, py, poly)
  local inside, j = false, #poly
  for i = 1, #poly do local xi, yi, xj, yj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
    if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then inside = not inside end; j = i end
  return inside
end
for y = 0, W-1 do for x = 0, W-1 do
  local i = y*W + x
  local sr, sg, sb, n, mL, mc = 0, 0, 0, 0, 1e9, nil
  for dy = 0, 2 do for dx = 0, 2 do
    local X, Y = x*3+dx, y*3+dy
    if pc.rgbaR(msk:getPixel(X, Y)) > 128 then
      local c = big:getPixel(X, Y); local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
      sr, sg, sb, n = sr+r, sg+g, sb+b, n+1
      local l = (3*r+6*g+b)/10; if l < mL then mL, mc = l, {r,g,b} end
    end
  end end
  if n >= 5 then
    local a = {sr/n, sg/n, sb/n}
    local c = (lum(a) - mL > (LINE_T or 45)) and mc or a
    local l = lum(c); L[i] = l
    local px, py = x + 0.5, y + 0.5
    local m
    if l < (OUT_L or 38) then m = "out"
    elseif inPoly(px, py, LAPTOP) and not (l > 150 and c[1]-c[3] > 25) then m = "laptop"
    elseif py >= DESK_Y and c[1]-c[3] > 22 and l < 175 then m = "desk"
    elseif l > 150 or c[1] - c[2] > 55 then m = "face"
    elseif c[1] - c[3] > (HAIR_RB or 14) then m = "hair"
    elseif inPoly(px, py, CHAIR) then m = "chair"
    else m = "plum" end
    mat[i], col[i] = m, c
  end
end end
-- quantile thresholds per ramp material
local function thresholds(m, q)
  local ls = {}; for i, mm in pairs(mat) do if mm == m then ls[#ls+1] = L[i] end end
  table.sort(ls); local t = {}
  for k, f in ipairs(q) do t[k] = ls[math.max(1, math.floor(#ls * f))] or 0 end
  return t, #ls
end
local TH = {}
for m, q in pairs(QUANT) do local t, cnt = thresholds(m, q); TH[m] = t; print(m, cnt, table.concat(t, " ")) end
local idx = {}
for i, m in pairs(mat) do
  if TH[m] then local k = 1; for j, t in ipairs(TH[m]) do if L[i] > t then k = j + 1 end end; idx[i] = k end
end
-- majority filter on ramp index inside each ramp material (flats)
for pass = 1, (MAJ or 1) do
  local nidx = {}
  for i, m in pairs(mat) do
    if TH[m] then
      local x, y = i % W, i // W; local cnt = {}
      for dy = -1, 1 do for dx = -1, 1 do local j = (y+dy)*W + (x+dx)
        if x+dx >= 0 and x+dx < W and mat[j] == m then cnt[idx[j]] = (cnt[idx[j]] or 0) + 1 end end end
      local best, bc = idx[i], cnt[idx[i]] or 0
      for k, v in pairs(cnt) do if v > bc + 1 then best, bc = k, v end end
      nidx[i] = best
    end
  end
  for i, v in pairs(nidx) do idx[i] = v end
end
local out = Image(W, W, ColorMode.RGB)
for i, m in pairs(mat) do
  local x, y = i % W, i // W; local cc
  if m == "out" then cc = OUTL elseif TH[m] then cc = RAMP[m][idx[i]] else cc = near(col[i], m == "laptop" and RAMP.laptopnear or FACE) end
  out:drawPixel(x, y, pc.rgba(cc[1], cc[2], cc[3], 255))
end
-- orphan merge outside the face box
local res, merged = out:clone(), 0
for y = 0, W-1 do for x = 0, W-1 do
  local c = out:getPixel(x, y)
  if pc.rgbaA(c) > 0 and not (x >= FACEBOX[1] and y >= FACEBOX[2] and x < FACEBOX[1]+FACEBOX[3] and y < FACEBOX[2]+FACEBOX[4]) then
    local orphan, best, bd = true, nil, math.huge
    for dy = -1, 1 do for dx = -1, 1 do if dx ~= 0 or dy ~= 0 then
      local nx, ny = x+dx, y+dy
      if nx >= 0 and ny >= 0 and nx < W and ny < W then
        local nc = out:getPixel(nx, ny)
        if pc.rgbaA(nc) > 0 then
          if nc == c then orphan = false end
          local dd = d2({pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)}, {pc.rgbaR(nc),pc.rgbaG(nc),pc.rgbaB(nc)})
          if dd < bd then bd, best = dd, nc end
        end
      end
    end end end
    if orphan and best and bd < 6000 then res:drawPixel(x, y, best); merged = merged + 1 end
  end
end end
local spr = Sprite(W, W, ColorMode.RGB)
spr.layers[1].name = "Art"
spr.cels[1].image = res
-- material map as a second sprite for layer splitting later
local mm = Image(W, W, ColorMode.RGB)
local MC = {out={0,0,0}, laptop={0,0,255}, desk={255,128,0}, face={255,0,255}, hair={128,64,0}, chair={0,255,0}, plum={128,0,128}}
for i, m in pairs(mat) do local c = MC[m]; mm:drawPixel(i % W, i // W, pc.rgba(c[1], c[2], c[3], 255)) end
spr:saveAs(D .. OUTN .. ".aseprite")
mm:saveAs(D .. OUTN .. "_mat.png")
print("merged", merged)
