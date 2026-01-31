# ❓ Frequently Asked Questions

> **⚠️ Important Note on Shortcuts:** > Whenever a shortcut is listed in **Capital Letters** (e.g., `V`, `H`, `A`), it means you must press **`Shift + key`** (e.g., `Shift+v`).  
> Shortcuts shown in lowercase (e.g., `y`) should be pressed directly without Shift.

<br>

## 🖥️ User Interface (UOSC)

<details>
<summary><b>Where are the controls? (New in v1.7.1)</b></summary>

You now have **two** easy ways to control everything:
1.  **Control Bar Button:** Click the **Sliders/Tune Icon** located in the control bar (just above the timeline). This opens the new **Controls Dashboard** (Sync, Colors, Interpolation).
2.  **Right-Click Menu:** Right-click anywhere > select **Controls** or **Anime Build Options**.
</details>

<details>
<summary><b>What does the "GPU API" setting do?</b></summary>

This is a **Read-Only** display found in the Controls menu.
* It tells you if MPV is running on `d3d11` (Windows) or `vulkan` (Linux).
* **Why is it greyed out?** Changing the GPU backend requires a full player restart. We made it unclickable to prevent accidental crashes during playback.
</details>

<details>
<summary><b>New FAQ Entry (v2.1): Adaptive Sharpen Toggle</b></summary>

**Why is there a ✨ icon in my OSD?**
This is the **Adaptive Sharpen** indicator. It means the build is currently applying a "Modern TV" style sharpening pass to the image. 

**Why can't I turn Sharpening ON?**
The toggle (**`CTRL+k`**) is locked in two scenarios:

1. Your **Master Shader Switch** (`CTRL+g`) is OFF. 

2. You are in **Power Saving Mode** or using **Nvidia VSR**. The build disables standard sharpening in these modes to prioritize battery life or AI-driven upscaling. 
</details>

<br>

## 📺 Video & Quality

<details>
<summary><b>What is "Fidelity Mode"? (New in v1.9)</b></summary>

By default, the build uses **Anime4K** (Mode A), which is fantastic for upscaling 720p or older anime to 4K. 
However, for **high-quality 1080p releases**, Anime4K can sometimes look "too processed."

**Fidelity Mode** switches the engine to **FSRCNNX** combined with **KrigBilateral**.
It is **Resolution Aware**:
* If you play an **SD** file, it uses a heavier 16-layer network to fix the image.
* If you play an **HD/1080p** file, it uses a lighter 8-layer "Line Art" network to simply refine the edges without destroying the artist's original texture.
</details>

<details>
<summary><b>How do I see what shaders are active?</b></summary>

Press **`Shift + I`** (or go to **System > Show Statistics** in the menu).
This opens the **Neon Glass Overlay**, which tells you exactly which scaler (NNEDI3, FSRCNNX, or Anime4K) is currently running.
</details>

<br>

## 🔊 Audio

<details>
<summary><b>What is Night Mode?</b></summary>

Night Mode applies **Dynamic Range Compression**. It boosts quiet dialogues (whispers) and lowers loud explosions. This is perfect for watching movies at night so you can hear what characters are saying without waking up the house during action scenes.
Toggle it in the Audio Menu or press `Shift + U`.
</details>

<br>

## 🚀 Nvidia VSR (Video Super Resolution)
*Exclusive to RTX 3000/4000 (2000 Series should also work) series users.*

<details>
<summary><b>How do I enable Nvidia VSR?</b></summary>

Simply press **`V`** (`Shift+v`) on your keyboard.
* **Status: Green** ("Active") means VSR is working.
* **Status: Yellow** ("Disabled") means VSR is off.

> **⚠️ Important:** The toggle is **Manual**. 
> * **If you have an RTX card:** It will work perfectly. 
> * **If you have an AMD/Intel/GTX card:** Turning this ON will force basic driver scaling (bilinear), which usually looks worse than the default MPV upscalers. **Do not enable this unless you have an RTX GPU.**
>
> *Note:* You must also enable "RTX Video Enhancement" in your **Nvidia Control Panel** (under *Adjust Video Image Settings*) and set the Quality to **4** for best results.
</details>

<details>
<summary><b>Why does the OSD say "P010" or "NV12"?</b></summary>

This is the **Smart Automation** protecting your video quality:
* **P010 (10-bit):** Used for **HDR** and **High-Quality Anime**. This prevents "color banding" (ugly gradient steps) that happens if you force standard VSR on high-bit-depth content.
* **NV12 (8-bit):** Used for standard **Web/YouTube** content. This is the native format for VSR and ensures maximum compatibility.
</details>

