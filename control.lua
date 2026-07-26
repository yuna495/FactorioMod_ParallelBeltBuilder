-- control.lua

local MIN_COUNT = 2
local MAX_COUNT = 16

local MODE_WAITING = "waiting"
local MODE_RECORDING = "recording"
local MODE_PLACING = "placing"

local function get_default_player_state()
  return {
    mode = MODE_WAITING,
    count = 4,
    side = "right",
    placement = "ghost",
    gui_position = nil,
    belt_type = nil,
    path = {}
  }
end

local function normalize_player_state(p_state)
  local default = get_default_player_state()
  for k, v in pairs(default) do
    if p_state[k] == nil then
      p_state[k] = v
    end
  end

  if p_state.mode == nil then
    if p_state.placing then
      p_state.mode = MODE_PLACING
    elseif p_state.recording then
      p_state.mode = MODE_RECORDING
    else
      p_state.mode = MODE_WAITING
    end
  end

  if p_state.mode ~= MODE_WAITING and p_state.mode ~= MODE_RECORDING and p_state.mode ~= MODE_PLACING then
    p_state.mode = MODE_WAITING
  end

  local count = tonumber(p_state.count) or 4
  count = math.floor(count)
  if count < MIN_COUNT then
    count = MIN_COUNT
  elseif count > MAX_COUNT then
    count = MAX_COUNT
  end
  p_state.count = count

  if p_state.side ~= "left" and p_state.side ~= "right" then
    p_state.side = "right"
  end
  if p_state.placement ~= "normal" and p_state.placement ~= "ghost" then
    p_state.placement = "ghost"
  end
  if type(p_state.path) ~= "table" then
    p_state.path = {}
  end

  p_state.recording = nil
  p_state.placing = nil
end

local function clear_reference_path(p_state)
  p_state.belt_type = nil
  p_state.path = {}
end

local function init_players()
  storage.players = storage.players or {}
  for _, player in pairs(game.players) do
    if not storage.players[player.index] then
      storage.players[player.index] = get_default_player_state()
    end
    normalize_player_state(storage.players[player.index])

    local window = player.gui.screen.pbb_main_window
    player.set_shortcut_toggled("pbb-toggle-recording", window ~= nil)
  end
end

script.on_init(function()
  init_players()
end)

script.on_configuration_changed(function()
  init_players()
end)

script.on_event(defines.events.on_player_created, function(event)
  storage.players[event.player_index] = get_default_player_state()
end)

script.on_event(defines.events.on_player_removed, function(event)
  storage.players[event.player_index] = nil
end)

