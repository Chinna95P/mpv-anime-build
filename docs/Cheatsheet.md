---

## 2. `CHEATSHEET.md`

```markdown
# ⚡ MPV Anime Build – Cheat Sheet

A complete reference for all keyboard shortcuts and commands available in this build.

---

## 🎨 Global Profile Controls

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| **`K`** | **Show Status** | Displays active Profile, Anime Mode, and Shaders for 2 seconds. |
| **`CTRL + L`** | **Anime Mode: AUTO** | (Default) Applies anime shaders only if anime is detected. |
| **`CTRL + ;`** | **Anime Mode: ON** | Forces Anime4K shaders on all videos. |
| **`CTRL + '`** | **Anime Mode: OFF** | Disables anime shaders completely (uses Live Action pipeline). |

---

## 🖌️ Anime Pipeline (Anime4K)
*Only active when Anime Mode is engaged.*

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| **`L`** | **Toggle Quality** | Switches between **Fast** (1080p+) and **HQ** (720p/480p) presets. |
| **`CTRL + 1`** | **Mode A** | Balanced (Restore + Upscale). Good for most content. |
| **`CTRL + 2`** | **Mode B** | Soft. Good for older anime with aliasing. |
| **`CTRL + 3`** | **Mode C** | Denoise. Heavy reconstruction for grainy video. |
| **`CTRL + 4`** | **Mode A+A** | Ultra-Sharp. Double pass for very clean sources. |
| **`CTRL + 5`** | **Mode B+B** | Ultra-Soft. Double pass blur reduction. |
| **`CTRL + 6`** | **Mode C+A** | Denoise + Sharp. Restores old/noisy anime. |

---

## 📺 Live-Action Pipeline ("Modern TV")
*Active for movies, TV shows, and when Anime Mode is OFF.*

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| **`CTRL + Q`** | **SD Mode Toggle** | Switch between **Clean** (Standard) and **Texture** (Masking for low-bitrate). |
| **`Q`** | **Force NNEDI3** | Manually enables NNEDI3 upscaling regardless of resolution. |
| **`W`** | **Reset to Auto** | Returns Live-Action logic to automatic resolution detection. |

---

## 🔊 Audio & Subtitles

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| **`M`** | **7.1 Surround** | Toggles virtual 7.1 upmixing with Bass Boost. |
| **`A`** | **Normalization** | Toggles Dynamic Audio Normalization (loudness equalization). |
| **`CTRL + A`** | **Audio Device** | Auto-toggles audio output device. |
| **`ALT + Left/Right`** | **Sub Seek** | Seeks to the previous/next subtitle line. |
| **`[` / `]`** | **Sub Delay** | Adjusts subtitle delay (-0.1s / +0.1s). |
| **`CTRL + Up/Down`** | **Sub Position** | Moves subtitles up or down vertically. |

---

## ⏯️ Playback & Navigation

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| **`Right` / `Left`** | **Seek** | Seek ±5 seconds. |
| **`Shift` + `Right/Left`** | **Exact Seek** | Seek ±1 second (Exact). |
| **`Up` / `Down`** | **Volume** | Adjust Volume. |
| **`[` / `]`** | **Sub Delay** | Adjust subtitle timing. |
| **`G`** | **Interpolation** | Toggles Motion Interpolation (Smooth Motion) ON/OFF. |
| **`H`** | **HDR Mode** | Toggles HDR Tone Mapping (Clip / Mobius). |
| **`I`** | **Stats** | Toggle playback statistics overlay. |
| **`Screenshot`** | **`s`** | Take a screenshot (saved to Desktop). |

---

## 🛠️ Image Adjustments

| Shortcut | Function |
| :--- | :--- |
| **`1` / `2`** | Contrast - / + |
| **`3` / `4`** | Brightness - / + |
| **`5` / `6`** | Gamma - / + |
| **`7` / `8`** | Saturation - / + |
