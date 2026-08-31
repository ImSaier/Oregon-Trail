# The Oregon Trail

A recreation of the **1985 MECC Oregon Trail**, written entirely in PowerShell and played in the terminal. Colored text graphics, a real-time hunting minigame, and the original rules, prices and scoring.

No modules. No dependencies. One script.

## Playing

Double-click `Play.bat`, or from a terminal:

```powershell
.\OregonTrail.ps1
```

**Requirements:** Windows PowerShell 5.1 or later, and a terminal at least **100x30**. Windows Terminal is recommended for the best coloration.

| Option | Effect |
|---|---|
| `-ColorMode 16` | Use 16 colors instead of 256, for terminals with limited color support |
| `-SkipSizeCheck` | Start anyway in a smaller window |

**Controls:** Number keys, or arrows and Enter, in menus. In the hunting and rafting minigames: WASD or arrows to move, SPACE to fire, ESC to quit.

## Differences from the 1985 original

- The trail follows the single standard route; the South Pass and Blue Mountains forks are not implemented.
- No wagon weight limit - the 1985 MECC version had none, and that arrived with the 1990 Deluxe release. Wagon load is shown for information only.
- Hunting is harder than the original, where bullets were effectively instant and the whole bounding box counted as a hit.
- No sound.

## Licence

*The Oregon Trail* was created by Don Rawitsch, Bill Heinemann and Paul Dillenberger in 1971 and published by MECC. This is an independent tribute, written from scratch, and is not affiliated with or endorsed by any rights holder.