local function get_or_create_gui(player)
  local window = player.gui.screen.pbb_main_window
  if window and (not window.flow_count or not window.flow_count.pbb_count_input or (window.flow_actions and window.flow_actions.pbb_start)) then
    window.destroy()
    window = nil
  end

  if not window then
    window = player.gui.screen.add{
      type = "frame",
      name = "pbb_main_window",
      caption = "Parallel Belt Builder",
      direction = "vertical"
    }

    local p_state = storage.players[player.index]

    if p_state.gui_position then
      window.location = p_state.gui_position
    else
      window.location = {x = 80, y = 150}
    end

    local flow_belt = window.add{type = "flow", name = "flow_belt", direction = "horizontal"}
    flow_belt.style.vertical_align = "center"
    flow_belt.style.horizontal_spacing = 8
    local lbl_belt = flow_belt.add{type = "label", caption = "Belt: "}
    lbl_belt.style.width = 80
    flow_belt.add{type = "label", name = "belt_label", caption = "Not selected"}

    local flow_count = window.add{type = "flow", name = "flow_count", direction = "horizontal"}
    flow_count.style.vertical_align = "center"
    flow_count.style.horizontal_spacing = 8
    local lbl_count = flow_count.add{type = "label", caption = "Count: "}
    lbl_count.style.width = 80
    local btn_minus = flow_count.add{type = "button", name = "pbb_count_minus", caption = "-"}
    btn_minus.style.width = 30
    local count_input = flow_count.add{type = "textfield", name = "pbb_count_input", text = tostring(p_state.count)}
    count_input.style.width = 45
    count_input.lose_focus_on_confirm = true
    local btn_plus = flow_count.add{type = "button", name = "pbb_count_plus", caption = "+"}
    btn_plus.style.width = 30

    local flow_side = window.add{type = "flow", name = "flow_side", direction = "horizontal"}
    flow_side.style.vertical_align = "center"
    flow_side.style.horizontal_spacing = 8
    local lbl_side = flow_side.add{type = "label", caption = "Side: "}
    lbl_side.style.width = 80
    local btn_left = flow_side.add{type = "button", name = "pbb_side_left", caption = "Left"}
    btn_left.style.width = 75
    local btn_right = flow_side.add{type = "button", name = "pbb_side_right", caption = "Right"}
    btn_right.style.width = 75

    local flow_place = window.add{type = "flow", name = "flow_place", direction = "horizontal"}
    flow_place.style.vertical_align = "center"
    flow_place.style.horizontal_spacing = 8
    local lbl_place = flow_place.add{type = "label", caption = "Placement: "}
    lbl_place.style.width = 80
    local btn_normal = flow_place.add{type = "button", name = "pbb_place_normal", caption = "Normal"}
    btn_normal.style.width = 75
    local btn_ghost = flow_place.add{type = "button", name = "pbb_place_ghost", caption = "Ghost"}
    btn_ghost.style.width = 75

    local line = window.add{type = "line", direction = "horizontal"}
    line.style.top_margin = 8
    line.style.bottom_margin = 8

    local flow_actions = window.add{type = "flow", name = "flow_actions", direction = "horizontal"}
    flow_actions.style.vertical_align = "center"
    flow_actions.style.horizontal_spacing = 8
    local btn_build = flow_actions.add{type = "button", name = "pbb_stop", caption = "Build"}
    btn_build.style.width = 75
    local btn_clear = flow_actions.add{type = "button", name = "pbb_clear", caption = "Clear"}
    btn_clear.style.width = 75

    player.opened = window
  end

  return window
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

local function update_gui(player)
  local p_state = storage.players[player.index]
  if not p_state then return end

  local window = player.gui.screen.pbb_main_window
  if not window then return end
  if not window.flow_count or not window.flow_count.pbb_count_input or not window.flow_actions or not window.flow_actions.pbb_clear then
    window.destroy()
    window = get_or_create_gui(player)
  end

  if p_state.belt_type then
    window.flow_belt.belt_label.caption = {"entity-name." .. p_state.belt_type}
  else
    window.flow_belt.belt_label.caption = "Not selected"
  end

  if window.flow_count.pbb_count_input then
    window.flow_count.pbb_count_input.text = tostring(p_state.count)
  end

  update_toggle_button(window.flow_side.pbb_side_left, p_state.side == "left", 75)
  update_toggle_button(window.flow_side.pbb_side_right, p_state.side == "right", 75)
  update_toggle_button(window.flow_place.pbb_place_normal, p_state.placement == "normal", 75)
  update_toggle_button(window.flow_place.pbb_place_ghost, p_state.placement == "ghost", 75)

  local mode = p_state.mode or MODE_WAITING
  local is_waiting = mode == MODE_WAITING
  local is_recording = mode == MODE_RECORDING
  local is_placing = mode == MODE_PLACING
  local has_path = p_state.path and #p_state.path > 0

  window.flow_count.pbb_count_minus.enabled = is_waiting
  window.flow_count.pbb_count_input.enabled = is_waiting
  window.flow_count.pbb_count_plus.enabled = is_waiting
  window.flow_side.pbb_side_left.enabled = is_waiting
  window.flow_side.pbb_side_right.enabled = is_waiting
  window.flow_place.pbb_place_normal.enabled = is_waiting
  window.flow_place.pbb_place_ghost.enabled = is_waiting

  window.flow_actions.pbb_stop.enabled = is_recording and has_path and not is_placing
  window.flow_actions.pbb_clear.enabled = is_recording and not is_placing
end

local function trim(text)
  return (text or ""):match("^%s*(.-)%s*$")
end

