# ⚡ MPV Anime Build v5.2 – Cheat Sheet

A complete reference for all keyboard shortcuts and commands defined in your `input.conf`.

---

## 🖱️ Mouse Controls

| Key | Function | Description |
| :--- | :--- | :--- |
| **`Left Click`** | **Pause** | Cycle pause/play. |
| **`Double Click`** | **Fullscreen** | Cycle fullscreen. |
| **`Back Thumb Btn`** | **Prev Chapter** | Go to previous chapter. |
| **`Fwd Thumb Btn`** | **Next Chapter** | Go to next chapter. |
| **`Scroll Wheel Up`** | **Vol +1 (Global)** | Increase volume anywhere on the screen and trigger the UOSC volume UI. |
| **`Scroll Wheel Down`** | **Vol -1 (Global)** | Decrease volume anywhere on the screen and trigger the UOSC volume UI. |

---

## ⏯️ Navigation & Seeking

| Key | Function | Description |
| :--- | :--- | :--- |
| **`RIGHT`** | **Seek +5s** | Seek forward 5 seconds. |
| **`LEFT`** | **Seek -5s** | Seek backward 5 seconds. |
| **`SHIFT+RIGHT`** | **Seek +1s** | Exact seek forward 1 second. |
| **`SHIFT+LEFT`** | **Seek -1s** | Exact seek backward 1 second. |
| **`CTRL+RIGHT`** | **Frame Step** | Advance one frame and show the current frame number. |
| **`CTRL+LEFT`** | **Frame Back** | Go back one frame and show the current frame number. |
| **`TAB`** | **Flash UOSC UI** | Flash the UOSC interface. |
| **`UP`** | **Vol +** | Increase volume (+1) and trigger the UOSC volume UI. |
| **`DOWN`** | **Vol -** | Decrease volume (-1) and trigger the UOSC volume UI. |
| **`SHIFT+UP`** | **Seek +2m** | Seek forward 2 minutes. |
| **`SHIFT+DOWN`** | **Seek -2m** | Seek backward 2 minutes. |
| **`ENTER`** | **Seek +85s** | Seek forward 85 seconds. |
| **`GO_BACK`** | **Seek -85s** | Seek backward 85 seconds. |
| **`-`** | **Prev Chapter** | Go to previous chapter. |
| **`=`** | **Next Chapter** | Go to next chapter. |
| **`w`** | **Playlist List** | Open the UOSC playlist/items menu. |
| **`e`** | **Prev File** | Play previous file in the playlist. |
| **`r`** | **Next File** | Play next file in the playlist. |
| **`z`** | **Chapter/Playlist Next** | Intelligent next: chapter, then playlist. |
| **`Z`** | **Chapter/Playlist Prev** | Intelligent previous: chapter, then playlist. |

---

## 🎨 Smart Skip & Chapter Colors

Skip Intro and the UOSC timeline use one synchronized palette for detected chapter categories:

| Chapter Category | Current Color | Skip Action |
| :--- | :--- | :--- |
| **Opening / OP** | Green (`#00FF00`) | Press **`ENTER`** while the Skip Intro card is visible. |
| **Ending / ED** | Blue (`#0080FF`) | Press **`ENTER`** while the Skip Intro card is visible. |
| **Preview / PV** | Orange (`#FF9900`) | Press **`ENTER`** while the Skip Intro card is visible. |
| **Intro / Prologue** | Magenta (`#FF00FF`) | Press **`ENTER`** while the Skip Intro card is visible. |

---

## 🔊 Audio & Subtitles

