$script:OTWindowPresets = @(
    @{ Label = 'Classic';     Width = 100; Height = 30 }
    @{ Label = 'Comfortable'; Width = 110; Height = 32 }
    @{ Label = 'Large';       Width = 128; Height = 40 }
    @{ Label = 'Wide';        Width = 160; Height = 48 }
)

function Get-ConsoleWindowSize {
    try {
        return @{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight }
    }
    catch {
        return $null
    }
}

function Get-MaxWindowSize {
    try {
        $w = [Console]::LargestWindowWidth
        $h = [Console]::LargestWindowHeight
        if ($w -lt 1 -or $h -lt 1) { return $null }
        return @{ Width = $w; Height = $h }
    }
    catch {
        return $null
    }
}

function Set-TerminalWindowSize {
    param([int]$Width, [int]$Height)
    $max = Get-MaxWindowSize
    if ($null -ne $max) {
        if ($Width -gt $max.Width) { $Width = $max.Width }
        if ($Height -gt $max.Height) { $Height = $max.Height }
    }
    if ($Width -lt 20) { $Width = 20 }
    if ($Height -lt 10) { $Height = 10 }
    $cur = Get-ConsoleWindowSize
    if ($null -ne $cur -and $cur.Width -eq $Width -and $cur.Height -eq $Height) {
        return @{ Ok = $true; Exact = $true; Width = $Width; Height = $Height; Wanted = @{ Width = $Width; Height = $Height } }
    }
    $resized = $false
    try {
        $bufW = [Console]::BufferWidth
        $bufH = [Console]::BufferHeight
        $newBufH = [math]::Max($bufH, $Height)
        if ($null -ne $cur -and ($Width -lt $cur.Width -or $Height -lt $cur.Height)) {
            [Console]::SetWindowSize($Width, $Height)
            [Console]::SetBufferSize($Width, $newBufH)
        }
        else {
            [Console]::SetBufferSize([math]::Max($bufW, $Width), $newBufH)
            [Console]::SetWindowSize($Width, $Height)
            [Console]::SetBufferSize($Width, $newBufH)
        }
        $resized = $true
    }
    catch {
        $resized = $false
    }
    if (-not $resized) {
        try { [Console]::Write("$([char]27)[8;$Height;${Width}t") } catch { }
        Start-Sleep -Milliseconds 150
    }
    $after = Get-ConsoleWindowSize
    if ($null -eq $after) { return @{ Ok = $false; Exact = $false; Width = $Width; Height = $Height; Wanted = @{ Width = $Width; Height = $Height } } }
    return @{
        Ok     = ($after.Width -ge $Width -and $after.Height -ge $Height)
        Exact  = ($after.Width -eq $Width -and $after.Height -eq $Height)
        Width  = $after.Width
        Height = $after.Height
        Wanted = @{ Width = $Width; Height = $Height }
    }
}

function Test-WindowsTerminal {
    return (-not [string]::IsNullOrEmpty($env:WT_SESSION))
}

function Start-GameInNewWindow {
    param([int]$Width, [int]$Height, [string]$ScriptPath, [string]$ColorMode = '256')
    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($null -eq $wt) { return $false }
    $wtArgs = @(
        '--size', ('' + $Width + ',' + $Height)
        'new-tab', '--title', 'The Oregon Trail'
        'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit'
        '-File', $ScriptPath
        '-WindowSize', 'current'
        '-ColorMode', $ColorMode
    )
    try { Start-Process -FilePath $wt.Source -ArgumentList $wtArgs | Out-Null }
    catch { return $false }
    return $true
}

function Confirm-NewWindow {
    param($Applied)
    Write-Host ''
    Write-Host '   This terminal will not resize itself from inside the game.' -ForegroundColor Yellow
    Write-Host ("   It is {0} x {1}, and you asked for {2} x {3}." -f $Applied.Width, $Applied.Height, $Applied.Wanted.Width, $Applied.Wanted.Height) -ForegroundColor DarkGray
    Write-Host '   Open a new window at that size instead? [Y/N] ' -NoNewline -ForegroundColor Gray
    while ($true) {
        $k = $null
        try { $k = [Console]::ReadKey($true) } catch { return $false }
        if ($k.KeyChar -eq 'y' -or $k.KeyChar -eq 'Y') { Write-Host 'Yes'; return $true }
        if ($k.KeyChar -eq 'n' -or $k.KeyChar -eq 'N' -or $k.Key -eq [System.ConsoleKey]::Escape -or $k.Key -eq [System.ConsoleKey]::Enter) { Write-Host 'No'; return $false }
    }
}