local function parse_count(text)
  local value_text = trim(text)
  if value_text == "" or not value_text:match("^%d+$") then
    return nil
  end

  local value = tonumber(value_text)
  if not value or value < MIN_COUNT or value > MAX_COUNT then
    return nil
  end

  return value
end

local function confirm_count_input(player)
  local p_state = storage.players[player.index]
  local window = player.gui.screen.pbb_main_window
  if not p_state or not window or not window.flow_count or not window.flow_count.pbb_count_input then
    return true
  end

  local input = window.flow_count.pbb_count_input
  if p_state.mode ~= MODE_WAITING then
    input.text = tostring(p_state.count)
    return false
  end

  local value = parse_count(input.text)
  if value then
    p_state.count = value
    input.text = tostring(value)
    update_gui(player)
    return true
  end

  input.text = tostring(p_state.count)
  return false
end

local function get_dir_vector(dir)
  if dir == defines.direction.north then return 0, -1
  elseif dir == defines.direction.east then return 1, 0
  elseif dir == defines.direction.south then return 0, 1
  elseif dir == defines.direction.west then return -1, 0
  end
  return 0, 0
end

local function get_offset_vector(direction, side)
  local factor = (side == "left") and -1 or 1
  if direction == defines.direction.north then return factor, 0
  elseif direction == defines.direction.east then return 0, factor
  elseif direction == defines.direction.south then return -factor, 0
  elseif direction == defines.direction.west then return 0, -factor
  end
  return 0, 0
end

local function analyze_path(player, path, expected_belt_type)
  if #path == 0 then return nil, "message.pbb-no-belts-placed" end

  local surface = player.surface
  local seen = {}
  local unique_nodes = {}

  for _, item in ipairs(path) do
    local tx = math.floor(item.x)
    local ty = math.floor(item.y)
    local key = string.format("%d,%d", tx, ty)

    if not seen[key] then
      local ents = surface.find_entities_filtered{
        position = {x = tx + 0.5, y = ty + 0.5},
        radius = 0.45,
        type = "transport-belt"
      }

      local actual_name = nil
      local actual_dir = nil
      if #ents > 0 and ents[1].valid then
        actual_name = ents[1].name
        actual_dir = ents[1].direction
      end

      if actual_name then
        if actual_name ~= expected_belt_type then
          return nil, "message.pbb-path-modified-error"
        end

        seen[key] = {
          tx = tx,
          ty = ty,
          x = tx + 0.5,
          y = ty + 0.5,
          direction = actual_dir,
          key = key,
          incoming = {},
          outgoing = {}
        }
        table.insert(unique_nodes, seen[key])
      end
    end
  end

  if #unique_nodes == 0 then
    return nil, "message.pbb-no-belts-placed"
  end

  for _, node in ipairs(unique_nodes) do
    local dx, dy = get_dir_vector(node.direction)
    local dest_tx = node.tx + dx
    local dest_ty = node.ty + dy
    local dest_key = string.format("%d,%d", dest_tx, dest_ty)

    local dest_node = seen[dest_key]
    if dest_node then
      table.insert(node.outgoing, dest_key)
      table.insert(dest_node.incoming, node.key)
    end
  end

  local starts = {}
  local ends = {}
  for _, node in ipairs(unique_nodes) do
    local in_count = #node.incoming
    local out_count = #node.outgoing

    if in_count > 1 or out_count > 1 then
      return nil, "message.pbb-path-has-branches"
    end

    if in_count == 0 then
      table.insert(starts, node)
    end
    if out_count == 0 then
      table.insert(ends, node)
    end
  end

  if #starts ~= 1 or #ends ~= 1 then
    return nil, "message.pbb-invalid-path-structure"
  end

  local start_node = starts[1]
  local sorted_path = {}
  local current = start_node
  local visited = {}

  while current do
    if visited[current.key] then
      return nil, "message.pbb-invalid-path-structure"
    end
    visited[current.key] = true
    table.insert(sorted_path, current)

    if #current.outgoing > 0 then
      current = seen[current.outgoing[1]]
    else
      current = nil
    end
  end

  if #sorted_path ~= #unique_nodes then
    return nil, "message.pbb-invalid-path-structure"
  end

  return sorted_path
