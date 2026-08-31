function Get-C {
    param([string]$Name)
    return Get-ColorIndex $Name
}

function Draw-TitleScreen {
    Clear-Buffer
    $sky = Get-C 'Night'
    Fill-BufferRect -X 0 -Y 0 -Width $script:OTScr.Width -Height 14 -Char ([char]32) -Fg 1 -Bg $sky
    Draw-StarField -Top 0 -Height 14 -Seed 11 -Fg (Get-C 'Silver') -Count 70 -Bg $sky
    $oregon = Get-Art 'TitleOregon'
    $trail = Get-Art 'TitleTrail'
    $ox = [math]::Floor(($script:OTScr.Width - (Get-ArtWidth -Lines $oregon)) / 2)
    $tx = [math]::Floor(($script:OTScr.Width - (Get-ArtWidth -Lines $trail)) / 2)
    Write-BufferArt -X $ox -Y 2 -Lines $oregon -Fg (Get-C 'Gold') -Bg $sky
    Write-BufferArt -X $tx -Y 8 -Lines $trail -Fg (Get-C 'Amber') -Bg $sky
    Write-BufferArt -X 0 -Y 14 -Lines (Get-Art 'Mountains') -Fg (Get-C 'Mountain') -Transparent
    Draw-Ground -Y 24 -Fg (Get-C 'DarkGreen')
    Write-BufferArt -X 10 -Y 20 -Lines (Get-Art 'OxTeam') -Fg (Get-C 'Ox') -Transparent
    Write-BufferArt -X 34 -Y 18 -Lines (Get-Art 'Wagon') -Fg (Get-C 'Canvas') -Transparent
    Write-BufferTextCentered -Y 26 -Text '1985 MECC EDITION' -Fg (Get-C 'DarkGrey')
    Write-BufferTextCentered -Y 28 -Text 'Press SPACE BAR to begin your journey' -Fg (Get-C 'White')
}

function Draw-Tombstone {
    param([string]$Name, [string]$Cause = '', [string]$DateText = '', [int]$Top = 5, [int]$Fg = -1)
    if ($Fg -lt 0) { $Fg = Get-C 'Silver' }
    $lines = Get-Art 'Tombstone'
    $left = [math]::Floor(($script:OTScr.Width - (Get-ArtWidth -Lines $lines)) / 2)
    Write-BufferArt -X $left -Y $Top -Lines $lines -Fg $Fg
    $inLeft = $left + 5
    $inWidth = 25
    $grey = Get-C 'DarkGrey'
    Write-BufferTextCentered -Y ($Top + 3) -Text 'HERE LIES' -Fg $grey -Left $inLeft -Width $inWidth
    Write-BufferTextCentered -Y ($Top + 5) -Text $Name.ToUpper() -Fg (Get-C 'White') -Left $inLeft -Width $inWidth
    if ($Cause.Length -gt 0) {
        Write-BufferTextCentered -Y ($Top + 7) -Text 'DIED OF' -Fg $grey -Left $inLeft -Width $inWidth
        Write-BufferTextCentered -Y ($Top + 8) -Text $Cause.ToUpper() -Fg $grey -Left $inLeft -Width $inWidth
    }
    if ($DateText.Length -gt 0) {
        Write-BufferTextCentered -Y ($Top + 10) -Text $DateText.ToUpper() -Fg $grey -Left $inLeft -Width $inWidth
    }
}

function Get-HealthLabel {
    param([int]$Health)
    if ($Health -lt 35) { return 'Good' }
    if ($Health -lt 70) { return 'Fair' }
    if ($Health -lt 105) { return 'Poor' }
    return 'Very Poor'
}

function Get-HealthColor {
    param([int]$Health)
    if ($Health -lt 35) { return (Get-C 'Green') }
    if ($Health -lt 70) { return (Get-C 'Yellow') }
    if ($Health -lt 105) { return (Get-C 'Orange') }
    return (Get-C 'Red')
}

function Get-TrailDateString {
    param($State)
    return $State.Date.ToString('MMMM d, yyyy')
}

function Draw-StatusBar {
    param($State, [int]$Top = 0)
    $w = $script:OTScr.Width
    $bg = Get-C 'DarkBlue'
    Fill-BufferRect -X 0 -Y $Top -Width $w -Height 3 -Char ([char]32) -Fg 1 -Bg $bg
    $date = Get-TrailDateString -State $State
    Write-BufferText -X 2 -Y ($Top + 1) -Text $date -Fg (Get-C 'White') -Bg $bg
    $wLabel = $State.Weather
    if (Get-Command Get-WeatherLabel -ErrorAction SilentlyContinue) { $wLabel = Get-WeatherLabel -State $State }
    $wLabel = $wLabel.Substring(0, 1).ToUpper() + $wLabel.Substring(1)
    $weather = 'Weather: ' + $wLabel
    Write-BufferText -X 26 -Y ($Top + 1) -Text $weather -Fg (Get-C 'SkyBlue') -Bg $bg
    Write-BufferText -X 50 -Y ($Top + 1) -Text 'Health: ' -Fg (Get-C 'Grey') -Bg $bg
    Write-BufferText -X 58 -Y ($Top + 1) -Text (Get-HealthLabel $State.Health) -Fg (Get-HealthColor $State.Health) -Bg $bg
    $food = 'Food: ' + (Format-Number $State.Food) + ' lbs'
    Write-BufferText -X 72 -Y ($Top + 1) -Text $food -Fg (Get-C 'Tan') -Bg $bg
}

function Draw-TrailScene {
    param($State, [int]$Top = 4, [int]$Offset = 0)
    Fill-BufferRect -X 0 -Y $Top -Width $script:OTScr.Width -Height 10 -Char ([char]32) -Fg 1 -Bg 0
    $groundY = $Top + 9
    Write-BufferArt -X 0 -Y $Top -Lines (Get-Art 'Mountains') -Fg (Get-C 'Mountain') -Transparent
    Draw-Ground -Y $groundY -Fg (Get-C 'DarkGreen')
    $wagon = Get-Art 'WagonSmall'
    $oxen = Get-Art 'OxTeam'
    $wx = 20 + (($Offset % 12) - 6)
    Write-BufferArt -X $wx -Y ($groundY - $oxen.Count) -Lines $oxen -Fg (Get-C 'Ox') -Transparent
    Write-BufferArt -X ($wx + 20) -Y ($groundY - $wagon.Count) -Lines $wagon -Fg (Get-C 'Canvas') -Transparent
}

