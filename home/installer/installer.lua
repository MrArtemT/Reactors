-- installer/installer.lua
local component = require("component")
local shell = require("shell")
local fs = require("filesystem")
local term = require("term")
local computer = require("computer")

local gpu = component.gpu

-- CHANGE THIS: must be raw + correct branch + repo
local BASE = "https://raw.githubusercontent.com/MrArtemT/Reactors/main/"

-- What we install (repo path -> OpenOS path)
local FILES = {
  { "openos/home/reactorctl/main.lua",        "/home/reactorctl/main.lua" },
  { "openos/home/reactorctl/config.lua",      "/home/reactorctl/config.lua" },

  { "openos/home/reactorctl/lib/ui.lua",      "/home/reactorctl/lib/ui.lua" },
  { "openos/home/reactorctl/lib/util.lua",    "/home/reactorctl/lib/util.lua" },
  { "openos/home/reactorctl/lib/log.lua",     "/home/reactorctl/lib/log.lua" },
  { "openos/home/reactorctl/lib/reactor.lua", "/home/reactorctl/lib/reactor.lua" },
  { "openos/home/reactorctl/lib/flux.lua",    "/home/reactorctl/lib/flux.lua" },
  { "openos/home/reactorctl/lib/me.lua",      "/home/reactorctl/lib/me.lua" },
}

-- What we remove on reinstall (only our stuff)
local REMOVE_PATHS = {
  "/home/reactorctl",
  "/home/reactorctl.log",
  "/home/.shrc", -- optional: we rewrite it, but keep remove as "owned"
}

-- UI helpers
local W, H = gpu.getResolution()

local COL = {
  bg = 0x0B0F14,
  frame = 0x2C3E50,
  text = 0xEAECEE,
  dim = 0x95A5A6,
  ok = 0x2ECC71,
  warn = 0xF1C40F,
  err = 0xE74C3C,
  barBg = 0x1F2A36,
  barFill = 0x3498DB,
}

local function set(bg, fg)
  gpu.setBackground(bg)
  gpu.setForeground(fg)
end

local function fill(x, y, w, h, ch)
  gpu.fill(x, y, w, h, ch or " ")
end

local function put(x, y, s)
  gpu.set(x, y, s)
end

local function clamp(s, n)
  s = tostring(s or "")
  if #s <= n then return s .. string.rep(" ", n - #s) end
  return s:sub(1, n)
end

local UI = {
  x = 2,
  y = 2,
  w = math.max(40, math.min(W - 2, 60)),
  h = math.max(14, math.min(H - 2, 18)),
  title = "reactorctl installer",
  status = "Starting...",
  hint = "",
  progress = 0,
  total = 1,
  color = COL.dim,
}

function UI:drawFrame()
  term.clear()
  set(COL.bg, COL.text)
  fill(1, 1, W, H, " ")

  local x, y, w, h = self.x, self.y, self.w, self.h

  set(COL.bg, COL.frame)
  put(x, y, "+" .. string.rep("-", w - 2) .. "+")
  for i = 1, h - 2 do
    put(x, y + i, "|" .. string.rep(" ", w - 2) .. "|")
  end
  put(x, y + h - 1, "+" .. string.rep("-", w - 2) .. "+")

  set(COL.bg, COL.text)
  put(x + 2, y + 1, clamp(self.title, w - 4))

  set(COL.bg, COL.dim)
  put(x + 2, y + h - 2, clamp("Q - abort (if it hangs)", w - 4))
end

function UI:drawProgress()
  local x, y, w, h = self.x, self.y, self.w, self.h

  local barX = x + 2
  local barY = y + 6
  local barW = w - 4

  local pct = 0
  if self.total > 0 then
    pct = math.floor((self.progress / self.total) * 100 + 0.5)
  end
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end

  set(COL.bg, self.color)
  put(barX, y + 3, clamp(self.status, barW))
  set(COL.bg, COL.dim)
  put(barX, y + 4, clamp(self.hint, barW))

  set(COL.barBg, COL.dim)
  fill(barX, barY, barW, 1, " ")

  local fillW = math.floor((barW * pct) / 100)
  if fillW > 0 then
    set(COL.barFill, COL.text)
    fill(barX, barY, fillW, 1, " ")
  end

  set(COL.bg, COL.text)
  put(barX, barY + 2, clamp(string.format("%d/%d (%d%%)", self.progress, self.total, pct), barW))
end

function UI:setStatus(text, color, hint)
  self.status = text or self.status
  self.color = color or self.color
  self.hint = hint or ""
  self:drawFrame()
  self:drawProgress()
end

local function ensureDir(path)
  local dir = path:match("(.+)/[^/]+$")
  if dir and not fs.exists(dir) then
    fs.makeDirectory(dir)
  end
end

local function removePath(path)
  if fs.exists(path) then
    fs.remove(path)
    return true
  end
  return false
end

local function reinstallCleanup()
  local removed = 0
  for i = 1, #REMOVE_PATHS do
    if removePath(REMOVE_PATHS[i]) then removed = removed + 1 end
  end
  return removed
end

local function wget(url, outPath)
  ensureDir(outPath)
  -- -f quiet, -q quiet, but OpenOS wget may vary. keep simple.
  local cmd = string.format("wget -fq %q %q", url, outPath)
  return shell.execute(cmd)
end

local function checkAbort()
  local e = { computer.pullSignal(0) }
  if e[1] == "key_down" then
    local ch = e[3]
    if ch == string.byte("q") or ch == string.byte("Q") then
      return true
    end
  end
  return false
end

local function writeAutorun()
  local f = io.open("/home/.shrc", "w")
  if not f then return false end
  f:write("/home/reactorctl/main.lua\n")
  f:close()
  return true
end

-- Main
UI.total = (#FILES + 4) -- cleanup + folders + download steps + autorun + finish
UI.progress = 0
UI:drawFrame()
UI:drawProgress()

UI.progress = UI.progress + 1
UI:setStatus("Cleaning old installation...", COL.warn)
local removedCount = reinstallCleanup()
if checkAbort() then return end

UI.progress = UI.progress + 1
UI:setStatus("Preparing folders...", COL.dim)
fs.makeDirectory("/home/reactorctl")
fs.makeDirectory("/home/reactorctl/lib")
if checkAbort() then return end

UI.progress = UI.progress + 1
UI:setStatus("Downloading files...", COL.dim, "Source: raw.githubusercontent.com")
if checkAbort() then return end

for i = 1, #FILES do
  local rel = FILES[i][1]
  local dst = FILES[i][2]
  local url = BASE .. rel

  UI.progress = UI.progress + 1
  UI:setStatus("Downloading: " .. rel, COL.dim, dst)

  local ok = wget(url, dst)
  if not ok then
    UI:setStatus("Download failed", COL.err, url)
    set(COL.bg, COL.err)
    put(UI.x + 2, UI.y + UI.h - 4, clamp("Check BASE and paths in repo.", UI.w - 4))
    return
  end

  if checkAbort() then return end
end

UI.progress = UI.progress + 1
UI:setStatus("Writing autorun...", COL.dim, "/home/.shrc")
if not writeAutorun() then
  UI:setStatus("Cannot write /home/.shrc", COL.err, "Check filesystem permissions")
  return
end
if checkAbort() then return end

UI.progress = UI.progress + 1
UI:setStatus("Done", COL.ok, string.format("Removed old items: %d", removedCount))

set(COL.bg, COL.dim)
put(UI.x + 2, UI.y + UI.h - 4, clamp("Rebooting...", UI.w - 4))
computer.beep(1200, 0.08)

shell.execute("reboot")
