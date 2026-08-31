function Show-ProfessionDifferences {
    $text = "Traveling to Oregon isn't easy! But if you're a banker, you'll have more money for supplies and services than a carpenter or a farmer.`n`n" +
            "However, the harder you have to try, the more points you deserve! Therefore, the farmer earns the greatest number of points and the banker earns the least."
    Show-Message -Text $text -Title 'ABOUT THE CHOICES' -Left 16 -Top 7 -Width 68 -BorderFg (Get-C 'Gold')
}

function Select-Profession {
    while ($true) {
        Clear-Buffer
        Write-BufferTextCentered -Y 2 -Text 'MANY KINDS OF PEOPLE MADE THE TRIP TO OREGON' -Fg (Get-C 'Gold')
        $opts = @(
            'Be a banker from Boston'
            'Be a carpenter from Ohio'
            'Be a farmer from Illinois'
            'Find out the differences between these choices'
        )
        $r = Show-Menu -Title 'CHOOSE YOUR PROFESSION' -Options $opts -Left 16 -Top 6 -Width 68 -BorderFg (Get-C 'Gold')
        if ($r -lt 0) { return $null }
        if ($r -eq 3) {
            Show-ProfessionDifferences
            continue
        }
        return $script:OTProfessions[$r].Key
    }
}

function Read-PartyNames {
    $names = New-Object System.Collections.ArrayList
    Clear-Buffer
    Write-BufferTextCentered -Y 2 -Text 'WHO IS TRAVELING TO OREGON?' -Fg (Get-C 'Gold')
    $leader = Read-BufferedLine -Prompt 'What is your first name?' -Title 'PARTY LEADER' -Left 20 -Top 8 -Width 60 -MaxLength 12
    if ($null -eq $leader) { return $null }
    [void]$names.Add($leader)
    for ($i = 1; $i -le 4; $i++) {
        Clear-Buffer
        Write-BufferTextCentered -Y 2 -Text 'WHO IS TRAVELING TO OREGON?' -Fg (Get-C 'Gold')
        $y = 5
        foreach ($n in $names) {
            Write-BufferTextCentered -Y $y -Text $n -Fg (Get-C 'White')
            $y++
        }
        $prompt = "What is the first name of party member $i of 4?"
        $nm = Read-BufferedLine -Prompt $prompt -Title 'YOUR COMPANIONS' -Left 20 -Top 12 -Width 60 -MaxLength 12
        if ($null -eq $nm) { return $null }
        [void]$names.Add($nm)
    }
    return ,$names.ToArray()
}

function Show-DepartureAdvice {
    $text = "You attend a public meeting held for 'folks with the California-Oregon fever.' You're told:`n`n" +
            "If you leave too early, there won't be any grass for your oxen to eat. If you leave too late, you may not get to Oregon before winter comes. If you leave at just the right time, there will be green grass and the weather will still be cool."
    Show-Message -Text $text -Title 'ADVICE' -Left 14 -Top 6 -Width 72 -BorderFg (Get-C 'Gold')
}

function Select-DepartureMonth {
    while ($true) {
        Clear-Buffer
        Write-BufferTextCentered -Y 2 -Text 'IT IS 1848' -Fg (Get-C 'Gold')
        $header = "Your jumping off place for Oregon is Independence, Missouri. You must decide which month to leave Independence."
        $opts = @('March', 'April', 'May', 'June', 'July', 'Ask for advice')
        $r = Show-Menu -Title 'WHEN WILL YOU LEAVE?' -Options $opts -Header $header -Left 16 -Top 5 -Width 68 -BorderFg (Get-C 'Gold')
        if ($r -lt 0) { return -1 }
        if ($r -eq 5) {
            Show-DepartureAdvice
            continue
        }
        return $script:OTDepartureMonths[$r].Month
    }
}

function Show-MainMenu {
    Clear-Buffer
    Draw-TitleScreen
    $opts = @(
        'Travel the trail'
        'Learn about the trail'
        'See the Oregon Top Ten'
        'Turn sound off'
        'End'
    )
    return (Show-Menu -Title 'THE OREGON TRAIL' -Options $opts -Left 30 -Top 8 -Width 42 -BorderFg (Get-C 'Gold'))
}

function Start-NewGame {
    $prof = Select-Profession
    if ($null -eq $prof) { return $null }
    $names = Read-PartyNames
    if ($null -eq $names) { return $null }
    $month = Select-DepartureMonth
    if ($month -lt 0) { return $null }
    $state = New-GameState -Profession $prof -Names $names -StartMonth $month
    Show-DepartureBriefing -State $state
    return $state
}

function Show-DepartureBriefing {
    param($State)
    $prof = @($script:OTProfessions | Where-Object { $_.Key -eq $State.Profession })[0]
    $monthName = @($script:OTDepartureMonths | Where-Object { $_.Month -eq $State.StartMonth })[0].Name
    $text = "You are a $($prof.Title.ToLower()).`n`n" +
            "You will leave Independence, Missouri in $monthName 1848 with $((Get-LivingCount -State $State)) people in your party.`n`n" +
            "Before leaving Independence you should buy equipment and supplies. You have $(Format-Money $State.Money) in cash, but you don't have to spend it all now."
    Show-Message -Text $text -Title 'YOUR JOURNEY BEGINS' -Left 14 -Top 6 -Width 72 -BorderFg (Get-C 'Gold')
}
