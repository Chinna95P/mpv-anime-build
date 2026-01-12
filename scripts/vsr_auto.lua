-- vsr_auto.lua
-- v1.5: Toggles Nvidia VSR with Smart State Restoration & Linux Safety
local mp = require 'mp'
local vsr_active = false

-- State Memory
local original_hwdec = "auto-copy"
local stored_shaders = nil
local stored_deband = nil

-- Create an OSD Overlay (Professional rendering)
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil

-- Color Codes (ASS Format: &HBBGGRR&)
local C_GREEN  = "{\\c&H00FF00&}"  -- Bright Green
local C_YELLOW = "{\\c&H00FFFF&}"  -- Yellow
local C_RED    = "{\\c&H0000FF&}"  -- Red
local C_WHITE  = "{\\c&HFFFFFF&}"  -- White (Reset)

function show_vsr_osd(text)
    overlay.data = "{\\an7}{\\fs26}" .. text
    overlay:update()
    if timer then timer:kill() end
    timer = mp.add_timeout(3, function() overlay:remove() end)
end

function toggle_vsr()
    -- 0. OS Safety Check (New)
    -- VSR depends on D3D11 (DirectX), which is Windows-only.
    local platform = mp.get_property("platform")
    if platform ~= "windows" then
        show_vsr_osd(C_RED .. "VSR Error: Windows Only (D3D11)")
        return
    end

    -- 1. Check for RTX GPU
    local renderer = mp.get_property("gpu-renderer-string", ""):upper()
    if not renderer:find("RTX") and not renderer:find("NVIDIA") then
        show_vsr_osd(C_RED .. "VSR Error: No Nvidia RTX GPU detected.")
        return
    end

    if vsr_active then
        -- DISABLE VSR
        mp.command('vf clr ""') 
        mp.set_property("hwdec", original_hwdec)
        
        -- SMART RESTORE: Re-apply the shaders/deband we saved earlier
        if stored_shaders then
            mp.set_property_native("glsl-shaders", stored_shaders)
        end
        if stored_deband then
            mp.set_property("deband", stored_deband)
        end

        -- Message: Yellow text
        show_vsr_osd(C_YELLOW .. "Nvidia VSR: Disabled " .. C_WHITE .. "(Restored Previous Config)")
        vsr_active = false
    else
        -- ENABLE VSR
        -- 1. Snapshot current state (Memory)
        original_hwdec = mp.get_property("hwdec") or "auto-copy"
        stored_shaders = mp.get_property_native("glsl-shaders")
        stored_deband  = mp.get_property("deband")

        -- 2. Apply VSR Profile
        mp.command("apply-profile Nvidia-VSR")
        
        -- 3. Clear Shaders (VSR handles scaling now)
        mp.command('no-osd change-list glsl-shaders clr ""')

        local pixel_format = mp.get_property("video-params/pixelformat", "")
        local target_format = "nv12" 
        local format_msg = "NV12 (8-bit)"

        -- Check for 10-bit source
        if pixel_format and (pixel_format:match("10") or pixel_format:match("12") or pixel_format:match("16")) then
            target_format = "p010"
            format_msg = "P010 (10-bit)"
        end

        local cmd = string.format("vf set d3d11vpp=scale=2.0:scaling-mode=nvidia:format=%s", target_format)
        mp.command(cmd)
        
        -- Message: Green text
        show_vsr_osd(C_GREEN .. "Nvidia VSR: Active " .. C_WHITE .. "(" .. format_msg .. ")")
        vsr_active = true
    end
end

mp.add_key_binding("V", "toggle-vsr-smart", toggle_vsr)