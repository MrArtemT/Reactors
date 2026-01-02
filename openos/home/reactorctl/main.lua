-- /home/reactorctl/main.lua
local component = require("component")
local computer  = require("computer")
local event     = require("event")
local term      = require("term")
local shell     = require("shell")

local ROOT = "/home/reactorctl"
package.path =
  ROOT.."/?.lua;"..
  ROOT.."/?/init.lua;"..
  ROOT.."/lib/?.lua;"..
  ROOT.."/lib/?/init.lua;"..
  package.path

local CFG    = require("config")

-- Lazy-load modules (safer on boot)
local UI, Util, Log, Reactor, Flux, ME

local function safeBeep()
  if not CFG.beepOnAlarm then return end
  pcall(computer.beep, 1000, 0.08)
end

local function discover(logger)
  local reactors = Reactor.discover(CFG.ignore)
  local flux = Flux.discover()
  local me = ME.discover()

  if logger then
    logger:info("discover", string.format("reactors=%d flux=%s me=%s",
      #reactors,
      flux and "yes" or "no",
      me and "yes" or "no"
    ))
  end

  return reactors, flux, me
end

local function reactorActivate(r)
  -- r is Reactor.new() object from lib/reactor.lua
  if r.activate then
    pcall(function() r:activate() end)
    return
  end
  if r.proxy and r.proxy.activate then
    pcall(function() r.proxy.activate() end)
  end
end

local function reactorDeactivate(r)
  if r.deactivate then
    pcall(function() r:deactivate() end)
    return
  end
  if r.proxy and r.proxy.deactivate then
    pcall(function() r.proxy.deactivate() end)
  end
end

local function buildCards(reactors, logger)
  local cards = {}
  local anyAlarm = false
  local totalGen = 0

  for i = 1, #reactors do
    local r = reactors[i]
    local st = r.status and r:status() or {}

    local alarm = false
    if st.coolantMax and st.coolantMax > 0 and st.coolant ~= nil then
      local ratio = st.coolant / st.coolantMax
      if ratio < (CFG.minCoolantRatio or 0) then
        alarm = true
      end
    end

    if alarm and CFG.shutdownOnLowCoolant and st.active then
      reactorDeactivate(r)
      if logger then logger:warn("reactor", (r.name or "reactor") .. " low coolant - deactivated") end
      safeBeep()
    end

    anyAlarm = anyAlarm or alarm
    totalGen = totalGen + (tonumber(st.gen) or 0)

    cards[i] = {
      name = r.name or ("Reactor " .. tostring(i)),
      addr = r.addr,
      active = st.active and true or false,
      temp = st.temp,
      gen = st.gen,
      coolant = st.coolant,
      coolantMax = st.coolantMax,
      kind = "Fluid",
      alarm = alarm,
    }
  end

  return cards, anyAlarm, totalGen
end

local function main()
  Util    = require("util")
  Log     = require("log")
  Reactor = require("reactor")
  Flux    = require("flux")
  ME      = require("me")
  UI      = require("ui")

  local logger = Log.new(CFG.logFile, CFG.logMaxKb)

  -- UI init (must be explicit)
  if UI.init then
    pcall(UI.init, CFG.ui and CFG.ui.title or "Reactor Control")
  end

  local reactors, flux, me = discover(logger)

  local logs = {
    "Запуск программы",
    "Реакторов найдено: " .. tostring(#reactors),
  }

  local function pushLog(s)
    logs[#logs + 1] = tostring(s)
    if #logs > 30 then table.remove(logs, 1) end
  end

  while true do
    local cards, anyAlarm, totalGen = buildCards(reactors, logger)

    local fluxInfo = flux and flux:energyInfo() or nil
    local meInfo = me and me:energyInfo() or nil

    -- If you later add ME-fluid reading, set these:
    local meFluid = nil
    local minFluid = nil

    UI.draw({
      reactors = cards,
      reactorCount = #reactors,
      uptime = computer.uptime(),
      totalGen = totalGen,
      logs = logs,

      alarm = anyAlarm,

      me = meInfo,
      flux = fluxInfo,
      meFluid = meFluid,
      minFluid = minFluid,
    })

    local action = UI.waitAction(0.25)

    if action == "exit" then
      logger:info("app", "exit")
      term.clear()
      return
    elseif action == "rediscover" then
      reactors, flux, me = discover(logger)
      pushLog("Rediscover: reactors=" .. tostring(#reactors))
    elseif action == "restart" then
      pushLog("Перезапуск...")
      logger:info("app", "restart")
      term.clear()
      shell.execute("/home/reactorctl/main.lua")
      return
    elseif action == "all_off" then
      for i = 1, #reactors do reactorDeactivate(reactors[i]) end
      pushLog("Отключаю все реакторы")
      logger:warn("app", "all_off")
    elseif action == "all_on" then
      for i = 1, #reactors do reactorActivate(reactors[i]) end
      pushLog("Запускаю все реакторы")
      logger:info("app", "all_on")
    elseif type(action) == "string" then
      local idx = action:match("^reactor_toggle:(%d+)$")
      if idx then
        idx = tonumber(idx)
        local r = reactors[idx]
        if r then
          local st = r.status and r:status() or {}
          if st.active then
            reactorDeactivate(r)
            pushLog("Reactor #" .. idx .. ": OFF")
            logger:info("reactor", "toggle off idx=" .. tostring(idx))
          else
            reactorActivate(r)
            pushLog("Reactor #" .. idx .. ": ON")
            logger:info("reactor", "toggle on idx=" .. tostring(idx))
          end
        end
      end
    end
  end
end

local ok, err = pcall(main)
if not ok then
  pcall(function()
    local Log = require("log")
    local CFG = require("config")
    local logger = Log.new(CFG.logFile, CFG.logMaxKb)
    logger:error("crash", tostring(err))
  end)
  term.clear()
  io.stderr:write("reactorctl crashed:\n" .. tostring(err) .. "\n")
end
