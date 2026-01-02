-- /home/reactorctl/lib/me.lua
local component = require("component")

local ME = {}
ME.__index = ME

function ME.new(addr)
  local self = setmetatable({}, ME)
  self.addr = addr
  self.proxy = component.proxy(addr)
  return self
end

function ME:energyInfo()
  local p = self.proxy
  local out = {
    stored = nil,
    max = nil,
    avgIn = nil,
    avgUse = nil,
    demand = nil,
    powered = nil,
  }
  pcall(function() out.stored = p.getStoredPower() end)
  pcall(function() out.max    = p.getMaxStoredPower() end)
  pcall(function() out.avgIn  = p.getAvgPowerInjection() end)
  pcall(function() out.avgUse = p.getAvgPowerUsage() end)
  pcall(function() out.demand = p.getEnergyDemand() end)
  pcall(function() out.powered= p.isNetworkPowered() end)
  return out
end

local M = {}

function M.discover()
  for addr, _ in component.list("me_interface") do
    return ME.new(addr)
  end
  return nil
end

return M
