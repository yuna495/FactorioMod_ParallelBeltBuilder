# Parallel Belt Builder

A Factorio 2.0 mod that allows you to easily place multiple parallel transport belts by simply building a single reference belt path.

## Features

* **Parallel Placement (2 to 16 Belts)**: Adjust the total number of parallel belts you want to build, ranging from 2 up to 16.
* **Direct Count Input**: Set the belt count with the `+` / `-` buttons or type a number directly into the count field.
* **Automatic Belt Detection**: Automatically detects the type of transport belt you placed first (Yellow, Red, Blue, or custom belts from other mods) and replicates it across all parallel lines.
* **Flexible Offsetting**: Choose to build parallel lines on either the **Left** or **Right** side relative to the reference belt's movement direction.
* **Placement Modes**:
  * **Normal**: Places physical belts using items from your inventory. If you run out of items mid-build, the mod automatically places the remaining belts as **ghosts (blueprints)**, prioritizing placement from inner-to-outer and start-to-end. In editor mode or cheat mode, Normal placement builds physical belts without checking or consuming inventory items.
  * **Ghost**: Places entity ghosts for all parallel lines without consuming any items.
* **90-Degree Corners & Complex Paths**: Handles right-angle (90-degree) corners and multi-segment layouts. It automatically calculates intersection coordinates to trim/extend inner and outer curves for seamless connections.
* **Obstacle Skipping**: Automatically skips placements on water or colliding structures, only placing belts on valid buildable ground.
* **Robust Validation**: Detects and warns you about invalid layouts (branches, merges, disconnected lines, loops, 180-degree U-turns, or path collapse due to extremely tight inner corners) and prevents faulty placements.
* **On-the-fly Corrections**: If you make a mistake while building the reference path, simply deconstruct/remove the incorrect belts before pressing **`Build`**. The mod will automatically skip the deleted coordinates as long as the remaining layout forms a valid continuous path.
* **Hotkeys & Esc Integration**: Toggle the GUI at any time using **`Ctrl + Alt + Q`** (rebindable under Controls > Mod controls). Closing the GUI discards the current reference path.

## How to Use

1. Open the settings GUI by clicking the **Parallel Belt Builder** shortcut icon or pressing **`Ctrl + Alt + Q`**.
2. Configure **Count** (2-16, using the buttons or direct numeric input), **Side** (Left/Right), and **Placement** (Normal/Ghost).
3. Place your reference transport belts in the world (either manually or by dragging). Recording starts automatically from the first belt placed while the GUI is open.
4. Click the **`Build`** button. The parallel belts/ghosts will be generated instantly, and the GUI stays open for the next path.
5. If you want to discard the current reference path without placing anything, click **`Clear`**.
6. Closing the GUI discards the current reference path.
