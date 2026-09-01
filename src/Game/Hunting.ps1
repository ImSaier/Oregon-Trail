$script:OTHuntSpecies = @(
    @{ Key = 'Squirrel'; Art = 'Squirrel'; Meat = 2;   Speed = 3; Weight = 30; Fg = 'Brown';     Points = 1; Drift = 2; Danger = 0 }
    @{ Key = 'Rabbit';   Art = 'Rabbit';   Meat = 3;   Speed = 3; Weight = 28; Fg = 'Silver';    Points = 1; Drift = 2; Danger = 0 }
    @{ Key = 'Deer';     Art = 'Deer';     Meat = 40;  Speed = 2; Weight = 24; Fg = 'Tan';       Points = 3; Drift = 1; Danger = 0 }
    @{ Key = 'Bear';     Art = 'Bear';     Meat = 80;  Speed = 2; Weight = 13;  Fg = 'DarkBrown'; Points = 5; Drift = 0; Danger = 1 }
    @{ Key = 'Buffalo';  Art = 'Buffalo';  Meat = 200; Speed = 2; Weight = 9;  Fg = 'DarkBrown'; Points = 8; Drift = 0; Danger = 0 }
)

$script:OTHuntTop = 4
$script:OTHuntBottom = 25
$script:OTHuntCarryLimit = 100
$script:OTHuntDurationFrames = 260
$script:OTHuntFps = 20
$script:OTHuntReloadFrames = 10
$script:OTHuntBulletSpeedX = 3
$script:OTHuntBulletSpeedY = 1
$script:OTHuntMaxAnimals = 5
$script:OTHuntBulletRange = 40
$script:OTHuntHitTolerance = 2
$script:OTHuntSpawnMin = 12
$script:OTHuntSpawnMax = 28

function Get-HuntSpeciesTotalWeight {
    $t = 0
    foreach ($s in $script:OTHuntSpecies) { $t += $s.Weight }
    return $t
}

function Select-HuntSpecies {
    param($Rng)
    $total = Get-HuntSpeciesTotalWeight
    $roll = $Rng.Next(0, $total)
    $acc = 0
    foreach ($s in $script:OTHuntSpecies) {
        $acc += $s.Weight
        if ($roll -lt $acc) { return $s }
    }
    return $script:OTHuntSpecies[0]
}

function New-HuntAnimal {
    param($Rng)
    $sp = Select-HuntSpecies -Rng $Rng
    $art = Get-Art -Name $sp.Art
    $h = $art.Count
    $w = Get-ArtWidth -Lines $art
    $fromLeft = ($Rng.Next(0, 2) -eq 0)
    $x = -$w
    $dx = $sp.Speed
    if (-not $fromLeft) {
        $x = 100
        $dx = -$sp.Speed
    }
    $y = $Rng.Next($script:OTHuntTop + 1, $script:OTHuntBottom - $h)
    return @{
        Species = $sp
        Art     = $art
        X       = [double]$x
        Y       = $y
        W       = $w
        H       = $h
        DX      = $dx
        DY      = 0
        DriftTimer = $Rng.Next(6, 18)
        Startled = $false
        Alive   = $true
        Flash   = 0
    }
}

function Test-BulletHit {
    param($Bullet, $Animal)
    if (-not $Animal.Alive) { return $false }
    $ax = [int][math]::Round($Animal.X)
    $col = $Bullet.X - $ax
    $row = $Bullet.Y - $Animal.Y
    if ($row -lt 0 -or $row -ge $Animal.H) { return $false }
    $line = $Animal.Art[$row]
    if ($null -eq $line -or $line.Length -eq 0) { return $false }
    $tol = $script:OTHuntHitTolerance
    if ($col -lt (-$tol) -or $col -ge ($line.Length + $tol)) { return $false }
    for ($d = -$tol; $d -le $tol; $d++) {
        $c = $col + $d
        if ($c -lt 0 -or $c -ge $line.Length) { continue }
        if ($line[$c] -ne ' ') { return $true }
    }
    return $false
}

