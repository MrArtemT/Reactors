local fs = require("filesystem")
local computer = require("computer")

local M = {}
M.__index = M

local function rotateIfNeeded(path, maxKb)
  if not fs.exists(path) then return end
  local sz = fs.size(path) or 0
  if sz <= (maxKb * 1024) then return end
  local bak = path .. ".1"
  if fs.exists(bak) then fs.remove(bak) end
  fs.rename(path, bak)
end

function M.new(path, maxKb)
  local self = setmetatable({}, M)
  self.path = path
  self.maxKb = maxKb or 256
  return self
end

function M:_write(level, tag, msg)
  rotateIfNeeded(self.path, self.maxKb)
  local f = io.open(self.path, "a")
  if not f then return end
  f:write(string.format("[%.1fs] [%s] %s - %s\n", computer.uptime(), level, tag or "-", msg or "-"))
  f:close()
end

function M:info(tag, msg)  self:_write("INFO", tag, msg) end
function M:warn(tag, msg)  self:_write("WARN", tag, msg) end
function M:error(tag, msg) self:_write("ERR",  tag, msg) end

return M