<details>
<summary><b>I pressed 'V' and my screen went black!</b></summary>

This usually happens if your GPU drivers are outdated or unstable.
1.  Update your Nvidia Drivers to the latest "Game Ready" or "Studio" driver.
2.  Press **`V`** (`Shift+v`) again to disable it.
3.  If the issue persists, your GPU might be struggling with the 4K upscaling load.
</details>

<details>
<summary><b>Does this build work on AMD or Intel GPUs?</b></summary>

**Yes, absolutely.**
* **Universal Support:** The 4K Upscaling (Anime4K), HDR Passthrough, and "Modern TV" Live Action shaders work on **ALL** GPUs (Nvidia, AMD, Intel).
* **The Only Exception:** The **`V`** key (Nvidia VSR) is designed for RTX cards. If you use it on AMD/Intel, it won't crash, but it won't look good either.
* **Note:** Hardware decoding is set to `auto-copy`, ensuring full performance on all vendors.
</details>

<br>

## 📺 HDR & Dolby Vision
*Universal support for TVs and Monitors.*

<details>
<summary><b>How do I get "True" HDR Passthrough?</b></summary>

**Just toggle the Windows HDR switch.**
1.  Go to Windows Display Settings and turn **"Use HDR"** to **ON**.
2.  MPV detects this and activates **True Passthrough** (`target-colorspace-hint=yes`).
3.  This bypasses MPV's processing and sends the raw metadata (MaxCLL/FALL) directly to your display, ensuring your TV handles the brightness mapping perfectly.
</details>

<details>
<summary><b>Why do I need to turn Windows HDR ON?</b></summary>

MPV requires the Windows D3D11 Swapchain to be in HDR mode to send metadata.
* **Windows HDR ON:** Triggers **Passthrough Mode** (Your Display handles the HDR).
* **Windows HDR OFF:** Triggers **Tone Mapping** (MPV converts HDR to SDR).
</details>

<details>
<summary><b>Why is Passthrough better than Tone Mapping?</b></summary>

* **Passthrough:** Allows your TV/Monitor to use its internal processor (and dynamic tone mapping) to handle the brightness. This usually results in the most accurate image for OLEDs.
* **Tone Mapping:** MPV converts the colors to fit an SDR container. This is better for projectors or standard monitors that don't support native HDR.
</details>

<details>
<summary><b>My videos look washed out (or too dark) on my Monitor!</b></summary>

This happens if MPV thinks you are in HDR mode when you aren't (or vice versa).
* **Solution:** Press **`H`** (`Shift+h`).
* This manually toggles between **Passthrough** (for TVs) and **Tone Mapping** (for SDR Monitors).
</details>

<details>
<summary><b>Does this support Dolby Vision?</b></summary>

**Yes.**
* **If you have a Dolby Vision TV:** Enable Windows HDR, and MPV will pass the signal through.
* **If you have a Standard Monitor:** MPV will automatically play the **HDR10 Base Layer** and tone-map it perfectly to your screen. You won't get purple/green tints.
</details>

<br>

## 🖥️ User Interface (UOSC)

<details>
<summary><b>Where did the old controls go?</b></summary>

We have moved to **UOSC** for a cleaner, modern experience. You can still use shortcuts, but the easiest way is now the Menu:
* **Right-click anywhere** or press the **Menu** button.
* Select **"Anime Build Options"**.
* This centralized panel controls everything: Anime4K, Audio Upmix, Power Mode, and VSR.
</details>

<br>

## 🔊 Audio & Surround Sound

<details>
<summary><b>I hear silence when playing TrueHD / DTS-X files!</b></summary>

This means your audio device (TV/Soundbar) doesn't support the raw Bitstream format.
* **Fix:** Press **`A`** (`Shift+a`).
* This disables Passthrough and forces MPV to decode the audio internally (PCM), effectively fixing the silence.
</details>

<details>
<summary><b>What is the difference between "PCM" and "Passthrough"?</b></summary>

Toggle between them using the **`A`** (`Shift+a`) key:
* **PCM (Upmix Active):** MPV decodes the audio. This allows our **7.1 Upmix** logic to work (great for headphones and PC speakers).
* **Bitstream (Passthrough):** MPV sends the raw data to your Receiver/AVR. Your Receiver does the decoding. Best for Home Theater setups with Atmos support.
</details>

<br>

## 🔧 Troubleshooting & Setup

<details>
<summary><b>The "Skip Intro" button is not appearing!</b></summary>

