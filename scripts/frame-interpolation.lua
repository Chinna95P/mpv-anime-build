-- =========================================================
-- SMOOTH 60 FPS INTERPOLATION SCRIPT
-- Clean Toggle • Android Safe • No Spam
-- =========================================================

local mp = require "mp"
local msg = require "mp.msg"

local enabled = false

-- =========================
-- APPLY INTERPOLATION
-- =========================
local function enable_interpolation()
    mp.set_property("interpolation", "yes")
    mp.set_property("video-sync", "display-resample")
    mp.set_property("tscale", "oversample")
    mp.set_property("tscale-clamp", "0.0")
    mp.set_property("display-fps-override", "60")

    mp.osd_message("⚡ Smooth 60FPS: ON", 2)
    msg.info("Interpolation enabled")
end

-- =========================
-- DISABLE INTERPOLATION
-- =========================
local function disable_interpolation()
    mp.set_property("interpolation", "no")
    mp.set_property("video-sync", "audio")
    mp.set_property("display-fps-override", "0")

    mp.osd_message("❌ Smooth 60FPS: OFF", 2)
    msg.info("Interpolation disabled")
end

-- =========================
-- TOGGLE
-- =========================
local function toggle()
    enabled = not enabled
    if enabled then
        enable_interpolation()
    else
        disable_interpolation()
    end
end

-- =========================
-- KEY BIND
-- =========================
mp.add_key_binding("i", "toggle_smooth60", toggle)

-- Optional: auto enable on file load
mp.register_event("file-loaded", function()
     enabled = true
     enable_interpolation()
 end)