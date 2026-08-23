local constants = require("scripts.constants")
local catalog = require("scripts.belt_catalog")
local geometry = require("scripts.geometry")

local planner = {}

local function key_for(entry)
  return string.format("%d,%d", math.floor(entry.x), math.floor(entry.y))
end

local function key_for_tile(tile)
  return string.format("%d,%d", math.floor(tile.x), math.floor(tile.y))
end

local function position_of(entry)
  return {x = entry.x, y = entry.y}
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

local function is_transport_belt_ghost(entity)
  if not (entity.valid and entity.name == "entity-ghost" and entity.ghost_name) then
    return false
  end

  local ghost_proto = prototypes.entity[entity.ghost_name]
  return ghost_proto and ghost_proto.type == "transport-belt"
end

local function conflicting_transport_belt(entity, belt_name, direction)
  if existing_transport_belt(entity, belt_name, direction)
    or existing_transport_belt_ghost(entity, belt_name, direction)
  then
    return false
  end

  return (entity.valid and entity.type == "transport-belt")
    or is_transport_belt_ghost(entity)
end

local function entry_key(entry)
  return string.format("%d,%d", math.floor(entry.x), math.floor(entry.y))
end

local function tile_key_from_xy(x, y)
  return string.format("%d,%d", x, y)
end

