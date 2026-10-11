--[[
================================================================================
OBS ULTRAWIDE VIEWPORT TRACKER  v2.1
================================================================================
Pans a 16:9 (or whatever your canvas is) window across an ultrawide capture,
following your mouse cursor or a controller stick.

SETUP (about 1 minute):
  1. OBS -> Tools -> Scripts -> "+" -> pick this file.
  2. Choose your game / display capture under "Capture Source".
  3. Click "1-Click Setup Scene". Done.

Works with any source size (21:9, 32:9, ...) and any canvas size: the viewport
size is worked out automatically. Mouse and controller input are Windows only.
MIT License.
================================================================================
]]

local obs = obslua
local ffi = require("ffi")

-- ---------------------------------------------------------------------------
-- Windows input (mouse via user32, controller via XInput)
-- ---------------------------------------------------------------------------
pcall(ffi.cdef, [[
    typedef struct { long x; long y; } UWT_POINT;
    int GetCursorPos(UWT_POINT* lpPoint);

    typedef struct {
        unsigned short wButtons;
        unsigned char  bLeftTrigger;
        unsigned char  bRightTrigger;
        short          sThumbLX;
        short          sThumbLY;
        short          sThumbRX;
        short          sThumbRY;
    } UWT_XINPUT_GAMEPAD;

    typedef struct {
        unsigned long      dwPacketNumber;
        UWT_XINPUT_GAMEPAD Gamepad;
    } UWT_XINPUT_STATE;

    unsigned long XInputGetState(unsigned long dwUserIndex, UWT_XINPUT_STATE* pState);
]])

local mouse_available = ffi.os == "Windows" and pcall(function() return ffi.C.GetCursorPos end)
local cursor_pt = mouse_available and ffi.new("UWT_POINT") or nil

local xinput = nil
if ffi.os == "Windows" then
    for _, dll in ipairs({"xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll"}) do
        local ok, lib = pcall(ffi.load, dll)
        if ok then xinput = lib; break end
    end
end
local pad_state = xinput and ffi.new("UWT_XINPUT_STATE") or nil

-- ---------------------------------------------------------------------------
-- Settings (filled in by script_update)
-- ---------------------------------------------------------------------------
local SCENE_NAME = "[Tracked] Ultrawide Viewport"

local source_name      = ""
local input_device     = "mouse"       -- "mouse", "gamepad_r", "gamepad_l", "manual"
local tracking_axis    = "horizontal"  -- "horizontal", "both"
local smoothness       = 8.0           -- higher = snappier
local deadzone_pct     = 10.0          -- mouse centre deadzone (% of screen)
local stick_deadzone   = 20.0          -- controller stick deadzone (%)
local idle_return      = true
local idle_timeout     = 3.0           -- seconds
local monitor_x_offset = 0             -- left edge of the captured monitor (px)

-- ---------------------------------------------------------------------------
-- Runtime state
-- ---------------------------------------------------------------------------
local tracking_enabled = true
local current_x, current_y = nil, nil  -- crop offsets in source pixels
local last_raw_x, last_raw_y = nil, nil
local idle_time = 0.0
local snap_frac = nil                  -- 0 / 0.5 / 1 while a snap hotkey is holding the view
local last_crop = {l = -1, r = -1, t = -1, b = -1}
local hotkeys = {}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Framerate-independent smoothing.
local function exp_decay(current, target, speed, dt)
    return target + (current - target) * math.exp(-speed * dt)
end

-- Removes a centred deadzone from a -1..1 value and rescales the rest to -1..1.
local function apply_deadzone(v, dz)
    if math.abs(v) <= dz then return 0.0 end
    local sign = v > 0 and 1 or -1
    return sign * clamp((math.abs(v) - dz) / (1.0 - dz), 0.0, 1.0)
end

-- ---------------------------------------------------------------------------
-- Geometry
-- ---------------------------------------------------------------------------

