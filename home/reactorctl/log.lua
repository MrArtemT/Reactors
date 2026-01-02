local M = {}

local function nowTime()
  local t = os.date("*t")
  return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
end

function M.new(maxLines)
  return { maxLines = maxLines or 200, lines = {} }
end

function M.push(L, msg)
  if not L then return end
  local line = string.format("[%s] %s", nowTime(), tostring(msg))
  table.insert(L.lines, line)
  while #L.lines > L.maxLines do
    table.remove(L.lines, 1)
  end
end

function M.wrapLines(text, width)
  local out = {}
  text = tostring(text or "")
  if width < 1 then width = 1 end
  while #text > width do
    table.insert(out, text:sub(1, width))
    text = text:sub(width + 1)
  end
  if #text > 0 then table.insert(out, text) end
  if #out == 0 then out[1] = "" end
  return out
end

return M
