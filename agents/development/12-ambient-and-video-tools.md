# Ambient Lighting, Picture-in-Picture & Video Tools

## Overview
This document covers MPV Anime Build's auxiliary video processing tools: Ambient Glow Manager (`scripts/ambient-manager.lua`), Picture-in-Picture mode (`scripts/pip.lua`), Dynamic Autocrop (`scripts/autocrop.lua`), Automatic Deinterlacing (`scripts/autodeint.lua`), and Manual Zoom (`scripts/manual_zoom.lua`).

---

## 🌈 Ambient Glow Lighting (`ambient-manager.lua`)

### Features
* Dynamically samples colors from the video borders and generates a real-time glowing ambient background filling black bars on ultrawide or non-native aspect ratio screens.
* **Cache Bypass Mechanism**: Alternates between two baked GLSL shaders (`ambient_baked_0.glsl` and `ambient_baked_1.glsl`) to circumvent MPV's aggressive GPU shader cache when aspect ratios change.
* **Regional/Locale Float Safety**: Replaces comma separators with periods to prevent European locale settings from breaking GLSL compilation.

### Keybinding & Toggle
- Shortcut: `CTRL+x` (`script-message toggle-crop-ambient`)
- **⚠️ SVP 4 Pro Users Warning**: Do not use Ambient Glow simultaneously with SVP's "Fill black bars" feature; choose one or the other to prevent rendering conflicts.

---

## 🪟 Picture-in-Picture Mode (`pip.lua`)

### Features
- Instantly snaps the MPV player window into a floating, always-on-top corner window (`30%x30%` or `35%x35%`).
- **Linux / KWin Compatibility**: Changes window title dynamically to `mpv-pip-mode` so Linux window managers (KWin, Hyprland, Sway) can apply sticky/floating window rules automatically.
- Remembers and restores pre-PiP geometry, fullscreen state, and aspect ratio upon exiting PiP mode.

---

## ✂️ Autocrop & Aspect Tools (`autocrop.lua` & `manual_zoom.lua`)

### Dynamic Autocrop
- Analyzes black bars (letterboxing/pillarboxing) using FFmpeg's `cropdetect` filter.
- Automatically crops hardcoded black bars from vintage 4:3 or non-standard aspect ratio encodes.

### Manual Zoom Engine (`manual_zoom.lua`)
- Provides 3 zoom modes switchable via UOSC menus or script-messages:
  1. **Fit-to-Zoom** (`zoom-mode-fit`): Preserves source aspect ratio.
  2. **Fill-to-Zoom** (`zoom-mode-fill`): Stretches to fill viewport.
  3. **Crop-to-Zoom** (`zoom-mode-crop`): Smart center-crops to eliminate borders.

---

## 🎞️ Auto Deinterlacing (`autodeint.lua`)

Automatically detects interlaced video streams using progressive/interlaced frame metadata and toggles hardware deinterlacing (`deinterlace=auto` / `d3d11va`/`yadif`) without requiring manual user intervention.
