$script:OTLandmarks = @(
    @{ Name = 'Independence';           Short = 'Independence';      Miles = 0;    Type = 'Start' }
    @{ Name = 'Kansas River Crossing';  Short = 'Kansas River';      Miles = 102;  Type = 'River'; RiverWidth = 620;  RiverDepth = 4.0;  FerryCost = 5.0;  FerryDays = 2 }
    @{ Name = 'Big Blue River Crossing'; Short = 'Big Blue River';   Miles = 185;  Type = 'River'; RiverWidth = 220;  RiverDepth = 3.0 }
    @{ Name = 'Fort Kearney';           Short = 'Fort Kearney';      Miles = 304;  Type = 'Fort'; PriceFactor = 1.5 }
    @{ Name = 'Chimney Rock';           Short = 'Chimney Rock';      Miles = 554;  Type = 'Landmark' }
    @{ Name = 'Fort Laramie';           Short = 'Fort Laramie';      Miles = 640;  Type = 'Fort'; PriceFactor = 1.7 }
    @{ Name = 'Independence Rock';      Short = 'Independence Rock'; Miles = 830;  Type = 'Landmark' }
    @{ Name = 'South Pass';             Short = 'South Pass';        Miles = 932;  Type = 'Landmark'; Mountain = $true }
    @{ Name = 'Fort Bridger';           Short = 'Fort Bridger';      Miles = 989;  Type = 'Fort'; PriceFactor = 2.0; Mountain = $true }
    @{ Name = 'Green River Crossing';   Short = 'Green River';       Miles = 1086; Type = 'River'; RiverWidth = 400; RiverDepth = 8.0; FerryCost = 5.0; FerryDays = 3; Mountain = $true }
    @{ Name = 'Soda Springs';           Short = 'Soda Springs';      Miles = 1215; Type = 'Landmark'; Mountain = $true }
    @{ Name = 'Fort Hall';              Short = 'Fort Hall';         Miles = 1295; Type = 'Fort'; PriceFactor = 2.2; Mountain = $true }
    @{ Name = 'Snake River Crossing';   Short = 'Snake River';       Miles = 1454; Type = 'River'; RiverWidth = 1000; RiverDepth = 5.0; FerryCost = 0; Mountain = $true }
    @{ Name = 'Fort Boise';             Short = 'Fort Boise';        Miles = 1543; Type = 'Fort'; PriceFactor = 2.4; Mountain = $true }
    @{ Name = 'Blue Mountains';         Short = 'Blue Mountains';    Miles = 1648; Type = 'Landmark'; Mountain = $true }
    @{ Name = 'Fort Walla Walla';       Short = 'Fort Walla Walla';  Miles = 1799; Type = 'Fort'; PriceFactor = 2.6; Mountain = $true }
    @{ Name = 'The Dalles';             Short = 'The Dalles';        Miles = 1863; Type = 'Landmark'; Mountain = $true }
    @{ Name = 'Willamette Valley';      Short = 'Willamette Valley'; Miles = 1963; Type = 'End' }
)

$script:OTTrailLength = 1963

function Get-Landmark {
    param([int]$Index)
    if ($Index -lt 0 -or $Index -ge $script:OTLandmarks.Count) { return $null }
    return $script:OTLandmarks[$Index]
}

function Get-NextLandmark {
    param($State)
    return Get-Landmark -Index ($State.LandmarkIndex + 1)
}

function Get-CurrentLandmark {
    param($State)
    return Get-Landmark -Index $State.LandmarkIndex
}

function Get-MilesToNextLandmark {
    param($State)
    $next = Get-NextLandmark -State $State
    if ($null -eq $next) { return 0 }
    return [math]::Max(0, $next.Miles - $State.Miles)
}

function Test-AtLandmark {
    param($State)
    $cur = Get-CurrentLandmark -State $State
    if ($null -eq $cur) { return $false }
    return ($State.Miles -le $cur.Miles)
}

function Test-InMountains {
    param($State)
    $cur = Get-CurrentLandmark -State $State
    if ($null -eq $cur) { return $false }
    return [bool]$cur.Mountain
}

function Get-LandmarkDescription {
    param($Landmark)
    switch ($Landmark.Short) {
        'Independence'      { return "Independence, Missouri is the jumping off place for the Oregon Trail. Wagons gather here each spring to form trains bound for the west." }
        'Kansas River'      { return "The Kansas River is the first major crossing on the trail. It is $($Landmark.RiverWidth) feet across and runs faster than it looks." }
        'Big Blue River'    { return "The Big Blue River is narrower than the Kansas, but its banks are steep and its bed is soft." }
        'Fort Kearney'      { return "Fort Kearney was built to protect travelers along the Platte River road. Supplies here cost more than in Independence." }
        'Chimney Rock'      { return "Chimney Rock rises nearly 300 feet above the North Platte valley. Emigrants can see it for two days before they reach it, and two days after." }
        'Fort Laramie'      { return "Fort Laramie sits at the confluence of the Laramie and North Platte rivers. It is the last good place to repair a wagon before the mountains." }
        'Independence Rock' { return "Independence Rock is a great granite dome covered in the carved names of emigrants. Reaching it by the fourth of July means you are on schedule." }
        'South Pass'        { return "South Pass is a broad, gentle saddle over the Continental Divide. From here the waters run west to the Pacific." }
        'Fort Bridger'      { return "Fort Bridger was built by the mountain man Jim Bridger as a trading post for emigrants. Prices are steep this far out." }
        'Green River'       { return "The Green River is deep, cold and swift. It is one of the most dangerous crossings on the whole trail." }
        'Soda Springs'      { return "Soda Springs bubbles with naturally carbonated water. Emigrants stop to taste it and to rest their teams." }
        'Fort Hall'         { return "Fort Hall is a Hudson's Bay Company post on the Snake River plain. Here the California Trail branches south." }
        'Snake River'       { return "The Snake River crossing is wide and treacherous. Many wagons have been lost in its current." }
        'Fort Boise'        { return "Fort Boise offers the last resupply before the Blue Mountains. Beyond lies the hardest country on the trail." }
        'Blue Mountains'    { return "The Blue Mountains are steep, timbered and cruel to worn out oxen. Snow closes them early." }
        'Fort Walla Walla'  { return "Fort Walla Walla stands near the Columbia River. The end of the journey is close, but the river ahead is not kind." }
        'The Dalles'        { return "At The Dalles the trail ends and the Columbia River begins. You must raft the rapids or pay the toll for the Barlow Road." }
        'Willamette Valley' { return "The Willamette Valley. Green, wide and yours. You have reached Oregon." }
    }
    return ''
}

