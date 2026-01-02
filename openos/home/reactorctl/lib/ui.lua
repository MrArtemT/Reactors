-- /home/reactorctl/lib/ui.lua
local component = require("component")
local term = require("term")
local unicode = require("unicode")

local Util = require("util")

local gpu = component.gpu

local M = {}

local W, H = 0, 0
local TITLE = "Reactor Control"

local function clamp(s, n)
  if not s then return "" end
  s = tostring(s)
  if unicode.len(s) <= n then
    return s .. string.rep(" ", n - unicode.len(s))
  end
  return unicode.sub(s, 1, n)
end

local function put(x, y, s)
  gpu.set(x, y, s)
end

local function line(y, s)
  put(1, y, clamp(s, W))
end

function M.init(title)
  TITLE = title or TITLE
  W, H = gpu.getResolution()

  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  gpu.fill(1, 1, W, H, " ")
end

local function header(alarm)
  gpu.setForeground(alarm and 0xFF5555 or 0x55FF55)
  line(1, " " .. TITLE .. (alarm and " - ALARM" or " - OK"))
  gpu.setForeground(0xFFFFFF)
  line(2, string.rep("-", W))
end

local function footer()
  line(H, "Q - quit | R - rediscover")
end

local function fmtReactorRow(r, width)
  local name = clamp(r.name, 16)
  local st = r.active and "ON " or "OFF"
  local temp = r.temp and (tostring(Util.round(r.temp)) .. "C") or "-"
  local gen = r.gen and (Util.kfmt(r.gen) .. "EU/t") or "-"
  local cool = "-"
  if r.coolantMax and r.coolantMax > 0 then
    cool = Util.pct(r.coolant, r.coolantMax)
  end
  local a = r.alarm and "!" or " "
  local s = string.format("%s %s %s T:%-5s G:%-9s Cool:%-4s", a, name, st, temp, gen, cool)
  return clamp(s, width)
end

local function drawReactors(list, startY, maxRows)
  local y = startY
  local shown = 0
  for i = 1, #list do
    if shown >= maxRows then break end
    local r = list[i]
    if r.alarm then gpu.setForeground(0xFF5555) else gpu.setForeground(0xFFFFFF) end
    line(y, fmtReactorRow(r, W))
    y = y + 1
    shown = shown + 1
  end
  gpu.setForeground(0xFFFFFF)
  while shown < maxRows do
    line(y, "")
    y = y + 1
    shown = shown + 1
  end
end

local function drawFlux(info, y)
  line(y, "Flux: " .. (info and "connected" or "not found"))
  if not info then return y + 2 end
  line(y + 1, "Flux details available (getEnergyInfo/getFluxInfo).")
  return y + 3
end

local function drawME(info, y)
  line(y, "ME: " .. (info and ((info.powered == false) and "offline" or "online") or "not found"))
  if not info then return y + 2 end

  local stored = info.stored and Util.kfmt(info.stored) or "-"
  local max    = info.max and Util.kfmt(info.max) or "-"
  local inAvg  = info.avgIn and Util.kfmt(info.avgIn) or "-"
  local useAvg = info.avgUse and Util.kfmt(info.avgUse) or "-"
  local dem    = info.demand and Util.kfmt(info.demand) or "-"

  line(y + 1, string.format("Power: %s/%s  In:%s  Use:%s  Demand:%s", stored, max, inAvg, useAvg, dem))
  return y + 3
end

function M.drawAll(model)
  local alarm = model.alarm and true or false

  header(alarm)

  local y = 3
  local footerHeight = 1
  local infoBlock = 6
  local maxRows = H - y - infoBlock - footerHeight
  if maxRows < 1 then maxRows = 1 end

  drawReactors(model.reactors or {}, y, maxRows)

  local infoY = y + maxRows + 1
  line(infoY - 1, string.rep("-", W))

  local nextY = infoY
  nextY = drawME(model.me, nextY)
  nextY = drawFlux(model.flux, nextY)

  footer()
end

-- helper for early states
function M.drawHeader(state)
  header(true)
  line(4, state.status or "")
  footer()
end

function M.drawFooter(text)
  line(H, text or "")
end

return M
