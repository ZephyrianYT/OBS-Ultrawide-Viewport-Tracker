--[[
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
================================================================================
]]

obs = obslua

-- FFI for mouse tracking (Windows)
local ffi = require("ffi")
ffi.cdef[[
    typedef struct { long x; long y; } POINT;
    int GetCursorPos(POINT* lpPoint);
    int GetSystemMetrics(int nIndex);
]]

-- Configuration
local source_name = ""
local ultrawide_width = 3440
local ultrawide_height = 1440
local viewport_width = 1920
local viewport_height = 1080
local smoothing = 0.15
local edge_margin = 200
local enabled = false
local use_percentage_mode = true

-- State
local current_offset = 0
local target_offset = 0
local screen_width = 1920

-- Get actual screen width (Windows)
function get_screen_width()
    local SM_CXSCREEN = 0
    return ffi.C.GetSystemMetrics(SM_CXSCREEN)
end

-- Get mouse position (Windows)
function get_mouse_position()
    local point = ffi.new("POINT")
    local result = ffi.C.GetCursorPos(point)
    
    if result ~= 0 then
        return point.x
    end
    
    -- Fallback if GetCursorPos fails
    return screen_width / 2
end

-- Calculate target offset based on mouse position
function calculate_target_offset(mouse_x)
    local max_offset = ultrawide_width - viewport_width
    
    -- Clamp to valid range
    if max_offset <= 0 then
        return 0
    end
    
    -- Create dead zones at edges
    local effective_width = screen_width - (edge_margin * 2)
    local mouse_relative = mouse_x - edge_margin
    
    -- Clamp to edges
    if mouse_relative <= 0 then
        return 0
    elseif mouse_relative >= effective_width then
        return max_offset
    end
    
    -- Map mouse position to offset (linear interpolation)
    local ratio = mouse_relative / effective_width
    return ratio * max_offset
end

-- Smooth interpolation (exponential ease)
function lerp(a, b, t)
    return a + (b - a) * t
end

-- Apply crop to source
function apply_crop(offset)
    local source = obs.obs_get_source_by_name(source_name)
    if source == nil then 
        return false
    end
    
    -- Get the crop filter
    local crop_filter = obs.obs_source_get_filter_by_name(source, "Viewport_Crop")
    if crop_filter == nil then
        obs.obs_source_release(source)
        return false
    end
    
    -- Calculate crop values
    local left_crop = math.floor(offset)
    local right_crop = math.floor(ultrawide_width - offset - viewport_width)
    local top_crop = math.floor((ultrawide_height - viewport_height) / 2)
    local bottom_crop = math.floor((ultrawide_height - viewport_height) / 2)
    
    -- Ensure non-negative values
    left_crop = math.max(0, left_crop)
    right_crop = math.max(0, right_crop)
    top_crop = math.max(0, top_crop)
    bottom_crop = math.max(0, bottom_crop)
    
    -- Apply settings
    local settings = obs.obs_source_get_settings(crop_filter)
    obs.obs_data_set_int(settings, "left", left_crop)
    obs.obs_data_set_int(settings, "right", right_crop)
    obs.obs_data_set_int(settings, "top", top_crop)
    obs.obs_data_set_int(settings, "bottom", bottom_crop)
    
    obs.obs_source_update(crop_filter, settings)
    
    -- Cleanup
    obs.obs_data_release(settings)
    obs.obs_source_release(crop_filter)
    obs.obs_source_release(source)
    
    return true
end

-- Main update loop
function update_viewport()
    if not enabled then 
        return 
    end
    
    if source_name == "" then
        return
    end
    
    -- Get current mouse position
    local mouse_x = get_mouse_position()
    
    -- Calculate target offset
    target_offset = calculate_target_offset(mouse_x)
    
    -- Smooth the movement
    current_offset = lerp(current_offset, target_offset, smoothing)
    
    -- Apply crop filter
    apply_crop(current_offset)
end

-- Timer callback (called every frame)
function timer_callback()
    update_viewport()
end

