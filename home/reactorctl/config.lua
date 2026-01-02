return {
  fluid = {
    label = "Низкотемпературный хладагент",
    name  = "low_temperature_refrigerant",
  },

  minFluid = 80000,          -- mB
  pollEveryReactor = 1.5,    -- сек
  pollEveryFluid   = 30,     -- сек
  beepOnAlarm      = true,

  maxReactors = 6,

  -- Цвета (можешь править)
  colors = {
    bg      = 0x0B0D10,
    panel   = 0x11161C,
    card    = 0x0F1318,
    border  = 0x2A3340,
    text    = 0xE6EEF7,
    dim     = 0x9AA7B6,

    red     = 0xFF4D5E,
    green   = 0x2EE59D,
    blue    = 0x4DA3FF,
    orange  = 0xFFB020,
    yellow  = 0xFFD84D,
  }
}

return M