| Key | Function | Description |
| :--- | :--- | :--- |
| **`UP`** | **Vol +** | Increase volume (+1). |
| **`DOWN`** | **Vol -** | Decrease volume (-1). |
| **`9`** | **Vol --** | Decrease volume (-2). |
| **`0`** | **Vol ++** | Increase volume (+2). |
| **`a`** | **Cycle Audio** | Switch audio track. |
| **`A`** | **Bitstream Toggle** | Toggle between PCM (Upmix) and Passthrough. |
| **`m`** | **7.1 Upmix** | Toggle 7.1 Surround Upmix with Bass Boost. |
| **`CTRL+a`** | **Audio Device** | Toggle auto-switching audio device. |
| **`[`** | **Sub Delay -** | Decrease subtitle delay (-0.1s). |
| **`]`** | **Sub Delay +** | Increase subtitle delay (+0.1s). |
| **`{`** | **Audio Delay -** | Decrease audio delay (-0.1s). |
| **`}`** | **Audio Delay +** | Increase audio delay (+0.1s). |
| **`CTRL+UP`** | **Sub Pos -** | Move subtitles Up. |
| **`CTRL+DOWN`** | **Sub Pos +** | Move subtitles Down. |
| **`ALT+RIGHT`** | **Sub Seek +** | Seek to next subtitle line. |
| **`ALT+LEFT`** | **Sub Seek -** | Seek to previous subtitle line. |
| **`s`** | **Cycle Sub** | Switch subtitle track. |
| **`S`** | **Sub Visible** | Toggle subtitle visibility. |
| **`CTRL+s`** | **Secondary Sub** | Cycle secondary subtitle track. |
| **`t`** | **Sub Margins** | Toggle subtitles in black bars (`sub-use-margins`). |
| **`T`** | **Force Margins** | Force subtitles to screen bottom (`ass-force-margins`). |
| **`CTRL+t`** | **Blend Subs** | Toggle subtitle blending (Fixes rendering issues). |
| **`y`** | **Sub Video Data** | Cycle how subs use video data (None / Aspect / All). |

**Automatic subtitle priority:** Preferred clean tracks → preferred complete SDH → clean language fallbacks → any complete SDH. Commentary is never selected automatically; an explicit manual commentary selection is still respected.

---

## 📺 Video & Display

| Key | Function | Description |
| :--- | :--- | :--- |
| **`1`** | **Contrast -** | Decrease contrast. |
| **`2`** | **Contrast +** | Increase contrast. |
| **`3`** | **Bright -** | Decrease brightness. |
| **`4`** | **Bright +** | Increase brightness. |
| **`5`** | **Gamma -** | Decrease gamma. |
| **`6`** | **Gamma +** | Increase gamma. |
| **`7`** | **Saturation -** | Decrease saturation. |
| **`8`** | **Saturation +** | Increase saturation. |
| **`9`** | **Vol --** | Decrease volume by 2. |
| **`0`** | **Vol ++** | Increase volume by 2. |
| **`!`** | **On Top** | Toggle Always on Top. |
| **`F5`** | **Window Screenshot** | Capture the complete rendered MPV window. |
| **`F6`** | **Video Screenshot** | Capture a clean video-frame screenshot. |
| **`p`** | **Rotate** | Cycle video rotation: 90 / 180 / 270 / 0 degrees. |
| **`P`** | **Aspect Ratio** | Cycle aspect ratio: 16:9 / 4:3 / 2.35:1 / 16:10 / Auto. |
| **`f`** | **Fullscreen** | Toggle fullscreen. |
| **`g`** | **Interpolation** | Toggle motion interpolation. |
| **`G`** | **Tscale Mode** | Cycle interpolation filters. |
| **`h`** | **Deinterlace** | Toggle deinterlacing. |
| **`H`** | **HDR Mode** | Toggle hybrid HDR behavior: passthrough / tone mapping. |
| **`j`** | **Deband** | Cycle debanding filter. |
| **`u`** | **HW Dec** | Cycle hardware decoding: auto / no / auto-copy. |
| **`Right Mouse Button`** | **UOSC Menu** | Open the UOSC menu. |
| **`Menu Key`** | **UOSC Menu** | Open the UOSC menu. |

---

## 📊 Stats & Info

| Key | Function | Description |
| :--- | :--- | :--- |
| **`K`** | **Build Status** | Show active profile and Anime Mode status. |
| **`CTRL+i`** | **Stats Overlay** | Toggle the Neon Glass Statistics overlay. |
| **`i`** | **Stats (Quick)** | Show stats temporarily. |
| **`I`** | **Stats (Toggle)** | Toggle persistent stats overlay. |
| **`k`** | **Tech Info** | Show wrapped audio/video filter and shader status. |
| **`o`** | **OSD Level** | Cycle OSD level: 3 / 1. |

---

## 🚀 Anime Build Shortcuts (Script Logic)