function ConvertTo-WindowSize {
    param([string]$Spec)
    if ([string]::IsNullOrWhiteSpace($Spec)) { return $null }
    $s = $Spec.Trim()
    if ($s -match '^(current|keep)$') { return (Get-ConsoleWindowSize) }
    if ($s -match '^(max|maximum|fit|full)$') { return (Get-MaxWindowSize) }
    foreach ($p in $script:OTWindowPresets) {
        if ($s -eq $p.Label) { return @{ Width = $p.Width; Height = $p.Height } }
    }
    if ($s -match '^(\d{2,4})\s*[xX,\*]\s*(\d{2,4})$') {
        return @{ Width = [int]$Matches[1]; Height = [int]$Matches[2] }
    }
    return $null
}

function Read-CustomWindowSize {
    $cur = Get-ConsoleWindowSize
    $curText = 'unknown'
    if ($null -ne $cur) { $curText = '' + $cur.Width + ' x ' + $cur.Height }
    while ($true) {
        try { [Console]::Clear() } catch { }
        Write-Host ''
        Write-Host '   CUSTOM WINDOW SIZE' -ForegroundColor Yellow
        Write-Host ''
        Write-Host ("   This window is {0}. The trail needs at least {1} x {2}." -f $curText, $script:OTMinWidth, $script:OTMinHeight) -ForegroundColor DarkGray
        Write-Host '   Enter a size as COLUMNS x ROWS, for example 120x36. Press ENTER alone to go back.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '   Size: ' -NoNewline -ForegroundColor Gray
        $line = $null
        try { $line = [Console]::ReadLine() } catch { return $null }
        if ([string]::IsNullOrWhiteSpace($line)) { return $null }
        $size = ConvertTo-WindowSize -Spec $line
        if ($null -eq $size) {
            Write-Host ''
            Write-Host '   That is not a size I understand. Try something like 120x36.' -ForegroundColor Red
            Start-Sleep -Milliseconds 1400
            continue
        }
        if ($size.Width -lt $script:OTMinWidth -or $size.Height -lt $script:OTMinHeight) {
            Write-Host ''
            Write-Host ("   The trail needs at least {0} x {1}." -f $script:OTMinWidth, $script:OTMinHeight) -ForegroundColor Red
            Start-Sleep -Milliseconds 1600
            continue
        }
        return $size
    }
}

function Get-WindowSizeChoices {
    $cur = Get-ConsoleWindowSize
    $max = Get-MaxWindowSize
    $items = New-Object System.Collections.ArrayList
    foreach ($p in $script:OTWindowPresets) {
        if ($null -ne $max -and ($p.Width -gt $max.Width -or $p.Height -gt $max.Height)) { continue }
        $note = ''
        if ($p.Width -eq $script:OTMinWidth -and $p.Height -eq $script:OTMinHeight) { $note = 'the smallest the trail fits in' }
        [void]$items.Add(@{
            Text = ('{0,-12} {1,3} x {2}' -f $p.Label, $p.Width, $p.Height)
            Note = $note
            Size = @{ Width = $p.Width; Height = $p.Height }
        })
    }
    if ($null -ne $max) {
        [void]$items.Add(@{
            Text = ('{0,-12} {1,3} x {2}' -f 'Maximum', $max.Width, $max.Height)
            Note = 'as large as this display allows'
            Size = @{ Width = $max.Width; Height = $max.Height }
        })
    }
    if ($null -ne $cur) {
        [void]$items.Add(@{
            Text = ('{0,-12} {1,3} x {2}' -f 'Current', $cur.Width, $cur.Height)
            Note = 'leave the window the way it is'
            Size = @{ Width = $cur.Width; Height = $cur.Height }
        })
    }
    [void]$items.Add(@{ Text = 'Custom size...'; Note = 'type your own columns and rows'; Size = $null })
    return $items
}

