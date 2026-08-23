local constants = require("scripts.constants")
local catalog = require("scripts.belt_catalog")
local geometry = require("scripts.geometry")

local planner = {}

local function key_for(entry)
  return string.format("%d,%d", math.floor(entry.x), math.floor(entry.y))
end

local function position_of(entry)
  return {x = entry.x, y = entry.y}
end

local function find_entities(surface, pos)
  return surface.find_entities_filtered{
    area = {
      {pos.x - 0.45, pos.y - 0.45},
      {pos.x + 0.45, pos.y + 0.45}
    }
  }
end

local function existing_transport_belt(entity, belt_name, direction)
  return entity.valid
    and entity.type == "transport-belt"
    and entity.name == belt_name
    and entity.direction == direction
end

local function existing_transport_belt_ghost(entity, belt_name, direction)
  return entity.valid
    and entity.name == "entity-ghost"
    and entity.ghost_name == belt_name
    and entity.direction == direction
end

local function classify_entry(surface, force, belt_name, entry)
  local pos = position_of(entry)
  local entities = find_entities(surface, pos)

  for _, entity in ipairs(entities) do
    if existing_transport_belt(entity, belt_name, entry.direction)
      or existing_transport_belt_ghost(entity, belt_name, entry.direction)
    then
      entry.state = constants.STATE_EXISTING
      entry.existing = true
      return
    end
  end

  if #entities > 0 then
    entry.state = constants.STATE_BLOCKED
    entry.blocked_reason = "entity"
    return
  end

  local can_place = surface.can_place_entity{
    name = belt_name,
    position = pos,
    direction = entry.direction,
    force = force,
    build_check_type = defines.build_check_type.manual_ghost
  }

  if can_place then
    entry.state = constants.STATE_NORMAL
  else
    entry.state = constants.STATE_BLOCKED
    entry.blocked_reason = "cannot-place"
  end
end

local function endpoint_is_clear(entry)
  return entry
    and entry.kind == constants.KIND_BELT
    and entry.state == constants.STATE_NORMAL
end

local function interior_can_be_undergrounded(entries, start_index, end_index)
  for i = start_index, end_index do
    local entry = entries[i]
    if not entry then return false end
    if entry.state == constants.STATE_EXISTING then
      return false
    end
    if entry.kind ~= constants.KIND_BELT then
      return false
    end
  end
  return true
end

local function can_place_underground(surface, force, underground_name, entry)
  if not endpoint_is_clear(entry) then return false end

  local pos = position_of(entry)
  if #find_entities(surface, pos) > 0 then
    return false
  end

  return surface.can_place_entity{
    name = underground_name,
    position = pos,
    direction = entry.direction,
    force = force,
    build_check_type = defines.build_check_type.manual_ghost
  }
end

local function group_segment_indices(entries)
  local groups = {}
  for i, entry in ipairs(entries) do
    local group = groups[entry.segment_index]
    if not group then
      group = {first = i, last = i}
      groups[entry.segment_index] = group
    else
      group.last = i
    end
  end
  return groups
end

local function find_underground_candidate(surface, force, entries, group, blocked_index, belt_info)
  local max_distance = belt_info.max_underground_distance
  local underground_name = belt_info.underground_name
  if not (underground_name and max_distance) then
    return nil, nil
  end

  for entry_index = blocked_index - 1, group.first, -1 do
    if blocked_index - entry_index > max_distance + 1 then
      break
    end

    local entry = entries[entry_index]
    if entry.direction ~= entries[blocked_index].direction then
      break
    end

    if can_place_underground(surface, force, underground_name, entry) then
      for exit_index = blocked_index + 1, group.last do
        local underground_nodes = exit_index - entry_index - 1
        if underground_nodes > max_distance then
          break
        end

        local exit = entries[exit_index]
        if exit.direction ~= entry.direction then
          break
        end

        if can_place_underground(surface, force, underground_name, exit)
          and interior_can_be_undergrounded(entries, entry_index + 1, exit_index - 1)
        then
          return entry_index, exit_index
        end
      end
    end
  end

  return nil, nil
