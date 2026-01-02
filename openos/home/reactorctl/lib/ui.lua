local UI = {}

local component = require("component")
local event = require("event")
local term = require("term")
local computer = require("computer")
local gpu = component.gpu
local U = require("util")

-- Colors (close to the reference)
local C = {
  bg = 0xB0B0B0,        -- main gray
  panel = 0x8F8F8F,     -- inner gray
  dark = 0x1A1A1A,      -- sidebar bg
  black = 0x000000,
  white = 0xFFFFFF,
  text = 0xE6E6E6,
  yellow = 0xFFB000,
  red = 0xD84040,
  red2 = 0xB83030,
  green = 0x2DBE4A,
  blue = 0x2A7DFF,
  cyan = 0x28C5FF,
  border = 0x5A5A5A,
}

local W, H = gpu.getResolution()

-- simple button system
local buttons = {}

local function set(bg, fg)
  gpu.setBackground(bg)
  gpu.setForeground(fg)
end

local function fill(x, y, w, h, ch)
  gpu.fill(x, y, w, h, ch or " ")
end

local function rect(x, y, w, h, bg, border)
  set(bg, border or C.border)
  gpu.set(x, y, "+" .. string.rep("-", w - 2) .. "+")
  for i = 1, h - 2 do
    gpu.set(x, y + i, "|")
    gpu.set(x + w - 1, y + i, "|")
  end
  gpu.set(x, y + h - 1, "+" .. string.rep("-", w - 2) .. "+")
  set(bg, C.white)
end

local function label(x, y, s, fg, bg)
  set(bg or gpu.getBackground(), fg or gpu.getForeground())
  gpu.set(x, y, s)
end

local function addBtn(id, x, y, w, h, text, bg, fg)
  buttons[#buttons + 1] = {
    id = id, x = x, y = y, w = w, h = h,
    text = text, bg = bg, fg = fg
  }
end

