# MPV Anime Build - Development & Architecture Guide

## Project Overview

**MPV Anime Build** is an advanced, context-aware MPV media player configuration featuring AI upscaling, dynamic power management, universal HDR support, intelligent audio processing, and a heavily customized UOSC interface.

- **Author**: Chinna95P
- **Current Version**: v5.4 (source of truth: `script-opts/build_info.conf`)
- **Repository**: https://github.com/Chinna95P/mpv-anime-build
- **Local Path**: `/var/mnt/Games/MPV/mpv-anime-build/`

## Critical Development Rules

### Git Rules
- **NEVER commit automatically**
- **NEVER push automatically**
- **NEVER reset, rebase, or checkout** without explicit instructions
- Inspect `git status` before making changes
- Show `git diff` after modifications for user review
- The user prefers to test changes locally before committing

### Core Architecture & High-Risk Components

1. **`anime_profile_controller.lua`** (High Risk)
   - Controls anime vs live-action detection, resolution tiers, shader chains, profile switching, and UOSC state sync
   - Understand state flow and all callers before modifying
   - Preserve public script-message interfaces and state keys

2. **`scripts/uosc/main.lua`** (High Risk)
   - Heavily customized UOSC v5.13.0 implementation
   - **Never replace with upstream blindly**
   - Contains custom menus, history, denoise, shader controls, HDR controls, audio-only, download integration, and chapter highlighting
   - Upgrades require a careful three-way merge

3. **`track-selector.lua`**
   - Smart audio/subtitle track selection
   - Manual track overrides persist per-session across playlist navigation
   - Do not reset `manual_override` on `file-loaded`

4. **`power_manager.lua`**
   - Cross-platform battery monitoring (PowerShell/CIM on Windows, sysfs on Linux)
   - Switches to low-end profile on battery, restores previous decoder on AC power
   - Safe desktop fallback (manual toggle only)

5. **Shaders (`shaders/`)**
   - Preserve filenames, ordering, and directory layout
   - Resolution-specific shader chains (SD, HD, FHD, 4K, 8K)
   - Test at relevant resolutions after any modification

### Configuration Hierarchy

1. Shipped base configuration: `mpv.conf` (tracked)
2. Personal option override: `mpv-<custom-name>.conf` (untracked, loaded after `mpv.conf`, exactly one file allowed)
3. UI remembered settings: `user-<custom-name>.conf` (untracked, loaded alphabetically)
4. Keybindings: `input.conf` (coupled to Lua scripts)
5. Script settings: `script-opts/*.conf`

### Skip Intro & Chapter Colors (v5.3 Palette)

- **Intro**: `#FF00FF` (Magenta) | ASS BGR: `FF00FF`
- **OP**: `#00FF00` (Green) | ASS BGR: `00FF00`
- **PV**: `#FF9900` (Orange) | ASS BGR: `0099FF`
- **ED**: `#0080FF` (Blue) | ASS BGR: `FF8000`

### Key Keybindings

| Key | Action |
|---|---|
| `K` | Show Profile / Shader Info overlay |
| `I` | Show Technical Stats overlay |
| `A` | Audio Mode toggle (7.1 Upmix vs Passthrough) |
| `H` | HDR Mode toggle (Passthrough vs Tone Mapping) |
| `V` | RTX Video Super Resolution toggle (Windows) |
| `Q` | Master Upscaler toggle (NNEDI3 vs FSRCNNX) |
| `L` | Anime4K Quality toggle (Fast vs HQ) |
| `CTRL+g` | Master Shader Killswitch |
| `CTRL+p` | Power Saving Mode toggle |
| `CTRL+l` / `CTRL+;` / `CTRL+'` | Anime Mode: Auto / On / Off |
| `F5` / `F6` | Window Screenshot / Clean Video-Frame Screenshot |
| `CTRL+f` / `CTRL+F` | Subtitle Lines Search (Primary / Secondary) |

## Change Workflow

1. Inspect relevant files, callers, and configuration bindings
2. Explain the planned approach to the user
3. Make minimal, targeted changes
4. Validate (syntax check, local test)
5. Present `git diff` and summary
6. Wait for explicit user instruction before committing or pushing
