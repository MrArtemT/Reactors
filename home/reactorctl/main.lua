local term = require("term")
local fs = require("filesystem")

local BASE = "/home/reactorctl"

local function load(rel)
  local path = BASE .. "/" .. rel
  io.write("Loading: " .. path .. "\n")
  local ok, res = pcall(dofile, path)
  if not ok then
    io.write("LOAD FAILED: " .. path .. "\n")
    io.write(tostring(res) .. "\n")
    return nil
  end
  if res == nil then
    io.write("LOAD RETURNED NIL: " .. path .. "\n")
    io.write("Expected last line: return M\n")
    return nil
  end
  io.write("OK: " .. rel .. "\n")
  return res
end

term.clear()
io.write("ReactorCTL bootstrap...\n")
io.write("BASE = " .. BASE .. "\n\n")

local cfg = load("config.lua"); if not cfg then return end
local UI  = load("lib/ui.lua"); if not UI then return end
local Ic  = load("lib/icons.lua"); if not Ic then return end
local Dev = load("lib/devices.lua"); if not Dev then return end
local Log = load("lib/log.lua"); if not Log then return end

io.write("\nLog module type: " .. type(Log) .. "\n")
io.write("Log.new type: " .. type(Log.new) .. "\n")

io.write("\nIf you see this, Log loaded fine.\n")
