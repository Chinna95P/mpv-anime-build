# Changelog – MPV Anime Build

All notable changes to this project are documented here.

---

## [v5.0] – Cross-Platform HDR, Durable User Overrides & Community Fixes

### ✨ New Features & Enhancements
* **Cross-Platform HDR Auto Detection:** Windows now reads active-display HDR state through the DisplayConfig API with a WMI compatibility fallback. KDE Plasma reads active output state through KScreen, while other Linux compositors defer to mpv's native colorspace negotiation.
* **Strict Platform Isolation:** Windows never launches Linux HDR helpers, Linux never launches PowerShell, and manual HDR/SDR modes bypass OS detection entirely.
* **Durable User Overrides:** Settings changed through UOSC Controls, including HDR mode, target peak, and tone-mapping selection, persist in update-safe `user-<custom-name>.conf` files.
* **Clear Anime FSRCNNX Naming:** Renamed the adjacent Anime shaders to `FSRCNNX_x2_16-0-4-1_anime_mild.glsl` and `FSRCNNX_x2_16-0-4-1_anime_aggressive.glsl`. Existing saved paths are migrated automatically.
* **Clean Shared Script Options:** Removed tracked per-user Anime, Anime4K, HDR, and equalizer state files. Scripts retain safe built-in defaults and recreate personal files locally when settings change.

### 🐛 Fixed
* **HDR Output Processing:** HDR display output now honors the selected tone-mapping curve instead of forcing `clip`, and the HDR menu remains usable during HDR output.
* **Startup Profile Conditions:** Made SVP, HDR, and 8K conditions safe while height and HDR metadata are temporarily unavailable.
* **Disabled Track Overrides:** Restoring saved disabled audio or subtitle selections no longer passes incomplete records into the track matcher.
* **Linux Peripheral Batteries:** Wireless mouse, keyboard, and headset batteries with `scope=Device` no longer make desktops enter `[Low-End]`; system batteries and older drivers remain supported.

### 🙏 Community
* Thanks to **dovahkinGH** for the HDR, remembered-settings, and track-selector reports and testing, and to **francomeisterm** for the Linux battery report and clearer Anime FSRCNNX naming suggestion.

---

## [v4.9] – Cross-Platform Power Guard, Smoother Scaling & Profile Clarity

### ✨ New Features & Enhancements
* **Cross-Platform Power Guard:** Reworked `power_manager.lua` to automatically support both **Windows and Linux** without requiring separate scripts or manual platform-specific edits. Windows battery monitoring now uses modern PowerShell/CIM detection, while Linux reads battery and charging status directly from the system power-supply interface.
* **Smart Desktop and Laptop Detection:** Battery-equipped laptops continue to switch automatically between normal and `[Low-End]` modes, while desktop systems cleanly use **Manual Toggle Only** mode without generating failed-subprocess warnings.
* **Safe Hardware Decoder Restoration:** Power Guard now remembers the active hardware-decoding configuration before entering Eco mode and restores it afterward. This preserves D3D11VA on Windows and NVDEC, VA-API, Vulkan, or SVP copy-back decoding on Linux without forcing an incompatible decoder.
* **High-Quality Rendering Baseline:** Enabled MPV's built-in `high-quality` profile as the global rendering foundation while retaining the build's resolution-aware shader and processing logic.
* **Smoother Anime Scaling:** Changed the Anime profile's native scaler from `ewa_lanczossharp` to `spline64` and removed the forced anti-ringing/radius overrides, producing smoother edges with less aggressive ringing.
* **FHD Profile and OSD Clarity:** Renamed the custom `[High-Quality]` profile to `[FHD-Native]` and updated controller state detection, profile evaluation, menus, and OSD labels to clearly distinguish it from MPV's built-in `high-quality` profile.
* **Video-Only Screenshot Shortcut:** Added `F6` for clean video-frame screenshots, complementing the existing `F5` window screenshot shortcut.

### 🐛 Fixed
* **Linux Power Manager Warning:** Fixed the recurring `[power_manager] Subprocess failed: init` warning caused by attempting to run Windows PowerShell battery checks on Linux.
* **Cross-Platform Decoder Override:** Fixed Power Guard restoration forcing `d3d11va` or `auto-copy` regardless of the operating system, which could interfere with native Linux hardware decoding or unexpectedly switch playback to copy-back decoding.
* **Power Mode State Handling:** Added explicit Eco-mode state tracking to prevent repeated profile application and ensure the correct decoder is restored when leaving power-saving mode.

---

## [v4.8] – UOSC File Browser, Controller Optimization & Track Selector Refinement

### ✨ New Features & Enhancements
* **Anime Profile Controller Optimization:** Optimized `anime_profile_controller.lua` and `main.lua` to reduce unnecessary work, improve state handling, and fix minor UI/logic bugs without changing the build's core profile behavior.
* **UOSC Open-File Control:** Added a dedicated **Open File** button to the UOSC controls bar. It opens UOSC's native file-selection menu directly from the player, making video/audio selection available without relying on the operating system's file dialog.
* **Video/Audio-Only File Browser:** The Open File menu is configured to show only supported **video and audio** files. Poster, backdrop, thumbnail, and other image assets can be excluded through the UOSC `image_types` configuration.
* **UOSC Behavior Refinements:** Adjusted several UOSC behaviors and menu interactions to make the interface more consistent with the MPV Anime Build workflow.
* **Track Selector Refinement:** Updated `track-selector.lua` with fixes and behavior refinements made during the v4.8 development cycle, improving track-selection reliability while preserving the build's manual-selection/override workflow.

### ⚙️ Configuration Note
For users maintaining a custom `uosc.conf`, the Open File browser can be restricted with:

```ini
load_types=video,audio
show_hidden_files=no
image_types=
```

This keeps normal video/audio selection available while preventing poster and other image files from appearing in the Open File menu.

---

## [v4.7] – UOSC 5.13, Stream Downloads, Visualizer Expansion & Smoothed Processing

