$script:OTWeatherTypes = @(
    @{ Key = 'Hot';       Name = 'hot';        Cold = 0; SpeedMod = 0 }
    @{ Key = 'Warm';      Name = 'warm';       Cold = 0; SpeedMod = 0 }
    @{ Key = 'Cool';      Name = 'cool';       Cold = 0; SpeedMod = 0 }
    @{ Key = 'Rainy';     Name = 'rainy';      Cold = 1; SpeedMod = -1 }
    @{ Key = 'Cold';      Name = 'cold';       Cold = 2; SpeedMod = 0 }
    @{ Key = 'VeryCold';  Name = 'very cold';  Cold = 3; SpeedMod = -2 }
    @{ Key = 'Snowy';     Name = 'snowy';      Cold = 4; SpeedMod = -3 }
)

function Get-WeatherOption {
    param([string]$Key)
    return @($script:OTWeatherTypes | Where-Object { $_.Key -eq $Key })[0]
}

function Update-Weather {
    param($State)
    $month = $State.Date.Month
    $mountain = Test-InMountains -State $State
    $roll = $State.Rng.Next(0, 100)
    $key = 'Warm'
    if ($month -le 4) {
        if ($roll -lt 30) { $key = 'Cool' } elseif ($roll -lt 55) { $key = 'Rainy' } elseif ($roll -lt 80) { $key = 'Warm' } else { $key = 'Cold' }
    }
    elseif ($month -le 6) {
        if ($roll -lt 40) { $key = 'Warm' } elseif ($roll -lt 65) { $key = 'Cool' } elseif ($roll -lt 85) { $key = 'Rainy' } else { $key = 'Hot' }
    }
    elseif ($month -le 8) {
        if ($roll -lt 45) { $key = 'Hot' } elseif ($roll -lt 75) { $key = 'Warm' } elseif ($roll -lt 90) { $key = 'Rainy' } else { $key = 'Cool' }
    }
    elseif ($month -le 10) {
        if ($roll -lt 30) { $key = 'Cool' } elseif ($roll -lt 55) { $key = 'Cold' } elseif ($roll -lt 80) { $key = 'Rainy' } else { $key = 'VeryCold' }
    }
    else {
        if ($roll -lt 30) { $key = 'Cold' } elseif ($roll -lt 65) { $key = 'VeryCold' } else { $key = 'Snowy' }
    }
    if ($mountain) {
        if ($key -eq 'Hot') { $key = 'Warm' }
        elseif ($key -eq 'Cold' -and $State.Rng.Next(0, 100) -lt 40) { $key = 'VeryCold' }
        elseif ($key -eq 'VeryCold' -and $State.Rng.Next(0, 100) -lt 40) { $key = 'Snowy' }
    }
    $State.Weather = $key
}

function Get-WeatherLabel {
    param($State)
    $w = Get-WeatherOption -Key $State.Weather
    if ($null -eq $w) { return 'warm' }
    return $w.Name
}

function Get-DailyMiles {
    param($State)
    $pace = Get-PaceOption -State $State
    $miles = $pace.Miles
    $miles += $State.Rng.Next(-2, 3)
    if ($State.Oxen -le 2) { $miles = [int][math]::Floor($miles * 0.5) }
    elseif ($State.Oxen -le 4) { $miles = [int][math]::Floor($miles * 0.75) }
    elseif ($State.Oxen -ge 8) { $miles += 2 }
    elseif ($State.Oxen -ge 6) { $miles += 1 }
    $w = Get-WeatherOption -Key $State.Weather
    if ($null -ne $w) { $miles += $w.SpeedMod }
    if (Test-InMountains -State $State) { $miles -= 2 }
    if ($State.Health -ge 105) { $miles -= 3 }
    elseif ($State.Health -ge 70) { $miles -= 1 }
    if ($miles -lt 1) { $miles = 1 }
    return $miles
}

function Get-RequiredClothing {
    param($State)
    return (Get-LivingCount -State $State) * 2
}

function Update-DailyHealth {
    param($State, [switch]$Resting)
    $delta = 0
    $rations = Get-RationOption -State $State
    $pace = Get-PaceOption -State $State
    if ($Resting) { $delta -= 3 }
    else { $delta += $pace.HealthCost }
    $delta += $rations.HealthCost
    if ($State.Food -le 0) { $delta += 5 }
    $w = Get-WeatherOption -Key $State.Weather
    if ($null -ne $w -and $w.Cold -gt 0) {
        $needed = Get-RequiredClothing -State $State
        if ($State.Clothing -lt $needed) { $delta += $w.Cold }
    }
    if ($State.Food -gt 0) {
        $delta -= 1
        if ($rations.Key -eq 'Filling') { $delta -= 1 }
        if ($pace.Key -eq 'Steady' -and -not $Resting) { $delta -= 1 }
    }
    Add-Health -State $State -Delta $delta
}

