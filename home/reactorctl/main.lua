-- /home/reactorctl/main.lua

local component = require("component")
local event = require("event")
local term = require("term")
local computer = require("computer")

local BASE = "/home/reactorctl"
local function load(rel)
  local ok, res = pcall(dofile, BASE .. "/" .. rel)
  if not ok then error(res) end
  return res
end

local cfg   = load("config.lua")
local UI    = load("lib/ui.lua")
local Icons = load("lib/icons.lua")
local Dev   = load("lib/devices.lua")
local Log   = load("lib/log.lua")

local gpu = component.gpu
local sw, sh = gpu.getResolution()

-- ---------- utils ----------
local function humanMB(mb)
  mb = tonumber(mb) or 0
  if mb >= 1000000 then return string.format("%.1fM", mb / 1000000) end
  if mb >= 1000 then return string.format("%.1fk", mb / 1000) end
  return string.format("%dm", mb)
end

local function beepAlarm()
  if not cfg.beepOnAlarm then return end
  pcall(computer.beep, 1100, 0.10)
  pcall(computer.beep,  900, 0.10)
  pcall(computer.beep,  700, 0.10)
end

-- ---------- state ----------
local L = Log.new(500)
Log.push(L, "Запуск ReactorCTL")

local devices = Dev.scan(cfg)
local lastFluid = { amount = nil, err = "no_data", ts = 0 }
local lastAlarm = false
local lastReactors = {}

-- ---------- layout ----------
local sidebarW = math.max(30, math.floor(sw * 0.28))
if sidebarW > sw - 22 then sidebarW = sw - 22 end

local pad = 2
local mainW = sw - sidebarW - 3
local mainH = sh - 6

local gridCols, gridRows = 2, 3
local cardW = math.max(24, math.floor((mainW - (pad * (gridCols + 1))) / gridCols))
local cardH = math.max(10, math.floor((mainH - (pad * (gridRows + 1))) / gridRows))

local ox, oy = 2, 2
local sx, sy = ox + mainW + 2, oy
local btnY = sh - 3

local buttons = {
  { key = "offAll",  label = "Отключить реакторы", w = 22, color = cfg.colors.red },
  { key = "onAll",   label = "Запуск реакторов",   w = 20, color = cfg.colors.green },
  { key = "theme",   label = "Тема",              w = 10, color = cfg.colors.blue },
  { key = "exit",    label = "Выход",             w = 8,  color = cfg.colors.red },
}

local theme = { bg = cfg.colors.bg, panel = cfg.colors.panel, card = cfg.colors.card }

local function cardPos(i)
  local r = math.floor((i - 1) / gridCols) + 1
  local c = ((i - 1) % gridCols) + 1
  local x = ox + pad + (c - 1) * (cardW + pad)
  local y = oy + pad + (r - 1) * (cardH + pad)
  return x, y
end

