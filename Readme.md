# 🎬 MPV Anime Build v1.1

> **Anime-aware MPV configuration with automatic Anime4K, NNEDI3, and "Modern TV" upscaling — zero manual profile switching.**

This project is a **fully automated MPV configuration** designed primarily for **anime playback**, while keeping **live-action and non-anime content fully isolated** and optimized.

The goal is simple:
**MPV decides the correct profile automatically — you only fine-tune when you want to.**

---

## 📌 Key Features (v1.1)

- 🎯 **Smart Detection:** Automatic anime vs. live-action isolation
- 🧠 **Global Anime Mode:** AUTO / ON / OFF
- 🖌️ **Anime Pipeline:** Full **Anime4K** suite (Fast & HQ modes)
- 📺 **Live-Action Pipeline:** New **"Modern TV"** style upscaling (Sony/Samsung emulation)
- ⚡ **Adaptive Sharpening:** Custom shaders for 480p, 720p, and 1080p
- 🧼 **Clean OSD:** Non-intrusive status messages
- 💾 **Persistent:** Settings save across restarts
- 🎞️ **SVP-Compatible:** Works alongside Smooth Video Project

---

## ⚡ Quick Start

1. Copy the files into: `C:\Users\<YourName>\AppData\Roaming\mpv\`
2. Open any video in MPV
3. Anime is detected automatically
4. Press **K** to see the active profile (2 seconds)

---

## 🔹 Anime Mode (Global Control)

Anime Mode decides **when anime shaders are allowed to run**.

| Shortcut | Mode | Behavior |
| :--- | :--- | :--- |
| `CTRL + L` | **AUTO** | Anime shaders only if anime is detected (Default) |
| `CTRL + ;` | **ON** | Force anime shaders for all content |
| `CTRL + '` | **OFF** | Disable anime shaders completely |

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

## 🔹 Live-Action Pipeline (New in v1.1)

Non-anime content uses a **completely separate processing path** featuring new "Modern TV" adaptive sharpening.

| Resolution | Profile | Technology |
| :--- | :--- | :--- |
| **< 720p** | `HQ-SD` | SSimSuperRes + Adaptive Sharpen (SD Tuned) |
| **720p – <1080p** | `HQ-HD` | NNEDI3 + KrigBilateral + Adaptive Sharpen (HD Tuned) |
| **≥ 1080p** | `High-Quality` | FSRCNNX + Film Grain + "Modern TV" Sharpening |

### 🛠️ Live-Action Controls
| Shortcut | Function |
| :--- | :--- |
| `CTRL + Q` | Toggle **SD Mode** (Clean ↔ Texture Masking) |
| `Q` | Force **NNEDI3** Upscaling |
| `W` | Return to **Auto** Logic |

---

## ℹ️ OSD & Information

| Shortcut | Action |
| :--- | :--- |
| `K` | Show current profile status |

---

## 📜 License

MIT License
© 2026 Rohith Polamreddy