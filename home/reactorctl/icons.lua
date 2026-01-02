local M = {}

-- маленькие 5x5 шаблоны, рисуем "█" где 1
local ICONS = {
  bolt = {
    "00100",
    "01100",
    "00110",
    "00010",
    "00100",
  },
  drop = {
    "00100",
    "01110",
    "11111",
    "11111",
    "01110",
  },
  heat = {
    "00100",
    "01110",
    "11111",
    "01110",
    "00100",
  },
}

function M.draw(gpu, x, y, name, color)
  local pat = ICONS[name]
  if not pat then return end
  local oldFG = gpu.getForeground()
  gpu.setForeground(color)
  for j=1,#pat do
    local row = pat[j]
    for i=1,#row do
      if row:sub(i,i) == "1" then
        gpu.set(x + i - 1, y + j - 1, "█")
      end
    end
  end
  gpu.setForeground(oldFG)
end

return M
