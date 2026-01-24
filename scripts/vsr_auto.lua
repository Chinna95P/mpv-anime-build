-- vsr_auto.lua
-- v1.9.8: Fixed Messy Text in Filter OSD (Uses OSD formatted string)
local mp = require 'mp'
local utils = require 'mp.utils'

local vsr_active = false
local power_locked = false 
local was_active_before_lock = false -- Memory for Smart Resume

-- State Memory
local original_hwdec = "auto-copy"
local stored_shaders = nil
local stored_deband = nil

-- OSD Overlay
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil

function show_osd(text)
    -- \an9 = Top Right
    overlay.data = "{\\an9}{\\fs26}" .. text
    
    overlay:update()
    if timer then timer:kill() end
    timer = mp.add_timeout(4, function() overlay:remove() end)
end

-- Hybrid Update Helper
local function update_status(is_active)
    -- 1. Update user-data (For Anime Button Menu)
    mp.set_property("user-data/vsr_active", is_active and "yes" or "no")

    -- 2. Broadcast (For UOSC Main Menu)
    local json = utils.format_json({ vsr_active = is_active })
    mp.commandv("script-message", "anime-state-broadcast", json)
end

-------------------------------------------------
-- CORE VSR LOGIC (Internal)
-------------------------------------------------
local function set_vsr_state(enable, is_power_event)
    -- 1. LINUX/OS SAFETY BLOCK
    local platform = mp.get_property("platform")
    if platform ~= "windows" then
        show_osd("{\\c&H0000FF&}VSR Error: Windows Only (DirectX 11)")
        return
    end

    if enable then
        -- [ENABLE VSR]
        if power_locked and not is_power_event then
            show_osd("{\\c&H0000FF&}Locked: {\\c&HFFFFFF&}Power Saving Mode Active")
            return
        end

        original_hwdec = mp.get_property("hwdec") or "auto-copy"
        stored_shaders = mp.get_property_native("glsl-shaders")
        stored_deband  = mp.get_property("deband")

        -- Adaptive Scaling Logic...
        local v_h = mp.get_property_number("video-params/h")
        local d_h = mp.get_property_number("display-height") 
        if not d_h then d_h = mp.get_property_number("osd-height") end
        
        local scale_factor = 2.0 
        if v_h and d_h then
             local ratio = d_h / v_h
             if ratio < 1.0 then ratio = 1.0 end
             if ratio > 4.0 then ratio = 4.0 end
             scale_factor = ratio
        end
        scale_factor = math.floor(scale_factor * 100 + 0.5) / 100

        mp.command("apply-profile Nvidia-VSR")
        mp.command('no-osd change-list glsl-shaders clr ""') 

        local p_fmt = mp.get_property("video-params/pixelformat", "")
        local fmt = "nv12"
        local msg = "NV12"
        if p_fmt and (p_fmt:match("10") or p_fmt:match("12") or p_fmt:match("16")) then
            fmt = "p010"
            msg = "P010"
        end
        
        -- Suppress Native OSD
        mp.command(string.format("no-osd vf set d3d11vpp=scale=%.2f:scaling-mode=nvidia:format=%s", scale_factor, fmt))
        
        -- [SILENT MODE CHECK]
        if not power_locked and not is_power_event then
             -- [FIX 1.9.8] Use get_property_osd to get clean, readable text
             local filters = mp.get_property_osd("vf") or "d3d11vpp"
             
             -- Construct message
             local header = "{\\c&H00FF00&}Nvidia VSR: Active {\\c&HFFFFFF&}(" .. msg .. " - Scale: x" .. scale_factor .. ")"
             local footer = "\\N\\N{\\fs16}{\\c&HAAAAAA&}Filters: " .. filters
             
             show_osd(header .. footer)
        end
        vsr_active = true

    else
        -- [DISABLE VSR]
        mp.command('no-osd vf clr ""') 
        mp.set_property("hwdec", original_hwdec)
        
        if is_power_event or power_locked then
            mp.command('no-osd change-list glsl-shaders clr ""')
        else
            -- Normal User Toggle
            if stored_shaders then mp.set_property_native("glsl-shaders", stored_shaders) end
            if stored_deband then mp.set_property("deband", stored_deband) end
            show_osd("{\\c&H00FFFF&}Nvidia VSR: Disabled {\\c&HFFFFFF&}(Restored Config)")
        end
        
        vsr_active = false
    end
    
    update_status(vsr_active)
end

-------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------

-- 1. USER TOGGLE
function user_toggle_vsr()
    set_vsr_state(not vsr_active, false)
end

-- 2. BROADCAST LISTENER (Power Events)
mp.register_script_message("anime-state-broadcast", function(json)
    local data = utils.parse_json(json)
    if not data then return end
    
    if data.power_active ~= nil then
        local new_power_state = data.power_active
        
        if new_power_state ~= power_locked then
            power_locked = new_power_state
            
            if power_locked then
                -- [BATTERY DETECTED]
                if vsr_active then
                    was_active_before_lock = true
                    set_vsr_state(false, true) 
                else
                    was_active_before_lock = false
                end
            else
                -- [AC POWER RESTORED]
                if was_active_before_lock then
                    set_vsr_state(true, true) 
                    was_active_before_lock = false
                end
            end
        end
    end
end)

mp.register_script_message("force-evaluate-profile", function()
    update_status(vsr_active)
end)

mp.add_key_binding("V", "toggle-vsr", user_toggle_vsr)