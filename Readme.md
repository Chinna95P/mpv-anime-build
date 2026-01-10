# 🎬 MPV Anime Build v1.3.2

> **Anime-aware MPV configuration with automatic Anime4K, NNEDI3, and "Modern TV" upscaling — zero manual profile switching.**

### ⚠️ Important: How Automatic Detection Works
For the auto-switching logic to function correctly, your files must follow these simple naming rules:
1.  **Anime:** The file path or folder name MUST contain the keyword **`anime`** (case-insensitive).
    * *Example:* `D:\Media\Anime\One Piece\video.mkv` -> **Activates Anime4K**
2.  **Live Action:** Any file path *without* the word 'anime' is automatically treated as Live Action.
3.  **Exceptions:** To play Live Action content located *inside* an Anime folder, the filename must contain **`live action`**, **`live-action`**, **`liveaction`**, or **`drama`**.

---

This project is a **fully automated MPV configuration** designed primarily for **anime playback**, while keeping **live-action and non-anime content fully isolated** and optimized.

It features a beautiful **ModernZ** skin interface and complete support for **SVP 4 Pro** motion interpolation.

The goal is simple:
**MPV decides the correct profile automatically — you only fine-tune when you want to.**

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

## 📌 Key Features (v1.3.2)

- 🎯 **Smart Detection:** Automatic anime vs. live-action isolation.
- 🎨 **Professional OSD:** Color-coded status overlay (Green/Blue/Red) via `anime_profile_controller`.
- 🧠 **Logic Lockdown:** Strict resolution gates prevent profiles from firing on the wrong content (SD is strictly < 576p).
- 🖥️ **Modern UI:** Pre-configured with the **ModernZ** skin for a sleek look.
- 🖌️ **Anime Pipeline:** Full **Anime4K** suite (Fast & HQ modes).
- 📺 **Live-Action Pipeline:** "Modern TV" style upscaling (Sony/Samsung emulation).
- 🧩 **Subtitle Correction:** Updated manual correction toggle (`y`) to use modern `sub-ass-use-video-data` for reliable aspect ratio handling.
- 💾 **SVP 4 Pro Support:** Verified compatibility with Smooth Video Project.
- ⚡ **Thumbfast Stability:** Optimized thumbnail generation with improved socket handling.

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

## 🎮 Controls & Shortcuts

### 🔹 Global Controls
| Shortcut | Function |
| :--- | :--- |
| `K` | **Show Profile Info** (Displays current Mode, Profile, and Active Shaders) |
| `I` | **Show Tech Stats** (Bitrate, Dropped Frames, Logic Status) |
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