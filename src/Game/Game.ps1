function Test-GameOver {
    param($State)
    if ((Get-LivingCount -State $State) -eq 0) {
        $State.Finished = $true
        $State.Outcome = 'AllDead'
        return $true
    }
    if ($State.Miles -ge $script:OTTrailLength) {
        $State.Finished = $true
        $State.Outcome = 'Arrived'
        return $true
    }
    return $false
}

function Show-Ending {
    param($State)
    if ($State.Outcome -eq 'AllDead') {
        Clear-Buffer
        Write-BufferTextCentered -Y 6 -Text 'EVERYONE IN YOUR PARTY HAS DIED.' -Fg (Get-C 'Blood')
        Write-BufferTextCentered -Y 9 -Text 'You never reached Oregon.' -Fg (Get-C 'Grey')
        Write-BufferTextCentered -Y 11 -Text ((Format-Number $State.Miles) + ' miles from Independence') -Fg (Get-C 'Grey')
        Write-BufferTextCentered -Y 13 -Text (Get-TrailDateString -State $State) -Fg (Get-C 'Grey')
        Draw-Art -Name 'Grave' -Left 0 -Top 16 -Fg (Get-C 'DarkGrey') -Centered
        Write-BufferTextCentered -Y 25 -Text 'Press SPACE BAR to continue' -Fg (Get-C 'DarkGrey')
        [void](Render-Frame)
        Wait-ForContinue
        return
    }
    Clear-Buffer
    $sky = Get-C 'Night'
    Fill-BufferRect -X 0 -Y 0 -Width 100 -Height 12 -Char ([char]32) -Fg 1 -Bg $sky
    Write-BufferTextCentered -Y 3 -Text 'YOU HAVE REACHED' -Fg (Get-C 'Grey') -Left 0 -Width 100
    Write-BufferTextCentered -Y 5 -Text 'THE WILLAMETTE VALLEY' -Fg (Get-C 'Gold')
    Write-BufferTextCentered -Y 7 -Text 'OREGON' -Fg (Get-C 'Amber')
    Write-BufferArt -X 0 -Y 12 -Lines (Get-Art 'Mountains') -Fg (Get-C 'Mountain') -Transparent
    Draw-Ground -Y 21 -Fg (Get-C 'DarkGreen')
    Write-BufferArt -X 12 -Y 17 -Lines (Get-Art 'OxTeam') -Fg (Get-C 'Ox') -Transparent
    Write-BufferArt -X 36 -Y 16 -Lines (Get-Art 'WagonSmall') -Fg (Get-C 'Canvas') -Transparent
    $living = Get-LivingMembers -State $State
    Write-BufferTextCentered -Y 23 -Text ("You arrived with $($living.Count) of your original 5 party members.") -Fg (Get-C 'White')
    Write-BufferTextCentered -Y 24 -Text ('The journey took ' + $State.DaysOnTrail + ' days.') -Fg (Get-C 'White')
    Write-BufferTextCentered -Y 25 -Text (Get-TrailDateString -State $State) -Fg (Get-C 'Tan')
    Write-BufferTextCentered -Y 27 -Text 'Press SPACE BAR to continue' -Fg (Get-C 'DarkGrey')
    [void](Render-Frame)
    Wait-ForContinue
}

function Invoke-LandmarkStop {
    param($State, $Landmark)
    Show-LandmarkArrival -State $State -Landmark $Landmark
    if ($Landmark.Type -eq 'River') {
        Invoke-RiverCrossing -State $State -Landmark $Landmark
        return
    }
    if ($Landmark.Type -eq 'Fort') {
        while ($true) {
            $opts = @('Buy supplies', 'Talk to people', 'Look at your supplies', 'Continue on trail')
            $r = Show-Menu -Title $Landmark.Name.ToUpper() -Options $opts -Left 26 -Top 8 -Width 48 -AllowEscape -BorderFg (Get-C 'Gold')
            if ($r -lt 0 -or $r -eq 3) { return }
            if ($r -eq 0) {
                $factor = 1.5
                if ($null -ne $Landmark.PriceFactor) { $factor = [double]$Landmark.PriceFactor }
                [void](Show-Store -State $State -SkipWelcome -PriceFactor $factor -LocationName $Landmark.Name)
            }
            elseif ($r -eq 1) { Invoke-TalkToPeople -State $State }
            else { Show-SuppliesScreen -State $State }
        }
    }
    if ($Landmark.Short -eq 'The Dalles') {
        Show-DallesChoice -State $State
        return
    }
    while ($true) {
        $opts = @('Look around', 'Talk to people', 'Look at your supplies', 'Continue on trail')
        $r = Show-Menu -Title $Landmark.Name.ToUpper() -Options $opts -Left 26 -Top 8 -Width 48 -AllowEscape -BorderFg (Get-C 'Gold')
        if ($r -lt 0 -or $r -eq 3) { return }
        if ($r -eq 0) {
            Show-Message -Text (Get-LandmarkDescription -Landmark $Landmark) -Title $Landmark.Name.ToUpper() -Left 18 -Top 10 -Width 64 -BorderFg (Get-C 'SkyBlue')
        }
        elseif ($r -eq 1) { Invoke-TalkToPeople -State $State }
        else { Show-SuppliesScreen -State $State }
    }
}

