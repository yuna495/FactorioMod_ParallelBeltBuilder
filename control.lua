-- control.lua

local function get_default_player_state()
  return {
    recording = false,
    previewing = false,
    count = 4,
    side = "right",
    placement = "ghost",
    gui_position = nil,
    belt_type = nil,
    path = {}
  }
end

-- プレイヤーごとの状態を初期化
local function init_players()
  storage.players = storage.players or {}
  for _, player in pairs(game.players) do
    if not storage.players[player.index] then
      storage.players[player.index] = get_default_player_state()
    else
      -- キーの欠損対策（アップデート時など）
      local default = get_default_player_state()
      for k, v in pairs(default) do
        if storage.players[player.index][k] == nil then
          storage.players[player.index][k] = v
        end
      end
    end
    -- ショートカットトグル状態の同期
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

-- GUIの作成
local function get_or_create_gui(player)
  local window = player.gui.screen.pbb_main_window
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
      window.force_auto_center()
    end
    
    -- Belt Info
    local flow_belt = window.add{type = "flow", name = "flow_belt", direction = "horizontal"}
    flow_belt.add{type = "label", caption = "Belt: "}
    flow_belt.add{type = "label", name = "belt_label", caption = "Not selected"}
    
    -- Count Info
    local flow_count = window.add{type = "flow", name = "flow_count", direction = "horizontal"}
    flow_count.add{type = "label", caption = "Count: "}
    flow_count.add{type = "button", name = "pbb_count_minus", caption = "-"}
    flow_count.add{type = "label", name = "count_label", caption = "4"}
    flow_count.add{type = "button", name = "pbb_count_plus", caption = "+"}
    
    -- Side Info
    local flow_side = window.add{type = "flow", name = "flow_side", direction = "horizontal"}
    flow_side.add{type = "label", caption = "Side: "}
    flow_side.add{type = "button", name = "pbb_side_left", caption = "Left"}
    flow_side.add{type = "button", name = "pbb_side_right", caption = "Right"}
    
    -- Placement Info
    local flow_place = window.add{type = "flow", name = "flow_place", direction = "horizontal"}
    flow_place.add{type = "label", caption = "Placement: "}
    flow_place.add{type = "button", name = "pbb_place_normal", caption = "Normal"}
    flow_place.add{type = "button", name = "pbb_place_ghost", caption = "Ghost"}
    
    -- Actions
    local flow_actions = window.add{type = "flow", name = "flow_actions", direction = "horizontal"}
    flow_actions.add{type = "button", name = "pbb_start", caption = "Start recording"}
    flow_actions.add{type = "button", name = "pbb_stop", caption = "Stop recording"}
    flow_actions.add{type = "button", name = "pbb_cancel", caption = "Cancel"}
  end
  return window
end

-- GUI状態の更新
local function update_gui(player)
  local p_state = storage.players[player.index]
  if not p_state then return end
  
  local window = player.gui.screen.pbb_main_window
  if not window then return end
  
  -- Belt label
  local belt_label = window.flow_belt.belt_label
  if p_state.belt_type then
    belt_label.caption = {"entity-name." .. p_state.belt_type}
  else
    belt_label.caption = "Not selected"
  end
  
  -- Count label
  window.flow_count.count_label.caption = tostring(p_state.count)
  
  -- Side style
  local side_left = window.flow_side.pbb_side_left
  local side_right = window.flow_side.pbb_side_right
  if p_state.side == "left" then
    side_left.style = "confirm_button"
    side_right.style = "button"
  else
    side_left.style = "button"
    side_right.style = "confirm_button"
  end
  
  -- Placement style
  local place_normal = window.flow_place.pbb_place_normal
  local place_ghost = window.flow_place.pbb_place_ghost
  if p_state.placement == "normal" then
    place_normal.style = "confirm_button"
    place_ghost.style = "button"
  else
    place_normal.style = "button"
    place_ghost.style = "confirm_button"
  end
  
  local is_recording = p_state.recording
  local is_idle = not is_recording
  
  -- 待機状態 (Idle) のときのみ設定変更可能
  window.flow_count.pbb_count_minus.enabled = is_idle
  window.flow_count.pbb_count_plus.enabled = is_idle
  side_left.enabled = is_idle
  side_right.enabled = is_idle
  place_normal.enabled = is_idle
  place_ghost.enabled = is_idle
  
  window.flow_actions.pbb_start.enabled = is_idle
  window.flow_actions.pbb_stop.enabled = is_recording
  window.flow_actions.pbb_cancel.enabled = is_recording
