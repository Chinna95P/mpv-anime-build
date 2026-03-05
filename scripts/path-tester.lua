local mp = require 'mp'

local function show_paths()
    -- Ask mpv to expand the paths
    local config_dir = mp.command_native({"expand-path", "~~/"})
    local shaders_dir = mp.command_native({"expand-path", "~~/shaders/"})
    
    -- Format the message
    local text = string.format(
        "📂 mpv Path Tester\nBase (~~/): %s\nShaders (~~/shaders/): %s",
        config_dir or "ERROR: Not Found",
        shaders_dir or "ERROR: Not Found"
    )
    
    -- Print to the mpv log just in case
    print(text)
    
    -- Display on the OSD for 8 seconds so you have time to read it
    mp.osd_message(text, 8)
end

-- Automatically run it as soon as you open a video
mp.register_event("file-loaded", show_paths)

-- Also allows you to trigger it manually via input.conf if you prefer:
-- script-message check-paths
mp.register_script_message("check-paths", show_paths)