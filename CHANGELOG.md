# Changelog – MPV Anime Build

All notable changes to this project are documented here.

---

## [v1.1] – Visual Refinement Update

### ✨ New Features
- **"Modern TV" Upscaling:** Added custom shader configurations (`adaptive-sharpen-modern-*.glsl`) to replicate high-end TV processing (Sony Reality Creation style) for 480p, 720p, and 1080p.
- **Smart Logic Update:** Added handlers for manual Live-Action toggles (`toggle-hq-sd`, `toggle-hq-hd-nnedi`) which were previously missing from the Lua script.
- **Visual Polish:** Added Film Grain and Dithering to High-Quality profiles for a more organic, cinematic look.

### 🐛 Fixed
- **Shader Compilation Errors:** Fixed `HOOKED : undeclared identifier` errors in `adaptive-sharpen-soft.glsl` by correcting the header definitions.
- **Logic Gaps:** Fixed an issue where shortcuts `Q`, `W`, and `Ctrl+Q` would not trigger their respective profiles in the Lua controller.
- **MPV Config:** Optimized `video-sync` and `interpolation` settings for smoother frame pacing on Windows 11.

---

## [v1.0] – Initial Stable Release

### Added
- Anime vs non-anime automatic detection
- Anime Mode: AUTO / ON / OFF
- Anime4K Fast & HQ pipelines (anime-only)
- NNEDI auto + manual modes
- SD Clean / Texture profiles
- Clean, non-persistent OSD system

### Fixed
- Persistent OSD messages
- Profile reapplication loops
- Anime4K leaking into non-anime content