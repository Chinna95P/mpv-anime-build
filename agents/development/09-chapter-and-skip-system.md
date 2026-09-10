# Smart Chapters & Skip Intro System

## Overview
This subsystem detects opening (OP), ending (ED), preview (PV), and intro chapters across English, Japanese, and Romaji naming conventions, offering auto/manual chapter skipping (`scripts/skip_intro.lua`) and color-coded timeline visualization in UOSC (`scripts/betterchapters.lua`).

---

## 🎨 Unified Category Palette

Both `skip_intro.lua` (ASS OSD) and `uosc/main.lua` (timeline highlights) share the exact same color mapping:

| Category | Description | Hex / RGB Code | ASS BGR Code | Timeline Look |
| :--- | :--- | :--- | :--- | :--- |
| **Intro** | Prologue / Cold Open / Avant | `#FF9900` (Orange) | `0099FF` | Translucent Orange |
| **OP** | Opening Theme Song | `#00FF00` (Green) | `00FF00` | Translucent Green |
| **PV** | Next Episode Preview / Trailer | `#FF00FF` (Magenta) | `FF00FF` | Translucent Magenta |
| **ED** | Ending Theme / Credits | `#0080FF` (Blue) | `FF8000` | Translucent Blue |

*Note on ASS Format*: `skip_intro.lua` specifies colors in BGR order (`&H00BBGGRR&`), while UOSC consumes standard RGB/RGBA Hex.

---

## 🔍 Keyword Detection Matrix

Keywords matched case-insensitively against chapter titles:

```lua
categories = {
    { 
        label = "OP", 
        keywords = { 
            "opening", " op ", "♪ OP", "♪OP", "^op$", "op%d", "theme song", "main theme",
            "オープニング", "オープニングテーマ", "OPテーマ", "主題歌",
            "ncop", "creditless op", "creditless opening"
        } 
    },
    { 
        label = "ED", 
        keywords = { 
            "ending", " ed ", "♪ ED", "♪ED", "^ed$", "ed%d", "credits", "outro", "end roll",
            "エンディング", "エンディングテーマ", "EDテーマ", "結び",
            "nced", "creditless ed", "creditless ending"
        } 
    },
    { 
        label = "PV", 
        keywords = { 
            "preview", " pv ", "^pv$", "pv%d", "trailer", "next episode",
            "予告", "次回予告", "特報", "プロモーション",
            "jikai", "yokoku"
        } 
    },
    { 
        label = "Intro", 
        keywords = { 
            "intro", "introduction", "prologue", "cold open", 
            "アバン", "アバンタイトル", "序章", "前説"
        } 
    }
}
```

---

## ⚡ Performance Optimization (Cached Chapters)

In earlier versions, chapter queries ran repeatedly on timer ticks. In `skip_intro.lua` v2.2+, `chapter-list` is cached on `file-loaded`:
```lua
state.cached_chapters = mp.get_property_native("chapter-list")
```
Tick routines read from memory cache instead of querying MPV IPC, reducing idle CPU usage to zero.

---

## ⌨️ Chapter Navigation Controls

- `ENTER`: Skip current detected OP/ED/PV/Intro chapter (interactive button appears on screen).
- `z`: Jump to next chapter (`betterchapters/chapterplaylist-next`).
- `Z`: Jump to previous chapter (`betterchapters/chapterplaylist-prev`).
- `-` / `=`: Previous / Next chapter with UI flash.
