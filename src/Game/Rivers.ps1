function Get-RiverConditions {
    param($State, $Landmark)
    $baseDepth = 3.0
    if ($null -ne $Landmark.RiverDepth) { $baseDepth = [double]$Landmark.RiverDepth }
    $variance = ($State.Rng.NextDouble() * 2.0) - 0.8
    $depth = [math]::Round([math]::Max(0.5, $baseDepth + $variance), 1)
    $w = Get-WeatherOption -Key $State.Weather
    if ($null -ne $w -and $State.Weather -eq 'Rainy') { $depth = [math]::Round($depth + 1.0, 1) }
    $current = 'slow'
    $croll = $State.Rng.Next(0, 100)
    if ($croll -lt 30) { $current = 'swift' }
    elseif ($croll -lt 65) { $current = 'moderate' }
    return @{
        Depth   = $depth
        Width   = $Landmark.RiverWidth
        Current = $current
    }
}

function Get-FordRisk {
    param($Conditions)
    $risk = 0
    if ($Conditions.Depth -le 2.5) { $risk = 5 }
    elseif ($Conditions.Depth -le 3.5) { $risk = 25 }
    elseif ($Conditions.Depth -le 5.0) { $risk = 55 }
    else { $risk = 85 }
    if ($Conditions.Current -eq 'swift') { $risk += 20 }
    elseif ($Conditions.Current -eq 'moderate') { $risk += 8 }
    if ($risk -gt 95) { $risk = 95 }
    return $risk
}

function Get-FloatRisk {
    param($Conditions)
    $risk = 20
    if ($Conditions.Depth -gt 6) { $risk = 30 }
    if ($Conditions.Current -eq 'swift') { $risk += 25 }
    elseif ($Conditions.Current -eq 'moderate') { $risk += 10 }
    if ($risk -gt 90) { $risk = 90 }
    return $risk
}

function Show-RiverAnimation {
    param($State, $Landmark, [string]$Method, [bool]$Success)
    $clock = New-FrameClock -Fps 12
    $wagonArt = Get-Art 'WagonSmall'
    $wagonW = Get-ArtWidth -Lines $wagonArt
    $startX = 4
    $endX = 92
    $steps = 26
    for ($i = 0; $i -le $steps; $i++) {
        Clear-Buffer
        Write-BufferTextCentered -Y 1 -Text $Landmark.Name.ToUpper() -Fg (Get-C 'Gold')
        Write-BufferText -X 0 -Y 8 -Text (New-Object System.String -ArgumentList ([char]0x2591), 100) -Fg (Get-C 'DarkGreen')
        for ($r = 9; $r -le 18; $r++) {
            $row = New-Object System.String -ArgumentList ([char]0x2248), 100
            $fg = Get-C 'River'
            if ($r % 2 -eq 0) { $fg = Get-C 'DeepRiver' }
            Write-BufferText -X 0 -Y $r -Text $row -Fg $fg
        }
        Write-BufferText -X 0 -Y 19 -Text (New-Object System.String -ArgumentList ([char]0x2591), 100) -Fg (Get-C 'DarkGreen')
        $x = $startX + [int](($endX - $startX) * ($i / [double]$steps))
        $y = 12
        if (-not $Success -and $i -gt ($steps / 2)) {
            $y = 12 + [math]::Min(4, $i - [int]($steps / 2))
        }
        Write-BufferArt -X $x -Y $y -Lines $wagonArt -Fg (Get-C 'Canvas') -Transparent
        Write-BufferTextCentered -Y 22 -Text $Method -Fg (Get-C 'White')
        [void](Render-Frame)
        [void](Step-FrameClock -Clock $clock)
    }
}

function Invoke-RiverLoss {
    param($State, [int]$SeverityPercent)
    $lost = New-Object System.Collections.ArrayList
    $foodLost = [int][math]::Floor($State.Food * ($SeverityPercent / 100.0))
    if ($foodLost -gt 0) {
        $State.Food -= $foodLost
        [void]$lost.Add("$foodLost pounds of food")
    }
    $bulletsLost = [int][math]::Floor($State.Bullets * ($SeverityPercent / 100.0))
    if ($bulletsLost -gt 0) {
        $State.Bullets -= $bulletsLost
        [void]$lost.Add("$bulletsLost bullets")
    }
    if ($State.Rng.Next(0, 100) -lt $SeverityPercent) {
        $clothLost = [math]::Min($State.Clothing, $State.Rng.Next(1, 4))
        if ($clothLost -gt 0) {
            $State.Clothing -= $clothLost
            [void]$lost.Add("$clothLost sets of clothing")
        }
    }
    if ($State.Oxen -gt 1 -and $State.Rng.Next(0, 100) -lt ($SeverityPercent / 2)) {
        $State.Oxen--
        [void]$lost.Add('an ox')
    }
    if ($lost.Count -eq 0) { return 'You lost nothing of value.' }
    return ('You lost ' + ($lost -join ', ') + '.')
}