local function add_entity_to_tile(entities_by_tile, key, entity)
  local entities = entities_by_tile[key]
  if not entities then
    entities = {}
    entities_by_tile[key] = entities
  end
  entities[#entities + 1] = entity
end

local function entity_bounds(entity)
  local ok, box = pcall(function()
    return entity.bounding_box
  end)
  if ok and box then
    return {
      left_top = box.left_top or box[1],
      right_bottom = box.right_bottom or box[2]
    }
  end

  local pos = entity.position
  return {
    left_top = {x = pos.x - 0.5, y = pos.y - 0.5},
    right_bottom = {x = pos.x + 0.5, y = pos.y + 0.5}
  }
end

local function build_entity_lookup(surface, target_tiles, chunks)
  local entities_by_tile = {}
  local seen_entities = {}

  for chunk_key in pairs(chunks) do
    local comma = chunk_key:find(",", 1, true)
    local cx = tonumber(chunk_key:sub(1, comma - 1))
    local cy = tonumber(chunk_key:sub(comma + 1))
    local area = {
      {cx * 32 - 0.5, cy * 32 - 0.5},
      {(cx + 1) * 32 + 0.5, (cy + 1) * 32 + 0.5}
    }

    for _, entity in ipairs(surface.find_entities_filtered{area = area}) do
      if entity.valid then
        local unit_key = entity.unit_number or (entity.name .. "@" .. entity.position.x .. "," .. entity.position.y)
        if not seen_entities[unit_key] then
          seen_entities[unit_key] = true
          local box = entity_bounds(entity)
          local min_x = math.floor(box.left_top.x)
          local max_x = math.floor(box.right_bottom.x)
          local min_y = math.floor(box.left_top.y)
          local max_y = math.floor(box.right_bottom.y)

          for x = min_x, max_x do
            for y = min_y, max_y do
              local key = tile_key_from_xy(x, y)
              if target_tiles[key] then
                add_entity_to_tile(entities_by_tile, key, entity)
              end
            end
          end
        end
      end
    end
  end

  return entities_by_tile
end

local function can_place_cached(surface, force, cache, name, pos, direction)
  local key = name .. "|" .. math.floor(pos.x) .. "," .. math.floor(pos.y) .. "|" .. direction
  local cached = cache[key]
  if cached ~= nil then
    return cached
  end

  local can_place = surface.can_place_entity{
    name = name,
    position = pos,
    direction = direction,
    force = force,
    build_check_type = defines.build_check_type.manual_ghost
  }
  cache[key] = can_place
  return can_place
end

local function classify_entry(surface, force, belt_name, entry, entities_by_tile, can_place_cache)
  local pos = position_of(entry)
  local entities = entities_by_tile[entry_key(entry)] or {}

  for _, entity in ipairs(entities) do
    if existing_transport_belt(entity, belt_name, entry.direction)
      or existing_transport_belt_ghost(entity, belt_name, entry.direction)
    then
      entry.state = constants.STATE_EXISTING
      entry.existing = true
      return
    end
  end

  for _, entity in ipairs(entities) do
    if conflicting_transport_belt(entity, belt_name, entry.direction) then
      entry.state = constants.STATE_BLOCKED
      entry.blocked_reason = "transport-belt-collision"
      return
    end
  end

  local can_place = can_place_cached(surface, force, can_place_cache, belt_name, pos, entry.direction)

  if can_place then
    entry.state = constants.STATE_NORMAL
  else
    entry.state = constants.STATE_BLOCKED
    entry.blocked_reason = (#entities > 0) and "entity-collision" or "cannot-place"
  end
end

local function endpoint_is_clear(entry)
  return entry
    and entry.kind == constants.KIND_BELT
    and entry.state == constants.STATE_NORMAL
end

local function endpoint_can_be_underground(surface, force, can_place_cache, underground_name, entry, belt_to_ground_type)
  if not endpoint_is_clear(entry) then return false end

  local direction = entry.direction

  if belt_to_ground_type == "output" then
    direction = (entry.direction + 8) % 16
  end

  return can_place_cached(surface, force, can_place_cache, underground_name, position_of(entry), direction)
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

local function blocked_run(entries, group, blocked_index)
  local first = blocked_index
  local last = blocked_index

  while first > group.first and entries[first - 1].state == constants.STATE_BLOCKED do
    first = first - 1
  end

  while last < group.last and entries[last + 1].state == constants.STATE_BLOCKED do
    last = last + 1
  end

  return first, last
end

local function find_underground_candidate(surface, force, can_place_cache, entries, group, blocked_first, blocked_last, belt_info)
  local max_distance = belt_info.max_underground_distance
  local underground_name = belt_info.underground_name
  if not (underground_name and max_distance) then
    return nil, nil
  end

  local blocked_direction = entries[blocked_first].direction

  for entry_index = blocked_first - 1, group.first, -1 do
    if blocked_first - entry_index > max_distance + 1 then
      break
    end

    local entry = entries[entry_index]
    if entry.direction ~= blocked_direction then
      break
    end

    if endpoint_can_be_underground(surface, force, can_place_cache, underground_name, entry, "input") then
      for exit_index = blocked_last + 1, group.last do
        local underground_nodes = exit_index - entry_index - 1
        if underground_nodes > max_distance then
          break
        end

        local exit = entries[exit_index]
        if exit.direction ~= entry.direction then
          break
        end

        if endpoint_can_be_underground(surface, force, can_place_cache, underground_name, exit, "output")
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
  entry.item_name = belt_info.underground_item_name
  entry.state = constants.STATE_NORMAL

  exit.kind = constants.KIND_UNDERGROUND_OUTPUT
  exit.prototype = belt_info.underground_name
  exit.item_name = belt_info.underground_item_name
  exit.state = constants.STATE_NORMAL

  for i = entry_index + 1, exit_index - 1 do
    entries[i].kind = constants.KIND_UNDERGROUND_HIDDEN
    entries[i].state = constants.STATE_HIDDEN
    entries[i].prototype = nil
    entries[i].item_name = nil
    entries[i].blocked_reason = nil
  end
end

local function underground_lane(surface, force, can_place_cache, lane, belt_info)
  local groups = group_segment_indices(lane.entries)

  for _, group in pairs(groups) do
    local i = group.first
    while i <= group.last do
      local entry = lane.entries[i]
      if entry and entry.state == constants.STATE_BLOCKED then
        local blocked_first, blocked_last = blocked_run(lane.entries, group, i)
        local entry_index, exit_index = find_underground_candidate(
          surface,
          force,
          can_place_cache,
          lane.entries,
          group,
          blocked_first,
          blocked_last,
          belt_info
        )
        if entry_index and exit_index then
          apply_underground(lane.entries, entry_index, exit_index, belt_info)
          i = exit_index + 1
        else
          i = blocked_last + 1
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

local function line_segments_from_tiles(tiles)
  local by_segment = {}
  for _, tile in ipairs(tiles or {}) do
    local bucket = by_segment[tile.segment_index]
    if not bucket then
      bucket = {}
      by_segment[tile.segment_index] = bucket
    end
    bucket[#bucket + 1] = tile
  end

  local lines = {}
  for i = 1, #by_segment do
    local bucket = by_segment[i]
    if bucket and #bucket > 0 then
      lines[#lines + 1] = {
        from = {x = bucket[1].x, y = bucket[1].y},
        to = {x = bucket[#bucket].x, y = bucket[#bucket].y}
      }
    end
  end
  return lines
end

local function remember_target_tile(target_tiles, chunks, tile)
  local tx = math.floor(tile.x)
  local ty = math.floor(tile.y)
  target_tiles[tile_key_from_xy(tx, ty)] = true
  local cx = math.floor(tx / 32)
  local cy = math.floor(ty / 32)
  chunks[tile_key_from_xy(cx, cy)] = true
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
  local occupied_by_lane = {}
  local target_tiles = {}
  local chunks = {}

  for lane_index = 0, p_state.count - 1 do
    local tiles, lane_err = geometry.generate_lane(axis_segments, lane_index, p_state.side)
    if not tiles then
      return nil, lane_err
    end

    local lane_ok, lane_collision_err = geometry.validate_lane_tiles(tiles)
    if not lane_ok then
      return nil, lane_collision_err
    end

    for _, tile in ipairs(tiles) do
      local key = key_for_tile(tile)
      local existing_lane = occupied_by_lane[key]
      if existing_lane and existing_lane ~= lane_index + 1 then
        return nil, "message.pbb-path-collapse-warning"
      end
      occupied_by_lane[key] = lane_index + 1
      remember_target_tile(target_tiles, chunks, tile)
    end

    local lane = {
      index = lane_index + 1,
      tiles = tiles,
      entries = make_entries(tiles, belt_info)
    }

    table.insert(plan.lanes, lane)
  end

  local entities_by_tile = build_entity_lookup(player.surface, target_tiles, chunks)
  local can_place_cache = {}

  for _, lane in ipairs(plan.lanes) do
    for _, entry in ipairs(lane.entries) do
      classify_entry(player.surface, player.force, belt_info.name, entry, entities_by_tile, can_place_cache)
    end
    underground_lane(player.surface, player.force, can_place_cache, lane, belt_info)
    for _, entry in ipairs(lane.entries) do
      plan.entries[#plan.entries + 1] = entry
    end
  end

  plan.line_lanes[1] = line_segments_from_tiles(plan.lanes[1] and plan.lanes[1].tiles)
  if p_state.count > 1 then
    plan.line_lanes[p_state.count] = line_segments_from_tiles(plan.lanes[p_state.count] and plan.lanes[p_state.count].tiles)
  end

  return plan
end

return planner
