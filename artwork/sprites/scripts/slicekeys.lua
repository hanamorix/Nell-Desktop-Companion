-- Per-frame slice keys. Aseprite's Lua API can't set them (slice.bounds always rewrites the frame-0 key),
-- so this rewrites the slice chunks (0x2022) of a saved .aseprite file directly.
-- SLICE_KEYS(path, keys): keys[name] = { {frame0based, x, y, w, h}, ... } replaces that slice's keys.
-- Slices not named in `keys` are left untouched. Returns a table name -> list of keys as read before the change.
-- SLICE_KEYS(path, {__readonly = true}) only reads the keys.
-- Close the sprite before calling and reopen it after: a later saveAs from the old in-memory sprite drops the keys.
function SLICE_KEYS(path, keys)
  local f = assert(io.open(path, "rb")); local s = f:read("a"); f:close()
  assert(string.unpack("<I2", s, 5) == 0xA5E0, "not an .aseprite file")
  local nframes = string.unpack("<I2", s, 7)
  local out, pos, before = {s:sub(1, 128)}, 129, {}
  for _ = 1, nframes do
    local fsize, fmagic, oldn, dur, _, newn = string.unpack("<I4 I2 I2 I2 I2 I4", s, pos)
    assert(fmagic == 0xF1FA, "bad frame magic")
    local nch = (newn ~= 0) and newn or oldn
    local cpos, chunks = pos + 16, {}
    for _ = 1, nch do
      local csize, ctype = string.unpack("<I4 I2", s, cpos)
      local data = s:sub(cpos + 6, cpos + csize - 1)
      if ctype == 0x2022 then
        local nk, flags, res, nlen = string.unpack("<I4 I4 I4 I2", data)
        local name = data:sub(15, 14 + nlen)
        local p, old = 15 + nlen, {}
        local extra = ((flags & 1) ~= 0 and 16 or 0) + ((flags & 2) ~= 0 and 8 or 0)
        local tails = {}
        for _ = 1, nk do
          local fr, x, y, w, h = string.unpack("<I4 i4 i4 I4 I4", data, p)
          old[#old + 1] = {fr, x, y, w, h}; tails[#tails + 1] = data:sub(p + 20, p + 19 + extra); p = p + 20 + extra
        end
        before[name] = old
        if keys[name] then
          assert(extra == 0, "slice " .. name .. " has 9-patch/pivot data; not supported")
          local parts = {string.pack("<I4 I4 I4 I2", #keys[name], flags, res, nlen), name}
          for _, k in ipairs(keys[name]) do parts[#parts + 1] = string.pack("<I4 i4 i4 I4 I4", k[1], k[2], k[3], k[4], k[5]) end
          data = table.concat(parts)
        end
      end
      chunks[#chunks + 1] = string.pack("<I4 I2", #data + 6, ctype) .. data
      cpos = cpos + csize
    end
    assert(cpos == pos + fsize, "frame size mismatch")
    local body = table.concat(chunks)
    out[#out + 1] = string.pack("<I4 I2 I2 I2 I2 I4", #body + 16, fmagic, oldn, dur, 0, newn) .. body
    pos = pos + fsize
  end
  if not keys.__readonly then
    local all = table.concat(out)
    all = string.pack("<I4", #all) .. all:sub(5)
    f = assert(io.open(path, "wb")); f:write(all); f:close()
  end
  return before
end
