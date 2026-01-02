local U = {}

function U.clamp(n, a, b)
  if n == nil then return a end
  if n < a then return a end
  if n > b then return b end
  return n
end

function U.round(x)
  if x == nil then return 0 end
  return math.floor(x + 0.5)
end

function U.kfmt(x)
  if x == nil then return "-" end
  local n = tonumber(x)
  if not n then return "-" end
  local a = math.abs(n)
  if a >= 1e9 then return string.format("%.2fG", n / 1e9) end
  if a >= 1e6 then return string.format("%.2fM", n / 1e6) end
  if a >= 1e3 then return string.format("%.2fk", n / 1e3) end
  return tostring(U.round(n))
end

function U.timeFmt(sec)
  sec = tonumber(sec or 0) or 0
  sec = math.max(0, math.floor(sec))
  local m = math.floor(sec / 60)
  local s = sec % 60
  if m >= 60 then
    local h = math.floor(m / 60)
    m = m % 60
    return string.format("%dh %dm %ds", h, m, s)
  end
  return string.format("%dm %ds", m, s)
end

function U.fit(s, w)
  s = tostring(s or "")
  if #s > w then return s:sub(1, w) end
  return s .. string.rep(" ", w - #s)
end

return U
