-- control.lua

local function get_default_player_state()
  return {
    recording = false,
    placing = false,
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
      -- キーの欠損対策
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

    -- デフォルト位置を画面左上寄りに設定
    if p_state.gui_position then
      window.location = p_state.gui_position
    else
      window.location = {x = 80, y = 150}
    end

    -- Belt Info
    local flow_belt = window.add{type = "flow", name = "flow_belt", direction = "horizontal"}
    flow_belt.style.vertical_align = "center"
    flow_belt.style.horizontal_spacing = 8
    local lbl_belt = flow_belt.add{type = "label", caption = "Belt: "}
    lbl_belt.style.width = 80
    flow_belt.add{type = "label", name = "belt_label", caption = "Not selected"}

    -- Count Info
    local flow_count = window.add{type = "flow", name = "flow_count", direction = "horizontal"}
    flow_count.style.vertical_align = "center"
    flow_count.style.horizontal_spacing = 8
    local lbl_count = flow_count.add{type = "label", caption = "Count: "}
    lbl_count.style.width = 80
    local btn_minus = flow_count.add{type = "button", name = "pbb_count_minus", caption = "-"}
    btn_minus.style.width = 30
    local lbl_val = flow_count.add{type = "label", name = "count_label", caption = "4"}
    lbl_val.style.width = 25
    lbl_val.style.horizontal_align = "center"
    local btn_plus = flow_count.add{type = "button", name = "pbb_count_plus", caption = "+"}
    btn_plus.style.width = 30

    -- Side Info
    local flow_side = window.add{type = "flow", name = "flow_side", direction = "horizontal"}
    flow_side.style.vertical_align = "center"
    flow_side.style.horizontal_spacing = 8
    local lbl_side = flow_side.add{type = "label", caption = "Side: "}
    lbl_side.style.width = 80
    local btn_left = flow_side.add{type = "button", name = "pbb_side_left", caption = "Left"}
    btn_left.style.width = 60
    local btn_right = flow_side.add{type = "button", name = "pbb_side_right", caption = "Right"}
    btn_right.style.width = 60

    -- Placement Info
    local flow_place = window.add{type = "flow", name = "flow_place", direction = "horizontal"}
    flow_place.style.vertical_align = "center"
    flow_place.style.horizontal_spacing = 8
    local lbl_place = flow_place.add{type = "label", caption = "Placement: "}
    lbl_place.style.width = 80
    local btn_normal = flow_place.add{type = "button", name = "pbb_place_normal", caption = "Normal"}
    btn_normal.style.width = 60
    local btn_ghost = flow_place.add{type = "button", name = "pbb_place_ghost", caption = "Ghost"}
    btn_ghost.style.width = 60

    -- Divider
    local line = window.add{type = "line", direction = "horizontal"}
    line.style.top_margin = 8
    line.style.bottom_margin = 8

    -- Actions
    local flow_actions = window.add{type = "flow", name = "flow_actions", direction = "horizontal"}
    flow_actions.style.vertical_align = "center"
    flow_actions.style.horizontal_spacing = 8
    local btn_start = flow_actions.add{type = "button", name = "pbb_start", caption = "Start"}
    btn_start.style.width = 65
    local btn_stop = flow_actions.add{type = "button", name = "pbb_stop", caption = "Stop"}
    btn_stop.style.width = 65
    local btn_cancel = flow_actions.add{type = "button", name = "pbb_cancel", caption = "Cancel"}
    btn_cancel.style.width = 65

    -- EscキーでGUIを閉じるための紐付け
    player.opened = window
  end
  return window
end

-- ボタンのスタイルとフォント等の揃えを一括適用するヘルパー
local function update_toggle_button(btn, selected, width)
  if selected then
    btn.style = "confirm_button"
  else
    btn.style = "button"
  end
  
  -- スタイル切り替えによるフォント崩れや位置ズレを防ぐためパラメータを明示的に上書き統一する
  btn.style.width = width
  btn.style.font = "default-semibold"
  btn.style.horizontal_align = "center"
  btn.style.vertical_align = "center"
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

  -- Side toggle state & style
  update_toggle_button(window.flow_side.pbb_side_left, p_state.side == "left", 60)
  update_toggle_button(window.flow_side.pbb_side_right, p_state.side == "right", 60)

  -- Placement toggle state & style
  update_toggle_button(window.flow_place.pbb_place_normal, p_state.placement == "normal", 60)
  update_toggle_button(window.flow_place.pbb_place_ghost, p_state.placement == "ghost", 60)

  local is_recording = p_state.recording
  local is_placing = p_state.placing
  local is_idle = not is_recording and not is_placing

  -- 各状態におけるボタン制御
  window.flow_count.pbb_count_minus.enabled = is_idle
  window.flow_count.pbb_count_plus.enabled = is_idle
  window.flow_side.pbb_side_left.enabled = is_idle
  window.flow_side.pbb_side_right.enabled = is_idle
  window.flow_place.pbb_place_normal.enabled = is_idle
  window.flow_place.pbb_place_ghost.enabled = is_idle

  window.flow_actions.pbb_start.enabled = is_idle
  window.flow_actions.pbb_stop.enabled = is_recording and not is_placing
  window.flow_actions.pbb_cancel.enabled = is_recording and not is_placing
end

-- 向きに対応する単位ベクトルを取得 (Y軸は下が正)
local function get_dir_vector(dir)
  if dir == defines.direction.north then return 0, -1
  elseif dir == defines.direction.east then return 1, 0
  elseif dir == defines.direction.south then return 0, 1
  elseif dir == defines.direction.west then return -1, 0
  end
  return 0, 0
end

-- 展開方向に応じたオフセットベクトルを取得
local function get_offset_vector(direction, side)
  local factor = (side == "left") and -1 or 1
  if direction == defines.direction.north then return factor, 0
  elseif direction == defines.direction.east then return 0, factor
  elseif direction == defines.direction.south then return -factor, 0
  elseif direction == defines.direction.west then return 0, -factor
  end
  return 0, 0
end

-- 基準経路の構造解析と順序ソート
local function analyze_path(player, path, expected_belt_type)
  if #path == 0 then return nil, "message.pbb-no-belts-placed" end

  local surface = player.surface
  local seen = {}
  local unique_nodes = {}

  for _, item in ipairs(path) do
    -- 浮動小数の誤差を排除するためタイルインデックス（整数）で管理
    local tx = math.floor(item.x)
    local ty = math.floor(item.y)
    local key = string.format("%d,%d", tx, ty)

    if not seen[key] then
      -- 配置された位置のベルトをサーフェスから直接検索し、最新の向きと種類を取得する
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

      -- 撤去されたベルトはエラーにせず、単に解析対象から除外（無視）する
      if actual_name then
        -- ただし、別種類のベルトに置き換わっている場合はエラーとする
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

  -- もし実在するベルトが0個になってしまった場合
  if #unique_nodes == 0 then
    return nil, "message.pbb-no-belts-placed"
  end

  -- 隣接接続関係を構築
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

  -- 分岐・合流・始点・終点の検証
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

  -- 始点から終点まで順序ソート
  local start_node = starts[1]
  local sorted_path = {}
  local current = start_node
  local visited = {}

  while current do
    if visited[current.key] then
      return nil, "message.pbb-invalid-path-structure" -- ループ検知
    end
    visited[current.key] = true
    table.insert(sorted_path, current)

    if #current.outgoing > 0 then
      current = seen[current.outgoing[1]]
    else
      current = nil
    end
  end

  -- 孤立した非連続経路がないか検証
  if #sorted_path ~= #unique_nodes then
    return nil, "message.pbb-invalid-path-structure"
  end

  return sorted_path
end

-- 連続する同方向のベルトを直線区間にグループ化
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
      -- 90度以外の転換 (180度Uターンなど) はエラーとする
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

-- 並列経路のタイル座標・方向の生成
local function generate_parallel_path(segments, col, side)
  local N = #segments
  if N == 0 then return {} end

  -- 1. 各区間のオフセット基準値を設定
  for _, seg in ipairs(segments) do
    local ox, oy = get_offset_vector(seg.direction, side)
    if seg.is_vertical then
      seg.offset_coord = seg.base_coord + ox * col
    else
      seg.offset_coord = seg.base_coord + oy * col
    end
  end

  -- 2. 頂点座標の算出
  local vertices = {}

  -- 始点頂点
  local ox1, oy1 = get_offset_vector(segments[1].direction, side)
  local start_node = segments[1].nodes[1]
  table.insert(vertices, {x = start_node.x + ox1 * col, y = start_node.y + oy1 * col})

  -- 中間交点
  for i = 2, N do
    local prev = segments[i-1]
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

  -- 終点頂点
  local last_seg = segments[N]
  local oxN, oyN = get_offset_vector(last_seg.direction, side)
  local last_node = last_seg.nodes[#last_seg.nodes]
  table.insert(vertices, {x = last_node.x + oxN * col, y = last_node.y + oyN * col})

  -- 3. 各直線区間を結ぶタイルの生成と逆行検証
  local parallel_tiles = {}
  for i = 1, N do
    local A = vertices[i]
    local B = vertices[i+1]
    local dir = segments[i].direction

    local dx = B.x - A.x
    local dy = B.y - A.y
    local step_x, step_y = get_dir_vector(dir)
    local dot = dx * step_x + dy * step_y

    -- 進行方向と逆向き (逆行・内側のきつい曲がりによる潰れ) を検出
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

-- タイル配置可能性・消費対象判定
local function check_tile_state(surface, target_pos, belt_type, direction, force)
  -- 既存ベルトの確認
  local existing_belts = surface.find_entities_filtered{
    position = target_pos,
    radius = 0.45,
    type = "transport-belt"
  }
  if #existing_belts > 0 then
    return "skip_no_consume"
  end

  -- 既存ゴーストの確認
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

  -- 配置可否チェック
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
    p_state.placing = false
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
  p_state.placing = false
  p_state.belt_type = nil
  p_state.path = {}

  player.print({"message.pbb-recording-started"})
  update_gui(player)
end

-- 配置確定処理 (解析、並列生成、配置実行を一括で行う)
local function confirm_placement(player)
  local p_state = storage.players[player.index]
  if not p_state or p_state.placing or #p_state.path == 0 or not p_state.belt_type then
    return false
  end

  p_state.placing = true

  -- 1. 基準経路の解析・接続順ソート
  local sorted_path, err = analyze_path(player, p_state.path, p_state.belt_type)
  if not sorted_path then
    player.print({err})
    p_state.placing = false
    reset_placement_state(player)
    return false
  end

  -- 2. 直線区間へのグループ化
  local segments, err2 = group_into_segments(sorted_path)
  if not segments then
    player.print({err2})
    p_state.placing = false
    reset_placement_state(player)
    return false
  end

  local belt_type = p_state.belt_type
  local count = p_state.count
  local side = p_state.side
  local placement = p_state.placement
  local surface = player.surface

  -- 3. 各並列列のタイル生成
  local all_parallel_tiles = {}
  for col = 1, count - 1 do
    local col_tiles, err3 = generate_parallel_path(segments, col, side)
    if not col_tiles then
      player.print({err3})
      p_state.placing = false
      reset_placement_state(player)
      return false
    end
    for _, tile in ipairs(col_tiles) do
      table.insert(all_parallel_tiles, tile)
    end
  end

  -- 重複タイルの排除
  local seen = {}
  local unique_tiles = {}
  for _, tile in ipairs(all_parallel_tiles) do
    local key = string.format("%.1f,%.1f", tile.x, tile.y)
    if not seen[key] then
      seen[key] = true
      table.insert(unique_tiles, tile)
    end
  end

  -- 4. 配置判定
  local place_positions = {}
  for _, tile in ipairs(unique_tiles) do
    local state = check_tile_state(surface, {x = tile.x, y = tile.y}, belt_type, tile.direction, player.force)
    if state == "place" then
      table.insert(place_positions, tile)
    end
  end

  if #place_positions == 0 then
    player.print({"message.pbb-no-belts-placed"})
    p_state.placing = false
    reset_placement_state(player)
    return true
  end

  -- 5. 配置実行
  local placed_entities = 0
  local placed_ghosts = 0

  if placement == "normal" then
    -- 通常配置モード
    local available_count = player.get_item_count(belt_type)

    for _, tile in ipairs(place_positions) do
      if available_count > 0 then
        -- 手持ちアイテムがある ➜ 実体を配置
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
        -- アイテム切れ ➜ ゴースト配置
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
    -- ゴースト配置モード
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

  -- 結果報告
  if placed_entities > 0 then
    player.print({"message.pbb-entities-placed", placed_entities})
  end
  if placed_ghosts > 0 then
    player.print({"message.pbb-ghosts-placed", placed_ghosts})
  end

  p_state.placing = false
  reset_placement_state(player)
  return true
end

-- 記録停止処理
local function stop_recording(player)
  local p_state = storage.players[player.index]
  if not p_state or not p_state.recording then return end

  p_state.recording = false

  if #p_state.path == 0 then
    player.print({"message.pbb-no-belts-placed"})
    reset_placement_state(player)
    return
  end

  player.print({"message.pbb-recording-stopped"})

  -- 配置処理の実行
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
    get_or_create_gui(player)
    update_gui(player)
    player.set_shortcut_toggled("pbb-toggle-recording", true)
  else
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

-- GUIをEscキーや閉じるボタンで閉じた時のイベント
script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.name == "pbb_main_window" then
    local player = game.get_player(event.player_index)
    if player then
      local p_state = storage.players[player.index]
      if p_state.recording then
        cancel_action(player)
      end
      if event.element.valid then
        event.element.destroy()
      end
      player.set_shortcut_toggled("pbb-toggle-recording", false)
    end
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
        y = entity.position.y
      })
    end
  end
end)
