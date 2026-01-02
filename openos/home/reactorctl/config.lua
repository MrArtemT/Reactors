local CFG = {
  pollEvery = 1.0,

  -- Alarm logic
  minCoolantRatio = 0.20,     -- 20% of max
  shutdownOnLowCoolant = true,
  beepOnAlarm = true,

  -- UI
  ui = {
    title = "Reactor Control",
  },

  -- Logging
  logFile = "/home/reactorctl/reactorctl.log",
  logMaxKb = 256,

  -- Ignore reactors by address if needed
  ignore = {
    -- ["cc8b9ade"] = true,
  },
}

return CFG
