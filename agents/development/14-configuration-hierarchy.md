# Configuration File Hierarchy & Overrides

## Overview
MPV Anime Build uses a robust, layered configuration hierarchy designed to separate core platform defaults from user-specific customizations, ensuring that git updates never overwrite personal settings.

---

## 🏗️ Configuration Layers & Load Precedence

Settings are evaluated from base defaults up to user-specific overrides:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. mpv.conf (Tracked in Git)                                │
│    ├─ [Platform-Windows-Base] / [Platform-Linux-Base]       │
│    ├─ [default] global base options                         │
│    └─ Conditional profile definitions ([Low-End], etc.)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Custom Config Files (Untracked)                          │
│    └─ mpv-<custom-name>.conf (Single file loaded at launch) │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Script Options (Default state)                           │
│    ├─ script-opts/uosc.conf                                 │
│    ├─ script-opts/anime-mode.conf                           │
│    ├─ script-opts/hdr-mode.conf                             │
│    └─ script-opts/youtube-download.conf                     │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Durable User Overrides (Untracked, Loaded Alphabetically)│
│    ├─ user-<anything>.conf                                  │
│    └─ user-settings.conf                                    │
│    (Automated persistence via scripts/user_settings.lua)    │
└─────────────────────────────────────────────────────────────┘
```

---

## 💾 Durable User Overrides (`user-*.conf`)

### Purpose
When users adjust sliders or toggles in UOSC (such as brightness, contrast, subtitle font size, deband iterations, interpolation, tone mapping), `scripts/user_settings.lua` catches the command and writes the values to `user-settings.conf` (or the last alphabetical `user-*.conf`).

### Managed Properties
```lua
properties = {
    "interpolation",
    "deband", "deband-iterations", "deband-threshold", "deband-range", "deband-grain",
    "deinterlace",
    "audio-delay", "sub-delay", "sub-pos",
    "contrast", "brightness", "gamma", "saturation", "hue",
    "sub-font", "sub-ass-override", "sub-font-size", "sub-blur", "sub-gauss", "sub-spacing",
    "sub-scale-with-window", "stretch-image-subs-to-screen", "sub-use-margins",
    "blend-subtitles", "sub-fix-timing",
    "video-sync", "dither", "dither-depth", "hwdec", "gpu-api", "gpu-context",
    "scale", "dscale", "cscale", "tscale",
    "linear-upscaling", "sigmoid-upscaling", "correct-downscaling", "linear-downscaling",
}
```

### Safety & Power Guard Ownership
If the user adjusts a setting during active Eco/Battery mode (e.g. scale), the setting is persisted to disk for later, but `reassert-low-power` immediately reasserts the `[Low-End]` profile's bilinear scaler so battery life is not compromised.

---

## 📁 Key File Locations

| File | Purpose | Git Status |
| :--- | :--- | :--- |
| `mpv.conf` | Core engine, platform profiles, video/audio output defaults | Tracked |
| `input.conf` | Keyboard shortcuts & mouse bindings | Tracked |
| `script-opts/build_info.conf` | Authoritative build version (`version=v5.2`) | Tracked |
| `script-opts/uosc.conf` | UOSC interface style, control buttons, timeline colors | Tracked |
| `script-opts/anime-mode.conf` | Initial states for controller (modes, shaders, toggles) | Tracked |
| `user-settings.conf` | Saved user preferences from UI menus | **Untracked (Local)** |
| `track-selector-overrides.json`| Saved per-video manual track selections | **Untracked (Local)** |
| `uosc_history.json` | Watch history entries (up to 50 videos) | **Untracked (Local)** |
