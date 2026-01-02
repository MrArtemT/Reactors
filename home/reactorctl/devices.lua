local component = require("component")

local M = {}

local function firstOfType(t)
  for addr in component.list(t) do
    return component.proxy(addr), addr
  end
  return nil, nil
end

function M.scan(cfg)
  local reactors = {}
  for addr in component.list("htc_reactors_nuclear_reactor") do
    reactors[#reactors+1] = { proxy = component.proxy(addr), addr = addr }
  end

  table.sort(reactors, function(a,b) return a.addr < b.addr end)
  while #reactors > (cfg.maxReactors or 6) do table.remove(reactors) end

  local me, meAddr = firstOfType("me_interface")
  local flux, fluxAddr = firstOfType("flux_controller") -- если есть

  return {
    reactors = reactors,
    me = me,
    meAddr = meAddr,
    flux = flux,
    fluxAddr = fluxAddr
  }
end

-- ME: жидкости в сети
function M.readFluidAmount(me, fluidName)
  if not me or not me.getFluidsInNetwork then return nil, "no_me" end
  local ok, list = pcall(me.getFluidsInNetwork)
  if not ok or type(list) ~= "table" then return nil, "bad_list" end

  for _, f in ipairs(list) do
    -- разные моды по-разному называют поля, страхуемся
    local name = f.name or (f.fluid and f.fluid.name)
    if name == fluidName then
      local amt = f.amount or f.qty or f.stored or 0
      return tonumber(amt) or 0, nil
    end
  end
  return 0, nil
end

-- Reactor: данные
function M.readReactor(r)
  local p = r.proxy
  local out = { addr = r.addr }

  local okActive, active = pcall(p.isFuelFilterActive) -- не всегда то, но ок как проба
  out.active = (okActive and active) or false

  local okTemp, temp = pcall(p.getTemperature)
  out.temp = (okTemp and temp) or 0

  local okGen, gen = pcall(p.getEnergyGeneration)
  out.gen = (okGen and gen) or 0

  local okCooling, cooling = pcall(p.isActiveCooling)
  out.isLiquid = (okCooling and cooling) or false

  -- твой “Air/Liquid” тип
  out.type = out.isLiquid and "Liquid" or "Air"

  return out
end

function M.setReactor(r, on)
  local p = r.proxy
  if on then
    if p.activate then pcall(p.activate) end
  else
    if p.deactivate then pcall(p.deactivate) end
  end
end

return M
