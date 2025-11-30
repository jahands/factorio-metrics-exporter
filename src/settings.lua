local constants = require("constants")

data:extend({
  {
    type = "int-setting",
    name = constants.settings.interval,
    setting_type = "runtime-global",
    default_value = 600,
    minimum_value = 60,
    maximum_value = 3600
  },
  {
    type = "bool-setting",
    name = constants.settings.per_player,
    setting_type = "runtime-per-user",
    default_value = false
  },
  {
    type = "int-setting",
    name = constants.settings.entity_budget,
    setting_type = "runtime-global",
    default_value = 2000,
    minimum_value = 100,
    maximum_value = 1000000
  }
})
