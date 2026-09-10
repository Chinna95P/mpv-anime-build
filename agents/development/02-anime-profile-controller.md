# Anime Profile Controller (Core Subsystem)

## Overview
`scripts/anime_profile_controller.lua` (1,780+ lines) is the **master brain** of MPV Anime Build. It controls content detection, resolution categorization, shader selection, state persistence, UOSC synchronization, and public script-messages.

---

## 🚨 CRITICAL HIGH-RISK INVARIANTS

### 1. Never Change State Keys or Message Names
- State keys broadcasted to UOSC must remain backward compatible
- Script-message interfaces are called by `input.conf`, UOSC UI elements, and external scripts

### 2. Live-Action Override Precedence (v5.2 Fix)
`is_live_action(path, title)` **MUST** take priority over anime folder names, Japanese audio tags, and CRC tags when `anime_mode == "auto"`.

### 3. Per-Resolution Tier Persistence
Anime4K quality (`fast`/`hq`/`ultra`) and mode (`A`, `B`, `C`, `AA`, `BB`, `CA`, `Ani4Kv2`, `AniSD`) as well as Fidelity toggle (`FSRCNNX` vs `Anime4K`) are stored **independently per resolution tier** (`SD`, `HD`, `FHD`, `2K`, `4K`, `8K`).

### 4. Power Guard & Low-End Precedence
When `power_saving` is active, the `[Low-End]` profile is authoritative and must not be overwritten by resolution evaluation until Eco mode exits.

---

## 🧠 Detection Logic Matrix

### Anime Detection Flow
```lua
-- Evaluation order when anime_mode == "auto":
1. Check is_live_action(path, title)
   - Matches: "live action", "live-action", "liveaction", "drama", "real person"
   - If true -> Force LIVE-ACTION pipeline (even if in /anime/ folder or JPN audio)

2. Check Explicit Anime Path / Name:
   - Matches: "/anime/", "donghua", "3d_anime", "cartoon"
   - If true -> ANIME pipeline

3. Check Audio Track Languages:
   - Matches: "jpn", "ja", "jp" (Japanese audio stream)
   - If true -> ANIME pipeline

4. Check Release Syntax / Tags:
   - Matches standard anime release formats (e.g., [SubGroup] Title - 01 [CRC32].mkv)
   - If true -> ANIME pipeline

5. Default fallback:
   - If none match -> LIVE-ACTION pipeline
```

### Anime Mode Settings
- `auto` (`CTRL+l`): Runs the detection logic above
- `on` (`CTRL+;`): Forces Anime pipeline regardless of content
- `off` (`CTRL+'`): Forces Live-Action / Native HQ pipeline

---

## 📏 Resolution Tier Categorization

| Tier | Conditions (`video-params/w`, `video-params/h`, or filename) | Target Profile |
| :--- | :--- | :--- |
| **SD** | `h < 577` or `w < 960` | `[SD-Anime]` / `[HQ-SD-*]` |
| **HD** | `720p`, `1280x720`, `577 <= h <= 720`, `960 <= w <= 1280` | `[HD-Anime]` / `[HQ-HD-*]` |
| **FHD** | `1080p`, `1920x1080`, `720 < h <= 1080`, `1280 < w <= 1920` | `[FHD-Native]` |
| **2K** | `1080 < h < 1450` | `[2K-Anime]` |
| **4K** | `1450 <= h <= 2160` and `w <= 3840` | `[4K-Anime]` |
| **8K** | `w > 3840` or `h > 2160` | `[8K-Hardware-Bypass]` |

---

## 🎨 Shader Chains & Engine Selection

### Anime Pipeline
1. **Fidelity Mode (FSRCNNX / Purist)**:
   - **SD**: `FSRCNNX_x2_16-0-4-1_anime_aggressive.glsl` + Line-Thinner + Adaptive Sharpen
   - **HD**: `FSRCNNX_x2_16-0-4-1_anime_mild.glsl` + Line-Thinner + Adaptive Sharpen
   - **FHD**: Native `spline64` scaler + Adaptive Sharpen + Line-Thinner
   - **4K**: Native scaling + subtle Adaptive Sharpen (bypasses heavy upscalers)

