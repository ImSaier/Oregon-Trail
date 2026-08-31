$script:OTDefaultTopTen = @(
    @{ Name = 'Stephen Meek';   Score = 7650; Rating = 'Trail Guide' }
    @{ Name = 'Celinda Hines';  Score = 5694; Rating = 'Adventurer' }
    @{ Name = 'Andrew Sublette'; Score = 4138; Rating = 'Adventurer' }
    @{ Name = 'David Hastings'; Score = 2945; Rating = 'Adventurer' }
    @{ Name = 'Ezra Meeker';    Score = 2052; Rating = 'Adventurer' }
    @{ Name = 'William Vaughn'; Score = 1571; Rating = 'Greenhorn' }
    @{ Name = 'Mary Bartlett';  Score = 1049; Rating = 'Greenhorn' }
    @{ Name = 'William Wiggins'; Score = 810; Rating = 'Greenhorn' }
    @{ Name = 'Charles Hopper'; Score = 604;  Rating = 'Greenhorn' }
    @{ Name = 'Elijah White';   Score = 450;  Rating = 'Greenhorn' }
)

function Get-SaveDirectory {
    $dir = Join-Path $script:OTGameRoot 'saves'
    if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    return $dir
}

function Get-Rating {
    param([int]$Score)
    if ($Score -ge 7000) { return 'Trail Guide' }
    if ($Score -ge 3000) { return 'Adventurer' }
    return 'Greenhorn'
}

function Get-HealthPoints {
    param([int]$Health)
    $label = Get-HealthLabel $Health
    switch ($label) {
        'Good'      { return 500 }
        'Fair'      { return 400 }
        'Poor'      { return 300 }
        'Very Poor' { return 200 }
    }
    return 200
}

function Get-FinalScore {
    param($State)
    $rows = New-Object System.Collections.ArrayList
    $total = 0
    $living = Get-LivingMembers -State $State
    $perPerson = Get-HealthPoints -Health $State.Health
    $peoplePoints = $living.Count * $perPerson
    $total += $peoplePoints
    [void]$rows.Add(@{ Label = "$($living.Count) people in $((Get-HealthLabel $State.Health).ToLower()) health"; Points = $peoplePoints })
    $total += 50
    [void]$rows.Add(@{ Label = '1 wagon'; Points = 50 })
    $oxPoints = $State.Oxen * 4
    $total += $oxPoints
    [void]$rows.Add(@{ Label = "$($State.Oxen) oxen"; Points = $oxPoints })
    $spares = $State.Wheels + $State.Axles + $State.Tongues
    $sparePoints = $spares * 2
    $total += $sparePoints
    [void]$rows.Add(@{ Label = "$spares spare wagon parts"; Points = $sparePoints })
    $clothPoints = $State.Clothing * 2
    $total += $clothPoints
    [void]$rows.Add(@{ Label = "$($State.Clothing) sets of clothing"; Points = $clothPoints })
    $bulletPoints = [int][math]::Floor($State.Bullets / 50)
    $total += $bulletPoints
    [void]$rows.Add(@{ Label = "$(Format-Number $State.Bullets) bullets"; Points = $bulletPoints })
    $foodPoints = [int][math]::Floor($State.Food / 25)
    $total += $foodPoints
    [void]$rows.Add(@{ Label = "$(Format-Number $State.Food) pounds of food"; Points = $foodPoints })
    $cashPoints = [int][math]::Floor($State.Money / 5)
    $total += $cashPoints
    [void]$rows.Add(@{ Label = "$(Format-Money $State.Money) cash"; Points = $cashPoints })
    $final = $total * $State.Multiplier
    return @{
        Rows       = $rows.ToArray()
        Subtotal   = $total
        Multiplier = $State.Multiplier
        Total      = $final
        Rating     = (Get-Rating -Score $final)
    }
}

function Get-TopTen {
    $path = Join-Path (Get-SaveDirectory) 'topten.json'
    if (-not (Test-Path $path)) { return ,$script:OTDefaultTopTen }
    try {
        $raw = Get-Content -Path $path -Raw -ErrorAction Stop
        $data = ConvertFrom-Json $raw -ErrorAction Stop
        $list = New-Object System.Collections.ArrayList
        foreach ($e in $data) {
            [void]$list.Add(@{ Name = [string]$e.Name; Score = [int]$e.Score; Rating = [string]$e.Rating })
        }
        if ($list.Count -eq 0) { return ,$script:OTDefaultTopTen }
        return ,$list.ToArray()
    }
    catch {
        return ,$script:OTDefaultTopTen
    }
}

function Save-TopTen {
    param($Entries)
    $path = Join-Path (Get-SaveDirectory) 'topten.json'
    try {
        $json = ConvertTo-Json @($Entries) -Depth 4
        [System.IO.File]::WriteAllText($path, $json)
        return $true
    }
    catch {
        return $false
    }
}