function Test-BulletNearMiss {
    param($Bullet, $Animal)
    if (-not $Animal.Alive) { return $false }
    $ax = [int][math]::Round($Animal.X)
    if ($Bullet.X -lt ($ax - 6) -or $Bullet.X -gt ($ax + $Animal.W + 6)) { return $false }
    if ($Bullet.Y -lt ($Animal.Y - 3) -or $Bullet.Y -gt ($Animal.Y + $Animal.H + 3)) { return $false }
    return $true
}

function Set-AnimalStartled {
    param($Animal, $Rng, [int]$AwayFromX = -1)
    if ($Animal.Startled) { return }
    $Animal.Startled = $true
    $sign = 1
    if ($Animal.DX -lt 0) { $sign = -1 }
    if ($AwayFromX -ge 0) {
        if ($Animal.X -lt $AwayFromX) { $sign = -1 } else { $sign = 1 }
    }
    $Animal.DX = $sign * ([math]::Abs($Animal.DX) + 1)
    if ($Animal.Species.Drift -gt 0) { $Animal.DriftTimer = 0 }
}

function Draw-HuntScene {
    param($Hunter, $Animals, $Bullets, [int]$Ammo, [int]$Bagged, [int]$FramesLeft, [string]$Flash, [int]$Reloading = 0)
    Clear-Buffer
    Write-BufferTextCentered -Y 1 -Text 'HUNTING' -Fg (Get-C 'Gold')
    Draw-Rule -Y 2 -Left 0 -Width 100 -Plain
    $grass = New-Object System.String -ArgumentList ([char]0x2591), 100
    Write-BufferText -X 0 -Y $script:OTHuntTop -Text $grass -Fg (Get-C 'DarkGreen')
    Write-BufferText -X 0 -Y $script:OTHuntBottom -Text $grass -Fg (Get-C 'DarkGreen')
    foreach ($a in $Animals) {
        if (-not $a.Alive) { continue }
        $fg = Get-C $a.Species.Fg
        if ($a.Flash -gt 0) { $fg = Get-C 'Red' }
        Write-BufferArt -X ([int][math]::Round($a.X)) -Y $a.Y -Lines $a.Art -Fg $fg -Transparent
    }
    foreach ($b in $Bullets) {
        Set-BufferCell -X $b.X -Y $b.Y -Char ([char]0x2022) -Fg (Get-C 'Yellow')
    }
    Write-BufferArt -X $Hunter.X -Y $Hunter.Y -Lines (Get-Art 'Hunter') -Fg (Get-C 'White') -Transparent
    Draw-Rule -Y 26 -Left 0 -Width 100 -Plain
    Write-BufferText -X 2 -Y 27 -Text ('AMMO: ' + $Ammo) -Fg (Get-C 'Silver')
    if ($Reloading -gt 0) {
        Write-BufferText -X 15 -Y 27 -Text 'RELOADING' -Fg (Get-C 'Red')
    }
    else {
        Write-BufferText -X 15 -Y 27 -Text 'READY' -Fg (Get-C 'Green')
    }
    Write-BufferText -X 27 -Y 27 -Text ('BAGGED: ' + $Bagged + ' lbs') -Fg (Get-C 'Tan')
    $secs = [math]::Ceiling($FramesLeft / $script:OTHuntFps)
    Write-BufferText -X 48 -Y 27 -Text ('TIME: ' + $secs + 's') -Fg (Get-C 'Amber')
    Write-BufferText -X 62 -Y 27 -Text 'WASD move  SPACE fire' -Fg (Get-C 'DarkGrey')
    if ($Flash.Length -gt 0) {
        Write-BufferTextCentered -Y 1 -Text $Flash -Fg (Get-C 'Green')
    }
}

