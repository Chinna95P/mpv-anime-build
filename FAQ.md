# ❓ Frequently Asked Questions

> **⚠️ Important Note on Shortcuts:** > Whenever a shortcut is listed in **Capital Letters** (e.g., `V`, `H`, `A`), it means you must press **`Shift + key`** (e.g., `Shift+v`).  
> Shortcuts shown in lowercase (e.g., `y`) should be pressed directly without Shift.

<br>

## 🚀 Nvidia VSR (Video Super Resolution)
*Exclusive to RTX 3000/4000 (2000 Series should also work) series users.*

<details>
<summary><b>How do I enable Nvidia VSR?</b></summary>

Simply press **`V`** (`Shift+v`) on your keyboard.
* **Status: Green** ("Active") means VSR is working.
* **Status: Yellow** ("Disabled") means VSR is off.
* **Status: Red** ("Error") means no supported Nvidia GPU was found.

> **Note:** You must also enable "RTX Video Enhancement" in your **Nvidia Control Panel** (under *Adjust Video Image Settings*) and set the Quality to **4** for best results.
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
* **The Only Exception:** The **`V`** key (Nvidia VSR) will simply stay disabled on non-Nvidia cards.
* **Note:** v1.3.1 fixed hardware decoding for AMD/Intel, so you get full performance!
</details>

<br>

## 📺 HDR & Dolby Vision
*Universal support for TVs and Monitors.*

<details>
<summary><b>How do I get HDR to work on my TV?</b></summary>

**Just toggle the Windows HDR switch.**
1.  Go to Windows Display Settings and turn **"Use HDR"** to **ON**.
2.  MPV will automatically detect this and switch to **Passthrough Mode**.
3.  Your TV should show its "HDR" or "Dolby Vision" popup.
</details>

<details>
<summary><b>Why do I need to turn Windows HDR ON? Can't MPV just force it?</b></summary>

MPV *can* force Passthrough, but we use the Windows setting as a **Preference Switch**:
* **Windows HDR ON:** Triggers **Passthrough Mode** (Your Display handles the HDR).
* **Windows HDR OFF:** Triggers **Tone Mapping** (MPV converts HDR to SDR).
* *Reason:* Some users prefer the look of MPV's high-quality Tone Mapping over their monitor's native HDR implementation. This logic gives you the choice without changing config files.
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
<summary><b>How does Auto-Detection for Anime work?</b></summary>

The build looks at your folder names and file paths.
* **Anime Mode:** Activates if the file is inside a folder named `Anime` (e.g., `D:/Media/Anime/Naruto/ep1.mkv`).
* **Live Action:** Activates for everything else.
* **Manual Override:** You can force modes using **`Ctrl+L`** (Auto), **`Ctrl+;`** (Force On), or **`Ctrl+'`** (Force Off).
</details>

<br>

---

### 📮 Found a Bug?
If you are still facing issues that aren't listed here or want to Request a New Feature, please raise a New Issue or create a Feature Request:
**[Issues Page](https://github.com/Chinna95P/mpv-anime-build/issues)**