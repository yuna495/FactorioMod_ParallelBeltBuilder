local constants = require("scripts.constants")

local preview = {}

local LINE_COLOR = {r = 0.2, g = 0.9, b = 1.0, a = 0.85}
local OUTER_LINE_COLOR = {r = 0.95, g = 0.85, b = 0.25, a = 0.85}
local BLOCKED_TINT = {r = 1.0, g = 0.15, b = 0.1, a = 0.95}
local START_TINT = {r = 0.15, g = 0.75, b = 1.0, a = 0.95}
local ANCHOR_TINT = {r = 0.35, g = 0.95, b = 0.45, a = 0.9}

local function store(p_state, object)
  p_state.preview_objects = p_state.preview_objects or {}
  table.insert(p_state.preview_objects, object)
end

function preview.clear(p_state)
  if not p_state or not p_state.preview_objects then return end
  for _, object in pairs(p_state.preview_objects) do
    if object and object.valid then
      object.destroy()
    end
  end
  p_state.preview_objects = {}
end

local function draw_lines(player, p_state, plan)
  for lane, lines in pairs(plan.line_lanes or {}) do
    local color = (lane == 1) and LINE_COLOR or OUTER_LINE_COLOR
    for _, line in ipairs(lines or {}) do
      store(p_state, rendering.draw_line{
        color = color,
        width = 4,
        from = line.from,
        to = line.to,
        surface = player.surface,
        players = {player}
      })
    end
  end
end

local function marker_orientation(direction)
  return (direction or 0) / 16
end

local function position_key(pos)
  return string.format("%d,%d", math.floor(pos.x), math.floor(pos.y))
end

local function draw_edit_marker(player, p_state, pos, tint)
  store(p_state, rendering.draw_sprite{
    sprite = "pbb-anchor",
    target = pos,
    x_scale = 0.42,
    y_scale = 0.42,
    tint = tint,
    surface = player.surface,
    players = {player}
  })
end

local function draw_markers(player, p_state, plan)
  for _, entry in ipairs(plan.entries or {}) do
    if entry.kind == constants.KIND_UNDERGROUND_INPUT
      or entry.kind == constants.KIND_UNDERGROUND_OUTPUT
    then
      store(p_state, rendering.draw_sprite{
        sprite = "pbb-entryexit",
        target = {x = entry.x, y = entry.y},
        orientation = marker_orientation(entry.direction),
        x_scale = 0.45,
        y_scale = 0.45,
        surface = player.surface,
        players = {player}
      })
    elseif entry.state == constants.STATE_BLOCKED then
      store(p_state, rendering.draw_sprite{
        sprite = "pbb-blocked",
        target = {x = entry.x, y = entry.y},
        x_scale = 0.5,
        y_scale = 0.5,
        tint = BLOCKED_TINT,
        surface = player.surface,
        players = {player}
      })
    end
  end
end

local function draw_edit_markers(player, p_state)
  local seen = {}
  local first_segment = p_state.segments and p_state.segments[1] or nil
  local start = first_segment and first_segment.from or p_state.current_start

  if start then
    seen[position_key(start)] = true
    draw_edit_marker(player, p_state, start, START_TINT)
  end

  for _, segment in ipairs(p_state.segments or {}) do
    local anchor = segment.to
    local key = position_key(anchor)
    if not seen[key] then
      seen[key] = true
      draw_edit_marker(player, p_state, anchor, ANCHOR_TINT)
    end
  end
end

function preview.draw(player, p_state, plan)
  preview.clear(p_state)
  if plan then
    draw_lines(player, p_state, plan)
    draw_markers(player, p_state, plan)
  end
  draw_edit_markers(player, p_state)
end

return preview