-- ---------- draw static ----------
local function drawButtons()
  local bx = ox + 2
  for _, b in ipairs(buttons) do
    b.x, b.y = bx, btnY
    UI.fill(gpu, bx, btnY, b.w, 1, b.color)
    UI.text(gpu, bx + math.max(0, math.floor((b.w - #b.label) / 2)), btnY, b.label, 0x000000, b.color)
    bx = bx + b.w + 2
  end
end

local function drawStatic()
  term.clear()
  gpu.setBackground(theme.bg)
  gpu.setForeground(cfg.colors.text)
  gpu.fill(1, 1, sw, sh, " ")

  UI.box(gpu, 1, 1, sw, sh, cfg.colors.border, theme.bg)
  UI.title(gpu, 2, 1, sw - 2, "РЕАКТОРЫ", cfg.colors.orange, theme.bg)

  UI.box(gpu, ox, oy, mainW, mainH, cfg.colors.border, theme.bg)
  UI.box(gpu, sx, sy, sidebarW, sh - 2, cfg.colors.border, theme.bg)
  UI.title(gpu, sx + 1, sy, sidebarW - 2, "ПАНЕЛЬ", cfg.colors.text, theme.bg)

  local idx = 1
  for r = 1, gridRows do
    for c = 1, gridCols do
      local x, y = cardPos(idx)
      UI.box(gpu, x, y, cardW, cardH, cfg.colors.border, theme.card)
      UI.text(gpu, x + 2, y + 1, ("Реактор #%d"):format(idx), cfg.colors.text, theme.card)
      idx = idx + 1
    end
  end

  UI.box(gpu, ox, sh - 4, sw - 2, 3, cfg.colors.border, theme.bg)
  UI.title(gpu, ox + 1, sh - 4, sw - 4, "УПРАВЛЕНИЕ", cfg.colors.dim, theme.bg)

  drawButtons()
end

-- ---------- draw dynamic ----------
local function clearCardBody(x, y)
  gpu.setBackground(theme.card)
  gpu.fill(x + 1, y + 2, cardW - 2, cardH - 3, " ")
end

local function drawReactorCard(i, d)
  local x, y = cardPos(i)
  UI.text(gpu, x + 2, y + 1, ("Реактор #%d"):format(i), cfg.colors.text, theme.card)
  clearCardBody(x, y)

  if not d then
    UI.text(gpu, x + 2, y + 5, "Нет реактора", cfg.colors.dim, theme.card)
    return
  end

  Icons.draw(gpu, x + 2, y + 3, "heat", cfg.colors.red)
  UI.text(gpu, x + 8, y + 3, "Нагрев: " .. math.floor(d.temp or 0) .. "C", cfg.colors.text, theme.card)

  Icons.draw(gpu, x + 2, y + 5, "bolt", cfg.colors.orange)
  UI.text(gpu, x + 8, y + 5, "Ген: " .. math.floor(d.gen or 0) .. " RF/t", cfg.colors.text, theme.card)

  Icons.draw(gpu, x + 2, y + 7, "drop", cfg.colors.blue)
  UI.text(gpu, x + 8, y + 7, "Тип: " .. tostring(d.type or "N/A"), cfg.colors.text, theme.card)

  local st = d.active and "Запущен" or "Остановлен"
  UI.text(gpu, x + 2, y + 9, "Статус: " .. st, d.active and cfg.colors.green or cfg.colors.red, theme.card)
end

local function drawSidebar()
  local x, y = sx + 2, sy + 2
  local w = sidebarW - 4

  -- Info block
  UI.box(gpu, x, y, w, 6, cfg.colors.border, theme.panel)
  UI.title(gpu, x + 1, y, w - 2, "Инфо", cfg.colors.dim, theme.panel)
  UI.text(gpu, x + 2, y + 2, "Реакторов: " .. tostring(#devices.reactors), cfg.colors.text, theme.panel)
  UI.text(gpu, x + 2, y + 3, "ME: " .. (devices.meAddr and ("OK " .. devices.meAddr:sub(1, 8)) or "Нет"), cfg.colors.text, theme.panel)
  UI.text(gpu, x + 2, y + 4, "Flux: " .. (devices.fluxAddr and ("OK " .. devices.fluxAddr:sub(1, 8)) or "Нет"), cfg.colors.text, theme.panel)

  y = y + 7

  -- Fluid block
  UI.box(gpu, x, y, w, 7, cfg.colors.border, theme.panel)
  UI.title(gpu, x + 1, y, w - 2, "Жидкость в ME", cfg.colors.dim, theme.panel)

  local ok = (lastFluid.err == nil)
  local tColor = ok and cfg.colors.blue or cfg.colors.red

  Icons.draw(gpu, x + 2, y + 2, "drop", cfg.colors.blue)
  UI.text(gpu, x + 8, y + 2, cfg.fluid.name .. ": " .. (lastFluid.amount and humanMB(lastFluid.amount) or "N/A"), tColor, theme.panel)
  UI.text(gpu, x + 2, y + 4, "minFluid: " .. humanMB(cfg.minFluid), cfg.colors.dim, theme.panel)

  local ratio = 0
  if lastFluid.amount then ratio = math.min(1, lastFluid.amount / cfg.minFluid) end
  UI.progress(gpu, x + 2, y + 5, w - 4, ratio, (ratio >= 1 and cfg.colors.green or cfg.colors.red), cfg.colors.border)

  y = y + 8

  -- Log block
  local logH = (sh - 2) - y - 2
  if logH < 8 then logH = 8 end

  UI.box(gpu, x, y, w, logH, cfg.colors.border, theme.panel)
  UI.title(gpu, x + 1, y, w - 2, "Логи", cfg.colors.dim, theme.panel)

  gpu.setBackground(theme.panel)
  gpu.fill(x + 1, y + 1, w - 2, logH - 2, " ")

  local visible = logH - 2
  local start = math.max(1, #L.lines - visible + 1)
  local yy = y + 1

  for i = start, #L.lines do
    local wrapped = Log.wrapLines(L.lines[i], w - 4)
    for _, ln in ipairs(wrapped) do
      if yy >= y + logH - 1 then break end
      UI.text(gpu, x + 2, yy, ln, cfg.colors.text, theme.panel)
      yy = yy + 1
    end
    if yy >= y + logH - 1 then break end
  end
end

-- ---------- control ----------
local function stopAll()
  for i, r in ipairs(devices.reactors) do
    Dev.setReactor(r, false)
    Log.push(L, "Отключение: реактор #" .. i)
  end
end

local function startAll()
  for i, r in ipairs(devices.reactors) do
    Dev.setReactor(r, true)
    Log.push(L, "Запуск: реактор #" .. i)
  end
end

local function emergencyOffLiquid()
  for i, r in ipairs(devices.reactors) do
    local d = Dev.readReactor(r)
    if d and d.type ~= "Air" then
      Dev.setReactor(r, false)
      Log.push(L, "АВАРИЯ: выключен реактор #" .. i .. " (Liquid)")
    else
      Log.push(L, "АВАРИЯ: реактор #" .. i .. " Air - пропущен")
    end
  end
end

local function hitButton(x, y)
  for _, b in ipairs(buttons) do
    if y == b.y and x >= b.x and x < (b.x + b.w) then
      return b.key
    end
  end
  return nil
end

-- ---------- polling ----------
local nextFluidPoll = 0
local nextReactorPoll = 0

local function pollFluid(now)
  if now < nextFluidPoll then return false end
  nextFluidPoll = now + (cfg.pollEveryFluid or 30)

  local amount, err = Dev.readFluidAmount(devices.me, cfg.fluid.name)
  lastFluid.amount = amount
  lastFluid.err = err
  lastFluid.ts = now

  Log.push(L, "ME fluid: " .. (amount and humanMB(amount) or "N/A") .. (err and (" (" .. err .. ")") or ""))
  return true
end

local function pollReactors(now)
  if now < nextReactorPoll then return false end
  nextReactorPoll = now + (cfg.pollEveryReactor or 1.5)

  -- alarm logic
  local alarm
  if lastFluid.amount ~= nil and lastFluid.err == nil then
    alarm = lastFluid.amount < cfg.minFluid
  else
    alarm = true -- no data => alarm
  end

  -- snapshot
  local snap = {}
  for i, r in ipairs(devices.reactors) do
    snap[i] = Dev.readReactor(r)
  end
  lastReactors = snap

  if alarm and not lastAlarm then
    Log.push(L, "АВАРИЯ: мало хладагента - выключаем Liquid реакторы")
    beepAlarm()
    emergencyOffLiquid()
  elseif (not alarm) and lastAlarm then
    Log.push(L, "Хладагента достаточно - авария снята")
    pcall(computer.beep, 1300, 0.08)
  end
  lastAlarm = alarm

  return true
end

-- ---------- run ----------
drawStatic()
drawSidebar()
for i = 1, (cfg.maxReactors or 6) do
  drawReactorCard(i, nil)
end

local running = true
while running do
  local now = computer.uptime()

  local changed = false
  if pollFluid(now) then changed = true end
  if pollReactors(now) then changed = true end

  if changed then
    for i = 1, (cfg.maxReactors or 6) do
      drawReactorCard(i, lastReactors[i])
    end
    drawSidebar()
  end

  local ev = { event.pull(0.1) }
  if ev[1] == "touch" then
    local tx, ty = ev[3], ev[4]
    local key = hitButton(tx, ty)
    if key == "offAll" then
      stopAll()
      drawSidebar()
    elseif key == "onAll" then
      startAll()
      drawSidebar()
    elseif key == "theme" then
      Log.push(L, "Theme toggled")
      drawSidebar()
    elseif key == "exit" then
      Log.push(L, "Выход")
      running = false
    end
  elseif ev[1] == "interrupted" then
    running = false
  end
end

term.clear()
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.set(1, 1, "Stopped.")