-- Returns source size and the largest canvas-shaped window that fits inside it.
local function get_geometry()
    local src = obs.obs_get_source_by_name(source_name)
    if src == nil then return nil end
    local sw = obs.obs_source_get_base_width(src)
    local sh = obs.obs_source_get_base_height(src)
    obs.obs_source_release(src)
    if sw <= 0 or sh <= 0 then return nil end  -- e.g. game capture not hooked yet

    local ovi = obs.obs_video_info()
    if not obs.obs_get_video_info(ovi) or ovi.base_width <= 0 or ovi.base_height <= 0 then
        return nil
    end
    local aspect = ovi.base_width / ovi.base_height

    local vw, vh = sh * aspect, sh
    if vw > sw then vw, vh = sw, sw / aspect end

    return {
        sw = sw, sh = sh,
        max_x = math.max(0, sw - vw),
        max_y = math.max(0, sh - vh),
        canvas_w = ovi.base_width, canvas_h = ovi.base_height,
    }
end

-- ---------------------------------------------------------------------------
-- Input -> normalised position (-1..1 on each axis, 0 = centre)
-- ---------------------------------------------------------------------------
local function read_mouse(g)
    if not mouse_available or ffi.C.GetCursorPos(cursor_pt) == 0 then return nil end
    local px, py = tonumber(cursor_pt.x), tonumber(cursor_pt.y)
    local dz = deadzone_pct / 100.0
    local nx = apply_deadzone(clamp((px - monitor_x_offset) / g.sw, 0, 1) * 2 - 1, dz)
    local ny = apply_deadzone(clamp(py / g.sh, 0, 1) * 2 - 1, dz)
    return nx, ny, px, py
end

local function read_gamepad(right_stick)
    if xinput == nil then return nil end
    for i = 0, 3 do
        if xinput.XInputGetState(i, pad_state) == 0 then
            local pad = pad_state.Gamepad
            local rx = right_stick and pad.sThumbRX or pad.sThumbLX
            local ry = right_stick and pad.sThumbRY or pad.sThumbLY
            local dz = stick_deadzone / 100.0
            local nx = apply_deadzone(clamp(rx / 32767.0, -1, 1), dz)
            local ny = apply_deadzone(clamp(-ry / 32767.0, -1, 1), dz)  -- stick up = look up
            -- Quantise so stick noise inside the deadzone doesn't count as activity.
            return nx, ny, math.floor(nx * 100), math.floor(ny * 100)
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Apply crop to the source in whatever scene is live
-- ---------------------------------------------------------------------------
local function apply_crop(g, x, y)
    local l = math.floor(x + 0.5)
    local t = math.floor(y + 0.5)
    local r = math.floor(g.max_x + 0.5) - l
    local b = math.floor(g.max_y + 0.5) - t
    if l == last_crop.l and r == last_crop.r and t == last_crop.t and b == last_crop.b then
        return
    end

    local scene_src = obs.obs_frontend_get_current_scene()
    if scene_src == nil then return end
    local scene = obs.obs_scene_from_source(scene_src)
    local item = scene and obs.obs_scene_find_source_recursive(scene, source_name)
    if item ~= nil then
        local crop = obs.obs_sceneitem_crop()
        crop.left, crop.right, crop.top, crop.bottom = l, r, t, b
        obs.obs_sceneitem_set_crop(item, crop)
        last_crop = {l = l, r = r, t = t, b = b}
    end
    obs.obs_source_release(scene_src)
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------
function script_tick(seconds)
    if not tracking_enabled or source_name == "" then return end
    local g = get_geometry()
    if g == nil then return end

    local nx, ny, raw_x, raw_y = nil, nil, nil, nil
    if input_device == "mouse" then
        nx, ny, raw_x, raw_y = read_mouse(g)
    elseif input_device == "gamepad_r" or input_device == "gamepad_l" then
        nx, ny, raw_x, raw_y = read_gamepad(input_device == "gamepad_r")
    end
    nx, ny = nx or 0.0, ny or 0.0

    -- Any real input movement cancels a snap and resets the idle timer.
    if raw_x ~= last_raw_x or raw_y ~= last_raw_y then
        if last_raw_x ~= nil then snap_frac = nil end
        idle_time = 0.0
        last_raw_x, last_raw_y = raw_x, raw_y
    else
        idle_time = idle_time + seconds
    end

    local tx, ty
    if snap_frac ~= nil then
        tx, ty = snap_frac, 0.0
    elseif input_device == "manual" or (idle_return and idle_time > idle_timeout) then
        tx, ty = 0.0, 0.0
    else
        tx, ty = nx, ny
    end
    if tracking_axis ~= "both" then ty = 0.0 end

    local target_x = (tx + 1) / 2 * g.max_x
    local target_y = (ty + 1) / 2 * g.max_y
    current_x = exp_decay(current_x or target_x, target_x, smoothness, seconds)
    current_y = exp_decay(current_y or target_y, target_y, smoothness, seconds)

    apply_crop(g, current_x, current_y)