end

local function apply_underground(entries, entry_index, exit_index, belt_info)
  local entry = entries[entry_index]
  local exit = entries[exit_index]

  entry.kind = constants.KIND_UNDERGROUND_INPUT
  entry.prototype = belt_info.underground_name
  entry.item_name = belt_info.underground_item_name or belt_info.underground_name
  entry.state = constants.STATE_NORMAL

  exit.kind = constants.KIND_UNDERGROUND_OUTPUT
  exit.prototype = belt_info.underground_name
  exit.item_name = belt_info.underground_item_name or belt_info.underground_name
  exit.state = constants.STATE_NORMAL

  for i = entry_index + 1, exit_index - 1 do
    entries[i].kind = constants.KIND_UNDERGROUND_HIDDEN
    entries[i].state = constants.STATE_HIDDEN
    entries[i].prototype = nil
    entries[i].item_name = nil
    entries[i].blocked_reason = nil
  end
end

local function underground_lane(surface, force, lane, belt_info)
  local groups = group_segment_indices(lane.entries)

  for _, group in pairs(groups) do
    local i = group.first
    while i <= group.last do
      local entry = lane.entries[i]
      if entry and entry.state == constants.STATE_BLOCKED then
        local entry_index, exit_index = find_underground_candidate(surface, force, lane.entries, group, i, belt_info)
        if entry_index and exit_index then
          apply_underground(lane.entries, entry_index, exit_index, belt_info)
          i = exit_index + 1
        else
          i = i + 1
        end
      else
        i = i + 1
      end
    end
  end
end

local function make_entries(tiles, belt_info)
  local entries = {}
  for index, tile in ipairs(tiles) do
    entries[index] = {
      lane = tile.lane,
      tile_index = index,
      segment_index = tile.segment_index,
      x = tile.x,
      y = tile.y,
      direction = tile.direction,
      kind = constants.KIND_BELT,
      state = constants.STATE_NORMAL,
      prototype = belt_info.name,
      item_name = belt_info.item_name
    }
  end
  return entries
end

function planner.build(player, p_state)
  local belt_name = catalog.ensure_selected_belt(p_state)
  if not belt_name then
    return nil, "message.pbb-no-belt-selected"
  end

  local belt_info = catalog.get_belt_info(belt_name)
  if not belt_info then
    return nil, "message.pbb-no-belt-selected"
  end

  local axis_segments = geometry.axis_segments(
    p_state.segments,
    p_state.current_start,
    p_state.current_end,
    p_state.current_bend
  )

  local ok, err = geometry.validate(axis_segments)
  if not ok then
    return nil, err
  end

  local plan = {
    belt = belt_info,
    axis_segments = axis_segments,
    lanes = {},
    entries = {},
    line_lanes = {}
  }

  for lane_index = 0, p_state.count - 1 do
    local tiles, lane_err = geometry.generate_lane(axis_segments, lane_index, p_state.side)
    if not tiles then
      return nil, lane_err
    end

    local lane = {
      index = lane_index + 1,
      tiles = tiles,
      entries = make_entries(tiles, belt_info)
    }

    for _, entry in ipairs(lane.entries) do
      classify_entry(player.surface, player.force, belt_info.name, entry)
    end

    underground_lane(player.surface, player.force, lane, belt_info)
    table.insert(plan.lanes, lane)
    for _, entry in ipairs(lane.entries) do
      plan.entries[#plan.entries + 1] = entry
    end
  end

  plan.line_lanes[1] = geometry.lane_line_segments(axis_segments, 0, p_state.side)
  if p_state.count > 1 then
    plan.line_lanes[p_state.count] = geometry.lane_line_segments(axis_segments, p_state.count - 1, p_state.side)
  end

  return plan
end

return planner
