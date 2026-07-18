# Parallel Belt Builder

A Factorio 2.0 mod that allows you to easily place multiple parallel transport belts by simply building a single reference belt path.

## Features

* **Parallel Placement (2 to 16 Belts)**: Adjust the total number of parallel belts you want to build, ranging from 2 up to 16.
* **Automatic Belt Detection**: Automatically detects the type of transport belt you placed first (Yellow, Red, Blue, or custom belts from other mods) and replicates it across all parallel lines.
* **Flexible Offsetting**: Choose to build parallel lines on either the **Left** or **Right** side relative to the reference belt's movement direction.
* **Placement Modes**:
  * **Normal**: Places physical belts using items from your inventory. If you run out of items mid-build, the mod automatically places the remaining belts as **ghosts (blueprints)**, prioritizing placement from inner-to-outer and start-to-end.
  * **Ghost**: Places entity ghosts for all parallel lines without consuming any items.
* **90-Degree Corners & Complex Paths**: Handles 직각 (90-degree) corners and multi-segment layouts. It automatically calculates intersection coordinates to trim/extend inner and outer curves for seamless connections.
* **Obstacle Skipping**: Automatically skips placements on water or colliding structures, only placing belts on valid buildable ground.
* **Robust Validation**: Detects and warns you about invalid layouts (branches, merges, disconnected lines, loops, 180-degree U-turns, or path collapse due to extremely tight inner corners) and prevents faulty placements.
* **On-the-fly Corrections**: If you make a mistake while building, simply deconstruct/remove the incorrect belts before stopping the recording. The mod will automatically skip the deleted coordinates as long as the remaining layout forms a valid continuous path.
* **Hotkeys & Esc Integration**: Toggle the GUI at any time using **`Ctrl + Alt + Q`** (rebindable under Controls > Mod controls). Pressing the **`Esc`** key while recording safely cancels the operation and closes the window.

## How to Use

1. Open the settings GUI by clicking the **Parallel Belt Builder** shortcut icon or pressing **`Ctrl + Alt + Q`**.
2. Configure **Count** (2-16), **Side** (Left/Right), and **Placement** (Normal/Ghost) before starting.
3. Click the **`Start`** button to begin recording.
4. Place your reference transport belts in the world (either manually or by dragging).
5. Click the **`Stop`** button. The parallel belts/ghosts will be generated instantly.
6. If you want to abort the current recording without placing anything, click the **`Cancel`** button or press the **`Esc`** key.
