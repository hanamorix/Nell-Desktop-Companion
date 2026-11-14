-- Redraw eyes, glasses and mouth as clean shapes on the face/eyes layers (pixels inside EYES rect -> eyes layer, else face layer)
local pc = app.pixelColor
local spr = app.activeSprite
local function hex(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local function layer(n) for _, l in ipairs(spr.layers) do if l.name == n then return l end end end
local LY = {}
for _, n in ipairs({"face", "eyes"}) do local c = layer(n):cel(1); local im = Image(128,128,ColorMode.RGB); im:drawImage(c.image, c.position); LY[n] = {cel = c, img = im} end
local function put(x, y, col)
  local n = (x >= EYES[1] and y >= EYES[2] and x < EYES[1]+EYES[3] and y < EYES[2]+EYES[4]) and "eyes" or "face"
  LY[n].img:drawPixel(x, y, col)
end
local function inE(x, y, cx, cy, rx, ry) local dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry; return dx*dx + dy*dy <= 1 end
local K, Q, P, V, W, T, X, A, I, U = hex("#120D0E"), hex("#F7F0ED"), hex("#E4D8D6"), hex("#622C36"), hex("#A16774"), hex("#CF7D8B"), hex("#EC9394"), hex("#531721"), hex("#B47D83"), hex("#833C47")
local RIM, RIMD, GLARE = hex("#64595B"), hex("#554141"), hex("#AF9295")
local function eye(e)
  -- sclera
  for y = math.floor(e.sy - e.sry - 1), math.ceil(e.sy + e.sry + 1) do for x = math.floor(e.sx - e.srx - 1), math.ceil(e.sx + e.srx + 1) do
    if inE(x, y, e.sx, e.sy, e.srx, e.sry) then put(x, y, (x + 0.5 > e.sx + e.srx * 0.45 and y + 0.5 > e.sy) and P or Q) end
  end end
  -- iris: dark ring, darker top under the lash, lighter bottom
  for y = math.floor(e.iy - e.iry - 1), math.ceil(e.iy + e.iry + 1) do for x = math.floor(e.ix - e.irx - 1), math.ceil(e.ix + e.irx + 1) do
    if inE(x, y, e.ix, e.iy, e.irx, e.iry) and inE(x, y, e.sx, e.sy, e.srx + 1, e.sry + 1) then
      local ring = not (inE(x-1, y, e.ix, e.iy, e.irx, e.iry) and inE(x+1, y, e.ix, e.iy, e.irx, e.iry) and inE(x, y-1, e.ix, e.iy, e.irx, e.iry) and inE(x, y+1, e.ix, e.iy, e.irx, e.iry))
      local c = T
      if ring then c = V elseif y + 0.5 < e.iy - e.iry * 0.3 then c = W elseif y + 0.5 > e.iy + e.iry * 0.45 then c = X end
      put(x, y, c)
    end
  end end
  -- pupil and glint
  for _, p in ipairs(e.pupil) do put(p[1], p[2], A) end
  for _, p in ipairs(e.glint) do put(p[1], p[2], Q) end
  -- upper lash: the top 2 rows of the sclera ellipse become outline, with an outer flick
  for x = math.floor(e.sx - e.srx - 1), math.ceil(e.sx + e.srx + 1) do
    local top
    for y = math.floor(e.sy - e.sry - 1), math.ceil(e.sy + e.sry + 1) do if inE(x, y, e.sx, e.sy, e.srx, e.sry) then top = y; break end end
    if top then put(x, top - 1, K); put(x, top, K) end
  end
  for _, p in ipairs(e.flick) do put(p[1], p[2], K) end
  -- lower lid: the row under the sclera in lid pink
  for x = math.floor(e.sx - e.srx + 1), math.ceil(e.sx + e.srx - 1) do
    local bot
    for y = math.ceil(e.sy + e.sry + 1), math.floor(e.sy - e.sry - 1), -1 do if inE(x, y, e.sx, e.sy, e.srx, e.sry) then bot = y; break end end
    if bot then put(x, bot + 1, I) end
  end
end
local function ringAt(x, y, cx, cy, rx, ry) return inE(x, y, cx, cy, rx, ry) and not (inE(x-1, y, cx, cy, rx, ry) and inE(x+1, y, cx, cy, rx, ry) and inE(x, y-1, cx, cy, rx, ry) and inE(x, y+1, cx, cy, rx, ry)) end
local function rim(r)
  for y = math.floor(r.cy - r.ry - 2), math.ceil(r.cy + r.ry + 2) do for x = math.floor(r.cx - r.rx - 2), math.ceil(r.cx + r.rx + 2) do
    if ringAt(x, y, r.cx, r.cy, r.rx, r.ry) then put(x, y, K)
    elseif ringAt(x, y, r.cx, r.cy, r.rx - 1, r.ry - 1) then put(x, y, (x + 0.5 > r.cx and y + 0.5 > r.cy) and RIMD or RIM) end
  end end
  for _, p in ipairs(r.glare) do put(p[1], p[2], GLARE) end
end
-- pre-clear: inside each lens, old eye colours become shaded skin and old rim pixels become hair; the mouth box becomes skin
local function get(x, y) local n = (x >= EYES[1] and y >= EYES[2] and x < EYES[1]+EYES[3] and y < EYES[2]+EYES[4]) and "eyes" or "face"; return LY[n].img:getPixel(x, y) end
local EYEC = {} for _, h in ipairs({"#F7F0ED","#E4D8D6","#EC9394","#CD636D","#F4B6AC","#622C36","#531721","#833C47","#B47D83","#CF7D8B","#D5A3A2","#A16774","#A74F5E","#AF9295","#7D5257","#DE7379"}) do EYEC[hex(h)] = true end
local SKIN2, HAIR = hex("#F2CDC1"), hex("#432E2B")
for _, r in ipairs(RIM_SPEC) do
  for y = math.floor(r.cy - r.ry - 2), math.ceil(r.cy + r.ry + 2) do for x = math.floor(r.cx - r.rx - 2), math.ceil(r.cx + r.rx + 2) do
    if inE(x, y, r.cx, r.cy, r.rx + 0.8, r.ry + 0.8) then local c = get(x, y)
      if EYEC[c] then put(x, y, SKIN2) elseif c == hex("#614B49") or c == hex("#64595B") or c == hex("#554141") then put(x, y, HAIR) end end
  end end
end
local mc = MOUTH_CLEAR or {MOUTH.x, MOUTH.y, #MOUTH.rows[1], #MOUTH.rows}
for y = mc[2], mc[2] + mc[4] - 1 do for x = mc[1], mc[1] + mc[3] - 1 do put(x, y, hex("#F5D4C9")) end end
for _, e in ipairs(EYE_SPEC) do eye(e) end
for _, r in ipairs(RIM_SPEC) do rim(r) end
for _, p in ipairs(BRIDGE) do put(p[1], p[2], RIM) end
-- mouth
for r, row in ipairs(MOUTH.rows) do for c = 1, #row do local ch = row:sub(c, c)
  local col = ({V = hex("#622C36"), Q = Q, S = hex("#F5D4C9"), K = K})[ch]
  if col then put(MOUTH.x + c - 1, MOUTH.y + r - 1, col) end
end end
for n, l in pairs(LY) do l.cel.image, l.cel.position = l.img, Point(0, 0) end
spr:saveAs(spr.filename)
print("face ok")
