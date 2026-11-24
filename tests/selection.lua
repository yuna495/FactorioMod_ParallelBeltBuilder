-- Run with `lua tests/selection.lua` from the mod root.
-- Exercise the actual control handlers with a player/rendering adapter.
local handlers = {}
local next_event = 0
defines = {events = setmetatable({}, {__index = function(t, k)
  next_event = next_event + 1
  rawset(t, k, next_event)
  return next_event
end}), direction = {north = 0, east = 4, south = 8, west = 12}}
script = {
  on_event = function(ids, fn)
    if type(ids) ~= "table" then ids = {ids} end
    for _, id in ipairs(ids) do handlers[id] = fn end
  end,
  on_init = function() end, on_configuration_changed = function() end
}
storage = {}
local constants = require("scripts.constants")
local state = require("scripts.state")
local surface = {}
local player = {index = 1, surface = surface, gui = {screen = {}},
  cursor_stack = {valid = true, valid_for_read = true, name = constants.PREVIEW_TOOL},
  print = function() end, set_shortcut_toggled = function() end}
player.clear_cursor = function() player.cursor_stack.valid_for_read = false; return true end
player.cursor_stack.set_stack = function(stack)
  player.cursor_stack.name, player.cursor_stack.valid_for_read = stack.name, true
end
game = {get_player = function(index) return index == 1 and player or nil end}
prototypes = {item = {[constants.PREVIEW_TOOL] = {}}}
package.loaded["scripts.belt_catalog"] = {}
local builds, commits, draws = 0, 0, 0
local committed
package.loaded["scripts.planner"] = {build = function(_, p)
  builds = builds + 1
  return {from = p.current_start, to = p.current_end, segments = p.segments}
end}
package.loaded["scripts.preview"] = {
  clear = function(p) p.preview_objects = {} end,
  draw = function(_, p, plan)
    draws = draws + 1
    p.preview_objects = plan and {{valid = true}} or {}
  end
}
package.loaded["scripts.place"] = {commit = function(_, plan)
  commits, committed = commits + 1, plan
  return {entities = 0, ghosts = 1, existing = 0, blocked = 0}
end}
package.loaded["scripts.gui"] = {update = function() end}
require("control")
local checks = 0
local function check(ok, message) assert(ok, message); checks = checks + 1 end
local function ready()
  local p = state.get(1)
  state.clear_plan(p)
  p.mode = constants.MODE_DRAWING
  player.cursor_stack.valid_for_read = true
  player.cursor_stack.name = constants.PREVIEW_TOOL
  return p
end
local function event(kind, sx, sy, x, y, item, event_surface)
  handlers[defines.events[kind]]{
    player_index = 1, item = item or constants.PREVIEW_TOOL,
    surface = event_surface or surface,
    position = {x = sx, y = sy}, cursor_position = {x = x, y = y}
  }
end
check(handlers[defines.events.on_pre_build] == nil, "must not depend on build events")
for _, target in ipairs{{8.2, 7.2}, {-8.2, 7.2}, {8.2, -7.2}, {-8.2, -7.2}} do
  local p = ready()
  local before = commits
  event("on_player_start_selected_area", 0.2, 0.2, 0.2, 0.2)
  event("on_player_change_selected_area", 0.2, 0.2, target[1], target[2])
  check(p.plan and #p.preview_objects > 0, "preview before releasing drag")
  check(commits == before, "no placement during drag")
  check(player.cursor_stack.name == constants.PREVIEW_TOOL, "stable tool during drag")
  local old_builds = builds
  event("on_player_change_selected_area", 0.2, 0.2, target[1], target[2])
  check(builds == old_builds, "same-tile updates are skipped")
  event("on_player_selected_area", 0.2, 0.2, target[1] * 2, target[2] * 2)
  check(commits == before + 1 and committed.from.x == 0.5, "release commits from real start")
  check(committed.to.x == math.floor(target[1] * 2) + 0.5, "final x overrides preview")
  check(committed.to.y == math.floor(target[2] * 2) + 0.5, "final y overrides preview")
  check(#p.preview_objects == 0 and p.drag_start == nil, "release clears preview")
end
local p = ready()
event("on_player_change_selected_area", 10, 10, -5, -5)
check(p.current_start.x == 10.5 and p.plan, "missing start event recovered")
handlers["pbb-flip-bend"]{player_index = 1}
check(p.current_bend == constants.BEND_VERTICAL, "bend control")
handlers["pbb-anchor"]{player_index = 1}
event("on_player_change_selected_area", 10, 10, -5, -15)
check(#p.segments == 1 and p.current_start.x == -4.5, "anchor retained during drag")
event("on_player_change_selected_area", 20, 20, 30, 30)
check(#p.segments == 0 and p.current_start.x == 20.5, "new drag discards stale plan")
local before = commits
event("on_player_cancel_selected_area", 10, 10, -5, -15)
check(p.plan ~= nil, "stale cancel ignored")
event("on_player_cancel_selected_area", 20, 20, 30, 30)
check(p.plan == nil and #p.preview_objects == 0 and commits == before, "cancel never commits")
p = ready()
event("on_player_selected_area", 20, 20, -20, -20)
check(commits == before + 1 and committed.from.x == 20.5 and committed.to.x == -19.5,
  "release without any preselection event preserves direction")
p = ready()
event("on_player_change_selected_area", 0, 0, 5, 5, "unrelated-tool")
check(p.plan == nil, "unrelated tools ignored")
event("on_player_change_selected_area", 0, 0, 5, 5, nil, {})
check(p.plan == nil, "other surfaces ignored")
event("on_player_change_selected_area", 0, 0, 5, 5)
handlers["pbb-cancel"]{player_index = 1}
before = commits
event("on_player_selected_area", 0, 0, 5, 5)
check(p.plan == nil and commits == before, "late release after clear-cursor ignored")
check(draws > 0, "render handler exercised")
print("PBB SELECTION PASS: " .. checks .. " assertions")