end

-- 基準経路の方向に応じたオフセット座標を取得
local function get_side_offsets(direction, col, side)
  local factor = (side == "left") and -1 or 1
  if direction == defines.direction.north then
    return col * factor, 0
  elseif direction == defines.direction.east then
    return 0, col * factor
  elseif direction == defines.direction.south then
    return -col * factor, 0
  elseif direction == defines.direction.west then
    return 0, -col * factor
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
    if path[i].direction ~= base_dir then
      return false
    end
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

-- タイル配置可能性・消費対象判定
local function check_tile_state(surface, target_pos, belt_type, direction, force)
  -- 1. 既存のベルトがあるかチェック
  local existing_belts = surface.find_entities_filtered{
    position = target_pos,
    radius = 0.45,
    type = "transport-belt"
  }
  if #existing_belts > 0 then
    return "skip_no_consume"
  end
  
  -- 既存のゴーストがあるかチェック
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

  -- 2. その位置に実体またはゴーストが配置できるかチェック
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

-- 記録リセット処理
local function reset_placement_state(player)
  local p_state = storage.players[player.index]
  if p_state then
    p_state.recording = false
    p_state.previewing = false
    p_state.belt_type = nil
    p_state.path = {}
  end
  local window = player.gui.screen.pbb_main_window
  player.set_shortcut_toggled("pbb-toggle-recording", window ~= nil)
  update_gui(player)
end

-- 記録開始処理
local function start_recording(player)
  local p_state = storage.players[player.index]
  if not p_state then return end
  
  p_state.recording = true
  p_state.previewing = false
  p_state.belt_type = nil
  p_state.path = {}
  
  player.print({"message.pbb-recording-started"})
  update_gui(player)
end

-- 配置確定処理 (実体またはゴースト配置)
local function confirm_placement(player)
  local p_state = storage.players[player.index]
  if not p_state or #p_state.path == 0 or not p_state.belt_type then
    return false
  end

  local path = p_state.path
  local belt_type = p_state.belt_type
  local count = p_state.count
  local side = p_state.side
  local placement = p_state.placement
  local surface = player.surface

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

  -- 配置対象タイルの選定
  local place_positions = {}
  for _, item in ipairs(unique_path) do
    for col = 1, count - 1 do
      local dx, dy = get_side_offsets(item.direction, col, side)
      local target_pos = {x = item.x + dx, y = item.y + dy}
      
      local state = check_tile_state(surface, target_pos, belt_type, item.direction, player.force)
      if state == "place" then
        table.insert(place_positions, {pos = target_pos, dir = item.direction})
      end
    end
  end

  if #place_positions == 0 then
    player.print({"message.pbb-no-belts-placed"})
    reset_placement_state(player)
    return true
  end

  if placement == "normal" then
    -- 通常配置モード：アイテム消費チェック
    local required_count = #place_positions
    local available_count = player.get_item_count(belt_type)
    if available_count < required_count then
      -- アイテム不足：部分配置せず警告して終了（記録中ではないため、記録やり直しの必要性を避けるため状態はIdleに戻さず、記録中状態をキャンセル状態とするか、あるいはConfirm失敗として待機状態に戻す。今回は失敗として待機状態に戻し、配置をキャンセルする）
      player.print({"message.pbb-insufficient-items", required_count, {"entity-name." .. belt_type}, available_count})
      reset_placement_state(player)
      return false
    end

    -- アイテム消費
    player.remove_item{name = belt_type, count = required_count}
    
    -- 実体配置
    local placed = 0
    for _, item in ipairs(place_positions) do
      local ent = surface.create_entity{
        name = belt_type,
        position = item.pos,
        direction = item.dir,
        force = player.force,
        raise_built = true
      }
      if ent then
        placed = placed + 1
      end
    end
    player.print({"message.pbb-entities-placed", placed})

  else
    -- ゴースト配置モード
    local placed = 0
    for _, item in ipairs(place_positions) do
      local ghost = surface.create_entity{
        name = "entity-ghost",
        inner_name = belt_type,
        position = item.pos,
        direction = item.dir,
        force = player.force,
        raise_built = true
      }
      if ghost then
        placed = placed + 1
      end
    end
    player.print({"message.pbb-ghosts-placed", placed})
  end

  reset_placement_state(player)
  return true
