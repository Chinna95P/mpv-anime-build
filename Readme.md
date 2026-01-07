MPV Anime Build is an anime-aware MPV configuration that automatically switches Anime4K, NNEDI, and SD/HD pipelines based on content. It keeps anime and live-action fully isolated, avoids manual profile switching, and includes clean OSD feedback with full PDF documentation.



\# 🎬 MPV Custom Build – Anime-Aware, Profile-Driven Setup



This MPV build is designed to \*\*automatically choose the best video profile\*\* while still giving you \*\*full manual control\*\* when needed — especially for anime playback.



It combines:

\- Smart Anime / Non-Anime detection

\- Anime4K (Fast \& HQ) with multiple modes

\- Separate SD / HD / NNEDI pipelines

\- Clean, non-persistent on-screen feedback

\- Persistent settings across files and restarts



---



\## 🔹 Core Concepts



\### Automatic Anime Detection

Anime is detected using:

\- Folder name (`/anime/`)

\- Filename patterns

\- Live-action exclusions (`live action`, `drama`, etc.)



Based on detection:

\- \*\*Anime → `anime-shaders` profile\*\*

\- \*\*Non-Anime → High-Quality / SD / NNEDI profiles\*\*



Anime shaders never leak into non-anime content.



---



\## 🔹 Anime Mode (Global Control)



Anime Mode decides \*when\* anime shaders are applied.



| Mode | Behavior |

|----|----|

| \*\*AUTO\*\* (default) | Apply anime shaders only for detected anime |

| \*\*ON\*\* | Force anime shaders for all videos |

| \*\*OFF\*\* | Disable anime shaders completely |



Anime Mode is \*\*persistent across restarts\*\*.



\### Anime Mode Shortcuts

```text

CTRL + L   → Anime Mode: AUTO

CTRL + ;   → Anime Mode: ON

CTRL + '   → Anime Mode: OFF



🔹 Anime4K System (Anime-Only)



Anime4K is strictly limited to anime playback.

It activates only when the anime-shaders profile is active.



It never affects:



Live-action



TV shows



Movies



Non-anime content



Anime4K Quality

Quality	Description

FAST	Lower GPU load, smoother playback

HQ	Maximum quality, higher GPU usage



The selected quality is remembered across anime files.



L → Toggle Anime4K Quality (FAST ↔ HQ)



Anime4K Modes



Anime4K modes control restoration strength, denoise behavior, and line emphasis.



Shortcut	Mode

CTRL + 1	A

CTRL + 2	B

CTRL + 3	C

CTRL + 4	AA

CTRL + 5	BB

CTRL + 6	CA



Important behavior



These shortcuts work only during anime playback



Pressing them during non-anime playback is ignored



Mode selection is persistent for future anime



🔹 Recommended Anime4K Modes

Modern Digital Anime (BD / Web / 1080p+)



FAST: Mode A



HQ: Mode A or AA



Best balance of sharpness and stability.



Older Anime / DVD / Soft Masters



FAST: Mode B



HQ: Mode BB



Avoids ringing and over-sharpening.



Grainy / Noisy Anime



FAST: Mode C



HQ: Mode CA



Better noise handling and cleaner edges.



Highly Stylized / Heavy Line Art



FAST: Mode AA



HQ: Mode AA



Stronger line reinforcement.



🔹 Non-Anime Video Pipeline



Non-anime content uses a completely separate processing path.



Resolution-Based Profiles

Resolution	Profile Used

< 720p	HQ-SD-Clean / HQ-SD-Texture

576p – <1080p	HQ-HD-NNEDI (Auto)

≥1080p	High-Quality

SD Profile Toggle

CTRL + Q → Toggle HQ-SD Clean ↔ Texture



NNEDI Control (HD Content Only)

Q → Force HQ-HD-NNEDI (Manual)

W → Return NNEDI to Auto



🔹 On-Screen Display (OSD) \& Information

Show Current Status

K → Show current profile \& mode (2 seconds)





Example messages:



Anime: AUTO | Anime4K: FAST (A)

Anime: ON | Anime4K: HQ (AA)

Anime: OFF | High-Quality

Anime: AUTO | HQ-HD-NNEDI



Startup Message



Shown once when a file loads



Non-persistent



Always reflects the actual active profile



🔹 Audio Enhancements

M → Toggle 7.1 Virtual Surround + LFE Boost

A → Toggle Dynamic Audio Normalization



🔹 Design Guarantees



Anime4K never applies to non-anime



Shader chains are cleared automatically when switching profiles



No permanent OSD clutter



Safe coexistence with SVP



Manual overrides are always reversible



No hidden background re-application loops



🔹 Mental Model



MPV decides the profile → You fine-tune only when needed



AUTO mode handles most cases.

Manual controls are precise, predictable, and safe.



🔹 Build Versioning

MPV Anime Build v1.0

Status: Stable





Recommended to update version when:



Changing shaders



Modifying profile logic



Adding/removing shortcuts



🔹 Backup Recommendation



Zip the entire MPV folder:



mpv-anime-build-v1.0.zip





Or use Git:



git init

git add .

git commit -m "MPV Anime Build v1.0 – stable"

git tag v1.0





Enjoy your MPV setup — it is now a clean, modular, TV-class playback system.