function Invoke-Hunt {
    param($State)
    if ($State.Bullets -lt 1) {
        Show-Message -Text 'You have no bullets. You cannot hunt.' -Title 'HUNTING' -Left 24 -Top 11 -Width 52 -BorderFg (Get-C 'Red')
        return
    }
    $result = Start-HuntSimulation -State $State
    $days = 1
    $State.Date = $State.Date.AddDays($days)
    $State.DaysOnTrail += $days
    $carried = [math]::Min($result.Bagged, $script:OTHuntCarryLimit)
    $State.Food += $carried
    if ($result.Mauled) {
        $extra = 2
        $State.Date = $State.Date.AddDays($extra)
        $State.DaysOnTrail += $extra
        Add-Health -State $State -Delta 8
        $victim = Get-RandomLivingMember -State $State
        $who = 'You were'
        if ($null -ne $victim) { $who = $victim.Name + ' was' }
        $text = "A bear charged out of the brush. $who badly clawed getting away from it. You lost $extra days and came back with $carried pounds of meat."
        Show-Message -Text $text -Title 'MAULED' -Left 20 -Top 11 -Width 60 -BorderFg (Get-C 'Blood')
        Add-Journal -State $State -Text 'Mauled by a bear while hunting.'
        return
    }
    if ($result.Bagged -le 0) {
        Show-Message -Text ("You hunted for a day and fired " + $result.Shots + " shots, but came back empty handed.") -Title 'HUNTING' -Left 22 -Top 11 -Width 56 -BorderFg (Get-C 'Red')
        Add-Journal -State $State -Text 'Hunted and came back empty handed.'
        return
    }
    $text = "You shot " + $result.Bagged + " pounds of meat"
    if ($result.Bagged -gt $script:OTHuntCarryLimit) {
        $text += ", but you were only able to carry " + $carried + " pounds back to the wagon."
    }
    else {
        $text += " and carried all of it back to the wagon."
    }
    Show-Message -Text $text -Title 'HUNTING' -Left 22 -Top 11 -Width 56 -BorderFg (Get-C 'Green')
    Add-Journal -State $State -Text "Hunted and brought back $carried pounds of meat."
}

