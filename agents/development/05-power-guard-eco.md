# Power Guard & Eco Mode

## Overview
`scripts/power_manager.lua` provides cross-platform battery detection and automatic power-saving profile switching for laptops and portable systems.

---

## 🔋 Cross-Platform Battery Detection

### Windows Detection
Uses PowerShell with CIM/WMI fallback:
```powershell
Get-CimInstance -ClassName Win32_Battery | Select-Object BatteryStatus
```
- `BatteryStatus == 1`: Discharging (on battery)
- `BatteryStatus == 2`: Connected to AC (charging/charged)

### Linux Detection
Reads native `/sys/class/power_supply/` interface:
```bash
/sys/class/power_supply/BAT0/type        # Must be "Battery"
/sys/class/power_supply/BAT0/scope       # Must be "System" (not "Device")
/sys/class/power_supply/BAT0/status      # "Discharging" = on battery
```

**Peripheral Battery Filter (v5.0 Fix)**:
- Filters out `scope=Device` batteries (wireless mouse, keyboard, headsets).
- Only `scope=System` or missing scope attribute qualifies as a system battery.

---

## 🖥️ Desktop vs. Laptop Mode

### Auto-Detection
- **Laptop**: System has at least one qualifying battery → Automatic battery monitoring enabled.
- **Desktop**: No batteries found → **Manual Toggle Only** mode (`Ctrl+P` or UOSC power menu).

---

## ⚡ Eco Mode Behavior

### Entering Eco Mode (On Battery / Manual Activation)
```lua
1. Save current hwdec decoder (preserves D3D11VA, NVDEC, VA-API, Vulkan, SVP copy-back)
2. Pause playback briefly (2 seconds)
3. Apply [Low-End] profile:
   - scale=bilinear
   - cscale=bilinear
   - dscale=bilinear
   - glsl-shaders=""
   - dither-depth=no
   - framedrop=vo
4. Broadcast power_active=true to anime_profile_controller
5. Resume playback after 2 seconds
```

### Exiting Eco Mode (AC Reconnect / Manual Deactivation)
```lua
1. Restore original hwdec decoder
2. Broadcast power_active=false immediately
3. Wait 0.5 seconds (VSR race condition safety delay)
4. Restore [Low-End] profile properties to their pre-eco values
5. Trigger force-evaluate-profile (anime_profile_controller re-evaluates)
```

---

## 🛡️ Eco Profile Ownership (v5.1 Durable Ownership)

### Problem Solved
Prior to v5.1, user settings saved via UOSC Controls could overwrite Eco-owned properties (like `scale=bilinear`), causing shaders to unexpectedly re-activate on battery.

### Solution
`power_manager.lua` reads the `[Low-End]` profile definition and marks all its properties as "power-owned":
```lua
power_owned = {
  "vf", "glsl-shaders", "scale", "cscale", "dscale",
  "dither-depth", "correct-downscaling", "linear-downscaling",
  "sigmoid-upscaling", "hdr-compute-peak", "framedrop"
}
```

`user_settings.lua` checks `power_active` and skips restoring power-owned properties while Eco is active:
```lua
if power_active and power_owned[key] then
  -- Skip restoration
end
```

---

## 📡 Script Messages

### Public API
- `script-binding toggle-power`: Manual Eco toggle (`Ctrl+P`)
- `script-message force-evaluate-profile`: Re-broadcast power state
- `script-message reassert-low-power`: Re-apply Eco settings (called by user_settings after UOSC save)

### State Broadcast
```lua
mp.commandv("script-message", "anime-state-broadcast", 
  utils.format_json({ power_active = is_active }))
```

---

## 🔗 Integration with Other Subsystems

### anime_profile_controller.lua
- Reads `external_power_active` from broadcast.
- Skips all profile evaluation while `external_power_active == true`.
- Eco mode has absolute priority over resolution-based profiles.

### vsr_auto.lua
- Disables VSR automatically when Eco activates.
- **Smart Resume**: Remembers if VSR was active before Eco and restores it on AC reconnect.

### user_settings.lua
- Prevents restoring power-owned properties during Eco.
- Calls `reassert-low-power` after saving settings to ensure Eco remains authoritative.

---

## ⏱️ Timing & Race Conditions

### 0.5s VSR Safety Delay (v4.9 Fix)
When exiting Eco mode, there's a 0.5-second delay before calling `force-evaluate-profile`:
```lua
mp.add_timeout(0.5, function()
  mp.commandv("apply-profile", "Low-End", "restore")
  mp.commandv("script-message", "force-evaluate-profile")
end)
```

**Why**: VSR needs time to safely re-initialize D3D11 backend and apply its `Nvidia-VSR` profile before the controller attempts to apply shader chains.

---

## 🎯 Quick Reference

| Event | Action |
|-------|--------|
| Unplug laptop | → Enable Eco, broadcast `power_active=true`, disable shaders |
| Reconnect AC | → Restore hwdec, broadcast `power_active=false`, wait 0.5s, restore profile |
| Desktop detected | → Manual toggle only, no battery monitoring |
| Wireless mouse battery low | → Ignored (scope=Device filtered out) |
| User saves UOSC setting during Eco | → Setting saved but NOT applied until AC reconnect |
