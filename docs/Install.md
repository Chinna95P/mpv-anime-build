
# 📥 MPV Anime Build – Installation Guide

This guide is designed for users who are **new to MPV** or just want a **simple copy-paste setup** for high-quality anime and movie playback.

> **ℹ️ Note: Auto-Detection Logic (v2.0)**
> This build is smart. It detects Anime automatically if:
> 1.  **Audio:** The file has a **Japanese Audio Track** (e.g., `jpn`).
> 2.  **Folder:** The folder path contains **`anime`** (case-insensitive).
> 3.  **Live Action:** It defaults to Live Action for everything else (or if metadata contains `drama`/`live action`).
---

## ✅ Requirements

### Mandatory
- **OS:** Windows 10/11 **OR** Linux (most distributions)
- **Player:** [MPV 0.35 or newer](https://mpv.io/installation/)
- **Hardware:** A dedicated GPU is highly recommended (NVIDIA GTX 1050 / AMD RX 560 or better) for Anime4K and NNEDI3 upscaling.

### Optional (Supported)
- **Motion Interpolation:** [SVP 4 Pro](https://www.svp-team.com/) (Fully compatible on Win/Linux)
- **Text Editor:** - *Windows:* [Notepad++](https://notepad-plus-plus.org/)
  - *Linux:* VS Code, Gedit, or Nano

---

## 🚀 Installation Steps

### Step 1: Download
1. Click the green **Code** button at the top of this page.
2. Select **Download ZIP**.
3. Extract the folder anywhere (e.g., your Desktop/Home).

---

### Step 2: Locate Config Folder

Depending on your Operating System, MPV stores configuration files in different locations.

#### 🪟 For Windows Users
1. Press `Win + R` on your keyboard.
2. Type `%APPDATA%\mpv\` and press **Enter**.
   - *If the folder doesn't exist, navigate to `%APPDATA%` and create a new folder named `mpv`.*

#### 🐧 For Linux Users
1. Open your File Manager (Nautilus, Dolphin, Thunar, etc.).
2. Enable **"Show Hidden Files"** (usually `Ctrl+H`).
3. Navigate to `~/.config/mpv/` (Home -> .config -> mpv).
   - *If the folder doesn't exist, create it.*
   - *Terminal shortcut:* `mkdir -p ~/.config/mpv/`

---

### Step 3: Copy Files
Copy the contents of the downloaded folder **into** the config folder you opened in Step 2.

Your final folder structure should look exactly like this:

#### Windows Path Structure
```text
C:\Users\<Name>\AppData\Roaming\mpv\
├── fonts/               # Required fonts for OSD
├── script-opts/         # Configuration for scripts
├── scripts/             # Lua automation scripts
├── shaders/             # Anime4K & Modern TV shaders
├── input.conf           # Keybindings
└── mpv.conf             # Main settings

```

#### Linux Path Structure

```text
/home/<username>/.config/mpv/
├── fonts/
├── script-opts/
├── scripts/
├── shaders/
├── input.conf
└── mpv.conf

```

### Optional: Keep Personal MPV Options Update-Safe

Create exactly one `mpv-<custom-name>.conf` file in the same folder as `mpv.conf` when you want to override the build defaults without editing the shipped file.

Example: `mpv-personal.conf`

```conf
fullscreen=no
volume=80
```

The custom file loads after `mpv.conf`, so its duplicate values take precedence. Add only the options you want to change. This works on Windows and Linux.

> [!IMPORTANT]
> Keep only one `mpv-*.conf` file in the config folder. If multiple matching files are found, the build safely loads none of them and shows a warning.

This is separate from `user-<custom-name>.conf`, which stores remembered Anime Build menu choices rather than general MPV options.

---

### Step 4: Verify

1. Open any video file with MPV.
2. The player should start without errors.
3. Press **`K`** on your keyboard.

* You should see a status message (e.g., "Anime Mode: AUTO") appear for 2 seconds.

---

## 🧪 Common Beginner Checks

| Action | Expected Result |
| --- | --- |
| **Play Anime file** | Anime4K shaders apply automatically. |
| **Play Movie/Live Action** | Switches to High-Quality / "Modern TV" mode. |
| **Press `K**` | Shows current profile and active shaders. |
| **Press `L**` | Toggles Anime4K between **Fast** and **HQ**. |

---

## ❓ Troubleshooting

**Nothing changes when I play a video?**

* **Windows:** Ensure you pasted files into `AppData\Roaming\mpv`, **NOT** the folder where `mpv.exe` is installed.
* **Linux:** Ensure you are using `~/.config/mpv/` and not `/etc/mpv/` (unless you know what you are doing with system-wide configs).

**The OSD looks weird or shows codes like `{\c&H...}`?**

* Restart MPV completely. Scripts load only on startup.

**Stuttering or Lag?**

* This build is GPU-intensive. If you have a weak GPU:

1. Open `mpv.conf`.
2. Change `profile=High-Quality` to `profile=Low-Quality`.
3. Change `vo=gpu-next` to `vo=gpu`.

---

## 🆘 Need Help?

If you encounter bugs or errors, please open an issue on the [GitHub Issues page](https://github.com/Chinna95P/mpv-anime-build/issues).

```

```
