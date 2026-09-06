local mp = require "mp"
local msg = require "mp.msg"
local options = require "mp.options"
local utils = require "mp.utils"

local config = {
    enabled = true,
    mappings = "",
    fallback_device = "",
    restore_device = "auto",
    log_display_name = true,
}

options.read_options(config, "auto_audio_device")

local auto_change = config.enabled
local platform = mp.get_property_native("platform")
    or (package.config:sub(1, 1) == "\\" and "windows" or "unix")

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function read_binary_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end

    local data = file:read("*a")
    file:close()
    return data
end

local function decode_edid_name(edid)
    if type(edid) ~= "string" or #edid < 128 then
        return nil
    end

    local expected_header = "\0\255\255\255\255\255\255\0"
    if edid:sub(1, 8) ~= expected_header then
        return nil
    end

    -- EDID base blocks contain four 18-byte descriptors starting at byte 54.
    -- A descriptor tagged 0xfc contains the display product name.
    for descriptor = 0, 3 do
        local start = 55 + (descriptor * 18)
        if edid:byte(start) == 0 and edid:byte(start + 1) == 0
            and edid:byte(start + 2) == 0 and edid:byte(start + 3) == 0xfc then
            local name = edid:sub(start + 5, start + 17)
                :gsub("%z", "")
                :gsub("[\r\n]", "")
                :gsub("[%c]", "")
            name = trim(name)
            if name ~= "" then
                return name
            end
        end
    end

    -- Some displays omit the product-name descriptor. Fall back to the EDID
    -- manufacturer code and numeric product code in that case.
    local manufacturer_word = (edid:byte(9) * 256) + edid:byte(10)
    local manufacturer = string.char(
        math.floor(manufacturer_word / 1024) % 32 + 64,
        math.floor(manufacturer_word / 32) % 32 + 64,
        manufacturer_word % 32 + 64
    )
    if manufacturer:match("^[A-Z][A-Z][A-Z]$") then
        local product_code = edid:byte(11) + (edid:byte(12) * 256)
        return string.format("%s %04X", manufacturer, product_code)
    end

    return nil
end

local display_name_cache = {}

local function linux_display_name(connector)
    if display_name_cache[connector] ~= nil then
        return display_name_cache[connector] or nil
    end

    local entries = utils.readdir("/sys/class/drm", "all")
    if type(entries) ~= "table" then
        display_name_cache[connector] = false
        return nil
    end

    table.sort(entries)
    local suffix = "-" .. connector
    for _, entry in ipairs(entries) do
        if #entry > #suffix and entry:sub(-#suffix) == suffix then
            local edid = read_binary_file("/sys/class/drm/" .. entry .. "/edid")
            local name = decode_edid_name(edid)
            if name then
                display_name_cache[connector] = name
                return name
            end
        end
    end

    display_name_cache[connector] = false
    return nil
end

local function log_display(connector, product_name)
    local description = connector
    if product_name and product_name ~= connector then
        description = connector .. " (" .. product_name .. ")"
    end

    if config.log_display_name then
        msg.info("Display: " .. description)
    else
        msg.verbose("Display: " .. description)
    end

    return description
end

