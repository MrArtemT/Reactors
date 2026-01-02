-- /home/reactorctl/main.lua (safe)

local term = require("term")

local BASE = "/home/reactorctl"
local function load(rel)
  local path = BASE .. "/" .. rel
  local ok, res = pcall(dofile, path)
  if not ok then
    term.clear()
    io.stderr:write("LOAD FAILED: " .. path .. "\n")
    io.stderr:write(tostring(res) .. "\n")
    return nil
  end
  if res == nil then
    term.clear()
    io.stderr:write("LOAD RETURNED NIL: " .. path .. "\n")
    io.stderr:write("Expected: return M\n")
    return nil
  end
  return res
end

term.clear()
print("ReactorCTL start...")

local cfg   = load("config.lua");      if not cfg then return end
local UI    = load("lib/ui.lua");      if not UI then return end
local Icons = load("lib/icons.lua");   if not Icons then return end
local Dev   = load("lib/devices.lua"); if not Dev then return end
local Log   = load("lib/log.lua");     if not Log then return end

if type(Log) ~= "table" or type(Log.new) ~= "function" or type(Log.push) ~= "function" then
  io.stderr:write("BAD LOG MODULE: lib/log.lua must provide table with new() and push().\n")
  return
end

-- IMPORTANT: create instance
local log = Log.new(300)
Log.push(log, "Log initialized")

-- quick self-test
print("OK modules loaded.")
print("Log lines:", #log.lines)

print("Now you can restore the UI loop.")
