$script:OTBox = @{
    H   = [char]0x2500
    V   = [char]0x2502
    TL  = [char]0x250C
    TR  = [char]0x2510
    BL  = [char]0x2514
    BR  = [char]0x2518
    DH  = [char]0x2550
    DV  = [char]0x2551
    DTL = [char]0x2554
    DTR = [char]0x2557
    DBL = [char]0x255A
    DBR = [char]0x255D
    DLT = [char]0x2560
    DRT = [char]0x2563
    DLTee = [char]0x255F
    DRTee = [char]0x2562
}

$script:OTBlocks = @{
    Full  = [char]0x2588
    Dark  = [char]0x2593
    Med   = [char]0x2592
    Light = [char]0x2591
    Up    = [char]0x2580
    Down  = [char]0x2584
}

$script:OTGlyph = @{
    Tri      = [char]0x25B2
    TriDown  = [char]0x25BC
    Dot      = [char]0x2022
    Wave     = [char]0x2248
    Heart    = [char]0x2665
    Diamond  = [char]0x25C6
    Arrow    = [char]0x2192
    Star     = [char]0x2605
}

function Get-WrappedLines {
    param([string]$Text, [int]$Width)
    $out = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrEmpty($Text)) { return ,@('') }
    foreach ($para in ($Text -split "`n")) {
        if ($para.Trim().Length -eq 0) { [void]$out.Add(''); continue }
        $line = ''
        foreach ($word in ($para -split '\s+' | Where-Object { $_.Length -gt 0 })) {
            if ($line.Length -eq 0) { $line = $word }
            elseif (($line.Length + 1 + $word.Length) -le $Width) { $line = $line + ' ' + $word }
            else { [void]$out.Add($line); $line = $word }
        }
        if ($line.Length -gt 0) { [void]$out.Add($line) }
    }
    return ,$out.ToArray()
}

function Draw-Box {
    param(
        [int]$Left, [int]$Top, [int]$Width, [int]$Height,
        [string]$Title = '',
        [int]$Fg = 2, [int]$Bg = 0,
        [int]$TitleFg = -1,
        [ValidateSet('Single', 'Double')][string]$Style = 'Single',
        [switch]$Fill
    )
    if ($Width -lt 2 -or $Height -lt 2) { return }
    if ($TitleFg -lt 0) { $TitleFg = $Fg }
    $b = $script:OTBox
    if ($Style -eq 'Double') {
        $h = $b.DH; $v = $b.DV; $tl = $b.DTL; $tr = $b.DTR; $bl = $b.DBL; $br = $b.DBR
    }
    else {
        $h = $b.H; $v = $b.V; $tl = $b.TL; $tr = $b.TR; $bl = $b.BL; $br = $b.BR
    }
    $inner = $Width - 2
    $hbar = New-Object System.String -ArgumentList $h, $inner
    Write-BufferText -X $Left -Y $Top -Text ([string]$tl + $hbar + $tr) -Fg $Fg -Bg $Bg
    $blank = New-Object System.String -ArgumentList ([char]32), $inner
    $midRow = [string]$v + $blank + [string]$v
    for ($r = 1; $r -lt ($Height - 1); $r++) {
        if ($Fill) {
            Write-BufferText -X $Left -Y ($Top + $r) -Text $midRow -Fg $Fg -Bg $Bg
        }
        else {
            Write-BufferText -X $Left -Y ($Top + $r) -Text ([string]$v) -Fg $Fg -Bg $Bg
            Write-BufferText -X ($Left + $Width - 1) -Y ($Top + $r) -Text ([string]$v) -Fg $Fg -Bg $Bg
        }
    }
    Write-BufferText -X $Left -Y ($Top + $Height - 1) -Text ([string]$bl + $hbar + $br) -Fg $Fg -Bg $Bg
    if ($Title.Length -gt 0) {
        $t = ' ' + $Title + ' '
        if ($t.Length -gt $inner) { $t = $t.Substring(0, $inner) }
        $tx = $Left + [math]::Floor(($Width - $t.Length) / 2)
        Write-BufferText -X $tx -Y $Top -Text $t -Fg $TitleFg -Bg $Bg
    }
}

function Draw-Panel {
    param([int]$Left, [int]$Top, [int]$Width, [int]$Height, [string]$Title = '', [int]$Fg = 2, [int]$Bg = 0, [string]$Style = 'Single')
    Fill-BufferRect -X $Left -Y $Top -Width $Width -Height $Height -Char ([char]32) -Fg 1 -Bg $Bg
    Draw-Box -Left $Left -Top $Top -Width $Width -Height $Height -Title $Title -Fg $Fg -Bg $Bg -Style $Style
}

