# Changelog – MPV Anime Build

All notable changes to this project are documented here.

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