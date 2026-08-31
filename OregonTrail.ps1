[CmdletBinding()]
param(
    [ValidateSet('256', '16')][string]$ColorMode = '256',
    [switch]$SkipSizeCheck
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'src\Bootstrap.ps1')

$size = Test-TerminalSize
if (-not $size.Ok -and -not $SkipSizeCheck) {
    Write-Host ''
    Write-Host '  The Oregon Trail needs a terminal at least 100 x 30.' -ForegroundColor Yellow
    Write-Host ("  Your window is currently {0} x {1}." -f $size.Width, $size.Height) -ForegroundColor Yellow
    Write-Host '  Resize the window and run again, or use -SkipSizeCheck to try anyway.' -ForegroundColor Yellow
    Write-Host ''
    exit 1
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
