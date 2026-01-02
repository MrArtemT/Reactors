-- /home/reactorctl/lib/log.lua
local fs = require("filesystem")

local M = {}
M.__index = M

local function ts()
  -- OpenOS doesn't always have os.date, keep simple uptime timestamp
  return string.format("[%.1fs]", require("computer").uptime())
end

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
  f:write(string.format("%s [%s] %s - %s\n", ts(), level, tag or "-", msg or "-"))
  f:close()
end

function M:info(tag, msg)  self:_write("INFO", tag, msg) end
function M:warn(tag, msg)  self:_write("WARN", tag, msg) end
function M:error(tag, msg) self:_write("ERR",  tag, msg) end

-- convenience static logger (created lazily by main)
local _default = nil
local function default()
  if not _default then
    local CFG = require("config")
    _default = M.new(CFG.logFile, CFG.logMaxKb)
  end
  return _default
end

function M.info(tag, msg)  default():info(tag, msg) end
function M.warn(tag, msg)  default():warn(tag, msg) end
function M.error(tag, msg) default():error(tag, msg) end

return M
