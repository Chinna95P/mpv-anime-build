# Changelog – 📱 MPV Android Anime Build

All notable changes to this project are documented here.

---

## [v1.2] – The "Visuals & Logic" Update

### 🎨 Visual Experience (OSD 2.0)
* **Color-Coded Overlay:** Replaced the plain white text with a rich **ASS Overlay** engine, matching the visual style of the `Skip Intro` button.
    * **Status Colors:** Instant visual feedback for your current mode:
        * ![](https://img.shields.io/badge/_-Magenta-FF00FF) **Anime4K Active**
        * ![](https://img.shields.io/badge/_-Green-00FF00) **FSRCNNX (Fidelity) Active**
        * ![](https://img.shields.io/badge/_-Cyan-00FFFF) **Live Action**
        * ![](https://img.shields.io/badge/_-Red-FF0000) **Battery Saver / Off**
    * **Emoji Fix:** Resolved rendering issues where status icons (✨, 🎧, ⚡) appeared as "blocks" on some Android devices.

### 🧠 Logic Upgrades
* **Smart Fallback (Sticky Shaders):**
    * **The Change:** Toggling **OFF** the built-in Anime4K shaders no longer results in a "No Shaders" state.
    * **The Result:** The system now intelligently falls back to **FSRCNNX (Anime Fidelity)** automatically. This ensures your Anime content always looks enhanced, treating FSRCNNX as the "Baseline" quality.
* **Snapshot & Restore:**
    * **Fixed:** Solved an issue where manually toggling back to **High Performance Mode** (after using Battery Saver) would fail to re-enable Anime4K.
    * **How:** The script now "snapshots" your exact Anime4K shader configuration and restores it 1:1 when you disable Eco Mode.
* **User Intent Detection:** The script now distinguishes between a **System Reset** (Eco Mode) and a **Manual Toggle**, preventing logic loops where the script would fight against your changes.

---

## [v1.1] – The "Subtitles & Stability" Update

### ✨ New Features

* **Auto Subtitle Selector:** Added `subtitle-selector.lua`, a smart script that automatically picks the best subtitle track based on content type.
    * **Anime:** Intelligent logic that prioritizes **"Dialogue"** or **"Full"** tracks (often styled/typeset) over basic signs/songs, ensuring you get the full translation immediately. Falls back to Japanese if no English dialogue track is found.
    * **Live Action:** Automatically selects the first available **English** subtitle track, preventing the player from defaulting to "No Subtitles" or foreign languages on multi-language rips.

### 🐛 Fixed

* **Loop/Repeat Mode Fix:** Resolved an issue where the native mpvEX "Repeat" button (or `loop-file` command) was being overridden or ignored by the script logic. Single-file looping now works correctly for both Anime and Live Action content.

---

## 📱 MPV Android Anime Build - Initial Release (v1.0)

**The high-fidelity PC experience, now optimized for mpvEX on Android.**

This release brings the core "Smart Logic" of the desktop build to your phone, featuring automatic profile switching, battery management, and gesture-based controls.

### 🌟 Key Features

* **🧠 Smart Auto-Detection:** Automatically switches between `[Anime]` (FSRCNNX LineArt) and `[Live-Action]` (Standard) profiles based on file content.
* **👆 Gesture Controls:**
    * **Skip Intro:** Double-tap (Right) during OP/ED sequences to skip instantly.
    * **Spatial Audio:** Double-tap (Right) during normal playback to toggle Virtual 7.1 Surround.
    * **Eco Mode:** Double-tap (Left) to instantly disable shaders for battery saving.
* **🔋 Power Guard:** Automatically disables heavy shaders if you toggle "Eco Mode", saving your battery during long trips.
* **🎧 Spatial Audio:** Includes a custom HRTF-based virtual surround profile designed specifically for headphones.

### 📥 How to Install

1. **Download** the `mpv-android-config-v1.0.zip` below.
2. **Extract** all files directly into a new folder on your phone (e.g., `/storage/emulated/0/mpv/`).
    * *Note: Do not create subfolders like `scripts/` inside. All files (`.lua`, `.conf`, `.glsl`) must be in the main folder you created.*
3. **Activate Config (Important):**
    * Open **mpvEX** and go to **Settings** -> **Advanced**.
    * Tap **Pick Configuration Storage location**.
    * Select the folder where you extracted the files (e.g., `mpv`) and tap **USE THIS FOLDER** -> **ALLOW**.
    * In the same menu, check **Enable Lua scripts**.
    * Tap **Manage Lua scripts** and ensure all scripts (`anime_auto_detect.lua`, `skip_intro.lua`, `subtitle-selector.lua`) are ticked.
4. **Setup Gestures:**
    * Go to **Settings** -> **Controls** -> **Gestures**.
    * Tap **Double Tap (Right)** -> Scroll to bottom -> **Custom Command**.
    * Enter exactly: `script-message smart-skip-audio`

### 📱 Requirements

* **App:** [mpv-android (mpvEX)](https://github.com/marlboro-advance/mpvEx)
* **Device:** Mid-range to High-end Android phone (Snapdragon 855 or better recommended for FSRCNNX).