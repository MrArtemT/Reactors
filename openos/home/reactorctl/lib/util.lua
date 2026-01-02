local M = {}

function M.round(x)
  if x == nil then return 0 end
  return math.floor(x + 0.5)
end

return M
