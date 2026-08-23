local constants = {}

constants.MIN_COUNT = 1
constants.MAX_COUNT = 16

constants.MODE_IDLE = "idle"
constants.MODE_DRAWING = "drawing"
constants.MODE_PLACING = "placing"

constants.DEFAULT_BELT = "transport-belt"
constants.TOOL = "pbb-draw-tool"
constants.PREVIEW_TOOL = "pbb-preview-tool"
constants.DUMMY_ENTITY = "pbb-dummy-entity"
constants.DUMMY_BELT = "pbb-dummy-transport-belt"

constants.BEND_HORIZONTAL = "horizontal-first"
constants.BEND_VERTICAL = "vertical-first"

constants.STATE_NORMAL = "normal"
constants.STATE_EXISTING = "existing"
constants.STATE_BLOCKED = "blocked"
constants.STATE_HIDDEN = "hidden"

constants.KIND_BELT = "belt"
constants.KIND_UNDERGROUND_INPUT = "underground-input"
constants.KIND_UNDERGROUND_OUTPUT = "underground-output"
constants.KIND_UNDERGROUND_HIDDEN = "underground-hidden"

return constants
