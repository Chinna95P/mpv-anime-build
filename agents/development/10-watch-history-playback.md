# Watch History & Playback Continuity

## Overview
MPV Anime Build provides seamless watch history tracking (`scripts/Up_Next.lua`), automated sibling file playlist population (`scripts/autoload.lua`), and intelligent state saving (`scripts/autosave.lua` and `scripts/auto-save-state.lua`).

---

## 📜 Native Watch History (`Up_Next.lua`)

### Features
- Records the **50 most recent files** played across sessions.
- Persisted to `~~/uosc_history.json`.
- Integrates with UOSC control bar (History icon).

### Visual Progress Indicators
- Calculates watch percentage in real-time (`percent-pos`).
- Displays unicode progress blocks in the history menu.
- **95% Watched Threshold**: Files watched past 95% are marked as completed (greyed out in UI with a completion indicator).

### Up Next Dynamic Notification
When playback reaches near the end of an episode, an "Up Next" preview card pops up prompting to jump directly to the next episode.

---

## 📂 Sibling File Autoloading (`autoload.lua`)

When opening a single video file, `autoload.lua` automatically scans the containing directory and appends sibling episodes to the active MPV playlist in natural alphanumeric order.

### Blacklist Configuration (`script-opts/blacklist_extensions.conf`)
Filters out non-media assets or auxiliary files from being added to the playlist:
```conf
# blacklist_extensions.conf
blacklist=iso,bin,cue,nfo,txt,jpg,jpeg,png,gif,zip,rar,7z
```

---

## 💾 State Saving & Watch-Later

### Behavior
- `save-position-on-quit=yes` in `mpv.conf` writes resume state to `~~/watch_later/`.
- `watch-later-options-remove=vf,video-scale-x,video-scale-y,video-aspect-override,video-crop` ensures dynamic shader or crop filters are not improperly locked into future playback sessions.
- `auto-save-state.lua` periodically flushes resume points every 30 seconds during active playback.
