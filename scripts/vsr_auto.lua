-- vsr_auto.lua
-- v1.9: Manual RTX VSR Toggle with Power Saving Lock
local mp = require 'mp'
local utils = require 'mp.utils'
local vsr_active = false
local power_locked = false -- [NEW] Local state for Power Lock

-- State Memory
local original_hwdec = "auto-copy"
local stored_shaders = nil
local stored_deband = nil

-- OSD Overlay
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil

function show_osd(text)
    overlay.data = "{\\an7}{\\fs26}" .. text
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

-- [NEW] Broadcast Listener
-- We listen for the "power_active" signal from power_manager.lua
-- This guarantees we are in sync with the other locked scripts.
mp.register_script_message("anime-state-broadcast", function(json)
    local data = utils.parse_json(json)
    if not data then return end
    
    if data.power_active ~= nil then
        power_locked = data.power_active
        -- If Power Mode gets enabled while VSR is ON, force disable VSR safely
        if power_locked and vsr_active then
             toggle_vsr() 
        end
    end
end)

function toggle_vsr()
    -- 1. LINUX/OS SAFETY BLOCK
    local platform = mp.get_property("platform")
    if platform ~= "windows" then
        show_osd("{\\c&H0000FF&}VSR Error: Windows Only (DirectX 11)")
        return
    end
	
	-- [NEW] POWER SAVING SAFETY BLOCK (Robust)
    if power_locked then
        show_osd("{\\c&H0000FF&}Locked: {\\c&HFFFFFF&}Power Saving Mode Active")
        return
    end

    if vsr_active then
        -- DISABLE VSR
        mp.command('vf clr ""') 
        mp.set_property("hwdec", original_hwdec)
        
        -- Restore Shaders & Deband
        if stored_shaders then mp.set_property_native("glsl-shaders", stored_shaders) end
        if stored_deband then mp.set_property("deband", stored_deband) end

        show_osd("{\\c&H00FFFF&}Nvidia VSR: Disabled {\\c&HFFFFFF&}(Restored Config)")
        vsr_active = false
    else
        -- ENABLE VSR
        original_hwdec = mp.get_property("hwdec") or "auto-copy"
        stored_shaders = mp.get_property_native("glsl-shaders")
        stored_deband  = mp.get_property("deband")

        -- Adaptive Scaling Calculation
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

        -- 1. Apply Profile & Clear Shaders
        mp.command("apply-profile Nvidia-VSR")
        mp.command('no-osd change-list glsl-shaders clr ""') 

        -- 2. Format Logic
        local p_fmt = mp.get_property("video-params/pixelformat", "")
        local fmt = "nv12"
        local msg = "NV12"
        if p_fmt and (p_fmt:match("10") or p_fmt:match("12") or p_fmt:match("16")) then
            fmt = "p010"
            msg = "P010"
        end
        
        -- 3. Force VSR Command
        mp.command(string.format("vf set d3d11vpp=scale=%.2f:scaling-mode=nvidia:format=%s", scale_factor, fmt))
        
        show_osd("{\\c&H00FF00&}Nvidia VSR: Active {\\c&HFFFFFF&}(" .. msg .. " - Scale: x" .. scale_factor .. ")")
        vsr_active = true
    end
    
    update_status(vsr_active)
end

-- Listen for the "force-evaluate" signal (from main.lua load)
mp.register_script_message("force-evaluate-profile", function()
    update_status(vsr_active)
end)

mp.add_key_binding("V", "toggle-vsr", toggle_vsr)