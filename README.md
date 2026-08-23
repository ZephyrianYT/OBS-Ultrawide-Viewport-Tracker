# 🚀 OBS Ultrawide Viewport Tracker (v2.0 Master Edition)

> **Stream Ultrawide to standard 16:9 without black bars, frame drops, or setup headaches.**

The **all-in-one, zero-dependency OBS Studio solution** for 21:9 and 32:9 monitors. It dynamically tracks your mouse cursor or gamepad analog stick and glides a 16:9 camera smoothly across your screen in real time.

---

### 🔥 Why You Want This:
- **🪶 Zero-Config & Native:** Pure OBS Lua + FFI. **No Python installations**, no `pip` dependencies, and zero setup friction.
- **⚡ 1-Click Scene Setup:** Hit one button in OBS and it auto-generates your tracked scene with correct alignments automatically.
- **🎮 Mouse & Gamepad Ready:** Track via desktop cursor or steer the viewport using your Xbox / PC controller's analog sticks via native XInput.
- **✨ Framerate-Independent Smoothing:** Silky-smooth exponential decay camera gliding that feels fluid at 30, 60, or 120+ FPS.
- **🎯 Smart Deadzones & Auto-Centering:** Prevents camera shaking during minor cursor twitches and gently re-centers when you're AFK.

---

## 🛠️ Open-Source & Built to Be Modified
> **Take it. Break it. Upgrade it.**  
> This engine was built as a clean, high-performance base meant to be **ripped apart, modified, customized, and integrated** into your own streaming layouts, plugins, or overlay stacks. If you build something cool with it, submit a PR or fork away!

---

## ⚡ Quick Start (v2.0)

### 1. Download
Grab **`ultrawide_tracker.lua`** from this repository (or from the Releases page).

### 2. Load into OBS
1. Open OBS Studio and go to **Tools** → **Scripts**.
2. Click the **`+`** (Add) button at the bottom left.
3. Select `ultrawide_tracker.lua`.

### 3. One-Click Setup
1. In the Script settings panel, choose your game or monitor under **Capture Source**.
2. Click the **`⚡ 1-Click Auto Setup Scene`** button.
3. OBS will generate a `[Tracked] Ultrawide Viewport` scene with all transforms pre-applied. You're ready to stream!

---

## ⚙️ Modern Control Options

| Setting | What It Does |
|---|---|
| **Capture Source** | The target Game Capture, Display Capture, or Window Capture. |
| **Input Controller** | Switch between `Mouse Cursor`, `Gamepad (Right Stick)`, `Gamepad (Left Stick)`, or `Manual Snap`. |
| **Resolution Preset** | `Auto-Detect` matches your canvas automatically, or pick manual 21:9 / 32:9 presets. |
| **Tracking Axis** | `Horizontal Only` (recommended for HUD stability) or `2D (Horizontal & Vertical)`. |
| **Panning Smoothness** | Controls glide speed (higher = faster snap, lower = cinematic glide). |
| **Center Deadzone** | Inner deadzone area where small movements won't shake the viewport. |
| **Inactivity Auto-Center** | Smoothly glides back to center when no input is detected. |

---

## ⌨️ Native OBS Hotkeys
Configure these under **OBS Settings → Hotkeys**:
- **Ultrawide: Toggle Tracking** (Freeze/unfreeze camera on the fly)
- **Ultrawide: Snap Viewport Left**
- **Ultrawide: Snap Viewport Center**
- **Ultrawide: Snap Viewport Right**

---

<br>
<hr>
<br>

# 📦 Legacy Reference (Old 4-Script System)

<details>
<summary><b>Click to expand rules & setup for the old multi-script versions</b></summary>

### ⚠️ Deprecation Notice
The 4 individual standalone scripts (previously split by aspect ratio and tracking mode) have been superseded by the unified `ultrawide_tracker.lua`. If you are still maintaining legacy setups, the rules below apply:

#### Old Version Architecture Rules:
1. **Separate Aspect Files:** 
   - `21x9_horizontal.py` (3440×1440 / 2560×1080)
   - `32x9_horizontal.py` (5120×1440 / 3840×1080)
   - `21x9_2D.py`
   - `32x9_2D.py`
2. **Manual Canvas Alignment:** 
   - OBS Base Canvas had to be manually configured to 16:9 (e.g. `2560x1440` or `1920x1080`).
   - The capture source required manual alignment to `Top Left (0,0)` with bounding box scaling disabled.
3. **Python Runtime Requirement:** 
   - Required configuring Python 3.8–3.10 x64 paths in OBS Script Settings (`Tools -> Scripts -> Python Settings`).
   - Depended on external modules (`ctypes`, `pywin32`) for cursor pooling.
4. **Crop Offset Formulas:**
   - Left Crop = `(CursorX / SourceWidth) * (SourceWidth - TargetWidth)`
   - Right Crop = `(SourceWidth - TargetWidth) - LeftCrop`
   - Top Crop = `(CursorY / SourceHeight) * (SourceHeight - TargetHeight)`
   - Bottom Crop = `(SourceHeight - TargetHeight) - TopCrop`

*All the legacy math, edge clamping, and transforms above are now handled internally and dynamically by `ultrawide_tracker.lua`.*

</details>

---

## 📄 License
Released under the **MIT License**. Use it, mod it, share it!
