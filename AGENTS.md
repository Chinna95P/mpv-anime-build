# MPV Anime Build — Project Instructions

## Project

- **Project:** MPV Anime Build
- **Current version:** v5.0
- **Repository:** https://github.com/Chinna95P/mpv-anime-build

## General development rules

- This is a heavily customized MPV configuration project.
- Preserve existing functionality unless the user explicitly asks to change it.
- Prefer minimal, targeted changes over broad rewrites.
- Understand existing code and dependencies before modifying it.
- Do not replace customized implementations with upstream code blindly.
- When updating an upstream component, compare the existing customized version with the upstream versions and port customizations deliberately.
- Preserve existing filenames, directory structure, script names, shader names, configuration names, and public script-message interfaces unless explicitly asked to change them.
- Maintain both Linux and Windows compatibility where the affected feature supports both platforms.
- Do not make unrelated cleanup/refactoring changes while implementing a requested feature.

## Git rules

- Never commit automatically.
- Never push automatically.
- Never reset, checkout, rebase, merge, or modify Git history unless explicitly instructed.
- Never discard the user's uncommitted changes.
- Before significant modifications, inspect Git status and understand the current working tree.
- After modifications, show the user the relevant Git diff and summarize the changed files.
- The user prefers to test changes locally before committing or pushing to GitHub.

## Version rules

- The authoritative application version is `script-opts/build_info.conf`.
- Keep `build_info.conf`, README, CHANGELOG, website version information, and release metadata synchronized when explicitly performing a release/version update.
- Do not infer the application version from `git describe` output.
- Historical version references in changelogs/comments are not necessarily active version sources.

## UOSC rules

- UOSC is currently version 5.13.0.
- `scripts/uosc/main.lua` is heavily customized.
- Never replace `scripts/uosc/main.lua` with an upstream version without first identifying and preserving MPV Anime Build customizations.
- When upgrading UOSC, compare:
  1. clean previous upstream UOSC;
  2. current customized UOSC;
  3. new upstream UOSC;
  and perform a deliberate three-way port.
- Preserve Anime Build UOSC menus, history, denoise controls, shader/profile controls, HDR controls, audio-only controls, download integration, chapter highlighting, state synchronization, and other custom functionality.
- Treat `scripts/uosc/elements/`, `scripts/uosc/lib/`, `scripts/uosc/intl/`, and `script-opts/uosc.conf` as part of the UOSC integration and check compatibility when changing UOSC.
- Do not introduce duplicate UOSC functionality when the upstream version already provides an appropriate mechanism.

## Anime profile controller

- `anime_profile_controller.lua` is a high-risk/core file.
- It controls anime/live-action detection, resolution tiers, shader selection/order, persistence, profile switching, UOSC state synchronization, and public script-message interfaces.
- Before changing it, understand its state flow and all callers.
- Preserve existing script-message names and state keys unless explicitly instructed otherwise.
- Changes to shader chains must be checked against the corresponding UI labels, persistence logic, and resolution tiers.

## Shader rules

- Preserve existing shader filenames and directory structure.
- Do not rename or remove shaders unless explicitly instructed.
- Treat shader ordering as functional.
- Check resolution-specific chains carefully.
- Changes to Adaptive Sharpen, Anime Line-Thinner, FSRCNNX, NNEDI3, Anime4K, ArtCNN, restoration, downscaling, and related shader stages must be tested at the relevant resolutions.
- Do not optimize shader chains purely by appearance of the code; understand their runtime purpose first.

## Audio-only and visualizer rules

- Audio-only mode must avoid unnecessary video processing.
- Preserve existing visualizer lifecycle and style persistence.
- Changes involving `audio-visualizer.lua`, audio profiles, equalizer, album art, spatial audio, passthrough, or audio-device selection should be tested together.

## Track selector rules

- `track-selector.lua` uses smart audio/subtitle selection.
- Manual track changes create a manual override.
- Manual override is intended to remain active for the current MPV session/playlist.
- A saved per-video manual override may restore that session-level override when the same video is resumed in a later MPV session.
- Do not accidentally reset `manual_override` on `file-loaded` when moving to next/previous files.
- Preserve the console message indicating that manual override is active.
- Do not change the override semantics without explicit instruction.

## Skip Intro and chapter rules

- `skip_intro.lua` detects OP, ED, PV, and Intro chapters.
- UOSC chapter highlighting uses the same category/color mapping.
- Current category colors are:
  - Intro = `0099FF`
  - OP = `00FF00`
  - PV = `FF00FF`
  - ED = `FF8000`
- UOSC chapter range colors use transparency consistent with the timeline.
- Preserve the relationship between `skip_intro.lua` category colors and UOSC chapter-range colors.

## Download rules

- `youtube-download.lua` is integrated with the UOSC Download button.
- Default downloads go to `~/ytdl` unless changed through `youtube-download.conf`.
- Preserve stream-download functionality.
- Do not remove or rename the UOSC download binding without explicit instruction.

## mpvSockets rules

- `mpvSockets.lua` has Windows-specific behavior intended to prevent CMD flashes.
- Preserve the Windows fix when modifying IPC/socket behavior.

## Configuration rules

- `input.conf` bindings are coupled to Lua scripts and UOSC script messages.
- `script-opts/*.conf` contains important persistent configuration.
- Do not rename configuration keys casually.
- When changing a configuration option, check all scripts that read it.

## Documentation rules

- `README.md`, `CHANGELOG.md`, `FAQ.md`, `index.html`, and related website files should remain consistent with the actual implementation.
- Do not claim a feature exists unless it is actually implemented.
- Preserve historical changelog entries.
- When performing a release update, update the relevant user-facing version references consistently.

## Testing rules

- Prefer local testing before GitHub commits/pushes.
- After code changes, perform appropriate syntax/configuration checks where possible.
- For MPV Lua changes, check Lua syntax and inspect relevant MPV console output.
- For UOSC changes, test both the UI behavior and the underlying script messages.
- For shader changes, test actual playback at representative resolutions.
- For changes involving multiple scripts, test the interaction between them rather than testing only the modified file.

## Change process

Before a substantial change:

1. Inspect relevant files and callers.
2. Explain the intended approach.
3. Make the smallest safe change.
4. Validate the result.
5. Show Git diff/status.
6. Do not commit or push unless explicitly instructed.

If there is uncertainty about whether a behavior is intentional, ask the user rather than silently changing it.
