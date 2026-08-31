$script:OTRaftTop = 4
$script:OTRaftBottom = 25
$script:OTRaftLeft = 24
$script:OTRaftRight = 74
$script:OTRaftFps = 15
$script:OTBarlowToll = 25.0

function Show-DallesChoice {
    param($State)
    while ($true) {
        Clear-Buffer
        Write-BufferTextCentered -Y 2 -Text 'THE DALLES' -Fg (Get-C 'Gold')
        for ($r = 5; $r -le 9; $r++) {
            $row = New-Object System.String -ArgumentList ([char]0x2248), 100
            $fg = Get-C 'River'
            if ($r % 2 -eq 0) { $fg = Get-C 'DeepRiver' }
            Write-BufferText -X 0 -Y $r -Text $row -Fg $fg
        }
        $header = "You must decide how to travel the last 100 miles to the Willamette Valley. The Columbia River is fast and full of rocks. The Barlow Toll Road goes around Mount Hood, but it is not free."
        $opts = @(
            'Float your wagon down the Columbia River'
            'Take the Barlow Toll Road ($' + $script:OTBarlowToll + ')'
            'Wait a day and think about it'
        )
        $r = Show-Menu -Title 'YOU MAY' -Options $opts -Header $header -Left 18 -Top 11 -Width 64 -BorderFg (Get-C 'Gold')
        if ($r -lt 0) { $r = 0 }
        if ($r -eq 2) {
            $State.Date = $State.Date.AddDays(1)
            $State.DaysOnTrail++
            [void](Update-DailyFood -State $State)
            Update-DailyHealth -State $State -Resting
            continue
        }
        if ($r -eq 1) {
            if ($State.Money -lt $script:OTBarlowToll) {
                Show-Message -Text ("The toll is " + (Format-Money $script:OTBarlowToll) + " and you cannot afford it. You will have to risk the river.") -Title 'BARLOW ROAD' -Left 20 -Top 12 -Width 60 -BorderFg (Get-C 'Red')
                continue
            }
            $State.Money -= $script:OTBarlowToll
            $days = 6
            for ($d = 0; $d -lt $days; $d++) {
                $State.Date = $State.Date.AddDays(1)
                $State.DaysOnTrail++
                Update-Weather -State $State
                [void](Update-DailyFood -State $State)
                Update-DailyHealth -State $State
                Update-Illness -State $State
                if ((Get-LivingCount -State $State) -eq 0) { break }
            }
            $State.Miles = $script:OTTrailLength
            Add-Journal -State $State -Text 'Took the Barlow Toll Road around Mount Hood.'
            Show-Message -Text "You paid the toll and took the Barlow Road around Mount Hood. It took $days hard days, but you arrived with your wagon intact." -Title 'BARLOW ROAD' -Left 20 -Top 12 -Width 60 -BorderFg (Get-C 'Green')
            return
        }
        Invoke-RaftingRun -State $State
        return
    }
}

function New-RaftHazard {
    param($Rng)
    $w = $Rng.Next(2, 6)
    $x = $Rng.Next($script:OTRaftLeft, $script:OTRaftRight - $w)
    return @{ X = $x; Y = [double]$script:OTRaftTop; W = $w; Hit = $false }
}

function Draw-RaftScene {
    param($Raft, $Hazards, [int]$Distance, [int]$Damage, [string]$Flash)
    Clear-Buffer
    Write-BufferTextCentered -Y 1 -Text 'THE COLUMBIA RIVER' -Fg (Get-C 'Gold')
    Draw-Rule -Y 2 -Left 0 -Width 100 -Plain
    for ($r = $script:OTRaftTop; $r -le $script:OTRaftBottom; $r++) {
        $bank = New-Object System.String -ArgumentList ([char]0x2593), ($script:OTRaftLeft)
        Write-BufferText -X 0 -Y $r -Text $bank -Fg (Get-C 'DarkGreen')
        $bank2 = New-Object System.String -ArgumentList ([char]0x2593), (100 - $script:OTRaftRight)
        Write-BufferText -X $script:OTRaftRight -Y $r -Text $bank2 -Fg (Get-C 'DarkGreen')
        $water = New-Object System.String -ArgumentList ([char]0x2248), ($script:OTRaftRight - $script:OTRaftLeft)
        $fg = Get-C 'River'
        if ($r % 2 -eq 0) { $fg = Get-C 'DeepRiver' }
        Write-BufferText -X $script:OTRaftLeft -Y $r -Text $water -Fg $fg
    }
    foreach ($h in $Hazards) {
        $rock = New-Object System.String -ArgumentList ([char]0x2588), $h.W
        Write-BufferText -X $h.X -Y ([int][math]::Round($h.Y)) -Text $rock -Fg (Get-C 'Rock')
    }
    Write-BufferArt -X $Raft.X -Y $Raft.Y -Lines (Get-Art 'Raft') -Fg (Get-C 'Wood') -Transparent
    Draw-Rule -Y 26 -Left 0 -Width 100 -Plain
    Write-BufferText -X 4 -Y 27 -Text ('MILES TO GO: ' + $Distance) -Fg (Get-C 'White')
    Write-BufferText -X 28 -Y 27 -Text ('DAMAGE: ' + $Damage + '%') -Fg (Get-C 'Red')
    Write-BufferText -X 48 -Y 27 -Text 'A/D or ARROWS to steer' -Fg (Get-C 'DarkGrey')
    if ($Flash.Length -gt 0) {
        Write-BufferTextCentered -Y 1 -Text $Flash -Fg (Get-C 'Red')
    }
}

