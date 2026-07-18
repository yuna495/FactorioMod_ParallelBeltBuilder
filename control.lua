-- control.lua

-- プレイヤーごとの状態を初期化
local function init_players()
  storage.players = storage.players or {}
  for _, player in pairs(game.players) do
    if not storage.players[player.index] then
      storage.players[player.index] = {
        recording = false,
        path = {}
      }
    end
  end
end

script.on_init(function()
  init_players()
end)

script.on_configuration_changed(function()
  init_players()
end)

script.on_event(defines.events.on_player_created, function(event)
  storage.players[event.player_index] = {
    recording = false,
    path = {}
  }
end)

script.on_event(defines.events.on_player_removed, function(event)
  storage.players[event.player_index] = nil
end)

-- 基準経路の方向に応じた、右側のオフセット座標を取得
local function get_right_offsets(direction, col)
  -- col は 1, 2, 3 (並列の列インデックス)
  if direction == defines.direction.north then
    return col, 0
  elseif direction == defines.direction.east then
    return 0, col
  elseif direction == defines.direction.south then
    return -col, 0
  elseif direction == defines.direction.west then
    return 0, -col
  end
  return 0, 0
end

-- 直線経路かどうかの判定
local function is_straight_path(path)
  if #path == 0 then return false end
  
  local base_dir = path[1].direction
  local base_x = path[1].x
  local base_y = path[1].y
  
  local is_vertical = (base_dir == defines.direction.north or base_dir == defines.direction.south)
  
  for i = 2, #path do
    -- すべて同じ向きであること
    if path[i].direction ~= base_dir then
      return false
    end
    -- 垂直方向ならX座標が、水平方向ならY座標が一致すること
    if is_vertical then
      if math.abs(path[i].x - base_x) > 0.01 then
        return false
      end
    else
      if math.abs(path[i].y - base_y) > 0.01 then
        return false
      end
    end
  end
  return true
end

-- 記録された経路から並列ゴーストベルトを配置
local function process_and_place(player, path)
  if #path == 0 then return end
  
  -- 直線判定
  if not is_straight_path(path) then
    player.print({"message.pbb-not-straight-path"})
    return
  end

  -- 重複位置の排除
  local seen = {}
  local unique_path = {}
  for _, item in ipairs(path) do
    local key = string.format("%.1f,%.1f", item.x, item.y)
    if not seen[key] then
      seen[key] = true
      table.insert(unique_path, item)
    end
  end

  local placed_count = 0
  for _, item in ipairs(unique_path) do
    for col = 1, 3 do
      local dx, dy = get_right_offsets(item.direction, col)
      local target_pos = {x = item.x + dx, y = item.y + dy}

      -- 黄色ベルトがその位置に配置可能かチェック (障害物や水など)
      local can_place = player.surface.can_place_entity{
        name = "transport-belt",
        position = target_pos,
        direction = item.direction,
        force = player.force,
        build_check_type = defines.build_check_type.manual_ghost
      }

      if can_place then
        local ghost = player.surface.create_entity{
          name = "entity-ghost",
          inner_name = "transport-belt",
          position = target_pos,
          direction = item.direction,
          force = player.force,
          raise_built = true
        }
        if ghost then
          placed_count = placed_count + 1
        end
      end
    end
  end
  
  if placed_count > 0 then
    player.print({"message.pbb-ghosts-placed", placed_count})
  else
    player.print({"message.pbb-no-ghosts-placed"})
  end
end

-- 記録トグル処理
local function toggle_recording(player)
  local p_state = storage.players[player.index]
  if not p_state then
    p_state = { recording = false, path = {} }
    storage.players[player.index] = p_state
  end

  if not p_state.recording then
    -- 記録開始
    p_state.recording = true
    p_state.path = {}
    player.set_shortcut_toggled("pbb-toggle-recording", true)
    player.print({"message.pbb-recording-started"})
  else
    -- 記録終了
    p_state.recording = false
    player.set_shortcut_toggled("pbb-toggle-recording", false)
    player.print({"message.pbb-recording-stopped"})
    
    process_and_place(player, p_state.path)
    p_state.path = {}
  end
end

-- ショートカットクリックイベントの検知
script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "pbb-toggle-recording" then
    local player = game.get_player(event.player_index)
    if not player then return end
    toggle_recording(player)
  end
end)

-- 黄色ベルト配置イベントの検知
script.on_event(defines.events.on_built_entity, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local p_state = storage.players[player.index]
  if p_state and p_state.recording then
    local entity = event.entity
    if entity and entity.valid and entity.name == "transport-belt" then
      table.insert(p_state.path, {
        x = entity.position.x,
        y = entity.position.y,
        direction = entity.direction
      })
    end
  end
end)
