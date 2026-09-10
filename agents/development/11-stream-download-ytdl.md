# Stream Extraction & Download Subsystem

## Overview
`scripts/youtube-download.lua` (1,370+ lines) integrates `yt-dlp` directly into MPV and the UOSC interface, allowing one-click video, audio, and subtitle downloading from web streams (YouTube, Stremio, direct URLs).

---

## 📥 Features & UOSC Integration

### Control Bar Button
A dedicated **Download** icon is present in the UOSC bottom control bar. Clicking it opens the interactive download menu with options:
- **Download Video**: Best quality or selected resolution.
- **Download Audio Only**: Extracted high-bitrate audio (`.mp3` / `.m4a` / `.opus`).
- **Download Subtitles**: Clean `.srt` / `.vtt` extract.
- **Select Range Mode (Cut)**: Interactive interval selector to clip specific start/end timestamps from a stream without re-encoding.

### Configuration (`script-opts/youtube-download.conf`)
- `download_path`: Default destination directory (`~/ytdl`).
- `youtube_dl_exe`: Path or executable name for `yt-dlp`.
- `filename_format`: `%(title)s.%(ext)s`.

---

## 🌐 Subtitle Configuration & English-Only Requests (v5.2 Fix)

Configured in `mpv.conf` under web stream settings:
```ini
# Force yt-dlp to request English authored and auto-generated subtitles only
ytdl-format=bestvideo[height<=?2160][fps<=?60]+bestaudio/best
ytdl-raw-options=extractor-args="youtube:player_client=default,-android_sdkless"
ytdl-raw-options-append=sub-lang=en,en-orig,write-subs=,write-auto-subs=
```

### Important Rule for Developers
Do not add arbitrary language codes to `ytdl-raw-options-append` without explicit user request. Subtitle requests must remain scoped strictly to `en,en-orig` to prevent excessive bandwidth and demuxer slowdowns on web streams.
