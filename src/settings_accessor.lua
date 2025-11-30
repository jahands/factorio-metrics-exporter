local M = {}

--Get export interval
---@return integer
function M.get_interval()
  return settings.global["factorio-metrics-exporter-interval"].value --[[@as integer]]
end

return M