The Skip Button relies on **Chapter Metadata**.
* **Requirement:** The file *must* have chapters.
* **Supported Patterns (v2.0):** We now support complex names like:
    * `OP`, `OP1`, `OP 2`, `Opening`
    * `ED`, `ED1`, `Ending`, `Credits`
    * `PV`, `Preview`, `Avant`
    * `Intro`, `Theme Song`
* **Why it fails:**
    * The file has **no chapters** at all (common in raw web-rips).
    * **Fix:** Use files from proper release groups (e.g., Erai-Raws, Judas, EMBER, SubsPlease) or use Stremio with the "SponsorBlock" plugin (if supported).
</details>

<details>
<summary><b>Why is SVP still running when I'm on Battery?</b></summary>

MPV cannot "kill" the SVP process because it runs separately.
* **The Fix:** You need to tell SVP to stop itself.
* Please read the **"Important for SVP 4 Pro Users"** section in the `README.md` to learn how to set up an automatic "Battery Profile" inside SVP.
</details>

<details>
<summary><b>Does this build work on Linux?</b></summary>

**Yes!**
The build is fully universal.
* **Config:** `mpv.conf` automatically switches to `vulkan` backend on Linux for best performance.
* **Shaders:** Anime4K and High-Quality shaders work perfectly.
* **Limitations:** Nvidia VSR (Key: `V`) is disabled on Linux because it requires DirectX 11.
</details>

<details>
<summary><b>SVP 4 Pro isn't working / "No active playback"</b></summary>

This is usually caused by the "Native Hardware Decoding" conflict.
* **The Fix:** We fixed this by setting `hwdec=auto-copy`.
* **Verify:** Press `Shift+I` and check `HW:`. It must say `d3d11va-copy` (or `nvdec-copy`). If it says just `d3d11va`, SVP cannot "see" the video frames to interpolate them.
</details>

<details>
<summary><b>Why does pressing 'Q' or 'Ctrl+Q' do nothing?</b></summary>

This is the **Logic Lockdown** feature protecting your video quality.
* **`Q` (HD Toggle):** Only works if the video is between **576p and 1080p**. It prevents you from accidentally sharpening 4K content or native 1080p.
* **`Ctrl+Q` (SD Toggle):** Only works if the video is **below 576p**.
* If the key doesn't work, it means the video resolution doesn't match the specific profile you are trying to toggle.
</details>

<details>
<summary><b>My subtitles are stretched or in the wrong place!</b></summary>

This can happen with older anime or files with hard-coded black bars.
* **Fix:** Press **`y`** (small letter).
* This cycles the subtitle logic (`none` → `aspect-ratio` → `all`).
* Keep pressing it until the subtitles look correct.
</details>

<details>
<summary><b>What if MPV crashes when using SVP 4 Pro?</b></summary>

If `mpv.exe` crashes immediately upon launch with SVP 4 Pro enabled, follow these steps to fix the library conflict:

1.  **Locate SVP Files:** Go to your SVP 4 installation folder (usually `C:\Program Files (x86)\SVP 4\mpv64` or `C:\Program Files\SVP 4\mpv64`) and **copy all files** inside.
2.  **Overwrite MPV:** Go to the folder where your `mpv.exe` is located, **paste** the files, and choose to **overwrite/replace**.
3.  **Update MPV:** Download the latest stable MPV build (Shinchiro) and extract `mpv.exe` over the top again to ensure you are on the newest version.
4.  **Restart:** Restart SVP 4 Pro and MPV.
</details>

<details>
<summary><b>Where do I put these files?</b></summary>

All files (`mpv.conf`, `input.conf`, `scripts/`, etc.) go into your MPV configuration folder:
* **Windows:** `%APPDATA%/mpv/`
* **Portable:** Inside the `portable_config` folder next to `mpv.exe`.
</details>

<details>
<summary><b>How does Auto-Detection for Anime work? (Updated v2.0)</b></summary>

The build uses a **3-Layer Detection System**:
1.  **Audio Scan:** It checks **all** audio tracks. If it finds `Japanese` (jpn/ja), it activates Anime Mode instantly (great for web streams).
2.  **Folder Name:** It checks your file path. If it sees `Anime` in the folder name, it activates Anime Mode.
3.  **Metadata:** It checks the internal title. If it sees `Live Action`, `Drama`, or `Movie`, it forces Live Action mode.

* **Manual Override:** You can force modes using **`Ctrl+l`** (Auto), **`Ctrl+;`** (Force On), or **`Ctrl+'`** (Force Off).
</details>

<br>

---

### 📮 Found a Bug?
If you are still facing issues that aren't listed here or want to Request a New Feature, please raise a New Issue or create a Feature Request:
**[Issues Page](https://github.com/Chinna95P/mpv-anime-build/issues)**