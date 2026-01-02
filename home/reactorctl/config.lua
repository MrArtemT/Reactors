cat <<'EOF' > /home/reactorctl/config.lua
-- /home/reactorctl/config.lua
local cfg = {}

cfg.maxReactors = 6

cfg.fluid = {
  label = "Низкотемпературный хладагент",
  name  = "low_temperature_refrigerant",
}

cfg.minFluid = 80000

cfg.pollEveryReactor = 1.5
cfg.pollEveryFluid   = 30

cfg.beepOnAlarm = true

cfg.colors = {
  bg     = 0x101010,
  panel  = 0x1A1A1A,
  card   = 0x161616,

  text   = 0xEAEAEA,
  dim    = 0xA0A0A0,

  border = 0x5A5A5A,

  red    = 0xD43C3C,
  green  = 0x2ECC71,
  blue   = 0x3498DB,
  orange = 0xF39C12,
}

return cfg
EOF
