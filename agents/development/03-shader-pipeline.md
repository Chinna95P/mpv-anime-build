# Shader Pipeline & Upscaling Engines

## Overview
MPV Anime Build includes a library of over 30 custom GLSL shaders located in `shaders/`. The pipeline features two distinct processing paradigms for anime (FSRCNNX Fidelity vs. Anime4K Performance) and a dedicated Live-Action adaptive pipeline.

---

## 🎨 Anime Engines

### 1. Fidelity Mode (FSRCNNX / Purist)
* **Goal**: "Show exactly what the artist drew." Preserves natural line art, authentic textures, and subtle film grain without artificial painting artifacts.
* **Tiers & Resolution Mapping**:
  * **SD (< 576p)**: Uses `FSRCNNX_x2_16-0-4-1_anime_aggressive.glsl` (deep reconstruction) + Anime Line-Thinner + Adaptive Sharpening SD curve.
  * **HD (720p)**: Uses `FSRCNNX_x2_16-0-4-1_anime_mild.glsl` (balanced refinement) + Anime Line-Thinner + Adaptive Sharpening HD curve.
  * **FHD (1080p)**: Native `spline64` scaler + Adaptive Sharpening 1080p curve + Line-Thinner (`Ctrl+j`).
  * **4K (2160p)**: Native 1:1 Pixel Mapping + subtle Adaptive Sharpening 4K curve.

### 2. Performance Mode (Anime4K / Stylized)
* **Goal**: "Make it look like 4K." Aggressive upscaling, line darkening/refinement, and artifact removal.
* **Tiers**:
  * **Fast**: Lightweight fragment passes designed for low-power GPUs and laptops.
  * **HQ**: Deep multi-pass reconstruction for mid/high-end dedicated GPUs.
  * **Ultra**: Unified Th-Underscore shader suite with advanced de-aliasing and blur-pull stages.
* **Modes**:
  * `Mode A` (`CTRL+1`): Blur / De-blur + Upscaling (ideal for blurry 720p sources)
  * `Mode B` (`CTRL+2`): Denoise + Upscaling (ideal for noisy/compressed anime)
  * `Mode C` (`CTRL+3`): De-ring + Upscaling (ideal for ringed or low-bitrate streams)
  * `Mode AA` (`CTRL+4`): Anti-Aliasing + Mode A combination
  * `Mode BB` (`CTRL+5`): Anti-Aliasing + Mode B combination
  * `Mode CA` (`CTRL+6`): De-ring + Mode A combination

### 3. Next-Gen ArtCNN Compute Engines
* **Ani4Kv2** (`CTRL+7`): Next-gen neural upscaling using ArtCNN C4F32 models. Fast quality uses fragment shaders (`_i2`/`_i4`), while HQ triggers parallel compute pipelines (`*_CMP.glsl`).
* **AniSD** (`CTRL+8`): Specially tuned ArtCNN network for deep restoration of vintage 480p/576p SD anime.

---

## 🎬 Live-Action Pipeline

Non-anime content uses a dedicated "Modern TV" adaptive pipeline:

| Resolution Tier | Engine Options | Purpose |
| :--- | :--- | :--- |
| **SD (< 576p)** | `HQ-SD-Clean` (NNEDI3 32-neuron)<br>`HQ-SD-Texture` (NNEDI3 64-neuron)<br>`HQ-SD-FSRCNNX` | Clean artifact removal vs. texture reconstruction vs. sharp edges. |
| **HD (720p - 1080p)** | `HQ-HD-NNEDI` (NNEDI3 geometry)<br>`HQ-HD-FSRCNNX` (FSRCNNX detail) | Geometry preservation vs. high-frequency edge sharpness. |
| **4K (2160p)** | Native 1:1 Pixel Mapping + Glaze | Bypasses upscalers; applies subtle adaptive sharpening. |
| **8K (4320p)** | `8K-Hardware-Bypass` | Completely disables post-processing to avoid GPU VRAM overflow. |

---

## 🗡️ Anime Line-Thinner & Adaptive Sharpen

### Anime Line-Thinner (`Ctrl+j`)
- Resolution-aware line thinning shaders that thin heavy or over-sharpened stroke lines.
- **Safety Rule**: Locked out during Anime4K execution to prevent severe edge distortion; active in FSRCNNX / Native modes.

### Adaptive Sharpening Suite (`CTRL+k`)
- Shaders:
  - `adaptive-sharpen-anime-SD.glsl` / `adaptive-sharpen-modern-SD.glsl`
  - `adaptive-sharpen-anime-720p.glsl` / `adaptive-sharpen-modern-HD.glsl`
  - `adaptive-sharpen-anime-1080p.glsl` / `adaptive-sharpen-modern-1080p.glsl`
  - `adaptive-sharpen-anime-4K.glsl` / `adaptive-sharpen-modern-4K.glsl`
- Strength curves are calibrated to avoid haloing or ringing on high-contrast edges.

---

## ⚙️ Native Scalers (Fallback / Shader Bypass)

When shaders are cleared or bypassed (`CTRL+g` or `CTRL+-`), MPV uses high-quality native scalers:
- **`spline64`** (Default): Smooth, stable edges with minimal ringing.
- **`ewa_lanczossharp`**: Sharper edge definition for users preferring punchy visuals.
- **`mitchell`**: Softer scaling that hides compression artifacts in low-bitrate streams.

---

## 🚨 Shader Rules for Developers

1. **Shader filenames are immutable**: Never rename or delete shader files in `shaders/` without updating `legacy_shader_names` in `anime_profile_controller.lua`.
2. **Order is functional**: In a GLSL chain, restoration must precede upscaling, and line thinning must precede sharpening.
3. **Validate at resolution boundaries**: Always verify changes at 480p, 720p, 1080p, 1440p, and 4K.
