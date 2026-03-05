-- =================================================================================
-- MPV ANDROID: AUDIO OUTPUT CYCLER
-- Tap = Cycle | Long Press = Reset
-- Adds micro pause for smooth switching
-- =================================================================================

local mp = require 'mp'

-- =================================================================================
-- CONFIG
-- =================================================================================
local audio_outputs = {
    "audiotrack",
    "aaudio",
    "opensles",
    "oboe"
}

local default_output = "audiotrack"

local opts = {
    accent_color = "00FFAA",
    reset_color  = "FF4444",
    bg_color     = "000000",
    bg_opacity   = "55",
    switch_delay = 0.7   -- seconds to pause during switch
}

-- =================================================================================
-- STATE
-- =================================================================================
local overlay = mp.create_osd_overlay("ass-events")
local current_index = 1

-- =================================================================================
-- FIND CURRENT AO
-- =================================================================================
local function update_current_index()
    local current = mp.get_property("ao")
    for i, v in ipairs(audio_outputs) do
        if v == current then
            current_index = i
            return
        end
    end
    current_index = 1
end

-- =================================================================================
-- TOP CENTER OVERLAY (TRUE CENTERED)
-- =================================================================================
local function show_overlay(text, color)

    local w = mp.get_property_number("osd-width")
    if not w then return end

    local x = w / 3
    local y = 90

    local style = string.format(
        "{\\an8}{\\pos(%d,%d)}{\\bord10}{\\blur8}{\\shad5}{\\3c&H%s&}{\\3a&H%s&}",
        x, y,
        opts.bg_color,
        opts.bg_opacity
    )

    local content = string.format(
        "{\\fs48}{\\b1}{\\c&H%s&}%s",
        color,
        text
    )

    overlay.data = style .. content
    overlay:update()

    mp.add_timeout(1.4, function()
        overlay:remove()
    end)
end

-- =================================================================================
-- SMOOTH SWITCH FUNCTION
-- =================================================================================
local function switch_audio(new_ao)

    local was_paused = mp.get_property_bool("pause")

    -- Pause video briefly
    mp.set_property("pause", "yes")

    mp.add_timeout(opts.switch_delay, function()
        mp.set_property("ao", new_ao)

        -- Resume only if it wasn't paused before
        if not was_paused then
            mp.set_property("pause", "no")
        end
    end)
end

-- =================================================================================
-- CYCLE
-- =================================================================================
local function cycle_audio()

    update_current_index()

    current_index = current_index + 1
    if current_index > #audio_outputs then
        current_index = 1
    end

    local new_ao = audio_outputs[current_index]

    switch_audio(new_ao)
    show_overlay("🎧 " .. new_ao:upper(), opts.accent_color)
end

-- =================================================================================
-- RESET
-- =================================================================================
local function reset_audio()

    switch_audio(default_output)
    show_overlay("RESET → " .. default_output:upper(), opts.reset_color)
end

-- =================================================================================
-- REGISTER FOR OSC
-- =================================================================================
mp.register_script_message("cycle-audio", cycle_audio)
mp.register_script_message("reset-audio", reset_audio)
