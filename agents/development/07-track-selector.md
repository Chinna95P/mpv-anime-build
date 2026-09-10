# Track Selector Subsystem (High-Risk Subsystem)

## Overview
`scripts/track-selector.lua` (820+ lines) enhances MPV's native track selection by intelligently parsing subtitle and audio track metadata, filtering out commentary or signs-only tracks, and managing persistent manual user overrides.

---

## 🚨 CRITICAL HIGH-RISK INVARIANTS

### 1. Never Reset `manual_override` on `file-loaded`
When a user manually selects an audio or subtitle track (`aid`/`sid`), `manual_override` is set to `true`. This override **must persist across the entire playlist session** and not be reset when moving to the next or previous file.

### 2. Differentiate Script vs. User Changes
All script-initiated track switches must set `internal_aid_change` / `internal_sid_change` flags before executing `mp.set_property`. The property observers check these markers so internal changes are never mistaken for manual user actions.

### 3. File Transition Settling Window
During file transitions, track observers are temporarily ignored (via `ignore_track_changes = true` and a 0.5s settling timer) to prevent race conditions during demuxer initialization.

---

## 🎯 Track Selection Rules & Priorities

### Audio Track Matching
1. Matches `alang` (Japanese `jpn`/`ja`/`jp` for Anime context, English `eng`/`en` for Western media).
2. Filters out commentary, audio description, and secondary audio streams.
3. Falls back to the primary/first clean non-commentary track.

### Subtitle Track Matching
1. **Clean Dialogue Match**: Searches for tracks with "Dialogue", "Full", or "Script" in the title matching `slang` (English `eng`/`en`).
2. **Exclusion Filter**: Excludes signs-only, songs/lyrics, forced, colored, and karaoke tracks from automatic selection.
3. **Preferred-Language SDH Fallback (v5.1 Logic)**:
   - If no clean preferred-language subtitle exists, the selector chooses a preferred-language **SDH / Hearing Impaired** track before choosing a clean subtitle in an unrelated language.
   - A clean preferred-language subtitle still outranks an SDH track.

---

## 💾 Manual Override Lifecycle & Persistence

```
┌────────────────────────────────────────────────────────┐
│ User manually changes subtitle/audio track (via OSD/UI)│
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ Observer detects change != internal_aid/sid marker     │
│ → Sets manual_override = true for current session      │
│ → Persists record to track-selector-overrides.json     │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ Next file in playlist loaded                           │
│ → Session-level manual_override remains active         │
│ → Applies saved track preference to new file           │
└────────────────────────────────────────────────────────┘
```

### Resume Persistence Format
Per-video manual track selections are persisted to `~~/track-selector-overrides.json`:
```json
{
  "manual_override": true,
  "audio": { "lang": "jpn", "title": "Stereo", "codec": "aac" },
  "subtitle": { "lang": "eng", "title": "Full Dialogue", "forced": false, "hearing_impaired": false }
}
```

---

## ⚙️ Operating Modes

Controlled via `script-opts/anime-mode.conf` (`track_selector_enabled=true|false`):
- **AUTO**: Runs the smart selector, metadata scoring, and SDH fallback logic.
- **DISABLED**: Bypasses the script entirely, leaving MPV's native `slang`/`alang` logic in full control.

### Script Messages
- `script-message set-enabled <true|false>`: Enable or disable smart selector.
- `script-message toggle-enabled`: Toggle between AUTO and DISABLED.
