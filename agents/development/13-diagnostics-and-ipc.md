# Diagnostics, Overlays & IPC Sockets

## Overview
This document covers real-time diagnostic overlays (`scripts/stats_overlay.lua`, `scripts/show_status.lua`), timeline thumbnail generation (`scripts/thumbfast.lua`), and multi-instance IPC socket management (`scripts/mpvSockets.lua`).

---

## 📊 Diagnostics & Status Overlays

### 1. A/V Filter & Shaders Info (`k` Key)
- Triggered by pressing `k` (`script-message show-status-wrapped`).
- **Features**:
  - Displays formatted, color-coded table of active video filters, audio DSP filters, GLSL shader chains, and decoder status.
  - Implements smart word wrapping and resolution-aware OSD scaling to prevent text clipping on smaller or high-DPI screens.

### 2. "Neon Glass" Real-Time Stats Overlay (`CTRL+i`)
- Triggered by `CTRL+i` (`script-binding toggle-stats`).
- Displays live FPS, dropped frames, bitrate, VRAM usage, display sync drift, and hardware decoder performance.

### 3. Native MPV Stats (`i` and `I`)
- Standard MPV stats pages 1 through 4 (`stats/display-stats-toggle`).

---

## 🖼️ Timeline Thumbnail Generation (`thumbfast.lua`)

`scripts/thumbfast.lua` generates on-hover video thumbnails for the UOSC timeline.

### Software-Decoded Default (v5.2 Safety Fix)
* Shipped configuration uses `hwdec=no` (software decoding).
* **Why**: Hardware decoding in background thumbnail worker processes causes driver crashes, VRAM starvation, and stutter during active playback on NVIDIA and Intel GPUs. Software decoding is fast enough for low-resolution thumbnail frames and completely stable.

---

## 🔌 IPC Sockets & Multi-Instance Management (`mpvSockets.lua`)

Enables external integrations (SVP 4 Pro, Discord RPC, browser extensions, remote controls) to communicate with MPV via JSON IPC.

### Cross-Platform Implementation
* **Windows**: Uses Windows Named Pipes (`\\.\pipe\mpvSockets_<PID>`).
  - **CMD Flash Fix**: Named pipes avoid executing shell commands, preventing command-prompt window flashes when opening files.
* **Linux / Unix**: Creates per-process Unix domain sockets in `/tmp/mpvSockets/<PID>`.
  - Cleans up socket files cleanly upon player `shutdown` event.
