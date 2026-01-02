local M = {}

function M.round(x)
  if x == nil then return 0 end
  return math.floor(x + 0.5)
end

function M.kfmt(x)
  if x == nil then return "-" end
  local n = tonumber(x)
  if not n then return "-" end
  local a = math.abs(n)
  if a >= 1e9 then
    return string.format("%.2fG", n / 1e9)
  elseif a >= 1e6 then
    return string.format("%.2fM", n / 1e6)
  elseif a >= 1e3 then
    return string.format("%.2fk", n / 1e3)
  else
    return tostring(M.round(n))
  end
end

function M.pct(a, b)
  if a == nil or b == nil or b == 0 then return "-" end
  return string.format("%d%%", math.floor((a / b) * 100 + 0.5))
end

function M.padRight(s, n)
  s = tostring(s or "")
  if #s >= n then return s:sub(1, n) end
  return s .. string.rep(" ", n - #s)
end

return M
