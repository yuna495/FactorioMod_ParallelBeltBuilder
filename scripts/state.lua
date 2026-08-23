local constants = require("scripts.constants")

local state = {}

local function default_player_state()
  return {
    mode = constants.MODE_IDLE,
    count = 1,
    side = "right",
    placement = "ghost",
    gui_position = nil,
    selected_belt_name = nil,
    segments = {},
    current_start = nil,
    current_end = nil,
    drag_start = nil,
    current_bend = constants.BEND_HORIZONTAL,
    plan = nil,
    preview_objects = {}
  }
end

local function clamp_count(value)
  local count = math.floor(tonumber(value) or 1)
  if count < constants.MIN_COUNT then
    count = constants.MIN_COUNT
  elseif count > constants.MAX_COUNT then
    count = constants.MAX_COUNT
  end
  return count
end

function state.normalize(p_state)
  local default = default_player_state()
  for key, value in pairs(default) do
    if p_state[key] == nil then
      p_state[key] = value
    end
  end

  if p_state.belt_type and not p_state.selected_belt_name then
    p_state.selected_belt_name = p_state.belt_type
  end

  p_state.count = clamp_count(p_state.count)

  if p_state.side ~= "left" and p_state.side ~= "right" then
    p_state.side = "right"
  end

  if p_state.placement ~= "normal" and p_state.placement ~= "ghost" then
    p_state.placement = "ghost"
  end

  if p_state.mode ~= constants.MODE_IDLE
    and p_state.mode ~= constants.MODE_DRAWING
    and p_state.mode ~= constants.MODE_PLACING
  then
    p_state.mode = constants.MODE_IDLE
  end

  if p_state.mode == "recording" or p_state.mode == "placing" then
    p_state.mode = constants.MODE_IDLE
  end

  if p_state.current_bend ~= constants.BEND_HORIZONTAL
    and p_state.current_bend ~= constants.BEND_VERTICAL
  then
    p_state.current_bend = constants.BEND_HORIZONTAL
  end

  if type(p_state.segments) ~= "table" then
    p_state.segments = {}
  end
  if type(p_state.preview_objects) ~= "table" then
    p_state.preview_objects = {}
  end

  p_state.path = nil
  p_state.recording = nil
  p_state.placing = nil
  p_state.belt_type = nil
end

function state.init()
  storage.players = storage.players or {}
  for _, player in pairs(game.players) do
    storage.players[player.index] = storage.players[player.index] or default_player_state()
    state.normalize(storage.players[player.index])
  end
end

function state.create_player(player_index)
  storage.players = storage.players or {}
  storage.players[player_index] = default_player_state()
  return storage.players[player_index]
end

function state.get(player_index)
  storage.players = storage.players or {}
  local p_state = storage.players[player_index]
  if not p_state then
    p_state = default_player_state()
    storage.players[player_index] = p_state
  end
  state.normalize(p_state)
  return p_state
end

function state.clear_plan(p_state)
  p_state.segments = {}
  p_state.current_start = nil
  p_state.current_end = nil
  p_state.drag_start = nil
  p_state.plan = nil
  p_state.current_bend = p_state.current_bend or constants.BEND_HORIZONTAL
  if p_state.mode ~= constants.MODE_PLACING then
    p_state.mode = constants.MODE_IDLE
  end
end

function state.set_count(p_state, value)
  p_state.count = clamp_count(value)
end

return state
