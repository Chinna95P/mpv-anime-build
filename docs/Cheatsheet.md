# ⚡ MPV Anime Build v1.5.1 – Cheat Sheet

A complete reference for all keyboard shortcuts and commands defined in your `input.conf`.

---

## 🖱️ Mouse Controls
| Key | Function | Description |
| :--- | :--- | :--- |
| **`Left Click`** | **Pause** | Cycle pause/play. |
| **`Double Click`** | **Fullscreen** | Cycle fullscreen. |
| **`Back Thumb Btn`** | **Prev Chapter** | Go to previous chapter. |
| **`Fwd Thumb Btn`** | **Next Chapter** | Go to next chapter. |

---

## ⏯️ Navigation & Seeking
| Key | Function | Description |
| :--- | :--- | :--- |
| **`RIGHT`** | **Seek +5s** | Seek forward 5 seconds. |
| **`LEFT`** | **Seek -5s** | Seek backward 5 seconds. |
| **`SHIFT+RIGHT`** | **Seek +1s** | Exact seek forward 1 second. |
| **`SHIFT+LEFT`** | **Seek -1s** | Exact seek backward 1 second. |
| **`SHIFT+UP`** | **Seek +2m** | Seek forward 2 minutes. |
| **`SHIFT+DOWN`** | **Seek -2m** | Seek backward 2 minutes. |
| **`CTRL+RIGHT`** | **Frame Step** | Advance one frame. |
| **`CTRL+LEFT`** | **Frame Back** | Go back one frame. |
| **`e`** | **Prev File** | Play previous file in playlist. |
| **`r`** | **Next File** | Play next file in playlist. |
| **`w`** | **Playlist List** | Show playlist list onscreen (OSC). |
| **`-`** | **Prev Chapter** | Go to previous chapter. |
| **`=`** | **Next Chapter** | Go to next chapter. |
| **`z`** | **Chapter/Playlist Next** | Intelligent skip (Chapter -> Playlist). |
| **`Z`** | **Chapter/Playlist Prev** | Intelligent skip (Chapter -> Playlist). |

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

---

## 📺 Video & Display
| Key | Function | Description |
| :--- | :--- | :--- |
| **`f`** | **Fullscreen** | Toggle fullscreen. |
| **`p`** | **Rotate** | Rotate video 90 degrees. |
| **`P`** | **Aspect Ratio** | Cycle Aspect Ratio (16:9, 4:3, etc). |
| **`!`** | **On Top** | Toggle "Always on Top" window mode. |
| **`1`** | **Contrast -** | Decrease contrast. |
| **`2`** | **Contrast +** | Increase contrast. |
| **`3`** | **Bright -** | Decrease brightness. |
| **`4`** | **Bright +** | Increase brightness. |
| **`5`** | **Gamma -** | Decrease gamma. |
| **`6`** | **Gamma +** | Increase gamma. |
| **`7`** | **Saturation -** | Decrease saturation. |
| **`8`** | **Saturation +** | Increase saturation. |
| **`g`** | **Interpolation** | Toggle Motion Interpolation. |
| **`G`** | **Tscale Mode** | Cycle interpolation filters (linear/catmull_rom/etc). |
| **`h`** | **Deinterlace** | Toggle deinterlacing. |
| **`H`** | **HDR Mode** | Manual Toggle: Passthrough ↔ Tone Mapping. |
| **`V`** | **Nvidia VSR** | Toggle Video Super Resolution (Shift+v). |
| **`j`** | **Deband** | Cycle debanding filter. |
| **`u`** | **HW Dec** | Cycle Hardware Decoding (auto-copy / no). |

---

## 📊 Stats & Info
| Key | Function | Description |
| :--- | :--- | :--- |
| **`i`** | **Stats (Quick)** | Show stats temporarily. |
| **`I`** | **Stats (Toggle)** | Toggle persistent stats overlay. |
| **`k`** | **Tech Info** | Show Audio/Video Filters and Shaders. |
| **`o`** | **OSD Level** | Cycle OSD level (1 / 3). |

---

## 🚀 Anime Build Shortcuts (Script Logic)

| Key | Function | Description |
| :--- | :--- | :--- |
| **`K`** | **Build Status** | Show Active Profile and Anime Mode Status. |
| **`q`** | **Quit (Save)** | Quit and save watch-later state conditionally. |
| **`CTRL+l`** | **Mode: Auto** | Set Anime Mode to Auto. |
| **`CTRL+;`** | **Mode: On** | Force Anime Mode ON. |
| **`CTRL+'`** | **Mode: Off** | Force Anime Mode OFF. |
| **`L`** | **Anime4K Qual** | Toggle Anime4K Quality (Fast ↔ HQ). |
| **`CTRL+1`** | **Mode A** | Anime4K Mode A (Restore+Upscale). |
| **`CTRL+2`** | **Mode B** | Anime4K Mode B (Soft). |
| **`CTRL+3`** | **Mode C** | Anime4K Mode C (Denoise). |
| **`CTRL+4`** | **Mode AA** | Anime4K Mode A+A (Ultra Sharp). |
| **`CTRL+5`** | **Mode BB** | Anime4K Mode B+B (Ultra Soft). |
| **`CTRL+6`** | **Mode CA** | Anime4K Mode C+A (Denoise+Restore). |
| **`CTRL+-`** | **Clear Shaders** | Clear all GLSL shaders. |
| **`CTRL+q`** | **SD Textures** | Toggle Clean ↔ Texture (Locked if Sharp Mode active). |
| **`Q`** | **Master Upscaler** | Toggle NNEDI3 ↔ FSRCNNX (Works for SD & HD). |