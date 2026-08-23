# Parallel Belt Builder

A Factorio 2.0 mod for drawing a virtual belt path and placing 1 to 16 planned belt lanes at once.

Parallel Belt Builder is no longer based on recording an already-built reference belt. Instead, it gives you a dedicated drawing tool: draw a virtual path, preview the resulting belt group, then confirm placement.

## Features

* **1 to 16 lanes**: Use it as a single-belt drawing tool or expand the path into a parallel belt group.
* **Virtual path drawing**: The dedicated tool uses a dummy belt while drawing, but the dummy entity is immediately removed and is not left in the world.
* **L-shaped segments**: Diagonal drags are converted into horizontal-first or vertical-first L-shaped belt paths.
* **Anchors**: Press the anchor key to fix the current segment and continue drawing from that point.
* **Automatic belt selection**: If you start PBB while holding an item that places a transport belt, that belt is selected.
* **Mod belt support**: Transport belt prototypes are discovered dynamically instead of using a fixed Yellow/Red/Blue list.
* **Per-lane underground planning**: Each generated lane is checked independently. If a lane cannot place normal belts through an obstacle, PBB attempts an underground-belt section for that lane only.
* **Blocked preview**: Positions that cannot be placed normally and cannot be undergrounded are marked as blocked.
* **Lightweight preview**: Normal path preview uses line rendering only. Underground entrances/exits and blocked positions are shown as markers.
* **Normal and Ghost placement**:
  * Normal places physical belts when the required item is available, and places ghosts for individual entities when items are missing.
  * Ghost places ghosts for the planned entities.

## Controls

* `Ctrl + Alt + Q`: Toggle Parallel Belt Builder.
* `F`: Toggle the current segment's L-bend mode.
* `R`: Anchor the current segment.
* Factorio clear-cursor control: Cancel drawing.
* `Draw`: Re-acquire the PBB drawing tool after cancelling.
* Confirm and Clear are GUI buttons.

All mod controls can be changed in Factorio's control settings.

## How To Use

1. Hold a transport belt item if you want PBB to select that belt automatically.
2. Open Parallel Belt Builder with the shortcut button or `Ctrl + Alt + Q`.
3. Set Belt, Count, Side, and Placement.
4. Drag with the PBB tool to draw a virtual belt path.
5. Press `F` to switch the current L-shaped segment between horizontal-first and vertical-first.
6. Press `R` to anchor the current segment and continue from that point.
7. Check the preview.
8. Click Confirm to place the full plan.

Count `1` uses the same flow and places a single planned belt lane.

Cancel clears the current plan and cursor while leaving the GUI open. Click Draw to resume drawing without closing and reopening PBB. Clear removes the current plan and immediately returns the drawing tool.

## Notes

PBB does not automatically remove or replace existing entities. Existing same-type and same-direction transport belts, or equivalent transport-belt ghosts, are reused without item cost. Other entities are treated as obstacles and may be crossed with underground belts if a valid underground section can be created.

Blocked positions are intentionally left unplaced when confirmed.
