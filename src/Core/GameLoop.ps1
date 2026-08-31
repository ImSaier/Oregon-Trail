$script:OTTimerResolutionRaised = $false

function Enable-HighResolutionTimer {
    if ($script:OTTimerResolutionRaised) { return $true }
    try {
        if (-not ('OregonTrail.NativeTimer' -as [type])) {
            $sig = @'
[DllImport("winmm.dll", EntryPoint = "timeBeginPeriod")]
public static extern uint TimeBeginPeriod(uint uMilliseconds);
[DllImport("winmm.dll", EntryPoint = "timeEndPeriod")]
public static extern uint TimeEndPeriod(uint uMilliseconds);
'@
            Add-Type -MemberDefinition $sig -Name 'NativeTimer' -Namespace 'OregonTrail' -ErrorAction Stop | Out-Null
        }
        [void][OregonTrail.NativeTimer]::TimeBeginPeriod(1)
        $script:OTTimerResolutionRaised = $true
        return $true
    }
    catch {
        return $false
    }
}

function Disable-HighResolutionTimer {
    if (-not $script:OTTimerResolutionRaised) { return }
    try { [void][OregonTrail.NativeTimer]::TimeEndPeriod(1) } catch { }
    $script:OTTimerResolutionRaised = $false
}

function New-FrameClock {
    param([int]$Fps = 20)
    Enable-HighResolutionTimer | Out-Null
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    return @{
        TargetFps     = $Fps
        FrameMs       = [double](1000.0 / $Fps)
        Stopwatch     = $sw
        LastTick      = 0.0
        Deadline      = [double](1000.0 / $Fps)
        Frames        = 0
        DroppedFrames = 0
        BusyTotalMs   = 0.0
        BusyMaxMs     = 0.0
    }
}

function Step-FrameClock {
    param($Clock)
    $sw = $Clock.Stopwatch
    $now = $sw.Elapsed.TotalMilliseconds
    $busy = $now - $Clock.LastTick
    $Clock.Frames++
    $Clock.BusyTotalMs += $busy
    if ($busy -gt $Clock.BusyMaxMs) { $Clock.BusyMaxMs = $busy }
    $remaining = $Clock.Deadline - $now
    if ($remaining -le 0) {
        $Clock.DroppedFrames++
        $behind = -$remaining
        if ($behind -gt ($Clock.FrameMs * 3)) { $Clock.Deadline = $now }
    }
    else {
        if ($remaining -gt 2) {
            [System.Threading.Thread]::Sleep([int][math]::Floor($remaining - 1.5))
        }
        while ($sw.Elapsed.TotalMilliseconds -lt $Clock.Deadline) {
            [System.Threading.Thread]::SpinWait(64)
        }
    }
    $Clock.Deadline += $Clock.FrameMs
    $Clock.LastTick = $sw.Elapsed.TotalMilliseconds
    return $busy
}