function Invoke-RiverCrossing {
    param($State, $Landmark)
    $conditions = Get-RiverConditions -State $State -Landmark $Landmark
    while ($true) {
        Clear-Buffer
        Write-BufferTextCentered -Y 1 -Text $Landmark.Name.ToUpper() -Fg (Get-C 'Gold')
        for ($r = 4; $r -le 9; $r++) {
            $row = New-Object System.String -ArgumentList ([char]0x2248), 100
            $fg = Get-C 'River'
            if ($r % 2 -eq 0) { $fg = Get-C 'DeepRiver' }
            Write-BufferText -X 0 -Y $r -Text $row -Fg $fg
        }
        Write-BufferTextCentered -Y 11 -Text ('The river here is ' + (Format-Number $conditions.Width) + ' feet across.') -Fg (Get-C 'White')
        Write-BufferTextCentered -Y 12 -Text ('The water is ' + $conditions.Depth + ' feet deep and the current is ' + $conditions.Current + '.') -Fg (Get-C 'White')
        $opts = New-Object System.Collections.ArrayList
        [void]$opts.Add('Attempt to ford the river')
        [void]$opts.Add('Caulk the wagon and float it across')
        $hasFerry = ($null -ne $Landmark.FerryCost -and $Landmark.FerryCost -gt 0)
        if ($hasFerry) { [void]$opts.Add('Take a ferry across ($' + $Landmark.FerryCost + ', ' + $Landmark.FerryDays + ' day wait)') }
        [void]$opts.Add('Wait a day to see if conditions improve')
        $r = Show-Menu -Title 'YOU MAY' -Options $opts.ToArray() -Left 26 -Top 14 -Width 52 -BorderFg (Get-C 'Gold')
        if ($r -lt 0) { $r = 0 }
        $ferryIndex = -1
        $waitIndex = 2
        if ($hasFerry) {
            $ferryIndex = 2
            $waitIndex = 3
        }
        if ($r -eq $waitIndex) {
            $State.Date = $State.Date.AddDays(1)
            $State.DaysOnTrail++
            Update-Weather -State $State
            [void](Update-DailyFood -State $State)
            Update-DailyHealth -State $State -Resting
            $conditions = Get-RiverConditions -State $State -Landmark $Landmark
            Show-Message -Text 'You waited a day. Conditions have changed.' -Title 'WAITING' -Left 24 -Top 12 -Width 52 -BorderFg (Get-C 'SkyBlue')
            continue
        }
        if ($r -eq $ferryIndex) {
            if ($State.Money -lt $Landmark.FerryCost) {
                Show-Message -Text ("The ferry costs " + (Format-Money $Landmark.FerryCost) + " and you cannot afford it.") -Title 'FERRY' -Left 24 -Top 12 -Width 52 -BorderFg (Get-C 'Red')
                continue
            }
            $State.Money -= $Landmark.FerryCost
            $days = $Landmark.FerryDays
            for ($d = 0; $d -lt $days; $d++) {
                $State.Date = $State.Date.AddDays(1)
                $State.DaysOnTrail++
                [void](Update-DailyFood -State $State)
                Update-DailyHealth -State $State -Resting
            }
            Show-RiverAnimation -State $State -Landmark $Landmark -Method 'Crossing by ferry' -Success $true
            Show-Message -Text "You waited $days days for the ferry, then crossed the river safely." -Title 'SAFE CROSSING' -Left 22 -Top 12 -Width 56 -BorderFg (Get-C 'Green')
            Add-Journal -State $State -Text "Crossed the $($Landmark.Short) by ferry."
            return
        }
        $method = 'Fording the river'
        $risk = Get-FordRisk -Conditions $conditions
        if ($r -eq 1) {
            $method = 'Floating the wagon across'
            $risk = Get-FloatRisk -Conditions $conditions
        }
        $roll = $State.Rng.Next(0, 100)
        $success = ($roll -ge $risk)
        Show-RiverAnimation -State $State -Landmark $Landmark -Method $method -Success $success
        if ($success) {
            Show-Message -Text 'You crossed the river with no trouble.' -Title 'SAFE CROSSING' -Left 24 -Top 12 -Width 52 -BorderFg (Get-C 'Green')
            Add-Journal -State $State -Text "Crossed the $($Landmark.Short) safely."
            return
        }
        $severity = $State.Rng.Next(15, 45)
        $lossText = Invoke-RiverLoss -State $State -SeverityPercent $severity
        Add-Health -State $State -Delta 5
        $drowned = $false
        if ($State.Rng.Next(0, 100) -lt 18) {
            $victim = Get-RandomLivingMember -State $State
            if ($null -ne $victim) {
                Set-MemberDead -State $State -Member $victim -Cause 'drowning'
                $drowned = $true
            }
        }
        $text = 'Your wagon tipped over while crossing. ' + $lossText
        Show-Message -Text $text -Title 'DISASTER' -Left 20 -Top 12 -Width 60 -BorderFg (Get-C 'Blood')
        if ($drowned) {
            $dead = @($State.Party | Where-Object { -not $_.Alive -and $_.DeathCause -eq 'drowning' })
            if ($dead.Count -gt 0) { Show-DeathScreen -State $State -Member $dead[$dead.Count - 1] }
        }
        Add-Journal -State $State -Text "Wagon tipped crossing the $($Landmark.Short)."
        return
    }
}
