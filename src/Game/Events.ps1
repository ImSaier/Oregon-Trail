$script:OTIllnesses = @(
    @{ Key = 'Typhoid';    Name = 'typhoid fever'; Severity = 8 }
    @{ Key = 'Cholera';    Name = 'cholera';       Severity = 10 }
    @{ Key = 'Dysentery';  Name = 'dysentery';     Severity = 6 }
    @{ Key = 'Measles';    Name = 'the measles';   Severity = 6 }
    @{ Key = 'Fever';      Name = 'a fever';       Severity = 4 }
    @{ Key = 'Exhaustion'; Name = 'exhaustion';    Severity = 4 }
)

$script:OTInjuries = @(
    @{ Key = 'BrokenArm';  Name = 'a broken arm'; Severity = 3 }
    @{ Key = 'BrokenLeg';  Name = 'a broken leg'; Severity = 5 }
    @{ Key = 'SnakeBite';  Name = 'a snake bite'; Severity = 7 }
)

function Get-RandomLivingMember {
    param($State)
    $living = Get-LivingMembers -State $State
    if ($living.Count -eq 0) { return $null }
    return $living[$State.Rng.Next(0, $living.Count)]
}

function Set-MemberIll {
    param($State, $Member, $Ailment)
    $Member.Illness = $Ailment.Name
    $Member.IllKey = $Ailment.Key
    $Member.IllSeverity = $Ailment.Severity
    $Member.IllDays = 0
    Add-Health -State $State -Delta 5
    Add-Journal -State $State -Text "$($Member.Name) has $($Ailment.Name)."
}

function Set-MemberDead {
    param($State, $Member, [string]$Cause)
    $Member.Alive = $false
    $Member.DeathCause = $Cause
    $Member.DeathDay = $State.Date
    $Member.Illness = ''
    Add-Journal -State $State -Text "$($Member.Name) has died of $Cause."
}

function Show-DeathScreen {
    param($State, $Member)
    Clear-Buffer
    Draw-Tombstone -Name $Member.Name -Cause $Member.DeathCause -DateText $Member.DeathDay.ToString('MMMM d, yyyy') -Top 5
    Write-BufferTextCentered -Y 20 -Text ($Member.Name + ' has died.') -Fg (Get-C 'Blood')
    Write-BufferTextCentered -Y 25 -Text 'Press SPACE BAR to continue' -Fg (Get-C 'DarkGrey')
    [void](Render-Frame)
    Wait-ForContinue
}

function Update-Illness {
    param($State)
    foreach ($m in (Get-LivingMembers -State $State)) {
        if ([string]::IsNullOrEmpty($m.Illness)) { continue }
        $m.IllDays++
        $severity = 4
        if ($null -ne $m.IllSeverity) { $severity = $m.IllSeverity }
        $deathChance = [math]::Floor($severity / 2) + [math]::Floor($State.Health / 30) + [math]::Floor($m.IllDays / 2) - 2
        if ($State.Food -le 0) { $deathChance += 4 }
        if ($deathChance -lt 1) { $deathChance = 1 }
        if ($State.Rng.Next(0, 100) -lt $deathChance) {
            Set-MemberDead -State $State -Member $m -Cause $m.Illness
            Show-DeathScreen -State $State -Member $m
            continue
        }
        $recoverChance = 30 - [math]::Floor($State.Health / 10)
        if ($recoverChance -lt 12) { $recoverChance = 12 }
        if ($m.IllDays -ge 2 -and $State.Rng.Next(0, 100) -lt $recoverChance) {
            $was = $m.Illness
            $m.Illness = ''
            $m.IllDays = 0
            Add-Journal -State $State -Text "$($m.Name) has recovered from $was."
            Show-Message -Text "$($m.Name) has recovered from $was." -Title 'GOOD NEWS' -Left 24 -Top 11 -Width 52 -BorderFg (Get-C 'Green')
        }
    }
    $chance = 2 + [math]::Floor($State.Health / 25)
    $rations = Get-RationOption -State $State
    $chance += $rations.HealthCost * 2
    if ($State.Food -le 0) { $chance += 8 }
    if ($chance -gt 14) { $chance = 14 }
    if ($State.Rng.Next(0, 100) -lt $chance) {
        $victim = Get-RandomLivingMember -State $State
        if ($null -ne $victim -and [string]::IsNullOrEmpty($victim.Illness)) {
            $ail = $script:OTIllnesses[$State.Rng.Next(0, $script:OTIllnesses.Count)]
            Set-MemberIll -State $State -Member $victim -Ailment $ail
            Show-Message -Text "$($victim.Name) has $($ail.Name)." -Title 'BAD NEWS' -Left 24 -Top 11 -Width 52 -BorderFg (Get-C 'Red')
        }
    }
}

