local constants = require("scripts.constants")

local geometry = {}

local function copy_pos(pos)
  return {x = pos.x, y = pos.y}
end

function geometry.snap_position(pos)
  return {
    x = math.floor(pos.x) + 0.5,
    y = math.floor(pos.y) + 0.5
  }
end

function geometry.same_position(a, b)
  return a and b and math.abs(a.x - b.x) < 0.01 and math.abs(a.y - b.y) < 0.01
end

function geometry.direction_between(a, b)
  if math.abs(a.x - b.x) > math.abs(a.y - b.y) then
    return (b.x >= a.x) and defines.direction.east or defines.direction.west
  end
  return (b.y >= a.y) and defines.direction.south or defines.direction.north
end

function geometry.dir_vector(dir)
  if dir == defines.direction.north then return 0, -1 end
  if dir == defines.direction.east then return 1, 0 end
  if dir == defines.direction.south then return 0, 1 end
  if dir == defines.direction.west then return -1, 0 end
  return 0, 0
end

function geometry.offset_vector(direction, side)
  local factor = (side == "left") and -1 or 1
  if direction == defines.direction.north then return factor, 0 end
  if direction == defines.direction.east then return 0, factor end
  if direction == defines.direction.south then return -factor, 0 end
  if direction == defines.direction.west then return 0, -factor end
  return 0, 0
end

local function add_axis_segment(segments, from, to, raw_index)
  if geometry.same_position(from, to) then return end
  local dir = geometry.direction_between(from, to)
  table.insert(segments, {
    from = copy_pos(from),
    to = copy_pos(to),
    direction = dir,
    is_vertical = dir == defines.direction.north or dir == defines.direction.south,
    raw_index = raw_index
  })
end

function geometry.expand_raw_segment(raw, raw_index)
  local result = {}
  local from = raw.from
  local to = raw.to
  if geometry.same_position(from, to) then
    return result
  end

  if math.abs(from.x - to.x) < 0.01 or math.abs(from.y - to.y) < 0.01 then
    add_axis_segment(result, from, to, raw_index)
    return result
  end

  local bend
  if raw.bend == constants.BEND_VERTICAL then
    bend = {x = from.x, y = to.y}
  else
    bend = {x = to.x, y = from.y}
  end

  add_axis_segment(result, from, bend, raw_index)
  add_axis_segment(result, bend, to, raw_index)
  return result
end

function geometry.axis_segments(raw_segments, current_start, current_end, current_bend)
  local axis = {}

  for i, raw in ipairs(raw_segments or {}) do
    for _, segment in ipairs(geometry.expand_raw_segment(raw, i)) do
      table.insert(axis, segment)
    end
  end

  if current_start and current_end and not geometry.same_position(current_start, current_end) then
    local raw = {
      from = current_start,
      to = current_end,
      bend = current_bend or constants.BEND_HORIZONTAL
    }
    for _, segment in ipairs(geometry.expand_raw_segment(raw, #(raw_segments or {}) + 1)) do
      table.insert(axis, segment)
    end
  end

  return axis
end

local function tile_key(pos)
  return string.format("%d,%d", math.floor(pos.x), math.floor(pos.y))
end

function geometry.tiles_for_axis_segments(axis_segments)
  local tiles = {}
  for i, segment in ipairs(axis_segments) do
    local sx, sy = geometry.dir_vector(segment.direction)
    local len = math.floor(math.max(math.abs(segment.to.x - segment.from.x), math.abs(segment.to.y - segment.from.y)) + 0.5)
    local end_idx = (i == #axis_segments) and len or (len - 1)
    for step = 0, end_idx do
      table.insert(tiles, {
        x = segment.from.x + sx * step,
        y = segment.from.y + sy * step,
        direction = segment.direction,
        segment_index = i
      })
    end
  end
  return tiles
end

function geometry.validate(axis_segments)
  if #axis_segments == 0 then
    return false, "message.pbb-no-path"
  end

  for i = 2, #axis_segments do
    local prev = axis_segments[i - 1]
    local curr = axis_segments[i]
    local px, py = geometry.dir_vector(prev.direction)
    local cx, cy = geometry.dir_vector(curr.direction)
    if (px + cx == 0 and py + cy == 0) then
      return false, "message.pbb-invalid-turn-warning"
    end
  end

  local seen = {}
  for _, tile in ipairs(geometry.tiles_for_axis_segments(axis_segments)) do
    local key = tile_key(tile)
    if seen[key] then
      return false, "message.pbb-invalid-path-structure"
    end
    seen[key] = true
  end

  return true
end

function geometry.generate_lane(axis_segments, lane_index, side)
  if #axis_segments == 0 then return {} end

  local offset_coords = {}
  for i, segment in ipairs(axis_segments) do
    local ox, oy = geometry.offset_vector(segment.direction, side)
    offset_coords[i] = segment.is_vertical and (segment.from.x + ox * lane_index) or (segment.from.y + oy * lane_index)
  end

  local vertices = {}
  local ox1, oy1 = geometry.offset_vector(axis_segments[1].direction, side)
  vertices[1] = {
    x = axis_segments[1].from.x + ox1 * lane_index,
    y = axis_segments[1].from.y + oy1 * lane_index
  }

  for i = 2, #axis_segments do
    local prev = axis_segments[i - 1]
    local curr = axis_segments[i]
    if prev.is_vertical then
      vertices[i] = {x = offset_coords[i - 1], y = offset_coords[i]}
    else
      vertices[i] = {x = offset_coords[i], y = offset_coords[i - 1]}
    end
  end

  local last = axis_segments[#axis_segments]
  local oxn, oyn = geometry.offset_vector(last.direction, side)
  vertices[#axis_segments + 1] = {
    x = last.to.x + oxn * lane_index,
    y = last.to.y + oyn * lane_index
  }

  local tiles = {}
  for i, segment in ipairs(axis_segments) do
    local a = vertices[i]
    local b = vertices[i + 1]
    local sx, sy = geometry.dir_vector(segment.direction)
    local dot = (b.x - a.x) * sx + (b.y - a.y) * sy
    if dot < -0.01 then
      return nil, "message.pbb-path-collapse-warning"
    end

    local len = math.floor(math.max(math.abs(b.x - a.x), math.abs(b.y - a.y)) + 0.5)
    local end_idx = (i == #axis_segments) and len or (len - 1)
    for step = 0, end_idx do
      table.insert(tiles, {
        x = a.x + sx * step,
        y = a.y + sy * step,
        direction = segment.direction,
        segment_index = i,
        lane = lane_index + 1
      })
    end
  end

  return tiles
end

function geometry.lane_line_segments(axis_segments, lane_index, side)
  local tiles, err = geometry.generate_lane(axis_segments, lane_index, side)
  if not tiles then return nil, err end

  local by_segment = {}
  for _, tile in ipairs(tiles) do
    local bucket = by_segment[tile.segment_index]
    if not bucket then
      bucket = {}
      by_segment[tile.segment_index] = bucket
    end
    table.insert(bucket, tile)
  end

  local lines = {}
  for i = 1, #axis_segments do
    local bucket = by_segment[i]
    if bucket and #bucket > 0 then
      table.insert(lines, {
        from = {x = bucket[1].x, y = bucket[1].y},
        to = {x = bucket[#bucket].x, y = bucket[#bucket].y}
      })
    end
  end
  return lines
end

return geometry
