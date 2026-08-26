# Query the HDR state of active Windows displays through the documented
# DisplayConfig API. Prints exactly True, False, or Fallback for hdr_detect.lua.

$source = @'
using System;
using System.Runtime.InteropServices;

public static class MpvHdrDisplayConfig
{
    private const uint QDC_ONLY_ACTIVE_PATHS = 0x00000002;
    private const uint GET_ADVANCED_COLOR_INFO = 9;
    private const uint GET_ADVANCED_COLOR_INFO_2 = 15;
    private const int ERROR_SUCCESS = 0;
    private const int MODE_INFO_SIZE = 64;

    [StructLayout(LayoutKind.Sequential)]
    private struct Luid
    {
        public uint LowPart;
        public int HighPart;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Rational
    {
        public uint Numerator;
        public uint Denominator;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PathSourceInfo
    {
        public Luid AdapterId;
        public uint Id;
        public uint ModeInfoIdx;
        public uint StatusFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PathTargetInfo
    {
        public Luid AdapterId;
        public uint Id;
        public uint ModeInfoIdx;
        public uint OutputTechnology;
        public uint Rotation;
        public uint Scaling;
        public Rational RefreshRate;
        public uint ScanLineOrdering;
        public int TargetAvailable;
        public uint StatusFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PathInfo
    {
        public PathSourceInfo SourceInfo;
        public PathTargetInfo TargetInfo;
        public uint Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct DeviceInfoHeader
    {
        public uint Type;
        public uint Size;
        public Luid AdapterId;
        public uint Id;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct AdvancedColorInfo
    {
        public DeviceInfoHeader Header;
        public uint Values;
        public uint ColorEncoding;
        public uint BitsPerColorChannel;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct AdvancedColorInfo2
    {
        public DeviceInfoHeader Header;
        public uint Values;
        public uint ColorEncoding;
        public uint BitsPerColorChannel;
        public uint ActiveColorMode;
    }

    [DllImport("user32.dll")]
    private static extern int GetDisplayConfigBufferSizes(
        uint flags, out uint pathCount, out uint modeCount);

    [DllImport("user32.dll")]
    private static extern int QueryDisplayConfig(
        uint flags,
        ref uint pathCount,
        [Out] PathInfo[] paths,
        ref uint modeCount,
        IntPtr modes,
        IntPtr currentTopologyId);

    [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo")]
    private static extern int GetAdvancedColorInfo(ref AdvancedColorInfo info);

    [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo")]
    private static extern int GetAdvancedColorInfo2(ref AdvancedColorInfo2 info);

    private static int GetPathHdrState(PathTargetInfo target)
    {
        var info2 = new AdvancedColorInfo2();
        info2.Header.Type = GET_ADVANCED_COLOR_INFO_2;
        info2.Header.Size = (uint)Marshal.SizeOf(typeof(AdvancedColorInfo2));
        info2.Header.AdapterId = target.AdapterId;
        info2.Header.Id = target.Id;

        if (GetAdvancedColorInfo2(ref info2) == ERROR_SUCCESS)
        {
            bool hdrSupported = (info2.Values & 0x10) != 0;
            if (!hdrSupported) return -1;
            return info2.ActiveColorMode == 2 ? 1 : 0;
        }

        var info = new AdvancedColorInfo();
        info.Header.Type = GET_ADVANCED_COLOR_INFO;
        info.Header.Size = (uint)Marshal.SizeOf(typeof(AdvancedColorInfo));
        info.Header.AdapterId = target.AdapterId;
        info.Header.Id = target.Id;

        if (GetAdvancedColorInfo(ref info) != ERROR_SUCCESS) return -1;

        bool advancedColorSupported = (info.Values & 0x1) != 0;
        bool advancedColorEnabled = (info.Values & 0x2) != 0;
        bool wideColorEnforced = (info.Values & 0x4) != 0;
        bool forceDisabled = (info.Values & 0x8) != 0;
        bool hdrSupported = advancedColorSupported && !wideColorEnforced && !forceDisabled;

        if (!hdrSupported) return -1;
        return advancedColorEnabled ? 1 : 0;
    }

    // Returns 1 when any active HDR display has HDR enabled, 0 when supported
    // displays are all in SDR mode, and -1 when the API cannot determine state.
    public static int GetAnyActiveHdrState()
    {
        if (Marshal.SizeOf(typeof(PathInfo)) != 72 ||
            Marshal.SizeOf(typeof(AdvancedColorInfo)) != 32 ||
            Marshal.SizeOf(typeof(AdvancedColorInfo2)) != 36)
            return -1;

        // Display topology can change between sizing and querying. Retry when
        // Windows reports that the buffers became too small (error 122).
        for (int attempt = 0; attempt < 3; attempt++)
        {
            uint pathCount;
            uint modeCount;
            if (GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out pathCount, out modeCount) != ERROR_SUCCESS ||
                pathCount == 0 || modeCount == 0)
                return -1;

            var paths = new PathInfo[pathCount];
            IntPtr modes = Marshal.AllocHGlobal(checked((int)modeCount * MODE_INFO_SIZE));
            try
            {
                int result = QueryDisplayConfig(
                    QDC_ONLY_ACTIVE_PATHS, ref pathCount, paths,
                    ref modeCount, modes, IntPtr.Zero);
                if (result == 122) continue;
                if (result != ERROR_SUCCESS) return -1;

                bool anySupported = false;
                for (int index = 0; index < pathCount; index++)
                {
                    int state = GetPathHdrState(paths[index].TargetInfo);
                    if (state == 1) return 1;
                    if (state == 0) anySupported = true;
                }
                return anySupported ? 0 : -1;
            }
            finally
            {
                Marshal.FreeHGlobal(modes);
            }
        }
        return -1;
    }
}
'@

try {
    Add-Type -TypeDefinition $source -ErrorAction Stop
    $state = [MpvHdrDisplayConfig]::GetAnyActiveHdrState()
    if ($state -eq 1) { 'True' }
    elseif ($state -eq 0) { 'False' }
    else {
        # Compatibility fallback for Windows installations that expose the
        # older optional WMI provider.
        $states = @(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorAdvancedColorProperties -ErrorAction Stop |
            ForEach-Object { [bool]$_.AdvancedColorEnabled })
        if ($states -contains $true) { 'True' }
        elseif ($states.Count -gt 0) { 'False' }
        else { 'Fallback' }
    }
} catch {
    'Fallback'
}
