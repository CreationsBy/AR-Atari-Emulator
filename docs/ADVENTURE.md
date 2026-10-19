# Adventure: measured NTSC 3D profile

Reopen the supplied Adventure ROM after updating. Its exact hashes select `adventure-ntsc-v2` and the `adventureNTSCv1` adapter automatically:

- SHA-256: `b0326b45e5cab066b2d03f1e683708d82de3ffe60b2e968bf88c5494237f0a96`
- MD5: `157bddb7192754a45372be196797f284`
- Size: 4,096 bytes. Other revisions/TV standards are not covered.

This replaces the earlier unmeasured size rules for this revision. Its ID changed because the interpretation is incompatible with the earlier profile; old profile-bound saves may be rejected. Commercial ROMs remain local and are excluded from Git and app/source packages.

## Reconstruction

The adapter reads visible pixels, RAM and graphics from the user's already-loaded cartridge. No commercial sprite or room masks are copied into source. The [annotated disassembly of Warren Robinett's game](https://6502disassembly.com/2600-adventure/Adventure.bin.html) informed the room/display-cache interpretation; raster alignment was measured against the supplied ROM.

- Thin floor, raised visible room walls and taller central masses in the three exterior castle rooms, preserving raster passages.
- Separate player block, including against same-color walls.
- Upright portcullis silhouettes following the original gate animation, with an authored doorway recess so castle volume does not bury the gate. These visual openings do not change original collisions or portal rules.
- Standing silhouettes for dragons, bat, keys, sword, chalice and magnet, using original colors and visible masks.
- Raised bridge interpretation preserving its holes.
- Thin side barriers where displayed. The invisible surround is a visibility window, not an obstacle; dark walls remain hidden outside its currently displayed area.

The two selected sprite masks are intersected with visible pixels. Recently observed, unchanged sprites can be held for at most three frames to reduce multiplexing flicker. Position/state/room changes invalidate held shapes; no unseen objects or predicted motion are invented. Frame-boundary room/display mismatches briefly use generic reconstruction. Room changes and state restoration clear history.

Settings → Miniature world → World orientation → **Vertical** stands the world upright. **Tabletop** restores the horizontal diorama. Standing creatures/items counterrotate in Vertical; floors, walls, bridge and player retain their intended transforms.

## Host checks and limits

All 27 local native tests pass, including both supplied Adventure and Ice Hockey ROMs. Original synthetic fixtures cover same-color separation, holes, translation/mesh reuse, bounded retention, room changes, dark visibility, item/bridge roles and budgets. Public CI skips the two private-ROM methods.

Adventure ran for 4,373 frames with only ordinary console/joystick inputs, across all three game selections and five room IDs including the title. The route picked up the yellow key, entered the yellow castle, picked up/dropped the sword and encountered dragons and the bat. There were zero geometry drops and 15 generic startup/transition frames. Reconstruction left emulator save bytes unchanged. `build/adventure/validation-report.json` records the captures; host timings are not iPhone FPS.

This remains **experimental**. Complete matches, all mazes/castles, bridge/chalice/magnet in real gameplay, dragon states, bat theft, secrets, wraparound, overlaps and physical iPhone acceptance need coverage. Synthetic tests do not establish real-ROM coverage for those scenarios. Tall silhouettes can occlude small items from some angles. Offline renders show captured geometry, not AR.

The original Adventure cartridge is single-player. A Wi-Fi guest can view the shared scene, but this profile does not add a second controllable adventurer.

## Reproduce

Run `scripts/capture_adventure.py` with the project Python and compiled native library. Captures remain in ignored `build/adventure/`. Render with `scripts/render_evidence.py` in Blender using `--input`, `--output` and optional `--upright` after Blender's `--` separator. See [DEVICE_TESTING.md](DEVICE_TESTING.md) for physical checks.