| Key | Function | Description |
| :--- | :--- | :--- |
| **`CTRL+p`** | **Power Mode** | Toggle the cross-platform Low-Power/Battery Saver mode manually. |
| **`D`** | **Anime Menu** | Open the Anime Build menu. |
| **`CTRL+1`** | **Mode A** | Anime4K Mode A. |
| **`CTRL+2`** | **Mode B** | Anime4K Mode B. |
| **`CTRL+3`** | **Mode C** | Anime4K Mode C. |
| **`CTRL+4`** | **Mode AA** | Anime4K Mode A+A. |
| **`CTRL+5`** | **Mode BB** | Anime4K Mode B+B. |
| **`CTRL+6`** | **Mode CA** | Anime4K Mode C+A. |
| **`CTRL+7`** | **Mode Ani4Kv2** | Apply next-generation ArtCNN Ani4Kv2 shaders. |
| **`CTRL+8`** | **Mode AniSD** | Apply next-generation ArtCNN AniSD shaders. |
| **`L`** | **Anime4K Quality** | Toggle Anime4K quality: Fast ↔ HQ ↔ Ultra. |
| **`CTRL+-`** | **Clear Shaders** | Clear all GLSL shaders. |
| **`CTRL+l`** | **Mode: Auto** | Set Anime Mode to Auto. |
| **`CTRL+;`** | **Mode: On** | Force Anime Mode ON. |
| **`CTRL+'`** | **Mode: Off** | Force Anime Mode OFF. |
| **`CTRL+q`** | **SD Texture Mode** | Toggle SD Clean ↔ Texture. |
| **`Q`** | **HD Upscaler** | Toggle HD NNEDI3 ↔ FSRCNNX. |
| **`CTRL+b`** | **Anime Fidelity** | Toggle Anime Fidelity: Anime4K ↔ FSRCNNX. |
| **`CTRL+c`** | **Auto-Deinterlace Detection** | Toggle Auto Deinterlace Detection. |
| **`CTRL+g`** | **Master Shader Switch** | Toggle all shaders ON/OFF (persistent). |
| **`CTRL+k`** | **Adaptive Sharpen** | Toggle Adaptive Sharpen ON/OFF. |
| **`Ctrl+j`** | **Anime Line Thinning** | Toggle Anime Line Thinning shader; Anime Fidelity Mode only. |
| **`CTRL+x`** | **Ambient Crop** | Toggle Ambient Crop. |
| **`q`** | **Quit (Save)** | Quit and conditionally save watch-later state. |

---

## 🔋 Power Guard Quick Reference (v4.9)

| System State | Automatic Behavior |
| :--- | :--- |
| **Windows Laptop** | Uses PowerShell/CIM battery detection and automatically enables `[Low-End]` while discharging. |
| **Linux Laptop** | Uses the native `/sys/class/power_supply` interface and automatically enables `[Low-End]` while discharging. |
| **Windows/Linux Desktop** | Uses **Manual Toggle Only** mode; press `CTRL+p` or use the UOSC power menu. |
| **Eco Mode Enabled** | Disables high-cost shaders and switches scaling to the lightweight bilinear `[Low-End]` profile. |
| **Eco Mode Disabled / AC Restored** | Restores the smart video profile and the exact hardware-decoding configuration that was active before Eco mode. |

Power Guard preserves platform-appropriate decoding, including D3D11VA on Windows and NVDEC, VA-API, Vulkan, or SVP copy-back decoding on Linux.

---

## ⚙️ Personal MPV Config Quick Reference

| Item | Behavior |
| :--- | :--- |
| **Filename** | Create exactly one `mpv-<custom-name>.conf` beside `mpv.conf`, such as `mpv-personal.conf`. |
| **Precedence** | Options in the custom file load after and override matching options from the shipped `mpv.conf`. |
| **Recommended Content** | Add only the options you want to change, such as `fullscreen=no`. |
| **Multiple Files** | No custom file is loaded; MPV displays a warning until only one `mpv-*.conf` remains. |
| **Platform Support** | The same convention works on Windows and Linux. |
| **Different Purpose** | `mpv-*.conf` overrides normal MPV options; `user-*.conf` stores remembered Anime Build menu settings. |

---

## 🎨 v4.9 Rendering Quick Reference

| Setting | v4.9 Behavior |
| :--- | :--- |
| **Global Rendering Base** | MPV's built-in `high-quality` profile provides the rendering foundation. |
| **Anime Native Scaler** | `spline64` is used for smoother edges and reduced ringing. |
| **Live-Action FHD/2K Profile** | The custom profile is named `[FHD-Native]`, clearly separating it from MPV's built-in `high-quality` profile. |
| **Manual Sharp Alternative** | `ewa_lanczossharp` remains available when stronger edge definition is preferred. |

---