local function drawBtn(b)
  rect(b.x, b.y, b.w, b.h, b.bg, C.border)
  local tx = b.x + math.floor((b.w - #b.text) / 2)
  local ty = b.y + math.floor(b.h / 2)
  label(tx, ty, b.text, b.fg, b.bg)
end

local function hit(x, y, b)
  return x >= b.x and x < (b.x + b.w) and y >= b.y and y < (b.y + b.h)
end

local function clearButtons()
  buttons = {}
end

local function header()
  set(C.bg, C.black)
  fill(1, 1, W, 3, " ")
  label(3, 2, "РЕАКТОРЫ", C.yellow, C.bg)
end

local function drawReactorCard(idx, r, x, y, w, h)
  -- outer
  rect(x, y, w, h, C.panel, C.border)

  -- inner black area
  set(C.black, C.white)
  fill(x + 2, y + 1, w - 4, h - 2, " ")

  -- vertical bar (coolant or state)
  local barH = h - 4
  local barX = x + 2
  local barY = y + 2
  local pct = 0
  if r.coolantMax and r.coolantMax > 0 and r.coolant then
    pct = U.clamp(r.coolant / r.coolantMax, 0, 1)
  end
  local filled = math.floor(barH * pct + 0.5)

  -- draw bar bg
  set(C.black, C.blue)
  for i = 0, barH - 1 do
    gpu.set(barX, barY + i, " ")
  end
  -- filled part (bottom up)
  set(C.blue, C.blue)
  for i = 0, filled - 1 do
    gpu.set(barX, barY + (barH - 1 - i), " ")
  end

  -- texts
  set(C.black, C.white)
  label(x + 5, y + 2, "Реактор #" .. tostring(idx), C.white, C.black)

  local temp = r.temp and (tostring(U.round(r.temp)) .. "C") or "-"
  local gen = r.gen and (U.kfmt(r.gen) .. " RF/t") or "-"
  local typ = r.kind or "Fluid"
  local run = r.active and "Да" or "Нет"

  label(x + 5, y + 4, "Нагрев: " .. temp, C.text, C.black)
  label(x + 5, y + 5, "Ген: " .. gen, C.text, C.black)
  label(x + 5, y + 6, "Тип: " .. typ, C.text, C.black)
  label(x + 5, y + 7, "Запущен: " .. run, C.text, C.black)

  -- button
  local btnText = r.active and "Отключить" or "Запустить"
  local btnBg = r.active and C.red or C.green
  local btnFg = C.white

  local bx = x + 5
  local by = y + h - 4
  local bw = w - 10
  local bh = 3
  addBtn("reactor_toggle:" .. tostring(idx), bx, by, bw, bh, btnText, btnBg, btnFg)
end

local function sidebar(model, x, y, w, h)
  rect(x, y, w, h, C.dark, C.border)
  set(C.dark, C.text)
  fill(x + 1, y + 1, w - 2, h - 2, " ")

  local cy = y + 2
  label(x + 2, cy, "Информационное окно:", C.text, C.dark)
  cy = cy + 2

  local logs = model.logs or {}
  local maxLines = 10
  for i = math.max(1, #logs - maxLines + 1), #logs do
    label(x + 2, cy, U.fit(logs[i], w - 4), C.text, C.dark)
    cy = cy + 1
    if cy >= y + 2 + maxLines then break end
  end

  cy = y + 15
  label(x + 2, cy, string.rep("-", w - 4), C.border, C.dark)
  cy = cy + 2

  -- stats blocks (close to reference meaning)
  local me = model.me
  local meLine = "ME: " .. (me and (me.powered == false and "offline" or "online") or "not found")
  label(x + 2, cy, U.fit(meLine, w - 4), C.cyan, C.dark)
  cy = cy + 2

  if me and me.stored and me.max then
    label(x + 2, cy, U.fit("Жидкость в ME: " .. U.kfmt(model.meFluid or 0) .. "Mb", w - 4), C.text, C.dark)
    cy = cy + 1
    label(x + 2, cy, U.fit("Порог: " .. tostring(model.minFluid or "-") .. "Mb", w - 4), C.text, C.dark)
    cy = cy + 2
    label(x + 2, cy, U.fit("Энергия: " .. U.kfmt(me.stored) .. "/" .. U.kfmt(me.max), w - 4), C.text, C.dark)
    cy = cy + 2
  end

  local flux = model.flux
  label(x + 2, cy, U.fit("Flux: " .. (flux and "connected" or "not found"), w - 4), flux and C.green or C.border, C.dark)
  cy = cy + 2

  label(x + 2, cy, U.fit("Генерация всех: " .. U.kfmt(model.totalGen or 0) .. " RF/t", w - 4), C.text, C.dark)
  cy = cy + 2

  label(x + 2, cy, U.fit("Время работы: " .. U.timeFmt(model.uptime or 0), w - 4), C.text, C.dark)
end

local function bottomBar(model, y)
  set(C.bg, C.black)
  fill(1, y, W, 6, " ")

  -- buttons (like reference)
  local bx = 4
  local by = y + 2
  local bw = 20
  local bh = 3
  addBtn("all_off", bx, by, bw, bh, "Отключить реакторы", C.red2, C.white)
  addBtn("all_on", bx + 22, by, bw, bh, "Запуск реакторов", C.green, C.white)

  addBtn("restart", bx, by + 3, bw, bh, "Рестарт программы", C.blue, C.white)
  addBtn("exit", bx + 22, by + 3, bw, bh, "Выход из программы", C.blue, C.white)

  -- status (right in bottom like reference)
  local statusX = 50
  label(statusX, y + 2, "Статус комплекса:", C.text, C.black)
  label(statusX, y + 3, "Кол-во реакторов: " .. tostring(model.reactorCount or 0), C.text, C.black)
  label(statusX, y + 4, "Режим: " .. (model.alarm and "ALARM" or "WORK"), model.alarm and C.red or C.green, C.black)
end

function UI.draw(model)
  term.setCursorBlink(false)
  W, H = gpu.getResolution()
  clearButtons()

  -- background
  set(C.bg, C.black)
  fill(1, 1, W, H, " ")

  -- inner main frame
  rect(1, 1, W, H, C.bg, C.border)

  header()

  -- layout (close to screenshot proportions)
  local sideW = 34
  local mainW = W - sideW - 4
  local mainX = 3
  local mainY = 5
  local mainH = H - 12

  rect(mainX, mainY, mainW, mainH, C.bg, C.border)

  -- cards grid (2 rows)
  local cards = model.reactors or {}
  local cardW = 20
  local cardH = 12
  local gapX = 4
  local gapY = 3

  local cx = mainX + 3
  local cy = mainY + 2
  local perRow = math.floor((mainW - 6) / (cardW + gapX))
  if perRow < 1 then perRow = 1 end

  for i = 1, math.min(#cards, 6) do
    local r = cards[i]
    local col = (i - 1) % perRow
    local row = math.floor((i - 1) / perRow)
    local x = cx + col * (cardW + gapX)
    local y = cy + row * (cardH + gapY)
    if y + cardH < mainY + mainH - 1 then
      drawReactorCard(i, r, x, y, cardW, cardH)
    end
  end

  -- sidebar
  local sideX = mainX + mainW + 1
  sidebar(model, sideX, mainY, sideW, mainH)

  -- bottom
  bottomBar(model, H - 7)

  -- draw all buttons last
  for i = 1, #buttons do
    drawBtn(buttons[i])
  end
end

function UI.waitAction(timeout)
  local e = { event.pull(timeout or 0.25) }
  if not e[1] then return nil end

  if e[1] == "touch" then
    local x, y = e[3], e[4]
    for i = 1, #buttons do
      local b = buttons[i]
      if hit(x, y, b) then
        return b.id
      end
    end
  end

  if e[1] == "key_down" then
    local code = e[4]
    if code == 16 or code == 113 then -- q (depends on layout, keep both)
      return "exit"
    end
    if code == 19 or code == 114 then -- r
      return "rediscover"
    end
  end

  return nil
end

return UI