function Start-HuntSimulation {
    param($State)
    $rng = $State.Rng
    $hunter = @{ X = 48; Y = 14; Facing = 'Right' }
    $animals = New-Object System.Collections.ArrayList
    $bullets = New-Object System.Collections.ArrayList
    $ammo = $State.Bullets
    $bagged = 0
    $shots = 0
    $cooldown = 0
    $flash = ''
    $flashTimer = 0
    $spawnTimer = 0
    $framesLeft = $script:OTHuntDurationFrames
    $mauled = $false
    $maxAnimals = $script:OTHuntMaxAnimals
    $clock = New-FrameClock -Fps $script:OTHuntFps

    while ($framesLeft -gt 0 -and $ammo -gt 0) {
        $keys = New-Object System.Collections.ArrayList
        while ($true) {
            $k = Read-GameKeyIfAvailable
            if ($null -eq $k) { break }
            [void]$keys.Add($k)
            if ($keys.Count -gt 8) { break }
        }
        $quit = $false
        foreach ($k in $keys) {
            if ($k.Key -eq 'Escape' -or $k.Key -eq 'CtrlC') { $quit = $true; break }
            $dir = Get-NormalizedDirection $k
            if ($dir -eq 'Left')  { $hunter.X -= 2; $hunter.Facing = 'Left' }
            elseif ($dir -eq 'Right') { $hunter.X += 2; $hunter.Facing = 'Right' }
            elseif ($dir -eq 'Up')    { $hunter.Y -= 1; $hunter.Facing = 'Up' }
            elseif ($dir -eq 'Down')  { $hunter.Y += 1; $hunter.Facing = 'Down' }
            elseif ($k.Key -eq 'Space' -and $cooldown -le 0 -and $ammo -gt 0) {
                $bx = $hunter.X + 1
                $by = $hunter.Y + 1
                $dx = 0
                $dy = 0
                switch ($hunter.Facing) {
                    'Left'  { $dx = -$script:OTHuntBulletSpeedX }
                    'Right' { $dx = $script:OTHuntBulletSpeedX }
                    'Up'    { $dy = -$script:OTHuntBulletSpeedY }
                    'Down'  { $dy = $script:OTHuntBulletSpeedY }
                }
                [void]$bullets.Add(@{ X = $bx; Y = $by; DX = $dx; DY = $dy; Dist = 0 })
                $ammo--
                $shots++
                $cooldown = $script:OTHuntReloadFrames
            }
        }
        if ($quit) { break }
        if ($hunter.X -lt 0) { $hunter.X = 0 }
        if ($hunter.X -gt 96) { $hunter.X = 96 }
        if ($hunter.Y -lt ($script:OTHuntTop + 1)) { $hunter.Y = $script:OTHuntTop + 1 }
        if ($hunter.Y -gt ($script:OTHuntBottom - 3)) { $hunter.Y = $script:OTHuntBottom - 3 }
        if ($cooldown -gt 0) { $cooldown-- }

        $spawnTimer--
        if ($spawnTimer -le 0 -and $animals.Count -lt $maxAnimals) {
            [void]$animals.Add((New-HuntAnimal -Rng $rng))
            $spawnTimer = $rng.Next($script:OTHuntSpawnMin, $script:OTHuntSpawnMax)
        }

        foreach ($a in $animals) {
            if (-not $a.Alive) { continue }
            $a.X += $a.DX
            if ($a.Species.Drift -gt 0) {
                $a.DriftTimer--
                if ($a.DriftTimer -le 0) {
                    $a.DY = $rng.Next(-1, 2)
                    $a.DriftTimer = $rng.Next(5, 14)
                }
                $ny = $a.Y + $a.DY
                if ($ny -gt ($script:OTHuntTop + 1) -and $ny -lt ($script:OTHuntBottom - $a.H)) { $a.Y = $ny }
            }
            if ($a.Flash -gt 0) { $a.Flash-- }
        }

        $deadBullets = New-Object System.Collections.ArrayList
        foreach ($b in $bullets) {
            $b.X += $b.DX
            $b.Y += $b.DY
            $b.Dist += ([math]::Abs($b.DX) + [math]::Abs($b.DY))
            $hitSomething = $false
            foreach ($a in $animals) {
                if ($a.Alive -and (Test-BulletNearMiss -Bullet $b -Animal $a)) {
                    Set-AnimalStartled -Animal $a -Rng $rng -AwayFromX $hunter.X
                }
                if (Test-BulletHit -Bullet $b -Animal $a) {
                    $a.Alive = $false
                    $a.Flash = 3
                    $bagged += $a.Species.Meat
                    $flash = 'You shot a ' + $a.Species.Key.ToLower() + '!'
                    $flashTimer = 20
                    $hitSomething = $true
                    break
                }
            }
            if ($hitSomething -or $b.Dist -ge $script:OTHuntBulletRange -or $b.X -lt 0 -or $b.X -ge 100 -or $b.Y -le $script:OTHuntTop -or $b.Y -ge $script:OTHuntBottom) {
                [void]$deadBullets.Add($b)
            }
        }
        foreach ($b in $deadBullets) { [void]$bullets.Remove($b) }

        $gone = New-Object System.Collections.ArrayList
        foreach ($a in $animals) {
            if (-not $a.Alive -and $a.Flash -le 0) { [void]$gone.Add($a); continue }
            if ($a.X -lt (-$a.W - 2) -or $a.X -gt 102) { [void]$gone.Add($a) }
        }
        foreach ($a in $gone) { [void]$animals.Remove($a) }

        foreach ($a in $animals) {
            if (-not $a.Alive -or $a.Species.Danger -le 0) { continue }
            $ax = [int][math]::Round($a.X)
            if ($ax -lt ($hunter.X + 4) -and ($ax + $a.W) -gt ($hunter.X - 1) -and
                $a.Y -lt ($hunter.Y + 3) -and ($a.Y + $a.H) -gt ($hunter.Y - 1)) {
                $mauled = $true
                break
            }
        }
        if ($mauled) { break }
        if ($flashTimer -gt 0) { $flashTimer-- } else { $flash = '' }

        Draw-HuntScene -Hunter $hunter -Animals $animals -Bullets $bullets -Ammo $ammo -Bagged $bagged -FramesLeft $framesLeft -Flash $flash -Reloading $cooldown
        [void](Render-Frame)
        [void](Step-FrameClock -Clock $clock)
        $framesLeft--
    }

    $State.Bullets = $ammo
    return @{ Bagged = $bagged; Shots = $shots; AmmoLeft = $ammo; Mauled = $mauled }
}
