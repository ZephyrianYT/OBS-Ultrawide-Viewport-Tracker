# OBS Ultrawide Viewport Tracker

Stream or record an **ultrawide (21:9 / 32:9) monitor as normal 16:9** without black bars.
A 16:9 window follows your **mouse** or **controller stick** across the screen and glides smoothly.

One Lua file. No Python, no plugins, nothing else to install.

---

## Install (1 minute)

1. **Download [`ultrawide_tracker.lua`](ultrawide_tracker.lua)** (open it, then click the download button).
2. In OBS: **Tools → Scripts → `+`** and pick the file.
3. In the script panel, choose your game or display capture under **Capture Source**.
4. Click **1-Click Setup Scene**.

That's it. OBS switches to a new `[Tracked] Ultrawide Viewport` scene and the view follows your mouse.

> **Tip:** set your OBS canvas (**Settings → Video → Base Resolution**) to a 16:9 size such as `1920x1080` or `2560x1440`. The script works out the window size from your source and canvas automatically.

---

## Settings

| Setting | What it does |
|---|---|
| **Capture Source** | The game, display or window capture to pan across. |
| **Follow** | `Mouse cursor`, `Controller - right stick`, `Controller - left stick`, or `Hotkeys only`. |
| **Direction** | `Left / right only` (recommended) or also `up / down`. |
| **Speed** | Higher = snappier, lower = smoother, more cinematic. |
| **Mouse center deadzone** | Small movements near the center don't move the view. |
| **Stick deadzone** | Ignores controller stick drift. |
| **Return to center when idle** | Glides back to center after the idle delay. |
| **Monitor X offset** | Only for multi-monitor setups: the left edge (in pixels) of the monitor you capture, e.g. `1920` if it sits right of a 1080p screen. |

## Hotkeys

Set these in **OBS Settings → Hotkeys**:

- **Ultrawide: Toggle Tracking**: freeze or unfreeze the view
- **Ultrawide: Snap Left / Center / Right**: jump the view; moving the mouse or stick takes over again

---

## Already have your own scene?

Skip the setup button. Add your capture to any scene, then right-click it → **Transform → Fit to screen**.
The script crops that source in whichever scene is live.

## Troubleshooting

- **Nothing moves:** make sure the selected Capture Source is in the scene that's live, and that tracking isn't toggled off by the hotkey.
- **Game capture shows nothing yet:** the script waits until the game is hooked and has a size.
- **Controller does nothing:** an XInput (Xbox-compatible) controller is needed. Mouse and controller input work on Windows only.
- **View is offset on a multi-monitor setup:** set **Monitor X offset**.

---

## Older scripts

The original single-purpose scripts are in [`legacy/`](legacy). They need a Crop/Pad filter named `Viewport_Crop` and manual sizes. `ultrawide_tracker.lua` replaces both.

## License

MIT. Use it, mod it, share it. PRs welcome.
