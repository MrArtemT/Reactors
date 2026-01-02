local M = {}

-- No heavy work on require
local component, gpu, term, computer
local Util

local W, H = 0, 0
local TITLE = "Reactor Control"

local COL = {
  bg    = 0x000000,
  text  = 0xFFFFFF,
  dim   = 0xA0A0A0,
  frame = 0x404040,

  ok    = 0x55FF55,
  warn  = 0xFFFF55,
  bad   = 0xFF5555,
  blue  = 0x55AAFF,

  barBg = 0x202020,
}

local last = {} -- cached lines to avoid redraw flicker

local function set(bg, fg)
  gpu.setBackground(bg)
  gpu.setForeground(fg)
end

local function clamp(s, n)
  s = tostring(s or "")
  if #s <= n then
    return s .. string.rep(" ", n - #s)
  end
  return s:sub(1, n)
end

local function put(x, y, s)
  gpu.set(x, y, s)
end

local function line(y, s)
  s = clamp(s, W)
  if last[y] ~= s then
    put(1, y, s)
    last[y] = s
  end
end

local function hline(y)
  line(y, string.rep("-", W))
end

local function box(x, y, w, h, title, fg)
  fg = fg or COL.frame
  set(COL.bg, fg)

  put(x, y, "+" .. string.rep("-", w - 2) .. "+")
  for i = 1, h - 2 do
    put(x, y + i, "|" .. string.rep(" ", w - 2) .. "|")
  end
  put(x, y + h - 1, "+" .. string.rep("-", w - 2) .. "+")

  if title and #title > 0 then
    local t = " " .. title .. " "
    if #t < w - 2 then
      put(x + 2, y, t)
    end
  end

  set(COL.bg, COL.text)
end

local function writeInBox(x, y, w, text, fg)
  fg = fg or COL.text
  set(COL.bg, fg)
  put(x, y, clamp(text, w))
  set(COL.bg, COL.text)
end

local function statusColor(alarm)
  if alarm then return COL.bad end
  return COL.ok
end

function M.init(title)
  component = require("component")
  term      = require("term")
  computer  = require("computer")
  Util      = require("util")
  gpu       = component.gpu

  TITLE = title or TITLE
  W, H = gpu.getResolution()

  set(COL.bg, COL.text)
  gpu.fill(1, 1, W, H, " ")
  last = {}
end

local function drawHeader(model)
  local alarm = model.alarm and true or false
  local rc = model.reactorCount or 0
  local up = model.uptime or 0

  set(COL.bg, statusColor(alarm))
  line(1, " " .. TITLE .. (alarm and " - ALARM" or " - OK"))
  set(COL.bg, COL.dim)
  line(2, string.format(" Reactors: %d   Uptime: %.0fs   R - rediscover   Q - quit", rc, up))
  set(COL.bg, COL.text)
  hline(3)
end

local function drawReactors(model, x, y, w, h)
  box(x, y, w, h, "Reactors", COL.frame)

  local header = string.format(" %-1s %-16s %-3s %-6s %-10s %-6s",
    "", "Name", "St", "Temp", "Gen", "Cool"
  )
  writeInBox(x + 1, y + 1, w - 2, header, COL.dim)

  local list = model.reactors or {}
  local maxRows = h - 3
  for i = 1, maxRows do
    local r = list[i]
    local yy = y + 1 + i
    if not r then
      writeInBox(x + 1, yy, w - 2, "", COL.text)
    else
      local mark = r.alarm and "!" or " "
      local name = Util.padRight(r.name or "Reactor", 16)
      local st   = r.active and "ON " or "OFF"
      local temp = r.temp and (tostring(Util.round(r.temp)) .. "C") or "-"
      temp = Util.padRight(temp, 6)

      local gen = "-"
      if r.gen ~= nil then gen = Util.kfmt(r.gen) .. "EU" end
      gen = Util.padRight(gen, 10)

      local cool = "-"
      if r.coolantMax and r.coolantMax > 0 then
        cool = Util.pct(r.coolant, r.coolantMax)
      end
      cool = Util.padRight(cool, 6)

      local row = string.format(" %-1s %-16s %-3s %-6s %-10s %-6s",
        mark, name, st, temp, gen, cool
      )

      local fg = COL.text
      if r.alarm then fg = COL.bad end

      writeInBox(x + 1, yy, w - 2, row, fg)
    end
  end
end

local function drawEnergy(model, x, y, w, h)
  box(x, y, w, h, "Network", COL.frame)

  local me = model.me
  if me then
    writeInBox(x + 1, y + 1, w - 2, "ME: " .. ((me.powered == false) and "offline" or "online"), COL.blue)

    local stored = me.stored and Util.kfmt(me.stored) or "-"
    local maxp   = me.max and Util.kfmt(me.max) or "-"
    writeInBox(x + 1, y + 2, w - 2, "Stored: " .. stored, COL.text)
    writeInBox(x + 1, y + 3, w - 2, "Max:    " .. maxp,   COL.text)
  else
    writeInBox(x + 1, y + 1, w - 2, "ME: not found", COL.dim)
    writeInBox(x + 1, y + 2, w - 2, "", COL.text)
    writeInBox(x + 1, y + 3, w - 2, "", COL.text)
  end

  local flux = model.flux
  if flux then
    writeInBox(x + 1, y + 5, w - 2, "Flux: connected", COL.blue)
  else
    writeInBox(x + 1, y + 5, w - 2, "Flux: not found", COL.dim)
  end
end

local function drawFooter(model)
  hline(H - 1)
  set(COL.bg, COL.dim)
  line(H, " Keys: Q - quit | R - rediscover | Alarm: auto-shutdown on low coolant (if enabled)")
  set(COL.bg, COL.text)
end

function M.drawAll(model)
  drawHeader(model)

  local topY = 4
  local bottomH = 8
  local listH = H - topY - bottomH
  if listH < 6 then listH = 6 end

  local leftX = 1
  local leftW = W
  drawReactors(model, leftX, topY, leftW, listH)

  local netY = topY + listH
  drawEnergy(model, 1, netY, W, bottomH)

  drawFooter(model)
end

function M.drawHeader(state)
  set(COL.bg, COL.bad)
  line(1, " " .. TITLE .. " - ERROR")
  set(COL.bg, COL.text)
  line(2, tostring(state.status or ""))
end

function M.drawFooter(text)
  set(COL.bg, COL.dim)
  line(H, tostring(text or ""))
  set(COL.bg, COL.text)
end

return M
