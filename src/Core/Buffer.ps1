$script:OTScr = $null
$script:OTRenderSb = New-Object System.Text.StringBuilder 32768
$script:OTCoalesceGap = 5

function Initialize-Screen {
    param([int]$Width = 100, [int]$Height = 30)
    $n = $Width * $Height
    $script:OTScreenWidth = $Width
    $script:OTScreenHeight = $Height
    $script:OTScr = @{
        Width    = $Width
        Height   = $Height
        Count    = $n
        BChar    = New-Object 'System.Char[]' $n
        BFg      = New-Object 'System.Int32[]' $n
        BBg      = New-Object 'System.Int32[]' $n
        FChar    = New-Object 'System.Char[]' $n
        FFg      = New-Object 'System.Int32[]' $n
        FBg      = New-Object 'System.Int32[]' $n
        Valid    = $false
        TplChar  = $null
        TplFgArr = $null
        TplBgArr = $null
        TplFg    = -999
        TplBg    = -999
    }
    Clear-Buffer
}

function Clear-Buffer {
    param([int]$Bg = 0, [int]$Fg = 1)
    $s = $script:OTScr
    $n = $s.Count
    if ($null -eq $s.TplChar -or $s.TplFg -ne $Fg -or $s.TplBg -ne $Bg) {
        $tc = New-Object 'System.Char[]' $n
        $tf = New-Object 'System.Int32[]' $n
        $tb = New-Object 'System.Int32[]' $n
        $sp = [char]32
        for ($i = 0; $i -lt $n; $i++) {
            $tc[$i] = $sp
            $tf[$i] = $Fg
            $tb[$i] = $Bg
        }
        $s.TplChar = $tc
        $s.TplFgArr = $tf
        $s.TplBgArr = $tb
        $s.TplFg = $Fg
        $s.TplBg = $Bg
    }
    [Array]::Copy($s.TplChar, $s.BChar, $n)
    [Array]::Copy($s.TplFgArr, $s.BFg, $n)
    [Array]::Copy($s.TplBgArr, $s.BBg, $n)
}

function Set-BufferCell {
    param([int]$X, [int]$Y, [char]$Char, [int]$Fg = 1, [int]$Bg = 0)
    $s = $script:OTScr
    if ($X -lt 0 -or $Y -lt 0 -or $X -ge $s.Width -or $Y -ge $s.Height) { return }
    $i = $Y * $s.Width + $X
    $s.BChar[$i] = $Char
    $s.BFg[$i] = $Fg
    $s.BBg[$i] = $Bg
}

function Write-BufferText {
    param([int]$X, [int]$Y, [string]$Text, [int]$Fg = 1, [int]$Bg = 0, [switch]$Transparent)
    if ([string]::IsNullOrEmpty($Text)) { return }
    $s = $script:OTScr
    if ($Y -lt 0 -or $Y -ge $s.Height) { return }
    $w = $s.Width
    $bc = $s.BChar; $bf = $s.BFg; $bb = $s.BBg
    $row = $Y * $w
    $len = $Text.Length
    for ($k = 0; $k -lt $len; $k++) {
        $px = $X + $k
        if ($px -lt 0) { continue }
        if ($px -ge $w) { break }
        $ch = $Text[$k]
        if ($Transparent -and $ch -eq [char]32) { continue }
        $i = $row + $px
        $bc[$i] = $ch
        $bf[$i] = $Fg
        $bb[$i] = $Bg
    }
}

function Write-BufferTextCentered {
    param([int]$Y, [string]$Text, [int]$Fg = 1, [int]$Bg = 0, [int]$Left = 0, [int]$Width = -1)
    if ($Width -lt 0) { $Width = $script:OTScr.Width }
    $x = $Left + [math]::Floor(($Width - $Text.Length) / 2)
    Write-BufferText -X $x -Y $Y -Text $Text -Fg $Fg -Bg $Bg
}

function Fill-BufferRect {
    param([int]$X, [int]$Y, [int]$Width, [int]$Height, [char]$Char = ' ', [int]$Fg = 1, [int]$Bg = 0)
    if ($Width -le 0 -or $Height -le 0) { return }
    $rowStr = New-Object System.String -ArgumentList $Char, $Width
    for ($r = 0; $r -lt $Height; $r++) {
        Write-BufferText -X $X -Y ($Y + $r) -Text $rowStr -Fg $Fg -Bg $Bg
    }
}

function Write-BufferArt {
    param([int]$X, [int]$Y, [string[]]$Lines, [int]$Fg = 1, [int]$Bg = 0, [switch]$Transparent)
    if ($null -eq $Lines) { return }
    for ($r = 0; $r -lt $Lines.Count; $r++) {
        Write-BufferText -X $X -Y ($Y + $r) -Text $Lines[$r] -Fg $Fg -Bg $Bg -Transparent:$Transparent
    }
}

function Render-Frame {
    param([switch]$Force)
    $s = $script:OTScr
    $w = $s.Width; $h = $s.Height
    $bc = $s.BChar; $bf = $s.BFg; $bb = $s.BBg
    $fc = $s.FChar; $ff = $s.FFg; $fb = $s.FBg
    $palFg = $script:OTPalFg; $palBg = $script:OTPalBg
    $ox = $script:OTTerm.OffsetX; $oy = $script:OTTerm.OffsetY
    $gap = $script:OTCoalesceGap
    $full = $Force -or (-not $s.Valid)
    $sb = $script:OTRenderSb
    [void]$sb.Clear()
    $curFg = -1; $curBg = -1
    $esc = $script:OTESC
    for ($y = 0; $y -lt $h; $y++) {
        $row = $y * $w
        $x = 0
        while ($x -lt $w) {
            $i = $row + $x
            if (-not $full -and $bc[$i] -eq $fc[$i] -and $bf[$i] -eq $ff[$i] -and $bb[$i] -eq $fb[$i]) {
                $x++
                continue
            }
            $runStart = $x
            $lastDirty = $x
            $probe = $x
            while ($probe -lt $w) {
                $pi = $row + $probe
                $dirty = $full -or ($bc[$pi] -ne $fc[$pi]) -or ($bf[$pi] -ne $ff[$pi]) -or ($bb[$pi] -ne $fb[$pi])
                if ($dirty) { $lastDirty = $probe }
                elseif (($probe - $lastDirty) -ge $gap) { break }
                $probe++
            }
            [void]$sb.Append($esc).Append('[').Append($y + 1 + $oy).Append(';').Append($runStart + 1 + $ox).Append('H')
            for ($k = $runStart; $k -le $lastDirty; $k++) {
                $ki = $row + $k
                $nf = $bf[$ki]; $nb = $bb[$ki]
                if ($nf -ne $curFg) { [void]$sb.Append($palFg[$nf]); $curFg = $nf }
                if ($nb -ne $curBg) { [void]$sb.Append($palBg[$nb]); $curBg = $nb }
                [void]$sb.Append($bc[$ki])
                $fc[$ki] = $bc[$ki]; $ff[$ki] = $nf; $fb[$ki] = $nb
            }
            $x = $lastDirty + 1
        }
    }
    $s.Valid = $true
    $out = $sb.ToString()
    if ($out.Length -gt 0) {
        [Console]::Write($out)
    }
    return $out.Length
}

