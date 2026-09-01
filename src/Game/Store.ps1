$script:OTStoreItems = @(
    @{ Key = 'Oxen';     Label = 'Oxen';                 Unit = 'yoke';   Plural = 'yoke';    Price = 40.0;  Field = 'Oxen';     PerUnit = 2
       Advice = "You'll need at least 3 yoke of oxen to pull your wagon. Any less and you'll be in trouble before you reach the Kansas River." }
    @{ Key = 'Food';     Label = 'Food';                 Unit = 'pound';  Plural = 'pounds';  Price = 0.20;  Field = 'Food';     PerUnit = 1
       Advice = "I'd recommend taking at least 200 pounds of food per person. You can always hunt for more along the way." }
    @{ Key = 'Clothing'; Label = 'Clothing';             Unit = 'set';    Plural = 'sets';    Price = 10.0;  Field = 'Clothing'; PerUnit = 1
       Advice = "You'll need warm clothing when you hit the mountains. I'd recommend at least 2 sets per person." }
    @{ Key = 'Bullets';  Label = 'Ammunition';           Unit = 'box';    Plural = 'boxes';   Price = 2.0;   Field = 'Bullets';  PerUnit = 20
       Advice = "Ammunition is `$2 for a box of 20 bullets. You'll want plenty for hunting and for trouble." }
    @{ Key = 'Wheels';   Label = 'Spare wagon wheels';   Unit = 'wheel';  Plural = 'wheels';  Price = 10.0;  Field = 'Wheels';   PerUnit = 1
       Advice = "A broken wheel will stop you cold. I'd take 2 or 3 spares." }
    @{ Key = 'Axles';    Label = 'Spare wagon axles';    Unit = 'axle';   Plural = 'axles';   Price = 10.0;  Field = 'Axles';    PerUnit = 1
       Advice = "Axles snap on rough trail. I'd take 2 or 3 spares." }
    @{ Key = 'Tongues';  Label = 'Spare wagon tongues';  Unit = 'tongue'; Plural = 'tongues'; Price = 10.0;  Field = 'Tongues';  PerUnit = 1
       Advice = "A cracked tongue means your oxen can't pull. I'd take 2 or 3 spares." }
)

$script:OTStorePriceFactor = 1.0
$script:OTStoreLocation = 'Independence, Missouri'

function Get-ItemPrice {
    param($Item)
    return [math]::Round($Item.Price * $script:OTStorePriceFactor, 2)
}

function Get-UnitLabel {
    param($Item, [int]$Count = 2)
    if ($Count -eq 1) { return $Item.Unit }
    if (-not [string]::IsNullOrEmpty($Item.Plural)) { return $Item.Plural }
    return ($Item.Unit + 's')
}

function Get-BuyPrompt {
    param($Item)
    $units = Get-UnitLabel -Item $Item
    $label = $Item.Label.ToLower()
    if ($label.EndsWith($units)) { return "How many $label`?" }
    return "How many $units of $label`?"
}

function Get-StoreQuantityText {
    param($State, $Item)
    $v = $State[$Item.Field]
    switch ($Item.Key) {
        'Oxen'     { return "$v oxen" }
        'Food'     { return "$(Format-Number $v) lbs" }
        'Clothing' { if ($v -eq 1) { return '1 set' } else { return "$v sets" } }
        'Bullets'  { return "$(Format-Number $v) bullets" }
        default    { return "$v" }
    }
}

function Format-StorePrice {
    param($Item)
    $amount = ('$' + (Get-ItemPrice -Item $Item).ToString('0.00')).PadLeft(7)
    return ($amount + ' per ' + $Item.Unit)
}