end

-- ---------------------------------------------------------------------------
-- 1-Click scene setup
-- ---------------------------------------------------------------------------
local function setup_scene()
    if source_name == "" then
        obs.script_log(obs.LOG_WARNING, "Pick a Capture Source first, then click Setup.")
        return
    end
    local capture = obs.obs_get_source_by_name(source_name)
    if capture == nil then
        obs.script_log(obs.LOG_WARNING, "Source '" .. source_name .. "' not found.")
        return
    end

    local scene_src = obs.obs_get_source_by_name(SCENE_NAME)
    local scene
    if scene_src == nil then
        scene = obs.obs_scene_create(SCENE_NAME)
        scene_src = obs.obs_scene_get_source(scene)  -- owns the creation reference
    else
        scene = obs.obs_scene_from_source(scene_src)
    end

    local item = obs.obs_scene_find_source(scene, source_name)
    if item == nil then item = obs.obs_scene_add(scene, capture) end
    obs.obs_source_release(capture)

    -- Stretch whatever the crop leaves to fill the canvas exactly.
    local ovi = obs.obs_video_info()
    if item ~= nil and obs.obs_get_video_info(ovi) then
        local pos = obs.vec2()
        pos.x, pos.y = 0, 0
        local bounds = obs.vec2()
        bounds.x, bounds.y = ovi.base_width, ovi.base_height
        obs.obs_sceneitem_set_alignment(item, obs.OBS_ALIGN_LEFT + obs.OBS_ALIGN_TOP)
        obs.obs_sceneitem_set_pos(item, pos)
        obs.obs_sceneitem_set_rot(item, 0)
        obs.obs_sceneitem_set_bounds_type(item, obs.OBS_BOUNDS_STRETCH)
        obs.obs_sceneitem_set_bounds_alignment(item, 0)
        obs.obs_sceneitem_set_bounds(item, bounds)
    end

    obs.obs_frontend_set_current_scene(scene_src)
    obs.obs_source_release(scene_src)
    last_crop = {l = -1, r = -1, t = -1, b = -1}
    obs.script_log(obs.LOG_INFO, "Scene '" .. SCENE_NAME .. "' is ready.")
end

-- ---------------------------------------------------------------------------
-- OBS script API
-- ---------------------------------------------------------------------------
function script_description()
    local warn = ""
    if not mouse_available then
        warn = "<p style='color:#e5a00d'>Mouse/controller input needs Windows. Only hotkeys will work here.</p>"
    elseif xinput == nil then
        warn = "<p style='color:#e5a00d'>XInput not found: controller input is unavailable.</p>"
    end
    return [[<h2>Ultrawide Viewport Tracker</h2>
<p>Follows your mouse or controller with a 16:9 window over an ultrawide capture.</p>
<ol>
<li>Choose your <b>Capture Source</b>.</li>
<li>Click <b>1-Click Setup Scene</b>.</li>
</ol>
<p>Hotkeys (Settings &rarr; Hotkeys): Toggle Tracking, Snap Left / Center / Right.</p>]] .. warn
end