local windows_display_lookup_command = [=[
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$source = @'
using System;
using System.Runtime.InteropServices;

public static class MpvDisplayNameLookup
{
    private const int DISPLAY_DEVICE_ACTIVE = 0x00000001;
    private const uint EDD_GET_DEVICE_INTERFACE_NAME = 0x00000001;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct DISPLAY_DEVICE
    {
        public int cb;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string DeviceName;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceString;

        public int StateFlags;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceID;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceKey;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool EnumDisplayDevicesW(
        string lpDevice,
        uint iDevNum,
        ref DISPLAY_DEVICE lpDisplayDevice,
        uint dwFlags
    );

    private static DISPLAY_DEVICE NewDisplayDevice()
    {
        DISPLAY_DEVICE device = new DISPLAY_DEVICE();
        device.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
        return device;
    }

    public static string FindMonitor(string targetDisplay)
    {
        for (uint adapterIndex = 0; ; adapterIndex++)
        {
            DISPLAY_DEVICE adapter = NewDisplayDevice();
            if (!EnumDisplayDevicesW(null, adapterIndex, ref adapter, 0))
                break;

            if (!String.Equals(adapter.DeviceName, targetDisplay, StringComparison.OrdinalIgnoreCase))
                continue;

            string fallback = null;
            for (uint monitorIndex = 0; ; monitorIndex++)
            {
                DISPLAY_DEVICE monitor = NewDisplayDevice();
                if (!EnumDisplayDevicesW(
                    adapter.DeviceName,
                    monitorIndex,
                    ref monitor,
                    EDD_GET_DEVICE_INTERFACE_NAME
                ))
                    break;

                if (String.IsNullOrWhiteSpace(monitor.DeviceString))
                    continue;

                string result = monitor.DeviceString + "\t" + (monitor.DeviceID ?? "");
                if (fallback == null)
                    fallback = result;

                if ((monitor.StateFlags & DISPLAY_DEVICE_ACTIVE) != 0)
                    return result;
            }

            return fallback ?? "";
        }

        return "";
    }
}
'@

Add-Type -TypeDefinition $source -ErrorAction Stop
$record = [MpvDisplayNameLookup]::FindMonitor($targetDisplay)
if ([String]::IsNullOrWhiteSpace($record)) { exit 0 }

$parts = $record -split "`t", 2
$deviceString = $parts[0].Trim()
$deviceId = if ($parts.Count -gt 1) { $parts[1] } else { '' }
$friendlyName = ''

$idMatch = [regex]::Match($deviceId, '(?i)(?:DISPLAY|MONITOR)[#\\]([^#\\]+)')
if ($idMatch.Success) {
    $instancePattern = 'DISPLAY\' + $idMatch.Groups[1].Value + '\*'
    $monitor = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue |
        Where-Object { $_.Active -and $_.InstanceName -like $instancePattern } |
        Select-Object -First 1

    if ($null -ne $monitor -and $null -ne $monitor.UserFriendlyName) {
        $friendlyName = -join ($monitor.UserFriendlyName |
            Where-Object { $_ -ne 0 } |
            ForEach-Object { [char]$_ })
    }
}

if ([String]::IsNullOrWhiteSpace($friendlyName)) {
    $friendlyName = $deviceString
}

[Console]::Out.Write($friendlyName.Trim())
]=]

local windows_display_name_cache = {}
local windows_display_name_pending = {}

local function powershell_string_literal(value)
    -- PowerShell single-quoted strings escape a literal quote by doubling it.
    return "'" .. value:gsub("'", "''") .. "'"
end

local function resolve_windows_display_name(connector)
    local cached = windows_display_name_cache[connector]
    if cached ~= nil then
        log_display(connector, cached or nil)
        return
    end

    if windows_display_name_pending[connector] then
        return
    end
    windows_display_name_pending[connector] = true

    local lookup_command = "$targetDisplay = " .. powershell_string_literal(connector)
        .. "\n" .. windows_display_lookup_command

    mp.command_native_async({
        name = "subprocess",
        args = {
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-WindowStyle", "Hidden",
            "-Command", lookup_command,
        },
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }, function(success, result, error)
        windows_display_name_pending[connector] = nil

        local product_name = nil
        if success and result and result.status == 0 then
            product_name = trim((result.stdout or ""):gsub("[\r\n]+", " "))
            if product_name == "" then
                product_name = nil
            end
        else
            local detail = error
            if result and result.stderr and trim(result.stderr) ~= "" then
                detail = trim(result.stderr)
            end
            msg.verbose("Windows display-name lookup failed: " .. tostring(detail or "unknown error"))
        end

        windows_display_name_cache[connector] = product_name or false
        log_display(connector, product_name)
    end)
end

local function report_display(connector)
    if platform == "linux" or platform == "unix" then
        log_display(connector, linux_display_name(connector))
    elseif platform == "windows" and config.log_display_name then
        resolve_windows_display_name(connector)
    else
        -- MPV already reports product names on macOS. If display-name logging is
        -- disabled, Windows also avoids launching the optional lookup process.
        log_display(connector, nil)
    end
end

local function parse_mappings(value)
    local parsed = {}

    for entry in (value .. ";;"):gmatch("(.-);;") do
        entry = trim(entry)
        if entry ~= "" then
            local separator_start, separator_end = entry:find("=>", 1, true)
            if not separator_start then
                msg.warn("Ignoring invalid audio-device mapping (expected DISPLAY=>DEVICE): " .. entry)
            else
                local display = trim(entry:sub(1, separator_start - 1))
                local device = trim(entry:sub(separator_end + 1))
                if display == "" or device == "" then
                    msg.warn("Ignoring incomplete audio-device mapping: " .. entry)
                else
                    if parsed[display] then
                        msg.warn("Duplicate mapping for display '" .. display .. "'; using the last value")
                    end
                    parsed[display] = device
                end
            end
        end
    end

    return parsed
end


local device_map = parse_mappings(config.mappings)

local function configured_device(value)
    if type(value) ~= "string" then
        return nil
    end

    value = trim(value)
    if value == "" then
        return nil
    end

    return value
end

local function apply_audio_device(device)
    device = configured_device(device)
    if not device then
        return
    end

    local current_device = mp.get_property("audio-device", "auto")
    if device ~= current_device then
        msg.info("Audio device: " .. device)
        mp.osd_message("Audio device: " .. device)
        mp.set_property("audio-device", device)
    end
end

local function set_audio_device(observed_displays)
    if not auto_change then
        return
    end

    local displays = observed_displays
    if displays == nil then
        displays = mp.get_property_native("display-names")
    end

    -- An empty list is MPV's normal initial value before the VO is ready.
    if type(displays) ~= "table" or type(displays[1]) ~= "string" or displays[1] == "" then
        return
    end

    local display = displays[1]
    report_display(display)

    -- Unmatched displays intentionally leave the current device untouched unless
    -- the user explicitly configures a fallback device.
    apply_audio_device(device_map[display] or config.fallback_device)
end

mp.observe_property("display-names", "native", function(_, value)
    set_audio_device(value)
end)

mp.add_key_binding("", "set-audio-device", function()
    set_audio_device(nil)
end)

mp.add_key_binding("", "toggle-switching", function()
    auto_change = not auto_change

    if auto_change then
        set_audio_device(nil)
    else
        apply_audio_device(config.restore_device)
    end

    mp.osd_message("Audio device switching: " .. (auto_change and "enabled" or "disabled"))
end)
