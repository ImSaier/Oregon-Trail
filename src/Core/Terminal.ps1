$script:OTTerm = @{
    Initialized      = $false
    OrigOutEncoding  = $null
    OrigCursor       = $true
    OrigTitle        = $null
    OrigCtrlC        = $false
    OrigConsoleMode  = $null
    StdOutHandle     = [IntPtr]::Zero
    AltScreen        = $false
    VtEnabled        = $false
    OffsetX          = 0
    OffsetY          = 0
}

$script:OTScreenWidth = 100
$script:OTScreenHeight = 30
$script:OTMinWidth = 100
$script:OTMinHeight = 30

function Enable-VirtualTerminal {
    if ($script:OTTerm.VtEnabled) { return $true }
    try {
        if (-not ('OregonTrail.NativeConsole' -as [type])) {
            $sig = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
            Add-Type -MemberDefinition $sig -Name 'NativeConsole' -Namespace 'OregonTrail' -ErrorAction Stop | Out-Null
        }
        $h = [OregonTrail.NativeConsole]::GetStdHandle(-11)
        if ($h -eq [IntPtr]::Zero -or $h -eq [IntPtr](-1)) { return $false }
        $mode = 0
        if (-not [OregonTrail.NativeConsole]::GetConsoleMode($h, [ref]$mode)) { return $false }
        $script:OTTerm.StdOutHandle = $h
        $script:OTTerm.OrigConsoleMode = $mode
        $newMode = $mode -bor 0x0004
        if (-not [OregonTrail.NativeConsole]::SetConsoleMode($h, $newMode)) { return $false }
        $script:OTTerm.VtEnabled = $true
        return $true
    }
    catch {
        return $false
    }
}

function Test-TerminalSize {
    try {
        $w = [Console]::WindowWidth
        $h = [Console]::WindowHeight
    }
    catch {
        return @{ Ok = $true; Width = $script:OTMinWidth; Height = $script:OTMinHeight }
    }
    return @{ Ok = ($w -ge $script:OTMinWidth -and $h -ge $script:OTMinHeight); Width = $w; Height = $h }
}

function Update-ScreenOffset {
    try {
        $w = [Console]::WindowWidth
        $h = [Console]::WindowHeight
    }
    catch {
        $script:OTTerm.OffsetX = 0
        $script:OTTerm.OffsetY = 0
        return
    }
    $ox = [math]::Floor(($w - $script:OTScreenWidth) / 2)
    $oy = [math]::Floor(($h - $script:OTScreenHeight) / 2)
    if ($ox -lt 0) { $ox = 0 }
    if ($oy -lt 0) { $oy = 0 }
    $script:OTTerm.OffsetX = $ox
    $script:OTTerm.OffsetY = $oy
}

function Initialize-Terminal {
    param(
        [ValidateSet('256', '16')][string]$ColorMode = '256'
    )
    if ($script:OTTerm.Initialized) { return }
    Initialize-Palette -Mode $ColorMode
    $script:OTTerm.OrigOutEncoding = [Console]::OutputEncoding
    try { $script:OTTerm.OrigCtrlC = [Console]::TreatControlCAsInput } catch { $script:OTTerm.OrigCtrlC = $false }
    try { $script:OTTerm.OrigCursor = [Console]::CursorVisible } catch { $script:OTTerm.OrigCursor = $true }
    try { $script:OTTerm.OrigTitle = $Host.UI.RawUI.WindowTitle } catch { $script:OTTerm.OrigTitle = $null }
    Enable-VirtualTerminal | Out-Null
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }
    try { $Host.UI.RawUI.WindowTitle = 'The Oregon Trail' } catch { }
    $init = "$script:OTESC[?1049h" + "$script:OTESC[?25l" + "$script:OTESC[?7l" + "$script:OTESC[0m" + $script:OTPalBg[0] + "$script:OTESC[2J" + "$script:OTESC[H"
    [Console]::Write($init)
    $script:OTTerm.AltScreen = $true
    $script:OTTerm.Initialized = $true
    Update-ScreenOffset
    Initialize-Screen -Width $script:OTScreenWidth -Height $script:OTScreenHeight
}

function Restore-Terminal {
    if (-not $script:OTTerm.Initialized) { return }
    Disable-HighResolutionTimer
    try {
        $restore = "$script:OTESC[0m" + "$script:OTESC[?7h" + "$script:OTESC[?25h"
        if ($script:OTTerm.AltScreen) { $restore += "$script:OTESC[?1049l" }
        [Console]::Write($restore)
        [Console]::Out.Flush()
    }
    catch { }
    if ($null -ne $script:OTTerm.OrigCtrlC) {
        try { [Console]::TreatControlCAsInput = [bool]$script:OTTerm.OrigCtrlC } catch { }
    }
    try { [Console]::CursorVisible = $script:OTTerm.OrigCursor } catch { }
    if ($null -ne $script:OTTerm.OrigOutEncoding) {
        try { [Console]::OutputEncoding = $script:OTTerm.OrigOutEncoding } catch { }
    }
    if ($null -ne $script:OTTerm.OrigTitle) {
        try { $Host.UI.RawUI.WindowTitle = $script:OTTerm.OrigTitle } catch { }
    }
    if ($script:OTTerm.VtEnabled -and $null -ne $script:OTTerm.OrigConsoleMode) {
        try { [OregonTrail.NativeConsole]::SetConsoleMode($script:OTTerm.StdOutHandle, $script:OTTerm.OrigConsoleMode) | Out-Null } catch { }
    }

    $script:OTTerm.Initialized = $false
    $script:OTTerm.AltScreen = $false
    $script:OTTerm.VtEnabled = $false
}