function script_properties()
    local props = obs.obs_properties_create()

    local p = obs.obs_properties_add_list(props, "source", "Capture Source",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, s in ipairs(sources) do
            local name = obs.obs_source_get_name(s)
            obs.obs_property_list_add_string(p, name, name)
        end
        obs.source_list_release(sources)
    end

    obs.obs_properties_add_button(props, "setup", "1-Click Setup Scene", function()
        setup_scene()
        return false
    end)

    p = obs.obs_properties_add_list(props, "input_device", "Follow",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(p, "Mouse cursor", "mouse")
    obs.obs_property_list_add_string(p, "Controller - right stick", "gamepad_r")
    obs.obs_property_list_add_string(p, "Controller - left stick", "gamepad_l")
    obs.obs_property_list_add_string(p, "Hotkeys only", "manual")

    p = obs.obs_properties_add_list(props, "tracking_axis", "Direction",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(p, "Left / right only", "horizontal")
    obs.obs_property_list_add_string(p, "Left / right and up / down", "both")

    obs.obs_properties_add_float_slider(props, "smoothness", "Speed (higher = snappier)", 1.0, 30.0, 0.5)
    obs.obs_properties_add_float_slider(props, "deadzone_pct", "Mouse center deadzone (%)", 0.0, 40.0, 1.0)
    obs.obs_properties_add_float_slider(props, "stick_deadzone", "Stick deadzone (%)", 5.0, 50.0, 1.0)
    obs.obs_properties_add_bool(props, "idle_return", "Return to center when idle")
    obs.obs_properties_add_float_slider(props, "idle_timeout", "Idle delay (seconds)", 0.5, 10.0, 0.5)
    obs.obs_properties_add_int(props, "monitor_x_offset",
        "Monitor X offset (px, multi-monitor only)", -16384, 16384, 1)

    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "input_device", "mouse")
    obs.obs_data_set_default_string(settings, "tracking_axis", "horizontal")
    obs.obs_data_set_default_double(settings, "smoothness", 8.0)
    obs.obs_data_set_default_double(settings, "deadzone_pct", 10.0)
    obs.obs_data_set_default_double(settings, "stick_deadzone", 20.0)
    obs.obs_data_set_default_bool(settings, "idle_return", true)
    obs.obs_data_set_default_double(settings, "idle_timeout", 3.0)
    obs.obs_data_set_default_int(settings, "monitor_x_offset", 0)
end

function script_update(settings)
    local new_source = obs.obs_data_get_string(settings, "source")
    if new_source ~= source_name then
        current_x, current_y = nil, nil
    end
    source_name      = new_source
    input_device     = obs.obs_data_get_string(settings, "input_device")
    tracking_axis    = obs.obs_data_get_string(settings, "tracking_axis")
    smoothness       = obs.obs_data_get_double(settings, "smoothness")
    deadzone_pct     = obs.obs_data_get_double(settings, "deadzone_pct")
    stick_deadzone   = obs.obs_data_get_double(settings, "stick_deadzone")
    idle_return      = obs.obs_data_get_bool(settings, "idle_return")
    idle_timeout     = obs.obs_data_get_double(settings, "idle_timeout")
    monitor_x_offset = obs.obs_data_get_int(settings, "monitor_x_offset")
    last_crop = {l = -1, r = -1, t = -1, b = -1}
end

local HOTKEYS = {
    {id = "uwt_toggle",  label = "Ultrawide: Toggle Tracking",
     fn = function() tracking_enabled = not tracking_enabled end},
    {id = "uwt_snap_l",  label = "Ultrawide: Snap Left",   fn = function() snap_frac = -1.0 end},
    {id = "uwt_snap_c",  label = "Ultrawide: Snap Center", fn = function() snap_frac = 0.0 end},
    {id = "uwt_snap_r",  label = "Ultrawide: Snap Right",  fn = function() snap_frac = 1.0 end},
}

function script_load(settings)
    for _, h in ipairs(HOTKEYS) do
        local fn = h.fn
        hotkeys[h.id] = obs.obs_hotkey_register_frontend(h.id, h.label, function(pressed)
            if pressed then fn() end
        end)
        local saved = obs.obs_data_get_array(settings, h.id)
        obs.obs_hotkey_load(hotkeys[h.id], saved)
        obs.obs_data_array_release(saved)
    end
end

function script_save(settings)
    for _, h in ipairs(HOTKEYS) do
        local arr = obs.obs_hotkey_save(hotkeys[h.id])
        obs.obs_data_set_array(settings, h.id, arr)
        obs.obs_data_array_release(arr)
    end
end
