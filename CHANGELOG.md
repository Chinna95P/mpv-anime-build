# Changelog – MPV Anime Build

All notable changes to this project are documented here.

---

## [v1.4.1] – HDR Auto-Detection Hotfix

### 🐛 Fixed
* **HDR Auto-Detection Logic:** Rewrote `hdr_detect.lua` to safely handle generic SDR displays that report `nil` display parameters.
    * **SDR Users:** Fixed an issue where the script could fail silently or report errors on standard sRGB monitors.
    * **HDR Users:** Improved detection accuracy for Windows HDR mode by adding checks for `dci-p3` primaries and `hybrid-log-gamma`.
* **Startup Reliability:** Added a `vo-configured` listener to ensure HDR state is checked only after the video output is fully initialized.

---

## [v1.4] – The "Universal HDR & VSR" Update

### ✨ New Features
* **Universal HDR Automation:** Introduced `hdr_detect.lua` to automatically sync MPV with Windows.
    * **Windows HDR ON:** MPV switches to **Passthrough Mode** (sends metadata to TV).
    * **Windows HDR OFF:** MPV switches to **High-Quality Tone Mapping** (optimizes for SDR screens).
    * **Manual Override:** Added the **`H`** key to manually force Passthrough or Tone Mapping mode if the auto-detection fails.
* **Nvidia VSR Smart Lock:** Added `vsr_auto.lua` for RTX users.
    * **Manual Toggle:** Press **`V`** to enable/disable VSR. The script automatically handles safety checks.
    * **Smart Bit-Depth:** Automatically selects `p010` (10-bit) for HDR/Anime to prevent banding, and `nv12` (8-bit) for standard web content.
    * **Safety Check:** Prevents VSR activation on unsupported GPUs (Intel/AMD/GTX).
* **Dolby Vision Hybrid Fallback:**
    * If your display supports Dolby Vision, it passes through (via Windows HDR).
    * If not supported, it **automatically falls back to the HDR10 Base Layer**, ensuring perfect colors instead of a purple/green mess.
* **Manual Audio Bitstream:** Replaced unstable auto-detection with a manual "Panic Toggle" (**`A`** key).
    * **Default:** Internal Decoding + 7.1 Upmix (Best for headphones/analog).
    * **Passthrough:** Sends raw Bitstream (TrueHD/DTS-X) to AVR/Soundbar.

### 🐛 Fixed
* **SDR Stuttering:** Fixed micro-stutters on SDR monitors by disabling `target-colorspace-hint` by default. It now only activates when an HDR signal is detected from the OS.
* **Dolby Vision Error Spam:** Silenced harmless `ffmpeg/video` errors (Missing Slice / Invalid NALU) caused by Profile 7 Enhancement Layers.
* **4K Bottlenecks:** Forced `hwdec=d3d11va` (Native Zero-Copy) for HDR and VSR profiles to eliminate bus bandwidth issues on high-bitrate files.
* **Global Dithering:** Standardized on `dither=fruit` globally to save GPU headroom for VSR/Upscaling.

---

## [v1.3.2] – Subtitle Logic Hotfix

### 🐛 Fixed
* **Deprecated Command Replacement:** Replaced the non-functional `stretch-image-subs-to-screen` command (deprecated in newer MPV builds) with the modern `sub-ass-use-video-data` property.
    * **New 'y' Shortcut Behavior:** The `y` key now cycles between `none` → `aspect-ratio` → `all`.
    * **Impact:** Restores the ability to fix stretched or misaligned subtitles on the latest MPV versions where the old command was ignored.

---

## [v1.3.1] – Universal GPU Support Hotfix

### 🐛 Fixed
* **Universal Hardware Decoding:** Changed `hwdec` from `nvdec-copy` (NVIDIA specific) to `auto-copy`.
    * **Impact:** This restores proper hardware acceleration for **AMD and Intel GPU** users, who were previously forced into CPU decoding (laggy) because the config was hardcoded for NVIDIA.
    * **Note:** NVIDIA users are unaffected and will still use the best decoding method automatically.