function Draw-StoreScreen {
    param($State, [int]$Selected, [string]$Note = '')
    Clear-Buffer
    $panelLeft = 3
    $panelWidth = 94
    $innerLeft = $panelLeft + 1
    $innerWidth = $panelWidth - 2
    $storeTitle = "MATT'S GENERAL STORE"
    if ($script:OTStorePriceFactor -ne 1.0) { $storeTitle = 'TRADING POST' }
    Draw-Panel -Left $panelLeft -Top 1 -Width $panelWidth -Height 24 -Title $storeTitle -Fg (Get-C 'Gold') -Style 'Double'
    Write-BufferText -X 6 -Y 3 -Text $script:OTStoreLocation -Fg (Get-C 'Tan')
    $dateText = Get-TrailDateString -State $State
    Write-BufferText -X (95 - $dateText.Length) -Y 3 -Text $dateText -Fg (Get-C 'Tan')
    $rule = New-Object System.String -ArgumentList ([char]0x2500), $innerWidth
    Draw-Rule -Y 4 -Left $panelLeft -Width $panelWidth -Rule $rule
    $y = 6
    for ($i = 0; $i -lt $script:OTStoreItems.Count; $i++) {
        $item = $script:OTStoreItems[$i]
        $fg = Get-C 'White'
        $marker = '  '
        if ($i -eq $Selected) {
            $marker = [string]$script:OTGlyph.Arrow + ' '
            $fg = Get-C 'Gold'
        }
        Write-BufferText -X 6 -Y $y -Text ($marker + ($i + 1).ToString() + '.') -Fg $fg
        Write-BufferText -X 11 -Y $y -Text $item.Label -Fg $fg
        Write-BufferText -X 44 -Y $y -Text (Format-StorePrice -Item $item) -Fg (Get-C 'Grey')
        Write-BufferText -X 72 -Y $y -Text (Get-StoreQuantityText -State $State -Item $item) -Fg (Get-C 'SkyBlue')
        $y++
    }
    $leaveFg = Get-C 'White'
    $leaveMark = '  '
    if ($Selected -eq $script:OTStoreItems.Count) {
        $leaveMark = [string]$script:OTGlyph.Arrow + ' '
        $leaveFg = Get-C 'Gold'
    }
    Write-BufferText -X 6 -Y 14 -Text ($leaveMark + '8. Leave the store') -Fg $leaveFg
    Draw-Rule -Y 15 -Left $panelLeft -Width $panelWidth -Rule $rule
    Write-BufferText -X 6 -Y 16 -Text ('Money left: ' + (Format-Money $State.Money)) -Fg (Get-C 'Green')
    Write-BufferText -X 40 -Y 16 -Text ('Wagon load: ' + (Format-Number (Get-WagonLoad -State $State)) + ' lbs') -Fg (Get-C 'Tan')
    if ($Note.Length -gt 0) {
        $noteLines = Get-WrappedLines -Text $Note -Width 86
        for ($i = 0; $i -lt $noteLines.Count -and $i -lt 3; $i++) {
            Write-BufferText -X 6 -Y (18 + $i) -Text $noteLines[$i] -Fg (Get-C 'Amber')
        }
    }
    Write-BufferTextCentered -Y 22 -Text 'Use number keys or arrows, then ENTER' -Fg (Get-C 'DarkGrey') -Left $panelLeft -Width $panelWidth
}

function Read-Quantity {
    param(
        [string]$Prompt,
        [double]$UnitPrice,
        [double]$Available,
        [int]$MaxUnits = 9999
    )
    while ($true) {
        $raw = Read-BufferedLine -Prompt $Prompt -Title 'HOW MANY?' -Left 22 -Top 10 -Width 56 -MaxLength 5 -AllowEmpty
        if ($null -eq $raw) { return -1 }
        $raw = $raw.Trim()
        if ($raw.Length -eq 0) { return 0 }
        $n = 0
        if (-not [int]::TryParse($raw, [ref]$n)) {
            Show-Message -Text 'Please enter a number.' -Title 'MATT SAYS' -Left 24 -Top 12 -Width 52 -BorderFg (Get-C 'Red')
            continue
        }
        if ($n -lt 0) {
            Show-Message -Text "You can't buy a negative amount." -Title 'MATT SAYS' -Left 24 -Top 12 -Width 52 -BorderFg (Get-C 'Red')
            continue
        }
        if ($n -gt $MaxUnits) {
            Show-Message -Text "I don't have that many to sell you." -Title 'MATT SAYS' -Left 24 -Top 12 -Width 52 -BorderFg (Get-C 'Red')
            continue
        }
        $cost = $n * $UnitPrice
        if ($cost -gt $Available) {
            Show-Message -Text ("You don't have enough money for that. It would cost " + (Format-Money $cost) + " and you have " + (Format-Money $Available) + '.') -Title 'MATT SAYS' -Left 22 -Top 12 -Width 56 -BorderFg (Get-C 'Red')
            continue
        }
        return $n
    }
}

