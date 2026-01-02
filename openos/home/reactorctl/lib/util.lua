-- /home/reactorctl/lib/util.lua
local M = {}

function M.round(x)
  if not x then return 0 end
  return math.floor(x + 0.5)
end

function M.kfmt(x)
  if x == nil then return "-" end
  local n = tonumber(x) or 0
  local abs = math.abs(n)
  if abs >= 1e9 then
    return string.format("%.2fG", n / 1e9)
  elseif abs >= 1e6 then
    return string.format("%.2fM", n / 1e6)
  elseif abs >= 1e3 then
    return string.format("%.2fk", n / 1e3)
  else
    return tostring(M.round(n))
  end
end

function M.pct(a, b)
  if not a or not b or b == 0 then return "-" end
  return string.format("%d%%", math.floor((a / b) * 100 + 0.5))
end

return M
