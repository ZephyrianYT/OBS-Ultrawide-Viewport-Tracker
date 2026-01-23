# OBS-Ultrawide-Viewport-Tracker
Simple lua script to add to obs, follow lua instructions:
================================================================================
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
===============================================================================
