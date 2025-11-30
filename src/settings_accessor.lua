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

---Get configured entity budget per tick
---@return integer
function M.get_entity_budget()
  local setting = settings.global[constants.settings.entity_budget]
  return setting and setting.value or 2000 --[[@as integer]]
end

return M
