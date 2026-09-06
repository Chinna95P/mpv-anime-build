-- power_manager.lua for mpv-anime-build v4.9
-- Features: Silent Laptop Check, Smart Resume, OSD Overlay Stacking
-- UPDATED: Increased Safety Delay to 0.5s to fix VSR Race Condition

local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- CONFIGURATION
local opts = {
    check_interval = 5,
    low_power_profile = "Low-End", 
    forced_hotkey = "toggle-power", 
}

-- PLATFORM SUPPORT
-- mpv exposes "platform" on current builds. Keep a separator-based fallback
-- for older builds so this script remains portable without user edits.
local function detect_platform()
    local value = (mp.get_property("platform") or ""):lower()
    if value == "windows" or value == "linux" then
        return value
    end
    return package.config:sub(1, 1) == "\\" and "windows" or "linux"
end

local platform = detect_platform()

local function read_trimmed(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local value = file:read("*l")
    file:close()
    return value and value:match("^%s*(.-)%s*$") or nil
end

local function find_linux_batteries()
    local batteries = {}
    local root = "/sys/class/power_supply"
    local entries = utils.readdir(root) or {}

    for _, entry in ipairs(entries) do
        local path = root .. "/" .. entry
        local supply_type = read_trimmed(path .. "/type")
        local scope = read_trimmed(path .. "/scope")
        local powers_system = scope == nil or scope:lower() == "system"
        if supply_type and supply_type:lower() == "battery" and powers_system then
            batteries[#batteries + 1] = path
        end
    end
    return batteries
end

local linux_batteries = platform == "linux" and find_linux_batteries() or {}

local function run_powershell(command)
    -- Windows PowerShell is built into supported Windows versions. pwsh is a
    -- fallback for systems that have replaced it with PowerShell 7.
    for _, executable in ipairs({"powershell.exe", "pwsh.exe", "powershell", "pwsh"}) do
        local result = mp.command_native({
            name = "subprocess",
            args = {executable, "-NoProfile", "-NonInteractive", "-Command", command},
            playback_only = false,
            capture_stdout = true,
            capture_stderr = true,
        })
        if result and result.status == 0 then
            return (result.stdout or ""):match("^%s*(.-)%s*$")
        end
    end
    return nil
end

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
    osd_overlay.data = "{\\an7}{\\fs29}{\\q1}\\N\\N" .. text
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
    resume_timer = nil,
    exit_timer = nil,
    reassert_timer = nil,
    low_power_active = false,
    saved_hwdec = nil,
    paused_by_power = false
}

-- Hybrid Helper: Broadcast + User-Data
local function update_menu_status(is_active)
    -- 1. Set User-Data (For Anime Mode Button)
    mp.set_property("user-data/power_active", is_active and "yes" or "no")
    
    -- 2. Broadcast (For UOSC Main Menu)
    local json = utils.format_json({ power_active = is_active })
    mp.commandv("script-message", "anime-state-broadcast", json)
end

-- HELPER: Check if system is a laptop
local function check_is_laptop()
    if platform == "windows" then
        local output = run_powershell(
            "$b = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue; " ..
            "if ($null -ne $b) { 'true' } else { 'false' }"
        )
        return output and output:lower() == "true" or false
    elseif platform == "linux" then
        return #linux_batteries > 0
    end
    return false
end

-- HELPER: Check Battery Status
local function check_battery_status()
    if platform == "windows" then
        local output = run_powershell(
            "$b = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue; " ..
            "if ($b | Where-Object { $_.BatteryStatus -eq 1 }) { 'true' } else { 'false' }"
        )
        return output and output:lower() == "true" or false
    elseif platform == "linux" then
        for _, path in ipairs(linux_batteries) do
            local status = read_trimmed(path .. "/status")
            if status and status:lower() == "discharging" then
                return true
            end
        end
    end
    return false
end

-- LOGIC: Apply Low Power Mode
local function apply_low_power_profile()
    mp.commandv("apply-profile", opts.low_power_profile)
end

local function cancel_timer(name)
    if state[name] then
        state[name]:kill()
        state[name] = nil
    end
end

local function schedule_low_power_reassert()
    if not state.low_power_active then return end
    cancel_timer("reassert_timer")
    state.reassert_timer = mp.add_timeout(0, function()
        state.reassert_timer = nil
        if state.low_power_active then apply_low_power_profile() end
    end)
end

local function enable_low_power()
    if state.low_power_active then return end

    -- A quick Off -> On transition must invalidate the older exit handoff.
    cancel_timer("exit_timer")
    cancel_timer("resume_timer")

    -- Preserve the decoder selected by the active platform/SVP profile. This
    -- lets the normal profile be restored without hard-coding a Windows or
    -- Linux hardware decoder.
    state.saved_hwdec = mp.get_property("hwdec")
    state.low_power_active = true

    show_power_osd(C.YELLOW .. "⚡ {\\b1}Power Saving:{\\b0} " .. C.GREEN .. "Enabled")
    msg.info("Power Manager: Switching to [Low-End]")

    local was_paused = mp.get_property_bool("pause")
    state.paused_by_power = not was_paused
    mp.set_property_bool("pause", true)

    -- Publish ownership before profile changes can trigger observers.
    update_menu_status(true)
    apply_low_power_profile()

    if state.paused_by_power then
        state.resume_timer = mp.add_timeout(2.0, function()
            state.resume_timer = nil
            if not state.low_power_active then return end
            mp.set_property_bool("pause", false)
            state.paused_by_power = false
            show_power_osd(C.YELLOW .. "⚡ {\\b1}Power Saving:{\\b0} " .. C.GREEN .. "Active")
        end)
    end
end

-- LOGIC: Restore Normal Mode
local function disable_low_power()
    if not state.low_power_active then
        update_menu_status(false)
        return
    end

    msg.info("Power Manager: Handing control to Anime Profile Controller")
    show_power_osd(C.YELLOW .. "🔌 {\\b1}AC Power:{\\b0} " .. C.CYAN .. "Restoring Smart Profile...")

    cancel_timer("resume_timer")
    cancel_timer("reassert_timer")
    cancel_timer("exit_timer")
    if state.paused_by_power then
        mp.set_property_bool("pause", false)
        state.paused_by_power = false
    end

    -- Restore exactly what was selected before Eco mode. On Windows this can
    -- be D3D11VA; on Linux it can be NVDEC, VA-API, Vulkan, or SVP copy-back.
    if state.saved_hwdec and state.saved_hwdec ~= "" then
        mp.set_property("hwdec", state.saved_hwdec)
    end
    state.saved_hwdec = nil
    state.low_power_active = false
    
    -- [STEP 1] Update Status immediately so VSR knows it can resume
    update_menu_status(false)

    -- [STEP 2] Restore every option owned by [Low-End], then let the
    -- controller select the correct profile for the current file.
    state.exit_timer = mp.add_timeout(0.5, function()
        state.exit_timer = nil
        if state.low_power_active then return end
        mp.commandv("apply-profile", opts.low_power_profile, "restore")
        mp.commandv("script-message", "force-evaluate-profile")
    end)
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
        show_power_osd(C.YELLOW .. "⚠️ {\\b1}Force Low Power:{\\b0} " .. C.RED .. "ON")
    else
        if state.on_battery then
             disable_low_power() 
             show_power_osd(C.YELLOW .. "⚠️ {\\b1}Force Low Power:{\\b0} " .. C.GREEN .. "OFF " .. C.RED .. "(Battery Warning)")
        else
             disable_low_power()
        end
    end
end

-- Respond to menu open requests
mp.register_script_message("force-evaluate-profile", function()
    -- Re-broadcast current state
    update_menu_status(state.low_power_active)
end)

-- UOSC may save an Eco-owned property while Power Saving is active. Keep the
-- saved preference for normal mode, but make Low-End authoritative right now.
mp.register_script_message("reassert-low-power", function()
    schedule_low_power_reassert()
end)

-- INITIALIZATION
mp.register_event("file-loaded", function()
    if not state.initialized then
        state.initialized = true
        update_menu_status(false) -- Init state
        if check_is_laptop() then
            msg.info((platform == "windows" and "Windows" or "Linux") .. " laptop detected. Power Monitor Active.")
            state.is_laptop = true
            state.timer = mp.add_periodic_timer(opts.check_interval, on_tick)
        else
            msg.info((platform == "windows" and "Windows" or "Linux") .. " desktop detected. Manual Toggle Only.")
        end
        mp.add_key_binding(nil, "toggle-power", toggle_force_mode)
    elseif state.low_power_active then
        -- reset-on-next-file includes vf, and metadata-dependent profiles can
        -- also run during load. Put the complete Low-End profile back on top.
        schedule_low_power_reassert()
    end
end)

-- Keep Eco last when native conditional profiles react to metadata changes.
mp.observe_property("video-params", "native", schedule_low_power_reassert)
mp.observe_property("current-tracks/video/image", "bool", schedule_low_power_reassert)
