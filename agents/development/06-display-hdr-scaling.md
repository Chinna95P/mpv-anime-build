# Display, HDR & Hardware Scaling

## Overview
This document covers the HDR detection and tone-mapping subsystem (`scripts/hdr_detect.lua`), NVIDIA RTX Video Super Resolution integration (`scripts/vsr_auto.lua`), and MPV's native rendering baseline.

---

## 🌈 3-Way HDR Matrix Switch

MPV Anime Build implements a flexible 3-way HDR output pipeline:

```
┌─────────────────────────────────────────────────────────────┐
│                    HDR Display Mode                         │
├─────────────────────────────────────────────────────────────┤
│ 1. Auto (Detected)                                          │
│    ├─ Windows: DisplayConfig API / WMI                      │
│    ├─ Linux: KDE KScreen status check                       │
│    └─ Linux (Other): MPV native colorspace negotiation      │
│                                                             │
│ 2. HDR Display (Passthrough)                                │
│    └─ Forces target-colorspace-hint=yes & target-trc=auto   │
│                                                             │
│ 3. SDR Display (Tone-Mapping)                               │
│    └─ Forces target-colorspace-hint=no & target-trc=srgb    │
└─────────────────────────────────────────────────────────────┘
```

### OS HDR Detection Mechanisms

#### Windows Detection
Executes a specialized PowerShell script `windows_hdr_status.ps1` utilizing the Windows DisplayConfig API to verify if `AdvancedColorEnabled` is active on the display monitor.

#### Linux Detection
- **KDE Plasma**: Invokes `kscreen-doctor -o` to query display HDR status.
- **GNOME / Wayland / Other Compositors**: Safely defers to MPV's native Wayland color management protocols (`target-colorspace-hint=auto`).
- **Strict Isolation**: Windows scripts never run on Linux; Linux shell commands never execute on Windows.

### Tone-Mapping Curves (User Configurable)
Configured in `script-opts/hdr-mode.conf` and remembered in `user-*.conf`:
- `bt.2390` (Recommended default: EETF curve)
- `st2094-40` (Dynamic metadata tone-mapping)
- `st2094-10` (Adaptive metadata curve)
- `bt.2446a` (Static tone-mapping)
- `spline` (Neutral spline curve)
- `hable` / `mobius` / `reinhard`
- `clip` (Hard cut highlight clipping)

---

## ⚡ NVIDIA RTX VSR (Video Super Resolution)

`scripts/vsr_auto.lua` integrates NVIDIA's driver-level AI upscaling (`d3d11vpp=scaling-mode=nvidia`).

### Platform Lock
* **Windows Only**: Requires DirectX 11 backend (`d3d11va-copy` hardware decoder and `gpu-api=d3d11`).
* Linux systems cleanly ignore VSR commands without error popups.

### Adaptive Scaling Factor
Calculates the precise ratio between source video resolution and display resolution:
```lua
local scale_factor = math.max(1.0, math.min(4.0, display_height / video_height))
```
- E.g., Scales 720p to 4K at ~3.0x, but scales 1080p on a 1080p screen at 1.0x (avoiding redundant GPU overhead).

### 10-Bit Banding Prevention
Automatically requests `p010` pixel format for 10-bit/HDR content (and `nv12` for standard 8-bit SDR) to prevent color banding in anime gradients.

### Shader & Eco Coordination
- Engaging VSR automatically disables all GLSL shaders to prevent duplicate processing.
- When Power Guard enters Eco mode, VSR is disabled and its state is remembered for automatic restoration upon AC reconnection.

---

## ⚙️ Native Scalers Baseline

Configured in `mpv.conf` under `[default]` and platform profiles:
- `vo=gpu-next`
- `profile=high-quality`
- `dither=fruit`, `temporal-dither=yes`
- `sigmoid-upscaling=yes` (prevents edge ringing)
- `correct-downscaling=yes`
- `fbo-format=rgba16hf` (16-bit half-float framebuffers for high precision)
- `scale=spline64` (default native scaler for smooth, ringing-free edges)
