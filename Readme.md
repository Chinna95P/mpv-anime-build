# 🎬 MPV Anime Build v1.5

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-7289da?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Pvf3huxFvU)

> **Anime-aware MPV configuration with automatic Anime4K, Nvidia VSR, and Universal HDR support — zero manual profile switching.**

### ⚠️ Important: How Automatic Detection Works
For the auto-switching logic to function correctly, your files must follow these simple naming rules:
1.  **Anime:** The file path or folder name MUST contain the keyword **`anime`** (case-insensitive).
    * *Example:* `D:\Media\Anime\One Piece\video.mkv` -> **Activates Anime4K**
2.  **Live Action:** Any file path *without* the word 'anime' is automatically treated as Live Action.
3.  **Exceptions:** To play Live Action content located *inside* an Anime folder, the filename must contain **`live action`**, **`live-action`**, **`liveaction`**, or **`drama`**.

---


## [v1.5] – The "Universal & SVP" Update

### ✨ New Features
* **Universal Linux Support:** The build is now 100% compatible with Linux (Wayland/X11).
    * **Dual-OS Config:** `mpv.conf` now automatically detects your OS. It loads `d3d11` for Windows and `vulkan` for Linux without needing manual edits.
    * **Script Safety:** `vsr_auto.lua` and `hdr_detect.lua` now include OS-checks to prevent Windows-only commands (like VSR) from crashing Linux.
    * **Universal Paths:** Updated all shader paths and script logic to work with both Windows (`%APPDATA%`) and Linux (`~/.config/mpv`) directory structures.
* **SVP 4 Pro Compatibility Mode:**
    * **The Fix:** Enforced `hwdec=auto-copy` on Windows. This fixes the conflict where Native D3D11 decoding was locking video frames on the GPU, preventing SVP from interpolating them.
    * **Result:** You can now use SVP 4 Pro (Frame Generation) and Nvidia VSR (Upscaling) simultaneously.

### 🐛 Fixed
* **Shader Syntax:** Replaced `glsl-shaders-set="..."` with `glsl-shaders-append`. This fixes a critical bug where Linux would fail to parse multiple shaders if they were separated by semicolons (`;`).
* **VSR Logic:** Updated `vsr_auto.lua` to smartly restore your previous specific shader profile (Anime vs Live Action) when disabled, instead of just resetting to default.

---


## 🌟 New in v1.4: Universal HDR & VSR

### 📺 Universal HDR/Dolby Vision Support
This build now automatically detects your monitor's capabilities via Windows.

* **For HDR/OLED TVs:** Enable **"Use HDR"** in Windows Display Settings. MPV will detect this and automatically switch to **Passthrough Mode** (sending the raw HDR signal to your TV).
* **For SDR Monitors:** Leave Windows HDR **OFF**. MPV will apply high-quality **HDR-to-SDR Tone Mapping** (Spline) to make colors look correct and vibrant on standard screens.
* **Manual Override:** Press **`H`** at any time to toggle between Passthrough (TV) and Tone Mapping (SDR) manually when playing HDR.
* **Dolby Vision:** Plays correctly on all devices. If your display does not support Dolby Vision, MPV automatically **falls back to the HDR10 Base Layer**.

### 🚀 Nvidia VSR Automation (RTX Only)
Press **`V`** to toggle **Nvidia Video Super Resolution**. The build uses a smart script to prevent color banding:
* **10-bit Video (Anime/HDR):** Uses `P010` format to preserve high-precision colors.
* **8-bit Video (Web/YouTube):** Uses `NV12` format for maximum compatibility.

---

## 📸 Gallery & Visual Comparisons

### 🔹 Anime Pipeline (Automated)
Left: **Standard Playback (Red OSD)** | Right: **Anime Mode Active (Green OSD)**
*Logic detects Anime content and applies Anime4K upscaling & restoration.*

| **Live Action Mode (Anime OFF)** | **Anime Mode (Anime4K ON)** |
| :---: | :---: |
| ![Anime Off](screenshots/anime-off.jpg) | ![Anime On](screenshots/anime-on.jpg) |

### 🔹 Live Action Pipeline (HD Content)
Comparison of the two high-quality upscaling engines for 720p/1080p content.

| **NNEDI3 (Auto Default)** | **FSRCNNX (Manual HQ)** |
| :---: | :---: |
| ![HD NNEDI3](screenshots/hd-nnedi.jpg) | ![HD FSRCNNX](screenshots/hd-fsrcnnx.jpg) |
| *Best for general viewing & speed* | *Best for maximum texture fidelity* |