function Invoke-BreakdownEvent {
    param($State)
    $parts = @(
        @{ Field = 'Wheels';  Name = 'wagon wheel' }
        @{ Field = 'Axles';   Name = 'wagon axle' }
        @{ Field = 'Tongues'; Name = 'wagon tongue' }
    )
    $part = $parts[$State.Rng.Next(0, 3)]
    if ($State[$part.Field] -gt 0) {
        $State[$part.Field] = $State[$part.Field] - 1
        return "A $($part.Name) broke. You used one of your spares to repair it."
    }
    $lost = $State.Rng.Next(2, 6)
    $State.Date = $State.Date.AddDays($lost)
    $State.DaysOnTrail += $lost
    Add-Health -State $State -Delta 3
    return "A $($part.Name) broke and you had no spare. You lost $lost days making repairs."
}

function Invoke-OxEvent {
    param($State)
    if ($State.Oxen -le 0) { return 'Your oxen are gone. You can go no further without a team.' }
    $roll = $State.Rng.Next(0, 100)
    if ($roll -lt 45) {
        $State.Oxen--
        return 'One of your oxen has died.'
    }
    if ($roll -lt 75) {
        $State.Oxen--
        return 'An ox wandered off in the night and could not be found.'
    }
    $lost = $State.Rng.Next(1, 4)
    $State.Date = $State.Date.AddDays($lost)
    $State.DaysOnTrail += $lost
    return "An ox is injured. You lost $lost days resting the team."
}

function Invoke-TheftEvent {
    param($State)
    $roll = $State.Rng.Next(0, 100)
    if ($roll -lt 40 -and $State.Food -gt 0) {
        $amount = [math]::Min($State.Food, $State.Rng.Next(20, 80))
        $State.Food -= $amount
        return "A thief came in the night and stole $amount pounds of food."
    }
    if ($roll -lt 70 -and $State.Bullets -gt 0) {
        $amount = [math]::Min($State.Bullets, $State.Rng.Next(20, 100))
        $State.Bullets -= $amount
        return "A thief came in the night and stole $amount bullets."
    }
    if ($State.Oxen -gt 1) {
        $State.Oxen--
        return 'A thief came in the night and stole an ox.'
    }
    return 'A thief came in the night but found nothing worth taking.'
}

function Invoke-FireEvent {
    param($State)
    $foodLost = [math]::Min($State.Food, $State.Rng.Next(10, 60))
    $State.Food -= $foodLost
    $bulletsLost = [math]::Min($State.Bullets, $State.Rng.Next(0, 60))
    $State.Bullets -= $bulletsLost
    Add-Health -State $State -Delta 2
    return "There was a fire in your wagon. You lost $foodLost pounds of food and $bulletsLost bullets."
}

function Invoke-LostTrailEvent {
    param($State)
    $lost = $State.Rng.Next(1, 5)
    $State.Date = $State.Date.AddDays($lost)
    $State.DaysOnTrail += $lost
    Add-Health -State $State -Delta 1
    return "You lost the trail. It took $lost days to find it again."
}

function Invoke-BadWaterEvent {
    param($State)
    Add-Health -State $State -Delta 4
    $victim = Get-RandomLivingMember -State $State
    if ($null -ne $victim -and [string]::IsNullOrEmpty($victim.Illness)) {
        $ail = @($script:OTIllnesses | Where-Object { $_.Key -eq 'Dysentery' })[0]
        Set-MemberIll -State $State -Member $victim -Ailment $ail
        return "You drank bad water. $($victim.Name) has come down with dysentery."
    }
    return 'You drank bad water. The whole party feels worse for it.'
}

