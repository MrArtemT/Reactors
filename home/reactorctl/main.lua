-- /home/reactorctl/main.lua
-- ReactorCTL main (stable module loading, no shell.getRunningProgram)
-- Notes:
-- - Loads local modules via dofile() from /home/reactorctl
-- - Fluid updates every cfg.pollEveryFluid seconds
-- - Reactor polling every cfg.pollEveryReactor seconds
-- - Emergency: if fluid < cfg.minFluid OR no data -> stop ONLY Liquid reactors (Air reactors are ignored)
-- - UI: static drawn once, dynamic fields updated (minimal flicker)

local component = require("component")
local event = require("event")
local term = require("term")
local computer = require("computer")

-- Base dir (fixed to avoid shell.getRunningProgram issues)
local BASE = "/home/reactorctl"
local function load(rel)
  return dofile(BASE .. "/" .. rel)
end

local cfg   = load("config.lua")
local UI    = load("lib/ui.lua")
local Icons = load("lib/icons.lua")
local Dev   = load("lib/devices.lua")
local Log   = load("lib/log.lua")

local gpu = component.gpu
local sw, sh = gpu.getResolution()

-- ---- helpers ----

local function humanMB(mb)
  mb = tonumber(mb) or 0
  if mb >= 1000000 then return string.format("%.1fMB", mb / 1000000) end
  if mb >= 1000 then return string.format("%.1fkB", mb / 1000) end
  return string.format("%dmB", mb)
end

local function safeBeep()
  if not cfg.beepOnAlarm then return end
  -- short tri-beep
  pcall(computer.beep, 1100, 0.12)
  pcall(computer.beep, 900, 0.12)
  pcall(computer.beep, 700, 0.12)
end

-- ---- state ----

local L = Log.new(400)
local devices = Dev.scan(cfg)

local last = {
  alarm = false,
  reactors = {},
  fluid = { amount = nil, err = "no_data" },
}

-- ---- layout (adaptive) ----

local sidebarW = math.max(30, math.floor(sw * 0.28))
if sidebarW > sw - 20 then sidebarW = sw - 20 end

local pad = 2
local mainW = sw - sidebarW - 3
local mainH = sh - 6

local gridCols = 2
local gridRows = 3
local cardW = math.max(24, math.floor((mainW - (pad * (gridCols + 1))) / gridCols))
local cardH = math.max(10, math.floor((mainH - (pad * (gridRows + 1))) / gridRows))

local originX = 2
local originY = 2
local sideX = originX + mainW + 2
local sideY = originY

-- bottom buttons
local btnY = sh - 3
local buttons = {
  { key = "offAll",  label = "Отключить", w = 18, color = cfg.colors.red },
  { key = "onAll",   label = "Запуск",    w = 18, color = cfg.colors.green },
  { key = "restart", label = "Рестарт",   w = 12, color = cfg.colors.orange },
  { key = "exit",    label = "Выход",     w = 10, color = cfg.colors.red },
}

-- theme (single style as requested)
local theme = {
  bg    = cfg.colors.bg,
  panel = cfg.colors.panel,
  card  = cfg.colors.card,
}

-- ---- UI draw ----

local function drawButtons()
  local bx = originX + 2
  for _, b in ipairs(buttons) do
    b.x = bx
    b.y = btnY
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

  UI.box(gpu, originX, originY, mainW, mainH, cfg.colors.border, theme.bg)
  UI.box(gpu, sideX, sideY, sidebarW, sh - 2, cfg.colors.border, theme.bg)
  UI.title(gpu, sideX + 1, sideY, sidebarW - 2, "ПАНЕЛЬ", cfg.colors.text, theme.bg)

  -- reactor cards frames
  local idx = 1
  for r = 1, gridRows do
    for c = 1, gridCols do
      local x = originX + pad + (c - 1) * (cardW + pad)
      local y = originY + pad + (r - 1) * (cardH + pad)
      UI.box(gpu, x, y, cardW, cardH, cfg.colors.border, theme.card)
      -- placeholder title
      UI.text(gpu, x + 2, y + 1, ("Реактор #%d"):format(idx), cfg.colors.text, theme.card)
      idx = idx + 1
    end
  end

  -- bottom bar
  UI.box(gpu, originX, sh - 4, sw - 2, 3, cfg.colors.border, theme.bg)
  UI.title(gpu, originX + 1, sh - 4, sw - 4, "УПРАВЛЕНИЕ", cfg.colors.dim, theme.bg)

  drawButtons()
  Log.push(L, "Запуск программы")