### ✨ New Features & Enhancements
* **Resolution-Tuned Adaptive Sharpen & Anime Line-Thinner:** Adjusted adaptive-sharpen and Anime-Line-Thinner strengths across resolution tiers to produce smoother, more soothing edges while preserving detail in both Anime and Live-Action content. Background textures and subject detail are enhanced without pushing edges into an overly harsh look.
* **Working Stream Download Button:** Added the [`mpv-youtube-download`](https://github.com/cvzi/mpv-youtube-download) script and bound its functionality to the UOSC **Download** button, restoring stream downloads directly from the player. Downloads are saved to `~/ytdl` by default; the destination can be changed in `youtube-download.conf`.
* **Windows CMD Flash Fix:** Updated `mpvSockets.lua` to eliminate command-window flashes on Windows when socket-based commands are executed.
* **Expanded Audio-Only Visualizers:** Added new visualizer styles to the Audio-Only profile for more visual variety during music playback.
* **UOSC 5.13.0:** Updated the integrated UOSC interface to the latest 5.13.0 release while preserving the MPV Anime Build custom controls and menu integration.
* **Color-Coded UOSC Chapter Timeline:** Added custom transparent timeline highlights for detected **OP, ED, PV, and Intro** chapter names. The colors match the Skip Intro palette:
  * 🟢 **OP:** `#00FF00`
  * 🟠 **ED:** `#FF8000`
  * 🟣 **PV:** `#FF00FF`
  * 🔵 **Intro:** `#0099FF`
* **Track Selector Resume Override:** Extended the Track Selector manual-override system so the override is persisted per video. When the same video is resumed in a later MPV session, the saved override is restored; once active, it remains in effect for the rest of that session/playlist, including next/previous files.

---

## [v4.6] – Strict Detection, Smart Overrides & FSRCNNX Fidelity Overhaul

### ✨ New Features & Enhancements
* **Smart Track Override:** The Track Selector script now features manual intervention detection. If you manually change an audio or subtitle track during playback, the script immediately enters a "Manual Override" state and suspends auto-selection for the remainder of the session/playlist to respect your choices.
* **Strict Anime Auto-Detection:** Hardened the metadata parser to eliminate false positives on Live-Action files. Filenames with single brackets (e.g., `[2024] Movie.mkv`) are no longer falsely flagged as anime. The engine now mandates strict scene release syntax (must have a prefix bracket AND a suffix hash bracket or episode dash).
* **FSRCNNX Pipeline Overhaul (Anime Fidelity Mode):** Rebuilt the FSRCNNX shader chains across all resolution tiers to act as a complete restoration pipeline. Natively injected `Anime4K Restore` to handle anti-aliasing/artifact removal, alongside `Anime-Line-Thinner` for precise line art and detail enhancement.

---

## [v4.5] – History Suite, Line-Thinner Shaders & Adaptive Sharpen Polish

### ✨ New Features & Enhancements
* **Native Watch History Engine:** Added a robust local tracking system that logs up to the last 50 played files into a persistent `uosc_history.json` store.
* **Visual Progress & Status Indicators:** Integrated a 10-block visual progress bar (`■■■■□□□□□□`) and percentage indicators into history menu items, with automatic **"Watched"** checkmarks once completion exceeds **95%** (alongside automated entry muting/grey-out).
* **Dedicated History Control Button:** Added a single-click history menu shortcut directly to the UOSC bottom control bar (`uosc.conf`).
* **Resolution-Aware Anime Line-Thinner Suite:** Bound separate custom Morphological Line-Thinner shaders (`SD`, `HD`, `FHD`, `4K`) dynamically into the FSRCNNX upscale chain with state persistence and a master toggle (`Ctrl+j`).
* **Contextual Safety Lockdown:** Added smart validation ensuring the Line-Thinner toggle only works when both Anime Mode and Fidelity Mode (FSRCNNX) are active, locking out and warning users in Live-Action or Anime4K modes.
* **Refined Adaptive Sharpening:** Fine-tuned adaptive-sharpen strength parameters across all resolution tiers for crisp edge definition without white ringing artifacts.

---

## [v4.4] – Performance Optimization & UI Sync

### ✨ New Features & Tweaks
* **ArtCNN Performance Optimization:** Replaced the heavy Compute (`_CMP`) versions of the Ani4Kv2 and AniSD ArtCNN shaders in the `HQ` tier with their highly-optimized fragment iteration counterparts (`_i2` and `_i4`). This eliminates frame drops and audio desync on mid-range GPUs while maintaining 99% of the visual quality.
* **UOSC Menu Reorganization:** Logically restructured the UOSC right-click and on-screen menus. Shifted the *Anime Mode Toggle* and *Anime4K Quality* options out of the *Fidelity & Restoration* sub-menu directly into the primary *Anime Mode* sub-menu for faster access.

### 🐛 Fixed
* **Fidelity Mode Lock Bypass:** Fixed a bug where clicking an Anime4K profile while Anime Fidelity Mode (FSRCNNX) was active would silently apply the shader in the background. The system now correctly intercepts the command, blocks the shader application, and displays a red `Locked: Switch to Anime4K Mode to use.` OSD warning.
* **Dual-Menu Sync Bug:** Fixed an issue where the right-click UOSC context menu was caching an older layout than the main on-screen Anime menu. Both menus are now perfectly synchronized in `main.lua` and the controller script.

---

## [v4.3] – Audio-Only Profile Fix & Control Update

### ✨ New Features
* **Audio-Only Profile Control:** Added a new toggle in the UOSC menu and Anime Mode Button (under `Audio & HDR`) to manually control the Audio-Only battery-saving profile. You can now switch between `Auto` (default smart detection) and `Disable` (forces the player to treat all media as standard video).
* **Smart Status Overlay:** Completely rewritten the status display logic (triggered by `k`).
  * **Native Data Parsing:** Now uses MPV's native tables to extract filter/shader data, eliminating artifacting symbols (like `%30%`) and ensuring the full, original configuration is displayed.
  * **Categorized Color-Coding:** Audio filters, Video filters, and Shaders now use distinct color-coded headers for immediate visual identification.
  * **Intelligent Wrapping:** Added automatic text wrapping and indentation logic so long shader paths or complex filter chains remain perfectly organized and readable without screen overflow.

### 🐛 Fixed
* **iGPU Race Condition Fix:** Fixed a critical bug affecting users with integrated graphics or slower CPUs where video files (MKV, MP4) were incorrectly flagged as audio files. Implemented a smart deferral check that waits for the demuxer to fully populate the track list before evaluating the media type.

---

## [v4.2] – The "Anime4K Ultra" Update

### ✨ New Features
* **Anime4K Ultra Tier Integration:** 
  * Upgraded the Anime4K pipeline to include the highly optimized **Anime4K-Ultra** shaders by **Th-Underscore**. This bypasses the old modular chains in favor of unified, single-pass shaders for superior performance, line thinning, and de-aliasing.
  * The "Anime4K Quality" toggle has been upgraded to a **3-tier Sub-Menu**: `Fast` (Performance), `HQ` (High Quality), and the new `Ultra` (Th-Underscore).
* **Dynamic Menu Labels:** The UOSC "Anime4K Profiles" menu now dynamically updates its text descriptions based on the active quality tier (e.g., Mode A+A automatically relabels to "DbL Recommended" when Ultra is active).
* **Seamless Cycling:** The `L` keybinding has been updated to smoothly cycle through `Fast -> HQ -> Ultra -> Fast` without needing to open the menu.

### 🔧 Credits
* **Th-Underscore:** Added to the credits for their incredible work on the unified Anime4K-Ultra shader variants.

---

## [v4.1] – The "Resolution-Aware Fidelity" Update

### ✨ New Features
* **Resolution-Aware Engine Persistence:** 
  * The Fidelity (`FSRCNNX`) vs. Performance (`Anime4K`) toggle is no longer a single global setting.
  * The build now tracks and remembers your preference **independently per resolution tier** (`SD`, `HD`, `FHD`, `2K`, `4K`, `8K`). You can now automatically use pure FSRCNNX line processing for 1080p Blu-rays while keeping aggressive Anime4K upscaling active for 720p streams.
* **ArtCNN Compute Profiling:** Reworked the `Ani4Kv2` and `AniSD` shader pipelines. Selecting **Fast Quality** now uses standard general loops, while **HQ Quality** leverages your GPU's parallel hardware by triggering dedicated Compute shaders (`*_CMP.glsl`).
* **Direct ArtCNN Hotkeys:** Added dedicated `input.conf` shortcuts (`CTRL+7` and `CTRL+8`) to instantly swap to the new ArtCNN models without opening the UOSC menu.

### ⚡ Telemetry & Logic Fixes
* **Streamlined HDR Gate Optimization:** Completely overhauled the `hdr_detect.lua` execution flow. Heavy OS-level color parameter tracking and PowerShell/WMI scanning are now locked strictly inside the `Auto` logic gate. When explicitly switching to **HDR Display** or **SDR Display** mode, the script skips background OS checks entirely to eliminate micro-stutters and ensure optimal frame delivery.
* **Stats Overlay Sync:** Updated the Neon Glass overlay to accurately read and display the new per-resolution fidelity states dynamically.

---

## [v4.0] – The "ArtCNN & Display Engine" Update

### ✨ New Features
* **Next-Gen ArtCNN Upscaling:** * Added cutting-edge **Ani4Kv2** and **AniSD** (ArtCNN) neural network shaders to the Anime4K profiles list. These provide superior artifact removal and upscaling quality compared to the legacy variants.
* **3-Way HDR Display Switch:** * Replaced the binary Auto/Manual HDR toggle with a robust 3-way system: **Auto**, **HDR Display (Passthrough)**, and **SDR Display (Tone-Map)**. This permanently solves issues where Windows auto-detection fails, allowing users to safely lock in their specific display type.
* **Interactive Subtitle Styling:** * Added a dedicated "Subtitles Styling" menu directly into the UOSC Controls menu, allowing on-the-fly customization of subtitle appearance without editing config files.
* **Global Volume Control:** * Added mouse-wheel support to `input.conf`. Scrolling up or down anywhere on the video screen now adjusts the volume and triggers the modern UOSC volume flash UI.

### ⚡ Performance & Logic
* **NVIDIA Hardware Decoding Priority:** * Updated the Windows Base profile in `mpv.conf` (`hwdec=nvdec,vulkan,auto` and `gpu-context=winvk,auto`). This explicitly prioritizes NVIDIA's highly efficient `nvdec` decoder over standard Vulkan decoding for RTX/GTX users, while maintaining safe fallbacks for AMD/Intel.

---

## [v3.2] – The "Resolution-Aware Anime4K" Update

### ✨ New Features
* **Smart Anime4K Persistence:**
  * Anime4K quality ("fast" vs "hq") and mode (A, B, C, AA, BB, CA) settings are no longer a single global toggle. 
  * The build now remembers your exact Anime4K preference **independently per resolution tier** (SD, HD, FHD, 2K, 4K, 8K). If you prefer "Mode B" for 720p and "Mode A+A" for 1080p, the script will automatically swap between them on the fly.

### ⚡ Improvements & Fixes
* **UOSC Menu Synchronization:** Fixed a visual desync where the UOSC right-click menu failed to highlight the currently active Anime4K profile. The state broadcaster (`sync_state`) was updated to fetch the dynamically evaluated resolution mode instead of relying on deprecated global variables.
* **Seamless Config Migration:** Re-wrote the `anime4k.conf` load/save logic to automatically catch and migrate your old global settings into the new resolution-aware format upon the first launch, ensuring no settings are lost.
* **Lua Execution Order:** Fixed an initialization crash caused by top-down execution logic regarding the `get_resolution_mode` helper function being called before it was defined.

---

## [v3.1] – The "Cross-Platform & Denoise" Update

### ✨ New Features

* **Interactive Denoise Filter (`hqdn3d`):**
  * Added a dedicated Denoise control suite to the UOSC Controls menu.
  * You can now toggle the filter on/off and independently adjust Luma Spatial, Chroma Spatial, Luma Temporal, and Chroma Temporal values directly from the UI.
  * **Smart Hardware Fallback:** CPU-based filters (like Denoise) crash when using strict GPU decoders (like `vulkan`). The script now acts as a safety net—it automatically forces `auto-copy` when you turn Denoise on, and perfectly restores your original `hwdec` setting when you turn it off.

* **Smart Track Selector Fallbacks:**
  * **Any-Language Fallbacks:** The `track-selector.lua` script now intelligently handles files with missing language metadata.
  * **Dialogue Priority:** If your preferred languages aren't found, it will automatically search for tracks labeled "Full" or "Dialogue" to prevent accidentally falling back to "Signs/Songs" tracks.
  * **Last Resort Match:** It will gracefully prioritize the muxer's native `default` flag, or cleanly pick the first valid subtitle track while still actively ignoring hardcoded junk (ignoring forced, SDH, or signs).

### ⚡ Performance & Logic

* **Linux Parsing Fix (Robust Shader Chains):**
  * **The Bug:** On certain Linux distributions, passing a long, semicolon-separated string of shaders to MPV via the `set` command fails to parse correctly, causing shaders to break.
  * **The Fix:** Completely rewrote the shader execution engine. The Lua script now parses the config strings (handling both semicolons and MPV's native commas) and uses `append` to inject each shader individually. This guarantees 100% cross-platform compatibility across Windows and Linux.
* **UI Race Condition Eliminated:**
  * Fixed an issue where the UOSC menu would visually "lag" behind internal state changes (requiring you to close and reopen the menu to see updated values). 
  * The menu updater now uses a microscopic 50ms async timeout, giving MPV's internal queue enough time to process math before redrawing the interface. 
* **Execution Order Correction:**
  * Fixed a logic gap in the `evaluate()` function where Live Action profiles (which trigger `apply_fsrcnnx()`) were accidentally executing *after* the post-processing engine. This caused the Adaptive Sharpen toggle to be overridden. The order of operations is now strictly enforced. 

---

## [v3.0] – The "Performance & Audio" Update

### ✨ New Features

* **Audio-Only Profile:**
* Added a dedicated `[Audio-Only]` profile specifically for music and audio playback.
* **Zero Overhead:** Automatically disables heavy video shaders, scaling algorithms, and hardware decoding to minimize CPU/GPU usage.
* **Visuals:** Features built-in support for audio visualizers and natively displays embedded album art.

* **Ambient Crop Shader:**
* Introduced a new Ambient Crop button/shader version for a highly immersive viewing experience that fills the screen with ambient colors.
* > **⚠️ Note for SVP Users:** You do not need to enable this shader! Instead, use SVP's dedicated "Fill black bars" feature to achieve a similar effect natively alongside motion interpolation.

* **Picture-in-Picture (PIP) Mode:**
* Added a dedicated PIP toggle, allowing you to seamlessly pop the video out into a floating window for multitasking.

* **On-the-Fly Equalizer:**
* Added a new Equalizer button to the interface, giving you instant access to fine-tune your audio frequencies without leaving the player.

### ⚡ Performance & Logic

* **8K Optimized Mode:**
* The build now automatically detects massive 8K resolution files.
* When triggered, it instantly applies the `[8K-Optimized]` profile, bypassing all heavy upscaling shaders (like Anime4K or FSRCNNX) to ensure smooth, hardware-accelerated playback and prevent GPU crashes.

* **Core Performance Optimizations:**
* Refined the underlying controller scripts and evaluation logic. The build now transitions between states faster and handles startup routines with significantly less overhead.

### 🎨 UI & Menus

* **Complete Menu Overhaul:**
* The UOSC menu has been heavily reorganized and expanded to accommodate all the new features. 
* The layout is now cleaner and groups the new PIP, Ambient, and Equalizer options into intuitive, easy-to-reach submenus.

---

## [v2.3] – The "Visuals & Performance" Update

### 🔥 Critical Fixes

* **"Infinite Wait" / Startup Deadlock:**
* **The Issue:** Fixed a race condition where the Audio Engine (`evaluate_audio`) and Video Engine (`evaluate`) tried to initialize simultaneously at startup. Because `video-sync=audio` was enabled, resetting the audio clock while the video was waiting for it caused the player to freeze at 00:00.
* **The Fix:** Audio profiles now load **immediately** (synchronously) upon file load, while heavy video shaders are slightly delayed (0.1s). This ensures the audio clock is stable before the GPU begins processing.

* **Subtitle Pre-roll Hang:**
* Disabled `demuxer-mkv-subtitle-preroll` in `mpv.conf`. This prevents MPV from stalling while scanning for subtitles in files with complex muxing or delayed subtitle tracks.

### ✨ Visual Improvements

* **New Shader: SSimDownscaler:**
* Added `SSimDownscaler.glsl` (Structural Similarity Downscaling) to the shader chain.
* **Benefit:** When content is upscaled (supersampled) by FSRCNNX/NNEDI3 and then clamped back to your screen size, SSimDownscaler preserves perceptual details better than standard `mitchell` or `lanczos`, significantly reducing ringing artifacts.


* **Optimized Shader Chain Order:**
* Re-ordered the processing pipeline for maximum efficiency and quality:
`Upscaler (FSR/NNEDI)` → `KrigBilateral` → `SSimSuperRes` → **`SSimDownscaler`** → `Adaptive Sharpen`.

### ⚡ Performance & Logic

* **Skip Intro Optimization (Caching):**
* **Previous:** The script queried the internal chapter list 10 times every second, causing unnecessary CPU overhead.
* **New:** The chapter list is now read **once** when the file loads and cached. The tick loop now only compares timestamps, resulting in near-zero CPU usage.

* **Up Next "Clean Mode" Parsing:**
* Rewrote the text cleaner regex for the "Up Next" card. It now intelligently strips:
* Release Group tags (`-YURASUKA`, `[SubsPlease]`).
* Tech specs (`1080p`, `10-Bit`, `FLAC2.0`, `x265`).
* Dots replacement (`Grand.Blue` → `Grand Blue`).

* **Result:** You get a clean Title and Episode number even if the file lacks metadata.

* **Startup Safety:** Added a safety delay (5 seconds) to the "Up Next" script to prevent it from scanning the playlist before the current file has fully initialized.

### 🧠 Smart Features

* **Menu Integration:**
* The "Up Next" and "Skip Intro" cards now listen for state toggles from the UOSC Menu immediately. You can enable/disable them mid-video without needing to restart the player.

---

## [v2.2.2] – The "Smart & Interactive" Update

### ✨ New Features
* **Up Next Notification:** Introduced `Up_Next.lua`, a new smart overlay that displays the next file in your playlist 10 seconds before the current one ends.
    * **Interactive:** Fully clickable (mouse support) for instant skipping.
    * **Zero-Lag:** Uses internal playlist data instead of disk scanning for instant performance.
    * **Menu Toggle:** Can be enabled/disabled via the new "Smart Features" menu.
* **Interactive Skip Intro:** Updated `skip_intro.lua` to support mouse hovering and clicking.
* **Smart Feature Menu:** Added a new submenu in **Anime Build Options** to toggle "Auto Skip" and "Up Next" features without editing files.

### 🧠 Logic Improvements
* **3D Animation Support:** Added `donghua`, `cartoon`, and `3d_anime` to the Anime auto-detection logic. These now correctly trigger the **Anime Profile** (Clean Upscaling) instead of falling back to Live Action.
* **Live Action Override:** Refined detection to check both Folder Path and Filename for "Live Action" keywords, preventing false positives on Anime Movies.

### 🔧 Credits
* **Up Next Script:** Core logic adapted from the original script by **@WaruiDevil** (Telegram).

---

## [v2.2.1] – The "Spatial Audio & Android" Update

### ✨ New Features
* **Spatial Audio Mode:**
    * **Virtual Surround:** Added a new audio profile `Cinema-Spatial` designed for headphones. It uses HRTF-based virtual surround to simulate a 7.1 cinema experience.
    * **Toggle:** Switch instantly between **Standard Stereo** and **Spatial Audio** via the Audio menu.
* **Android Build Release:**
    * **Mobile Optimized:** Officially released the **mpvEX Android Config** (available on the [`android`](https://github.com/Chinna95P/mpv-anime-build/tree/android) branch).
    * **Features:** Includes Auto-Detection, Smart Shaders, and Gesture-based UI ported specifically for mobile devices.

---

## [v2.2] – The "Logic & Swapper" Update

### ✨ New Features
* **Shader Swapper Menus:**
    * **Instant Switching:** You can now swap specific shader variants on the fly via the Menu (e.g., Switch FSRCNNX from *Anime Mild* to *LineArt*, or NNEDI3 from *64-Neurons* to *256-Neurons*).
    * **Context Aware:** The menu automatically shows valid options for your current content (Anime vs. Live Action).
* **Split Live-Action Logic:**
    * **SD Content:** Toggle between **NNEDI3** (Clean/Texture) and **FSRCNNX** (Sharp) independently.
    * **HD Content:** Toggle between **NNEDI3** (Geometry focus) and **FSRCNNX** (Detail focus) independently.
    * **Memory:** The build remembers your choice for SD and HD separately.
* **Advanced Motion Control:**
    * **Video Sync Menu:** New menu to toggle between `Audio` (Default), `Display Resample` (Smooth Motion), `Vdrop`, and `Desync`.
    * **Temporal Scaler:** New menu to select the interpolation algorithm (e.g., `Oversample` for sharpness, `Sphinx` for balance).
    * **Automation:** Enabling Interpolation now automatically forces `display-resample` mode to prevent stutter.

### ⚡ Improvements
* **Stats Overlay v2.1:**
    * **Target Resolution:** The overlay now calculates the *actual* video area inside black bars (e.g., `1440x1080` on a 16:9 screen) instead of just showing the window size.
    * **Detailed Identification:** Explicitly names the active variant (e.g., `"FSRCNNX 16 (Anime Mild)"` vs `"FSRCNNX 8 (LineArt)"`).
* **Menu Logic:** Renamed "SD Upscaler" to **"SD Mode (NNEDI)"** and "HD Upscaler" to **"SD/HD Logic"** to better reflect their function. Checks are now based on the active profile name for 100% accuracy.

---

## [v2.1] – The "Sharpen & Safety" Update

### ✨ New Features
* **Adaptive Sharpen Toggle:** * Users can now manually enable or disable the `adaptive-sharpen` shaders independently.
    * Integrated a new toggle option directly into the **Anime Mode Button** and the **uosc Anime Build Options** menu.
    * Added **`CTRL+k`** as the dedicated keyboard shortcut for this toggle.
* **Visual Status Indicator ✨:** * A "Sparkle" emoji ✨ now appears in the Profile OSD when sharpening is active.
    * The icon is context-aware and automatically hides when using **Anime4K**, as it does not use the adaptive-sharpen shaders.

### ⚡ Improvements
* **Safety Lockdown & Efficiency:** * The toggle is automatically locked when the **Master Shader Switch** is OFF.
    * To conserve battery, sharpening is strictly disabled when **Power Saving Mode** is active.
    * To prevent artifacts, the toggle is overridden if **Nvidia VSR** is enabled.

---

## [v2.0.1] – YouTube Streaming Hotfix

### 🐛 Fixed
* **YouTube Force Close:** Fixed a critical issue where pasting YouTube links caused MPV to close immediately due to HTTP 403 Forbidden errors.
* **Stream Stability:** Updated `ytdl-raw-options` with **Client Spoofing** (`player_client=default,-android_sdkless`) to bypass new YouTube anti-bot protections.
* **Format Selector:** Refined `ytdl-format` logic to allow **4K/8K WebM** streams (VP9/AV1) while maintaining stability.

---

## [v2.0] – The "Universal" Update

### 🌍 Universal Compatibility
* **Stream-Aware Detection:**
    * **The Fix:** The Anime Controller now scans **all** audio tracks (not just the active one) to find `jpn`/`ja` tags.
    * **Benefit:** Web streams that default to English audio will now correctly trigger **Anime Mode** automatically if a Japanese track exists in the container.
    * **Metadata Scan:** Added logic to check `media-title` (stream metadata) for keywords like "Live Action" or "Drama", ensuring URL-based playback is categorized correctly.
* **Subtitle "Force" Mode:**
    * **New:** Added `ytdl-raw-options=sub-langs=all` to `mpv.conf`.
    * **Benefit:** Forces `yt-dlp` to download **all available subtitles** for a web stream, fixing the "Missing Subtitles" issue on pirate sites.

### 🎨 Visual & Logic Polish
* **"Visual Finesse" Shader Chain:**
    * **Optimized:** Finalized the FSRCNNX chain order: `FSRCNNX` → `KrigBilateral` → **`SSimSuperRes`** → `Adaptive Sharpen`. This maximizes Luma refinement before final sharpening.
* **Smart 4K Profile:**
    * **Optimization:** The `[4K-Native]` profile now strictly bypasses heavy upscalers (NNEDI3/FSRCNNX) and uses only `SSimSuperRes` + `Adaptive Sharpen` for pure image refinement.
* **Context-Aware Subtitles:**
    * **New:** The subtitle selector now changes behavior based on content.
        * **Anime:** Prioritizes "Dialogue", "Full", or Japanese tracks.
        * **Live Action:** Defaults to the first English track found.

### ✨ Features
* **Skip Intro v2.0:**
    * **Comprehensive Recognition:** Updated regex logic to detect complex chapter patterns.
        * **Sequences:** Supports numbered chapters like `OP1`, `OP 2`, `ED3`, `PV4`.
        * **Keywords:** Expanded library to catch diverse naming conventions (`Theme`, `Song`, `Avant`, `Ending`, `Preview`).
    * **Multi-Color Context:** The button now changes color to indicate what it's skipping:
        * 🟢 **Green:** OP (Opening)
        * 🔵 **Blue:** ED (Ending)
        * 🟣 **Magenta:** PV (Preview)
        * 🟠 **Orange:** Intro (Generic)
* **Stats Overlay v2.0:**
    * **New Layout:** Shifted the glass overlay down to avoid blocking OSD messages.
    * **New Data:** Now reports **Input vs. Output Resolution** and explicitly identifies the "Anime FSRCNNX" chain.

### 🔧 System
* **Centralized Versioning:** Created `script-opts/build_info.conf` as the single source of truth for the build version. All scripts (`update`, `stats`, `controller`) now sync from this one file.

---

## [v1.9.6] – The "Scaling" Update

### ✨ New Features

* **Expanded Scaling Menu:**
* **New Downscalers:** Added **`spline64`** and **`lanczos`** to the "Scaling" Section in Controls Menu.
* **Use Case:** This allows users playing 4K content on 1080p screens to match the sharp, high-quality downscaling.
* **New Upscalers:** Added **`spline64`** and **`lanczos`** as manual alternatives to the default `ewa_lanczossharp`.

### ⚡ Improvements

* **Menu Completeness:** The "Controls" -> "Scaling" menu now features the full "Hall of Fame" of MPV native scalers, giving users total control over sharpness vs. ringing artifacts:
* **Sharp:** `ewa_lanczossharp`, `spline64`, `lanczos`
* **Balanced:** `spline36`
* **Soft:** `mitchell`, `hermite`

---

## [v1.9.5] – The "Synchronized Logic" Update

### ✨ New Features

* **Smart OSD Separation:**
* **The Split:** To prevent text overlapping, **Nvidia VSR** status messages have been moved to the **Top-Right** corner, while Power & Anime Profile messages remain on the **Top-Left**.
* **Clean Filter Info:** Suppressed MPV's native "Video Filter" text (which often displayed messy code like `scale=%2.25`). Replaced it with a clean, formatted overlay that sits neatly below the VSR status.

* **Silent Partner Protocol:**
* During power events (unplugging/plugging in), the VSR script now enters "Silent Mode." It changes its internal state quietly and lets the **Power Manager** handle the OSD announcements ("Power Saving Enabled" / "AC Power Restored"), eliminating duplicate text crashes.


### ⚡ Improvements

* **Race Condition Fix (Power Manager):**
* Added a **0.5-second safety delay** when restoring AC Power. This forces the system to wait for Nvidia VSR to fully wake up and broadcast its "Active" signal *before* the Anime Controller attempts to calculate shaders.
* *Result:* Completely eliminated the "Double Scaling" glitch where FSRCNNX shaders would accidentally apply on top of VSR.

* **Logic Hardening:**
* **"Stand Down" Order:** The `anime_profile_controller.lua` now performs a strict check for VSR activity before running. If VSR is detected, the controller immediately halts execution, ensuring it never overrides the AI Upscaler.


### 🐛 Fixed

* **OSD Formatting:** Fixed an issue where filter properties were displayed as URL-encoded strings (e.g., `%20`) instead of readable text.
* **Button Logic:** Separated the internal logic for "User Button Presses" vs. "Automatic Power Events" to prevent keyboard shortcuts from accidentally triggering battery-saving routines.

---

## [v1.9.4] – The "Adaptive Intelligence" Update

### ✨ New Features
* **Adaptive Nvidia VSR:**
    * **Smart Scaling:** VSR now calculates the exact ratio between your video and monitor (e.g., 1.5x) to maximize quality without wasting GPU power.
    * **Safety Clamps:** Scaling is automatically capped between **1.0x** and **4.0x**.
* **Power Mode "Lockdown":**
    * **Feature Guard:** While in Power Saving Mode, resource-heavy toggles (Fidelity, Anime4K, VSR) are now **Locked** with a Red OSD warning.
    * **Visuals:** The Profile Info OSD now explicitly displays `Profile: ⚡Power Saving Mode`.
* **Master Switch Persistence:**
    * The Global Shaders ON/OFF Toggle (**`CTRL+g`**) now remembers your choice. If you disable shaders to watch raw content, they will remain disabled across restarts until you enable them again.

### ⚡ Improvements
* **Enhanced Stats Overlay:** The "Scaler" line now prioritizes system states, displaying **"Power Saving Mode (Eco)"** or **"Nvidia VSR (AI Upscale)"** when active.
* **Input Logic Cleanup:** Simplified the Interpolation shortcut (**`g`**) in `input.conf`. It now relies on the new global watchdog to automatically switch `video-sync` modes, ensuring perfect consistency between UOSC menus and keybinds.

### 🐛 Fixed
* **Power Restore Race Condition:** Fixed a bug where switching from Battery to AC Power would sometimes fail to restore the High-Quality profile automatically.
* **VSR Synchronization:** Updated `vsr_auto.lua` to listen to the central broadcast system, ensuring it correctly auto-disables if Power Saving Mode is triggered.

---

## [v1.9.3] – The "Live Action Persistence" Update

### ✨ New Features
* **Live Action Persistence:** Your upscaler preferences for Live Action content are now saved automatically.
    * **HD Content:** If you switch from **NNEDI3** (Default) to **FSRCNNX** (HQ), the build will remember this choice for all future SD/HD files, even after restarting MPV.
    * **SD Content:** Your preference between **Clean Mode**, **Texture Mode**, or **FSRCNNX (Sharp)** is now persistent.
    * **Config:** These settings are saved to `anime-mode.conf` alongside your Fidelity preferences.

### ⚡ Improvements
* **Instant Save:** Toggling options via the UOSC Menu or Shortcuts (`Q`, `Ctrl+Q`) now triggers an immediate save to the config file.
* **Smart Restore:** Removed the logic that forced settings to reset to "Default" on every file load. The player now respects your last used configuration.

---

## [v1.9.2] – The "Fidelity Persistence" Update

### ✨ New Features
* **Fidelity Mode Persistence:** The build now remembers your preference between **Fidelity (FSRCNNX)** and **Performance (Anime4K)**.
    * **Behavior:** If you switch to Anime4K mode, MPV will now launch in Anime4K mode on the next restart instead of resetting to Fidelity default.
    * **Config:** This preference is saved automatically to `anime-mode.conf`.

### 🐛 Fixed
* **Logic Consistency:** Fixed a minor annoyance where switching to "Performance Mode" would not survive a restart, forcing users to re-toggle it every session.

---

## [v1.9.1] – The "HDR & Target Peak" Update

### ✨ New Features
* **Professional HDR Tone-Mapping:**
    * **Algorithm Selection:** Added a new menu to choose between industry standards (**BT.2390**, **BT.2446a**), active correction (**ST.2094-40**), or legacy curves (**Reinhard**, **Hable**).
    * **Target Peak Presets:** Added manual brightness overrides (e.g., **100 nits**, **600 nits**, **1000 nits**) to correctly calibrate tone-mapping for your specific display.
    * **Persistence:** HDR settings now save to `hdr-mode.conf` and persist across restarts.
* **Enhanced Stats Overlay:**
    * Updated the "Neon Glass" overlay to display the **Active Tone-Mapping Algorithm** (e.g., `HDR (Tone-Mapping) [st2094-40]`) instead of a generic HDR label.

### 🐛 Fixed
* **HDR Logic Fallback:** Fixed `hdr_detect.lua` to respect the user's saved Tone-Mapping preference when switching out of Passthrough mode, preventing it from resetting to `spline`.
* **Menu Stability:** Removed experimental text-input features to ensure maximum stability for the Target Peak selector.

---

## [v1.9] – The "Fidelity & Stats" Update

### ✨ New Features
* **Anime Fidelity Mode:** A completely new rendering engine for purists (Now Default for Anime).
    * **Concept:** While Anime4K focuses on aggressive upscaling and "painting" over artifacts, Fidelity Mode uses **FSRCNNX** + **KrigBilateral** to strictly preserve original line art and texture details.
    * **Resolution-Aware Application:**
        * **SD Content:** Uses **FSRCNNX-16 (Anime Enhance)** to reconstruct missing details in older, low-res anime.
        * **HD/FHD (720p/1080p):** Uses **FSRCNNX-8 (Line Art)** for precise edge refinement without altering the artistic intent.
        * **4K Content:** Uses **Adaptive Sharpening** only, avoiding unnecessary processing overhead.
* **"Neon Glass" Stats Overlay:** A professional, hardware-accelerated debug overlay (Toggle via Menu or 'Statistics' Button).
    * **Live Monitoring:** Displays exact active shader chains, distinguishing between "Line Art" (Anime) and "Generic" (Live Action) scalers.
    * **Audio & HDR:** Tracks PCM vs Passthrough, Night Mode status, and HDR Tone-Mapping.
    * **Visuals:** Uses a virtual 720p vector canvas to ensure pixel-perfect alignment on any screen size (1080p to 4K).
* **Smart Resolution Logic (Live Action):** Rewritten logic for non-anime content.
    * **SD (<576p):** Defaults to **NNEDI3** (Texture). Manual switch to **FSRCNNX** (Sharp).
    * **HD (720p):** Defaults to **NNEDI3** (Geometry). Manual switch to **FSRCNNX** (HQ).
    * **FHD (1080p):** Defaults to **High-Quality** (glaze/adaptive-sharpen).
    * **4K:** Defaults to **Native** (Bitrate efficient).
* **Audio Night Mode:** Dynamic Range Compression (DRC) for watching at night without waking the neighbors.
* **Manual Zoom:** New controls to Crop/Fill/Fit video for Ultrawide monitors.

### 🔧 Improvements
* **Fixed Profile Logic:** Solved an issue where `HQ-HD-FSRCNNX` was missing from `mpv.conf`, restoring full manual control for 720p content.

---

## [v1.8] – The "Skip Intro" Update

### ✨ New Feature: Smart Skip Button
Now introducing a fully automated, context-aware **Skip Intro** button inspired by modern streaming services.

* **Context-Aware Logic:** Automatically detects and distinguishes between **Openings (OP)**, **Endings (ED)**, **Previews (PV)**, and generic **Intros**.
* **Multi-Color Coding:** The button adapts its color based on the content type for instant recognition:
    * 🟢 **Green:** OP (Opening)
    * 🔵 **Blue:** ED (Ending)
    * 🟣 **Magenta:** PV (Preview)
    * 🟠 **Orange:** Intro (Generic)
* **Smart Timer:** The countdown timer automatically **pauses** if you pause the video, ensuring the button doesn't expire while you're away.
* **Mouse Support:** The button is fully interactive. Hovering turns the text **Cyan**, and clicking it instantly skips the chapter. (Keyboard Shortcut: `ENTER` only works when the button is visible)

### 🎨 Visual Refinement
* **High-Contrast Design:** Redesigned the button with a heavy black border and "Two-Tone" text (Color + White) to ensure visibility against any anime background (bright sky or dark cave).

---

## [v1.7.3] - The Synchronization Update

**Core Improvements:**
* **Hybrid Menu Sync System:** Solved the "Invisible Checkmark" issue. The UOSC Main Menu and the Anime Mode Button now share a real-time communication channel.
    * Toggling VSR, Power Mode, or Shaders from *any* menu instantly updates the checkmarks in *all* other menus.
    * Fixed the desync where `user-data` updates were sometimes too slow to reflect in the UI immediately.

**Under the Hood:**
* **Broadcast Listeners:** Added dedicated listeners to `anime_profile_controller.lua` and `main.lua` to catch state changes instantly.
* **Robust State Caching:** UOSC now caches the anime state locally to prevent UI flickering during rapid menu navigation.
* **Startup Evaluation:** Forced a profile re-evaluation on file load to ensure the menu always shows the correct state immediately after opening a file.

---

## [v1.7.2] – The "Visual Feedback" Update

### 🎮 Interface & Controls

* **Comprehensive Scaling Menu:** Expanded the **Scaling** section within the 'Controls' menu to include all available upscaler and downscaler options, giving users granular control over image resizing directly from the UI.
* **Universal Checkmarks:** Implemented consistent visual feedback across the interface. Active settings now display checkmarks correctly in both the main **'Controls'** and the **'Anime Mode'** Buttons, ensuring you always know which features are enabled.

### 🐛 Logic Fixes

* **Audio Passthrough Fix:** Resolved a logic error in the Audio Passthrough toggle. The button now correctly identifies and highlights the active state (PCM vs. Bitstream), preventing mismatch errors where the menu would show the wrong status.

---

## [v1.7.1] – The "Total Control" Update

### 🎮 Interface & Workflow
* **New 'Controls' Button:** Added a dedicated **Controls** button (Sliders Icon) to the interface (above the timeline). This gives instant access to essential adjustments (Sync, Colors, Interpolation) without needing keyboard shortcuts.
* **Centralized Right-Click Menu:** Integrated **"Anime Build Options"** and the new **"Controls"** menu directly into the main UOSC Right-Click context menu.
* **Searchable Playlist:** The Playlist panel now includes a **Search Bar**. Simply type to find files instantly.

### ⚙️ Logic & Stability
* **Smart Menu Memory:** The Controls menu now remembers your cursor position. This makes repetitive tasks (like tapping "Decrease Audio Delay") smooth and frustration-free.
* **Advanced Sub-Menu:** Cleaned up the UI by moving technical settings (Hardware Decoding, Dither, Interpolation Method) into a separate **"Advanced"** folder.
* **Safety Guard:** The **GPU API** selector is now **Read-Only**. It displays your active API (e.g., `d3d11`) but prevents accidental clicks that would otherwise crash the player.

---

## [v1.7] – The "Glass UI" & True HDR Update

### 🎨 Visual & Interface (UOSC)
* **New UI Engine (UOSC):** Shifted from the 'ModernZ' skin to **UOSC** for a cleaner, faster, and more modern interface.
* **Customized Integration:** Heavily modified the default UOSC configuration to seamlessly fit the specific needs and workflows of the *mpv-anime-build*.
* **"Glass" Theme Design:** Designed a custom **"Smoked Glass" theme** with transparency effects (33% opacity) for menus, title bars, and volume sliders, ensuring the video remains visible while navigating.

### ⚙️ Logic & Workflow
* **Centralized Anime Control:** Reworked all existing scripts to route through a single, centralized **Anime Build Options** button in the menu. This panel now houses all build-specific features (Anime4K, Upscaling, Audio, Power) in one place.
* **HDR Logic Overhaul:** Fixed the **HDR Manual Toggle** bugs and completely reworked the detection logic to support **True HDR Passthrough**, ensuring raw metadata is correctly sent to the display when Windows HDR is active.

---

## [v1.6.3] – Cinema 4K & Color Pop

### 🎨 Visual Tuning
* **SDR Vibrancy Boost:** Moved color tuning (`gamma=1.02`, `contrast=1.05`, `saturation=1.05`) to the global scope. This gives Anime and SDR content a subtle "modern pop" by default.
* **HDR Safety Net:** Updated the `[HDR-High-Quality]` profile to explicitly reset all color values to `1.0` (Reference Standards). This prevents the SDR boost from crushing blacks or clipping highlights in HDR/Dolby Vision content.
* **Cinema 4K Shader:** Introduced a dedicated `adaptive-sharpen-modern-4K.glsl` shader.
    * **The Change:** Lowered sharpening strength from `1.0` to `0.6`.
    * **Why:** Native 4K content doesn't need heavy sharpening. The lower strength improves clarity without boosting film grain or sensor noise, resulting in a cleaner "Cinema" look.

---

## [v1.6.2] – Resolution Logic Refinement

### 🧠 Logic Upgrade
* **Smart Resolution Gates (`anime_profile_controller.lua`):**
    * **The Upgrade:** Resolution detection now checks **Width OR Height** instead of just Height.
    * **Fix 1 (Ultrawide 1080p/4K):** Movies with cropped black bars (e.g., `1920x800` or `3840x1600`) are now correctly identified as **FullHD (High-Quality)/4K-Native** instead of being mistaken for 720p/1080p.
    * **Fix 2 (PAL SD):** European DVDs (`720x576`) are now correctly identified as **SD**, applying the proper restoration shaders.
    * **Result:** Perfect profile application regardless of aspect ratio or cropping.

---

## [v1.6.1] – HDR Detection Hotfix

### 🐛 Critical Fixes
* **Hybrid HDR Detection (`hdr_detect.lua`):**
    * **The Issue:** On some Windows setups, MPV's internal API would incorrectly report "SDR" (BT.709) even when Windows HDR was enabled in the OS settings. This caused the script to force Tone Mapping instead of Passthrough.
    * **The Fix:** Implemented a **Silent PowerShell Fallback**. If MPV reports SDR, the script now silently queries the Windows API (`WmiMonitorAdvancedColorProperties`) to verify the *real* HDR status.
    * **Logging:** Added a diagnostic log message to the MPV console (`[HDR-Detect] Windows Settings report HDR: ON/OFF`) to help users verify their system state.
    * **Result:** 100% accurate Auto-Switching for OLED/HDR TV users.

---

## [v1.6] – The "Mobile Power" Update

### 🔋 New Features
* **Power Manager (`power_manager.lua`):**
    * **Laptop Detection:** Automatically detects if you are running on a laptop.
    * **Battery Awareness:** Automatically switches MPV to a `[Low-End]` profile when unplugged (Battery Mode). This disables high-end shaders (NNEDI3/FSRCNNX/Anime4K) and switches scaling to bilinear to save battery.
    * **Smart Resume:** Pauses playback briefly during the switch to prevent stuttering or glitches.
    * **Manual Override:** Added **`Ctrl+p`** to force "Low Power Mode" ON/OFF manually (useful for desktops or saving energy while plugged in).
* **SVP Intelligence:**
    * **The Problem:** SVP 4 Pro is aggressive and often tries to re-hook into MPV even after we disable it for battery saving.
    * **The Fix:** The script now cleanly hands off control. We also added a guide (see Readme) for configuring SVP's internal "Battery Profile" for perfect synchronization.

### 🛠️ Improvements
* **OSD Stacking:** Rewrote the OSD logic in `power_manager.lua` to properly stack messages *below* the Anime Profile info, preventing text overlap.
* **Logic Handshake:** Updated `anime_profile_controller.lua` with a new `force-evaluate` hook. When you plug your laptop back in, the Power Manager forces the Anime Controller to re-scan the file and restore the exact correct profile (Anime/Live-Action/SD/HD) automatically.
* **Fallback Profiles:** Added `[Fallback-SD-Tier2]` and `[Fallback-HD-Tier2]` to `mpv.conf` for future performance monitoring features.

---

## [v1.5.2] – The "RTX Manual Override" Update

### 🚀 Critical Fixes (Nvidia VSR)
* **Manual VSR Toggle (`vsr_auto.lua`):**
    * **The Change:** Switched VSR activation from "Auto-Detection" to **"Manual Override"**.
    * **Why:** On many Hybrid Laptops (Optimus), MPV cannot "see" the dedicated RTX GPU even when it is being used, causing the script to falsely block VSR.
    * **New Behavior:** Pressing **`V`** now forces the command directly to the GPU driver. If you have an RTX card, it works instantly.
* **Linux Safety Gate:**
    * Added a strict platform check to `vsr_auto.lua`.
    * **Behavior:** If you press `V` on Linux, the script now blocks the command and displays an error ("Windows Only"), preventing MPV from crashing (since VSR relies on DirectX 11).

### 📚 Documentation
* **Anime Mode Philosophy:** Added a new **"Stylized vs. Faithful"** section to the Readme. This breaks down exactly when to use Anime4K (Modern look) vs. NNEDI3 (Reference look).
* **Gallery Update:** Added visual evidence and technical stats for **RTX VSR (AI Upscaling)** to the "Technical Verification" section.
* **FAQ Update:** Clarified that the `V` toggle is manual and should **NOT** be used on AMD/Intel cards (as it would degrade quality).

---

## [v1.5.1] – The "Sharp SD" Update

### ✨ New Features
* **Unified 'Q' Toggle:** The **`Q`** key is now the universal "Master Upscaler Toggle" for all resolutions below 1080p.
    * **HD (Default):** Toggles between NNEDI3 (Smooth) and FSRCNNX (Sharp).
    * **SD (New):** Now toggles between NNEDI3 (Default) and FSRCNNX (New Sharp Mode). Previously, 'Q' did nothing for SD files.
* **Smart NNEDI3 Optimization:**
    * **SD (<576p):** Now uses **`nns256`** (Max Quality). Since SD files have fewer pixels, we allocate maximum neural power to reconstruct details and fix artifacts.
    * **HD (≥576p):** Now uses **`nns64`** (Balanced). This provides perfectly smooth lines for 720p/1080p content without the massive GPU cost of nns256, ensuring smooth playback.
* **New Profile:** Added `[HQ-SD-FSRCNNX]` to `mpv.conf`. This applies the high-end FSRCNNX scaler to high-quality SD content (like DVD rips) that doesn't require heavy noise reduction.

### 🛡️ Logic & Safety
* **Safety Lock:** Added a smart lock to `CTRL+Q` (Clean/Texture).
    * If you switch SD to **FSRCNNX (Sharp Mode)**, the `CTRL+Q` toggle is temporarily locked.
    * *Reasoning:* FSRCNNX is designed for sharpness; applying the heavy "Texture" mask on top of it contradicts the upscaler's purpose. Switch back to NNEDI3 (Press 'Q') to unlock it.

---

## [v1.5] – The "Universal, 4K & SVP" Update

### ✨ New Features
* **Universal Linux Support:** The build is now 100% compatible with Linux (Wayland/X11).
    * **Dual-OS Config:** `mpv.conf` now automatically detects your OS. It loads `d3d11` for Windows and `vulkan` for Linux without needing manual edits.
    * **Script Safety:** `vsr_auto.lua` and `hdr_detect.lua` now include OS-checks to prevent Windows-only commands (like VSR) from crashing Linux.
    * **Universal Paths:** Updated all shader paths and script logic to work with both Windows (`%APPDATA%`) and Linux (`~/.config/mpv`) directory structures.
* **SVP 4 Pro Compatibility Mode:**
    * **The Fix:** Enforced `hwdec=auto-copy` on Windows. This fixes the conflict where Native D3D11 decoding was locking video frames on the GPU, preventing SVP from interpolating them.
    * **Result:** You can now use SVP 4 Pro (Frame Generation) and Nvidia VSR (Upscaling) simultaneously.
* **Native 4K Logic Gate:**
    * **The Fix:** Added a robust "Logic Gate" for Native 4K (2160p) content using the new `[4K-Native]` profile.
    * **Why:** Previous versions treated 4K video as "HD" and attempted to upscale it further to 8K using FSRCNNX, wasting massive amounts of GPU power.

### 🐛 Fixed
* **Shader Syntax:** Replaced `glsl-shaders-set="..."` with `glsl-shaders-append`. This fixes a critical bug where Linux would fail to parse multiple shaders if they were separated by semicolons (`;`).
* **VSR Logic:** Updated `vsr_auto.lua` to smartly restore your previous specific shader profile (Anime vs Live Action) when disabled, instead of just resetting to default.

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
- **\"Modern TV\" Upscaling:** Added custom shader configurations (`adaptive-sharpen-modern-*.glsl`) to replicate high-end TV processing (Sony Reality Creation style) for 480p, 720p, and 1080p.
- **Smart Logic Update:** Added handlers for manual Live-Action toggles (`toggle-hq-sd`, `toggle-hq-hd-nnedi`) which were previously missing from the Lua script.
- **Visual Polish:** Added Film Grain and Dithering to High-Quality profiles for a more organic, cinematic look.

### 🐛 Fixed
- **Shader Compilation Errors:** Fixed `HOOKED : undeclared identifier` errors in `adaptive-sharpen-soft.glsl` by correcting the header definitions.
- **Logic Gaps:** Fixed an issue where shortcuts `Q`, `W`, and `Ctrl+Q` would not trigger their respective profiles in the Lua controller.
- **MPV Config:** Optimized `video-sync` and `interpolation` settings for smoother frame pacing on Windows 11.
