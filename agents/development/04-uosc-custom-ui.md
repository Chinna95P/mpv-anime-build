# UOSC Custom UI Integration (High-Risk Subsystem)

## Overview
`scripts/uosc/` contains a **heavily customized fork of UOSC v5.13.0**. It powers the modern smoked-glass on-screen controller, interactive menus, timeline highlights, and controls bar.

---

## 🚨 CRITICAL RULE: Never Replace with Upstream Directly

**`scripts/uosc/main.lua` must NEVER be overwritten with upstream UOSC code without deliberate 3-way porting.**

### UOSC Upgrade Procedure
When upgrading UOSC in the future:
1. Obtain the clean previous upstream version (v5.13.0).
2. Diff against the current customized `mpv-anime-build` version to identify all customizations.
3. Apply customizations deliberately onto the new upstream release.

---

## 🎨 Custom Features in MPV Anime Build Fork

### 1. Dedicated Open File Control Bar Button
- Opens UOSC's native file-selection browser directly from the player.
- Configured with `load_types=video,audio` and `show_hidden_files=no` to exclude poster, backdrop, and thumbnail images from file lists.

### 2. Stream Download Integration
- Integrated with `scripts/youtube-download.lua` through the dedicated **Download** control bar button.
- Default path: `~/ytdl`.

### 3. Native Watch History Menu
- Displays the 50 most recent videos with visual progress bars.
- 95% watched threshold marks files as completed (greyed-out).
- Triggered from the history button on the control bar.

### 4. Interactive Denoise Filter (`hqdn3d`)
- Dedicated sub-menu in UOSC with independent Luma and Chroma sliders.
- **Smart Hardware Fallback**: Automatically manages `hwdec` fallback to prevent MPV crashes when CPU-based video filters are engaged.

### 5. Color-Coded Chapter Ranges on Timeline
- Renders transparent colored ranges matching `skip_intro.lua`:
  - **OP (Opening)**: Green (`#00FF00`)
  - **ED (Ending)**: Blue (`#0080FF`)
  - **PV (Preview)**: Magenta (`#FF00FF`)
  - **Intro**: Orange (`#FF9900`)

### 6. Interactive Subtitle Styling
- Subtitle styling controls embedded directly in the UOSC Controls menu (font family, font size, border thickness, colors, shadows, vertical position).

### 7. Full-Screen Volume Scroll
- Allows scrolling the mouse wheel anywhere across the video area to adjust volume smoothly with custom smoked-glass volume popups.

### 8. Real-Time Anime State Synchronization
- Receives JSON state broadcasts from `anime_profile_controller.lua` via `anime-state-broadcast`.
- Dynamic menu descriptions reflect the current resolution tier, active shader quality (Fast/HQ/Ultra), and fidelity state.
- Automatically locks/disables incompatible options (e.g., locks Anime4K menus when Fidelity Mode is active).

---

## 📁 File Structure

```
scripts/uosc/
├── main.lua                # [HIGH RISK] Main UI logic, menus, event dispatching
├── elements/
│   ├── BufferingIndicator.lua
│   ├── Button.lua
│   ├── Controls.lua        # Control bar layout & buttons (Download, History, Open File)
│   ├── Curtain.lua
│   ├── CycleButton.lua
│   ├── Element.lua
│   ├── Elements.lua
│   ├── ManagedButton.lua
│   ├── Menu.lua            # Menu rendering & keyboard navigation
│   ├── PauseIndicator.lua
│   ├── Speed.lua
│   ├── Timeline.lua        # Timeline rendering with chapter color highlighting
│   ├── TopBar.lua
│   ├── Updater.lua
│   ├── Volume.lua
│   └── WindowBorder.lua
└── lib/
    ├── ass.lua
    ├── buttons.lua
    ├── char_conv.lua
    ├── cursor.lua
    ├── fzy.lua
    ├── intl.lua
    ├── menus.lua
    ├── std.lua
    ├── text.lua
    └── utils.lua
```

---

## ⚙️ Configuration (`script-opts/uosc.conf`)

Key UOSC configuration parameters tailored for this build:
- `controls`: List of buttons displayed on the bottom bar (`menu,subtitles,audio,video,playlist,history,open-file,download,fullscreen`)
- `timeline_style`: Line style with chapter markers and colored ranges
- `volume`: Right-side or popup volume bar
- `languages`: Localization settings
