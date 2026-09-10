# Architecture Overview

## Overview
This document describes MPV Anime Build's script architecture, event sequencing, inter-script communication patterns, and profile evaluation hierarchy.

---

## 🏗️ System Architecture

### Component Layers

```
┌─────────────────────────────────────────────────────┐
│              MPV Core Engine                        │
│  (gpu-next, hwdec, profiles, properties)           │
└─────────────────────────────────────────────────────┘
                        ↕
┌─────────────────────────────────────────────────────┐
│         Profile Evaluation Layer                    │
│  - Platform detection (Windows/Linux)              │
│  - SVP IPC configuration                           │
│  - Resolution-based profile selection              │
│  - HDR/SDR mode switching                          │
└─────────────────────────────────────────────────────┘
                        ↕
┌─────────────────────────────────────────────────────┐
│        Core Controller Scripts                      │
│  • anime_profile_controller.lua (master brain)     │
│  • power_manager.lua (eco/battery mode)            │
│  • hdr_detect.lua (display detection)              │
│  • vsr_auto.lua (RTX upscaling)                    │
└─────────────────────────────────────────────────────┘
                        ↕
┌─────────────────────────────────────────────────────┐
│         Content Processing Scripts                  │
│  • track-selector.lua (audio/subtitle logic)       │
│  • skip_intro.lua (chapter detection)              │
│  • audio-visualizer.lua (audio-only mode)          │
│  • autocrop.lua, autodeint.lua                     │
└─────────────────────────────────────────────────────┘
                        ↕
┌─────────────────────────────────────────────────────┐
│            UI & Integration Layer                   │
│  • uosc/main.lua (custom glass UI)                 │
│  • uosc/elements/* (UI components)                 │
│  • stats_overlay.lua (diagnostics)                 │
│  • thumbfast.lua (thumbnail generation)            │
└─────────────────────────────────────────────────────┘
                        ↕
┌─────────────────────────────────────────────────────┐
│       Session Persistence & Utilities               │
│  • user_settings.lua (durable overrides)           │
│  • Up_Next.lua (watch history)                     │
│  • autoload.lua (playlist generation)              │
│  • youtube-download.lua (stream extraction)        │
└─────────────────────────────────────────────────────┘
```

---

## 🔄 MPV Event Lifecycle

### Script Load Order
MPV loads scripts alphabetically from `scripts/` directory:

```
1. ambient-manager.lua
2. anime_profile_controller.lua       ← Master controller
3. audio-visualizer.lua
4. auto-audio-device.lua
5. autocrop.lua
6. autodeint.lua
7. autoload.lua
8. autosave.lua
9. auto-save-state.lua
10. betterchapters.lua
11. blacklist-extensions.lua
12. firequalizer15.lua
13. fix-sub-timing.lua
14. hdr_detect.lua                     ← Display detection
15. manual_zoom.lua
16. mpvSockets.lua
17. pip.lua
18. power_manager.lua                  ← Battery/eco mode
19. show_status.lua
20. skip_intro.lua                     ← Chapter categories
21. stats_overlay.lua
22. thumbfast.lua
23. track-selector.lua                 ← Track intelligence
24. uosc/main.lua                      ← Custom UI (loads last in uosc/)
25. update_check.lua
26. Up_Next.lua
27. user_settings.lua
28. vsr_auto.lua                       ← RTX VSR
29. youtube-download.lua
```

### Critical Event Sequence

#### 1. File Loaded (`file-loaded`)
```lua
-- Triggered when a new file begins loading
mp.register_event("file-loaded", function()
    -- Profile evaluation happens here
    -- anime_profile_controller reads metadata
    -- track-selector runs smart selection
    -- HDR detection activates
end)
```

#### 2. Video Reconfig (`video-reconfig`)
```lua
-- Triggered when video resolution/format changes
mp.observe_property("video-params", "native", function(name, params)
    -- Resolution tier detection
    -- Shader chain selection
    -- VSR ratio calculation
end)
```

#### 3. Playback Restart (`playback-restart`)
```lua
-- Triggered after seeking or format change
mp.register_event("playback-restart", function()
    -- Shader application
    -- State synchronization
end)
```