function Add-TopTenEntry {
    param([string]$Name, [int]$Score)
    $entries = New-Object System.Collections.ArrayList
    foreach ($e in (Get-TopTen)) { [void]$entries.Add($e) }
    [void]$entries.Add(@{ Name = $Name; Score = $Score; Rating = (Get-Rating -Score $Score) })
    $sorted = @($entries | Sort-Object -Property Score -Descending)
    $top = @($sorted | Select-Object -First 10)
    [void](Save-TopTen -Entries $top)
    $rank = -1
    for ($i = 0; $i -lt $top.Count; $i++) {
        if ($top[$i].Name -eq $Name -and $top[$i].Score -eq $Score) { $rank = $i; break }
    }
    return @{ Rank = $rank; Entries = $top }
}

function Show-TopTen {
    param([int]$HighlightRank = -1, $Entries = $null)
    if ($null -eq $Entries) { $Entries = Get-TopTen }
    Clear-Buffer
    Draw-Panel -Left 22 -Top 3 -Width 56 -Height 22 -Title 'THE OREGON TOP TEN' -Fg (Get-C 'Gold') -Style 'Double'
    Write-BufferText -X 26 -Y 5 -Text 'Name' -Fg (Get-C 'Grey')
    Write-BufferText -X 46 -Y 5 -Text 'Rating' -Fg (Get-C 'Grey')
    Write-BufferText -X 66 -Y 5 -Text 'Points' -Fg (Get-C 'Grey')
    Draw-Rule -Y 6 -Left 22 -Width 56
    $y = 7
    for ($i = 0; $i -lt $Entries.Count -and $i -lt 10; $i++) {
        $e = $Entries[$i]
        $fg = Get-C 'White'
        if ($i -eq $HighlightRank) { $fg = Get-C 'Gold' }
        Write-BufferText -X 24 -Y $y -Text (($i + 1).ToString().PadLeft(2) + '.') -Fg (Get-C 'DarkGrey')
        Write-BufferText -X 28 -Y $y -Text $e.Name -Fg $fg
        Write-BufferText -X 46 -Y $y -Text $e.Rating -Fg $fg
        Write-BufferText -X 66 -Y $y -Text ($e.Score.ToString().PadLeft(6)) -Fg $fg
        $y++
    }
    Draw-Rule -Y 19 -Left 22 -Width 56
    Write-BufferTextCentered -Y 20 -Text 'Trail Guide  7000+' -Fg (Get-C 'DarkGrey') -Left 22 -Width 56
    Write-BufferTextCentered -Y 21 -Text 'Adventurer   3000-6999' -Fg (Get-C 'DarkGrey') -Left 22 -Width 56
    Write-BufferTextCentered -Y 22 -Text 'Greenhorn    below 3000' -Fg (Get-C 'DarkGrey') -Left 22 -Width 56
    Write-BufferTextCentered -Y 26 -Text 'Press SPACE BAR to continue' -Fg (Get-C 'DarkGrey')
    [void](Render-Frame)
    Wait-ForContinue
}

function Show-ScoreScreen {
    param($State)
    $score = Get-FinalScore -State $State
    Clear-Buffer
    Draw-Panel -Left 14 -Top 1 -Width 72 -Height 26 -Title 'YOUR FINAL SCORE' -Fg (Get-C 'Gold') -Style 'Double'
    $y = 4
    foreach ($row in $score.Rows) {
        Write-BufferText -X 18 -Y $y -Text $row.Label -Fg (Get-C 'White')
        Write-BufferText -X 72 -Y $y -Text ($row.Points.ToString().PadLeft(6)) -Fg (Get-C 'SkyBlue')
        $y++
    }
    Draw-Rule -Y ($y + 1) -Left 14 -Width 72
    Write-BufferText -X 18 -Y ($y + 2) -Text 'Subtotal' -Fg (Get-C 'White')
    Write-BufferText -X 72 -Y ($y + 2) -Text ($score.Subtotal.ToString().PadLeft(6)) -Fg (Get-C 'White')
    Write-BufferText -X 18 -Y ($y + 3) -Text ("Multiplier for a " + $State.ProfessionTitle.ToLower()) -Fg (Get-C 'White')
    Write-BufferText -X 72 -Y ($y + 3) -Text ('x' + $score.Multiplier).PadLeft(6) -Fg (Get-C 'White')
    Draw-Rule -Y ($y + 4) -Left 14 -Width 72
    Write-BufferText -X 18 -Y ($y + 5) -Text 'TOTAL' -Fg (Get-C 'Gold')
    Write-BufferText -X 72 -Y ($y + 5) -Text ($score.Total.ToString().PadLeft(6)) -Fg (Get-C 'Gold')
    Write-BufferTextCentered -Y ($y + 7) -Text ('Rating: ' + $score.Rating) -Fg (Get-C 'Amber') -Left 14 -Width 72
    Write-BufferTextCentered -Y 26 -Text 'Press SPACE BAR to continue' -Fg (Get-C 'DarkGrey')
    [void](Render-Frame)
    Wait-ForContinue
    return $score
}