function Draw-Rule {
    param([int]$Y, [int]$Left, [int]$Width, [string]$Rule = '', [int]$Fg = 3, [switch]$Plain)
    if ($Plain) {
        $bar = New-Object System.String -ArgumentList $script:OTBox.H, $Width
        Write-BufferText -X $Left -Y $Y -Text $bar -Fg $Fg
        return
    }
    if ($Rule.Length -eq 0) {
        $Rule = New-Object System.String -ArgumentList $script:OTBox.H, ($Width - 2)
    }
    Write-BufferText -X ($Left + 1) -Y $Y -Text $Rule -Fg $Fg
    Write-BufferText -X $Left -Y $Y -Text ([string]$script:OTBox.DLTee) -Fg $Fg
    Write-BufferText -X ($Left + $Width - 1) -Y $Y -Text ([string]$script:OTBox.DRTee) -Fg $Fg
}

function Draw-Gauge {
    param(
        [int]$Left, [int]$Top, [int]$Width,
        [double]$Value, [double]$Max = 100,
        [int]$Fg = 8, [int]$Bg = 0, [int]$EmptyFg = 3,
        [string]$Label = ''
    )
    if ($Max -le 0) { $Max = 1 }
    $ratio = $Value / $Max
    if ($ratio -lt 0) { $ratio = 0 }
    if ($ratio -gt 1) { $ratio = 1 }
    $filled = [int][math]::Round($Width * $ratio)
    if ($filled -gt $Width) { $filled = $Width }
    $lx = $Left
    if ($Label.Length -gt 0) {
        Write-BufferText -X $lx -Y $Top -Text $Label -Fg 2 -Bg $Bg
        $lx += $Label.Length + 1
    }
    if ($filled -gt 0) {
        $bar = New-Object System.String -ArgumentList $script:OTBlocks.Full, $filled
        Write-BufferText -X $lx -Y $Top -Text $bar -Fg $Fg -Bg $Bg
    }
    $rest = $Width - $filled
    if ($rest -gt 0) {
        $empty = New-Object System.String -ArgumentList $script:OTBlocks.Light, $rest
        Write-BufferText -X ($lx + $filled) -Y $Top -Text $empty -Fg $EmptyFg -Bg $Bg
    }
}

function Show-Message {
    param(
        [string]$Text,
        [string]$Title = '',
        [int]$Left = 20, [int]$Top = 9, [int]$Width = 60,
        [int]$Fg = 1, [int]$BorderFg = 2, [int]$Bg = 0,
        [string]$Footer = 'Press SPACE BAR to continue',
        [switch]$NoWait
    )
    $inner = $Width - 4
    $lines = Get-WrappedLines -Text $Text -Width $inner
    $height = $lines.Count + 4
    if ($Footer.Length -gt 0) { $height += 2 }
    if (($Top + $height) -gt $script:OTScr.Height) { $Top = [math]::Max(0, $script:OTScr.Height - $height) }
    Draw-Panel -Left $Left -Top $Top -Width $Width -Height $height -Title $Title -Fg $BorderFg -Style 'Double'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        Write-BufferText -X ($Left + 2) -Y ($Top + 2 + $i) -Text $lines[$i] -Fg $Fg -Bg $Bg
    }
    if ($Footer.Length -gt 0) {
        Write-BufferTextCentered -Y ($Top + $height - 2) -Text $Footer -Fg 3 -Bg $Bg -Left $Left -Width $Width
    }
    [void](Render-Frame)
    if ($NoWait) { return }
    Wait-ForContinue
}

function Wait-ForContinue {
    while ($true) {
        $k = Read-GameKey
        if ($k.Key -eq 'CtrlC') { return }
        if ($k.Key -eq 'Space' -or $k.Key -eq 'Enter' -or $k.Key -eq 'Escape') { return }
    }
}

