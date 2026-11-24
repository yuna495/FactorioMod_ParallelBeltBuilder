-- Injected into a disposable copy by run-factorio.ps1; never loaded by the mod.
local constants = require("scripts.constants")
local state = require("scripts.state")
local catalog = require("scripts.belt_catalog")
local planner = require("scripts.planner")
local place = require("scripts.place")
local preview = require("scripts.preview")


return function()
  -- Headless maps have no connected player. Use an inventory adapter with real
  -- engine surfaces/prototypes; GUI, input gestures and Undo need a live player.
  local inventory = {}
  local player = {
    force = game.forces.player,
    controller_type = defines.controllers.god,
    cheat_mode = false,
    get_item_count = function(name) return inventory[name] or 0 end,
    remove_item = function(stack) inventory[stack.name] = (inventory[stack.name] or 0) - stack.count end,
    insert = function(stack) inventory[stack.name] = (inventory[stack.name] or 0) + stack.count end
  }
  local surface = game.create_surface("pbb-test", {width = 256, height = 256})
  surface.request_to_generate_chunks({0, 0}, 4)
  surface.force_generate_chunk_requests()
  for _, entity in pairs(surface.find_entities()) do entity.destroy() end
  local tiles = {}
  for x = -100, 100 do
    for y = -100, 100 do
      tiles[#tiles + 1] = {name = "landfill", position = {x, y}}
    end
  end
  surface.set_tiles(tiles)
  player.surface = surface

  local p = state.get(1)
  local checks = 0
  local function check(value, message)
    assert(value, message)
    checks = checks + 1
  end
  local function path(count, side, y, bend)
    state.clear_plan(p)
    p.selected_belt_name = "transport-belt"
    p.count, p.side = count, side
    p.current_start = {x = -60.5, y = y + 0.5}
    p.current_end = {x = -20.5, y = y + 0.5 + (bend and 40 or 0)}
    p.current_bend = bend or constants.BEND_HORIZONTAL
    local plan, err = planner.build(player, p)
    check(plan ~= nil, err or "missing plan")
    return plan
  end

  local belts = catalog.list_belts()
  check(#belts >= 3, "vanilla belt discovery")
  for i, belt in ipairs(belts) do
    local info = catalog.get_belt_info(belt.name)
    check(info.item_name and info.underground_name and info.max_underground_distance,
      "belt/underground mapping: " .. belt.name)
    if i > 1 then check(belts[i - 1].speed <= belt.speed, "speed order") end
  end
  for _, count in ipairs{1, 2, 16} do
    for _, side in ipairs{"left", "right"} do
      for _, bend in ipairs{false, constants.BEND_HORIZONTAL, constants.BEND_VERTICAL} do
        local plan = path(count, side, -60, bend)
        check(#plan.lanes == count, "lane count")
        p.preview_objects = {rendering.draw_line{color = {1, 1, 1}, width = 4, from = plan.line_lanes[1][1].from, to = plan.line_lanes[1][1].to, surface = surface}}
        check(#p.preview_objects > 0, "render objects")
        preview.clear(p)
        check(#p.preview_objects == 0, "render cleanup")
      end
    end
  end
  local plan = path(1, "right", 0)
  player.cheat_mode = true

  local result = place.commit(player, plan, "normal")
  check(result.entities == 41 and result.ghosts == 0, "physical placement")

  result = place.commit(player, path(1, "right", 0), "normal")
  check(result.existing == 41 and result.entities == 0, "existing belt reuse")


  player.cheat_mode = false
  player.insert{name = "transport-belt", count = 3}
  result = place.commit(player, path(1, "right", 10), "normal")
  check(result.entities == 3 and result.ghosts == 38, "inventory shortage ghosts")
  check(player.get_item_count("transport-belt") == 0, "item consumption")
  result = place.commit(player, path(1, "right", 10), "ghost")
  check(result.existing == 41 and result.ghosts == 0, "existing ghost reuse")

  for _, mode in ipairs{"normal", "ghost"} do
    local y = mode == "normal" and 20 or 30
    local obstacle = surface.create_entity{name = "stone-wall", position = {-40.5, y + 0.5}, force = player.force}
    plan = path(2, "right", y)
    local underground = 0
    for _, entry in ipairs(plan.entries) do
      if entry.prototype == "underground-belt" then underground = underground + 1 end
    end
    check(underground == 2, "per-lane underground planning")
    player.cheat_mode = true
    result = place.commit(player, plan, mode)
    check(result.blocked == 0 and obstacle.valid, "obstacle preserved")
    if mode == "normal" then
      local ends = surface.find_entities_filtered{type = "underground-belt"}
      check(#ends == 2 and ends[1].underground_belt_neighbour ~= nil, "connected underground pair")
    else
      check(result.ghosts > 0, "underground ghost placement")
    end
  end

  -- No underground prototype: blocked locations must remain unplaced.
  surface.create_entity{name = "stone-wall", position = {-40.5, 40.5}, force = player.force}
  local original = catalog.get_belt_info
  catalog.get_belt_info = function(name)
    local info = original(name)
    info.underground_name, info.max_underground_distance = nil, nil
    return info
  end
  plan = path(1, "right", 40)
  catalog.get_belt_info = original
  result = place.commit(player, plan, "ghost")
  check(result.blocked > 0, "blocked skip")

  -- Player settings and serializable preview objects survive a save/reload.
  p.count, p.side, p.placement = 7, "left", "normal"
  p.current_start, p.current_end = {x = 10.5, y = 60.5}, {x = 50.5, y = 60.5}
  p.plan = assert(planner.build(player, p))
  p.preview_objects = {rendering.draw_line{color = {1, 1, 1}, width = 4, from = p.current_start, to = p.current_end, surface = surface}}

  check(state.get(2) ~= p and state.get(2).count == 1, "per-player isolation")
  storage.pbb_test_player = 1
  log("PBB INTEGRATION PASS: " .. checks .. " assertions")
end
