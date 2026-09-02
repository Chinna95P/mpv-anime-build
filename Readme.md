# 🎬 MPV Anime Build v5.2
> **The Detection & Playback Defaults Update: reliable Live-Action overrides, safer thumbnail decoding, and focused English stream subtitles.**

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-7289da?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Pvf3huxFvU)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Chinna95P/mpv-anime-build)
[![Sponsor on GitHub](https://img.shields.io/badge/GitHub-Sponsor-ea4aaa?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/Chinna95P)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-Support-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=000000)](https://buymeacoffee.com/chinna95p)

> **An advanced, context-aware MPV configuration featuring AI upscaling, dynamic power management, universal HDR support, and intelligent audio processing.**

### 📱 Android Support Available
The MPV Anime Build is also available for **Android (mpvEX / Aniyomi)**!
* **Features:** Gesture Controls, Smart Auto-Detection, and Optimized Shaders for mobile.
* **Download:** Switch to the [**Android Branch**](https://github.com/Chinna95P/mpv-anime-build/tree/android) to get the mobile-specific files.

<a href="https://github.com/Chinna95P/mpv-anime-build/releases?q=android">
<img src="https://img.shields.io/badge/📱_Android_Releases-000000?style=for-the-badge&logo=android&logoColor=white" alt="Android Releases"/>
</a>

**Note for HDR Users:** `Auto (Detected)` follows active Windows HDR displays and KDE Plasma's Linux HDR state. Other Linux compositors use mpv's native colorspace negotiation. `HDR Display (Passthrough)` remains available as a manual override when a display driver does not expose its HDR state correctly.

---

## 🚀 What's New in (v4.0 - v5.2)

* **🎬 Restored Live-Action Path Override (v5.2):** Explicit `Live Action`, `Live-Action`, `liveaction`, `drama`, and `real person` path/title signals once again take priority over Anime folder and Japanese-audio signals while Anime Mode is set to Auto.
* **🖼️ Safer Thumbfast Decoding (v5.2):** Thumbnail generation now explicitly uses software decoding by default, matching Thumbfast's built-in safe fallback and avoiding hardware-decoder instability in the helper process.
* **🌐 English-Only Stream Subtitles (v5.2):** yt-dlp automatic and authored subtitle requests are limited to English and original-English tracks; unintended Telugu language requests were removed.
* **🎨 Contrast-Separated Smart Skip Colors (v5.2):** Swapped the Intro and PV colors across Skip Intro and the UOSC chapter timeline so adjacent chapter categories remain visually distinct: OP green, ED blue, PV orange, and Intro magenta.
* **💬 Commentary-Safe Subtitle Fallbacks (v5.2):** Automatic selection completely skips commentary subtitles, preserves clean-track priority, and falls back to a complete SDH or hearing-impaired track when no usable clean subtitle exists—even when the SDH track lacks preferred-language metadata.

* **🔋 Durable Eco Profile Ownership (v5.1):** Power Saving now remains authoritative across file loads, metadata changes, and saved UOSC setting updates. User preferences are preserved for normal playback and restored deterministically when Eco mode ends.
* **💬 Preferred-Language SDH Fallback (v5.1):** When no clean preferred-language subtitle exists, the selector now chooses a preferred-language SDH or hearing-impaired track before an unrelated clean language, while still rejecting forced and signs-only tracks.

* **🌈 Cross-Platform HDR Detection (v5.0):** Windows uses the DisplayConfig API with a WMI compatibility fallback, KDE Plasma uses KScreen, and other Linux compositors defer safely to mpv's native colorspace negotiation. Windows and Linux detection paths remain strictly isolated.
* **💾 Durable User Overrides (v5.0):** UOSC Controls and HDR choices are remembered in untracked `user-<custom-name>.conf` files, loaded alphabetically and reapplied after profile evaluation so build updates do not overwrite personal settings.
* **🧩 Community-Reported Reliability Fixes (v5.0):** Fixed disabled track-selector overrides, wireless peripheral batteries forcing Linux desktops into Eco mode, and nil-sensitive profile conditions during startup.
* **🎨 Clear Anime FSRCNNX Names (v5.0):** Renamed the two easily-confused Anime FSRCNNX shaders to explicit `anime_mild` and `anime_aggressive` filenames, with automatic migration of saved legacy paths.

* **🔋 Cross-Platform Power Guard (v4.9):** Completely reworked `power_manager.lua` for automatic Windows and Linux support. Windows uses modern PowerShell/CIM battery monitoring, while Linux reads the native system power-supply interface without requiring PowerShell or manual platform-specific edits.
* **🖥️ Smart Desktop/Laptop Detection (v4.9):** Battery-equipped laptops retain automatic Eco switching on battery and smart restoration on AC power. Desktop systems cleanly use **Manual Toggle Only** mode without generating failed-subprocess warnings.
* **🎞️ Safe Decoder Restoration (v4.9):** Power Guard now remembers and restores the active hardware decoder instead of forcing a platform-specific value. This preserves D3D11VA on Windows and NVDEC, VA-API, Vulkan, or SVP copy-back decoding on Linux.
* **✨ Smoother High-Quality Scaling (v4.9):** Enabled MPV's built-in `high-quality` rendering foundation and changed Anime native scaling from `ewa_lanczossharp` to `spline64` for smoother edges, reduced ringing, and more consistent rendering.
* **📺 FHD-Native Profile Clarity (v4.9):** Renamed the custom `[High-Quality]` profile to `[FHD-Native]` and synchronized controller state detection, profile evaluation, menus, and OSD labels to distinguish it from MPV's built-in `high-quality` profile.
* **📸 Video-Only Screenshots (v4.9):** Added `F6` for clean video-frame screenshots alongside the existing `F5` window screenshot shortcut.
* **🧩 Optimized Anime Profile Controller & Main UI Logic (v4.8):** Optimized `anime_profile_controller.lua` and `main.lua` to fix minor bugs and reduce unnecessary processing while preserving the existing profile system and menu synchronization.
* **📂 Dedicated UOSC Open File Button (v4.8):** Added an **Open File** button directly to the UOSC controls bar. It opens UOSC's file-selection menu for selecting video and audio files without leaving the player.
* **🖼️ Image Filtering in Open File Menu (v4.8):** The UOSC file browser can now be configured with `load_types=video,audio`, `show_hidden_files=no`, and an empty `image_types` value so poster/backdrop image assets are not shown alongside playable media.
* **🎛️ Refined UOSC Behaviors (v4.8):** Adjusted several UOSC controls and menu behaviors for a cleaner, more consistent MPV Anime Build experience.
* **🎵 Track Selector Fixes & Refinements (v4.8):** Updated `track-selector.lua` with the fixes and behavior changes developed for v4.8, improving track-selection reliability while retaining the manual-selection/override workflow.
* **🎨 Resolution-Tuned Adaptive Sharpen & Anime Line-Thinner (v4.7):** Adjusted sharpening and line-thinner strengths across resolution tiers for smoother, more soothing edges on both Anime and Live-Action content while retaining background and subject detail.
* **📥 Working Stream Downloads (v4.7):** Added the [`mpv-youtube-download`](https://github.com/cvzi/mpv-youtube-download) script and connected it to the UOSC **Download** button. Stream downloads are saved to `~/ytdl` by default and can be redirected through `youtube-download.conf`.
* **🪟 Windows CMD Flash Fix (v4.7):** Updated `mpvSockets.lua` to prevent command-window flashes on Windows when socket commands are issued.
* **🌊 Expanded Audio-Only Visualizers (v4.7):** Added new visualizer styles to the Audio-Only profile for more visual variety during music playback.
* **🎛️ UOSC 5.13.0 (v4.7):** Updated UOSC to the latest 5.13.0 release while retaining the MPV Anime Build's custom controls, menus, and integrations.
* **🌈 Color-Coded Chapter Timeline (v4.7):** UOSC highlights detected chapter ranges using the same colors as Skip Intro. The current displayed palette is **OP `#00FF00`**, **ED `#0080FF`**, **PV `#FF9900`**, and **Intro `#FF00FF`**, with transparent timeline colors. *(PV and Intro used the opposite colors in the original v4.7 palette and were swapped in v5.2 for stronger contrast between neighboring chapter ranges.)*
* **💾 Track Selector Resume Manual Override (v4.7):** Manual audio/subtitle overrides are persisted per video. When resumed in a later MPV session, the matching override is restored and then remains active for the rest of that session/playlist, including next/previous files.
* **📜 Native Watch History & Progress Bars (v4.5):** Tracks up to 50 recent files with visual progress blocks, 95% watched thresholds, greyed-out completed entries, and a dedicated control bar button.
* **🗡️ Anime Line-Thinner Suite & Context Locks (v4.5):** Resolution-aware line-thinning shaders mapped into FSRCNNX with a persistent menu toggle (`Ctrl+j`) and safety lockdown checks.
* **✨ Refined Adaptive Sharpening (v4.5):** Balanced strength curves across SD, HD, FHD, and 4K tiers for pristine edge fidelity.
* **⚡ ArtCNN Performance Optimizations (v4.4):** Upgraded the Ani4Kv2 and AniSD shader chains to use highly optimized fragment iterations (`_i2` / `_i4`) instead of heavy compute models, entirely eliminating frame drops during real-time playback.
* **🔒 Strict Fidelity Locks & UI Sync (v4.4):** Anime4K profiles are now strictly locked out while Fidelity Mode is active, complete with custom OSD warnings. UOSC menus have also been reorganized and dual-synced for a cleaner right-click experience.
* **🎵 Audio-Only Smart Toggle & Fix (v4.3):** Added a new UOSC menu toggle to enable (`Auto`) or completely bypass (`Disable`) the audio-only battery-saving profile. Fixed a major race condition that incorrectly applied audio-profiles to video files on systems without discrete GPUs.
* **Status Overlay Overhaul (v4.3):** The status view now features structured, color-coded layouts for audio/video filters and shaders. Implemented smart text wrapping and native table parsing to eliminate string artifacts and ensure perfect readability on all screen resolutions. Press 'k' for A/V Filter and Shaders Info
* **✨ Anime4K Ultra Tier (v4.2):** Integrated the unified **Anime4K-Ultra** shaders by Th-Underscore. The quality setting is now a 3-tier system (`Fast`, `HQ`, `Ultra`), bringing superior line thinning, pre-sharpen blur-pulls, and de-aliasing to the pipeline.
* **🔤 Dynamic UI Labels (v4.2):** The UOSC Anime4K Profiles menu now dynamically updates its descriptions based on the active quality tier, mapping specific Th-Underscore files to the correct modes.
* **🧠 Resolution-Aware Engine Persistence (v4.1):** The toggle choice between **Anime Fidelity (FSRCNNX)** and **Performance (Anime4K)** is now tracked and remembered **independently per resolution tier**. Mix and match purist edge refinement for 1080p content while running aggressive upscaling on 720p content completely automatically.
* **💻 ArtCNN Compute Engine Optimizations (v4.1):** Next-gen `Ani4Kv2` and `AniSD` rendering engines now leverage dynamic compute profiles. **Fast Quality** utilizes general loops, while **HQ Quality** triggers parallel hardware Compute pipelines (`*_CMP.glsl`) to maximize your graphics card's hardware capabilities.
* **📺 Advanced 3-Way HDR Matrix Switch (v4.0):** Overhauled the display engine output to route through an explicit 3-way layout loop: **Auto**, **HDR Display (Passthrough)**, and **SDR Display (Tone-Mapping)**.
* **🔤 Interactive Subtitle Styling (v4.0):** Fine-tune your subtitle fonts, colors, and borders directly from the new Subtitles section in the UOSC Controls Menu.
* **🔊 Screen-Wide Scroll Volume Engine (v4.0):** Adjust sound balances comfortably by using your mouse scroll wheel anywhere across the video output field, syncing natively with the custom smoked glass volume popups.
* **⌨️ New ArtCNN Control Interfacing (v4.0):** Quick-swap layout styles on the fly using standard keyboard overrides (`CTRL+7` for Ani4Kv2 and `CTRL+8` for AniSD).
* **⚡ NVIDIA Decoding Priority (v4.0):** The Windows core engine now prioritizes `nvdec` hardware decoding, ensuring maximum performance and lower power draw for RTX/GTX users.

---

## 🚀 What's New (v3.0 - v3.2)
* **🧠 Resolution-Aware Anime4K (v3.2):** Anime4K is no longer a single global toggle. The build now remembers your precise Quality ("fast" vs "hq") and Mode (A, B, C, AA, BB, CA) preferences independently for **each resolution tier** (SD, HD, FHD, 2K, 4K, 8K), seamlessly swapping settings on the fly to match your content.
* **🎛️ Interactive Denoise Filter (v3.1):** A dedicated Denoise (`hqdn3d`) control suite in the UOSC menu with independent Luma and Chroma adjustments. It features a **Smart Hardware Fallback** that safely manages your `hwdec` settings to prevent crashes when engaging CPU-based filters.
* **🌐 Smart Track Selector (v3.1):** Intelligently handles missing metadata, prioritizing "Dialogue" or "Full" subtitle tracks over "Signs/Songs", and cleanly falls back to muxer defaults if your preferred language isn't found.
* **🎵 Audio-Only Profile (v3.0):** Instantly drops GPU load to 0% for music playback. Automatically disables heavy video shaders/scalers while displaying embedded album art and dynamic visualizers.
* **🎚️ On-the-Fly Equalizer & PIP (v3.0):** Fine-tune your audio frequencies directly from the UI, and seamlessly pop the video out into a floating Picture-in-Picture (PIP) window for multitasking.
* **⚡ 8K Optimized Mode (v3.0):** Automatically detects massive 8K resolution files and bypasses heavy upscaling shaders to prevent GPU crashes and ensure buttery-smooth playback.
* **🌈 Ambient Crop Shader (v3.0):** A highly immersive viewing mode that fills black bars with ambient glowing colors. *(⚠️ Note for SVP Users: Use SVP's dedicated "Fill black bars" instead).*
* **⚡ Core Performance Optimizations (v3.0):** Refined underlying scripts for significantly faster state transitions and lower startup overhead.
* **🎨 Menu Overhaul (v3.0):** The UOSC Glass UI has been completely reorganized with new intuitive submenus for PIP, Ambient, and Equalizer controls.

---

## 🧠 Smart Intelligence & Automation

### 1. Universal Auto-Detection
The build automatically switches profiles (Anime vs Live Action) based on what you are watching.
* **File/Folder Rules:** If the path contains `anime`, it applies Anime shaders. If it contains `live action`, `drama`, `real person`, or lacks anime tags, it applies Live Action shaders. 
* **3D/Donghua:** Automatically recognizes keywords like `donghua`, `3d_anime`, and `cartoon`.
* **Streaming Detection:** Works flawlessly on Web Streams (Stremio, Debrid, URLs) by automatically scanning audio tracks for Japanese language tags to trigger Anime Mode.

### 2. Power Guard (Battery Safety)
A cross-platform power manager designed for Windows and Linux laptops, portable systems, and desktops.
* **Automatic Platform Detection:** Uses modern PowerShell/CIM battery monitoring on Windows and the native system power-supply interface on Linux. No platform-specific script editing is required.
* **Auto-Eco:** Unplugging a laptop automatically disables high-end shaders (Anime4K/FSRCNNX), locks them out, and switches to the lightweight `[Low-End]` bilinear profile.
* **Auto-Restore:** Reconnecting AC power restores the smart video profile and the exact hardware decoder that was active before Eco mode.
* **Desktop Mode:** Systems without a battery automatically use **Manual Toggle Only** mode through `Ctrl+P` or the UOSC power menu.
* **Decoder Safety:** Preserves D3D11VA, NVDEC, VA-API, Vulkan, and SVP copy-back configurations instead of forcing an incompatible decoder.
* *Note for SVP Users:* Create a "Battery Profile" in SVP 4 Pro to disable frame interpolation when on battery to ensure total efficiency.

### 3. Adaptive Nvidia VSR (RTX AI Upscaling)
* **Smart Ratio:** Calculates the exact pixel ratio between your video and monitor to maximize quality without wasting GPU power (e.g., scales 720p to 4K at 3.0x, but leaves 1080p on a 1080p screen at 1.0x).
* **Safety & Bit-Depth:** Automatically selects `p010` (10-bit) for HDR/Anime to prevent banding.

---

## 🎨 The Video Pipeline (Visuals & Shaders)

### Anime Mode: Stylized vs. Faithful
You have two distinct engines for watching Anime.

| Mode | Engine | Best For | Philosophy |
| :--- | :--- | :--- | :--- |
| **Performance (Default)** | **Anime4K** | **720p / Old Anime** | "Make it look like 4K." Aggressive upscaling, artifact removal, and "painting" effect. Razor-sharp. |
| **Fidelity (Purist)** | **FSRCNNX** | **1080p / Modern Anime** | "Show exactly what the artist drew." Preserves original texture, line art, and film grain. |

* **SD Content:** Applies `FSRCNNX-16 (Anime Enhance)` for deep reconstruction.
* **HD/FHD Content:** Applies `FSRCNNX-8 (Line Art)` for subtle edge refinement.

### Live-Action Pipeline
Non-anime content uses a completely separate "Modern TV" adaptive processing path.
* **SD (< 576p):** Choose between **NNEDI3 (Clean/Texture)** or **FSRCNNX (Sharp Mode)**.
* **HD (720p-1080p):** Choose between **NNEDI3 (Geometry)** or **FSRCNNX (Detail/Sharp)**.
* **4K (2160p):** Native 1:1 Pixel Mapping with subtle Adaptive Sharpening + Glaze. Bypasses all heavy upscalers.
* **8K (4320p) [v3.0]:** Engages Hardware-Decoded optimized mode. Bypasses all post-processing.

### Native Scalers Guide (Manual Overrides)
If you disable shaders (`CTRL+g`), MPV falls back to its high-quality native scaling configuration:
* **`spline64`:** The v4.9 default for Anime and native FHD processing. Produces smooth, stable edges with less aggressive ringing.
* **`ewa_lanczossharp`:** A sharper manual alternative when stronger edge definition is preferred.
* **`mitchell`:** A softer option that can help conceal compression artifacts and low-quality source detail.

---

## 🎵 The Audio & HDR Engine

### Professional Audio
* **Audio-Only Mode [v3.0]:** Instantly drops GPU load to 0% for music playback, showing embedded album art and dynamic visualizers.
* **Spatial Audio:** Uses HRTF-based virtual surround to simulate a 7.1 cinema experience on standard stereo headphones.
* **Night Mode:** Applies Dynamic Range Compression (DRC) to lower explosions and boost whispers for late-night viewing.
* **Passthrough/Bitstream:** Send raw TrueHD/DTS-X to your AVR with a single click (`A`).

### True HDR & Dolby Vision
Automatically detects your monitor's capabilities via Windows.
* **Windows HDR ON:** Activates the **HDR Display** output path. The selected metadata-aware tone-mapping curve remains active for HDR10+/Dolby Vision highlight handling.
* **Windows HDR OFF:** Switches to **High-Quality Tone Mapping** (Spline/BT.2390) for SDR monitors.
* **Dolby Vision:** Plays correctly on all devices, automatically falling back to the HDR10 Base Layer if your display lacks DV support (fixes purple/green screen errors).
* **Calibration:** Manually set Target Peak Brightness (e.g., 400 nits, 1000 nits) and Tone-Mapping algorithms via the menu.

---

## 📺 UI & Smart Features

* **Glass UI (UOSC):** A modern, transparent "Smoked Glass" interface that doesn't block the video.
* **Smart Skip Intro / Up Next:** Interactive, context-aware cards.
    * 🟢 **Green:** Skip OP | 🔵 **Blue:** Skip ED | 🟣 **Magenta:** Skip Preview
    * *Click to skip instantly. Pauses the timer if you pause the video.*
* **Neon Glass Stats Overlay (`I`):** Real-time monitoring of active shaders, Input vs Output resolution, HDR status, and Audio logic.
* **Master Persistence:** The build remembers *everything* across restarts (Fidelity vs Performance preference, HD upscaler choice, Tone-mapping algorithm, etc.).

---

## 🌊 Recommended Streaming Ecosystem
This build is designed to be the "Engine" for high-quality streaming apps.

| App | Best For | Why? |
| :--- | :--- | :--- |
| **Stremio** | **Movies, TV & Anime** | The ultimate hub. Supports 4K HDR, Dolby Vision, and real-time torrent streaming. |
| **Hayase / Shiru** | **Anime Only** | Dedicated Anime clients with **Anilist/MAL sync**. Tracks progress automatically. |

**How to Set MPV as External Player:**
* **Stremio:** Settings → Player → Enable **"Play in external player"**.
* **Hayase / Shiru:** Settings → Player Settings → Select your `mpv.exe`.

---

## ⌨️ Master Controls & Shortcuts

| Shortcut | Function |
| :--- | :--- |
| `K` | **Show Profile Info** (Displays current Mode, Profile, and Active Shaders) |
| `I` | **Show Tech Stats** (Bitrate, Dropped Frames, Logic Status) |
| `A` | **Audio Mode** (Toggle between **7.1 Upmix** and **Passthrough/Bitstream**) |
| `H` | **HDR Mode** (Manual Override: Force Passthrough vs Tone Mapping) |
| `V` | **Nvidia VSR** (Toggle RTX Video Super Resolution - Windows Only) |
| `Q` | **Master Upscaler Toggle** (SD/HD Logic Switch: NNEDI3 ↔ FSRCNNX) |
| `CTRL + q` | **SD Only:** Toggle **Clean** ↔ **Texture** mode (Requires NNEDI3). |
| `CTRL + k` | **Toggle Adaptive Sharpen** (ON/OFF). |
| `CTRL + g` | **Master Shader Killswitch.** Disables all AI processing for raw playback. |
| `CTRL + p` | **Toggle Power Saving Mode** manually. |
| `F5` / `F6` | **Window Screenshot / Clean Video-Frame Screenshot** |
| `y` | **Cycle Sub Video Data** (None / Aspect / All) - Fixes subtitle scaling issues. |

### Anime Pipeline Overrides
| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| `CTRL + l` | **AUTO** | Detects based on folder path & keywords (Default) |
| `CTRL + ;` | **ON** | Force anime shaders for all content |
| `CTRL + '` | **OFF** | Disable anime shaders completely |
| `L` | **Anime4K Quality** | Toggle Anime4K **FAST** ↔ **HQ** |
| `CTRL + 1-6` | **Anime4K Modes** | Cycle between Modes A, B, C, AA, BB, CA |

---

## 💻 System Requirements & Installation

### Minimum (1080p Playback)
* **GPU:** NVIDIA GTX 960 / AMD RX 560 or better (2GB+ VRAM)
* **CPU:** Quad-core Intel/AMD CPU
* **RAM:** 8GB

### Recommended (4K Upscaling + SVP)
* **GPU:** NVIDIA RTX 3060 / AMD RX 6600 or better (6GB+ VRAM)
* **CPU:** Modern 6-core CPU (Ryzen 5 3600 / Intel i5-10400 or newer)
* **RAM:** 16GB

### Installation
1. **Install MPV:** Download the latest 64-bit version of MPV (shinchiro builds recommended).
2. **Install SVP 4 Pro (Optional):** Ensure SVP is installed if you want motion interpolation.
3. **Copy Files:** Extract the contents of this build into your `%APPDATA%/mpv/` folder (Windows) or `~/.config/mpv` (Linux).
4. **Fonts:** Install `Source Sans Pro` (included) to ensure the Stats overlay renders correctly.

### User overrides and remembered menu settings
Settings changed in **UOSC → Controls** are saved outside the tracked defaults, so updating the build does not reset them. The HDR display mode, target peak, and tone-mapping choice use the same override layer.

* User files must be named `user-<custom-name>.conf`; `<custom-name>` can be any non-empty name.
* If no user file exists, the first remembered change creates `user-settings.conf`.
* Multiple user files are loaded alphabetically. Later files override earlier files, and the last file is updated when a menu choice is saved.
* Built-in script defaults and `mpv.conf` remain the fallback when a setting has no user override.

---

## 📸 Gallery, Visual Comparisons & Tech Verification

### 🔹 UI & Smart Features
| Main Menu | Advanced Controls |
| :---: | :---: |
| ![Menu](screenshots/ui6.jpg) | ![Controls](screenshots/ui7.jpg) |

| OP Detected | ED Detected | Skipped |
| :---: | :---: | :---: |
| ![OP](screenshots/ui2.jpg) | ![ED](screenshots/ui9.jpg) | ![Skipped](screenshots/ui4.jpg) |

### 🔹 Anime Pipeline
| Live Action Mode (Anime OFF) | Anime Mode (Anime4K ON) |
| :---: | :---: |
| ![Anime Off](screenshots/anime-off.jpg) | ![Anime On](screenshots/anime-on.jpg) |

| Anime4K (Art Style) | Fidelity (Purist) |
| :---: | :---: |
| ![Anime4K](screenshots/anime-new-auto-anime4k.jpg) | ![Fidelity](screenshots/anime-new-auto-fsr.jpg) |

### 🔹 Live Action Pipeline
| HD: NNEDI3 (Auto Default) | HD: FSRCNNX (Manual HQ) |
| :---: | :---: |
| ![HD NNEDI3](screenshots/hd-nnedi.jpg) | ![HD FSRCNNX](screenshots/hd-fsrcnnx.jpg) |

| SD: Clean Mode | SD: Texture Mode |
| :---: | :---: |
| ![SD Clean](screenshots/sd-clean.jpg) | ![SD Texture](screenshots/sd-texture.jpg) |

### 🔹 Nvidia VSR (RTX AI Upscaling)
| RTX VSR Active (Green OSD) |
| :---: |
| ![RTX VSR](screenshots/rtx-vsr-on.jpg) |

### 🔹 Shader Verification (Proof of Logic)
<details>
<summary><b>🔻 Click to View Shader Chains</b></summary>

**Anime Mode**
| Auto (Default) | Manual Off |
| :---: | :---: |
| ![Info Auto](screenshots/shaders-info-anime-mode-auto.jpg) | ![Info Off](screenshots/shaders-info-anime-mode-off.jpg) |

**Live Action (HD)**
| NNEDI3 Chain | FSRCNNX Chain |
| :---: | :---: |
| ![Info NNEDI](screenshots/shaders-info-live-action-hd-nnedi-auto.jpg) | ![Info FSRCNNX](screenshots/shaders-info-live-action-hd-fsrcnnx-auto.jpg) |

**Live Action (SD)**
| Clean Chain | Texture Chain |
| :---: | :---: |
| ![Info Clean](screenshots/shaders-info-live-action-sd-clean-auto.jpg) | ![Info Texture](screenshots/shaders-info-live-action-sd-texture-auto.jpg) |

**4K Content (Native)**
| 4K Native Pipeline |
| :---: |
| ![Info 4K](screenshots/shaders-info-live-action-4k-auto.jpg) |

**Nvidia VSR (Manual)**
| VSR Active | Detail View |
| :---: | :---: |
| ![VSR Stats 1](screenshots/rtx-vsr-stats1.jpg) | ![VSR Stats 2](screenshots/rtx-vsr-stats2.jpg) |

</details>

---

## 📝 Credits
* **Anime4K:** bloc97
* **Anime4K-Ultra:** Th-Underscore
* **UOSC Skin:** tomasklaen
* **Thumbfast:** po5
* **Up Next Script:** @WaruiDevil (Telegram User)
* **Shaders:** bloc97 (Anime4K), igv (FSRCNNX), bjin (KrigBilateral)
* **Equalizer:** DonCanjas
* **mpv-youtube-download:** cvzi
* **Config & Logic:** Customized and built by Chinna95P
