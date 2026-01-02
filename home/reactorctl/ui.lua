-- /home/reactorctl/lib/ui.lua
local M = {}

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

function M.box(gpu, x, y, w, h, border, fill)
  gpu.setForeground(border)
  gpu.setBackground(fill)

  gpu.set(x, y, "┌" .. string.rep("─", w - 2) .. "┐")
  for i = 1, h - 2 do
    gpu.set(x, y + i, "│" .. string.rep(" ", w - 2) .. "│")
  end
  gpu.set(x, y + h - 1, "└" .. string.rep("─", w - 2) .. "┘")
end

function M.title(gpu, x, y, w, text, fg, bg)
  gpu.setForeground(fg)
  gpu.setBackground(bg)

  local t = " " .. tostring(text or "") .. " "
  local left = math.max(0, math.floor((w - #t) / 2))
  gpu.set(x + left, y, t)
end

function M.fill(gpu, x, y, w, h, bg)
  gpu.setBackground(bg)
  gpu.fill(x, y, w, h, " ")
end

function M.text(gpu, x, y, s, fg, bg)
  if bg ~= nil then gpu.setBackground(bg) end
  if fg ~= nil then gpu.setForeground(fg) end
  gpu.set(x, y, tostring(s or ""))
end

function M.progress(gpu, x, y, w, ratio, fg, bg)
  ratio = clamp(tonumber(ratio) or 0, 0, 1)
  local n = math.floor(w * ratio)

  gpu.setBackground(bg)
  gpu.fill(x, y, w, 1, " ")

  if n > 0 then
    gpu.setBackground(fg)
    gpu.fill(x, y, n, 1, " ")
  end
end

return M
