$script:OTGameRoot = Split-Path -Parent $PSScriptRoot
$script:OTSrcRoot = $PSScriptRoot
$script:OTLoadOrder = @(
    'Core\Palette.ps1'
    'Core\Buffer.ps1'
    'Core\Terminal.ps1'
    'Core\WindowSize.ps1'
    'Core\Input.ps1'
    'Core\GameLoop.ps1'
    'UI\Widgets.ps1'
    'UI\Art.ps1'
    'UI\Screens.ps1'
    'Game\State.ps1'
    'Game\Setup.ps1'
    'Game\Store.ps1'
    'Game\Landmarks.ps1'
    'Game\Events.ps1'
    'Game\Travel.ps1'
    'Game\Hunting.ps1'
    'Game\Rivers.ps1'
    'Game\Trading.ps1'
    'Game\Rafting.ps1'
    'Game\Scoring.ps1'
    'Game\Game.ps1'
)
foreach ($rel in $script:OTLoadOrder) {
    $p = Join-Path $script:OTSrcRoot $rel
    if (-not (Test-Path $p)) { throw "Missing source file: $p" }
    . $p
}