end

local function cardPos(i)
  local r = math.floor((i - 1) / gridCols) + 1
  local c = ((i - 1) % gridCols) + 1
  local x = originX + pad + (c - 1) * (cardW + pad)
  local y = originY + pad + (r - 1) * (cardH + pad)
  return x, y
end

local function clearCardBody(x, y)
  -- clear inside area except borders and title row
  gpu.setBackground(theme.card)
  gpu.fill(x + 1, y + 2, cardW - 2, cardH - 3, " ")
end

local function drawReactorCard(i, data)
  local x, y = cardPos(i)

  -- title row always present
  UI.text(gpu, x + 2, y + 1, ("Реактор #%d"):format(i), cfg.colors.text, theme.card)

  clearCardBody(x, y)

  if not data then
    UI.text(gpu, x + 2, y + 4, "Нет реактора", cfg.colors.dim, theme.card)
    return
  end

  -- icons small & colored
  Icons.draw(gpu, x + 2, y + 3, "heat", cfg.colors.red)
  UI.text(gpu, x + 8, y + 3, "Нагрев: " .. tostring(math.floor(data.temp or 0)) .. "C", cfg.colors.text, theme.card)

  Icons.draw(gpu, x + 2, y + 5, "bolt", cfg.colors.orange)
  UI.text(gpu, x + 8, y + 5, "Ген: " .. tostring(math.floor(data.gen or 0)) .. " RF/t", cfg.colors.text, theme.card)

  Icons.draw(gpu, x + 2, y + 7, "drop", cfg.colors.blue)
  UI.text(gpu, x + 8, y + 7, "Тип: " .. tostring(data.type or "N/A"), cfg.colors.text, theme.card)

  local st = data.active and "Запущен" or "Остановлен"
  UI.text(gpu, x + 2, y + 9, "Статус: " .. st, data.active and cfg.colors.green or cfg.colors.red, theme.card)
end

