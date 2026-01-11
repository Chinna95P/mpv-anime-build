-- vsr_auto.lua
-- Toggles Nvidia VSR with colorized OSD status messages using the Overlay API.

local mp = require 'mp'
local vsr_active = false
local original_hwdec = "auto-copy"

-- Create an OSD Overlay (Professional rendering)
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil

-- Color Codes (ASS Format: &HBBGGRR&)
local C_GREEN  = "{\\c&H00FF00&}"  -- Bright Green
local C_YELLOW = "{\\c&H00FFFF&}"  -- Yellow
local C_RED    = "{\\c&H0000FF&}"  -- Red
local C_WHITE  = "{\\c&HFFFFFF&}"  -- White (Reset)

function show_vsr_osd(text)
    -- Align text to top-left or use standard OSD position (alignment 7 = top-left)
    overlay.data = "{\\an7}{\\fs26}" .. text
    overlay:update()
    
    -- Auto-hide after 3 seconds
    if timer then timer:kill() end
    timer = mp.add_timeout(3, function() overlay:remove() end)
end

function toggle_vsr()
    -- 1. Check for RTX GPU
    local renderer = mp.get_property("gpu-renderer-string", ""):upper()
    if not renderer:find("RTX") and not renderer:find("NVIDIA") then
        show_vsr_osd(C_RED .. "VSR Error: No Nvidia GPU detected.")
        return
    end

    if vsr_active then
        -- DISABLE VSR
        mp.command('vf clr ""') 
        mp.set_property("hwdec", original_hwdec)
        
        -- Message: Yellow text
        show_vsr_osd(C_YELLOW .. "Nvidia VSR: Disabled " .. C_WHITE .. "(Restored " .. original_hwdec .. ")")
        vsr_active = false
    else
        -- ENABLE VSR
        original_hwdec = mp.get_property("hwdec") or "auto-copy"
        mp.command("apply-profile Nvidia-VSR")
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