# 🎬 MPV Anime Build v3.2
> **The Performance & Audio Update: Ultimate Playback, Smart Automation, and Unmatched Fidelity.**

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-7289da?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Pvf3huxFvU)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Chinna95P/mpv-anime-build)

> **An advanced, context-aware MPV configuration featuring AI upscaling, dynamic power management, universal HDR support, and intelligent audio processing.**

### 📱 Android Support Available
The MPV Anime Build is also available for **Android (mpvEX / Aniyomi)**!
* **Features:** Gesture Controls, Smart Auto-Detection, and Optimized Shaders for mobile.
* **Download:** Switch to the [**Android Branch**](https://github.com/Chinna95P/mpv-anime-build/tree/android) to get the mobile-specific files.

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
A smart power manager designed for laptops and portable devices.
* **Auto-Eco:** Unplugging your laptop instantly disables high-end shaders (Anime4K/FSRCNNX) and locks them out, switching to a `[Low-End]` bilinear profile to save battery.
* **Auto-Restore:** Plugging it back in instantly restores your exact previous High-Quality profile.
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
If you disable shaders (`CTRL+g`), MPV falls back to these high-end native scalers:
* **`ewa_lanczossharp`:** Best general upscaler. Sharp but clean.
* **`spline64`:** Best downscaler (watching 4K on 1080p) and best Chroma scaler.
* **`mitchell`:** Best for soft, smooth images to hide compression artifacts.

---

## 🎵 The Audio & HDR Engine

### Professional Audio
* **Audio-Only Mode [v3.0]:** Instantly drops GPU load to 0% for music playback, showing embedded album art and dynamic visualizers.
* **Spatial Audio:** Uses HRTF-based virtual surround to simulate a 7.1 cinema experience on standard stereo headphones.
* **Night Mode:** Applies Dynamic Range Compression (DRC) to lower explosions and boost whispers for late-night viewing.
* **Passthrough/Bitstream:** Send raw TrueHD/DTS-X to your AVR with a single click (`A`).

### True HDR & Dolby Vision
Automatically detects your monitor's capabilities via Windows.
* **Windows HDR ON:** Activates **True Passthrough**. Sends raw metadata directly to your TV.
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
* **UOSC Skin:** tomasklaen
* **Thumbfast:** po5
* **Up Next Script:** @WaruiDevil (Telegram User)
* **Shaders:** bloc97 (Anime4K), igv (FSRCNNX), bjin (KrigBilateral)
* **Equalizer:** DonCanjas
* **Config & Logic:** Customized and built by Chinna95P