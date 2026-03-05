# 📱 MPV Android Anime Build v2.0

An advanced configuration for **mpv-android (mpvEX, Aniyomi, official mpv-android, and other mpv-based players)** that brings high-end PC features to mobile:
* **Broad Compatibility [NEW]:** Works flawlessly across mpvEX, Aniyomi, standard mpv-android, and any mobile player that supports custom `mpv.conf` and Lua scripts.
* **Auto-Detection:** Automatically switches profiles for Anime vs. Live Action.
* **Performance Tiers [NEW]:** Choose between HQ, Balanced, or Fast auto-detect scripts to match your phone's processing power.
* **8K Optimization [NEW]:** Smart bypass for ultra-high-resolution content to ensure smooth playback.
* **Ambient Shaders [NEW]:** A dedicated ambient shader version for a highly immersive visual experience.
* **Spatial Audio:** Virtual Surround Sound for headphones.
* **Gesture & Custom Button UI:** "Double Tap to Skip Intro" and custom on-screen UI buttons (mpvEX recommended for custom UI mappings).

| Anime (Anime4K) | Anime (FSRCNNX) | Live Action | Battery Saver |
| :---: | :---: | :---: | :---: |
| ![Anime4K](screenshots/mpv%20(9).jpg) | ![FSRCNNX](screenshots/mpv%20(3).jpg) | ![Live](screenshots/mpv%20(1).jpg) | ![Battery](screenshots/mpv%20(11).jpg) |
| **Modern / Stylized** | **Purist / Fidelity** | **Natural Detail** | **Zero Drain** |

## 📥 Installation

1.  **Download Files:** Switch to the `android` branch and download the ZIP.
2.  **Locate Config Folder:** * For **mpvEX / mpv-android**: Go to for example: `/storage/emulated/0/[your-folder]/` (or create it).
    * For **Aniyomi**: Go to `Settings > Player > Advanced > mpv conf storage location` to find or set your folder.
3.  **Copy:** **Extract ALL files directly into this folder.**

## ⚙️ Critical Setup (Do not skip!)

### 1. Enable Storage Permissions
For the shaders to load, your video player needs full storage access.
* *Android Settings > Apps > [Your App: mpvEX / Aniyomi] > Permissions > Files > **Allow all time/Management**.*

### 2. Activate Config (Important):
*(Menu paths may vary slightly depending on if you use mpvEX, Aniyomi, or standard mpv-android)*
* Open your player app and go to **Settings** -> **Advanced**.
* Tap **Pick Configuration Storage location**.
* Select the folder where you extracted the files and tap **USE THIS FOLDER** -> **ALLOW**.
* In the same menu, check **Enable Lua scripts**.
* Tap **Manage Lua scripts** and select your preferred scripts. 
    * **[NEW]** *Choose ONLY ONE auto-detect tier: `anime_auto_detect_HQ.lua`, `_Balanced.lua`, or `_Fast.lua`.*
    * Ensure `skip_intro.lua` and `subtitle-selector.lua` are also ticked.

### 3. Configure Gestures (Required for Skip Intro)
*Note: Custom gesture mapping is best supported on **mpvEX**.*

1.  Open **mpvEX Settings > Controls > Gestures**.
2.  Tap **Double tap (right)**.
3.  Scroll to bottom and select **Custom command**.
4.  Enter exactly: `script-message smart-skip-audio`
5.  *(Optional)* Set **Double tap (left)** to: `script-message toggle-power-mode`

### 4. Configure Custom On-Screen Buttons (mpvEX)
The latest mpvEX update allows you to trigger Lua script commands directly from the player overlay using **Custom Buttons**. 

1. Go to **Settings > UI > Custom Lua** (or Custom Buttons).
2. Tap an **Empty slot** to expand the editor and give it a title (e.g., "Anime Mode").
3. In the **Tap action** or **Long press action** fields, enter the following commands to link the button to the script:

| Feature | Command String |
| :--- | :--- |
| **Power Mode** | `mp.command("script-message toggle-power-mode")` |
| **Audio Mode** | `mp.command("script-message toggle-audio-mode")` |
| **Smart-Skip** | `mp.command("script-message smart-skip-audio")` |
| **Shaders Toggle** | `mp.command("script-message toggle-shaders-mode")` |
| **Cycle Audio** | `mp.command("script-message cycle-audio")` |
| **Reset Audio** | `mp.command("script-message reset-audio")` |
| **Ambient Mode ON/OFF** | `mp.command("script-message toggle-ambient")` |

📖 **For a complete, in-depth guide on setting up UI buttons, automation, and shaders, please read the [Custom Buttons & Shaders Guide](https://github.com/Chinna95P/mpv-anime-build/blob/android/Custom%20Buttons%20%26%20Shaders%20Readme.md) located in this repository.**

---

## 🎮 How to Use

### ⚡ Smart Audio / Skip Intro (Right Double-Tap)
*(Requires gesture setup in mpvEX)*
* **During OP/ED:** You will see a prompt **"DOUBLE TAP TO SKIP OP"**.
    * **Action:** Double-tap Right side.
    * **Result:** Skips the intro instantly.
* **During Normal Playback:**
    * **Action:** Double-tap Right side.
    * **Result:** Toggles **Spatial Audio** (Cinema Surround vs Standard).

| Skip Intro (OP) | Skip Intro (ED) | Visual Feedback |
| :---: | :---: | :---: |
| ![OP Skip](screenshots/mpv%20(5).jpg) | ![ED Skip](screenshots/mpv%20(7).jpg) | ![Feedback](screenshots/mpv%20(8).jpg) |
| **Green Indicator** | **Blue Indicator** | **Instant Confirmation** |

### 🖥️ Smart Video Profiles & Features
The build automatically detects what you are watching and adjusts to your device:

* **Performance Tiers [NEW]:** You can now pick your script based on your phone's power.
    * **HQ Mode:** Pushes the highest quality shaders (Snapdragon 8 Gen 1+).
    * **Balanced Mode:** Great visual upgrades without overheating (Mid-range).
    * **Fast Mode:** Lightweight optimizations for older devices.
* **Anime:** Enables FSRCNNX LineArt + SSimSuperRes.
    * *Note:* If you enable "Anime4K" in the App's side menu, the script detects it and disables FSRCNNX to prevent lag.
* **Live Action:** Enables FSRCNNX (Standard) + SSimSuperRes.
    * *Note:* Automatically disables Anime4K if you accidentally leave it on.
* **8K Optimization [NEW]:** If an 8K video is detected, the script instantly bypasses all heavy upscaling shaders, allowing your phone's hardware decoder to handle the massive frame load without crashing.
* **Ambient Shaders [NEW]:** You can now load the dedicated Ambient Shader version for a highly immersive, glowing visual experience.
* **Battery Saver:** Double-tap Left (if mapped) to disable all shaders instantly.