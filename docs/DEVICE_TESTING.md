# Physical iPhone acceptance procedure

No rows below have been executed on a phone yet. Record iPhone model, iOS version, commit/source ZIP hash, build artifact SHA-256, signing method, profile ID and exact ROM hashes with every result. Use the original test cartridge first.

| Test | Acceptance condition | Current result |
|---|---|---|
| Device installation | A correctly signed build installs, launches and can be refreshed | Pending |
| Camera permission | Allow/deny paths explain recovery and preserve app navigation | Pending |
| Scan and place | Preview follows an actual horizontal plane; tapping places once | Pending |
| Physical viewpoint | Walk around, crouch and approach; object volume and holes remain visible | Pending |
| Anchor stability | A stationary room remains fixed during two minutes of camera motion | Pending |
| Controls | Diagonals and Fire work simultaneously; leaving a control releases it | Pending |
| Console | Select changes room; Reset works; difficulty/color switches reach the core | Pending |
| Paddle input | Slider moves the real paddle smoothly; both players' Fire buttons map correctly | Pending |
| Bluetooth | Two controllers map to separate players and disconnect clears input | Pending |
| Audio | Original tone begins with Fire, remains paced and does not crackle over five minutes | Pending |
| Save/load | Actor, enemy and room return to saved state; correct geometry returns; anchor stays fixed | Pending |
| Lifecycle | Background/foreground, camera interruption and audio route change do not stick input | Pending |
| Settings | Tiny/custom/large scale, pinch, rotation, tilt and reposition work in portrait/landscape | Pending |
| Geometry updates | Actors move without full-scene rebuild; removed pixels cease drawing immediately | Pending |
| HUD | Digits remain original pixels rather than obstacles for a validated profile | Pending |
| Performance | Record emulator cadence, measured AR FPS, analysis time, objects, drops and scene errors | Pending |
| Thermal behavior | Record memory/power/thermal state over a 15-minute run; adjust quality if necessary | Pending |

Use a normally lit, textured table, place the test game, then hold Right and Fire. Orbit to see the actor's extrusion and the wall's height. Select a different room, save, move, restore and compare. The original game logic remains a 2D Atari program; the extra visual dimension does not add 3D collisions or platforming.

For a commercial ROM, log title/revision/hash and test each important scenario. Adventure needs castles, dragons, keys, sword, held objects, doors and room changes. Combat needs both players, projectiles, tank/aircraft variations and obstacle rules. Breakout needs analog paddle range, both Fire buttons, brick destruction and score. Pitfall! needs room transitions, tree/ladder/pit silhouettes and character frames. These targets currently remain experimental.

Collect the app's exported diagnostic JSON with a short screen recording and the same ROM/profile/core identity. Do not include the commercial ROM in a public issue or source package. A failure report should describe the original-frame behavior as well as the 3D result, so emulation and interpretation errors can be distinguished.
