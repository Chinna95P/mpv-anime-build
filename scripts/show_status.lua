local mp = require("mp")

-- 1. Helper to wrap excessively long individual lines (like long paths)
local function wrap_text(text, limit)
local result = ""
local count = 0
for i = 1, #text do
    local char = text:sub(i, i)
    result = result .. char
    count = count + 1
    -- If we hit the character limit, inject a line break and an indent
    if count >= limit then
        result = result .. "\\N      "
        count = 0
        end
        end
        return result
        end

        -- 2. Helper to fetch filters cleanly without MPV's "%30%" string artifacts
        local function get_filters(prop)
        local filters = mp.get_property_native(prop)
        if not filters or #filters == 0 then return {"None"} end

            local list = {}
            for _, f in ipairs(filters) do
                local str = f.name
                if f.label then
                    str = "@" .. f.label .. ":" .. str
                    end

                    -- Rebuild the parameters cleanly
                    local p_list = {}
                    for k, v in pairs(f.params or {}) do
                        table.insert(p_list, k .. "=" .. tostring(v))
                        end

                        if #p_list > 0 then
                            str = str .. "=" .. table.concat(p_list, ":")
                            end
                            table.insert(list, str)
                            end
                            return list
                            end

                            -- 3. Helper to fetch Shaders as a clean list
                            local function get_shaders()
                            local shaders = mp.get_property_native("glsl-shaders")
                            if not shaders or #shaders == 0 then return {"None"} end
                                return shaders
                                end

                                -- 4. Main Display Function
                                local function show_wrapped_status()
                                local af_list = get_filters("af")
                                local vf_list = get_filters("vf")
                                local glsl_list = get_shaders()

                                local limit = 80 -- Max characters per line before wrapping

                                -- Helper to build each section block with a CUSTOM color
                                local function build_section(title, color, list)
                                -- Apply color and bold (\b1) to the header, then turn off bold (\b0) but KEEP the color for the list
                                local section = string.format("{\\c%s\\b1}%s:{\\b0}\\N", color, title)
                                for _, item in ipairs(list) do
                                    -- Bullet point for each item, wrapped safely
                                    section = section .. " • " .. wrap_text(item, limit) .. "\\N"
                                    end
                                    return section .. "\\N"
                                    end

                                    -- Construct the final overlay text using distinct ASS colors (Format: &HBBGGRR&)
                                    local msg = "{\\fscx85\\fscy85}" -- Scale text down slightly for neatness
                                    .. build_section("Audio Filters", "&H88FF88&", af_list)   -- Soft Green
                                    .. build_section("Video Filters", "&HFFFF55&", vf_list)   -- Soft Cyan
                                    .. build_section("Shaders", "&H55AAFF&", glsl_list)       -- Neon Orange

                                    -- Render the ASS formatted text to the screen
                                    mp.set_osd_ass(0, 0, msg)

                                    -- Clear OSD automatically after 7 seconds
                                    mp.add_timeout(5, function() mp.set_osd_ass(0, 0, "") end)
                                    end

                                    -- 5. Register the command for input.conf
                                    mp.register_script_message("show-status-wrapped", show_wrapped_status)
