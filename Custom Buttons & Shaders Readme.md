
# Complete Guide to Lua Scripts & Shaders for mpvEX (Android)

This documentation provides a comprehensive guide on enhancing your **mpvEX** experience using Lua scripts and GLSL shaders. These tools allow you to automate tasks, add new UI elements, and significantly improve video quality through advanced upscaling and post-processing.

---

## 1. Understanding the Basics

### What are Lua Scripts?

Lua scripts are small programs that extend the functionality of the player. They can automate UI behaviors (like hiding the status bar), manage playlists, or create custom logic like "Smart Skip" and "Ambient Mode".

### What are Shaders?

Shaders (GLSL) are scripts that run on your device's GPU to process every pixel of a video frame. They are primarily used for:

* **Upscaling:** Making low-resolution video look sharp on high-resolution screens (e.g., Anime4K).
* **Correction:** Removing compression artifacts, noise, or "banding" in dark scenes.

---

## 2. Setting Up the Environment

To use scripts and shaders, you must first define a configuration directory where mpvEX can read your files.

1. **Create Folders:** In your Android internal storage, create a folder named `MPV`. Inside it, create two sub-folders: `scripts` and `shaders`.
2. **Pick Storage Location:** Open mpvEX and navigate to **Settings > Advanced**. Tap **Pick configuration storage location** and select the `MPV` folder you created.
3. **Enable Lua:** Ensure the **Enable Lua Scripts** toggle is switched **ON**.

---

## 3. Managing and Activating Scripts

Once your `.lua` files are in the `/MPV/scripts/` folder, you need to verify they are active.

* **Manage Lua Scripts:** Under the Advanced menu, tap **Manage Lua Scripts**. This screen lists all detected scripts. You can toggle individual scripts on or off here to troubleshoot performance.
* **Activation via mpv.conf:** For shaders or specific script settings, you may need to edit the `mpv.conf` file.
* *Example for Shaders:* `glsl-shader="~~/shaders/Anime4K_Upscale.glsl"`

---

## 4. Custom Buttons: The Modern Integration

The latest mpvEX update allows you to trigger Lua script commands directly from the player overlay using **Custom Buttons**. This replaces the need for complex keyboard shortcuts or gesture memorization.

### How to Add a Custom Button

1. Go to **Settings > UI > Custom Lua** (or Custom Buttons).
2. Tap an **Empty slot** to expand the editor.
3. **Button Title:** Enter the name you want to see on screen (e.g., "Anime Mode").
4. **Action Inputs:** Use the `mp.command()` syntax to link the button to a script message.

### Recommended Command Examples

Below are few examples for the precise commands to use in the **Tap action** or **Long press action** fields to call script functions:

| Feature | Command String |
| --- | --- |
| **Power Mode** | `mp.command("script-message toggle-power-mode")` |
| **Audio Mode** | `mp.command("script-message toggle-audio-mode")` |
| **Smart-Skip** | `mp.command("script-message smart-skip-audio")` |
| **Shader Toggle** | `mp.command("script-message toggle-shaders-mode")` |
| **Ambient Mode** | `mp.command("script-message toggle-ambient")` |
| **Cycle Audio** | `mp.command("script-message cycle-audio")` |

You can also customize the scripts to anything, just make sure that same variables are used for both scripts and custom buttons to sync.

---

## 5. Automation: The "On Startup" Feature

As seen in the Custom Buttons UI, there is an **On startup** field. This is ideal for scripts that you want to run every time you open a video, such as:

* Setting a specific volume level.
* Enabling "Ambient Mode" automatically.
* Applying a default shader profile.

---