function Invoke-TrailTurn {
    param($State)
    $r = Show-TrailMenu -State $State
    switch ($r) {
        0 { return 'Travel' }
        1 { Show-SuppliesScreen -State $State; return 'Menu' }
        2 { Show-MapScreen -State $State; return 'Menu' }
        3 { Show-PaceMenu -State $State; return 'Menu' }
        4 { Show-RationsMenu -State $State; return 'Menu' }
        5 { Invoke-Rest -State $State; return 'Menu' }
        6 { Invoke-Trade -State $State; return 'Menu' }
        7 { Invoke-Hunt -State $State; return 'Menu' }
        8 {
            $lm = Get-CurrentLandmark -State $State
            if ($null -ne $lm -and $lm.Type -eq 'Fort' -and (Test-AtLandmark -State $State)) {
                $factor = 1.5
                if ($null -ne $lm.PriceFactor) { $factor = [double]$lm.PriceFactor }
                [void](Show-Store -State $State -SkipWelcome -PriceFactor $factor -LocationName $lm.Name)
            }
            return 'Menu'
        }
    }
    return 'Travel'
}

function Start-Journey {
    param($State)
    while (-not $State.Finished) {
        Show-TravelAnimation -State $State -Frames 5
        $action = Invoke-TrailTurn -State $State
        if ($action -eq 'Menu') {
            if (Test-GameOver -State $State) { break }
            continue
        }
        $daysThisLeg = 0
        while ($true) {
            $day = Invoke-TravelDay -State $State
            $daysThisLeg++
            if ((Get-LivingCount -State $State) -eq 0) { break }
            if ($State.Oxen -le 0) {
                Show-Message -Text 'You have no oxen left to pull your wagon. Your journey ends here.' -Title 'STRANDED' -Left 20 -Top 12 -Width 60 -BorderFg (Get-C 'Blood')
                $State.Finished = $true
                $State.Outcome = 'Stranded'
                break
            }
            if ($State.Food -le 0) {
                Show-Message -Text 'You are out of food. Your party is starving.' -Title 'STARVATION' -Left 22 -Top 12 -Width 56 -BorderFg (Get-C 'Red')
            }
            $evt = Invoke-RandomEvent -State $State
            if ($null -ne $evt) {
                Show-TravelAnimation -State $State -Frames 2
                Show-EventMessage -Event $evt
            }
            if ($day.Arrived) {
                $State.LandmarkIndex++
                $lm = Get-CurrentLandmark -State $State
                if ($null -ne $lm -and $lm.Type -eq 'End') { break }
                Invoke-LandmarkStop -State $State -Landmark $lm
                break
            }
            Show-TravelAnimation -State $State -Frames 3
            if ($daysThisLeg -ge 1) { break }
        }
        if (Test-GameOver -State $State) { break }
    }
    Show-Ending -State $State
    if ($State.Outcome -eq 'Arrived') {
        $score = Show-ScoreScreen -State $State
        $leader = Get-Leader -State $State
        $name = 'Traveler'
        if ($null -ne $leader) { $name = $leader.Name }
        $result = Add-TopTenEntry -Name $name -Score $score.Total
        Show-TopTen -HighlightRank $result.Rank -Entries $result.Entries
    }
}

function Show-LearnAboutTrail {
    $text = "The Oregon Trail ran two thousand miles from Independence, Missouri to the Willamette Valley in Oregon.`n`n" +
            "Between 1841 and 1869, some three hundred thousand emigrants walked it. Roughly one in ten died on the way. Disease killed far more of them than any other cause: cholera, dysentery, typhoid and fever took whole families in a matter of days.`n`n" +
            "The journey had to be timed carefully. Leave too early and there is no grass for the oxen. Leave too late and the mountain passes fill with snow before you reach them."
    Show-Message -Text $text -Title 'ABOUT THE TRAIL' -Left 12 -Top 4 -Width 76 -BorderFg (Get-C 'Gold')
}

function Start-OregonTrail {
    while ($true) {
        $choice = Show-MainMenu
        if ($choice -lt 0 -or $choice -eq 4) { return }
        if ($choice -eq 1) { Show-LearnAboutTrail; continue }
        if ($choice -eq 2) { Show-TopTen; continue }
        if ($choice -eq 3) { continue }
        $state = Start-NewGame
        if ($null -eq $state) { continue }
        [void](Show-Store -State $state)
        Start-Journey -State $state
    }
}
