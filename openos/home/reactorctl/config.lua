-- /home/reactorctl/config.lua
local CFG = {
  pollEvery = 1.0,

  -- Coolant alarm
  minCoolantRatio = 0.20,   -- 20% of max
  shutdownOnLowCoolant = true,
  beepOnAlarm = true,

  -- UI
  ui = {
    title = "Reactor Control",
    margin = 1,
  },

  -- Logging
  logFile = "/home/reactorctl/reactorctl.log",
  logMaxKb = 256, -- rotate if file bigger than this

  -- Optional: if you want to ignore some reactors by address
  ignore = {
    -- ["cc8b9ade"] = true,
  },
}

return CFG
