# Physical iPhone acceptance procedure

The user reports that the earlier build's AR works with the test cartridge and their own Atari ROMs on their phone. This is a user-reported smoke result; device details and individual checks below have not been recorded. The new two-phone multiplayer feature has not yet been physically tested. Record iPhone model, iOS version, commit/source ZIP hash, build artifact SHA-256, signing method, profile ID and exact ROM hashes with every result. Use the original test cartridge first.

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

## Two-phone multiplayer acceptance (pending)

Follow [LOCAL_MULTIPLAYER.md](LOCAL_MULTIPLAYER.md) on two iPhones with the same build. Keep Player 2's library empty to prove that no ROM is required.

| Test | Acceptance condition | Current result |
|---|---|---|
| Discovery and code | Correct code connects on the same Wi-Fi; wrong code cannot join; Local Network denial gives recovery instructions | Pending |
| Two-player fixture | Host moves blue actor; guest moves red actor and fires. Release stops the red actor. Both screens show the same positions | Pending |
| Independent perspective | Both phones align to one physical table location; walking to opposite sides changes their views independently | Pending |
| Shared transforms | Host pinch/rotation/tilt and reposition propagate; guest cannot independently move the shared world | Pending |
| Cartridge modes | User-supplied two-player joystick cartridge responds to both phones; paddle cartridge maps both sliders and both Fire buttons | Pending |
| Sound and delay | Both hear original TIA audio; measure touch-to-game response and listen for gaps over five minutes | Pending |
| Host authority | Guest cannot operate host Reset/Select/save/load or take over Player 1 | Pending |
| Pause and menus | Host pause affects both; guest settings/inspection releases only guest input; closing a menu permits explicit resume | Pending |
| Stale input and disconnect | Holding Right/Fire while disconnecting cannot leave input stuck; host pauses and guest can rejoin | Pending |
| Room isolation | A third phone cannot replace Player 2; a newly created room uses a new code | Pending |
| Lifecycle and routes | Background either app closes its connection; same-Wi-Fi recovery works; different Wi-Fi/cellular does not silently route online | Pending |
| Sustained performance | Measure AR FPS, input latency, audio quality and thermal behavior on both phones for 15 minutes | Pending |
