# Audio Visualizer & DSP Processing

## Overview
MPV Anime Build features a comprehensive audio processing suite including an audio-only 0% GPU mode with live visualizers, 15-band equalizer, spatial audio (HRTF 7.1 simulation), night mode compression, and bitstream passthrough.

---

## 🎵 Audio-Only Mode

### Activation Logic
Automatically detects when playing audio-only files (music, podcasts) and switches to a lightweight profile:
```lua
-- Detection criteria:
1. vid == "no" (no video stream)
2. OR track-list has no real video tracks (not album art)
3. AND audio_only_mode == "Auto"
```

### Profile Behavior (`[Audio-Only]`)
- Clears all video processing filters and GLSL shaders
- Sets GPU load to 0% (no video frame rendering)
- Displays embedded album art if available
- Launches live audio visualizer (8 styles available)

### Operating Modes
- **Auto** (Default): Automatically activates for audio-only files
- **Disabled**: Never activates audio-only profile (useful when playing audio over static images)

---

## 🌊 Audio Visualizer Engine

Located in `scripts/audio-visualizer.lua` (264 lines).

### Visualizer Styles (8 Built-In)
1. **CQT Bars**: `showcqt` with 200px tall bars
2. **Vectorscope**: `avectorscope` line mode (L/R stereo mapping)
3. **Spectrum**: `showspectrum` with scroll mode
4. **Mirrored Stereo Lines**: `showwaves` cline with split channels
5. **Waveform**: `showwaves` p2p mode
6. **Cartesian Particles**: `avectorscope` lissajous_xy with axis grid
7. **Particles (Tri-Layer Ultra-Fast)**: 3-layer blend at 640x360 upscaled
8. **Wisp Cloud**: Multi-stage particle cloud with bloom effect

### lavfi-complex Filter Pattern
```lua
"[aid1]asplit[ao][a]; " ..
"color=c=0x101218:s=1280x720:r=60[bg]; " ..  -- UOSC background color match
"[a]showcqt=s=1280x200:fps=60[fg]; " ..
"[bg][fg]overlay=shortest=1[vo]"
```

### Script Messages
- `script-message cycle-vis-style`: Cycle to next visualizer style
- `script-message toggle-vis-state`: Toggle visualizer ON/OFF mid-playback

---

## 🎚️ 15-Band Parametric Equalizer

Implemented via `scripts/firequalizer15.lua` using FFmpeg's `firequalizer` filter.

### Band Frequencies (Hz)
```
32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k (standard 10-band)
+ 31.25, 62.5, 11.025k, 15.5k, 20k (extended)
```

### Control Integration
- Accessible through UOSC Controls → Audio → Equalizer menu
- Real-time gain adjustment per band (-12 dB to +12 dB)
- Persistent across sessions

---

## 🔊 Spatial Audio (HRTF 7.1 Simulation)

Transforms stereo/5.1 sources into virtual 7.1 surround using Head-Related Transfer Function (HRTF) processing.

### Audio Profile Hierarchy
```lua
-- No spatial, no upmix
apply-profile "Standard-Audio-PC"

-- Upmix only (7.1 channel expansion)
af="lavfi=[surround=chl_out=7.1:lfe_low=80]"

-- Spatial only (HRTF processing)
apply-profile "Cinema-Spatial-Pure"

-- Spatial + Upmix (full cinema simulation)
apply-profile "Cinema-Virtual-7.1"
```

### Script Messages
- `script-message toggle-audio-spatial`: Toggle spatial audio
- `script-message toggle-audio-upmix`: Toggle 7.1 upmix

---

## 🌙 Night Mode (Dynamic Range Compression)

Uses `dynaudnorm` (Dynamic Audio Normalizer) to compress dynamic range:
- Lowers explosions/loud peaks
- Boosts whispers/quiet dialogue
- Ideal for late-night viewing in shared spaces

### Script Message
- `script-message toggle-audio-nightmode`: Toggle night mode

---

## 📡 Bitstream Passthrough

Sends raw audio streams (TrueHD, DTS-X, Dolby Atmos) directly to an AVR/soundbar via SPDIF/HDMI.

### Activation
- Keyboard shortcut: `A` (capital A)
- Cycles between PCM decoding and bitstream passthrough
- Controlled via `audio-spdif` property

---

## 🎛️ Auto Audio Device Switching

`scripts/auto-audio-device.lua` monitors connected audio devices and switches automatically when headphones or Bluetooth speakers are connected/disconnected.

### Script Message
- `script-binding auto_audio_device/toggle-switching`: Toggle auto device switching

---

## 🎯 Quick Reference

| Feature | Shortcut | Script Message |
|---------|----------|----------------|
| 7.1 Upmix | `m` | `toggle-audio-upmix` |
| Spatial Audio | (UOSC menu) | `toggle-audio-spatial` |
| Night Mode | (UOSC menu) | `toggle-audio-nightmode` |
| Bitstream Passthrough | `A` | (uses `audio-spdif` property) |
| Cycle Visualizer | (UOSC menu) | `cycle-vis-style` |
| Equalizer | (UOSC menu) | (firequalizer15 commands) |