-- Script properties UI
function script_properties()
    local props = obs.obs_properties_create()
    
    -- Source selection
    local p = obs.obs_properties_add_list(props, "source", "Ultrawide Source", 
                                          obs.OBS_COMBO_TYPE_EDITABLE, 
                                          obs.OBS_COMBO_FORMAT_STRING)
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(p, name, name)
        end
    end
    obs.source_list_release(sources)
    
    -- Dimensions
    obs.obs_properties_add_int(props, "ultrawide_width", "Ultrawide Width (px)", 1920, 7680, 1)
    obs.obs_properties_add_int(props, "ultrawide_height", "Ultrawide Height (px)", 1080, 4320, 1)
    obs.obs_properties_add_int(props, "viewport_width", "Viewport Width (px)", 1280, 3840, 1)
    obs.obs_properties_add_int(props, "viewport_height", "Viewport Height (px)", 720, 2160, 1)
    
    -- Behavior
    obs.obs_properties_add_float_slider(props, "smoothing", "Smoothing (lower = faster)", 0.01, 0.5, 0.01)
    obs.obs_properties_add_int(props, "edge_margin", "Edge Margin (px)", 0, 500, 10)
    
    -- Enable/Disable
    obs.obs_properties_add_bool(props, "enabled", "Enable Tracking")
    
    -- Info text
    obs.obs_properties_add_text(props, "info", "ℹ️ Filter must be named 'Viewport_Crop'", obs.OBS_TEXT_INFO)
    
    return props
end

-- Default values
function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "ultrawide_width", 3440)
    obs.obs_data_set_default_int(settings, "ultrawide_height", 1440)
    obs.obs_data_set_default_int(settings, "viewport_width", 1920)
    obs.obs_data_set_default_int(settings, "viewport_height", 1080)
    obs.obs_data_set_default_double(settings, "smoothing", 0.15)
    obs.obs_data_set_default_int(settings, "edge_margin", 200)
    obs.obs_data_set_default_bool(settings, "enabled", false)
end

-- Update settings
function script_update(settings)
    source_name = obs.obs_data_get_string(settings, "source")
    ultrawide_width = obs.obs_data_get_int(settings, "ultrawide_width")
    ultrawide_height = obs.obs_data_get_int(settings, "ultrawide_height")
    viewport_width = obs.obs_data_get_int(settings, "viewport_width")
    viewport_height = obs.obs_data_get_int(settings, "viewport_height")
    smoothing = obs.obs_data_get_double(settings, "smoothing")
    edge_margin = obs.obs_data_get_int(settings, "edge_margin")
    
    local new_enabled = obs.obs_data_get_bool(settings, "enabled")
    
    -- Reset offset when enabling
    if new_enabled and not enabled then
        current_offset = 0
        target_offset = 0
    end
    
    enabled = new_enabled
end

-- Script description
function script_description()
    return [[<center><h2>🎮 Ultrawide Viewport Tracker</h2></center>
<p>Automatically pans a 16:9 viewport across your ultrawide source, following your mouse cursor.</p>

<h3>✅ Quick Setup:</h3>
<ol>
<li>Add ultrawide source to OBS</li>
<li>Add <b>Crop/Pad</b> filter to source</li>
<li>Rename filter to: <code>Viewport_Crop</code></li>
<li>Select source in dropdown above</li>
<li>Enable tracking</li>
</ol>

<h3>⚙️ Tips:</h3>
<ul>
<li><b>Smoothing:</b> Lower values = faster response (0.05-0.20 recommended)</li>
<li><b>Edge Margin:</b> Creates "safe zones" at screen edges (100-300px recommended)</li>
<li><b>Performance:</b> Runs at 60 FPS - minimal CPU impact</li>
</ul>

<p><i>Windows only - requires FFI support</i></p>]]
end

-- Initialize script
function script_load(settings)
    -- Get actual screen width
    screen_width = get_screen_width()
    
    -- Start update timer (~60 FPS)
    obs.timer_add(timer_callback, 16)
    
    print("Ultrawide Viewport Tracker loaded - Screen width: " .. screen_width)
end

-- Cleanup
function script_unload()
    obs.timer_remove(timer_callback)
    print("Ultrawide Viewport Tracker unloaded")
end