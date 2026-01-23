--[[
================================================================================
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
ffi.cdef[[
    typedef struct { long x; long y; } POINT;
    int GetCursorPos(POINT* lpPoint);
    int GetSystemMetrics(int nIndex);
]]

-- ============================================================================
-- SCRIPT CONFIGURATION - User Settings (set via OBS UI)
-- ============================================================================
local source_name = ""              -- Which OBS source to track
local ultrawide_width = 3440        -- Your monitor width (e.g., 3440 for 21:9)
local ultrawide_height = 1440       -- Your monitor height
local viewport_width = 1920         -- Output stream width (usually 1920)
local viewport_height = 1080        -- Output stream height (usually 1080)
local smoothing = 0.15              -- How smooth the movement is (0.01=instant, 0.5=very smooth)
local sensitivity = 1.0             -- How much mouse position affects pan (0.5=less, 2.0=more)
local center_deadzone = 0.2         -- Size of center zone (0.0=none, 0.5=half screen)
local enabled = false               -- Is tracking active?

-- ============================================================================
-- INTERNAL STATE - Don't modify these
-- ============================================================================
local current_offset = 0            -- Current viewport position (pixels from left)
local target_offset = 0             -- Where viewport wants to be
local screen_width = 1920           -- Detected screen width

-- ============================================================================
-- MOUSE TRACKING - Get cursor position
-- ============================================================================
function get_screen_width()
    local SM_CXSCREEN = 0
    return ffi.C.GetSystemMetrics(SM_CXSCREEN)
end

function get_mouse_position()
    local point = ffi.new("POINT")
    local result = ffi.C.GetCursorPos(point)
    
    if result ~= 0 then
        return point.x
    end
    
    -- Fallback if GetCursorPos fails
    return screen_width / 2
end

-- ============================================================================
-- VIEWPORT POSITIONING - Calculate where viewport should be
-- ============================================================================
function calculate_target_from_mouse(mouse_x)
    local max_offset = ultrawide_width - viewport_width
    
    if max_offset <= 0 then
        return max_offset / 2  -- Center if viewport >= source
    end
    
    -- Calculate center position
    local center_pos = screen_width / 2
    local center_offset = max_offset / 2
    
    -- Calculate distance from center as percentage
    local distance_from_center = (mouse_x - center_pos) / (screen_width / 2)
    
    -- If mouse is in center deadzone, return to center
    if math.abs(distance_from_center) < center_deadzone then
        return center_offset
    end
    
    -- Map mouse position to viewport offset
    -- Remove deadzone from calculation for smooth transition
    local sign = distance_from_center >= 0 and 1 or -1
    local abs_distance = math.abs(distance_from_center)
    
    -- Rescale so deadzone edge maps to center and screen edge maps to max offset
    local rescaled = (abs_distance - center_deadzone) / (1.0 - center_deadzone)
    rescaled = math.max(0, math.min(1, rescaled))  -- Clamp to 0-1
    
    -- Apply sensitivity and calculate offset
    local offset_from_center = rescaled * (max_offset / 2) * sensitivity
    local new_offset = center_offset + (sign * offset_from_center)
    
    -- Clamp to valid range
    return math.max(0, math.min(max_offset, new_offset))
end

-- Smooth interpolation between current and target position
function lerp(a, b, t)
    return a + (b - a) * t
end

-- ============================================================================
-- OBS FILTER CONTROL - Apply crop to create viewport effect
-- ============================================================================
function apply_crop(offset)
    -- Get the source from OBS
    local source = obs.obs_get_source_by_name(source_name)
    if source == nil then 
        return false
    end
    
    -- Find the crop filter (must be named "Viewport_Crop")
    local crop_filter = obs.obs_source_get_filter_by_name(source, "Viewport_Crop")
    if crop_filter == nil then
        obs.obs_source_release(source)
        return false
    end
    
    -- Calculate crop amounts for each edge
    local left_crop = math.floor(offset)  -- How much to crop from left
    local right_crop = math.floor(ultrawide_width - offset - viewport_width)  -- Crop from right
    local top_crop = math.floor((ultrawide_height - viewport_height) / 2)  -- Center vertically
    local bottom_crop = math.floor((ultrawide_height - viewport_height) / 2)
    
    -- Ensure values are never negative
    left_crop = math.max(0, left_crop)
    right_crop = math.max(0, right_crop)
    top_crop = math.max(0, top_crop)
    bottom_crop = math.max(0, bottom_crop)
    
    -- Apply crop values to the filter
    local settings = obs.obs_source_get_settings(crop_filter)
    obs.obs_data_set_int(settings, "left", left_crop)
    obs.obs_data_set_int(settings, "right", right_crop)
    obs.obs_data_set_int(settings, "top", top_crop)
    obs.obs_data_set_int(settings, "bottom", bottom_crop)
    
    obs.obs_source_update(crop_filter, settings)
    
    -- Clean up memory
    obs.obs_data_release(settings)
    obs.obs_source_release(crop_filter)
    obs.obs_source_release(source)
    
    return true
end

-- ============================================================================
-- MAIN UPDATE LOOP - Called ~60 times per second
-- ============================================================================
function update_viewport()
    -- Don't do anything if tracking is disabled
    if not enabled then return end
    if source_name == "" then return end
    
    -- Get current mouse position
    local mouse_x = get_mouse_position()
    
    -- Calculate where viewport should be based on mouse position
    target_offset = calculate_target_from_mouse(mouse_x)
    
    -- Smoothly move current position toward target
    current_offset = lerp(current_offset, target_offset, smoothing)
    
    -- Apply the crop to actually move the viewport
    apply_crop(current_offset)
end

-- Timer callback - called every 16ms (~60 FPS)
function timer_callback()
    update_viewport()
end

-- ============================================================================
-- OBS SCRIPT UI - Configuration interface
-- ============================================================================
function script_properties()
    local props = obs.obs_properties_create()
    
    -- Source dropdown (which OBS source to track)
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
    
    -- Resolution settings
    obs.obs_properties_add_int(props, "ultrawide_width", "Ultrawide Width (px)", 1920, 7680, 1)
    obs.obs_properties_add_int(props, "ultrawide_height", "Ultrawide Height (px)", 1080, 4320, 1)
    obs.obs_properties_add_int(props, "viewport_width", "Viewport Width (px)", 1280, 3840, 1)
    obs.obs_properties_add_int(props, "viewport_height", "Viewport Height (px)", 720, 2160, 1)
    
    -- Behavior tuning
    obs.obs_properties_add_float_slider(props, "smoothing", "Smoothing (lower = faster)", 0.01, 0.5, 0.01)
    obs.obs_properties_add_float_slider(props, "sensitivity", "Sensitivity", 0.5, 3.0, 0.1)
    obs.obs_properties_add_float_slider(props, "center_deadzone", "Center Deadzone", 0.0, 0.5, 0.05)
    
    -- Enable/Disable toggle
    obs.obs_properties_add_bool(props, "enabled", "Enable Tracking")
    
    -- Status info
    obs.obs_properties_add_text(props, "info", 
        "ℹ️ Filter must be named 'Viewport_Crop'\n" ..
        "Screen width detected: " .. screen_width .. "px", 
        obs.OBS_TEXT_INFO)
    
    return props
end

-- Default values for settings
function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "ultrawide_width", 3440)
    obs.obs_data_set_default_int(settings, "ultrawide_height", 1440)
    obs.obs_data_set_default_int(settings, "viewport_width", 1920)
    obs.obs_data_set_default_int(settings, "viewport_height", 1080)
    obs.obs_data_set_default_double(settings, "smoothing", 0.15)
    obs.obs_data_set_default_double(settings, "sensitivity", 1.0)
    obs.obs_data_set_default_double(settings, "center_deadzone", 0.2)
    obs.obs_data_set_default_bool(settings, "enabled", false)
end

-- Called when user changes settings
function script_update(settings)
    source_name = obs.obs_data_get_string(settings, "source")
    ultrawide_width = obs.obs_data_get_int(settings, "ultrawide_width")
    ultrawide_height = obs.obs_data_get_int(settings, "ultrawide_height")
    viewport_width = obs.obs_data_get_int(settings, "viewport_width")
    viewport_height = obs.obs_data_get_int(settings, "viewport_height")
    smoothing = obs.obs_data_get_double(settings, "smoothing")
    sensitivity = obs.obs_data_get_double(settings, "sensitivity")
    center_deadzone = obs.obs_data_get_double(settings, "center_deadzone")
    
    local new_enabled = obs.obs_data_get_bool(settings, "enabled")
    
    -- When first enabling, start viewport centered
    if new_enabled and not enabled then
        local max_offset = ultrawide_width - viewport_width
        current_offset = max_offset / 2
        target_offset = current_offset
    end
    
    enabled = new_enabled
end

-- Script description shown in OBS
function script_description()
    return [[<center><h2>🖱️ Mouse Viewport Tracker (Auto-Center)</h2></center>
<p>Control viewport position using your mouse. Viewport returns to center when mouse is centered.</p>

<h3>Quick Setup:</h3>
<ol>
<li>Add <b>Crop/Pad</b> filter to your source</li>
<li>Rename filter to: <code>Viewport_Crop</code></li>
<li>Select source above</li>
<li>Enable tracking</li>
</ol>

<h3>Settings Guide:</h3>
<ul>
<li><b>Smoothing:</b> 0.10=responsive, 0.25=smooth</li>
<li><b>Sensitivity:</b> 1.0=normal, 2.0=wider range</li>
<li><b>Center Deadzone:</b> 0.2=medium center zone</li>
</ul>

<h3>🖱️ Controls:</h3>
<ul>
<li><b>Move Mouse Left:</b> Pan viewport left</li>
<li><b>Move Mouse Right:</b> Pan viewport right</li>
<li><b>Center Mouse:</b> Returns to center</li>
</ul>

<p><i>Windows only</i></p>]]
end

-- ============================================================================
-- SCRIPT LIFECYCLE - Initialize and cleanup
-- ============================================================================
function script_load(settings)
    -- Get actual screen width
    screen_width = get_screen_width()
    
    -- Start update timer at ~60 FPS (16ms = 1000ms / 60fps)
    obs.timer_add(timer_callback, 16)
    
    print("Mouse Viewport Tracker loaded - Screen width: " .. screen_width .. "px")
end

function script_unload()
    obs.timer_remove(timer_callback)
    print("Mouse Viewport Tracker unloaded")
end