---

## [v1.3] – Logic Lockdown & Stability Update

### ✨ New Features
* **Strict Resolution Gates:** Updated the core detection logic to adhere to strict broadcast standards:
    * **SD:** Strictly `< 576p` (activates `HQ-SD` profiles).
    * **HD:** `≥ 576p` and `< 1080p` (activates `HQ-HD` profiles).
    * **FHD+:** `≥ 1080p` (activates `High-Quality` native profiles).
* **Subtitle Correction Suite:**
    * **Text Subs:** Added `sub-ass-vsfilter-aspect-compat=no` to prevent `.ass` subtitles from stretching on anamorphic video.
    * **Image Subs:** Updated handling to fix distorted PGS/VobSub streams (toggleable with `y`).
* **Profile Isolation:** Manual toggles (`Q`, `Ctrl+Q`) are now context-aware. They will strictly refuse to execute if the playing video does not match their specific resolution tier, preventing accidental logic breaks.

### 🐛 Fixed
* **Thumbfast Subprocess Error:** Fixed intermittent `[thumbfast] subprocess create failed` errors on Windows by optimizing the socket pipe configuration and disabling `spawn_first`.
* **Logic Loophole (576p Conflict):** Fixed a bug where 576p-719p content was correctly detected as "SD" by the autoloader but incorrectly allowed "HD" manual toggles to fire, causing OSD conflicts.
* **Ghost Toggles:** Fixed an issue where the `Q` key would trigger "HD Logic" messages even when playing 1080p+ content.

### 🗑️ Removed
* **'W' Keybinding:** Removed the "Reset HD Logic" command. It is no longer needed as the `Q` key now functions as a smart toggle (Auto ↔ Manual), and logic automatically resets on file load.

---

## [v1.2] – The "Color Update" & Modernization

### ✨ New Features
- **Professional OSD Overlay:** Completely rewrote the OSD backend (`anime_profile_controller.lua` v1.6) using the `mp.create_osd_overlay` API.
  - **Color-Coded Status:**
    - **Anime Mode:** Auto (Green), On (Blue), Off (Red).
    - **Live Action:** High-Quality (Cyan), NNEDI3 (Gold), SD (Orange).
    - **Anime4K:** Magenta.
- **ModernZ Skin:** Integrated the "ModernZ" skin for a cleaner, modern player interface.
- **SVP 4 Pro Support:** Verified compatibility and safety with Smooth Video Project (SVP 4).
- **System Requirements:** Added official minimum and recommended specs to the documentation.

### 🐛 Fixed
- **OSD White Text Bug:** Fixed an issue where manual toggles (`Q`, `W`, `Ctrl+Q`) displayed plain white text instead of color codes.
- **Pattern Matching Error:** Fixed a Lua bug where profiles containing hyphens (e.g., `HQ-SD-Clean`) were not being colored correctly in the status message.
- **Input Conflicts:** Resolved conflicts where `input.conf` text commands were overriding the script's graphical overlay.

---

## [v1.1] – Visual Refinement Update

### ✨ New Features
- **"Modern TV" Upscaling:** Added custom shader configurations (`adaptive-sharpen-modern-*.glsl`) to replicate high-end TV processing (Sony Reality Creation style) for 480p, 720p, and 1080p.
- **Smart Logic Update:** Added handlers for manual Live-Action toggles (`toggle-hq-sd`, `toggle-hq-hd-nnedi`) which were previously missing from the Lua script.
- **Visual Polish:** Added Film Grain and Dithering to High-Quality profiles for a more organic, cinematic look.

### 🐛 Fixed
- **Shader Compilation Errors:** Fixed `HOOKED : undeclared identifier` errors in `adaptive-sharpen-soft.glsl` by correcting the header definitions.
- **Logic Gaps:** Fixed an issue where shortcuts `Q`, `W`, and `Ctrl+Q` would not trigger their respective profiles in the Lua controller.
- **MPV Config:** Optimized `video-sync` and `interpolation` settings for smoother frame pacing on Windows 11.