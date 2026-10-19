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

## Vertical world and Ice Hockey acceptance (pending)

Use the new build and the exact cartridge hashes in [ICE_HOCKEY.md](ICE_HOCKEY.md). The local real-ROM capture and offline renders do not establish these physical results.

| Test | Acceptance condition | Current result |
|---|---|---|
| Existing preferences | Updating preserves volume, selected player and other settings; world initially remains Tabletop | Pending |
| Vertical placement | On a horizontal table anchor, Vertical stands the scene on its bottom edge; rotation/tilt/size and switching back work while paused and playing | Pending |
| Existing side-view profile | A profile with an already-upright pixel plane is not rotated twice | Pending |
| Ice Hockey profile | Reopening selects `ice-hockey-ntsc-v2`; original rink/goal openings, skater silhouettes, sticks and visible puck match source pixels; no added boards/posts/nets or pedestal | Pending |
| Poses and scoring | Play a complete match with both teams, falls, overlaps and goals; record disappearing/merged parts against the original-frame comparison | Pending |
| Complete artwork | Both scores, timer and Activision logo appear as live world geometry in original positions, with no separate score overlay; changing digits remove their old pixels | Pending |
| Vertical artwork | Entire raster relief including skaters/text rotates together in Tabletop/Vertical; text stays readable from the front and source-plane positions stay intact | Pending |
| Original colors | Ambient-light changes do not recolor Ice Hockey's unlit artwork; compare original frame and world colors | Pending |
| Two-phone orientation | With the same updated build on both phones, the host's Vertical/Tabletop choice propagates while each phone retains its own camera view | Pending |
| Ice Hockey two-player | Host selects game 2 or 4 and resets; each phone independently controls the correct team, including Fire, with no ROM in the guest library | Pending |

## Adventure acceptance (pending)

Use the exact revision in [ADVENTURE.md](ADVENTURE.md). Reopen it to select `adventure-ntsc-v2`; the earlier profile's save identity changed.

| Test | Acceptance condition | Current result |
|---|---|---|
| Castle/key/gate | Player and key stay distinct; carrying the key opens the original gate; animation preserves the passage | Pending |
| Rooms/dark maze | Openings match original pixels; no old-room objects remain; dark walls appear only within the game's displayed visibility window | Pending |
| Creatures/items | Compare all dragon states, bat theft, keys, sword, chalice, magnet and bridge against original pixels, including overlap/flicker | Pending |
| Original rules | Complete all three variations; carrying, dropping, dragon death/eating and winning remain original emulated behavior | Pending |
| Presentation/restore | Tabletop/Vertical keep silhouettes upright; Reset/save/load clear stale models without moving AR placement | Pending |
| Shared spectator | Same-build guest sees the scene from its own position without a ROM; stock Adventure remains single-player | Pending |
| Performance | Record device FPS, analysis/mesh counts, input/audio timing and sustained thermal behavior | Pending |