#### 4. Shutdown (`shutdown`)
```lua
-- Triggered on quit
mp.register_event("shutdown", function()
    -- Save watch-later state
    -- Persist user settings
end)
```

---

## 📡 Script Communication Patterns

### 1. Script-Message Bus
The primary inter-script communication mechanism.

#### Broadcast Pattern (anime_profile_controller → UOSC)
```lua
-- anime_profile_controller.lua broadcasts state
local state_json = utils.format_json({
    is_anime_context = true,
    anime_fidelity = true,
    mode_auto = true,
    anime4k_quality = "fast",
    -- ... more state keys
})
mp.commandv("script-message", "anime-state-broadcast", state_json)
```

```lua
-- uosc/main.lua receives and caches state
mp.register_script_message('anime-state-broadcast', function(json)
    local data = utils.parse_json(json)
    if data then
        for k, v in pairs(data) do
            anime_cache[k] = v
        end
    end
end)
```

#### Command Pattern (UOSC → anime_profile_controller)
```lua
-- User clicks menu item in UOSC
{ title = "Toggle Fidelity", value = "script-message toggle-anime-fidelity" }

-- anime_profile_controller.lua registers handler
mp.register_script_message("toggle-anime-fidelity", function()
    -- Toggle fidelity mode
    -- Update shader chains
    -- Broadcast new state
end)
```

### 2. Property Observation
Scripts watch MPV properties for reactive updates.

```lua
-- Track manual user changes
mp.observe_property("aid", "number", function(name, value)
    -- Detect manual audio track selection
end)

mp.observe_property("sid", "number", function(name, value)
    -- Detect manual subtitle track selection
end)
```

### 3. User Data Store
Scripts use `user-data` for cross-script state sharing.

```lua
-- Set state
mp.set_property("user-data/track-selector-enabled", "yes")

-- Read state
local enabled = mp.get_property("user-data/track-selector-enabled")
```

---

## 🎛️ Configuration Hierarchy

### Load Order (Bottom-to-Top Precedence)
```
1. mpv.conf                           # Base configuration
   ├─ [default] section
   ├─ [Platform-Windows-Base]
   ├─ [Platform-Linux-Base]
   └─ [cache], [SVP-*], etc.

2. mpv-<custom>.conf                  # Custom base overrides (untracked)
   └─ Loaded by custom-config-loader.lua
   └─ Only ONE mpv-*.conf allowed (fails if multiple)

3. Profile evaluation                 # Resolution/context profiles
   ├─ [Low-End] (battery mode)
   ├─ [SD-Anime], [HD-Anime], [FHD-Native]
   ├─ [4K-Anime], [8K-Hardware-Bypass]
   └─ Applied by anime_profile_controller.lua

4. Script option files                # Per-script configuration
   ├─ script-opts/uosc.conf
   ├─ script-opts/anime-mode.conf
   ├─ script-opts/anime4k.conf
   ├─ script-opts/youtube-download.conf
   └─ Read via opts.read_options()

5. user-*.conf files                  # Durable user overrides (untracked)
   └─ Loaded alphabetically via user_settings.lua
   └─ Survives git pulls and version updates
   └─ Written by UOSC Controls menu changes
```

### Configuration Module (`script-modules/user_config.lua`)
Provides centralized user override management:

```lua
local user_config = require("user_config")

-- Read all user-*.conf files
local settings = user_config.read()

-- Update a setting (writes to last user-*.conf or creates user-settings.conf)
user_config.update({
    ["tone-mapping"] = "bt.2390",
    ["target-peak"] = "1000"
})
```

---

## 🎯 Profile Evaluation Flow

### anime_profile_controller.lua Logic