function Update-DailyFood {
    param($State)
    $need = Get-DailyFoodNeed -State $State
    if ($State.Food -ge $need) {
        $State.Food -= $need
        return $true
    }
    $State.Food = 0
    return $false
}

function Draw-TravelStatus {
    param($State, [int]$Offset = 0)
    Clear-Buffer
    Draw-StatusBar -State $State -Top 0
    Draw-TrailScene -State $State -Top 4 -Offset $Offset
    Draw-Rule -Y 15 -Left 0 -Width 100 -Plain
    $next = Get-NextLandmark -State $State
    Write-BufferText -X 4 -Y 17 -Text ('Miles traveled: ' + (Format-Number $State.Miles)) -Fg (Get-C 'White')
    if ($null -ne $next) {
        Write-BufferText -X 4 -Y 18 -Text ('Next landmark: ' + $next.Short + ' in ' + (Format-Number (Get-MilesToNextLandmark -State $State)) + ' miles') -Fg (Get-C 'SkyBlue')
    }
    Write-BufferText -X 4 -Y 19 -Text ('Pace: ' + (Get-PaceOption -State $State).Name) -Fg (Get-C 'Tan')
    Write-BufferText -X 4 -Y 20 -Text ('Rations: ' + (Get-RationOption -State $State).Name) -Fg (Get-C 'Tan')
    Write-BufferText -X 56 -Y 17 -Text ('Oxen: ' + $State.Oxen) -Fg (Get-C 'Ox')
    Write-BufferText -X 56 -Y 18 -Text ('Food: ' + (Format-Number $State.Food) + ' lbs') -Fg (Get-C 'Tan')
    Write-BufferText -X 56 -Y 19 -Text ('Bullets: ' + (Format-Number $State.Bullets)) -Fg (Get-C 'Silver')
    Write-BufferText -X 56 -Y 20 -Text ('Money: ' + (Format-Money $State.Money)) -Fg (Get-C 'Green')
    $y = 17
    foreach ($m in $State.Party) {
        $label = $m.Name.PadRight(12)
        $fg = Get-C 'DarkGrey'
        $status = 'dead'
        if ($m.Alive) {
            $fg = Get-HealthColor $State.Health
            $status = Get-HealthLabel $State.Health
            if ($m.Illness.Length -gt 0) { $status = $m.Illness }
        }
        Write-BufferText -X 78 -Y $y -Text $label -Fg (Get-C 'White')
        Write-BufferText -X 88 -Y $y -Text $status -Fg $fg
        $y++
    }
    Write-BufferTextCentered -Y 27 -Text 'Press SPACE BAR for options' -Fg (Get-C 'DarkGrey')
}

function Show-SuppliesScreen {
    param($State)
    Clear-Buffer
    Draw-Panel -Left 20 -Top 4 -Width 60 -Height 21 -Title 'YOUR SUPPLIES' -Fg (Get-C 'Gold') -Style 'Double'
    $rows = @(
        @{ L = 'Oxen';                V = "$($State.Oxen)" }
        @{ L = 'Food';                V = ((Format-Number $State.Food) + ' pounds') }
        @{ L = 'Clothing';            V = "$($State.Clothing) sets" }
        @{ L = 'Ammunition';          V = ((Format-Number $State.Bullets) + ' bullets') }
        @{ L = 'Spare wagon wheels';  V = "$($State.Wheels)" }
        @{ L = 'Spare wagon axles';   V = "$($State.Axles)" }
        @{ L = 'Spare wagon tongues'; V = "$($State.Tongues)" }
        @{ L = 'Money';               V = (Format-Money $State.Money) }
    )
    $y = 6
    foreach ($r in $rows) {
        Write-BufferText -X 24 -Y $y -Text $r.L -Fg (Get-C 'White')
        Write-BufferText -X 54 -Y $y -Text $r.V -Fg (Get-C 'SkyBlue')
        $y++
    }
    Draw-Rule -Y 15 -Left 20 -Width 60
    Write-BufferText -X 24 -Y 16 -Text 'Party' -Fg (Get-C 'Gold')
    $y = 17
    foreach ($m in $State.Party) {
        $status = 'dead'
        $fg = Get-C 'DarkGrey'
        if ($m.Alive) {
            $status = Get-HealthLabel $State.Health
            $fg = Get-HealthColor $State.Health
            if ($m.Illness.Length -gt 0) { $status = $m.Illness }
        }
        Write-BufferText -X 24 -Y $y -Text $m.Name -Fg (Get-C 'White')
        Write-BufferText -X 54 -Y $y -Text $status -Fg $fg
        $y++
    }
    Write-BufferTextCentered -Y 23 -Text 'Press SPACE BAR to continue' -Fg (Get-C 'DarkGrey') -Left 20 -Width 60
    [void](Render-Frame)
    Wait-ForContinue
}