local function drawSidebar(fluidAmount, fluidErr)
  local x = sideX + 2
  local y = sideY + 2
  local w = sidebarW - 4

  -- INFO block
  UI.box(gpu, x, y, w, 6, cfg.colors.border, theme.panel)
  UI.title(gpu, x + 1, y, w - 2, "Инфо", cfg.colors.dim, theme.panel)
  UI.text(gpu, x + 2, y + 2, "Реакторов: " .. tostring(#devices.reactors), cfg.colors.text, theme.panel)
  UI.text(gpu, x + 2, y + 3, "ME: " .. (devices.meAddr and ("OK " .. devices.meAddr:sub(1, 8)) or "Нет"), cfg.colors.text, theme.panel)
  UI.text(gpu, x + 2, y + 4, "Flux: " .. (devices.fluxAddr and ("OK " .. devices.fluxAddr:sub(1, 8)) or "Нет"), cfg.colors.text, theme.panel)

  y = y + 7

  -- Fluid block
  UI.box(gpu, x, y, w, 7, cfg.colors.border, theme.panel)
  UI.title(gpu, x + 1, y, w - 2, "Жидкость в ME", cfg.colors.dim, theme.panel)

  local ok = (fluidErr == nil)
  local tColor = ok and cfg.colors.blue or cfg.colors.red

  Icons.draw(gpu, x + 2, y + 2, "drop", cfg.colors.blue)
  UI.text(gpu, x + 8, y + 2, cfg.fluid.name .. ": " .. (fluidAmount and humanMB(fluidAmount) or "N/A"), tColor, theme.panel)

  UI.text(gpu, x + 2, y + 4, "minFluid: " .. humanMB(cfg.minFluid), cfg.colors.dim, theme.panel)

  local ratio = 0
  if fluidAmount then ratio = math.min(1, fluidAmount / cfg.minFluid) end
  UI.progress(gpu, x + 2, y + 5, w - 4, ratio, (ratio >= 1 and cfg.colors.green or cfg.colors.red), cfg.colors.border)

  y = y + 8

  -- Log block
  local logH = (sh - 2) - y - 2
  if logH < 6 then logH = 6 end

  UI.box(gpu, x, y, w, logH, cfg.colors.border, theme.panel)
  UI.title(gpu, x + 1, y, w - 2, "Логи", cfg.colors.dim, theme.panel)

  -- clear log inner area
  gpu.setBackground(theme.panel)
  gpu.fill(x + 1, y + 1, w - 2, logH - 2, " ")

  local linesToShow = logH - 2
  local start = math.max(1, #L.lines - linesToShow + 1)

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

-- ---- actions ----

local function shutdownLiquidReactors()
  for i, r in ipairs(devices.reactors) do
    local d = Dev.readReactor(r)
    if d.type ~= "Air" then
      Dev.setReactor(r, false)
      Log.push(L, "АВАРИЯ: выключен реактор #" .. i .. " (Liquid)")
    else
      Log.push(L, "АВАРИЯ: реактор #" .. i .. " Air - пропущен")
    end
  end
end

local function startAllReactors()
  for i, r in ipairs(devices.reactors) do
    Dev.setReactor(r, true)
    Log.push(L, "Запуск: реактор #" .. i)
  end
end

local function stopAllReactors()
  for i, r in ipairs(devices.reactors) do
    Dev.setReactor(r, false)
    Log.push(L, "Отключение: реактор #" .. i)
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

-- ---- polling ----

local nextReactorPoll = 0
local nextFluidPoll = 0

local function pollFluid(now)
  if now < nextFluidPoll then return end
  nextFluidPoll = now + (cfg.pollEveryFluid or 30)

  local amount, err = Dev.readFluidAmount(devices.me, cfg.fluid.name)
  last.fluid.amount = amount
  last.fluid.err = err

  Log.push(L, "ME fluid: " .. (amount and humanMB(amount) or "N/A") .. (err and (" (" .. err .. ")") or ""))
end

local function pollReactors(now)
  if now < nextReactorPoll then return end
  nextReactorPoll = now + (cfg.pollEveryReactor or 1.5)

  local alarm
  if last.fluid.amount ~= nil and last.fluid.err == nil then
    alarm = last.fluid.amount < cfg.minFluid
  else
    -- no data => alarm
    alarm = true
  end

  local snapshot = {}
  for i, r in ipairs(devices.reactors) do
    snapshot[i] = Dev.readReactor(r)
  end
  last.reactors = snapshot

  if alarm and not last.alarm then
    Log.push(L, "АВАРИЯ: мало хладагента - выключаем Liquid реакторы")
    safeBeep()
    shutdownLiquidReactors()
  elseif (not alarm) and last.alarm then
    Log.push(L, "Хладагента достаточно - авария снята")
    pcall(computer.beep, 1300, 0.08)
  end
  last.alarm = alarm

  -- update UI (dynamic only)
  for i = 1, (cfg.maxReactors or 6) do
    drawReactorCard(i, snapshot[i])
  end
  drawSidebar(last.fluid.amount, last.fluid.err)
end

-- ---- main ----

drawStatic()
drawSidebar(nil, "no_data")
for i = 1, (cfg.maxReactors or 6) do
  drawReactorCard(i, nil)
end

local running = true
while running do
  local now = computer.uptime()

  -- fluid updates every 30 sec
  pollFluid(now)
  -- reactors update every ~1.5 sec
  pollReactors(now)

  local ev = { event.pull(0.1) }
  if ev[1] == "touch" then
    local tx, ty = ev[3], ev[4]
    local key = hitButton(tx, ty)
    if key == "offAll" then
      stopAllReactors()
      drawSidebar(last.fluid.amount, last.fluid.err)
    elseif key == "onAll" then
      startAllReactors()
      drawSidebar(last.fluid.amount, last.fluid.err)
    elseif key == "restart" then
      Log.push(L, "Рестарт программы")
      drawSidebar(last.fluid.amount, last.fluid.err)
      os.sleep(0.2)
      term.clear()
      return
    elseif key == "exit" then
      Log.push(L, "Выход")
      drawSidebar(last.fluid.amount, last.fluid.err)
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
