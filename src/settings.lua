local constants = require("constants")

data:extend({
  {
    type = "int-setting",
    name = constants.settings.interval,
    setting_type = "runtime-global",
    default_value = 600,
    minimum_value = 60,
    maximum_value = 3600
  }
})
