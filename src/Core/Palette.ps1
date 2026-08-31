$script:OTESC = [char]27
$script:OTPaletteMode = '256'
$script:OTPalIndex = @{}
$script:OTPalFg = @()
$script:OTPalBg = @()
$script:OTPalDef = @(
    @{ Name = 'Black';      C256 = 16;  C16 = 30 }
    @{ Name = 'White';      C256 = 231; C16 = 97 }
    @{ Name = 'Grey';       C256 = 250; C16 = 37 }
    @{ Name = 'DarkGrey';   C256 = 240; C16 = 90 }
    @{ Name = 'Silver';     C256 = 145; C16 = 37 }
    @{ Name = 'Red';        C256 = 196; C16 = 91 }
    @{ Name = 'DarkRed';    C256 = 124; C16 = 31 }
    @{ Name = 'Blood';      C256 = 160; C16 = 31 }
    @{ Name = 'Green';      C256 = 46;  C16 = 92 }
    @{ Name = 'DarkGreen';  C256 = 28;  C16 = 32 }
    @{ Name = 'Grass';      C256 = 34;  C16 = 32 }
    @{ Name = 'Yellow';     C256 = 226; C16 = 93 }
    @{ Name = 'Gold';       C256 = 220; C16 = 33 }
    @{ Name = 'Amber';      C256 = 214; C16 = 33 }
    @{ Name = 'Orange';     C256 = 208; C16 = 33 }
    @{ Name = 'Fire';       C256 = 202; C16 = 91 }
    @{ Name = 'Blue';       C256 = 33;  C16 = 94 }
    @{ Name = 'SkyBlue';    C256 = 117; C16 = 96 }
    @{ Name = 'DarkBlue';   C256 = 18;  C16 = 34 }
    @{ Name = 'Night';      C256 = 17;  C16 = 34 }
    @{ Name = 'River';      C256 = 39;  C16 = 96 }
    @{ Name = 'DeepRiver';  C256 = 25;  C16 = 34 }
    @{ Name = 'Cyan';       C256 = 51;  C16 = 96 }
    @{ Name = 'Magenta';    C256 = 201; C16 = 95 }
    @{ Name = 'Purple';     C256 = 141; C16 = 95 }
    @{ Name = 'Brown';      C256 = 130; C16 = 33 }
    @{ Name = 'DarkBrown';  C256 = 94;  C16 = 33 }
    @{ Name = 'Wood';       C256 = 137; C16 = 33 }
    @{ Name = 'Tan';        C256 = 180; C16 = 33 }
    @{ Name = 'Canvas';     C256 = 223; C16 = 37 }
    @{ Name = 'Ox';         C256 = 101; C16 = 33 }
    @{ Name = 'Mountain';   C256 = 102; C16 = 90 }
    @{ Name = 'Rock';       C256 = 138; C16 = 37 }
    @{ Name = 'Snow';       C256 = 255; C16 = 97 }
    @{ Name = 'Sun';        C256 = 227; C16 = 93 }
    @{ Name = 'Dust';       C256 = 179; C16 = 33 }
    @{ Name = 'Bone';       C256 = 253; C16 = 37 }
)

function Initialize-Palette {
    param([ValidateSet('256', '16')][string]$Mode = '256')
    $script:OTPaletteMode = $Mode
    $script:OTPalIndex = @{}
    $fg = New-Object 'System.String[]' $script:OTPalDef.Count
    $bg = New-Object 'System.String[]' $script:OTPalDef.Count
    for ($i = 0; $i -lt $script:OTPalDef.Count; $i++) {
        $d = $script:OTPalDef[$i]
        $script:OTPalIndex[$d.Name] = $i
        if ($Mode -eq '256') {
            $fg[$i] = "$script:OTESC[38;5;$($d.C256)m"
            $bg[$i] = "$script:OTESC[48;5;$($d.C256)m"
        }
        else {
            $fg[$i] = "$script:OTESC[$($d.C16)m"
            $bg[$i] = "$script:OTESC[$($d.C16 + 10)m"
        }
    }
    $script:OTPalFg = $fg
    $script:OTPalBg = $bg
}

function Get-ColorIndex {
    param([Parameter(Mandatory)][string]$Name)
    if ($script:OTPalIndex.ContainsKey($Name)) { return $script:OTPalIndex[$Name] }
    throw "Unknown color '$Name'. Known colors: $($script:OTPalDef.Name -join ', ')"
}