end

local function group_into_segments(sorted_path)
  local segments = {}
  if #sorted_path == 0 then return segments end

  local current_seg = {
    direction = sorted_path[1].direction,
    is_vertical = (sorted_path[1].direction == defines.direction.north or sorted_path[1].direction == defines.direction.south),
    nodes = { sorted_path[1] }
  }

  for i = 2, #sorted_path do
    local node = sorted_path[i]
    local is_vert = (node.direction == defines.direction.north or node.direction == defines.direction.south)
    if node.direction == current_seg.direction then
      table.insert(current_seg.nodes, node)
    else
      if current_seg.is_vertical == is_vert then
        return nil, "message.pbb-invalid-turn-warning"
      end

      current_seg.base_coord = current_seg.is_vertical and current_seg.nodes[1].x or current_seg.nodes[1].y
      table.insert(segments, current_seg)

      current_seg = {
        direction = node.direction,
        is_vertical = is_vert,
        nodes = { node }
      }
    end
  end

  current_seg.base_coord = current_seg.is_vertical and current_seg.nodes[1].x or current_seg.nodes[1].y
  table.insert(segments, current_seg)

  return segments
end

local function generate_parallel_path(segments, col, side)
  local N = #segments
  if N == 0 then return {} end

  for _, seg in ipairs(segments) do
    local ox, oy = get_offset_vector(seg.direction, side)
    if seg.is_vertical then
      seg.offset_coord = seg.base_coord + ox * col
    else
      seg.offset_coord = seg.base_coord + oy * col
    end
  end

  local vertices = {}

  local ox1, oy1 = get_offset_vector(segments[1].direction, side)
  local start_node = segments[1].nodes[1]
  table.insert(vertices, {x = start_node.x + ox1 * col, y = start_node.y + oy1 * col})

  for i = 2, N do
    local prev = segments[i - 1]
    local curr = segments[i]
    local intersection = {}
    if prev.is_vertical then
      intersection.x = prev.offset_coord
      intersection.y = curr.offset_coord
    else
      intersection.x = curr.offset_coord
      intersection.y = prev.offset_coord
    end
    table.insert(vertices, intersection)
  end

  local last_seg = segments[N]
  local oxN, oyN = get_offset_vector(last_seg.direction, side)
  local last_node = last_seg.nodes[#last_seg.nodes]
  table.insert(vertices, {x = last_node.x + oxN * col, y = last_node.y + oyN * col})

  local parallel_tiles = {}
  for i = 1, N do
    local A = vertices[i]
    local B = vertices[i + 1]
    local dir = segments[i].direction

    local dx = B.x - A.x
    local dy = B.y - A.y
    local step_x, step_y = get_dir_vector(dir)
    local dot = dx * step_x + dy * step_y

    if dot < -0.01 then
      return nil, "message.pbb-path-collapse-warning"
    end

    local len = math.max(math.abs(dx), math.abs(dy))
    local end_idx = (i == N) and len or (len - 1)

    for step = 0, end_idx do
      local tx = A.x + step_x * step
      local ty = A.y + step_y * step
      table.insert(parallel_tiles, {x = tx, y = ty, direction = dir})
    end
  end

  return parallel_tiles
end

local function check_tile_state(surface, target_pos, belt_type, direction, force)
  local existing_belts = surface.find_entities_filtered{
    position = target_pos,
    radius = 0.45,
    type = "transport-belt"
  }
  if #existing_belts > 0 then
    return "skip_no_consume"
  end

  local existing_ghosts = surface.find_entities_filtered{
    position = target_pos,
    radius = 0.45,
    name = "entity-ghost"
  }
  for _, ghost in ipairs(existing_ghosts) do
    if ghost.ghost_name == belt_type and ghost.direction == direction then
      return "skip_no_consume"
    else
      return "skip_no_consume"
    end
  end

  local can_place = surface.can_place_entity{
    name = belt_type,
    position = target_pos,
    direction = direction,
    force = force,
    build_check_type = defines.build_check_type.manual_ghost
  }
  if not can_place then
    return "skip_no_consume"
  end

  return "place"
end

local function reset_placement_state(player)
  local p_state = storage.players[player.index]
  if p_state then
    p_state.mode = MODE_WAITING
    clear_reference_path(p_state)
  end

  local window = player.gui.screen.pbb_main_window
  player.set_shortcut_toggled("pbb-toggle-recording", window ~= nil)
  update_gui(player)
end

local function confirm_placement(player)
  local p_state = storage.players[player.index]
  if not p_state or p_state.mode == MODE_PLACING or #p_state.path == 0 or not p_state.belt_type then
    return false
  end

  p_state.mode = MODE_PLACING
  update_gui(player)

  local sorted_path, err = analyze_path(player, p_state.path, p_state.belt_type)
  if not sorted_path then
    player.print({err})
    reset_placement_state(player)
    return false
  end

  local segments, err2 = group_into_segments(sorted_path)
  if not segments then
    player.print({err2})
    reset_placement_state(player)
    return false
  end

  local belt_type = p_state.belt_type
  local count = p_state.count
  local side = p_state.side
  local placement = p_state.placement
  local surface = player.surface

  local all_parallel_tiles = {}
  for col = 1, count - 1 do
    local col_tiles, err3 = generate_parallel_path(segments, col, side)
    if not col_tiles then
      player.print({err3})
      reset_placement_state(player)
      return false
    end
    for _, tile in ipairs(col_tiles) do
      table.insert(all_parallel_tiles, tile)
    end
  end

  local seen = {}
  local unique_tiles = {}
  for _, tile in ipairs(all_parallel_tiles) do
    local key = string.format("%.1f,%.1f", tile.x, tile.y)
    if not seen[key] then
      seen[key] = true
      table.insert(unique_tiles, tile)
    end
  end

  local place_positions = {}
  for _, tile in ipairs(unique_tiles) do
    local state = check_tile_state(surface, {x = tile.x, y = tile.y}, belt_type, tile.direction, player.force)
    if state == "place" then
      table.insert(place_positions, tile)
    end
  end

  if #place_positions == 0 then
    player.print({"message.pbb-no-belts-placed"})
    reset_placement_state(player)
    return true
  end

  local placed_entities = 0
  local placed_ghosts = 0

  if placement == "normal" then
    local free_build =
      player.controller_type == defines.controllers.editor
      or player.cheat_mode
    local available_count = free_build and 0 or player.get_item_count(belt_type)

    for _, tile in ipairs(place_positions) do
      if free_build then
        local ent = surface.create_entity{
          name = belt_type,
          position = {x = tile.x, y = tile.y},
          direction = tile.direction,
          force = player.force,
          raise_built = true
        }
        if ent then
          placed_entities = placed_entities + 1
        end
      elseif available_count > 0 then
        local ent = surface.create_entity{
          name = belt_type,
          position = {x = tile.x, y = tile.y},
          direction = tile.direction,
          force = player.force,
          raise_built = true
        }
        if ent then
          placed_entities = placed_entities + 1
          available_count = available_count - 1
          player.remove_item{name = belt_type, count = 1}
        end
      else
        local ghost = surface.create_entity{
          name = "entity-ghost",
          inner_name = belt_type,
          position = {x = tile.x, y = tile.y},
          direction = tile.direction,
          force = player.force,
          raise_built = true
        }
        if ghost then
          placed_ghosts = placed_ghosts + 1
        end
      end
    end
  else
    for _, tile in ipairs(place_positions) do
      local ghost = surface.create_entity{
        name = "entity-ghost",
        inner_name = belt_type,
        position = {x = tile.x, y = tile.y},
        direction = tile.direction,
        force = player.force,
        raise_built = true
      }
      if ghost then
        placed_ghosts = placed_ghosts + 1
      end
    end
  end

  reset_placement_state(player)
  return true
end

local function build_action(player)
  local p_state = storage.players[player.index]
  if not p_state or p_state.mode ~= MODE_RECORDING or #p_state.path == 0 or not p_state.belt_type then
    return
  end

  confirm_placement(player)
end

local function cancel_action(player)
  reset_placement_state(player)
end

local function toggle_gui_and_recording(player)
  local window = player.gui.screen.pbb_main_window

  if not window then
    get_or_create_gui(player)
    reset_placement_state(player)
    player.set_shortcut_toggled("pbb-toggle-recording", true)
  else
    reset_placement_state(player)
    if window.valid then
      window.destroy()
    end
    player.set_shortcut_toggled("pbb-toggle-recording", false)
  end
end

local function is_in_pbb_window(element)
  local current = element
  while current and current.valid do
    if current.name == "pbb_main_window" then
      return true
    end
    current = current.parent
  end
  return false
end

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "pbb-toggle-recording" then
    local player = game.get_player(event.player_index)
    if not player then return end
    toggle_gui_and_recording(player)
  end
end)