function Show-StoreWelcome {
    $text = "Hello, I'm Matt. So you're going to Oregon! I can fix you up with what you need:`n`n" +
            "  - a team of oxen to pull your wagon`n" +
            "  - clothing for both summer and winter`n" +
            "  - plenty of food for the trip`n" +
            "  - ammunition for your rifles`n" +
            "  - spare parts for your wagon"
    Show-Message -Text $text -Title 'MATT S GENERAL STORE' -Left 16 -Top 5 -Width 68 -BorderFg (Get-C 'Gold')
}

function Test-StoreReadyToLeave {
    param($State)
    if ($State.Oxen -lt 2) {
        return "You can't leave Independence without at least one yoke of oxen to pull your wagon."
    }
    if ($State.Food -le 0) {
        return "You haven't bought any food. You'll starve before you reach the Kansas River. Are you sure?"
    }
    return ''
}

function Show-Store {
    param($State, [switch]$SkipWelcome, [double]$PriceFactor = 1.0, [string]$LocationName = 'Independence, Missouri')
    $script:OTStorePriceFactor = $PriceFactor
    $script:OTStoreLocation = $LocationName
    if (-not $SkipWelcome) { Show-StoreWelcome }
    $sel = 0
    $note = ''
    $itemCount = $script:OTStoreItems.Count
    while ($true) {
        Draw-StoreScreen -State $State -Selected $sel -Note $note
        [void](Render-Frame)
        $k = Read-GameKey
        if ($k.Key -eq 'CtrlC') { return $State }
        $dir = Get-NormalizedDirection $k
        if ($dir -eq 'Up') {
            $sel--
            if ($sel -lt 0) { $sel = $itemCount }
            continue
        }
        if ($dir -eq 'Down') {
            $sel++
            if ($sel -gt $itemCount) { $sel = 0 }
            continue
        }
        $chosen = -1
        if ($k.Key -match '^[1-8]$') { $chosen = [int]$k.Key - 1 }
        elseif ($k.Key -eq 'Enter' -or $k.Key -eq 'Space') { $chosen = $sel }
        if ($chosen -lt 0) { continue }
        if ($chosen -ge $itemCount) {
            if ($script:OTStorePriceFactor -ne 1.0) { return $State }
            $problem = Test-StoreReadyToLeave -State $State
            if ($problem.Length -gt 0) {
                if ($State.Oxen -lt 2) {
                    Show-Message -Text $problem -Title 'MATT SAYS' -Left 20 -Top 11 -Width 60 -BorderFg (Get-C 'Red')
                    continue
                }
                if (-not (Show-Confirm -Text $problem -Title 'MATT SAYS' -Left 20 -Top 10 -Width 60)) { continue }
            }
            return $State
        }
        $item = $script:OTStoreItems[$chosen]
        $sel = $chosen
        $note = $item.Advice
        Draw-StoreScreen -State $State -Selected $sel -Note $note
        [void](Render-Frame)
        $unitPrice = Get-ItemPrice -Item $item
        $maxAfford = [math]::Floor($State.Money / $unitPrice)
        $prompt = Get-BuyPrompt -Item $item
        $n = Read-Quantity -Prompt $prompt -UnitPrice $unitPrice -Available $State.Money -MaxUnits ([int]$maxAfford)
        if ($n -le 0) { continue }
        $cost = [math]::Round($n * $unitPrice, 2)
        $State.Money = [math]::Round($State.Money - $cost, 2)
        $State[$item.Field] = $State[$item.Field] + ($n * $item.PerUnit)
        $note = "You bought $n $(Get-UnitLabel -Item $item -Count $n) for $(Format-Money $cost)."
    }
}