### 🔹 Live Action Pipeline (SD Content)
Comparison of restoration modes for DVD-quality (<576p) content.

| **Clean Mode** | **Texture Mode** |
| :---: | :---: |
| ![SD Clean](screenshots/sd-clean.jpg) | ![SD Texture](screenshots/sd-texture.jpg) |
| *Cleans artifacts & noise* | *Preserves original film grain* |

---

## 🤓 Technical Verification (Shaders Info)

Click below to see the active shader chains for each mode (Proof of Logic).

<details>
<summary><b>🔻 Click to View Shader Chains</b></summary>

### Anime Mode
| Auto (Default) | Manual Off |
| :---: | :---: |
| ![Info Auto](screenshots/shaders-info-anime-mode-auto.jpg) | ![Info Off](screenshots/shaders-info-anime-mode-off.jpg) |

### Live Action (HD)
| NNEDI3 Chain | FSRCNNX Chain |
| :---: | :---: |
| ![Info NNEDI](screenshots/shaders-info-live-action-hd-nnedi-auto.jpg) | ![Info FSRCNNX](screenshots/shaders-info-live-action-hd-fsrcnnx-auto.jpg) |

### Live Action (SD)
| Clean Chain | Texture Chain |
| :---: | :---: |
| ![Info Clean](screenshots/shaders-info-live-action-sd-clean-auto.jpg) | ![Info Texture](screenshots/shaders-info-live-action-sd-texture-auto.jpg) |

### 4K Content (Native)
| 4K Native Pipeline |
| :---: |
| ![Info 4K](screenshots/shaders-info-live-action-4k-auto.jpg) |

</details>

---

## 🧪 HDR Behavior & Test Cases (v1.5)

This build features a robust **Auto-Detection System** (`hdr_detect.lua`) that changes behavior based on your monitor's capabilities. Below are the verified test results.

### 1. SDR Display Behavior
*Scenario: Windows HDR is **OFF** (Standard Monitor).*

| Video Content | MPV Action (Auto) | OSD Message | Visual Result |
| :--- | :--- | :--- | :--- |
| **SDR Video** | **Standard Mode** | *(None)* | **Normal Playback.** |
| **HDR Video** | **TONE MAPPING** | `HDR Mode: Tone Mapping` | **Correct Colors.** MPV compresses HDR colors to standard range. Image is vibrant, not washed out. |

### 2. HDR Display Behavior
*Scenario: Windows HDR is **ON** (HDR TV / OLED Monitor).*

| Video Content | MPV Action (Auto) | OSD Message | Visual Result |
| :--- | :--- | :--- | :--- |
| **SDR Video** | **Standard Mode** | *(None)* | **Normal Playback.** Windows handles the container. |
| **HDR Video** | **PASSTHROUGH** | `HDR Mode: Passthrough` | **True HDR.** Metadata is sent to the TV. Highlights are bright and correct. |

### 3. Manual Toggle ('H') Behavior
*Use the `H` (`Shift+h`) shortcut to override the auto-logic.*

| Current State | Toggle Action | Resulting Mode | What Happens? |
| :--- | :--- | :--- | :--- |
| **Any** (SDR Content) | Press `H` | **ERROR** | **Safety Block.** Prevents accidental tone-mapping of non-HDR content. |
| **Passthrough** | Press `H` | **Force TONE MAP** | **Simulated SDR.** Stops sending metadata. Useful if your TV's native HDR processing looks dark or buggy. |
| **Tone Mapping** | Press `H` | **Force PASSTHROUGH** | **Force HDR Output.** <br>• On HDR Screens: Activates max brightness.<br>• On SDR Screens: **Washed Out Colors** (Grey/Foggy look). |

---

## 📌 Key Features (v1.4)

- 🎯 **Smart Detection:** Automatic anime vs. live-action isolation.
- 🌈 **Universal HDR:** Auto-switching between Passthrough and Tone Mapping (Manual Toggle: **`H`**).
- 🚀 **Nvidia VSR:** Smart automation with bit-depth protection (Manual Toggle: **`V`**).
- 🎨 **Professional OSD:** Color-coded status overlay (Green/Blue/Red).
- 🧠 **Logic Lockdown:** Strict resolution gates prevent profiles from firing on the wrong content.
- 🖥️ **Modern UI:** Pre-configured with the **ModernZ** skin.
- 🖌️ **Anime Pipeline:** Full **Anime4K** suite (Fast & HQ modes).
- 📺 **Live-Action Pipeline:** "Modern TV" style upscaling (Sony/Samsung emulation).
- 🔊 **Smart Audio:** Manual toggle for 7.1 Upmix vs. TrueHD/DTS-X Passthrough (Toggle: **`A`**).

