[CmdletBinding()]
param(
    [ValidateSet('256', '16')][string]$ColorMode = '256',
    [string]$WindowSize = 'Ask',
    [switch]$SkipSizeCheck
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'src\Bootstrap.ps1')

$asked = ($WindowSize.Length -eq 0 -or $WindowSize -eq 'Ask')
while ($true) {
    $chosen = Initialize-WindowSize -Spec $WindowSize -ScriptPath $PSCommandPath -ColorMode $ColorMode
    if (-not $chosen.Ok) {
        Write-Host ''
        Write-Host ('  ' + $chosen.Message) -ForegroundColor Yellow
        Write-Host ''
        exit 1
    }
    if ($chosen.Quit) { exit 0 }
    $size = Test-TerminalSize
    if ($size.Ok -or $SkipSizeCheck) { break }
    Write-Host ''
    Write-Host ("  The Oregon Trail needs a terminal at least {0} x {1}." -f $script:OTMinWidth, $script:OTMinHeight) -ForegroundColor Yellow
    Write-Host ("  This window is {0} x {1} and would not grow any further." -f $size.Width, $size.Height) -ForegroundColor Yellow
    Write-Host '  A smaller terminal font will make more columns and rows fit.' -ForegroundColor DarkGray
    if (-not $asked) {
        Write-Host '  Run without -WindowSize to choose a size, or with -SkipSizeCheck to play anyway.' -ForegroundColor DarkGray
        Write-Host ''
        exit 1
    }
    Write-Host '  Press any key to choose a size again, or ESC to quit.' -ForegroundColor DarkGray
    $again = $null
    try { $again = [Console]::ReadKey($true) } catch { exit 1 }
    if ($again.Key -eq [System.ConsoleKey]::Escape) { exit 0 }
}

try {
    Initialize-Terminal -ColorMode $ColorMode
    Start-OregonTrail
}
catch {
    Restore-Terminal
    Write-Host ''
    Write-Host '  The Oregon Trail stopped unexpectedly:' -ForegroundColor Red
    Write-Host ("  " + $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
finally {
    Restore-Terminal
}
