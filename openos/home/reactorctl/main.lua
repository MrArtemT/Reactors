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

local CFG = require("config")

local function safeBeep()
  if not CFG.beepOnAlarm then return end
  pcall(computer.beep, 1000, 0.08)
end

local function main()
  -- Lazy requires (avoid memory spike at boot)
  local Util    = require("util")
  local Log     = require("log")
  local Reactor = require("reactor")
  local Flux    = require("flux")
  local ME      = require("me")
  local UI      = require("ui")

  local logger = Log.new(CFG.logFile, CFG.logMaxKb)

  -- UI init must be explicit (no GPU work during require)
  UI.init(CFG.ui.title)

  local function discover()
    local reactors = Reactor.discover(CFG.ignore)
    local flux = Flux.discover()
    local me = ME.discover()

    logger:info("discover", string.format("reactors=%d flux=%s me=%s",
      #reactors,
      flux and "yes" or "no",
      me and "yes" or "no"
    ))

    return reactors, flux, me
  end

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

  while true do
    local now = computer.uptime()
    local dt = now - lastTick
    if dt < CFG.pollEvery then
      local e = { event.pull(CFG.pollEvery - dt) }
      if e[1] == "key_down" then
        local ch = e[3]
        if ch == string.byte("q") or ch == string.byte("Q") then
          logger:info("app", "quit")
          term.clear()
          return
        end
        if ch == string.byte("r") or ch == string.byte("R") then
          logger:info("app", "rediscover")
          reactors, flux, me = discover()
        end
      end
    end

    lastTick = computer.uptime()

    local rows = {}
    local anyAlarm = false

    for i = 1, #reactors do
      local r = reactors[i]
      local st = r:status()

      local alarm = false
      if st.coolantMax and st.coolantMax > 0 then
        local ratio = st.coolant / st.coolantMax
        if ratio < CFG.minCoolantRatio then alarm = true end
      end

      if alarm and CFG.shutdownOnLowCoolant and st.active then
        r:deactivate()
        logger:warn("reactor", r.name .. " low coolant - deactivated")
        safeBeep()
      end

      anyAlarm = anyAlarm or alarm

      rows[#rows+1] = {
        name = r.name,
        addr = r.addr,
        active = st.active,
        temp = st.temp,
        gen = st.gen,
        coolant = st.coolant,
        coolantMax = st.coolantMax,
        alarm = alarm,
      }
    end

    local fluxInfo = flux and flux:energyInfo() or nil
    local meInfo = me and me:energyInfo() or nil

    UI.drawAll({
      alarm = anyAlarm,
      reactors = rows,
      flux = fluxInfo,
      me = meInfo,
    })

    if anyAlarm then safeBeep() end
  end
end

local ok, err = pcall(main)
if not ok then
  -- Avoid heavy UI on crash
  pcall(function()
    local Log = require("log")
    local CFG = require("config")
    local logger = Log.new(CFG.logFile, CFG.logMaxKb)
    logger:error("crash", tostring(err))
  end)
  term.clear()
  io.stderr:write("reactorctl crashed:\n" .. tostring(err) .. "\n")
end