---

## 💻 System Requirements

This build scales based on your hardware, but high-quality upscaling requires a decent GPU.

### **Minimum (1080p Playback)**
- **GPU:** NVIDIA GTX 960 / AMD RX 560 or better (2GB+ VRAM)
- **CPU:** Quad-core Intel/AMD CPU
- **RAM:** 8GB
- **Storage:** SATA SSD

### **Recommended (4K Upscaling + SVP)**
- **GPU:** NVIDIA RTX 3060 / AMD RX 6600 or better (6GB+ VRAM)
- **CPU:** Modern 6-core CPU (Ryzen 5 3600 / Intel i5-10400 or newer)
- **RAM:** 16GB
- **Storage:** NVMe SSD

---

### 🔹 Global Controls
| Shortcut | Function |
| :--- | :--- |
| `K` | **Show Profile Info** (Displays current Mode, Profile, and Active Shaders) |
| `I` | **Show Tech Stats** (Bitrate, Dropped Frames, Logic Status) |
| `A` | **Audio Mode** (Toggle between **7.1 Upmix** and **Passthrough/Bitstream**) |
| `H` | **HDR Mode** (Manual Override: Force Passthrough vs Tone Mapping) |
| `V` | **Nvidia VSR** (Toggle RTX Video Super Resolution) |
| `y` | **Cycle Sub Video Data** (None / Aspect / All) - Fixes subtitle scaling issues |

### 🔹 Anime Mode (Master Switch)
Controls whether the build treats the file as Anime or Live-Action.

| Shortcut | Mode | Description | OSD Color |
| :--- | :--- | :--- | :--- |
| `CTRL + l` | **AUTO** | Detects based on folder path & keywords (Default) | **GREEN** |
| `CTRL + ;` | **ON** | Force anime shaders for all content | **BLUE** |
| `CTRL + '` | **OFF** | Disable anime shaders completely | **RED** |

---

## 🔹 Anime Pipeline (Anime4K)

Anime4K is applied **only when anime shaders are active**. It never affects live-action files.

### 🎮 Controls
| Shortcut | Function |
| :--- | :--- |
| `L` | Toggle Anime4K **FAST** ↔ **HQ** |
| `CTRL + 1` | Mode A (Balanced) |
| `CTRL + 2` | Mode B (Soft) |
| `CTRL + 3` | Mode C (Denoise) |
| `CTRL + 4` | Mode A+A (Ultra Sharp) |
| `CTRL + 5` | Mode B+B (Ultra Soft) |
| `CTRL + 6` | Mode C+A (Denoise + Restore) |

---

## 🔹 Live-Action Pipeline

Non-anime content uses a **completely separate processing path** featuring "Modern TV" adaptive sharpening.

### Resolution Tiers (v1.3.1 Logic)
| Resolution | Profile | Technology |
| :--- | :--- | :--- |
| **< 576p** | `HQ-SD` | SSimSuperRes + Adaptive Sharpen (SD Tuned) |
| **576p – <1080p** | `HQ-HD` | NNEDI3 + KrigBilateral + Adaptive Sharpen (HD Tuned) |
| **≥ 1080p** | `High-Quality` | Native + Adaptive Sharpen + Glaze (Film Grain) |

### 🎮 Controls
| Shortcut | Context | Function |
| :--- | :--- | :--- |
| `CTRL + q` | **SD Only** | Toggle **Clean** ↔ **Texture** mode. <br>*(Texture mode preserves grain/noise for older DVDs)* |
| `Q` | **HD Only** | Toggle **NNEDI3 (Auto)** ↔ **FSRCNNX (Manual High-Quality)**. <br>*(Switches logic between Geometry-focused and Texture-focused upscaling)* |

> **Note:** The shortcuts `Q` and `Ctrl+q` are **smart**. They will not activate if you are playing content that doesn't match their resolution tier.

---

## 🔧 Installation

1. **Install MPV:** Download the latest 64-bit version of MPV (shinchiro builds recommended).
2. **Install SVP 4 Pro:** (Optional) Ensure SVP is installed and running if you want motion interpolation.
3. **Copy Files:** Extract the contents of this build into your `%APPDATA%/mpv/` folder.
4. **Font Installation:** Install `Source Sans Pro` (included) to ensure the Stats overlay renders correctly.

## 📝 Credits
- **Anime4K:** bloc97
- **ModernZ Skin:** Samillion
- **Thumbfast:** po5
- **Config & Logic:** Customized for MPV Anime Build v1.3.2