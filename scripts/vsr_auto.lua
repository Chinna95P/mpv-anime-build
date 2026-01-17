-- vsr_auto.lua
-- v1.6: Manual RTX VSR Toggle with State Broadcast
local mp = require 'mp'
local vsr_active = false

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

function toggle_vsr()
    -- 1. LINUX/OS SAFETY BLOCK
    local platform = mp.get_property("platform")
    if platform ~= "windows" then
        show_osd("{\\c&H0000FF&}VSR Error: Windows Only (DirectX 11)")
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
        mp.set_property("user-data/vsr_active", "no") -- [BROADCAST STATE]
    else
        -- ENABLE VSR
        original_hwdec = mp.get_property("hwdec") or "auto-copy"
        stored_shaders = mp.get_property_native("glsl-shaders")
        stored_deband  = mp.get_property("deband")

        -- 1. Apply Profile & Clear Shaders
        mp.command("apply-profile Nvidia-VSR")
        mp.command('no-osd change-list glsl-shaders clr ""') 

        -- 2. Format Logic (Crucial for 10-bit Anime)
        local p_fmt = mp.get_property("video-params/pixelformat", "")
        local fmt = "nv12"
        local msg = "NV12"
        if p_fmt and (p_fmt:match("10") or p_fmt:match("12") or p_fmt:match("16")) then
            fmt = "p010"
            msg = "P010"
        end
        
        -- 3. Force VSR Command
        mp.command(string.format("vf set d3d11vpp=scale=2.0:scaling-mode=nvidia:format=%s", fmt))
        
        show_osd("{\\c&H00FF00&}Nvidia VSR: Active {\\c&HFFFFFF&}(" .. msg .. " - Manual)")
        vsr_active = true
        mp.set_property("user-data/vsr_active", "yes") -- [BROADCAST STATE]
    end
end

-- Initialize state
mp.set_property("user-data/vsr_active", "no")

mp.add_key_binding("V", "toggle-vsr", toggle_vsr)