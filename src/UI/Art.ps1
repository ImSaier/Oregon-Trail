$script:OTArt = @{}

$script:OTArt.TitleOregon = @(
    '  ___  ____  _____ ____  ___  _   _ '
    ' / _ \|  _ \| ____/ ___|/ _ \| \ | |'
    '| | | | |_) |  _|| |  _| | | |  \| |'
    '| |_| |  _ <| |__| |_| | |_| | |\  |'
    ' \___/|_| \_\_____\____|\___/|_| \_|'
)

$script:OTArt.TitleTrail = @(
    ' _____ ____      _     ___ _     '
    '|_   _|  _ \    / \   |_ _| |    '
    '  | | | |_) |  / _ \   | || |    '
    '  | | |  _ <  / ___ \  | || |___ '
    '  |_| |_| \_\/_/   \_\|___|_____|'
)

$script:OTArt.Wagon = @(
    '        ______________        '
    '   ____/              \____   '
    '  /                        \  '
    ' |    |    |    |    |    |  |'
    ' |____|____|____|____|____|__|'
    '(O)__________________________(O)'
)

$script:OTArt.WagonSmall = @(
    '   _______   '
    '  /       \  '
    ' |  |  |  |  '
    ' |__|__|__|  '
    ' (o)-----(o) '
)

$script:OTArt.OxTeam = @(
    '  ^^__      ^^__   '
    ' (oo\_)    (oo\_)  '
    '  ||  |     ||  |  '
    '  ^^  ^^    ^^  ^^ '
)

$script:OTArt.Tombstone = @(
    '         _________________         '
    '      __/                 \__      '
    '     /                       \     '
    '    |                         |    '
    '    |                         |    '
    '    |                         |    '
    '    |                         |    '
    '    |                         |    '
    '    |                         |    '
    '    |                         |    '
    '    |                         |    '
    '  __|_________________________|__  '
    ' /_____________________________\   '
)

$script:OTArt.Mountains = @(
    '                /\                    /\                '
    '           /\  /  \        /\        /  \    /\         '
    '      /\  /  \/    \  /\  /  \  /\  /    \  /  \  /\    '
    '  ___/  \/           \/  \/    \/  \/      \/    \/  \__'
)

$script:OTArt.Fort = @(
    '   |^^^^^^^^^^^^^^^^^^^^^^|   '
    '  /|  __    ______    __  |\  '
    ' / |  ||   |      |   ||  | \ '
    '|  |  ||   |  ==  |   ||  |  |'
    '|__|__||___|______|___||__|__|'
)

$script:OTArt.Hunter = @(
    ' o '
    '/|\'
    '/ \'
)

$script:OTArt.Deer = @(
    ' \\_/\_//'
    '  (o.o) '
    '  /| |\ '
)

$script:OTArt.Buffalo = @(
    '  ___    '
    ' /^^^\__ '
    '(  o    )'
    ' || || | '
)

$script:OTArt.Bear = @(
    ' (o) (o) '
    '(    ^   )'
    ' \______/ '
)

$script:OTArt.Rabbit = @(
    ' \\|| '
    ' (o.o)'
    ' (")_)'
)

$script:OTArt.Squirrel = @(
    '  (o) ~ '
    ' (   ) )'
    '  ^^ ^^ '
)

$script:OTArt.RiverBank = @(
    '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
)

$script:OTArt.Raft = @(
    ' [===============] '
    ' |   |   |   |   | '
)

$script:OTArt.Grave = @(
    '   ___   '
    '  /   \  '
    ' |  +  | '
    ' |_____| '
)

function Get-Art {
    param([Parameter(Mandatory)][string]$Name)
    if (-not $script:OTArt.ContainsKey($Name)) {
        throw "Unknown art asset '$Name'. Known: $(($script:OTArt.Keys | Sort-Object) -join ', ')"
    }
    return ,[string[]]$script:OTArt[$Name]
}

function Get-ArtWidth {
    param([string[]]$Lines)
    $max = 0
    foreach ($l in $Lines) { if ($l.Length -gt $max) { $max = $l.Length } }
    return $max
}

function Draw-Art {
    param([string]$Name, [int]$Left, [int]$Top, [int]$Fg = 1, [int]$Bg = 0, [switch]$Transparent, [switch]$Centered)
    $lines = Get-Art -Name $Name
    $x = $Left
    if ($Centered) { $x = [math]::Floor(($script:OTScr.Width - (Get-ArtWidth -Lines $lines)) / 2) }
    Write-BufferArt -X $x -Y $Top -Lines $lines -Fg $Fg -Bg $Bg -Transparent:$Transparent
}

function Draw-StarField {
    param([int]$Top, [int]$Height, [int]$Seed = 7, [int]$Fg = 3, [int]$Count = 40, [int]$Bg = 0)
    $r = New-Object System.Random $Seed
    for ($i = 0; $i -lt $Count; $i++) {
        $sx = $r.Next(0, $script:OTScr.Width)
        $sy = $Top + $r.Next(0, $Height)
        Set-BufferCell -X $sx -Y $sy -Char ([char]46) -Fg $Fg -Bg $Bg
    }
}

function Draw-Ground {
    param([int]$Y, [int]$Fg = 25, [char]$Char = '_')
    $row = New-Object System.String -ArgumentList $Char, $script:OTScr.Width
    Write-BufferText -X 0 -Y $Y -Text $row -Fg $Fg
}
