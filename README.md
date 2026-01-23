📘 OBS Viewport Tracking Scripts

A collection of Lua scripts for OBS Studio that allow you to pan a 16:9 viewport across ultrawide footage using either your mouse or a controller. Each script provides a different control style and behavior.

These scripts are designed for creators who record or stream ultrawide gameplay but want the output to stay in a standard 16:9 frame while dynamically following the action.
🛠️ Installation Guide (All Scripts)

Follow these steps for any of the scripts in this pack:
1. Save the Script

Save the .lua file anywhere on your system (e.g., Documents/OBS Scripts/).
2. Load the Script in OBS

    Open OBS Studio

    Go to Tools → Scripts

    Click the + button

    Select the .lua file you saved

3. Add the Required Crop Filter

Each script requires a Crop/Pad filter named exactly:
Code

Viewport_Crop

To add it:

    Right‑click your ultrawide source

    Choose Filters

    Add Crop/Pad

    Rename it to Viewport_Crop (case‑sensitive)

4. Configure Script Settings

Inside Tools → Scripts, select the script and configure:

    Your ultrawide source

    Your monitor dimensions

    Your output (viewport) dimensions

    Sensitivity / smoothing / deadzones

    Enable tracking

5. Done

Once enabled, the viewport will begin tracking based on the script’s control method.
📂 Script Overview

Below is a breakdown of each script and what it’s designed for.
🎯 1. mouse_viewport_trackerspringy.lua
Purpose:

A smooth, spring‑like mouse‑controlled viewport tracker.
The viewport follows your mouse position horizontally and automatically returns to center when your mouse is near the middle of the screen.
Best For:

    Fast, fluid camera panning

    Hands‑free control while gaming

    Natural “follow the action” behavior

Key Features:

    Auto‑center deadzone

    Adjustable smoothing

    Adjustable sensitivity

    Works at ~60 FPS

    Windows‑only (uses GetCursorPos)

🎮 2. controller_viewport_tracker springy.lua
Purpose:

A controller‑based viewport tracker with spring‑return behavior.
When you let go of the right stick, the viewport smoothly returns to center.
Best For:

    Gamepad‑controlled camera movement

    Cinematic panning

    Streamers who want analog control

Key Features:

    Uses XInput (Xbox controllers or compatible)

    Deadzone handling for worn sticks

    Smooth return‑to‑center

    Adjustable sensitivity and smoothing

    Windows‑only

🎮 3. controller_viewport_tracker.lua
Purpose:

A simpler controller‑based viewport tracker with direct control.
The viewport moves proportionally to the right stick and does not auto‑center unless the stick is centered.
Best For:

    Manual camera control

    Users who want predictable, linear movement

    Situations where auto‑centering is not desired

Key Features:

    XInput support

    Deadzone filtering

    Adjustable sensitivity

    Smooth interpolation

    Windows‑only

🖱️ 4. ultrawide_tracker.lua
Purpose:

A lightweight mouse‑based tracker with edge margins instead of a center deadzone.
The viewport moves only when your mouse enters the left or right “active zones.”
Best For:

    Users who want less jittery movement

    Slower, more deliberate panning

    Ultrawide → 16:9 conversion with minimal motion

Key Features:

    Edge‑margin based control

    Smooth interpolation

    Simple, predictable behavior

    Windows‑only

⚙️ Recommended Settings
Smoothing

    Lower = snappier

    Higher = cinematic

Sensitivity

    Lower = subtle movement

    Higher = wide panning

Deadzone / Edge Margin

    Prevents jitter

    Helps recenters or stabilizes viewport

🧩 Compatibility
Script	Control Method	Auto‑Center	OS	Notes
mouse_viewport_trackerspringy	Mouse	Yes	Windows	Smoothest mouse version
controller_viewport_tracker springy	Controller	Yes	Windows	Best for analog control
controller_viewport_tracker	Controller	No	Windows	Direct stick → viewport
ultrawide_tracker	Mouse	No	Windows	Edge‑based movement
