local constants = require("scripts.constants")
local catalog = require("scripts.belt_catalog")
local state = require("scripts.state")

local gui = {}

local function is_valid_window(window)
  return window
    and window.valid
    and window.flow_belt
    and window.flow_belt.pbb_belt_dropdown
    and window.flow_count
    and window.flow_count.pbb_count_input
    and window.flow_actions
    and window.flow_actions.pbb_draw
    and window.flow_actions.pbb_confirm
end

local function update_toggle_button(btn, selected, width)
  if selected then
    btn.style = "confirm_button"
  else
    btn.style = "button"
  end
  btn.style.width = width
  btn.style.font = "default-semibold"
  btn.style.horizontal_align = "center"
  btn.style.vertical_align = "center"
end

local function add_row(window, name, caption)
  local flow = window.add{type = "flow", name = name, direction = "horizontal"}
  flow.style.vertical_align = "center"
  flow.style.horizontal_spacing = 8
  local label = flow.add{type = "label", caption = caption}
  label.style.width = 80
  return flow
end

function gui.get_or_create(player)
  local window = player.gui.screen.pbb_main_window
  if window and not is_valid_window(window) then
    window.destroy()
    window = nil
  end

  if window then return window end

  local p_state = state.get(player.index)
  window = player.gui.screen.add{
    type = "frame",
    name = "pbb_main_window",
    caption = {"gui.pbb-title"},
    direction = "vertical"
  }

  window.location = p_state.gui_position or {x = 80, y = 150}

  local flow_belt = add_row(window, "flow_belt", {"gui.pbb-belt"})
  local dropdown = flow_belt.add{type = "drop-down", name = "pbb_belt_dropdown", items = {"transport-belt"}}
  dropdown.style.width = 220

  local flow_count = add_row(window, "flow_count", {"gui.pbb-count"})
  local btn_minus = flow_count.add{type = "button", name = "pbb_count_minus", caption = "-"}
  btn_minus.style.width = 30
  local count_input = flow_count.add{type = "textfield", name = "pbb_count_input", text = tostring(p_state.count)}
  count_input.style.width = 45
  count_input.lose_focus_on_confirm = true
  local btn_plus = flow_count.add{type = "button", name = "pbb_count_plus", caption = "+"}
  btn_plus.style.width = 30

  local flow_side = add_row(window, "flow_side", {"gui.pbb-side"})
  local btn_left = flow_side.add{type = "button", name = "pbb_side_left", caption = {"gui.pbb-left"}}
  btn_left.style.width = 75
  local btn_right = flow_side.add{type = "button", name = "pbb_side_right", caption = {"gui.pbb-right"}}
  btn_right.style.width = 75

  local flow_place = add_row(window, "flow_place", {"gui.pbb-placement"})
  local btn_normal = flow_place.add{type = "button", name = "pbb_place_normal", caption = {"gui.pbb-normal"}}
  btn_normal.style.width = 75
  local btn_ghost = flow_place.add{type = "button", name = "pbb_place_ghost", caption = {"gui.pbb-ghost"}}
  btn_ghost.style.width = 75

  local line = window.add{type = "line", direction = "horizontal"}
  line.style.top_margin = 8
  line.style.bottom_margin = 8

  local flow_actions = window.add{type = "flow", name = "flow_actions", direction = "horizontal"}
  flow_actions.style.vertical_align = "center"
  flow_actions.style.horizontal_spacing = 8
  local draw = flow_actions.add{type = "button", name = "pbb_draw", caption = {"gui.pbb-draw"}}
  draw.style.width = 75
  local confirm = flow_actions.add{type = "button", name = "pbb_confirm", caption = {"gui.pbb-confirm"}}
  confirm.style.width = 85
  local clear = flow_actions.add{type = "button", name = "pbb_clear", caption = {"gui.pbb-clear"}}
  clear.style.width = 75

  player.opened = window
  return window
end

local function dropdown_items()
  local belts = catalog.list_belts()
  local items = {}
  for _, belt in ipairs(belts) do
    items[#items + 1] = belt.localised_name or {"entity-name." .. belt.name}
  end
  return belts, items
end

function gui.update(player)
  local p_state = state.get(player.index)
  local window = player.gui.screen.pbb_main_window
  if not window then return end
  if not is_valid_window(window) then
    window.destroy()
    window = gui.get_or_create(player)
  end

  catalog.ensure_selected_belt(p_state)

  local belts, items = dropdown_items()
  p_state.gui_belt_names = {}
  local selected_index = 1
  for i, belt in ipairs(belts) do
    p_state.gui_belt_names[i] = belt.name
    if belt.name == p_state.selected_belt_name then
      selected_index = i
    end
  end

  window.flow_belt.pbb_belt_dropdown.items = (#items > 0) and items or {"transport-belt"}
  window.flow_belt.pbb_belt_dropdown.selected_index = selected_index

  window.flow_count.pbb_count_input.text = tostring(p_state.count)
  window.flow_count.pbb_count_minus.enabled = p_state.count > constants.MIN_COUNT
  window.flow_count.pbb_count_plus.enabled = p_state.count < constants.MAX_COUNT

  update_toggle_button(window.flow_side.pbb_side_left, p_state.side == "left", 75)
  update_toggle_button(window.flow_side.pbb_side_right, p_state.side == "right", 75)
  update_toggle_button(window.flow_place.pbb_place_normal, p_state.placement == "normal", 75)
  update_toggle_button(window.flow_place.pbb_place_ghost, p_state.placement == "ghost", 75)

  local side_enabled = p_state.count > 1
  window.flow_side.pbb_side_left.enabled = side_enabled
  window.flow_side.pbb_side_right.enabled = side_enabled

  local has_path = (#p_state.segments > 0)
    or (p_state.current_start ~= nil and p_state.current_end ~= nil)

  window.flow_actions.pbb_confirm.enabled = has_path and p_state.mode ~= constants.MODE_PLACING
  window.flow_actions.pbb_clear.enabled = has_path and p_state.mode ~= constants.MODE_PLACING
  window.flow_actions.pbb_draw.enabled = p_state.mode ~= constants.MODE_PLACING
end

function gui.destroy(player)
  local window = player.gui.screen.pbb_main_window
  if window and window.valid then
    window.destroy()
  end
end

function gui.is_in_window(element)
  local current = element
  while current and current.valid do
    if current.name == "pbb_main_window" then
      return true
    end
    current = current.parent
  end
  return false
end

function gui.parse_count(text)
  local trimmed = (text or ""):match("^%s*(.-)%s*$")
  if trimmed == "" or not trimmed:match("^%d+$") then
    return nil
  end
  local value = tonumber(trimmed)
  if not value or value < constants.MIN_COUNT or value > constants.MAX_COUNT then
    return nil
  end
  return math.floor(value)
end

return gui