script.on_event("pbb-toggle-recording-key", function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  toggle_gui_and_recording(player)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.valid and event.element.name == "pbb_main_window" then
    local player = game.get_player(event.player_index)
    if player then
      reset_placement_state(player)
      if event.element.valid then
        event.element.destroy()
      end
      player.set_shortcut_toggled("pbb-toggle-recording", false)
    end
  end
end)

script.on_event(defines.events.on_gui_confirmed, function(event)
  local element = event.element
  if not element or not element.valid or element.name ~= "pbb_count_input" then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  confirm_count_input(player)
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not element or not element.valid then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local p_state = storage.players[player.index]
  if not p_state then return end

  if element.name ~= "pbb_count_input" and is_in_pbb_window(element) and p_state.mode == MODE_WAITING then
    local window = player.gui.screen.pbb_main_window
    local input = window and window.flow_count and window.flow_count.pbb_count_input
    if input and input.text ~= tostring(p_state.count) and not confirm_count_input(player) then
      return
    end
  end

  local can_configure = p_state.mode == MODE_WAITING

  if element.name == "pbb_count_minus" then
    if can_configure and p_state.count > MIN_COUNT then
      p_state.count = p_state.count - 1
      update_gui(player)
    end
  elseif element.name == "pbb_count_plus" then
    if can_configure and p_state.count < MAX_COUNT then
      p_state.count = p_state.count + 1
      update_gui(player)
    end
  elseif element.name == "pbb_side_left" then
    if can_configure then
      p_state.side = "left"
      update_gui(player)
    end
  elseif element.name == "pbb_side_right" then
    if can_configure then
      p_state.side = "right"
      update_gui(player)
    end
  elseif element.name == "pbb_place_normal" then
    if can_configure then
      p_state.placement = "normal"
      update_gui(player)
    end
  elseif element.name == "pbb_place_ghost" then
    if can_configure then
      p_state.placement = "ghost"
      update_gui(player)
    end
  elseif element.name == "pbb_stop" then
    build_action(player)
  elseif element.name == "pbb_clear" or element.name == "pbb_cancel" then
    cancel_action(player)
  end
end)

script.on_event(defines.events.on_gui_location_changed, function(event)
  local element = event.element
  if element and element.valid and element.name == "pbb_main_window" then
    local player = game.get_player(event.player_index)
    if player and storage.players[player.index] then
      storage.players[player.index].gui_position = element.location
    end
  end
end)

script.on_event(defines.events.on_built_entity, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local p_state = storage.players[player.index]
  if not p_state then return end

  if not player.gui.screen.pbb_main_window then
    return
  end

  local entity = event.entity
  if not entity or not entity.valid or entity.type ~= "transport-belt" then
    return
  end

  if p_state.mode == MODE_PLACING then
    return
  end

  if p_state.mode == MODE_WAITING then
    confirm_count_input(player)
    clear_reference_path(p_state)
    p_state.mode = MODE_RECORDING
  elseif p_state.mode ~= MODE_RECORDING then
    return
  end

  if not p_state.belt_type then
    p_state.belt_type = entity.name
  elseif p_state.belt_type ~= entity.name then
    player.print({"message.pbb-different-belt-warning"})
    update_gui(player)
    return
  end

  table.insert(p_state.path, {
    x = entity.position.x,
    y = entity.position.y
  })

  update_gui(player)
end)
