local component = require("component")
local event = require("event")
local term = require("term")
local computer = require("computer")

local cfg = require("reactorctl/config")
local UI = require("reactorctl/lib/ui")
local Icons = require("reactorctl/lib/icons")
local Dev = require("reactorctl/lib/devices")
local Log = require("reactorctl/lib/log")

local gpu = component.gpu
local sw, sh = gpu.getResolution()

-- state
local L = Log.new(400)
local devices = Dev.scan(cfg)
local last = {
  fluidAmount = nil,
  alarm = false,
  reactors = {}
}

local function humanMB(mb)
  mb = tonumber(mb) or 0
  if mb >= 1000000 then return string.format("%.1fMB", mb/1000000) end
  if mb >= 1000 then return string.format("%.1fkB", mb/1000) end
  return string.format("%dmB", mb)
end

-- layout (адаптируется)
local sidebarW = math.max(28, math.floor(sw * 0.28))
local pad = 2
local mainW = sw - sidebarW - 3
local mainH = sh - 6

local gridCols = 2
local gridRows = 3
local cardW = math.floor((mainW - (pad*(gridCols+1))) / gridCols)
local cardH = math.floor((mainH - (pad*(gridRows+1))) / gridRows)

local originX = 2
local originY = 2
local sideX = originX + mainW + 2
local sideY = originY

-- clickable buttons bottom
local btnY = sh - 3
local buttons = {
  { key="offAll", label="Отключить",  w=18, color=cfg.colors.red },
  { key="onAll",  label="Запуск",     w=18, color=cfg.colors.green },
  { key="theme",  label="Тема",       w=12, color=cfg.colors.blue },
  { key="restart",label="Рестарт",    w=12, color=cfg.colors.orange },
  { key="exit",   label="Выход",      w=10, color=cfg.colors.red },
}

local theme = { bg=cfg.colors.bg, panel=cfg.colors.panel, card=cfg.colors.card }

