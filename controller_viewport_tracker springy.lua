--[[
================================================================================
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
]]

obs = obslua
local ffi = require("ffi")

-- ============================================================================
-- WINDOWS API DECLARATIONS (Don't modify unless you know what you're doing)
-- ============================================================================
ffi.cdef[[
    typedef struct {
        unsigned short wButtons;
        unsigned char bLeftTrigger;
        unsigned char bRightTrigger;
        short sThumbLX;
        short sThumbLY;
        short sThumbRX;        // RIGHT STICK X-AXIS (this is what we read)
        short sThumbRY;        // RIGHT STICK Y-AXIS (unused)
    } XINPUT_GAMEPAD;
    
    typedef struct {
        unsigned long dwPacketNumber;
        XINPUT_GAMEPAD Gamepad;
    } XINPUT_STATE;
    
    unsigned long XInputGetState(unsigned long dwUserIndex, XINPUT_STATE* pState);
]]

-- ============================================================================
-- SCRIPT CONFIGURATION - User Settings (set via OBS UI)
-- ============================================================================
local source_name = ""              -- Which OBS source to track
local ultrawide_width = 3440        -- Your monitor width (e.g., 3440 for 21:9)
local ultrawide_height = 1440       -- Your monitor height
local viewport_width = 1920         -- Output stream width (usually 1920)
local viewport_height = 1080        -- Output stream height (usually 1080)
local smoothing = 0.1               -- How smooth the movement is (0.01=instant, 0.5=very smooth)
local sensitivity = 1.5             -- How fast viewport moves (0.5=slow, 5.0=fast)
local deadzone = 0.15               -- Stick deadzone to prevent drift (0.0=none, 0.3=large)
local controller_index = 0          -- Which controller (0=first, 1=second, etc.)
local enabled = false               -- Is tracking active?

-- ============================================================================
-- INTERNAL STATE - Don't modify these
-- ============================================================================
local xinput = nil                  -- XInput library handle
local xinput_available = false      -- Did XInput load successfully?
local current_offset = 0            -- Current viewport position (pixels from left)
local target_offset = 0             -- Where viewport wants to be

-- ============================================================================
-- XINPUT INITIALIZATION - Load controller support
-- ============================================================================
local function load_xinput()
    -- Try different XInput DLL versions (newer to older)
    local xinput_dlls = {"xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll"}
    
    for _, dll_name in ipairs(xinput_dlls) do
        local success, result = pcall(function()
            return ffi.load(dll_name)
        end)
        
        if success then
            xinput = result
            xinput_available = true
            print("✓ Loaded " .. dll_name)
            return true
        end
    end
    
    print("✗ XInput not available - controller support disabled")
    return false
end

-- ============================================================================
-- CONTROLLER INPUT - Read right stick position
-- ============================================================================
function get_controller_state()
    if not xinput_available then return nil end
    
    local state = ffi.new("XINPUT_STATE")
    local result = xinput.XInputGetState(controller_index, state)
    
    -- result == 0 means controller connected successfully
    if result == 0 then
        return state
    end
    
    return nil  -- Controller not connected
end

-- Apply deadzone to stick input (prevents drift from worn sticks)
function normalize_stick(value, deadzone_threshold)
    -- Convert raw value (-32767 to +32767) to normalized float (-1.0 to +1.0)
    local normalized = value / 32767.0
    
    -- If stick is within deadzone, treat as zero
    if math.abs(normalized) < deadzone_threshold then
        return 0.0
    end
    
    -- Rescale so deadzone edge maps to 0.0 and max stick maps to 1.0
    local sign = normalized >= 0 and 1 or -1
    local abs_normalized = math.abs(normalized)
    local rescaled = (abs_normalized - deadzone_threshold) / (1.0 - deadzone_threshold)
    
    return sign * rescaled
end