```
┌─────────────────────────┐
│   file-loaded event     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Check anime_mode        │
│ • auto (detection)      │
│ • on (forced anime)     │
│ • off (forced live)     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ is_anime_context?       │
│ • Path: /anime/         │
│ • Audio: jpn,ja,jp      │
│ • Keywords: donghua     │
│ • Live override check   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Resolution tier?        │
│ • < 576p   → SD         │
│ • 720p     → HD         │
│ • 1080p    → FHD        │
│ • 1440p    → 2K         │
│ • 2160p    → 4K         │
│ • 4320p    → 8K         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ External constraints?   │
│ • Power saving active?  │
│ • HDR mode override?    │
│ • SVP detected?         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Apply profile           │
│ • Select shader chain   │
│ • Set scalers           │
│ • Configure filters     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Broadcast state to UOSC │
└─────────────────────────┘
```

---

## 🔐 State Synchronization

### anime_profile_controller State Keys
Broadcasted to UOSC and other listeners:

```lua
{
    -- Detection
    "is_anime_context"        -- boolean
    "mode_auto"               -- boolean
    "mode_on"                 -- boolean
    "mode_off"                -- boolean
    
    -- Resolution
    "resolution_tier"         -- "SD", "HD", "FHD", "2K", "4K", "8K"
    "current_profile"         -- Applied profile name
    
    -- Fidelity
    "anime_fidelity"          -- boolean (FSRCNNX vs Anime4K)
    "anime4k_allowed"         -- boolean (not locked by fidelity)
    
    -- Anime4K
    "anime4k_quality"         -- "fast", "hq", "ultra"
    "anime4k_fast"            -- boolean
    "anime4k_hq"              -- boolean
    "anime4k_ultra"           -- boolean
    "a4k_mode_a"              -- boolean
    "a4k_mode_b"              -- boolean
    "a4k_mode_c"              -- boolean
    "a4k_mode_aa"             -- boolean
    "a4k_mode_bb"             -- boolean
    "a4k_mode_ca"             -- boolean
    "a4k_mode_ani4kv2"        -- boolean
    "a4k_mode_anisd"          -- boolean
    
    -- Shaders
    "shaders_enabled"         -- boolean (master switch)
    "sharpen_enabled"         -- boolean
    "line_thinner_enabled"    -- boolean
    
    -- Audio
    "audio_only_mode"         -- "Auto", "Disabled"
    "spatial_active"          -- boolean
    "upmix_active"            -- boolean
    "night_mode_active"       -- boolean
    
    -- External
    "vsr_active"              -- boolean (from vsr_auto.lua)
    "power_saving"            -- boolean (from power_manager.lua)
    "hdr_mode"                -- string (from hdr_detect.lua)
    
    -- History
    "history_enabled"         -- boolean
}
```

---

## 🚨 Critical Invariants

### 1. Script Load Dependencies
- **anime_profile_controller.lua** must load before UOSC to ensure state is available
- **user_config.lua** module must be accessible to all scripts needing persistence

### 2. Event Handler Timing
- `file-loaded` handlers must complete before `video-reconfig`
- Track selection must finish before manual override detection begins

### 3. State Consistency
- UOSC menu state must reflect anime_profile_controller state
- Manual overrides must persist across file transitions
- Profile changes must trigger UOSC state updates

### 4. Profile Conflicts
- `[Low-End]` (power saving) overrides all other profiles
- User settings from `user-*.conf` apply after profile evaluation
- Manual property changes (via UOSC) persist to `user-*.conf`

---

## 📚 Related Documentation
- [Anime Profile Controller](02-anime-profile-controller.md) — Detection and profile logic
- [UOSC Custom UI](04-uosc-custom-ui.md) — UI state synchronization
- [Track Selector](07-track-selector.md) — Manual override lifecycle
- [Power Guard](05-power-guard-eco.md) — Eco mode profile ownership
- [Configuration Hierarchy](14-configuration-hierarchy.md) — Detailed config loading

---

## 🎯 Key Takeaways

1. **anime_profile_controller.lua is the master brain** — it orchestrates profiles, shaders, and state
2. **Script-messages are the communication backbone** — broadcast pattern for state, command pattern for actions
3. **user-*.conf files preserve user choices** — immune to git pulls and version updates
4. **UOSC reads state, anime_profile_controller owns state** — unidirectional data flow
5. **Event timing matters** — respect load order and event sequencing
