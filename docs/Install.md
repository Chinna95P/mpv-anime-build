
# 📥 MPV Anime Build – Installation Guide

This guide is designed for users who are **new to MPV** or just want a **simple copy-paste setup** for high-quality anime and movie playback.

---

## ✅ Requirements

### Mandatory
- **OS:** Windows 10 / 11
- **Player:** [MPV 0.35 or newer](https://mpv.io/installation/)
- **Hardware:** A dedicated GPU is highly recommended (NVIDIA GTX 1050 / AMD RX 560 or better) for Anime4K and NNEDI3 upscaling.

### Optional (Supported)
- **Motion Interpolation:** [SVP 4 Pro](https://www.svp-team.com/) (Fully compatible)
- **Text Editor:** [Notepad++](https://notepad-plus-plus.org/) (Recommended for editing configs)

---

## 🚀 Installation Steps

### Step 1: Download
1. Click the green **Code** button at the top of this page.
2. Select **Download ZIP**.
3. Extract the folder anywhere (e.g., your Desktop).

### Step 2: Locate Config Folder
MPV looks for configuration files in a specific hidden folder.
1. Press `Win + R` on your keyboard.
2. Type `%APPDATA%\mpv\` and press **Enter**.
   - *If the folder doesn't exist, create a new folder named `mpv` inside `%APPDATA%`.*

### Step 3: Copy Files
Copy the contents of the downloaded folder **into** the `%APPDATA%\mpv\` folder.

Your final folder structure should look exactly like this:
```text
C:\Users\<YourName>\AppData\Roaming\mpv\
├── fonts/               # Required fonts for OSD
├── script-opts/         # Configuration for scripts
├── scripts/             # Lua automation scripts
├── shaders/             # Anime4K & Modern TV shaders
├── input.conf           # Keybindings
└── mpv.conf             # Main settings

```

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

* Ensure you pasted the files into `AppData\Roaming\mpv`, **NOT** the folder where `mpv.exe` is installed.

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
