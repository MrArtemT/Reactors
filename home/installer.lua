local component = require("component")
local fs = require("filesystem")

if not component.isAvailable("internet") then
  io.stderr:write("No internet card installed.\n")
  return
end

local internet = component.internet

-- RAW base URL (проверь путь!)
local BASE = "https://raw.githubusercontent.com/MrArtemT/Reactors/main/home/reactorctl/"
local INSTALL_DIR = "/home/reactorctl"

local FALLBACK = {
  "main.lua",
  "config.lua",
  "lib/ui.lua",
  "lib/icons.lua",
  "lib/devices.lua",
  "lib/log.lua",
}

local function join(a, b)
  if a:sub(-1) == "/" then return a .. b end
  return a .. "/" .. b
end

local function readAll(handle)
  local out = {}
  while true do
    local chunk = handle.read(8192)
    if not chunk then break end
    out[#out+1] = chunk
  end
  handle.close()
  return table.concat(out)
end

local function httpGet(url)
  local h, err = internet.request(url)
  if not h then return nil, err end
  local ok, body = pcall(readAll, h)
  if not ok then return nil, body end
  return body, nil
end

local function ensureDirFor(path)
  local dir = fs.path(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDirectory(dir)
  end
end

local function writeFile(path, data)
  ensureDirFor(path)
  local f, err = io.open(path, "w")
  if not f then return nil, err end
  f:write(data)
  f:close()
  return true
end

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local d = f:read("*a")
  f:close()
  return d
end

local function println(s) io.write(tostring(s).."\n") end

local function ensureDirs()
  if not fs.exists(INSTALL_DIR) then fs.makeDirectory(INSTALL_DIR) end
  if not fs.exists(INSTALL_DIR.."/lib") then fs.makeDirectory(INSTALL_DIR.."/lib") end
end

local function loadManifest()
  local url = join(BASE, "manifest.lua")
  println("Fetching manifest: " .. url)
  local src = httpGet(url)
  if not src or #src == 0 then return nil end

  local ok, chunk = pcall(load, src, "=manifest")
  if not ok or not chunk then return nil end

  local ok2, list = pcall(chunk)
  if not ok2 or type(list) ~= "table" or #list == 0 then return nil end
  return list
end

local function writeLauncher()
  local launcherPath = "/home/reactorctl.lua"
  local launcher = ([[-- ReactorCTL launcher
local ok, err = pcall(dofile, "%s/main.lua")
if not ok then
  io.stderr:write("ReactorCTL failed: " .. tostring(err) .. "\n")
end
]]):format(INSTALL_DIR)

  writeFile(launcherPath, launcher)
end

-- MODE: install / update (берём из {...}, без shell/process)
local args = {...}
local mode = tostring(args[1] or "install"):lower()
if mode ~= "install" and mode ~= "update" then mode = "install" end

ensureDirs()

local files = loadManifest()
if not files then
  files = FALLBACK
  println("Manifest not found - using fallback list. Files: " .. tostring(#files))
else
  println("Manifest OK. Files: " .. tostring(#files))
end

local updated, skipped, failed = 0, 0, 0

for _, rel in ipairs(files) do
  local url = join(BASE, rel)
  local dst = join(INSTALL_DIR, rel)

  local remote, err = httpGet(url)
  if not remote then
    io.stderr:write("FAILED: "..rel.." ("..tostring(err)..")\n")
    failed = failed + 1
  else
    if mode == "update" then
      local localData = readFile(dst)
      if localData ~= nil and localData == remote then
        println("SKIP: " .. rel)
        skipped = skipped + 1
      else
        println((localData and "UPDATE: " or "NEW: ") .. rel)
        local okW, errW = writeFile(dst, remote)
        if not okW then
          io.stderr:write("WRITE FAILED: "..rel.." ("..tostring(errW)..")\n")
          failed = failed + 1
        else
          updated = updated + 1
        end
      end
    else
      println("Downloading: " .. rel)
      local okW, errW = writeFile(dst, remote)
      if not okW then
        io.stderr:write("WRITE FAILED: "..rel.." ("..tostring(errW)..")\n")
        failed = failed + 1
      else
        updated = updated + 1
      end
    end
  end
end

writeLauncher()

println("")
println("Done ("..mode.."). Updated/New: "..updated.." | Skipped: "..skipped.." | Failed: "..failed)
println("Run: lua /home/reactorctl.lua")
