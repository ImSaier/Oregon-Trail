function ConvertTo-GameKey {
    param([System.ConsoleKeyInfo]$KeyInfo)
    $ctrl = ($KeyInfo.Modifiers -band [System.ConsoleModifiers]::Control) -ne 0
    $ch = $KeyInfo.KeyChar
    $name = switch ($KeyInfo.Key) {
        'UpArrow'    { 'Up' }
        'DownArrow'  { 'Down' }
        'LeftArrow'  { 'Left' }
        'RightArrow' { 'Right' }
        'Enter'      { 'Enter' }
        'Escape'     { 'Escape' }
        'Spacebar'   { 'Space' }
        'Backspace'  { 'Backspace' }
        'Tab'        { 'Tab' }
        'Delete'     { 'Delete' }
        'Home'       { 'Home' }
        'End'        { 'End' }
        default      { $null }
    }
    if ($null -eq $name) {
        if ($ctrl -and $KeyInfo.Key -eq [System.ConsoleKey]::C) { $name = 'CtrlC' }
        elseif ($ch -eq ' ') { $name = 'Space' }
        elseif ([int]$ch -ge 32 -and [int]$ch -lt 127) { $name = ([string]$ch).ToUpper() }
        else { $name = 'Unknown' }
    }
    return @{ Key = $name; Char = $ch; Ctrl = $ctrl }
}

function Get-NormalizedDirection {
    param($GameKey)
    switch ($GameKey.Key) {
        'Up'    { return 'Up' }
        'W'     { return 'Up' }
        'Down'  { return 'Down' }
        'S'     { return 'Down' }
        'Left'  { return 'Left' }
        'A'     { return 'Left' }
        'Right' { return 'Right' }
        'D'     { return 'Right' }
    }
    return $null
}

function Read-GameKey {
    return ConvertTo-GameKey -KeyInfo ([Console]::ReadKey($true))
}

function Read-GameKeyIfAvailable {
    if ([Console]::KeyAvailable) {
        return ConvertTo-GameKey -KeyInfo ([Console]::ReadKey($true))
    }
    return $null
}

