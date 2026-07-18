data:extend({
  {
    type = "shortcut",
    name = "pbb-toggle-recording",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/transport-belt.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/transport-belt.png",
    small_icon_size = 64,
    localised_name = {"shortcut.pbb-toggle-recording"}
  },
  {
    type = "custom-input",
    name = "pbb-toggle-recording-key",
    key_sequence = "CONTROL + ALT + Q",
    consuming = "none"
  }
})
