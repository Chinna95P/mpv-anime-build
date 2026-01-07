# 🎬 MPV Anime Build

> **Anime-aware MPV configuration with automatic Anime4K, NNEDI, and SD/HD pipelines — zero manual profile switching.**

This project is a **fully automated MPV configuration** designed primarily for **anime playback**, while keeping **live-action and non-anime content fully isolated** and optimized.

The goal is simple:  
**MPV decides the correct profile automatically — you only fine-tune when you want to.**

---

## 📌 Key Features

- 🎯 Automatic **anime vs non-anime detection**
- 🧠 Global **Anime Mode** (AUTO / ON / OFF)
- 🖌️ Anime-only **Anime4K** (Fast & HQ, multiple modes)
- 📺 Resolution-aware **SD / HD / NNEDI** pipelines
- 🧼 Clean, **non-persistent OSD**
- 💾 Persistent settings across restarts
- 🎞️ **SVP-compatible**
- 📄 Full illustrated **PDF manual + cheat sheet**

---

## 👤 Who This Is For

✔ Anime watchers  
✔ Mixed anime + live-action libraries  
✔ Users who hate manual profile switching  
✔ Power users who still want full control  

❌ Not intended for very low-end GPUs

---

## ⚡ Quick Start

1. Copy the files into:
C:\Users<YourName>\AppData\Roaming\mpv\

2. Open any video in MPV
3. Anime is detected automatically
4. Press **K** to see the active profile (2 seconds)
5. Use shortcuts only if you want to fine-tune

That’s it.

---

## 🔹 Anime Mode (Global Control)

Anime Mode decides **when anime shaders are allowed to run**.

| Shortcut | Mode | Behavior |
|-------|------|--------|
| `CTRL + L` | AUTO | Anime shaders only if anime is detected |
| `CTRL + ;` | ON | Force anime shaders for all content |
| `CTRL + '` | OFF | Disable anime shaders completely |

**AUTO is the recommended default.**

---

## 🔹 Anime4K System (Anime-Only)

Anime4K is applied **only when anime shaders are active**.  
It never affects live-action or non-anime files.

### Anime4K Quality Toggle
L → Toggle Anime4K FAST ↔ HQ


### Anime4K Modes

CTRL + 1 → Mode A (balanced)
CTRL + 2 → Mode B (soft)
CTRL + 3 → Mode C (denoise)
CTRL + 4 → Mode A+A
CTRL + 5 → Mode B+B
CTRL + 6 → Mode C+A


### Recommended Usage
- **TV anime / weekly episodes** → FAST
- **Blu-ray / high-quality anime** → HQ
- **Old / noisy anime** → Mode C or C+A

---

## 🔹 Non-Anime Video Pipeline

Non-anime content uses a **completely separate processing path**.

| Resolution | Pipeline |
|---------|---------|
| `< 720p` | HQ-SD (Clean / Texture) |
| `576p – <1080p` | HQ-HD-NNEDI (Auto) |
| `≥ 1080p` | High-Quality |

### SD Mode Toggle

CTRL + Q → SD Clean ↔ Texture


### NNEDI Control

Q → Force NNEDI
W → Return to Auto NNEDI


---

## ℹ️ OSD & Information

| Shortcut | Action |
|-------|------|
| `K` | Show current profile (2 seconds) |

OSD messages:
- Never persist
- Never loop
- Show only when something changes or is requested

---

## 🔊 Audio Enhancements

| Shortcut | Function |
|-------|---------|
| `M` | 7.1 virtual surround |
| `A` | Dynamic audio normalization |

---

## 🛡️ Design Guarantees

- Anime shaders **never leak** into non-anime
- Shader chains are cleared safely before switching
- No profile reapplication loops
- No persistent OSD clutter
- No background services required
- Works with or without SVP

---

## 📄 Documentation

- 📘 **Full Illustrated Manual (PDF)**  
  `docs/MPV_Full_Readme_Illustrated.pdf`
- ⚡ **Quick Cheat Sheet (PDF)**  
  `docs/MPV_CheatSheet_Illustrated.pdf`
- 📥 **Beginner Install Guide**  
  `docs/INSTALL.md`
- 🧾 **Changelog**  
  `docs/CHANGELOG.md`

---

## 🔮 Roadmap (v1.1)

Planned improvements:
- Smarter anime detection heuristics
- Optional per-anime Anime4K presets
- Performance optimizations for low-end GPUs
- Optional modular install (lite / full)

No breaking changes planned.

---

## 📜 License

MIT License  
© 2026 Rohith Polamreddy

---

## ⭐ If This Helped You

- Star ⭐ the repository
- Share it with other MPV users
- Open issues or suggestions — feedback is welcome
