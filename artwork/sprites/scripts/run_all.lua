-- Rebuild artwork/sprites/nell-master.aseprite and the review PNGs from the concept art.
-- Run from Aseprite (or the aseprite MCP run_lua_script):  dofile([[<repo>/artwork/sprites/scripts/run_all.lua]])
-- or headless:  aseprite -b --script artwork/sprites/scripts/run_all.lua
-- ROUND (global, default "r4") names the review exports master-<ROUND>-{1x,2x}.png (transparent).
-- BROUND (global, default "r2") names the body exports body-<BROUND>-{idle,typing,idle-blink}.gif and -frames.png.
-- FROUND (global, default "r5") names the face exports faces-<FROUND>-sheet.png, -blinkswap.gif and -<CLOSEUP>-closeup.png.
local here = debug.getinfo(1, "S").source:gsub("^@", "")
local dir = app.fs.filePath(here)
local function run(n) dofile(app.fs.joinPath(dir, n)) end
run("cfg.lua")
app.fs.makeAllDirectories(D)
for _, step in ipairs({"prep.lua", "still2.lua", "build.lua", "hands.lua", "face.lua", "finish.lua", "outline.lua", "orphans.lua", "patch.lua", "tidy.lua"}) do run(step) end
app.open(MASTER)
run("export.lua")
run("faces.lua")          -- face frames + tags and the eyes:closed patch, built from frame 1
run("faces_export.lua")
run("body.lua")           -- body:idle and body:typing after frame 9, with per-frame slice keys
run("body_export.lua")
