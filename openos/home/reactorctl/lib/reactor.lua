local component = require("component")

local Reactor = {}
Reactor.__index = Reactor

function Reactor.new(addr)
  local self = setmetatable({}, Reactor)
  self.addr = addr
  self.proxy = component.proxy(addr)
  self.name = "Reactor " .. addr:sub(1, 8)
  return self
end

function Reactor:status()
  local p = self.proxy

  local st = {
    active = false,
    temp = nil,
    gen = nil,
    coolant = nil,
    coolantMax = nil,
  }

  pcall(function() st.active = p.hasWork() and true or false end)
  pcall(function() st.temp = p.getTemperature() end)
  pcall(function() st.gen = p.getEnergyGeneration() end)
  pcall(function() st.coolant = p.getFluidCoolant() end)
  pcall(function() st.coolantMax = p.getMaxFluidCoolant() end)

  return st
end

function Reactor:deactivate()
  pcall(function() self.proxy.deactivate() end)
end

local M = {}

function M.discover(ignore)
  local out = {}
  for addr, _ in component.list("htc_reactors_nuclear_reactor") do
    if not (ignore and ignore[addr]) then
      out[#out+1] = Reactor.new(addr)
    end
  end
  table.sort(out, function(a, b) return a.addr < b.addr end)
  return out
end

return M