function Show-WindowSizeMenu {
    $items = Get-WindowSizeChoices
    $cur = Get-ConsoleWindowSize
    $sel = 0
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($null -ne $items[$i].Size -and $items[$i].Size.Width -eq 110 -and $items[$i].Size.Height -eq 32) { $sel = $i }
    }
    while ($true) {
        try { [Console]::Clear() } catch { }
        Write-Host ''
        Write-Host '   THE OREGON TRAIL' -ForegroundColor Yellow
        Write-Host '   Choose your window size' -ForegroundColor Gray
        Write-Host ''
        if ($null -ne $cur) {
            Write-Host ("   This window is {0} x {1}. The trail needs at least {2} x {3}." -f $cur.Width, $cur.Height, $script:OTMinWidth, $script:OTMinHeight) -ForegroundColor DarkGray
        }
        Write-Host ''
        for ($i = 0; $i -lt $items.Count; $i++) {
            $it = $items[$i]
            $label = ' ' + ($i + 1).ToString() + '. ' + $it.Text + ' '
            if ($i -eq $sel) {
                Write-Host '  >' -NoNewline -ForegroundColor Yellow
                Write-Host $label -ForegroundColor Black -BackgroundColor Yellow
            }
            else {
                Write-Host ('   ' + $label) -ForegroundColor Gray
            }
            if ($it.Note.Length -gt 0) {
                Write-Host ('        ' + $it.Note) -ForegroundColor DarkGray
            }
        }
        Write-Host ''
        Write-Host '   Arrow keys or number keys to choose, ENTER to accept, ESC to quit.' -ForegroundColor DarkGray
        $k = $null
        try { $k = [Console]::ReadKey($true) } catch { return $null }
        if ($k.Key -eq [System.ConsoleKey]::UpArrow) {
            $sel--
            if ($sel -lt 0) { $sel = $items.Count - 1 }
            continue
        }
        if ($k.Key -eq [System.ConsoleKey]::DownArrow) {
            $sel++
            if ($sel -ge $items.Count) { $sel = 0 }
            continue
        }
        if ($k.Key -eq [System.ConsoleKey]::Escape) { return 'Quit' }
        $pick = -1
        if ($k.Key -eq [System.ConsoleKey]::Enter -or $k.KeyChar -eq ' ') { $pick = $sel }
        elseif ($k.KeyChar -ge '1' -and $k.KeyChar -le '9') {
            $n = [int]::Parse([string]$k.KeyChar) - 1
            if ($n -lt $items.Count) { $pick = $n }
        }
        if ($pick -lt 0) { continue }
        $size = $items[$pick].Size
        if ($null -eq $size) {
            $size = Read-CustomWindowSize
            if ($null -eq $size) { continue }
        }
        return $size
    }
}

function Initialize-WindowSize {
    param([string]$Spec = '', [string]$ScriptPath = '', [string]$ColorMode = '256')
    $size = $null
    if ($Spec.Length -gt 0 -and $Spec -ne 'Ask') {
        $size = ConvertTo-WindowSize -Spec $Spec
        if ($null -eq $size -and $Spec.Trim() -match '^(current|keep|max|maximum|fit|full)$') {
            return @{ Ok = $true; Quit = $false; Message = '' }
        }
        if ($null -eq $size) {
            return @{ Ok = $false; Quit = $false; Message = "I do not understand the window size '$Spec'. Use a size such as 120x36, a preset name (Classic, Comfortable, Large, Wide), 'current' or 'max'." }
        }
    }
    else {
        $choice = Show-WindowSizeMenu
        if ($null -eq $choice) { return @{ Ok = $true; Quit = $false; Message = '' } }
        if ($choice -is [string]) { return @{ Ok = $true; Quit = $true; Message = '' } }
        $size = $choice
    }
    if ($null -eq $size) { return @{ Ok = $true; Quit = $false; Message = '' } }
    $applied = Set-TerminalWindowSize -Width $size.Width -Height $size.Height
    if (-not $applied.Exact -and $null -ne $applied.Wanted -and $ScriptPath.Length -gt 0 -and (Test-WindowsTerminal)) {
        if (Confirm-NewWindow -Applied $applied) {
            if (Start-GameInNewWindow -Width $applied.Wanted.Width -Height $applied.Wanted.Height -ScriptPath $ScriptPath -ColorMode $ColorMode) {
                return @{ Ok = $true; Quit = $true; Message = ''; Applied = $applied }
            }
            Write-Host '   Windows Terminal would not open a new window. Carrying on in this one.' -ForegroundColor Yellow
            Start-Sleep -Milliseconds 1500
        }
    }
    try { [Console]::Clear() } catch { }
    return @{ Ok = $true; Quit = $false; Message = ''; Applied = $applied }
}
