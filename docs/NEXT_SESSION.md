# Resume with physical Adventure / Vertical / multiplayer testing

## Completed October 19, 2026 (America/New_York)

The supplied Adventure ROM now has a measured `adventure-ntsc-v2` profile and native `adventureNTSCv1` adapter. Reopen/import the existing cartridge entry after updating to select it automatically. Its previous profile ID changed; older profile-bound saves may be rejected.

- SHA-256: `b0326b45e5cab066b2d03f1e683708d82de3ffe60b2e968bf88c5494237f0a96`
- MD5: `157bddb7192754a45372be196797f284`; size 4,096 bytes.

Read-only pixels, RAM and graphics from the user's loaded cartridge produce visible room walls, taller castle masses, a separate player, animated portcullises, upright creatures/items and a raised bridge interpretation. Commercial graphics/masks are not copied into source. A measured doorway recess keeps the gate opening clear. Thin side barriers and the local dark-maze visibility window are interpreted. Unchanged observed sprites can persist for three multiplexed frames; changed positions/states/rooms invalidate them. No game-state writes, new physics or predicted motion.

The user clarified that Vertical means an upright 3D world, not portrait orientation. Settings → Miniature world → World orientation offers Tabletop / Vertical. Vertical stands on the bottom edge at a horizontal AR anchor. Adventure's player/creatures/items move to a foreground layer derived from wall geometry so castle relief cannot bury them; standing silhouettes counterrotate. Tabletop positions stay unchanged. Both peers apply the same transforms to shared geometry.

Earlier Ice Hockey and private same-Wi-Fi multiplayer remain present. P1 runs the ROM; P2 joins by code, receives geometry/pixels/audio and uses port 2 without a ROM. ARWorldMap sharing supports independent physical camera views. Install the same current build on both phones (wire protocol 2). Stock Adventure itself is single-player; its guest can spectate but no second adventurer was added. See [ADVENTURE.md](ADVENTURE.md), [ICE_HOCKEY.md](ICE_HOCKEY.md) and [LOCAL_MULTIPLAYER.md](LOCAL_MULTIPLAYER.md).

## Verified latest build

- [GitHub Actions run #9](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39296849358) passed.
- Built commit: `7bf94a0c4963b66e651923573a99f6f4b8f5f512`.
- All 27 local native methods pass. Hosted Ubuntu passes 25 and skips the two private-ROM methods. Native library compiles 102 sources; 286 pinned vendor files verify.
- Adventure capture: 4,373 frames using normal console/joystick input only; all three game selections, five room IDs including title; yellow-key pickup, castle entry, sword pickup/drop and creature encounters. Zero geometry drops; 15 generic startup/transition frames. Serialized emulator state unchanged by reconstruction.
- Original synthetic CI fixtures cover same-color separation, holes, translation/mesh reuse, bounded retention, room changes, dark visibility, item/bridge roles and budgets. A supplied-ROM assertion checks the doorway recess.
- Hosted Swift checks pass: native adapter selection, vertical creature/item orientation, foreground placement, unchanged Tabletop/bridge transforms, prior settings/wire checks and real TLS-PSK endpoint regressions.
- Xcode 16.4 (16F6), iPhoneOS 18.5 SDK, iOS 16 target: arm64 device archive and unsigned IPA passed.
- Artifact download digests and IPA/source CRCs pass; all 383 matching-source files equal built Git blobs. Six profiles, original fixture and camera/network keys verify. No commercial ROM is bundled.
- Full record: [evidence/adventure-build.json](evidence/adventure-build.json).

Offline renders were inspected at `build/adventure/tabletop/reconstruction-3d.png`, `build/adventure/vertical/reconstruction-3d.png` and `build/adventure/dragon/reconstruction-3d.png`. They are actual captured geometry rendered offline, not iPhone/AR screenshots.

Adventure remains experimental: complete matches, all mazes/castles, bridge/chalice/magnet in actual gameplay, dragon states, bat theft, secrets, wraparound and overlaps need coverage. Dark-room synthetic tests do not establish full real-maze acceptance. Tall silhouettes can occlude small objects from some angles. Host timings are not iPhone FPS.

## Deliverables

- Latest IPA: `build/deliverables/AtariDiorama-UNSIGNED-requires-resigning.ipa`
- Manifest: `build/deliverables/artifact-manifest.json`
- Exact matching source for build #9: `build/deliverables/AtariDiorama-source.zip`
- Downloads and full logs: `build/github-run-9/`; earlier #7, #5 and #1 remain in their own directories.
- IPA SHA-256: `c917dcbb0905f427d02833c2d2b841b2f4ed06a4dfb4ace08ecdec2a9c256c40`.

[IPA/source artifact](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39296849358/artifacts/12209586721) expires November 2, 2026 at 12:48 PM EST (2026-11-02T17:48:11Z). Local copies remain available. Later evidence/documentation commits are separate from the exact matching-source ZIP.

## Next action

Re-sign/install the new IPA and reopen Adventure. Follow [DEVICE_TESTING.md](DEVICE_TESTING.md), comparing original pixels with Tabletop and Vertical during key carrying, gate movement, creatures, room changes and save/load. Then test physical Wi-Fi discovery, shared-table alignment, latency and audio on two phones using the original two-player test ROM or a supported two-player cartridge.

The user reported earlier single-device AR worked with the demo and their Atari ROMs. This does not validate the new Adventure/Ice Hockey/Vertical or two-phone features. Do not claim physical acceptance, full commercial-profile support or unsigned launch without re-signing.

Keep commercial cartridges under ignored `roms/`; never upload them or include them in app/source packages.

## Workspace and tools

Root: `C:\Users\spagh\OneDrive\Documents\Ai projects\games\AR Atari 2600`.
Portable Git: `.tools/mingit/cmd/git.exe`; GitHub CLI `.tools/gh/bin/gh.exe` remains unauthenticated.
Python: `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`.
Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.

The connected GitHub plugin handles writes, runs and downloads. Do not extract credentials. Publish through the connector and public Git fetch to sync main. Original history remains on `local-before-github-upload`. Git metadata writes may need escalation; use per-command safe.directory for this exact workspace only.

The preview server is stopped so its DLL can rebuild. Restart with `scripts/Start-Preview.ps1` if needed. Capture Adventure with `scripts/capture_adventure.py`; Blender evidence accepts --input / --output / --upright after --. Do not repeat broad passing checks without new changes/failures.
