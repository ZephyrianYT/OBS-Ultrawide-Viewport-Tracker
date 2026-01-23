1 ================================================================================
OBS ULTRAWIDE VIEWPORT TRACKER
================================================================================
Dynamically pans a 16:9 viewport across an ultrawide source following your mouse.

INSTALLATION:
1. Save this file as "ultrawide_tracker.lua"
2. In OBS: Tools → Scripts → + (Plus) → Select this file
3. Add your ultrawide source to OBS (e.g., Game Capture, Display Capture)
4. Add a filter to that source: Right-click source → Filters → + → Crop/Pad
5. Name the filter EXACTLY: "Viewport_Crop" (case-sensitive)
6. In Scripts panel, configure:
   - Select your ultrawide source
   - Set dimensions (default: 3440×1440 → 1920×1080)
   - Enable "Enable Tracking"
7. Done! Viewport follows your mouse automatically.

NOTES:
- Mouse tracking works on Windows (uses GetCursorPos)
- For Mac/Linux, you'll need alternative mouse tracking
- Adjust "Smoothing" for responsiveness (lower = faster)
- "Edge Margin" creates dead zones at screen edges
- Runs at ~60 FPS for smooth tracking

PROJECTION TO VIRTUAL DISPLAY:
- Right-click your source → Windowed Projector (Source)
- Use virtual display software (OBS VirtualCam, etc.) to capture projector
================================================================================
2================================================================================
OBS CONTROLLER VIEWPORT TRACKER
================================================================================
Pan a 16:9 viewport across ultrawide footage using your controller's right stick

QUICK START:
1. Save as .lua file
2. OBS → Tools → Scripts → + → Select file
3. Add Crop/Pad filter to your source, name it: Viewport_Crop
4. In script settings: pick source, pick controller, enable tracking
5. Move right stick to pan viewport left/right

WHAT TO CHANGE:
• Smoothing (0.05-0.30): Lower = snappier, Higher = smoother
• Sensitivity (0.5-5.0): Lower = slower pan, Higher = faster pan  
• Deadzone (0.05-0.25): Higher = ignore small stick movements
• Dimensions: Match your monitor size and output resolution

REQUIREMENTS:
- Windows only
- XInput controller (Xbox or compatible)
- OBS Studio with Lua scripting support
================================================================================
3================================================================================
OBS CONTROLLER VIEWPORT TRACKER
================================================================================
Pan a 16:9 viewport across ultrawide footage using your controller's right stick

QUICK START:
1. Save as .lua file
2. OBS → Tools → Scripts → + → Select file
3. Add Crop/Pad filter to your source, name it: Viewport_Crop
4. In script settings: pick source, pick controller, enable tracking
5. Move right stick left/right to pan, release stick to return to center

WHAT TO CHANGE:
• Smoothing (0.05-0.30): Lower = snappier, Higher = smoother
• Sensitivity (0.5-5.0): Lower = slower pan, Higher = faster pan  
• Deadzone (0.05-0.25): Higher = ignore small stick movements
• Dimensions: Match your monitor size and output resolution

REQUIREMENTS:
- Windows only
- XInput controller (Xbox or compatible)
- OBS Studio with Lua scripting support
================================================================================
4================================================================================
OBS MOUSE VIEWPORT TRACKER (AUTO-CENTER)
================================================================================
Pan a 16:9 viewport across ultrawide footage using mouse position.
Viewport returns to center when mouse is in the center zone.

QUICK START:
1. Save as .lua file
2. OBS → Tools → Scripts → + → Select file
3. Add Crop/Pad filter to your source, name it: Viewport_Crop
4. In script settings: pick source, enable tracking
5. Move mouse left/right to pan, center mouse to return to center

WHAT TO CHANGE:
• Smoothing (0.05-0.30): Lower = snappier, Higher = smoother
• Sensitivity (0.5-3.0): Lower = less pan range, Higher = more pan range
• Center Deadzone (0.1-0.4): Size of center zone that triggers return to center
• Dimensions: Match your monitor size and output resolution

REQUIREMENTS:
- Windows only
- OBS Studio with Lua scripting support
================================================================================
]]

obs = obslua
local ffi = require("ffi")

-- ============================================================================
-- WINDOWS API DECLARATIONS (Don't modify unless you know what you're doing)
-- ============================================================================
