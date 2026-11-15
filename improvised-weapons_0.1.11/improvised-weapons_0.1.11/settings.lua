data:extend({
  {
    type = "double-setting",
    name = "iw-coal-burn-seconds",
    setting_type = "runtime-global",
    default_value = 10,
    minimum_value = 1,
    maximum_value = 600,
    order = "a"
  },
  {
    type = "double-setting",
    name = "iw-fire-pollution-per-minute",
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 0,
    maximum_value = 6000,
    order = "b"
  }
})