function Invoke-RaftingRun {
    param($State)
    $rng = $State.Rng
    $raft = @{ X = 46; Y = 22 }
    $hazards = New-Object System.Collections.ArrayList
    $distance = 100
    $damage = 0
    $flash = ''
    $flashTimer = 0
    $spawnTimer = 0
    $clock = New-FrameClock -Fps $script:OTRaftFps
    $frames = 0
    $maxFrames = 400

    while ($distance -gt 0 -and $frames -lt $maxFrames) {
        $frames++
        while ($true) {
            $k = Read-GameKeyIfAvailable
            if ($null -eq $k) { break }
            $dir = Get-NormalizedDirection $k
            if ($dir -eq 'Left') { $raft.X -= 2 }
            elseif ($dir -eq 'Right') { $raft.X += 2 }
        }
        if ($raft.X -lt $script:OTRaftLeft) { $raft.X = $script:OTRaftLeft }
        if ($raft.X -gt ($script:OTRaftRight - 19)) { $raft.X = $script:OTRaftRight - 19 }

        $spawnTimer--
        if ($spawnTimer -le 0) {
            [void]$hazards.Add((New-RaftHazard -Rng $rng))
            $spawnTimer = $rng.Next(4, 10)
        }
        $gone = New-Object System.Collections.ArrayList
        foreach ($h in $hazards) {
            $h.Y += 1
            $hy = [int][math]::Round($h.Y)
            if (-not $h.Hit -and $hy -ge $raft.Y -and $hy -le ($raft.Y + 1)) {
                $raftLeft = $raft.X
                $raftRight = $raft.X + 18
                if (($h.X + $h.W) -gt $raftLeft -and $h.X -lt $raftRight) {
                    $h.Hit = $true
                    $damage += $rng.Next(8, 20)
                    $flash = 'You hit a rock!'
                    $flashTimer = 12
                }
            }
            if ($hy -gt $script:OTRaftBottom) { [void]$gone.Add($h) }
        }
        foreach ($h in $gone) { [void]$hazards.Remove($h) }

        $distance -= 1
        if ($flashTimer -gt 0) { $flashTimer-- } else { $flash = '' }
        if ($damage -ge 100) { break }

        Draw-RaftScene -Raft $raft -Hazards $hazards -Distance $distance -Damage $damage -Flash $flash
        [void](Render-Frame)
        [void](Step-FrameClock -Clock $clock)
    }

    $days = 3
    for ($d = 0; $d -lt $days; $d++) {
        $State.Date = $State.Date.AddDays(1)
        $State.DaysOnTrail++
        [void](Update-DailyFood -State $State)
    }
    $State.Miles = $script:OTTrailLength

    if ($damage -ge 100) {
        $lossText = Invoke-RiverLoss -State $State -SeverityPercent 60
        Add-Health -State $State -Delta 10
        if ($State.Rng.Next(0, 100) -lt 40) {
            $victim = Get-RandomLivingMember -State $State
            if ($null -ne $victim) {
                Set-MemberDead -State $State -Member $victim -Cause 'drowning'
                Show-Message -Text ('Your raft broke apart in the rapids. ' + $lossText) -Title 'DISASTER' -Left 20 -Top 12 -Width 60 -BorderFg (Get-C 'Blood')
                Show-DeathScreen -State $State -Member $victim
                Add-Journal -State $State -Text 'The raft broke apart in the Columbia rapids.'
                return
            }
        }
        Show-Message -Text ('Your raft broke apart in the rapids. ' + $lossText) -Title 'DISASTER' -Left 20 -Top 12 -Width 60 -BorderFg (Get-C 'Blood')
        Add-Journal -State $State -Text 'The raft broke apart in the Columbia rapids.'
        return
    }
    if ($damage -gt 0) {
        $lossText = Invoke-RiverLoss -State $State -SeverityPercent ([int][math]::Floor($damage / 3))
        Show-Message -Text ("You made it down the Columbia, but the rocks took their toll. " + $lossText) -Title 'THE COLUMBIA' -Left 20 -Top 12 -Width 60 -BorderFg (Get-C 'Amber')
        Add-Journal -State $State -Text 'Rafted the Columbia River with some losses.'
        return
    }
    Show-Message -Text 'You floated the Columbia River without striking a single rock. A remarkable piece of steering.' -Title 'THE COLUMBIA' -Left 20 -Top 12 -Width 60 -BorderFg (Get-C 'Green')
    Add-Journal -State $State -Text 'Rafted the Columbia River without a scratch.'
}
