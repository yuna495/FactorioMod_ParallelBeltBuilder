local constants = require("scripts.constants")

local place = {}

local function ghost_type_for(entry)
  if entry.kind == constants.KIND_UNDERGROUND_INPUT then
    return "input"
  elseif entry.kind == constants.KIND_UNDERGROUND_OUTPUT then
    return "output"
  end
  return nil
end

local function physical_entity_params(player, entry)
  local params = {
    name = entry.prototype,
    position = {x = entry.x, y = entry.y},
    direction = entry.direction,
    force = player.force,
    raise_built = true
  }

  if entry.kind == constants.KIND_UNDERGROUND_INPUT then
    params.belt_to_ground_type = "input"
  elseif entry.kind == constants.KIND_UNDERGROUND_OUTPUT then
    params.belt_to_ground_type = "output"
    params.direction = (entry.direction + 8) % 16
  end

  return params
end

local function ghost_entity_params(player, entry)
  local params = {
    name = "entity-ghost",
    inner_name = entry.prototype,
    position = {x = entry.x, y = entry.y},
    direction = entry.direction,
    force = player.force,
    raise_built = true
  }

  local underground_type = ghost_type_for(entry)
  if underground_type then
    params.type = underground_type
  end

  return params
end

local function is_placeable_entry(entry)
  return entry.state == constants.STATE_NORMAL
    and entry.kind ~= constants.KIND_UNDERGROUND_HIDDEN
    and entry.prototype ~= nil
end

local function apply_undo_params(params, undo_state)
  params.player = undo_state.player_index
  params.undo_index = undo_state.started and 1 or 0
end

local function create_with_undo(player, params, undo_state)
  apply_undo_params(params, undo_state)
  local entity = player.surface.create_entity(params)
  if entity then
    undo_state.started = true
  end
  return entity
end

local function place_physical(player, entry, undo_state)
  return create_with_undo(player, physical_entity_params(player, entry), undo_state)
end

local function place_ghost(player, entry, undo_state)
  return create_with_undo(player, ghost_entity_params(player, entry), undo_state)
end

function place.commit(player, plan, placement_mode)
  local placed_entities = 0
  local placed_ghosts = 0
  local skipped_blocked = 0
  local skipped_existing = 0

  local free_build = player.controller_type == defines.controllers.editor or player.cheat_mode
  local available = {}
  local undo_state = {
    player_index = player.index,
    started = false
  }

  local function item_count(item_name)
    if free_build then return 0 end
    if not item_name then return 0 end
    if available[item_name] == nil then
      available[item_name] = player.get_item_count(item_name)
    end
    return available[item_name]
  end

  for _, entry in ipairs(plan.entries or {}) do
    if entry.state == constants.STATE_EXISTING then
      skipped_existing = skipped_existing + 1
    elseif entry.state == constants.STATE_BLOCKED then
      skipped_blocked = skipped_blocked + 1
    elseif is_placeable_entry(entry) then
      if placement_mode == "normal" then
        if free_build then
          if place_physical(player, entry, undo_state) then
            placed_entities = placed_entities + 1
          end
        elseif item_count(entry.item_name) > 0 then
          if place_physical(player, entry, undo_state) then
            placed_entities = placed_entities + 1
            available[entry.item_name] = available[entry.item_name] - 1
            player.remove_item{name = entry.item_name, count = 1}
          end
        else
          if place_ghost(player, entry, undo_state) then
            placed_ghosts = placed_ghosts + 1
          end
        end
      else
        if place_ghost(player, entry, undo_state) then
          placed_ghosts = placed_ghosts + 1
        end
      end
    end
  end

  return {
    entities = placed_entities,
    ghosts = placed_ghosts,
    blocked = skipped_blocked,
    existing = skipped_existing
  }
end

return place
