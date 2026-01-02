local component = require("component")
local fs = require("filesystem")
local shell = require("shell")

if not component.isAvailable("internet") then
  io.stderr:write("No internet card installed.\n")
  return
end

local internet = component.internet

-- Repo base (raw)
local BASE = "https://raw.githubusercontent.com/MrArtemT/Reactors/main/home/reactorctl/"

-- Install dir
local INSTALL_DIR = "/home/reactorctl"

-- Fallback list (если manifest.lua не найден) - поправь под свои реальные файлы
local FALLBACK = {
  "main.lua",
  "config.lua",
  "lib/ui.lua",
  "lib/icons.lua",
  "lib/devices.lua",
  "lib/log.lua",
}

local function readAll(handle)
  local chunks = {}
  while true do
    local data = handle.read(math.huge)
    if not data then break end
    chunks[#chunks + 1] = data
  end
  handle.close()
  return table.concat(chunks)
end

local function httpGet(url)
  local h, err = internet.request(url)
  if not h then return nil, err end
  return readAll(h)
end

local function ensureDir(path)
  local dir = fs.path(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDirectory(dir)
  end
end

local function writeFile(path, data)
  ensureDir(path)
  local f, err = io.open(path, "w")
  if not f then return nil, err end
  f:write(data)
  f:close()
  return true
end

local function join(a, b)
  if a:sub(-1) == "/" then return a .. b end
  return a .. "/" .. b
end

local function printStep(msg)
  io.write(msg .. "\n")
end

-- 1) Create base dir
if not fs.exists(INSTALL_DIR) then
  fs.makeDirectory(INSTALL_DIR)
end
if not fs.exists(INSTALL_DIR .. "/lib") then
  fs.makeDirectory(INSTALL_DIR .. "/lib")
end

-- 2) Try load manifest.lua
local files = nil
do
  local manifestUrl = join(BASE, "manifest.lua")
  printStep("Fetching manifest: " .. manifestUrl)
  local src = httpGet(manifestUrl)
  if src and #src > 0 and src:find("return", 1, true) then
    local ok, chunk = pcall(load, src, "=manifest")
    if ok and chunk then
      local ok2, list = pcall(chunk)
      if ok2 and type(list) == "table" and #list > 0 then
        files = list
        printStep("Manifest OK. Files: " .. tostring(#files))
      end
    end
  end
end

if not files then
  files = FALLBACK
  printStep("Manifest not found - using fallback list. Files: " .. tostring(#files))
end

-- 3) Download files
local okCount, failCount = 0, 0
for _, rel in ipairs(files) do
  local url = join(BASE, rel)
  local dst = join(INSTALL_DIR, rel)
  printStep("Downloading: " .. rel)

  local body, err = httpGet(url)
  if not body then
    io.stderr:write("  FAILED: " .. tostring(err) .. "\n")
    failCount = failCount + 1
  else
    local okW, errW = writeFile(dst, body)
    if not okW then
      io.stderr:write("  WRITE FAILED: " .. tostring(errW) .. "\n")
      failCount = failCount + 1
    else
      okCount = okCount + 1
    end
  end
end

-- 4) Launcher
local launcherPath = "/home/reactorctl.lua"
local launcher = ([[-- ReactorCTL launcher
local ok, err = pcall(dofile, "%s/main.lua")
if not ok then
  io.stderr:write("ReactorCTL failed: " .. tostring(err) .. "\n")
end
]]):format(INSTALL_DIR)

writeFile(launcherPath, launcher)

printStep("")
printStep("Install complete.")
printStep("OK: " .. okCount .. " | Failed: " .. failCount)
printStep("Run: lua /home/reactorctl.lua")
