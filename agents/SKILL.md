# 🎬 MPV Anime Build — Development Skill & Subsystem Router

This router indexes all subsystem documentation for **MPV Anime Build**. When working on a task, refer to the corresponding modular documentation file under `agents/development/` for detailed architectural rules, invariants, and implementation details.

---

## 🚨 Non-Negotiable Invariants

1. **NEVER commit or push automatically**: Always show `git diff` and wait for explicit user confirmation. (See [00-git-and-release-workflow.md](development/00-git-and-release-workflow.md))
2. **Version Source of Truth**: `script-opts/build_info.conf` is authoritative (never infer from `git describe`).
3. **NEVER overwrite `scripts/uosc/main.lua` with upstream UOSC**: It contains extensive custom controls and event hooks. (See [04-uosc-custom-ui.md](development/04-uosc-custom-ui.md))
4. **NEVER reset `manual_override` on `file-loaded`**: Track selections persist across playlist files. (See [07-track-selector.md](development/07-track-selector.md))
5. **Eco Mode Priority**: The `[Low-End]` profile owns rendering properties on battery; user settings must not overwrite it. (See [05-power-guard-eco.md](development/05-power-guard-eco.md))
6. **Live-Action Detection Override**: Explicit live-action titles/paths override anime folders/Japanese audio in Auto mode. (See [02-anime-profile-controller.md](development/02-anime-profile-controller.md))

---

## 🗺️ Subsystem Navigation Index

| Subsystem / Area | Focus & Key Components | Documentation Module |
| :--- | :--- | :--- |
| **Git, Releases & Versioning** | Commit rules, version sync (`build_info.conf`, README, CHANGELOG, index.html) | [`00-git-and-release-workflow.md`](development/00-git-and-release-workflow.md) |
| **Architecture & Event Flow** | MPV event lifecycle, script load order, script-message communication bus | [`01-architecture-overview.md`](development/01-architecture-overview.md) |
| **Anime Profile Controller** | [HIGH RISK] Detection matrix, resolution tiers, profile switching, state broadcast | [`02-anime-profile-controller.md`](development/02-anime-profile-controller.md) |
| **Shader Pipeline & Engines** | Shaders library, FSRCNNX Fidelity vs Anime4K, ArtCNN (Ani4Kv2/SD), Line-Thinner | [`03-shader-pipeline.md`](development/03-shader-pipeline.md) |
| **UOSC Custom UI Fork** | [HIGH RISK] UOSC 5.13.0 fork, custom buttons, history, denoise, styling controls | [`04-uosc-custom-ui.md`](development/04-uosc-custom-ui.md) |
| **Power Guard & Battery** | Cross-platform battery detection (Linux sysfs / Windows CIM), Eco `[Low-End]` mode | [`05-power-guard-eco.md`](development/05-power-guard-eco.md) |
| **Display, HDR & Scalers** | 3-Way HDR matrix (Auto/Passthrough/SDR), RTX VSR, native `spline64` scalers | [`06-display-hdr-scaling.md`](development/06-display-hdr-scaling.md) |
| **Track Selector Intelligence** | [HIGH RISK] Audio/sub matching, SDH preferred fallback, manual override persistence | [`07-track-selector.md`](development/07-track-selector.md) |
| **Audio Visualizer & DSP** | Audio-only 0% GPU profile, 15-band EQ, Spatial Audio (HRTF 7.1), Night Mode DRC | [`08-audio-visualizer-dsp.md`](development/08-audio-visualizer-dsp.md) |
| **Smart Chapters & Skip Intro** | OP/ED/PV/Intro detection, unified color palette, timeline chapter highlighting | [`09-chapter-and-skip-system.md`](development/09-chapter-and-skip-system.md) |
| **Watch History & Continuity** | 50-item watch history (`Up_Next.lua`), 95% completion, directory autoloading | [`10-watch-history-playback.md`](development/10-watch-history-playback.md) |
| **Stream Extraction & yt-dlp** | UOSC Download button integration, range cut mode, English-only stream subtitles | [`11-stream-download-ytdl.md`](development/11-stream-download-ytdl.md) |
| **Ambient Glow & Video Tools**| Real-time ambient background glow, Picture-in-Picture mode, dynamic autocrop | [`12-ambient-and-video-tools.md`](development/12-ambient-and-video-tools.md) |
| **Diagnostics & IPC Sockets** | A/V filter info ('k'), Neon Glass stats ('CTRL+i'), Thumbfast software decoding | [`13-diagnostics-and-ipc.md`](development/13-diagnostics-and-ipc.md) |
| **Configuration Hierarchy** | Load order (`mpv.conf` → `script-opts` → durable `user-*.conf` overrides) | [`14-configuration-hierarchy.md`](development/14-configuration-hierarchy.md) |

---

## 🛠️ Step-by-Step Task Execution Protocol

1. **Identify the subsystem**: Locate the relevant module from the index above.
2. **Review documentation**: Read the designated `.md` file to understand constraints and invariants.
3. **Inspect the code**: Check existing implementation in `scripts/`, `script-opts/`, or `shaders/`.
4. **Make minimal, safe changes**: Match surrounding coding idiom and respect state flows.
5. **Validate changes**: Perform syntax checks and verify cross-script message compatibility.
6. **Report git status**: Display `git diff` and summarize changes for user review.
