local M = {}

local component
local gpu
local term

local W, H = 0, 0
local TITLE = "Reactor Control"

local COL = {
  bg = 0x000000,
  text = 0xFFFFFF,
  dim = 0xA0A0A0,
  ok = 0x55FF55,
  bad = 0xFF5555,
  bar = 0x404040,
}

local function clamp(s, n)
  s = tostring(s or "")
  if #s <= n then return s .. string.rep(" ", n - #s) end
  return s:sub(1, n)
end

local function line(y, s)
  gpu.set(1, y, clamp(s, W))
end

function M.init(title)
  component = require("component")
  term = require("term")
  gpu = component.gpu

  TITLE = title or TITLE
  W, H = gpu.getResolution()

  gpu.setBackground(COL.bg)
  gpu.setForeground(COL.text)
  gpu.fill(1, 1, W, H, " ")
end

local function header(alarm)
  gpu.setForeground(alarm and COL.bad or COL.ok)
  line(1, " " .. TITLE .. (alarm and " - ALARM" or " - OK"))
  gpu.setForeground(COL.text)
  line(2, string.rep("-", W))
end

local function footer()
  gpu.setForeground(COL.dim)
  line(H, "Q - quit | R - rediscover")
  gpu.setForeground(COL.text)
end

function M.drawAll(model)
  local alarm = model.alarm and true or false
  header(alarm)

  local y = 3
  local maxRows = H - 3 - 6
  if maxRows < 1 then maxRows = 1 end

  local reactors = model.reactors or {}
  for i = 1, maxRows do
    local r = reactors[i]
    if not r then
      line(y + i - 1, "")
    else
      gpu.setForeground(r.alarm and COL.bad or COL.text)
      local st = r.active and "ON " or "OFF"
      local temp = r.temp and (tostring(math.floor(r.temp + 0.5)) .. "C") or "-"
      local gen = r.gen and tostring(math.floor(r.gen + 0.5)) or "-"
      local cool = "-"
      if r.coolantMax and r.coolantMax > 0 then
        cool = tostring(math.floor((r.coolant / r.coolantMax) * 100 + 0.5)) .. "%"
      end
      line(y + i - 1, string.format(" %s %-16s %-3s T:%-6s G:%-8s Cool:%-4s",
        r.alarm and "!" or " ",
        r.name or "Reactor",
        st, temp, gen, cool
      ))
    end
  end

  gpu.setForeground(COL.text)
  line(y + maxRows, string.rep("-", W))

  local infoY = y + maxRows + 1
  local me = model.me
  if me then
    line(infoY,     "ME: " .. ((me.powered == false) and "offline" or "online"))
    line(infoY + 1, string.format("Stored:%s  Max:%s", tostring(me.stored or "-"), tostring(me.max or "-")))
  else
    line(infoY, "ME: not found")
    line(infoY + 1, "")
  end

  local flux = model.flux
  if flux then
    line(infoY + 3, "Flux: connected")
  else
    line(infoY + 3, "Flux: not found")
  end

  footer()
end

function M.drawHeader(state)
  header(true)
  line(4, state.status or "")
end

function M.drawFooter(text)
  gpu.setForeground(COL.dim)
  line(H, text or "")
  gpu.setForeground(COL.text)
end

return M
