# 🎬 MPV Anime Build v1.3

> **Anime-aware MPV configuration with automatic Anime4K, NNEDI3, and "Modern TV" upscaling — zero manual profile switching.**

This project is a **fully automated MPV configuration** designed primarily for **anime playback**, while keeping **live-action and non-anime content fully isolated** and optimized.

It features a beautiful **ModernZ** skin interface and complete support for **SVP 4 Pro** motion interpolation.

The goal is simple:
**MPV decides the correct profile automatically — you only fine-tune when you want to.**

---

## 📌 Key Features (v1.3)

- 🎯 **Smart Detection:** Automatic anime vs. live-action isolation.
- 🎨 **Professional OSD:** Color-coded status overlay (Green/Blue/Red) via `anime_profile_controller`.
- 🧠 **Logic Lockdown:** Strict resolution gates prevent profiles from firing on the wrong content (SD is strictly < 576p).
- 🖥️ **Modern UI:** Pre-configured with the **ModernZ** skin for a sleek look.
- 🖌️ **Anime Pipeline:** Full **Anime4K** suite (Fast & HQ modes).
- 📺 **Live-Action Pipeline:** "Modern TV" style upscaling (Sony/Samsung emulation).
- 🧩 **Subtitle Correction:** Automatic anti-stretching logic for `.ass` (text) and `.sup` (image) subtitles.
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
| `y` | **Toggle Image Sub Stretch** (Fixes stretched PGS/VobSub subtitles) |

### 🔹 Anime Mode (Master Switch)
Controls whether the build treats the file as Anime or Live-Action.

| Shortcut | Mode | Description | OSD Color |
| :--- | :--- | :--- | :--- |
| `CTRL + ;` | **AUTO** | Detects based on folder path & keywords (Default) | **GREEN** |
| `CTRL + :` | **ON** | Force anime shaders for all content | **BLUE** |
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

### Resolution Tiers (v1.3 Logic)
| Resolution | Profile | Technology |
| :--- | :--- | :--- |
| **< 576p** | `HQ-SD` | SSimSuperRes + Adaptive Sharpen (SD Tuned) |
| **576p – <1080p** | `HQ-HD` | NNEDI3 + KrigBilateral + Adaptive Sharpen (HD Tuned) |
| **≥ 1080p** | `High-Quality` | Native + Adaptive Sharpen + Glaze (Film Grain) |

### 🎮 Controls
| Shortcut | Context | Function |
| :--- | :--- | :--- |
| `CTRL + Q` | **SD Only** | Toggle **Clean** ↔ **Texture** mode. <br>*(Texture mode preserves grain/noise for older DVDs)* |
| `Q` | **HD Only** | Toggle **NNEDI3 (Auto)** ↔ **FSRCNNX (Manual High-Quality)**. <br>*(Switches logic between Geometry-focused and Texture-focused upscaling)* |

> **Note:** The shortcuts `Q` and `Ctrl+Q` are **smart**. They will not activate if you are playing content that doesn't match their resolution tier.

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
- **Config & Logic:** Customized for MPV Anime Build v1.3