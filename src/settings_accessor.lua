local constants = require("constants")

local M = {}

--Get export interval
---@return integer
function M.get_interval()
  return settings.global[constants.settings.interval].value --[[@as integer]]
end

---Check if a player has opted into local exports
---@param player LuaPlayer
---@return boolean
function M.should_export_for_player(player)
  local player_settings = settings.get_player_settings(player)
  local setting = player_settings and player_settings[constants.settings.per_player]
  return setting and setting.value or false --[[@as boolean]]
end

return M