local function drawStatic()
  term.clear()
  gpu.setBackground(theme.bg)
  gpu.setForeground(cfg.colors.text)
  gpu.fill(1,1,sw,sh," ")

  -- header
  UI.box(gpu, 1,1, sw, sh, cfg.colors.border, theme.bg)
  UI.title(gpu, 2,1, sw-2, "РЕАКТОРЫ", cfg.colors.orange, theme.bg)

  -- main area frame
  UI.box(gpu, originX, originY, mainW, mainH, cfg.colors.border, theme.bg)

  -- sidebar
  UI.box(gpu, sideX, sideY, sidebarW, sh-2, cfg.colors.border, theme.bg)
  UI.title(gpu, sideX+1, sideY, sidebarW-2, "ПАНЕЛЬ", cfg.colors.text, theme.bg)

  -- cards frames
  local idx = 1
  for r=1,gridRows do
    for c=1,gridCols do
      local x = originX + pad + (c-1)*(cardW + pad)
      local y = originY + pad + (r-1)*(cardH + pad)
      UI.box(gpu, x,y, cardW, cardH, cfg.colors.border, theme.card)
      idx = idx + 1
    end
  end

  -- bottom bar
  UI.box(gpu, originX, sh-4, sw-2, 3, cfg.colors.border, theme.bg)
  UI.title(gpu, originX+1, sh-4, sw-4, "УПРАВЛЕНИЕ", cfg.colors.dim, theme.bg)

  -- buttons
  local bx = originX + 2
  for _,b in ipairs(buttons) do
    b.x = bx
    b.y = btnY
    UI.fill(gpu, bx, btnY, b.w, 1, b.color)
    UI.text(gpu, bx + math.max(0, math.floor((b.w-#b.label)/2)), btnY, b.label, 0x0, b.color)
    bx = bx + b.w + 2
  end

  Log.push(L, "Запуск программы")
end

local function drawSidebar(fluidAmount, fluidErr)
  local x = sideX + 2
  local y = sideY + 2
  local w = sidebarW - 4

  -- блок INFO
  UI.box(gpu, x, y, w, 6, cfg.colors.border, theme.panel)
  UI.title(gpu, x+1, y, w-2, "Инфо", cfg.colors.dim, theme.panel)

  UI.text(gpu, x+2, y+2, "Реакторов: "..tostring(#devices.reactors), cfg.colors.text, theme.panel)
  UI.text(gpu, x+2, y+3, "ME: "..(devices.meAddr and ("OK "..devices.meAddr:sub(1,8)) or "Нет"), cfg.colors.text, theme.panel)
  UI.text(gpu, x+2, y+4, "Flux: "..(devices.fluxAddr and ("OK "..devices.fluxAddr:sub(1,8)) or "Нет"), cfg.colors.text, theme.panel)

  y = y + 7

  -- блок Fluid
  UI.box(gpu, x, y, w, 7, cfg.colors.border, theme.panel)
  UI.title(gpu, x+1, y, w-2, "Жидкость в ME", cfg.colors.dim, theme.panel)

  local ok = (fluidErr == nil)
  local titleColor = ok and cfg.colors.blue or cfg.colors.red

  Icons.draw(gpu, x+2, y+2, "drop", cfg.colors.blue)
  UI.text(gpu, x+8, y+2, cfg.fluid.name..": "..(fluidAmount and humanMB(fluidAmount) or "N/A"), titleColor, theme.panel)

  UI.text(gpu, x+2, y+4, "minFluid: "..humanMB(cfg.minFluid), cfg.colors.dim, theme.panel)

  local ratio = 0
  if fluidAmount then ratio = math.min(1, fluidAmount / cfg.minFluid) end
  UI.progress(gpu, x+2, y+5, w-4, ratio, (ratio>=1 and cfg.colors.green or cfg.colors.red), cfg.colors.border)

  y = y + 8

  -- блок Log
  local logH = (sh-2) - y - 2
  UI.box(gpu, x, y, w, logH, cfg.colors.border, theme.panel)
  UI.title(gpu, x+1, y, w-2, "Логи", cfg.colors.dim, theme.panel)

  local linesToShow = logH - 2
  local start = math.max(1, #L.lines - linesToShow + 1)
  local yy = y + 1
  for i=start,#L.lines do
    local wrapped = Log.wrapLines(L.lines[i], w-4)
    for _,ln in ipairs(wrapped) do
      if yy >= y + logH - 1 then break end
      UI.text(gpu, x+2, yy, ln, cfg.colors.text, theme.panel)
      yy = yy + 1
    end
    if yy >= y + logH - 1 then break end
  end
end

local function drawReactorCard(i, data)
  local r = math.floor((i-1)/gridCols) + 1
  local c = ((i-1) % gridCols) + 1
  local x = originX + pad + (c-1)*(cardW + pad)
  local y = originY + pad + (r-1)*(cardH + pad)

  -- заголовок
  UI.text(gpu, x+2, y+1, "Реактор #"..tostring(i), cfg.colors.text, theme.card)

  if not data then
    UI.text(gpu, x+2, y+3, "Нет реактора", cfg.colors.dim, theme.card)
    return
  end

  -- иконки маленькие, цветные
  Icons.draw(gpu, x+2, y+3, "heat", cfg.colors.red)
  UI.text(gpu, x+8, y+3, "Нагрев: "..tostring(math.floor(data.temp)).."C", cfg.colors.text, theme.card)

  Icons.draw(gpu, x+2, y+5, "bolt", cfg.colors.orange)
  UI.text(gpu, x+8, y+5, "Ген: "..tostring(math.floor(data.gen)).." RF/t", cfg.colors.text, theme.card)

  Icons.draw(gpu, x+2, y+7, "drop", cfg.colors.blue)
  UI.text(gpu, x+8, y+7, "Тип: "..data.type, cfg.colors.text, theme.card)

  local st = data.active and "Запущен" or "Остановлен"
  UI.text(gpu, x+2, y+9, "Статус: "..st, data.active and cfg.colors.green or cfg.colors.red, theme.card)
end

local function shutdownLiquidReactors()
  for i,r in ipairs(devices.reactors) do
    local d = Dev.readReactor(r)
    if d.type ~= "Air" then
      Dev.setReactor(r, false)
      Log.push(L, "АВАРИЯ: выключен реактор #"..i.." (Liquid)")
    else
      Log.push(L, "АВАРИЯ: реактор #"..i.." Air - пропущен")
    end
  end
end

local function startAllReactors()
  for i,r in ipairs(devices.reactors) do
    Dev.setReactor(r, true)
    Log.push(L, "Запуск: реактор #"..i)
  end
end

local function stopAllReactors()
  for i,r in ipairs(devices.reactors) do
    Dev.setReactor(r, false)
    Log.push(L, "Отключение: реактор #"..i)
  end
end

-- timers
local nextReactorPoll = 0
local nextFluidPoll = 0
local cachedFluid = { amount=nil, err="no_data" }

local function update()
  local now = computer.uptime()

  -- Fluid poll раз в 30 сек
  if now >= nextFluidPoll then
    nextFluidPoll = now + cfg.pollEveryFluid
    local amount, err = Dev.readFluidAmount(devices.me, cfg.fluid.name)
    cachedFluid.amount = amount
    cachedFluid.err = err
    Log.push(L, "ME fluid обновлен: "..(amount and humanMB(amount) or "N/A")..(err and (" ("..err..")") or ""))
  end

  -- Reactor poll чаще
  if now >= nextReactorPoll then
    nextReactorPoll = now + cfg.pollEveryReactor

    local alarm = false
    if cachedFluid.amount ~= nil and cachedFluid.err == nil then
      alarm = cachedFluid.amount < cfg.minFluid
    else
      -- если нет данных - считаем аварией (как у тебя было по смыслу)
      alarm = true
    end

    -- реакторы
    local snapshot = {}
    for i,r in ipairs(devices.reactors) do
      snapshot[i] = Dev.readReactor(r)
    end

    -- реакция на аварию (только если поменялось состояние)
    if alarm and not last.alarm then
      Log.push(L, "АВАРИЯ: мало хладагента - выключаем Liquid реакторы")
      if cfg.beepOnAlarm then computer.beep(1000, 0.2); computer.beep(800, 0.2); computer.beep(600, 0.2) end
      shutdownLiquidReactors()
    end

    if (not alarm) and last.alarm then
      Log.push(L, "Хладагента достаточно - авария снята")
      if cfg.beepOnAlarm then computer.beep(1200, 0.08) end
    end

    last.alarm = alarm
    last.reactors = snapshot

    -- перерисовка только динамики
    for i=1, cfg.maxReactors do
      drawReactorCard(i, snapshot[i])
    end
    drawSidebar(cachedFluid.amount, cachedFluid.err)
  end
end

local function hitButton(x,y)
  for _,b in ipairs(buttons) do
    if y == b.y and x >= b.x and x < b.x + b.w then
      return b.key
    end
  end
  return nil
end

-- main
drawStatic()
drawSidebar(nil, "no_data")
for i=1, cfg.maxReactors do drawReactorCard(i, nil) end

local running = true
while running do
  local ev = { event.pull(0.1) }
  if ev[1] == "touch" then
    local tx, ty = ev[3], ev[4]
    local key = hitButton(tx, ty)
    if key == "offAll" then stopAllReactors()
    elseif key == "onAll" then startAllReactors()
    elseif key == "theme" then
      -- одна тема, без "второго стиля" (как ты просил)
      Log.push(L, "Тема: без переключения (фикс)")
    elseif key == "restart" then
      Log.push(L, "Рестарт программы")
      os.sleep(0.2)
      return
    elseif key == "exit" then
      Log.push(L, "Выход")
      running = false
    end
  elseif ev[1] == "key_down" then
    local ch = ev[3]
    if ch == 113 then running = false end -- q
  end

  update()
end

term.clear()
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