function Show-PaceMenu {
    param($State)
    $opts = @(
        'a steady pace (about 14 miles a day)'
        'a strenuous pace (about 19 miles a day)'
        'a grueling pace (about 24 miles a day)'
    )
    $header = 'How hard do you want to push your teams?'
    $r = Show-Menu -Title 'CHANGE PACE' -Options $opts -Header $header -Left 20 -Top 8 -Width 60 -AllowEscape -BorderFg (Get-C 'Gold')
    if ($r -ge 0) { $State.Pace = $script:OTPaceOptions[$r].Key }
}

function Show-RationsMenu {
    param($State)
    $opts = @(
        'filling - well fed, 3 pounds per person a day'
        'meager - not much, 2 pounds per person a day'
        'bare bones - very little, 1 pound per person a day'
    )
    $header = 'How much food do you want your party to eat?'
    $r = Show-Menu -Title 'CHANGE FOOD RATIONS' -Options $opts -Header $header -Left 18 -Top 8 -Width 64 -AllowEscape -BorderFg (Get-C 'Gold')
    if ($r -ge 0) { $State.Rations = $script:OTRationOptions[$r].Key }
}

function Invoke-Rest {
    param($State)
    $raw = Read-BufferedLine -Prompt 'How many days would you like to rest?' -Title 'STOP TO REST' -Left 20 -Top 10 -Width 60 -MaxLength 3 -AllowEmpty
    if ($null -eq $raw) { return }
    $days = 0
    if (-not [int]::TryParse($raw.Trim(), [ref]$days)) { return }
    if ($days -le 0) { return }
    if ($days -gt 30) { $days = 30 }
    for ($d = 0; $d -lt $days; $d++) {
        $State.Date = $State.Date.AddDays(1)
        $State.DaysOnTrail++
        $State.RestDays++
        Update-Weather -State $State
        [void](Update-DailyFood -State $State)
        Update-DailyHealth -State $State -Resting
        Update-Illness -State $State
        if ((Get-LivingCount -State $State) -eq 0) { break }
    }
    Show-Message -Text "You rested for $days day$(if ($days -ne 1) { 's' })." -Title 'REST' -Left 24 -Top 11 -Width 52 -BorderFg (Get-C 'Green')
}

function Show-TrailMenu {
    param($State)
    $landmark = Get-CurrentLandmark -State $State
    $opts = New-Object System.Collections.ArrayList
    [void]$opts.Add('Continue on trail')
    [void]$opts.Add('Check supplies')
    [void]$opts.Add('Look at map')
    [void]$opts.Add('Change pace')
    [void]$opts.Add('Change food rations')
    [void]$opts.Add('Stop to rest')
    [void]$opts.Add('Attempt to trade')
    [void]$opts.Add('Hunt for food')
    if ($null -ne $landmark -and $landmark.Type -eq 'Fort' -and (Test-AtLandmark -State $State)) {
        [void]$opts.Add('Buy supplies')
    }
    return (Show-Menu -Title 'YOU MAY' -Options $opts.ToArray() -Left 26 -Top 3 -Width 48 -AllowEscape -BorderFg (Get-C 'Gold'))
}

function Invoke-TravelDay {
    param($State)
    $State.Date = $State.Date.AddDays(1)
    $State.DaysOnTrail++
    Update-Weather -State $State
    $miles = Get-DailyMiles -State $State
    $next = Get-NextLandmark -State $State
    $arrived = $false
    if ($null -ne $next -and ($State.Miles + $miles) -ge $next.Miles) {
        $miles = $next.Miles - $State.Miles
        $arrived = $true
    }
    $State.Miles += $miles
    $ateWell = Update-DailyFood -State $State
    Update-DailyHealth -State $State
    Update-Illness -State $State
    return @{ Miles = $miles; Arrived = $arrived; AteWell = $ateWell }
}

function Show-TravelAnimation {
    param($State, [int]$Frames = 6)
    $clock = New-FrameClock -Fps 12
    for ($f = 0; $f -lt $Frames; $f++) {
        Draw-TravelStatus -State $State -Offset $f
        [void](Render-Frame)
        if ($null -ne (Read-GameKeyIfAvailable)) { break }
        [void](Step-FrameClock -Clock $clock)
    }
}