function Show-Menu {
    param(
        [string]$Title,
        [string[]]$Options,
        [string]$Header = '',
        [int]$Left = 18, [int]$Top = 6, [int]$Width = 64,
        [int]$BorderFg = 2, [int]$Bg = 0,
        [int]$HighlightFg = 8,
        [switch]$AllowEscape,
        [string]$Footer = ''
    )
    $sel = 0
    $inner = $Width - 4
    $headerLines = @()
    if ($Header.Length -gt 0) { $headerLines = Get-WrappedLines -Text $Header -Width $inner }
    $height = $Options.Count + $headerLines.Count + 5
    if ($Footer.Length -gt 0) { $height += 1 }
    while ($true) {
        Draw-Panel -Left $Left -Top $Top -Width $Width -Height $height -Title $Title -Fg $BorderFg -Style 'Double'
        $y = $Top + 2
        for ($i = 0; $i -lt $headerLines.Count; $i++) {
            Write-BufferText -X ($Left + 2) -Y $y -Text $headerLines[$i] -Fg 1 -Bg $Bg
            $y++
        }
        if ($headerLines.Count -gt 0) { $y++ }
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $marker = '  '
            $fg = 1
            if ($i -eq $sel) { $marker = [string]$script:OTGlyph.Arrow + ' '; $fg = $HighlightFg }
            $line = $marker + ($i + 1).ToString() + '. ' + $Options[$i]
            $pad = $inner - $line.Length
            if ($pad -gt 0) { $line = $line + (New-Object System.String -ArgumentList ([char]32), $pad) }
            Write-BufferText -X ($Left + 2) -Y $y -Text $line -Fg $fg -Bg $Bg
            $y++
        }
        if ($Footer.Length -gt 0) {
            Write-BufferTextCentered -Y ($Top + $height - 2) -Text $Footer -Fg 3 -Bg $Bg -Left $Left -Width $Width
        }
        [void](Render-Frame)
        $k = Read-GameKey
        if ($k.Key -eq 'CtrlC') { return -2 }
        if ($k.Key -eq 'Escape' -and $AllowEscape) { return -1 }
        $dir = Get-NormalizedDirection $k
        if ($dir -eq 'Up') {
            $sel--
            if ($sel -lt 0) { $sel = $Options.Count - 1 }
            continue
        }
        if ($dir -eq 'Down') {
            $sel++
            if ($sel -ge $Options.Count) { $sel = 0 }
            continue
        }
        if ($k.Key -eq 'Enter' -or $k.Key -eq 'Space') { return $sel }
        if ($k.Key -match '^[1-9]$') {
            $n = [int]$k.Key - 1
            if ($n -lt $Options.Count) { return $n }
        }
    }
}

function Read-BufferedLine {
    param(
        [string]$Prompt,
        [int]$Left = 20, [int]$Top = 12, [int]$Width = 60,
        [int]$MaxLength = 20,
        [string]$Initial = '',
        [string]$Title = '',
        [switch]$AllowEmpty
    )
    $text = $Initial
    $height = 7
    while ($true) {
        Draw-Panel -Left $Left -Top $Top -Width $Width -Height $height -Title $Title -Fg 2 -Style 'Double'
        Write-BufferText -X ($Left + 2) -Y ($Top + 2) -Text $Prompt -Fg 1
        $field = $text + [string]$script:OTBlocks.Full
        $pad = ($Width - 6) - $field.Length
        if ($pad -lt 0) { $pad = 0 }
        $field = $field + (New-Object System.String -ArgumentList ([char]32), $pad)
        Write-BufferText -X ($Left + 3) -Y ($Top + 4) -Text $field -Fg 8
        [void](Render-Frame)
        $k = Read-GameKey
        if ($k.Key -eq 'CtrlC') { return $null }
        if ($k.Key -eq 'Enter') {
            if ($text.Trim().Length -gt 0 -or $AllowEmpty) { return $text.Trim() }
            continue
        }
        if ($k.Key -eq 'Backspace') {
            if ($text.Length -gt 0) { $text = $text.Substring(0, $text.Length - 1) }
            continue
        }
        $ch = $k.Char
        if ([int]$ch -ge 32 -and [int]$ch -lt 127 -and $text.Length -lt $MaxLength) {
            $text = $text + $ch
        }
    }
}

function Show-Confirm {
    param([string]$Text, [string]$Title = '', [int]$Left = 24, [int]$Top = 10, [int]$Width = 52)
    $r = Show-Menu -Title $Title -Header $Text -Options @('Yes', 'No') -Left $Left -Top $Top -Width $Width -AllowEscape
    return ($r -eq 0)
}

function Format-Money {
    param([double]$Amount)
    return '$' + $Amount.ToString('N2')
}

function Format-Number {
    param([double]$Value)
    return $Value.ToString('N0')
}