function Invoke-LittleWaterEvent {
    param($State)
    Add-Health -State $State -Delta 3
    $lost = $State.Rng.Next(1, 3)
    $State.Date = $State.Date.AddDays($lost)
    $State.DaysOnTrail += $lost
    return "There was very little water here. You lost $lost days searching for a spring."
}

function Invoke-HailEvent {
    param($State)
    $lost = $State.Rng.Next(1, 4)
    $State.Date = $State.Date.AddDays($lost)
    $State.DaysOnTrail += $lost
    $bulletsLost = [math]::Min($State.Bullets, $State.Rng.Next(0, 40))
    $State.Bullets -= $bulletsLost
    Add-Health -State $State -Delta 2
    return "A violent hail storm struck the wagon. You lost $lost days and $bulletsLost bullets."
}

function Invoke-WildAnimalEvent {
    param($State)
    if ($State.Bullets -lt 20) {
        $victim = Get-RandomLivingMember -State $State
        if ($null -ne $victim) {
            Add-Health -State $State -Delta 5
            return "Wild animals attacked! You had too little ammunition to drive them off, and $($victim.Name) was hurt."
        }
    }
    $used = [math]::Min($State.Bullets, $State.Rng.Next(20, 60))
    $State.Bullets -= $used
    $meat = $State.Rng.Next(20, 60)
    $State.Food += $meat
    return "Wild animals attacked! You fired $used bullets driving them off, and gained $meat pounds of meat."
}

function Invoke-SnakeBiteEvent {
    param($State)
    $victim = Get-RandomLivingMember -State $State
    if ($null -eq $victim) { return 'A rattlesnake startled the oxen.' }
    $ail = @($script:OTInjuries | Where-Object { $_.Key -eq 'SnakeBite' })[0]
    Set-MemberIll -State $State -Member $victim -Ailment $ail
    return "$($victim.Name) was bitten by a rattlesnake."
}

function Invoke-InjuryEvent {
    param($State)
    $victim = Get-RandomLivingMember -State $State
    if ($null -eq $victim) { return 'The trail was rough today.' }
    $inj = $script:OTInjuries[$State.Rng.Next(0, 2)]
    Set-MemberIll -State $State -Member $victim -Ailment $inj
    $lost = $State.Rng.Next(1, 4)
    $State.Date = $State.Date.AddDays($lost)
    $State.DaysOnTrail += $lost
    return "$($victim.Name) has $($inj.Name). You lost $lost days."
}

function Invoke-RoughTrailEvent {
    param($State)
    Add-Health -State $State -Delta 3
    return 'The trail was very rough today. Everyone is worn out.'
}

function Invoke-WildFruitEvent {
    param($State)
    $amount = $State.Rng.Next(15, 60)
    $State.Food += $amount
    return "You found wild fruit growing near the trail and gathered $amount pounds."
}

function Invoke-AbandonedWagonEvent {
    param($State)
    $msg = 'You found an abandoned wagon beside the trail.'
    $roll = $State.Rng.Next(0, 100)
    if ($roll -lt 35) {
        $amount = $State.Rng.Next(20, 80)
        $State.Food += $amount
        return "$msg It held $amount pounds of food."
    }
    if ($roll -lt 65) {
        $amount = $State.Rng.Next(20, 100)
        $State.Bullets += $amount
        return "$msg It held $amount bullets."
    }
    if ($roll -lt 85) {
        $State.Wheels++
        return "$msg You salvaged a spare wagon wheel."
    }
    $sets = $State.Rng.Next(1, 4)
    $State.Clothing += $sets
    return "$msg You salvaged $sets sets of clothing."
}

function Invoke-HelpfulStrangersEvent {
    param($State)
    $roll = $State.Rng.Next(0, 100)
    if ($roll -lt 50) {
        $amount = $State.Rng.Next(20, 70)
        $State.Food += $amount
        return "You met friendly travelers who shared $amount pounds of food with you."
    }
    if ($State.Health -gt 0) {
        Add-Health -State $State -Delta -5
        return 'You met a doctor traveling east who treated your party. Everyone feels better.'
    }
    return 'You met friendly travelers on the trail. Their news lifted your spirits.'
}

