-- /home/reactorctl/main.lua
local component = require("component")
local computer  = require("computer")
local event     = require("event")
local term      = require("term")

local ROOT = "/home/reactorctl"
package.path =
  ROOT.."/?.lua;"..
  ROOT.."/?/init.lua;"..
  ROOT.."/lib/?.lua;"..
  ROOT.."/lib/?/init.lua;"..
  package.path

local CFG    = require("config")
local UI     = require("ui")
local Util   = require("util")
local Log    = require("log")
local Reactor= require("reactor")
local Flux   = require("flux")
local ME     = require("me")

local function safeBeep()
  if CFG.beepOnAlarm then
    pcall(computer.beep, 1000, 0.08)
  end
end

local function discover()
  local reactors = Reactor.discover(CFG.ignore)
  local flux = Flux.discover()
  local me = ME.discover()

  Log.info("discover", string.format("reactors=%d flux=%s me=%s",
    #reactors,
    flux and "yes" or "no",
    me and "yes" or "no"
  ))

  return reactors, flux, me
end

local function evaluateReactor(r)
  local st = r:status()

  local alarm = false
  if st.coolantMax and st.coolantMax > 0 then
    local ratio = st.coolant / st.coolantMax
    if ratio < CFG.minCoolantRatio then
      alarm = true
    end
  end

  if alarm and CFG.shutdownOnLowCoolant and st.active then
    r:deactivate()
    Log.warn("reactor", r.name .. " low coolant - deactivated")
    safeBeep()
  end

  return st, alarm
end

local function main()
  term.clear()
  local logger = Log.new(CFG.logFile, CFG.logMaxKb)

  UI.init(CFG.ui.title)

  local reactors, flux, me = discover()

  if #reactors == 0 then
    UI.drawHeader({ status = "NO REACTORS FOUND" })
    UI.drawFooter("Press Q to exit")
    while true do
      local _, _, ch = event.pull("key_down")
      if ch == string.byte("q") or ch == string.byte("Q") then
        term.clear()
        return
      end
    end
  end

  local lastTick = 0
  local alarms = {}

  while true do
    local now = computer.uptime()
    local dt = now - lastTick
    if dt < CFG.pollEvery then
      local e = { event.pull(CFG.pollEvery - dt) }
      if e[1] == "key_down" then
        local ch = e[3]
        if ch == string.byte("q") or ch == string.byte("Q") then
          Log.info("app", "quit")
          term.clear()
          return
        end
        if ch == string.byte("r") or ch == string.byte("R") then
          Log.info("app", "rediscover")
          reactors, flux, me = discover()
        end
      end
    end

    lastTick = computer.uptime()

    local rows = {}
    local anyAlarm = false

    for i = 1, #reactors do
      local r = reactors[i]
      local st, alarm = evaluateReactor(r)
      alarms[r.addr] = alarm
      anyAlarm = anyAlarm or alarm
      rows[#rows+1] = {
        name = r.name,
        addr = r.addr,
        active = st.active,
        temp = st.temp,
        gen = st.gen,
        coolant = st.coolant,
        coolantMax = st.coolantMax,
        rod = st.rod,
        alarm = alarm,
      }
    end

    local energy = nil
    if flux then energy = flux:energyInfo() end

    local meEnergy = nil
    if me then meEnergy = me:energyInfo() end

    UI.drawAll({
      title = CFG.ui.title,
      alarm = anyAlarm,
      reactors = rows,
      flux = energy,
      me = meEnergy,
    })

    if anyAlarm then safeBeep() end
  end
end

local ok, err = pcall(main)
if not ok then
  local Log = require("log")
  local CFG = require("config")
  local logger = Log.new(CFG.logFile, CFG.logMaxKb)
  logger:error("crash", tostring(err))
  term.clear()
  io.stderr:write("reactorctl crashed:\n" .. tostring(err) .. "\n")
end
