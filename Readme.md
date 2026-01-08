# 🎬 MPV Anime Build v1.2

> **Anime-aware MPV configuration with automatic Anime4K, NNEDI3, and "Modern TV" upscaling — zero manual profile switching.**

This project is a **fully automated MPV configuration** designed primarily for **anime playback**, while keeping **live-action and non-anime content fully isolated** and optimized.

It features a beautiful **ModernZ** skin interface and complete support for **SVP 4 Pro** motion interpolation.

The goal is simple:
**MPV decides the correct profile automatically — you only fine-tune when you want to.**

---

## 📌 Key Features (v1.2)

- 🎯 **Smart Detection:** Automatic anime vs. live-action isolation
- 🎨 **Professional OSD:** New color-coded status overlay (Green/Blue/Red indicators)
- 🖥️ **Modern UI:** Pre-configured with the **ModernZ** skin for a sleek look
- 🖌️ **Anime Pipeline:** Full **Anime4K** suite (Fast & HQ modes)
- 📺 **Live-Action Pipeline:** "Modern TV" style upscaling (Sony/Samsung emulation)
- 💾 **SVP 4 Pro Support:** Fully compatible with Smooth Video Project
- ⚡ **Adaptive Sharpening:** Custom shaders for 480p, 720p, and 1080p
- 🧼 **Clean OSD:** Non-intrusive status messages using the Overlay API

---

## 💻 System Requirements

This build scales based on your hardware, but high-quality upscaling (NNEDI3/FSRCNNX) is demanding.

| Component | Minimum (1080p Playback) | Recommended (4K / High-Quality Upscaling) |
| :--- | :--- | :--- |
| **OS** | Windows 10 / 11 | Windows 10 / 11 |
| **GPU** | Intel UHD 630 / AMD Vega 8<br>*(Use Low-Quality Profile)* | **NVIDIA GTX 1060 / AMD RX 580** or better<br>*(Required for Anime4K HQ & FSRCNNX)* |
| **CPU** | Modern Quad-Core | Modern Hex-Core (Ryzen 5 / i5) |
| **RAM** | 8 GB | 16 GB |

> **Note:** If you experience stuttering, switch to the "Low-Quality" profile in `mpv.conf`.

---

## ⚡ Quick Start

1. Copy the files into: `C:\Users\<YourName>\AppData\Roaming\mpv\`
2. Open any video in MPV.
3. Anime is detected automatically.
4. Press **K** to see the active profile (Displays for 2 seconds).

---

## 🔹 Anime Mode (Global Control)

Anime Mode decides **when anime shaders are allowed to run**.

| Shortcut | Mode | Behavior | OSD Color |
| :--- | :--- | :--- | :--- |
| `CTRL + L` | **AUTO** | Anime shaders only if anime is detected (Default) | **GREEN** |
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

---

## 🔹 Live-Action Pipeline

Non-anime content uses a **completely separate processing path** featuring "Modern TV" adaptive sharpening.

| Resolution | Profile | Technology |
| :--- | :--- | :--- |
| **< 720p** | `HQ-SD` | SSimSuperRes + Adaptive Sharpen (SD Tuned) |
| **720p – <1080p** | `HQ-HD` | NNEDI3 + KrigBilateral + Adaptive Sharpen (HD Tuned) |
| **≥ 1080p** | `High-Quality` | FSRCNNX + Film Grain + "Modern TV" Sharpening |

### 🛠️ Live-Action Controls
| Shortcut | Function | OSD Color |
| :--- | :--- | :--- |
| `CTRL + Q` | Toggle **SD Mode** (Clean ↔ Texture) | **ORANGE** |
| `Q` | Force **NNEDI3** Upscaling | **GOLD** |
| `W` | Return to **Auto** Logic | **GREEN** |

---

## ℹ️ OSD & Information

| Shortcut | Action |
| :--- | :--- |
| `K` | Show current profile status |

---

## 📜 License

MIT License
© 2026 Rohith Polamreddy