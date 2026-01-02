local component = require("component")

local Flux = {}
Flux.__index = Flux

function Flux.new(addr)
  local self = setmetatable({}, Flux)
  self.addr = addr
  self.proxy = component.proxy(addr)
  return self
end

function Flux:energyInfo()
  local p = self.proxy
  local info = {}
  pcall(function() info.energy = p.getEnergyInfo() end)
  return info
end

local M = {}

function M.discover()
  for addr, _ in component.list("flux_controller") do
    return Flux.new(addr)
  end
  return nil
end

return M
