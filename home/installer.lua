local component = require("component")
local fs = require("filesystem")
local shell = require("shell")

if not component.isAvailable("internet") then
  io.stderr:write("No internet card installed.\n")
  return
end

local internet = component.internet

-- IMPORTANT: correct path (reactorctl, not reactorct1)
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

local function printStep(msg) io.write(msg .. "\n") end

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

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local d = f:read("*a")
  f:close()
  return d
end

local function join(a, b)
  if a:sub(-1) == "/" then return a .. b end
  return a .. "/" .. b
end

-- MD5 helper (OpenOS: /bin/md5sum exists in most distros)
local function md5_of_string(s)
  local tmp = "/tmp/reactorctl_md5.tmp"
  local f = io.open(tmp, "w"); f:write(s); f:close()
  local p = io.popen("md5sum " .. tmp)
  local out = p:read("*l") or ""
  p:close()
  fs.remove(tmp)
  return out:match("^(%w+)") or ""
end

local function md5_of_file(path)
  if not fs.exists(path) then return nil end
  local p = io.popen("md5sum " .. path)
  local out = p:read("*l") or ""
  p:close()
  return out:match("^(%w+)") or ""
end

local function loadManifest()
  local manifestUrl = join(BASE, "manifest.lua")
  printStep("Fetching manifest: " .. manifestUrl)
  local src = httpGet(manifestUrl)
  if not src or #src == 0 then return nil end

  local ok, chunk = pcall(load, src, "=manifest")
  if not ok or not chunk then return nil end

  local ok2, list = pcall(chunk)
  if not ok2 or type(list) ~= "table" or #list == 0 then return nil end
  return list
end

local function ensureBaseDirs()
  if not fs.exists(INSTALL_DIR) then fs.makeDirectory(INSTALL_DIR) end
  if not fs.exists(INSTALL_DIR .. "/lib") then fs.makeDirectory(INSTALL_DIR .. "/lib") end
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

-- mode: install | update (default: install)
local mode = (shell.args()[1] or "install"):lower()
if mode ~= "install" and mode ~= "update" then mode = "install" end

ensureBaseDirs()

local files = loadManifest()
if not files then
  files = FALLBACK
  printStep("Manifest not found - using fallback list. Files: " .. tostring(#files))
else
  printStep("Manifest OK. Files: " .. tostring(#files))
end

local okCount, failCount, updCount, skipCount = 0, 0, 0, 0

for _, rel in ipairs(files) do
  local url = join(BASE, rel)
  local dst = join(INSTALL_DIR, rel)

  if mode == "update" then
    -- compare hashes and skip unchanged
    local remote, err = httpGet(url)
    if not remote then
      io.stderr:write("FAILED: " .. rel .. " (" .. tostring(err) .. ")\n")
      failCount = failCount + 1
    else
      local remoteMd5 = md5_of_string(remote)
      local localMd5 = md5_of_file(dst)

      if localMd5 and localMd5 == remoteMd5 then
        printStep("SKIP: " .. rel)
        skipCount = skipCount + 1
      else
        printStep((localMd5 and "UPDATE: " or "NEW: ") .. rel)
        local okW, errW = writeFile(dst, remote)
        if not okW then
          io.stderr:write("WRITE FAILED: " .. rel .. " (" .. tostring(errW) .. ")\n")
          failCount = failCount + 1
        else
          updCount = updCount + 1
          okCount = okCount + 1
        end
      end
    end
  else
    -- install: always download
    printStep("Downloading: " .. rel)
    local body, err = httpGet(url)
    if not body then
      io.stderr:write("FAILED: " .. rel .. " (" .. tostring(err) .. ")\n")
      failCount = failCount + 1
    else
      local okW, errW = writeFile(dst, body)
      if not okW then
        io.stderr:write("WRITE FAILED: " .. rel .. " (" .. tostring(errW) .. ")\n")
        failCount = failCount + 1
      else
        okCount = okCount + 1
      end
    end
  end
end

writeLauncher()

printStep("")
printStep("Done (" .. mode .. ").")
if mode == "update" then
  printStep("Updated/New: " .. updCount .. " | Skipped: " .. skipCount .. " | Failed: " .. failCount)
else
  printStep("OK: " .. okCount .. " | Failed: " .. failCount)
end
printStep("Run: lua /home/reactorctl.lua")