function Invoke-HeavyFogEvent {
    param($State)
    $lost = $State.Rng.Next(1, 4)
    $State.Date = $State.Date.AddDays($lost)
    $State.DaysOnTrail += $lost
    return "Heavy fog settled over the trail. You lost $lost days."
}

function Invoke-InadequateGrassEvent {
    param($State)
    if ($State.Oxen -gt 1 -and $State.Rng.Next(0, 100) -lt 40) {
        $State.Oxen--
        return 'There was inadequate grass here. One of your oxen weakened and died.'
    }
    $lost = $State.Rng.Next(1, 3)
    $State.Date = $State.Date.AddDays($lost)
    $State.DaysOnTrail += $lost
    return "There was inadequate grass for the oxen. You lost $lost days finding better pasture."
}

$script:OTTrailEvents = @(
    @{ Key = 'Breakdown';   Weight = 10; Good = $false; Handler = 'Invoke-BreakdownEvent' }
    @{ Key = 'Ox';          Weight = 9;  Good = $false; Handler = 'Invoke-OxEvent' }
    @{ Key = 'Theft';       Weight = 6;  Good = $false; Handler = 'Invoke-TheftEvent' }
    @{ Key = 'Fire';        Weight = 4;  Good = $false; Handler = 'Invoke-FireEvent' }
    @{ Key = 'LostTrail';   Weight = 7;  Good = $false; Handler = 'Invoke-LostTrailEvent' }
    @{ Key = 'BadWater';    Weight = 6;  Good = $false; Handler = 'Invoke-BadWaterEvent' }
    @{ Key = 'LittleWater'; Weight = 5;  Good = $false; Handler = 'Invoke-LittleWaterEvent' }
    @{ Key = 'Hail';        Weight = 5;  Good = $false; Handler = 'Invoke-HailEvent' }
    @{ Key = 'WildAnimals'; Weight = 5;  Good = $false; Handler = 'Invoke-WildAnimalEvent' }
    @{ Key = 'SnakeBite';   Weight = 4;  Good = $false; Handler = 'Invoke-SnakeBiteEvent' }
    @{ Key = 'Injury';      Weight = 5;  Good = $false; Handler = 'Invoke-InjuryEvent' }
    @{ Key = 'RoughTrail';  Weight = 6;  Good = $false; Handler = 'Invoke-RoughTrailEvent' }
    @{ Key = 'Fog';         Weight = 4;  Good = $false; Handler = 'Invoke-HeavyFogEvent' }
    @{ Key = 'NoGrass';     Weight = 5;  Good = $false; Handler = 'Invoke-InadequateGrassEvent' }
    @{ Key = 'WildFruit';   Weight = 6;  Good = $true;  Handler = 'Invoke-WildFruitEvent' }
    @{ Key = 'Abandoned';   Weight = 5;  Good = $true;  Handler = 'Invoke-AbandonedWagonEvent' }
    @{ Key = 'Strangers';   Weight = 5;  Good = $true;  Handler = 'Invoke-HelpfulStrangersEvent' }
)

function Get-EventTotalWeight {
    $total = 0
    foreach ($e in $script:OTTrailEvents) { $total += $e.Weight }
    return $total
}

function Select-RandomEvent {
    param($State)
    $total = Get-EventTotalWeight
    $roll = $State.Rng.Next(0, $total)
    $acc = 0
    foreach ($e in $script:OTTrailEvents) {
        $acc += $e.Weight
        if ($roll -lt $acc) { return $e }
    }
    return $script:OTTrailEvents[0]
}

function Invoke-RandomEvent {
    param($State, [int]$ChancePercent = 13)
    if ($State.Rng.Next(0, 100) -ge $ChancePercent) { return $null }
    $evt = Select-RandomEvent -State $State
    $message = & $evt.Handler -State $State
    Add-Journal -State $State -Text $message
    return @{ Key = $evt.Key; Good = $evt.Good; Message = $message }
}

function Show-EventMessage {
    param($Event)
    if ($null -eq $Event) { return }
    $title = 'BAD NEWS'
    $fg = Get-C 'Red'
    if ($Event.Good) {
        $title = 'GOOD NEWS'
        $fg = Get-C 'Green'
    }
    Show-Message -Text $Event.Message -Title $title -Left 20 -Top 10 -Width 60 -BorderFg $fg
}
