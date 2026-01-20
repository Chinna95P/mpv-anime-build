-- [[ 
--    FILENAME: manual_zoom.lua
--    DESCRIPTION: Manual Zoom/Crop Controls for UltraWide
--    MODES: Fit (Reset), Fill (PanScan), Crop (Smart Detect)
-- ]]

local mp = require("mp")
local msg = require("mp.msg")

-- Helper: Silent Remove
local function safe_remove(label)
    local vf = mp.get_property("vf") or ""
    if string.find(vf, label) then mp.command("no-osd vf remove " .. label) end
end

-- 1. FIT-TO-ZOOM (Reset)
mp.register_script_message("zoom-mode-fit", function()
    safe_remove("@autocrop")
    mp.set_property("panscan", "0.0")
    mp.set_property("video-zoom", "0")
    
    mp.osd_message("Zoom: Fit (Original)", 2)
    mp.commandv("script-message", "zoom-state-update", "fit")
end)

-- 2. FILL-TO-ZOOM (Force Fullscreen)
mp.register_script_message("zoom-mode-fill", function()
    safe_remove("@autocrop")
    mp.set_property("panscan", "1.0") -- Force Fill
    
    mp.osd_message("Zoom: Fill (Cropped)", 2)
    mp.commandv("script-message", "zoom-state-update", "fill")
end)

-- 3. CROP-TO-ZOOM (Smart Hard-Bar Removal)
mp.register_script_message("zoom-mode-crop", function()
    mp.osd_message("Zoom: Detecting Black Bars...", 2)
    
    -- 1. Add detector with NUCLEAR THRESHOLD (0.25)
    -- This is aggressive enough to catch almost any black bar, 
    -- even if it has noise or is dark grey.
    mp.command("no-osd vf pre @cropdetect:cropdetect=limit=0.25:round=2:reset=0")
    
    -- 2. Wait 2.0s then Apply
    mp.add_timeout(2.0, function()
        local meta = mp.get_property_native("vf-metadata/cropdetect")
        safe_remove("@cropdetect") -- Clean up detector
        
        if meta and meta["w"] and meta["h"] then
            local w, h = tonumber(meta["w"]), tonumber(meta["h"])
            local x, y = tonumber(meta["x"]), tonumber(meta["y"])
            local vw = mp.get_property_number("video-params/w")
            local vh = mp.get_property_number("video-params/h")
            
            -- Check if we actually found bars (margin of error 10px)
            if vw and w < (vw - 10) then
                local crop_cmd = string.format("@autocrop:crop=w=%s:h=%s:x=%s:y=%s", w, h, x, y)
                mp.command("no-osd vf add " .. crop_cmd)
                mp.set_property("panscan", "0.0") -- Reset panscan so crop does the work
                
                -- Calculate Aspect Ratio for OSD
                local ar = w / h
                mp.osd_message(string.format("Zoom: Cropped to %.2f:1 (%dx%d)", ar, w, h), 3)
                mp.commandv("script-message", "zoom-state-update", "crop")
                return
            end
        end
        
        mp.osd_message("Zoom: No Bars Found (Switching to Fit)", 2)
        mp.commandv("script-message", "zoom-mode-fit") -- Fallback
    end)
end)