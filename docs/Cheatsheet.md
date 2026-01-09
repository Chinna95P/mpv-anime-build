# ⚡ MPV Anime Build v1.3 – Cheat Sheet

A complete reference for all keyboard shortcuts and commands available in this build.

---

## 🖱️ Mouse Controls
| Key | Function | Description |
| :--- | :--- | :--- |
| **`MOUSE_BTN0`** | **Pause** | Toggle playback pause. |
| **`MOUSE_BTN0_DBL`** | **Fullscreen** | Toggle fullscreen mode. |
| **`MOUSE_BTN5`** | **Prev Chapter** | Go to the previous chapter. |
| **`MOUSE_BTN6`** | **Next Chapter** | Go to the next chapter. |

---

## ⏯️ Navigation & Seeking
| Key | Function | Description |
| :--- | :--- | :--- |
| **`RIGHT`** | **Seek +5s** | Seek forward 5 seconds (Keyframes). |
| **`LEFT`** | **Seek -5s** | Seek backward 5 seconds (Keyframes). |
| **`SHIFT+RIGHT`** | **Seek +1s** | Exact seek forward 1 second. |
| **`SHIFT+LEFT`** | **Seek -1s** | Exact seek backward 1 second. |
| **`SHIFT+UP`** | **Seek +2m** | Seek forward 120 seconds (Keyframes). |
| **`SHIFT+DOWN`** | **Seek -2m** | Seek backward 120 seconds (Keyframes). |
| **`CTRL+RIGHT`** | **Frame Step** | Advance one frame forward. |
| **`CTRL+LEFT`** | **Frame Back** | Go back one frame. |
| **`r`** | **Playlist Next** | Play next file and show playlist position. |

---

## 🔊 Audio & Subtitles
| Key | Function | Description |
| :--- | :--- | :--- |
| **`UP`** | **Vol +** | Increase volume. |
| **`DOWN`** | **Vol -** | Decrease volume. |
| **`s`** | **Cycle Sub** | Switch subtitle track. |
| **`S`** | **Sub Visibility** | Toggle subtitle visibility. |
| **`CTRL+s`** | **Secondary Sub** | Cycle secondary subtitle track. |
| **`CTRL+UP`** | **Sub Pos -** | Move subtitles Up. |
| **`CTRL+DOWN`** | **Sub Pos +** | Move subtitles Down. |
| **`ALT+RIGHT`** | **Sub Seek +** | Seek to next subtitle line. |
| **`ALT+LEFT`** | **Sub Seek -** | Seek to previous subtitle line. |
| **`[`** | **Sub Delay -** | Decrease subtitle delay (-0.1s). |
| **`]`** | **Sub Delay +** | Increase subtitle delay (+0.1s). |
| **`t`** | **Sub Margins** | Toggle subtitles in black bars (`sub-use-margins`). |
| **`T`** | **Force Margins** | Toggle forcing subtitles to screen bottom (`ass-force-margins`). |
| **`CTRL+t`** | **Blend Subs** | Toggle subtitle blending (Fixes some rendering issues). |
| **`y`** | **Stretch Image Subs**| Toggle stretching for PGS/VobSub (`stretch-image-subs-to-screen`). |

---

## 📺 Video & Display
| Key | Function | Description |
| :--- | :--- | :--- |
| **`f`** | **Fullscreen** | Toggle fullscreen. |
| **`p`** | **Rotate** | Rotate video (90 / 180 / 270 / 0). |
| **`P`** | **Aspect Ratio** | Cycle Aspect Ratio (16:9, 4:3, 2.35:1, etc). |
| **`g`** | **Interpolation** | Toggle Motion Interpolation (Sync/Resample). |
| **`G`** | **Tscale Mode** | Cycle interpolation filters (linear, catmull_rom, mitchell, etc). |
| **`h`** | **Deinterlace** | Toggle deinterlacing. |
| **`H`** | **HDR Mode** | Cycle Tone Mapping (clip/mobius) & HWDec. |

---

## 📊 Stats & Info
| Key | Function | Description |
| :--- | :--- | :--- |
| **`i`** | **Stats (Quick)** | Show playback statistics temporarily. |
| **`I`** | **Stats (Toggle)** | Toggle persistent playback statistics. |
| **`k`** | **Tech Info** | Show Audio Filters, Video Filters, and Shaders. |
| **`o`** | **OSD Level** | Cycle On-Screen Display level (1 / 3). |

---

## 🚀 Anime Build Shortcuts (Script Logic)
*Note: These keys are defined by the Anime Build scripts, not input.conf directly.*

| Key | Function | Description |
| :--- | :--- | :--- |
| **`K`** | **Build Status** | Show current Profile, Anime Mode, and Active Shaders. |
| **`CTRL+L`** | **Anime Mode: Auto** | Enable automatic detection. |
| **`CTRL+;`** | **Anime Mode: On** | Force Anime shaders On. |
| **`CTRL+'`** | **Anime Mode: Off** | Force Anime shaders Off. |
| **`L`** | **Anime4K Quality** | Toggle **Fast** ↔ **HQ** (Anime Mode only). |
| **`Q`** | **HD Toggle** | Toggle **NNEDI3** ↔ **FSRCNNX** (HD Non-Anime only). |
| **`CTRL+Q`** | **SD Toggle** | Toggle **Clean** ↔ **Texture** (SD Non-Anime only). |