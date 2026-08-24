# Parallel Belt Builder

Parallel Belt Builder is a Factorio 2.0 mod for drawing virtual transport-belt paths and placing the planned belts in one action.

It is no longer a tool that copies an already-built reference belt. Version 2.0 turns PBB into a general belt drawing tool: draw a path, optionally expand it into parallel lanes, preview underground sections and blocked positions, then release the drag to place the plan.

## Features

* Draw 1 to 16 transport-belt lanes from the same virtual path.
* Count starts at 1 whenever PBB is opened, making it useful as a single-belt drawing tool.
* Expand multiple lanes to the left or right of the drawn path.
* Draw L-shaped paths and switch the current bend mode with the configured control.
* Add anchors while drawing to create multi-segment paths.
* Select the belt automatically from the belt item in your cursor, or choose from the GUI.
* Discover available transport-belt prototypes dynamically and sort them by belt speed.
* Reuse existing same-type, same-direction belts and equivalent ghosts without consuming items.
* Plan underground belt sections independently for each lane.
* Mark blocked positions when a belt cannot be placed normally and cannot be converted to an underground section.
* Use a lightweight line preview instead of rendering every belt tile.
* Place in Normal mode or Ghost mode.
* Register newly created PBB entities with Factorio's standard Undo queue where possible.

## Controls

* `Ctrl + Alt + Q`: Toggle Parallel Belt Builder.
* `F`: Toggle the current segment's L-bend mode.
* `R`: Anchor the current segment.
* Factorio clear-cursor control: Cancel the current drawing.
* `Draw`: Re-acquire the PBB drawing tool after cancelling.

All mod controls can be changed in Factorio's control settings.

## How To Use

1. Hold a transport belt item if you want PBB to select that belt automatically.
2. Open Parallel Belt Builder with the shortcut button or toggle control.
3. Choose Belt, Count, Side, and Placement mode.
4. Drag with the PBB drawing tool to create a virtual path.
5. Press `F` while drawing to switch the current L-shaped segment between horizontal-first and vertical-first.
6. Press `R` while drawing to anchor the current segment and continue from that point.
7. Check the preview markers for underground entrances, underground exits, and blocked positions.
8. Release the drag to place the full plan.

Count `1` uses the same flow and places a single planned belt lane. Count `2` to `16` expands the same path into parallel lanes.

## Placement Behavior

Normal mode places physical belts when the required item is available. If an individual planned entity cannot be supplied from the player's inventory, PBB places a ghost for that entity instead.

Ghost mode places ghosts for the planned entities.

Existing same-type, same-direction transport belts, and equivalent transport-belt ghosts, are treated as valid existing path parts. PBB does not replace them, consume items for them, or add them to Undo.

Other entities are treated as obstacles. PBB may convert the affected part of each lane into underground belts when a valid underground section can be created. If a position cannot be placed normally and cannot be undergrounded, it is shown as blocked and is left unplaced when the plan is committed.

PBB does not remove obstacles, replace existing entities, landfill terrain, destroy cliffs, or route around obstacles automatically.

## Preview

The normal belt path is shown with lines. For multiple lanes, PBB shows the reference lane and the outermost lane to indicate the occupied width without rendering every belt tile.

Underground entrances, underground exits, blocked positions, the start point, and user-created anchors are shown as markers. Automatic L-bend corners are not shown as anchors.

## Compatibility Notes

PBB targets Factorio 2.0.

Vanilla transport belts are supported. Modded transport belts are discovered dynamically when they behave like normal transport-belt prototypes and have usable placement items. Special belt prototypes with custom rules or unusual constraints are not guaranteed to work.

## License Notes

This mod's drawing workflow was designed with ideas from MIT-licensed belt planning mods such as Belt Draw and Shoter Belt Planner. PBB 2.0 does not require those mods.
