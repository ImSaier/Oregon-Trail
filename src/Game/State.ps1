$script:OTProfessions = @(
    @{ Key = 'Banker';    Title = 'Banker from Boston';     Money = 1600; Multiplier = 1 }
    @{ Key = 'Carpenter'; Title = 'Carpenter from Ohio';    Money = 800;  Multiplier = 2 }
    @{ Key = 'Farmer';    Title = 'Farmer from Illinois';   Money = 400;  Multiplier = 3 }
)

$script:OTDepartureMonths = @(
    @{ Month = 3; Name = 'March' }
    @{ Month = 4; Name = 'April' }
    @{ Month = 5; Name = 'May' }
    @{ Month = 6; Name = 'June' }
    @{ Month = 7; Name = 'July' }
)

$script:OTPaceOptions = @(
    @{ Key = 'Steady';    Name = 'a steady pace';    Miles = 14; HealthCost = 0 }
    @{ Key = 'Strenuous'; Name = 'a strenuous pace'; Miles = 19; HealthCost = 1 }
    @{ Key = 'Grueling';  Name = 'a grueling pace';  Miles = 24; HealthCost = 2 }
)

$script:OTRationOptions = @(
    @{ Key = 'Filling';   Name = 'filling';    Pounds = 3; HealthCost = 0 }
    @{ Key = 'Meager';    Name = 'meager';     Pounds = 2; HealthCost = 1 }
    @{ Key = 'BareBones'; Name = 'bare bones'; Pounds = 1; HealthCost = 2 }
)

function New-PartyMember {
    param([string]$Name, [switch]$IsLeader)
    return @{
        Name     = $Name
        Alive    = $true
        Health   = 0
        Illness  = ''
        IllKey   = ''
        IllSeverity = 0
        IllDays  = 0
        IsLeader = [bool]$IsLeader
        DeathDay = $null
        DeathCause = ''
    }
}

function New-GameState {
    param(
        [string]$Profession = 'Banker',
        [string[]]$Names = @('Player', 'Amanda', 'Zeke', 'Charlie', 'Mary'),
        [int]$StartMonth = 4,
        [int]$Seed = -1
    )
    $prof = @($script:OTProfessions | Where-Object { $_.Key -eq $Profession })[0]
    if ($null -eq $prof) { throw "Unknown profession '$Profession'" }
    if ($Seed -lt 0) { $Seed = (Get-Random -Minimum 1 -Maximum 999999) }
    $party = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $Names.Count; $i++) {
        [void]$party.Add((New-PartyMember -Name $Names[$i] -IsLeader:($i -eq 0)))
    }
    return @{
        Profession      = $prof.Key
        ProfessionTitle = $prof.Title
        Multiplier      = $prof.Multiplier
        Money           = [double]$prof.Money
        StartingMoney   = [double]$prof.Money
        Party           = $party
        Oxen            = 0
        Food            = 0
        Clothing        = 0
        Bullets         = 0
        Wheels          = 0
        Axles           = 0
        Tongues         = 0
        Money2          = 0
        StartMonth      = $StartMonth
        Date            = [datetime]::new(1848, $StartMonth, 1)
        Miles           = 0
        LandmarkIndex   = 0
        MilesToNext     = 0
        Pace            = 'Steady'
        Rations         = 'Filling'
        Weather         = 'Warm'
        Health          = 0
        Rng             = (New-Object System.Random $Seed)
        Seed            = $Seed
        Journal         = (New-Object System.Collections.ArrayList)
        Finished        = $false
        Outcome         = ''
        DaysOnTrail     = 0
        RestDays        = 0
        NextTrade       = 0
    }
}

function Get-LivingMembers {
    param($State)
    return ,@($State.Party | Where-Object { $_.Alive })
}

function Get-LivingCount {
    param($State)
    return (Get-LivingMembers -State $State).Count
}

function Get-Leader {
    param($State)
    return @($State.Party | Where-Object { $_.IsLeader })[0]
}

function Add-Journal {
    param($State, [string]$Text)
    [void]$State.Journal.Add(@{ Date = $State.Date; Text = $Text })
}

function Get-PaceOption {
    param($State)
    return @($script:OTPaceOptions | Where-Object { $_.Key -eq $State.Pace })[0]
}

function Get-RationOption {
    param($State)
    return @($script:OTRationOptions | Where-Object { $_.Key -eq $State.Rations })[0]
}

function Get-DailyFoodNeed {
    param($State)
    $r = Get-RationOption -State $State
    return $r.Pounds * (Get-LivingCount -State $State)
}

function Add-Health {
    param($State, [int]$Delta)
    $State.Health += $Delta
    if ($State.Health -lt 0) { $State.Health = 0 }
    if ($State.Health -gt 120) { $State.Health = 120 }
}

function Get-WagonLoad {
    param($State)
    $load = $State.Food
    $load += $State.Clothing * 8
    $load += [math]::Ceiling($State.Bullets / 20) * 5
    $load += ($State.Wheels + $State.Axles + $State.Tongues) * 20
    return [int]$load
}
