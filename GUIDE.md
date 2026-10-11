# Guide

- [Why you might need it](#why-you-might-need-it)
- [Install](#install)
- [How it works](#how-it-works)
- [Use cases](#use-cases)
- [Updating and removing](#updating-and-removing)
- [Troubleshooting](#troubleshooting)

---

## Why you might need it

Ultrawide monitors (21:9 like 3440×1440, or 32:9 like 5120×1440) don't fit a normal 16:9 stream or video. In OBS you usually get one of these:

| Option | Problem |
|---|---|
| Shrink the whole screen to fit | Big black bars above and below, and everything looks tiny on phones. |
| Stretch it to fill | Everything looks squashed. |
| Crop a fixed area in the middle | Anything you do near the edges goes off-screen. |

This script gives you a fourth option: a **16:9 window that moves to wherever you're looking**. Viewers see a normal, full-size picture, and they still see what you're doing even at the far edges of the screen.

It's a good fit if you:
- stream or record from an ultrawide monitor to Twitch, YouTube, Kick or similar
- make tutorials or desktop recordings on an ultrawide screen
- want vertical (9:16) clips for TikTok / Shorts / Reels from an ultrawide screen

You **don't** need it if your monitor is already 16:9 and your canvas is 16:9. There's nothing to pan across.

---

## Install

**You need:** OBS Studio 28 or newer. Mouse and controller tracking need **Windows**. On Mac/Linux the script loads, but only the hotkeys work.

Nothing else is needed. OBS already includes Lua scripting, so there's no Python or plugin to install.

### 1. Download the script

Pick one:
- **Easiest:** open [`ultrawide_tracker.lua`](ultrawide_tracker.lua) on GitHub and click the **Download raw file** button (top right of the file view).
- Download the whole repo: **Code → Download ZIP**, then unzip it.
- `git clone https://github.com/ZephyrianYT/OBS-Ultrawide-Viewport-Tracker`

Save it somewhere it will stay, for example `Documents\OBS Scripts\`. OBS loads it from that location every time it starts, so don't leave it in Downloads if you clean that folder.

### 2. Set your canvas size

**Settings → Video → Base (Canvas) Resolution**: set this to the shape you want viewers to see.

| You want | Canvas |
|---|---|
| Normal stream / YouTube | `1920x1080` or `2560x1440` |
| Vertical clips | `1080x1920` |

The script reads this to work out the size of the moving window, so set it first.

### 3. Add your capture

In any scene, add a **Display Capture** (whole monitor) or **Game Capture** (one game). If you already have one, skip this step.

### 4. Load the script

1. **Tools → Scripts**
2. Click **`+`** at the bottom left and pick `ultrawide_tracker.lua`.
3. Under **Capture Source**, choose the capture from step 3.
4. Click **1-Click Setup Scene**.

OBS creates and switches to a scene called `[Tracked] Ultrawide Viewport`. Move your mouse to the left and right edges, and the view should follow.

### 5. (Optional) Set hotkeys

**Settings → Hotkeys**, search for `Ultrawide`:

| Hotkey | Does |
|---|---|
| Ultrawide: Toggle Tracking | Freeze / unfreeze the view where it is. |
| Ultrawide: Snap Left / Center / Right | Jump the view. It stays there until you move the mouse or stick. |

Hotkeys are saved and come back after OBS restarts.

---

## How it works

Every frame (60 times a second at 60 FPS) the script:

1. **Works out the window size.** It takes the largest rectangle with your canvas's shape that fits inside your capture.
   For example, a 3440×1440 monitor with a 16:9 canvas gives a 2560×1440 window, which leaves 880 px of room to slide left and right.
2. **Reads your input.** That's the mouse position on the captured monitor, or a controller stick.
3. **Picks a target position.**
   - Mouse: the window follows where the cursor is across the screen. Far left shows the left edge, the middle shows the middle, and so on. Small movements near the center (the *deadzone*) are ignored so the picture doesn't wobble.
   - Controller: tilting the stick pushes the window that way. Let go and it springs back to center.
4. **Glides there smoothly.** It eases toward the target instead of jumping, and the motion feels the same at 30, 60 or 144 FPS. The **Speed** setting controls how quickly it catches up.
5. **Crops the capture.** It sets the crop on the capture inside the live scene. This is the same crop you'd get by Alt-dragging the source edges. The cropped area is stretched to fill the canvas.

The script doesn't add filters, re-encode anything, or touch your game. It moves a crop rectangle, which costs almost no CPU. Only the capture in the scene that's **live** is moved. Other scenes are left alone until you switch to them.

---

## Use cases

Everything below is built into the one script; you change behavior with the **Follow** and **Direction** settings.

### Mouse games (strategy, MOBA, simulation, shooters)
- **Follow:** Mouse cursor
- **Speed:** 6–10, smooth enough not to make viewers dizzy
- **Mouse center deadzone:** 10–20%
- **Return to center when idle:** on

The view follows wherever you click, and drifts back to center when you stop moving the mouse.

### Controller games (third-person, racing, action)
- **Follow:** Controller - right stick (camera stick), or left stick if you'd rather follow movement
- **Stick deadzone:** 15–25%; raise it if the view drifts on its own
- **Speed:** 4–8

Push the stick and viewers see more of that side; let go and it returns to center. Any Xbox-compatible (XInput) controller works. The first connected controller is used.

### Desktop tutorials and coding streams
- **Follow:** Mouse cursor
- **Speed:** 4–6 for a calm, readable glide
- **Return to center when idle:** **off**, so the view stays on the window you're working in while you type

### You decide where the camera goes
- **Follow:** Hotkeys only
- Set the **Snap Left / Center / Right** hotkeys (e.g. on a Stream Deck).

The view only moves when you press a hotkey. This is good for games where the action sits in fixed places, like a minimap on one side and chat on the other.

### Vertical clips (TikTok / Shorts / Reels)
- Set the canvas to `1080x1920`.
- **Follow:** Mouse cursor
- Click **1-Click Setup Scene** again so the capture is refit to the new canvas.

The window becomes a tall 9:16 strip that follows your cursor across the ultrawide screen.

### Up/down tracking
- **Direction:** Left / right and up / down

This only does something when the window is **shorter** than your capture. That happens, for example, with a 16:9 monitor on a 21:9 "cinematic" canvas. With an ultrawide monitor and a 16:9 canvas the window is already full height, so leave this on *Left / right only*.

### Multi-monitor setups
If the monitor you capture isn't your main (leftmost) one, set **Monitor X offset** to where it starts:

| Layout | Offset |
|---|---|
| Ultrawide is the main monitor | `0` |
| A 1920 px monitor is to the left of it | `1920` |
| A 1920 px monitor is to the right, and the ultrawide sits to its left | `-3440` (minus the ultrawide's width) |

Check **Windows Settings → Display** if you're unsure which monitor is main.

### Already have your own scene layout?
You don't have to use the setup button. Add your capture to any scene, then right-click it → **Transform → Fit to screen**. The script crops it wherever it is, including inside nested scenes or groups.

---

## Updating and removing

- **Update:** replace `ultrawide_tracker.lua` with the new version, then in **Tools → Scripts** select it and click the **reload** (↻) button. Your settings are kept.
- **Remove:** select it in **Tools → Scripts** and click **`-`**. The capture keeps its last crop. To undo the crop, right-click the capture → **Transform → Reset Transform**.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Nothing moves | Check the **Capture Source** is the one in the live scene, and that the Toggle Tracking hotkey hasn't paused it. |
| Game capture is black or doesn't move | The script waits until the game is hooked. Make sure the game is running and visible in OBS. |
| View is shifted or tracks the wrong area | On multi-monitor setups, set **Monitor X offset**. |
| Black bars or the wrong size after changing the canvas | Click **1-Click Setup Scene** again, or right-click the capture → Transform → Fit to screen. |
| Controller does nothing | Use an XInput (Xbox-compatible) controller. PlayStation controllers need Steam Input or DS4Windows to appear as XInput. |
| View drifts with the controller | Raise **Stick deadzone**. |
| Too shaky / too slow | Lower / raise **Speed**, and raise the deadzone. |
| See errors | **Tools → Scripts → Script Log** shows what the script reports. |
