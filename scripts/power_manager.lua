-- power_manager.lua for mpv-anime-build v1.6
-- Features: Silent Laptop Check, Smart Resume, OSD Overlay Stacking
-- UPDATED: Fixed OSD Collision (\N\N), Restored Symbols (⚡ 🔌 🔒)

local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- CONFIGURATION
local opts = {
    check_interval = 5,            -- How often to check power state (seconds)
    low_power_profile = "Low-End", 
    forced_hotkey = "toggle-power", 
}

-- OSD COLORS 
local C = {
    YELLOW  = "{\\c&H00FFFF&}",
    GREEN   = "{\\c&H00FF00&}",
    RED     = "{\\c&H0000FF&}",
    WHITE   = "{\\c&HFFFFFF&}",
    CYAN    = "{\\c&HFFFF00&}"
}

-- OSD OVERLAY SYSTEM
local osd_overlay = mp.create_osd_overlay("ass-events")
local osd_timer = nil

local function hide_osd()
    osd_overlay:remove()
end

local function show_power_osd(text)
    -- Layout: Top-Left (an7)
    -- FIX: Used {\q1} (Exact Wrapping) and \\N\\N (Hard Line Breaks).
    -- This forces the text to start on 'Line 3', leaving Line 1 free for the Anime Profile OSD.
    osd_overlay.data = "{\\an7}{\\fs32}{\\q1}\\N\\N" .. text
    osd_overlay:update()
    
    if osd_timer then osd_timer:kill() end
    osd_timer = mp.add_timeout(2, hide_osd)
end

-- STATE VARIABLES
local state = {
    is_laptop = false,
    on_battery = false,
    forced_mode = false,
    initialized = false,
    timer = nil,
    resume_timer = nil
}

-- HELPER: Check if system is a laptop (SILENT VERSION)
local function check_is_laptop()
    local res = utils.subprocess({ 
        args = {"powershell", "-command", "Get-WmiObject Win32_Battery"}, 
        cancellable = false,
        playback_only = false
    })
    
    if res.status == 0 and res.stdout and res.stdout ~= "" then
        return true
    end
    return false
end

-- HELPER: Check Battery Status
local function check_battery_status()
    local res = utils.subprocess({ 
        args = {"powershell", "-command", "(Get-WmiObject Win32_Battery).BatteryStatus"}, 
        cancellable = false 
    })
    if res.status == 0 and res.stdout then
        local status = res.stdout:gsub("%s+", "")
        return (status == "1") -- 1 = Discharging
    end
    return false
end

-- LOGIC: Apply Low Power Mode
local function enable_low_power()
    if mp.get_property("profile") == opts.low_power_profile then return end

    -- Bold Label, Colored Text, Symbol Restored
    show_power_osd(C.YELLOW .. "⚡ {\\b1}Power Saving:{\\b0} " .. C.GREEN .. "Enabled")
    msg.info("Power Manager: Switching to [Low-End]")

    local was_paused = mp.get_property_bool("pause")
    mp.set_property_bool("pause", true)
    
    -- Apply Profile
    mp.commandv("apply-profile", opts.low_power_profile)

    if not was_paused then
        if state.resume_timer then state.resume_timer:kill() end
        state.resume_timer = mp.add_timeout(2.0, function()
            mp.set_property_bool("pause", false)
            show_power_osd(C.YELLOW .. "⚡ {\\b1}Power Saving:{\\b0} " .. C.GREEN .. "Active")
        end)
    end
end

-- LOGIC: Restore Normal Mode
local function disable_low_power()
    msg.info("Power Manager: Handing control to Anime Profile Controller")
    -- Bold Label, Cyan Text, Symbol Restored
    show_power_osd(C.YELLOW .. "🔌 {\\b1}AC Power:{\\b0} " .. C.CYAN .. "Restoring Smart Profile...")
    
    -- 1. Force SVP-Compatible Decoder FIRST
    mp.set_property("hwdec", "auto-copy")
    
    -- 2. Ask the Controller to re-evaluate the file
    mp.commandv("script-message", "force-evaluate-profile")
end

-- CORE: Main Loop
local function on_tick()
    if state.forced_mode then return end
    local battery_now = check_battery_status()
    
    if battery_now and not state.on_battery then
        state.on_battery = true
        enable_low_power()
    elseif not battery_now and state.on_battery then
        state.on_battery = false
        disable_low_power()
    end
end

-- MANUAL TOGGLE
local function toggle_force_mode()
    state.forced_mode = not state.forced_mode
    if state.forced_mode then
        enable_low_power()
        show_power_osd(C.YELLOW .. "🔒 {\\b1}Force Low Power:{\\b0} " .. C.RED .. "ON")
    else
        if state.on_battery then
             disable_low_power() 
             show_power_osd(C.YELLOW .. "🔒 {\\b1}Force Low Power:{\\b0} " .. C.GREEN .. "OFF " .. C.RED .. "(Battery Warning)")
        else
             disable_low_power()
        end
    end
end

-- INITIALIZATION
mp.register_event("file-loaded", function()
    if not state.initialized then
        state.initialized = true
        if check_is_laptop() then
            msg.info("Laptop detected. Power Monitor Active.")
            state.is_laptop = true
            state.timer = mp.add_periodic_timer(opts.check_interval, on_tick)
        else
            msg.info("Desktop detected. Manual Toggle Only.")
        end
        mp.add_key_binding(nil, "toggle-power", toggle_force_mode)
    end
end)