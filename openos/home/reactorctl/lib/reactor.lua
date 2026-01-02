-- /home/reactorctl/lib/reactor.lua
local component = require("component")
local Util = require("util")

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

  local active = false
  local temp = nil
  local gen = nil
  local coolant = nil
  local coolantMax = nil
  local rod = nil

  pcall(function() active = p.hasWork() end)
  pcall(function() temp = p.getTemperature() end)
  pcall(function() gen = p.getEnergyGeneration() end)

  -- These exist in your adapter dump:
  pcall(function() coolant = p.getFluidCoolant() end)
  pcall(function() coolantMax = p.getMaxFluidCoolant() end)

  -- Optional - might not exist or might require selector setup, so keep safe
  pcall(function()
    local r = p.getSelectStatusRod()
    if r and type(r) == "table" then
      rod = r
    end
  end)

  return {
    active = active and true or false,
    temp = temp,
    gen = gen,
    coolant = coolant,
    coolantMax = coolantMax,
    rod = rod,
  }
end

function Reactor:activate()
  pcall(function() self.proxy.activate() end)
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
  table.sort(out, function(a,b) return a.addr < b.addr end)
  return out
end

return M
