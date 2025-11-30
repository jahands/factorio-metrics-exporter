local constants = require("constants")

local M = {}

--Get export interval
---@return integer
function M.get_interval()
  return settings.global[constants.settings.interval].value --[[@as integer]]
end

return M
