# Changelog – 📱 MPV Android Anime Build

All notable changes to this project are documented here.

---

## [v2.0] – The "Performance & Ambient" Update

### ✨ New Features

* **Granular Auto-Detect Modes:**
  * The main auto-detect shader script has been completely refactored and divided into three distinct performance tiers: **HQ**, **Balanced**, and **Fast**.
  * You can now perfectly tailor the script's visual fidelity and power draw to match your specific Android device's hardware capabilities, bridging the gap between flagship and mid-range phones.
* **Ambient Shader Version:**
  * Introduced a dedicated "Ambient" shader version to the build. This provides a new, immersive visual option for your playback experience. 

### ⚡ Performance & Stability

* **Smart 8K Optimization:**
  * Added a dedicated resolution gate for 8K videos. 
  * When 8K content is detected, the script now automatically bypasses heavy upscaling shaders (like FSRCNNX) to ensure smooth, hardware-accelerated playback and prevent the mpvEX app from freezing under massive frame loads.

---

## [v1.4] – The "Stability & Logic" Update

### 🔥 Critical Fixes (Startup Freeze)

* **Fixed "Infinite Wait" / Deadlock:**
* Resolved a race condition where the Audio Engine and Video Shaders tried to initialize simultaneously.
* **Solution:** Audio profiles now load *immediately* (synchronously), while heavy detection logic is delayed by 0.5s. This prevents the A/V clock from desyncing at 00:00.

* **Fixed Subtitle Preroll Hang:**
* Disabled `demuxer-mkv-subtitle-preroll`. This stops the player from freezing on MKVs while trying to scan for subtitles before the first frame.

### 🧠 Smart Logic & Interactions

* **Audio Toggle Logic Fix:**
* The OSD now correctly reports "Spatial Audio" based on the *intended logic state* rather than the hardware state. This fixes the issue where the toggle appeared to fail (showing "Standard") on devices that reject 7.1 channels.

* **Skip Intro "Ghost" Fix:**
* Fixed a logic gap where the "Double Tap to Skip" action remained active even after the "Skip Intro" button disappeared. The timer now strictly resets to 0 instantly when the OSD vanishes.

### ⚡ Performance

* **Lazy Caching (Skip Intro):**
* The script no longer spams the Android API for chapter lists every 0.2s. It now fetches the list **once** per file and caches it, significantly reducing background CPU usage.

* **Startup Guard (Up Next):**
* Added a safety delay to the "Up Next" script to prevent it from scanning the filesystem while the video is still initializing.

---


---

## [v1.3] – The "Up Next" Update

### ✨ New Features
* **Up Next Notification:** Ported the `Up_Next` logic to Android. A notification now appears before the episode ends, showing the next file in the playlist.
* **Mobile Layout:** Optimized the OSD positioning to sit perfectly above Android gesture bars and navigation elements.

### 🔧 Credits
* **Up Next Script:** Core logic adapted from the original script by **@WaruiDevil** (Telegram).

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