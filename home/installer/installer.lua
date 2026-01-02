-- installer/installer.lua
local shell = require("shell")
local fs = require("filesystem")

-- CHANGE THIS:
-- Use raw, not github tree/blob.
local BASE = "https://raw.githubusercontent.com/MrArtemT/Reactors/refs/heads/main/"

local FILES = {
  { "openos/home/reactorctl/main.lua",       "/home/reactorctl/main.lua" },
  { "openos/home/reactorctl/config.lua",     "/home/reactorctl/config.lua" },

  { "openos/home/reactorctl/lib/ui.lua",     "/home/reactorctl/lib/ui.lua" },
  { "openos/home/reactorctl/lib/util.lua",   "/home/reactorctl/lib/util.lua" },
  { "openos/home/reactorctl/lib/log.lua",    "/home/reactorctl/lib/log.lua" },
  { "openos/home/reactorctl/lib/reactor.lua","/home/reactorctl/lib/reactor.lua" },
  { "openos/home/reactorctl/lib/flux.lua",   "/home/reactorctl/lib/flux.lua" },
  { "openos/home/reactorctl/lib/me.lua",     "/home/reactorctl/lib/me.lua" },
}

local function ensureDir(path)
  local dir = path:match("(.+)/[^/]+$")
  if dir and not fs.exists(dir) then
    fs.makeDirectory(dir)
  end
end

local function wget(url, outPath)
  ensureDir(outPath)
  local cmd = string.format("wget -fq %q %q", url, outPath)
  local ok = shell.execute(cmd)
  return ok
end

local function reinstall()
  if fs.exists("/home/reactorctl") then
    fs.remove("/home/reactorctl")
  end
  fs.makeDirectory("/home/reactorctl")
  fs.makeDirectory("/home/reactorctl/lib")
end

local function installFiles()
  for i = 1, #FILES do
    local rel, dst = FILES[i][1], FILES[i][2]
    local url = BASE .. rel
    local ok = wget(url, dst)
    if not ok then
      io.stderr:write("Install failed:\n- " .. url .. "\n")
      io.stderr:write("Tip: check BASE raw url and file paths in repo.\n")
      return false
    end
  end
  return true
end

local function setAutorun()
  local f = io.open("/home/.shrc", "w")
  if f then
    f:write("/home/reactorctl/main.lua\n")
    f:close()
  end
end

print("reactorctl installer")
print("Reinstalling...")
reinstall()

print("Downloading...")
if not installFiles() then
  return
end

setAutorun()
print("Installed OK. Rebooting...")
shell.execute("reboot")
