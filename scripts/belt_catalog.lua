local constants = require("scripts.constants")

local catalog = {}
local belt_cache = nil

local function prototype_name(proto)
  if not proto then
    return nil
  end
  if type(proto) == "string" then
    return proto
  end

  local ok, name = pcall(function()
    return proto.name
  end)
  if ok then
    return name
  end
  return nil
end

local function first_item_name(entity_proto)
  if not entity_proto then
    return nil
  end

  local ok, items = pcall(function()
    return entity_proto.items_to_place_this
  end)
  if not ok then
    return nil
  end

  if items and items[1] then
    return items[1].name
  end
  return nil
end

function catalog.get_belt_info(belt_name)
  local entity = prototypes.entity[belt_name]
  if not entity or entity.type ~= "transport-belt" then
    return nil
  end

  local underground_name = prototype_name(entity.related_underground_belt)
  local underground = underground_name and prototypes.entity[underground_name] or nil
  local max_distance = underground and underground.max_underground_distance or nil

  return {
    name = entity.name,
    localised_name = entity.localised_name,
    item_name = first_item_name(entity),
    underground_name = underground and underground.name or nil,
    underground_item_name = first_item_name(underground),
    max_underground_distance = max_distance
  }
end

function catalog.default_belt_name()
  local default = catalog.get_belt_info(constants.DEFAULT_BELT)
  if default and default.item_name then
    return constants.DEFAULT_BELT
  end

  for _, belt in ipairs(catalog.list_belts()) do
    return belt.name
  end
  return nil
end

local function is_user_selectable_belt(name, proto)
  if name == constants.DUMMY_BELT then return false end
  if proto.type ~= "transport-belt" then return false end

  local info = catalog.get_belt_info(name)
  if not (info and info.item_name) then
    return false
  end

  return true
end

local function build_belt_cache()
  local belts = {}
  for name, proto in pairs(prototypes.entity) do
    if is_user_selectable_belt(name, proto) then
      table.insert(belts, {
        name = name,
        localised_name = proto.localised_name
      })
    end
  end
  table.sort(belts, function(a, b) return a.name < b.name end)
  return belts
end

function catalog.list_belts()
  if not belt_cache then
    belt_cache = build_belt_cache()
  end
  return belt_cache
end

function catalog.invalidate_cache()
  belt_cache = nil
end

function catalog.belt_from_cursor(player)
  local stack = player.cursor_stack
  if not (stack and stack.valid and stack.valid_for_read) then
    return nil
  end

  local item_proto = stack.prototype
  local place_result = item_proto and item_proto.place_result
  if place_result and place_result.type == "transport-belt" and is_user_selectable_belt(place_result.name, place_result) then
    return place_result.name
  end
  return nil
end

function catalog.ensure_selected_belt(p_state)
  local selected = p_state.selected_belt_name and catalog.get_belt_info(p_state.selected_belt_name)
  if selected and selected.item_name then
    return p_state.selected_belt_name
  end

  p_state.selected_belt_name = catalog.default_belt_name()
  return p_state.selected_belt_name
end

return catalog