end

-- 記録停止処理 (即時に配置処理を実行)
local function stop_recording(player)
  local p_state = storage.players[player.index]
  if not p_state or not p_state.recording then return end
  
  p_state.recording = false
  
  if #p_state.path == 0 then
    player.print({"message.pbb-no-belts-placed"})
    reset_placement_state(player)
    return
  end

  if not is_straight_path(p_state.path) then
    player.print({"message.pbb-not-straight-path"})
    reset_placement_state(player)
    return
  end
  
  player.print({"message.pbb-recording-stopped"})
  
  -- 配置処理の即時実行
  confirm_placement(player)
end

-- キャンセル処理
local function cancel_action(player)
  player.print({"message.pbb-placement-cancelled"})
  reset_placement_state(player)
end

-- ショートカット・GUIトグル処理
local function toggle_gui_and_recording(player)
  local window = player.gui.screen.pbb_main_window
  
  if not window then
    -- GUIを開く（待機状態）
    get_or_create_gui(player)
    update_gui(player)
    player.set_shortcut_toggled("pbb-toggle-recording", true)
  else
    -- GUIを閉じる
    local p_state = storage.players[player.index]
    if p_state.recording then
      cancel_action(player)
    end
    if player.gui.screen.pbb_main_window then
      player.gui.screen.pbb_main_window.destroy()
    end
    player.set_shortcut_toggled("pbb-toggle-recording", false)
  end
end

-- ショートカットイベント
script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "pbb-toggle-recording" then
    local player = game.get_player(event.player_index)
    if not player then return end
    toggle_gui_and_recording(player)
  end
end)

-- GUIボタンクリックイベント
script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not element or not element.valid then return end
  
  local player = game.get_player(event.player_index)
  if not player then return end
  
  local p_state = storage.players[player.index]
  if not p_state then return end
  
  if element.name == "pbb_count_minus" then
    if p_state.count > 2 then
      p_state.count = p_state.count - 1
      update_gui(player)
    end
  elseif element.name == "pbb_count_plus" then
    if p_state.count < 16 then
      p_state.count = p_state.count + 1
      update_gui(player)
    end
  elseif element.name == "pbb_side_left" then
    p_state.side = "left"
    update_gui(player)
  elseif element.name == "pbb_side_right" then
    p_state.side = "right"
    update_gui(player)
  elseif element.name == "pbb_place_normal" then
    p_state.placement = "normal"
    update_gui(player)
  elseif element.name == "pbb_place_ghost" then
    p_state.placement = "ghost"
    update_gui(player)
  elseif element.name == "pbb_start" then
    start_recording(player)
  elseif element.name == "pbb_stop" then
    stop_recording(player)
  elseif element.name == "pbb_cancel" then
    cancel_action(player)
  end
end)

-- GUI位置変更イベント
script.on_event(defines.events.on_gui_location_changed, function(event)
  local element = event.element
  if element.name == "pbb_main_window" then
    local player = game.get_player(event.player_index)
    if player then
      storage.players[player.index].gui_position = element.location
    end
  end
end)

-- ベルト配置イベント
script.on_event(defines.events.on_built_entity, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local p_state = storage.players[player.index]
  if p_state and p_state.recording then
    local entity = event.entity
    if entity and entity.valid and entity.type == "transport-belt" then
      if not p_state.belt_type then
        p_state.belt_type = entity.name
        update_gui(player)
      elseif p_state.belt_type ~= entity.name then
        player.print({"message.pbb-different-belt-warning"})
        return
      end
      
      table.insert(p_state.path, {
        x = entity.position.x,
        y = entity.position.y,
        direction = entity.direction
      })
    end
  end
end)
