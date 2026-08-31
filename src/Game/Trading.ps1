$script:OTTradeGoods = @(
    @{ Field = 'Food';     Label = 'pounds of food';  Min = 25; Max = 120 }
    @{ Field = 'Bullets';  Label = 'bullets';         Min = 20; Max = 120 }
    @{ Field = 'Clothing'; Label = 'sets of clothing'; Min = 1; Max = 4 }
    @{ Field = 'Wheels';   Label = 'wagon wheels';    Min = 1;  Max = 2 }
    @{ Field = 'Axles';    Label = 'wagon axles';     Min = 1;  Max = 2 }
    @{ Field = 'Tongues';  Label = 'wagon tongues';   Min = 1;  Max = 2 }
    @{ Field = 'Oxen';     Label = 'oxen';            Min = 1;  Max = 2 }
)

function Invoke-Trade {
    param($State)
    if ($State.Rng.Next(0, 100) -lt 30) {
        Show-Message -Text 'You look for someone to trade with, but nobody on this stretch of trail wants to deal.' -Title 'TRADING' -Left 22 -Top 11 -Width 56 -BorderFg (Get-C 'Grey')
        return
    }
    $wantIdx = $State.Rng.Next(0, $script:OTTradeGoods.Count)
    $giveIdx = $wantIdx
    while ($giveIdx -eq $wantIdx) { $giveIdx = $State.Rng.Next(0, $script:OTTradeGoods.Count) }
    $want = $script:OTTradeGoods[$wantIdx]
    $give = $script:OTTradeGoods[$giveIdx]
    $wantQty = $State.Rng.Next($want.Min, $want.Max + 1)
    $giveQty = $State.Rng.Next($give.Min, $give.Max + 1)
    if ($State[$want.Field] -lt $wantQty) {
        Show-Message -Text "A trader wants $wantQty $($want.Label), but you don't have that many to spare." -Title 'TRADING' -Left 22 -Top 11 -Width 56 -BorderFg (Get-C 'Grey')
        return
    }
    $text = "A trader offers $giveQty $($give.Label) in exchange for $wantQty $($want.Label)."
    if (Show-Confirm -Text $text -Title 'TRADING' -Left 20 -Top 10 -Width 60) {
        $State[$want.Field] = $State[$want.Field] - $wantQty
        $State[$give.Field] = $State[$give.Field] + $giveQty
        Add-Journal -State $State -Text "Traded $wantQty $($want.Label) for $giveQty $($give.Label)."
        Show-Message -Text 'You made the trade.' -Title 'TRADING' -Left 26 -Top 12 -Width 48 -BorderFg (Get-C 'Green')
    }
    else {
        Show-Message -Text 'You decline the offer and move on.' -Title 'TRADING' -Left 24 -Top 12 -Width 52 -BorderFg (Get-C 'Grey')
    }
    $State.Date = $State.Date.AddDays(1)
    $State.DaysOnTrail++
}

$script:OTTalkLines = @(
    "A woman at the well tells you her party buried two children between here and the Platte. She does not say their names."
    "An old teamster says the secret is light loads and slow oxen. 'Them that hurry get there last, or not at all.'"
    "A man mending a wheel says there is good grass two days ahead, but no water for the day after."
    "A trader says the rivers run higher this year than last. He advises paying for the ferry where you can."
    "A missionary bound east says the Blue Mountains have already taken snow. He looks at your oxen and says nothing more."
    "A boy of about ten is minding a team alone. He says his father is sick in the wagon and asks if you have any medicine."
    "A woman offers you dried apples and refuses payment. She says her party was fed the same way near Fort Kearney."
    "A man says he turned back once and regrets it every day of his life. He is going west again."
    "A guide warns you not to drink from standing water, no matter how thirsty the party gets."
    "An emigrant says a party ahead lost a wagon at the crossing. 'They tried to ford a river they should have floated.'"
)

function Invoke-TalkToPeople {
    param($State)
    $line = $script:OTTalkLines[$State.Rng.Next(0, $script:OTTalkLines.Count)]
    Show-Message -Text $line -Title 'TALKING TO PEOPLE' -Left 18 -Top 10 -Width 64 -BorderFg (Get-C 'SkyBlue')
}
