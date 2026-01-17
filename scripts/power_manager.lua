-- power_manager.lua for mpv-anime-build v1.7
-- Features: Silent Laptop Check, Smart Resume, OSD Overlay Stacking
-- UPDATED: State Broadcast added for Menu Highlight (Fix 3)

local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- CONFIGURATION
local opts = {
    check_interval = 5,
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

-- [NEW] HELPER: Broadcast State for Menu Highlighting
local function update_menu_status(is_active)
    mp.set_property("user-data/power_active", is_active and "yes" or "no")
end

-- HELPER: Check if system is a laptop
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

    show_power_osd(C.YELLOW .. "⚡ {\\b1}Power Saving:{\\b0} " .. C.GREEN .. "Enabled")
    msg.info("Power Manager: Switching to [Low-End]")

    local was_paused = mp.get_property_bool("pause")
    mp.set_property_bool("pause", true)
    
    mp.commandv("apply-profile", opts.low_power_profile)
    
    -- [FIX 3] Broadcast State Active
    update_menu_status(true)

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
    show_power_osd(C.YELLOW .. "🔌 {\\b1}AC Power:{\\b0} " .. C.CYAN .. "Restoring Smart Profile...")
    
    mp.set_property("hwdec", "auto-copy")
    mp.commandv("script-message", "force-evaluate-profile")
    
    -- [FIX 3] Broadcast State Inactive
    update_menu_status(false)
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
        update_menu_status(false) -- Init state
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