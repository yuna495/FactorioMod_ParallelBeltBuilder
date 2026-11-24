local constants = require("scripts.constants")
local state = require("scripts.state")
local catalog = require("scripts.belt_catalog")
local geometry = require("scripts.geometry")
local planner = require("scripts.planner")
local preview = require("scripts.preview")
local place = require("scripts.place")
local gui = require("scripts.gui")

local function player_of(event)
  if not event.player_index then
    return nil
  end
  return game.get_player(event.player_index)
end

local function holding_tool(player)
  local stack = player.cursor_stack
  return stack
    and stack.valid
    and stack.valid_for_read
    and (stack.name == constants.TOOL or stack.name == constants.PREVIEW_TOOL)
end

local function is_tool_name(name)
  return name == constants.TOOL or name == constants.PREVIEW_TOOL
end

local function item_prototype_exists(name)
  return prototypes and prototypes.item and prototypes.item[name] ~= nil
end

local function preferred_tool_name()
  local name = constants.PREVIEW_TOOL
  return item_prototype_exists(name) and name or nil
end

local function has_path(p_state)
  return (#p_state.segments > 0)
    or (p_state.current_start and p_state.current_end and not geometry.same_position(p_state.current_start, p_state.current_end))
end

local function refresh_shortcut(player)
  local window = player.gui.screen.pbb_main_window
  player.set_shortcut_toggled("pbb-toggle-recording", window ~= nil)
end

local function rebuild_preview(player, p_state, update_gui)
  if not has_path(p_state) then
    p_state.plan = nil
    preview.draw(player, p_state, nil)
    if update_gui then
      gui.update(player)
    end
    return
  end

  local plan = planner.build(player, p_state)
  if not plan and #p_state.segments > 0 then
    plan = planner.build(player, {
      count = p_state.count,
      side = p_state.side,
      placement = p_state.placement,
      selected_belt_name = p_state.selected_belt_name,
      segments = p_state.segments,
      current_start = nil,
      current_end = nil,
      current_bend = p_state.current_bend
    })
  end

  p_state.plan = plan
  preview.draw(player, p_state, plan)
  if update_gui then
    gui.update(player)
  end
end

local confirm_plan

local function set_tool(player)
  local target = preferred_tool_name()
  if not target then
    return false
  end

  local stack = player.cursor_stack
  if not (stack and stack.valid) then
    return false
  end

  if stack.valid_for_read and stack.name == target then
    return true
  end

  if stack.valid_for_read and not is_tool_name(stack.name) and not player.clear_cursor() then
    return false
  end

  local ok = pcall(function()
    stack.set_stack{name = target, count = 1}
  end)
  if not ok then
    return false
  end

  return stack.valid_for_read and stack.name == target
end

local function give_tool(player)
  if not set_tool(player) then
    player.print({"message.pbb-cursor-not-cleared"})
    return false
  end
  return true
end

local function begin_drawing(player)
  local p_state = state.get(player.index)
  preview.clear(p_state)
  state.clear_plan(p_state)
  if give_tool(player) then
    p_state.mode = constants.MODE_DRAWING
    player.opened = gui.get_or_create(player)
    gui.update(player)
    refresh_shortcut(player)
    return true
  end
  gui.update(player)
  refresh_shortcut(player)
  return false
end

local function open_pbb(player)
  local p_state = state.get(player.index)
  state.set_count(p_state, 1)
  local cursor_belt = catalog.belt_from_cursor(player)
  if cursor_belt then
    p_state.selected_belt_name = cursor_belt
  else
    catalog.ensure_selected_belt(p_state)
  end

  gui.get_or_create(player)
  begin_drawing(player)
  refresh_shortcut(player)
  rebuild_preview(player, p_state, true)
end

local function cancel_plan(player, clear_cursor)
  local p_state = state.get(player.index)
  preview.clear(p_state)
  state.clear_plan(p_state)
  p_state.mode = constants.MODE_IDLE
  if clear_cursor then
    player.clear_cursor()
  end
  gui.update(player)
  refresh_shortcut(player)
end

local function close_pbb(player)
  cancel_plan(player, true)
  gui.destroy(player)
  refresh_shortcut(player)
end

local function toggle_pbb(player)
  if player.gui.screen.pbb_main_window then
    close_pbb(player)
  else
    open_pbb(player)
  end
end

local function parse_and_apply_count(player, update_preview)
  local p_state = state.get(player.index)
  local window = player.gui.screen.pbb_main_window
  if not window or not window.flow_count or not window.flow_count.pbb_count_input then
    return true
  end

  local input = window.flow_count.pbb_count_input
  local value = gui.parse_count(input.text)
  if not value then
    input.text = tostring(p_state.count)
    return false
  end

  state.set_count(p_state, value)
  if update_preview ~= false then
    rebuild_preview(player, p_state, true)
  end
  return true
end

local function append_current_segment(p_state)
  if not (p_state.current_start and p_state.current_end) then
    return false
  end
  if geometry.same_position(p_state.current_start, p_state.current_end) then
    return false
  end

  table.insert(p_state.segments, {
    from = {x = p_state.current_start.x, y = p_state.current_start.y},
    to = {x = p_state.current_end.x, y = p_state.current_end.y},
    bend = p_state.current_bend
  })
  p_state.current_start = {x = p_state.current_end.x, y = p_state.current_end.y}
  p_state.current_end = nil
  return true
end

local function update_draw_position(player, event)
  if not is_tool_name(event.item) or not holding_tool(player) then return false end
  if event.surface ~= player.surface then return false end

  local p_state = state.get(player.index)
  if p_state.mode ~= constants.MODE_DRAWING then return false end
  local start = geometry.snap_position(event.position)
  local pos = geometry.snap_position(event.cursor_position)

  -- Preselection events are best-effort. Recover from a missing start event,
  -- and discard a stale drawing when a different drag begins.
  if p_state.drag_start and not geometry.same_position(p_state.drag_start, start) then
    preview.clear(p_state)
    state.clear_plan(p_state)
    p_state.mode = constants.MODE_DRAWING
  end
  p_state.drag_start = start

  if p_state.current_end and geometry.same_position(p_state.current_end, pos) then
    return true
  end

  if not p_state.current_start then
    local last = p_state.segments[#p_state.segments]
    p_state.current_start = last and {x = last.to.x, y = last.to.y} or start
  end

  p_state.current_end = pos

  rebuild_preview(player, p_state, false)
  return true
end

local function finish_selection(event)
  if not is_tool_name(event.item) then return end
  local player = player_of(event)
  if not player then return end
  -- Final selection coordinates are authoritative, including when the last
  -- change event (or every preselection event) was dropped.
  if not update_draw_position(player, event) then return end
  confirm_plan(player)
end

function confirm_plan(player)
  local p_state = state.get(player.index)
  if p_state.mode == constants.MODE_PLACING then return end
  if not has_path(p_state) then
    player.print({"message.pbb-no-path"})
    return
  end

  parse_and_apply_count(player, false)
  p_state.mode = constants.MODE_PLACING
  gui.update(player)

  local plan, err = planner.build(player, p_state)
  if not plan then
    player.print({err or "message.pbb-invalid-path-structure"})
    p_state.mode = constants.MODE_DRAWING
    gui.update(player)
    return
  end

  local result = place.commit(player, plan, p_state.placement)
  player.print({"message.pbb-placement-summary", result.entities, result.ghosts, result.existing, result.blocked})

  preview.clear(p_state)
  state.clear_plan(p_state)
  if holding_tool(player) and set_tool(player) then
    p_state.mode = constants.MODE_DRAWING
  else
    p_state.mode = constants.MODE_IDLE
  end
  gui.update(player)
end

script.on_init(function()
  catalog.invalidate_cache()
  state.init()
end)

script.on_configuration_changed(function()
  catalog.invalidate_cache()
  state.init()
  for _, player in pairs(game.players) do
    local p_state = state.get(player.index)
    preview.clear(p_state)
    p_state.plan = nil
    refresh_shortcut(player)
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  state.create_player(event.player_index)
end)

script.on_event(defines.events.on_player_removed, function(event)
  local p_state = storage.players and storage.players[event.player_index]
  if p_state then
    preview.clear(p_state)
    storage.players[event.player_index] = nil
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= "pbb-toggle-recording" then return end
  local player = player_of(event)
  if player then toggle_pbb(player) end
end)

script.on_event("pbb-toggle-recording-key", function(event)
  local player = player_of(event)
  if player then toggle_pbb(player) end
end)

script.on_event("pbb-flip-bend", function(event)
  local player = player_of(event)
  if not (player and holding_tool(player)) then return end
  local p_state = state.get(player.index)
  if p_state.current_bend == constants.BEND_HORIZONTAL then
    p_state.current_bend = constants.BEND_VERTICAL
  else
    p_state.current_bend = constants.BEND_HORIZONTAL
  end
  rebuild_preview(player, p_state, false)
end)

script.on_event("pbb-anchor", function(event)
  local player = player_of(event)
  if not (player and holding_tool(player)) then return end
  local p_state = state.get(player.index)
  if append_current_segment(p_state) then
    rebuild_preview(player, p_state, true)
  end
end)

script.on_event("pbb-cancel", function(event)
  local player = player_of(event)
  if player and holding_tool(player) then
    cancel_plan(player, true)
  end
end)

script.on_event({defines.events.on_player_start_selected_area, defines.events.on_player_change_selected_area}, function(event)
  local player = player_of(event)
  if player then
    update_draw_position(player, event)
  end
end)

script.on_event(defines.events.on_player_cancel_selected_area, function(event)
  if not is_tool_name(event.item) then return end
  local player = player_of(event)
  if not (player and holding_tool(player) and event.surface == player.surface) then return end
  local p_state = state.get(player.index)
  local start = geometry.snap_position(event.position)
  if p_state.drag_start and geometry.same_position(p_state.drag_start, start) then
    preview.clear(p_state)
    state.clear_plan(p_state)
    p_state.mode = constants.MODE_DRAWING
    gui.update(player)
  end
end)

script.on_event(defines.events.on_built_entity, function(event)
  local entity = event.entity
  if entity
    and entity.valid
    and (entity.name == constants.DUMMY_BELT or entity.name == constants.DUMMY_ENTITY)
  then
    entity.destroy()
  end
end)

script.on_event(defines.events.on_player_selected_area, function(event)
  finish_selection(event)
end)

script.on_event(defines.events.on_player_alt_selected_area, function(event)
  finish_selection(event)
end)

script.on_event(defines.events.on_player_reverse_selected_area, function(event)
  finish_selection(event)
end)

script.on_event(defines.events.on_player_alt_reverse_selected_area, function(event)
  finish_selection(event)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  local player = player_of(event)
  if not player then return end
  local p_state = state.get(player.index)
  if not holding_tool(player) and p_state.mode == constants.MODE_DRAWING then
    preview.clear(p_state)
    state.clear_plan(p_state)
    gui.update(player)
  end
end)

script.on_event(defines.events.on_player_changed_surface, function(event)
  local player = player_of(event)
  if player then
    cancel_plan(player, false)
  end
end)

script.on_event(defines.events.on_player_left_game, function(event)
  local p_state = storage.players and storage.players[event.player_index]
  if p_state then
    preview.clear(p_state)
  end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = player_of(event)
  if not player then return end
  local p_state = state.get(player.index)
  if has_path(p_state) then
    gui.get_or_create(player)
    rebuild_preview(player, p_state, true)
  else
    gui.update(player)
  end
  refresh_shortcut(player)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.valid and event.element.name == "pbb_main_window" then
    local player = player_of(event)
    if player then
      close_pbb(player)
    end
  end
end)

script.on_event(defines.events.on_gui_location_changed, function(event)
  if not (event.element and event.element.valid and event.element.name == "pbb_main_window") then return end
  local p_state = state.get(event.player_index)
  p_state.gui_position = event.element.location
end)

script.on_event(defines.events.on_gui_confirmed, function(event)
  if not (event.element and event.element.valid and event.element.name == "pbb_count_input") then return end
  local player = player_of(event)
  if player then parse_and_apply_count(player) end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  if not (event.element and event.element.valid and event.element.name == "pbb_belt_dropdown") then return end
  local player = player_of(event)
  if not player then return end

  local p_state = state.get(player.index)
  local selected = event.element.selected_index
  if p_state.gui_belt_names and p_state.gui_belt_names[selected] then
    p_state.selected_belt_name = p_state.gui_belt_names[selected]
    rebuild_preview(player, p_state, true)
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid) then return end

  local player = player_of(event)
  if not player then return end
  local p_state = state.get(player.index)

  if gui.is_in_window(element) and element.name ~= "pbb_count_input" then
    parse_and_apply_count(player)
  end

  if element.name == "pbb_count_minus" then
    state.set_count(p_state, p_state.count - 1)
    rebuild_preview(player, p_state, true)
  elseif element.name == "pbb_count_plus" then
    state.set_count(p_state, p_state.count + 1)
    rebuild_preview(player, p_state, true)
  elseif element.name == "pbb_side_left" and p_state.count > 1 then
    p_state.side = "left"
    rebuild_preview(player, p_state, true)
  elseif element.name == "pbb_side_right" and p_state.count > 1 then
    p_state.side = "right"
    rebuild_preview(player, p_state, true)
  elseif element.name == "pbb_place_normal" then
    p_state.placement = "normal"
    gui.update(player)
  elseif element.name == "pbb_place_ghost" then
    p_state.placement = "ghost"
    gui.update(player)
  elseif element.name == "pbb_draw" then
    begin_drawing(player)
  end
end)