2. **Performance Mode (Anime4K / Stylized)**:
   - **Tiers**: `Fast` (optimized shaders), `HQ` (high compute), `Ultra` (Th-Underscore suite)
   - **Modes**:
     - Mode A: Blur/De-blur + Upscale
     - Mode B: Denoise + Upscale
     - Mode C: De-ring + Upscale
     - Mode AA / BB / CA: Multi-pass combinations
     - Mode Ani4Kv2: ArtCNN C4F32 fragment/compute pipeline
     - Mode AniSD: ArtCNN optimized for low-res sources

3. **Line-Thinner Suite** (`Ctrl+j`):
   - Resolution-specific thinning shaders (`Anime Line-Thinner`) mapped into FSRCNNX chains.
   - Disabled during Anime4K execution to prevent artifacts.

4. **Adaptive Sharpening** (`CTRL+k`):
   - Resolution-tuned strength profiles: SD, HD, 1080p, 4K curves.

### Live-Action Pipeline
- **SD**: Choice between `[HQ-SD-Clean]` (NNEDI3), `[HQ-SD-Texture]` (NNEDI3 64-neuron), and `[HQ-SD-FSRCNNX]`.
- **HD**: Choice between `[HQ-HD-NNEDI]` (Geometry reconstruction) and `[HQ-HD-FSRCNNX]` (Sharp detail).
- **FHD/4K**: Native 1:1 Pixel Mapping + Live-Action Adaptive Sharpening.
- **8K**: `[8K-Hardware-Bypass]` - complete post-processing bypass.

---

## 📡 Script Messages & API

### Profile & Mode Controls
- `script-binding anime-mode-auto`: Set detection to Auto
- `script-binding anime-mode-on`: Force Anime mode ON
- `script-binding anime-mode-off`: Force Anime mode OFF (Live-Action)
- `script-message toggle-anime-fidelity`: Toggle FSRCNNX ↔ Anime4K
- `script-message toggle-global-shaders`: Master toggle for all GLSL shaders
- `script-message toggle-adaptive-sharpen`: Toggle Adaptive Sharpen
- `script-message toggle-line-thinner`: Toggle Anime Line-Thinner
- `script-message toggle-crop-ambient`: Toggle Ambient Glow filling

### Anime4K Controls
- `script-message set-anime4k-quality <fast|hq|ultra>`: Set quality tier
- `script-message anime4k-mode <A|B|C|AA|BB|CA|Ani4Kv2|AniSD>`: Set mode

### Live-Action Toggles
- `script-message toggle-hq-sd`: Cycle SD modes (`Clean` → `Texture` → `FSRCNNX`)
- `script-message toggle-hq-hd-nnedi`: Toggle HD modes (`NNEDI3` ↔ `FSRCNNX`)

### Tone-Mapping & Display
- `script-message save-tone-mapping <curve>`: Save tone-mapping algorithm (`bt.2390`, `st2094-40`, `st2094-10`, `bt.2446a`, `spline`, `hable`, `mobius`, `reinhard`, `clip`)

---

## 🔄 State Broadcast to UOSC

`anime_profile_controller.lua` broadcasts its state JSON via `mp.commandv("script-message", "anime-state-broadcast", json)` whenever state changes or a file loads.

### Key State Fields
```json
{
  "is_anime_context": true,
  "mode_auto": true,
  "mode_on": false,
  "mode_off": false,
  "resolution_tier": "FHD",
  "current_profile": "FHD-Native",
  "anime_fidelity": true,
  "anime4k_allowed": false,
  "anime4k_quality": "fast",
  "shaders_enabled": true,
  "sharpen_active": true,
  "line_thinner_enabled": true
}
```

---

## ⚠️ Important Developer Rules

1. **Test at multiple resolutions**: Any change to shader mapping must be verified against SD (<576p), 720p, 1080p, 1440p, and 4K media.
2. **Never optimize chains blindly**: Shader order is functional. Placing de-blur after upscaling or line-thinning before denoising alters the visual output dramatically.
3. **Preserve `normalize_shader_path`**: Handles legacy shader name migrations (e.g., `_enhance_anime` → `_anime_mild`).
4. **Avoid synchronous subprocess blocking**: All property inspections and file checks must be non-blocking.