-- ============================================================================
-- VIEWPORT POSITIONING - Calculate where viewport should be
-- ============================================================================
function calculate_target_from_stick(stick_x)
    -- Maximum distance viewport can move (total ultrawide width minus viewport width)
    local max_offset = ultrawide_width - viewport_width
    
    if max_offset <= 0 then
        return current_offset  -- Viewport is same size or bigger than source
    end
    
    -- Convert stick input (-1.0 to +1.0) to offset change
    -- Positive stick = move viewport right (increase offset)
    -- sensitivity controls how fast it moves
    -- Divide by 100 to make sensitivity values feel reasonable
    local offset_change = stick_x * sensitivity * (max_offset / 100.0)
    
    -- Add change to current position
    local new_offset = current_offset + offset_change
    
    -- Clamp to valid range (can't go past edges)
    new_offset = math.max(0, math.min(max_offset, new_offset))
    
    return new_offset
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
    if not xinput_available then return end
    
    -- Read controller state
    local state = get_controller_state()
    if state == nil then return end  -- Controller not connected
    
    -- Get right stick X-axis and normalize it
    local stick_x_raw = state.Gamepad.sThumbRX
    local stick_x = normalize_stick(stick_x_raw, deadzone)
    
    -- If stick is centered (no input), return to center position
    if math.abs(stick_x) < 0.01 then
        -- Calculate center position
        local max_offset = ultrawide_width - viewport_width
        target_offset = max_offset / 2
    else
        -- Calculate where viewport should be based on stick input
        target_offset = calculate_target_from_stick(stick_x)
    end
    
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
    
    -- Controller selection
    local controller_list = obs.obs_properties_add_list(props, "controller", "Controller", 
                                                        obs.OBS_COMBO_TYPE_LIST, 
                                                        obs.OBS_COMBO_FORMAT_INT)
    obs.obs_property_list_add_int(controller_list, "Controller 1", 0)
    obs.obs_property_list_add_int(controller_list, "Controller 2", 1)
    obs.obs_property_list_add_int(controller_list, "Controller 3", 2)
    obs.obs_property_list_add_int(controller_list, "Controller 4", 3)
    
    -- Resolution settings
    obs.obs_properties_add_int(props, "ultrawide_width", "Ultrawide Width (px)", 1920, 7680, 1)
    obs.obs_properties_add_int(props, "ultrawide_height", "Ultrawide Height (px)", 1080, 4320, 1)
    obs.obs_properties_add_int(props, "viewport_width", "Viewport Width (px)", 1280, 3840, 1)
    obs.obs_properties_add_int(props, "viewport_height", "Viewport Height (px)", 720, 2160, 1)
    
    -- Behavior tuning
    obs.obs_properties_add_float_slider(props, "smoothing", "Smoothing (lower = faster)", 0.01, 0.5, 0.01)
    obs.obs_properties_add_float_slider(props, "sensitivity", "Sensitivity", 0.5, 5.0, 0.1)
    obs.obs_properties_add_float_slider(props, "deadzone", "Stick Deadzone", 0.0, 0.3, 0.01)
    
    -- Enable/Disable toggle
    obs.obs_properties_add_bool(props, "enabled", "Enable Tracking")
    
    -- Status info
    local info_text = "ℹ️ Filter must be named 'Viewport_Crop'\n"
    if not xinput_available then
        info_text = info_text .. "⚠️ XInput not available"
    else
        info_text = info_text .. "✅ XInput loaded - controller ready"
    end
    obs.obs_properties_add_text(props, "info", info_text, obs.OBS_TEXT_INFO)
    
    return props
end

-- Default values for settings
function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "ultrawide_width", 3440)
    obs.obs_data_set_default_int(settings, "ultrawide_height", 1440)
    obs.obs_data_set_default_int(settings, "viewport_width", 1920)
    obs.obs_data_set_default_int(settings, "viewport_height", 1080)
    obs.obs_data_set_default_double(settings, "smoothing", 0.1)
    obs.obs_data_set_default_double(settings, "sensitivity", 1.5)
    obs.obs_data_set_default_double(settings, "deadzone", 0.15)
    obs.obs_data_set_default_int(settings, "controller", 0)
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
    deadzone = obs.obs_data_get_double(settings, "deadzone")
    controller_index = obs.obs_data_get_int(settings, "controller")
    
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
    return [[<center><h2>🎮 Controller Viewport Tracker</h2></center>
<p>Control viewport position using your controller's right analog stick.</p>

<h3>Quick Setup:</h3>
<ol>
<li>Add <b>Crop/Pad</b> filter to your source</li>
<li>Rename filter to: <code>Viewport_Crop</code></li>
<li>Select source above</li>
<li>Select controller</li>
<li>Enable tracking</li>
</ol>

<h3>Settings Guide:</h3>
<ul>
<li><b>Smoothing:</b> 0.05=instant, 0.20=smooth</li>
<li><b>Sensitivity:</b> 1.0=slow, 3.0=fast</li>
<li><b>Deadzone:</b> 0.15 prevents drift</li>
</ul>

<p><i>Windows + XInput controller required</i></p>]]
end

-- ============================================================================
-- SCRIPT LIFECYCLE - Initialize and cleanup
-- ============================================================================
function script_load(settings)
    -- Try to load XInput library
    load_xinput()
    
    -- Start update timer at ~60 FPS (16ms = 1000ms / 60fps)
    obs.timer_add(timer_callback, 16)
    
    if xinput_available then
        print("Controller Viewport Tracker loaded ✓")
    else
        print("Controller Viewport Tracker loaded (XInput unavailable)")
    end
end

function script_unload()
    obs.timer_remove(timer_callback)
    print("Controller Viewport Tracker unloaded")
end