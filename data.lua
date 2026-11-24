local shortcut_icon = "__base__/graphics/icons/transport-belt.png"

local pbb_layer = {
  type = "collision-layer",
  name = "pbb-tool-layer"
}

local empty_smoke = {
  type = "trivial-smoke",
  name = "pbb-empty-smoke",
  animation = {
    filename = "__core__/graphics/empty.png",
    size = {1, 1},
    frame_count = 8
  },
  duration = 1
}

local sentinel_entity = {
  type = "simple-entity-with-owner",
  name = "pbb-never-selected",
  picture = {
    filename = "__core__/graphics/empty.png",
    size = 64,
    priority = "very-low"
  },
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid"},
  collision_mask = {layers = {}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
  hidden = true,
  hidden_in_factoriopedia = true
}

local dummy_entity = {
  type = "simple-entity-with-force",
  name = "pbb-dummy-entity",
  flags = {"not-on-map", "player-creation"},
  collision_box = {{-0.4, -0.4}, {0.4, 0.4}},
  collision_mask = {layers = {}},
  selectable_in_game = false,
  hidden_in_factoriopedia = true,
  picture = {
    filename = "__core__/graphics/empty.png",
    size = 1
  },
  created_smoke = {smoke_name = "pbb-empty-smoke"},
  build_sound = {filename = "__core__/sound/silence-1sec.ogg"}
}

local dummy_belt = table.deepcopy(data.raw["transport-belt"]["transport-belt"])
dummy_belt.name = "pbb-dummy-transport-belt"
dummy_belt.localised_name = {"entity-name.pbb-dummy-transport-belt"}
dummy_belt.hidden = true
dummy_belt.hidden_in_factoriopedia = true
dummy_belt.selectable_in_game = false
dummy_belt.next_upgrade = nil
dummy_belt.minable = nil
dummy_belt.created_smoke = {smoke_name = "pbb-empty-smoke"}
dummy_belt.build_sound = {filename = "__core__/sound/silence-1sec.ogg"}
dummy_belt.collision_mask = {
  layers = {
    transport_belt = true
  }
}

local function selection_mode()
  return {
    mode = "nothing",
    border_color = {r = 0, g = 0, b = 0, a = 0},
    cursor_box_type = "not-allowed"
  }
end

local base_tool = {
  type = "selection-tool",
  icon = shortcut_icon,
  icon_size = 64,
  stack_size = 1,
  subgroup = "tool",
  order = "c[automated-construction]-p[pbb-draw-tool]",
  mouse_cursor = "arrow",
  send_pre_selection_events = true,
  flags = {"only-in-cursor", "spawnable", "not-stackable"},
  hidden = true,
  hidden_in_factoriopedia = true,
  collision_mask = {
    layers = {
      ["pbb-tool-layer"] = true
    }
  },
  select = selection_mode(),
  alt_select = selection_mode(),
  reverse_select = selection_mode(),
  alt_reverse_select = selection_mode(),
  super_forced_select = selection_mode()
}

local tool = table.deepcopy(base_tool)
tool.name = "pbb-draw-tool"

local preview_tool = table.deepcopy(base_tool)
preview_tool.name = "pbb-preview-tool"

data:extend({
  pbb_layer,
  empty_smoke,
  sentinel_entity,
  dummy_entity,
  dummy_belt,
  tool,
  preview_tool,
  {
    type = "sprite",
    name = "pbb-entryexit",
    filename = "__ParallelBeltBuilder__/graphics/under.png",
    size = 64,
    priority = "extra-high-no-scale"
  },
  {
    type = "sprite",
    name = "pbb-blocked",
    filename = "__ParallelBeltBuilder__/graphics/blocked.png",
    size = 64,
    priority = "extra-high-no-scale"
  },
  {
    type = "sprite",
    name = "pbb-anchor",
    filename = "__ParallelBeltBuilder__/graphics/anchor.png",
    size = 64,
    priority = "extra-high-no-scale"
  },
  {
    type = "shortcut",
    name = "pbb-toggle-recording",
    action = "lua",
    toggleable = true,
    icon = shortcut_icon,
    icon_size = 64,
    small_icon = shortcut_icon,
    small_icon_size = 64,
    localised_name = {"shortcut.pbb-toggle-recording"},
    associated_control_input = "pbb-toggle-recording-key"
  },
  {
    type = "custom-input",
    name = "pbb-toggle-recording-key",
    key_sequence = "CONTROL + ALT + Q",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "pbb-flip-bend",
    key_sequence = "F",
    consuming = "none",
    order = "pbb-a"
  },
  {
    type = "custom-input",
    name = "pbb-anchor",
    key_sequence = "R",
    consuming = "none",
    order = "pbb-b"
  },
  {
    type = "custom-input",
    name = "pbb-cancel",
    key_sequence = "",
    linked_game_control = "clear-cursor",
    consuming = "none",
    order = "pbb-c"
  }
})