function Draw-MapScreen {
    param($State)
    Clear-Buffer
    Draw-Panel -Left 2 -Top 2 -Width 96 -Height 21 -Title 'THE OREGON TRAIL' -Fg (Get-C 'Gold') -Style 'Double'
    $col1 = 5
    $col2 = 51
    $half = [math]::Ceiling($script:OTLandmarks.Count / 2)
    for ($i = 0; $i -lt $script:OTLandmarks.Count; $i++) {
        $lm = $script:OTLandmarks[$i]
        $x = $col1
        $y = 5 + $i
        if ($i -ge $half) {
            $x = $col2
            $y = 5 + ($i - $half)
        }
        $marker = '  '
        $fg = Get-C 'DarkGrey'
        if ($i -lt $State.LandmarkIndex) {
            $marker = [string]$script:OTGlyph.Dot + ' '
            $fg = Get-C 'DarkGreen'
        }
        elseif ($i -eq $State.LandmarkIndex) {
            $marker = [string]$script:OTGlyph.Arrow + ' '
            $fg = Get-C 'Gold'
        }
        $typeFg = $fg
        if ($i -gt $State.LandmarkIndex) {
            if ($lm.Type -eq 'River') { $typeFg = Get-C 'DeepRiver' }
            elseif ($lm.Type -eq 'Fort') { $typeFg = Get-C 'DarkBrown' }
        }
        Write-BufferText -X $x -Y $y -Text ($marker + $lm.Short) -Fg $typeFg
        Write-BufferText -X ($x + 30) -Y $y -Text ((Format-Number $lm.Miles).PadLeft(5)) -Fg $fg
    }
    Draw-Rule -Y 16 -Left 2 -Width 96
    $pct = [math]::Round(($State.Miles / $script:OTTrailLength) * 100)
    Write-BufferText -X 5 -Y 18 -Text ('Miles traveled: ' + (Format-Number $State.Miles) + ' of ' + (Format-Number $script:OTTrailLength)) -Fg (Get-C 'White')
    Draw-Gauge -Left 45 -Top 18 -Width 40 -Value $State.Miles -Max $script:OTTrailLength -Fg (Get-C 'Gold')
    Write-BufferText -X 87 -Y 18 -Text ("$pct%") -Fg (Get-C 'White')
    Write-BufferTextCentered -Y 20 -Text 'Press SPACE BAR to continue' -Fg (Get-C 'DarkGrey')
    Write-BufferTextCentered -Y 25 -Text 'The Oregon Trail  -  Independence, Missouri to the Willamette Valley' -Fg (Get-C 'DarkGrey')
}

function Show-MapScreen {
    param($State)
    Draw-MapScreen -State $State
    [void](Render-Frame)
    Wait-ForContinue
}

function Show-LandmarkArrival {
    param($State, $Landmark)
    Clear-Buffer
    $fg = Get-C 'Gold'
    Write-BufferTextCentered -Y 2 -Text 'YOU HAVE REACHED' -Fg (Get-C 'Grey')
    Write-BufferTextCentered -Y 4 -Text $Landmark.Name.ToUpper() -Fg $fg
    switch ($Landmark.Type) {
        'Fort'  { Draw-Art -Name 'Fort' -Left 0 -Top 7 -Fg (Get-C 'Wood') -Centered }
        'River' { Write-BufferArt -X 0 -Y 9 -Lines (Get-RiverArt) -Fg (Get-C 'River') }
        default { Write-BufferArt -X 22 -Y 7 -Lines (Get-Art 'Mountains') -Fg (Get-C 'Mountain') }
    }
    $desc = Get-LandmarkDescription -Landmark $Landmark
    $lines = Get-WrappedLines -Text $desc -Width 76
    for ($i = 0; $i -lt $lines.Count; $i++) {
        Write-BufferTextCentered -Y (15 + $i) -Text $lines[$i] -Fg (Get-C 'White')
    }
    Write-BufferTextCentered -Y 21 -Text ((Format-Number $State.Miles) + ' miles from Independence') -Fg (Get-C 'Tan')
    Write-BufferTextCentered -Y 22 -Text (Get-TrailDateString -State $State) -Fg (Get-C 'Tan')
    Write-BufferTextCentered -Y 25 -Text 'Press SPACE BAR to continue' -Fg (Get-C 'DarkGrey')
    [void](Render-Frame)
    Wait-ForContinue
}

function Get-RiverArt {
    $w = [char]0x2248
    $rows = New-Object System.Collections.ArrayList
    for ($r = 0; $r -lt 4; $r++) {
        [void]$rows.Add((New-Object System.String -ArgumentList $w, 100))
    }
    return ,$rows.ToArray()
}
