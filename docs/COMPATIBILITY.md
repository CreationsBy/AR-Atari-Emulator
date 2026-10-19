# Compatibility and milestone results

Updated 2026-10-19. This is a development prototype, not a completed or certified iOS emulator release.

## Complete original-art Ice Hockey update

[Build #14](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39320563294) passed for `8ac791b6c03a40c34937a09e2e87e52d5eead113`. Hosted Linux passes 30 methods and skips two private-ROM methods; hosted Mac passes the constrained-stack suites, actual loading queue, profile/presentation rules and encrypted transport. Xcode 16.4 compiled the unlit RealityKit renderer and archived ARM64 successfully. IPA/source CRC and digest checks pass; all 401 source files match the built commit and no commercial ROM is bundled. See [the build record](evidence/ice-hockey-faithful-build.json).

The supplied ROM now selects `ice-hockey-ntsc-v2` / `iceHockeyNTSCv2`. The complete live frame, including both scores, timer and Activision logo, is voxel geometry in the world. Added boards, posts, nets, RAM-derived standing poses and presentation pedestal are removed. Original pixel shapes/positions/colors are retained, with depth as the only added dimension. Text uses shallow relief; the renderer uses unlit colors and disables the separate score HUD for this profile.

An independent box-footprint projection matched every RGBA pixel in all 3,600 captured frames: 120,960,000 checked pixels, no missing/extra/overlapping footprints and no geometry drops. The scene peaked at 68 objects / 389 boxes. All 32 local native methods pass, including constrained worker-stack coverage. Offline Tabletop/Vertical renders were inspected with readable original lettering. This verifies source-plane artwork, not arbitrary-perspective AR screenshots or a nonexistent original 3D scene. Physical phone acceptance remains pending. See [profile details](ICE_HOCKEY.md) and [measured results](evidence/ice-hockey-faithful-validation.json).

## Earlier ROM-opening crash regression

[Corrected build #11](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39299234767) passed for `1ce8b7674034bc6724178c5ab904bf989b011cc5`. The iOS ARM64 native stack budget and archive passed. All 390 source files match the built Git blobs; IPA digest/CRC, resources and commercial-ROM exclusion verify. See [the full verification record](evidence/rom-opening-build.json).

The user reports build #9 crashed immediately on opening any ROM, before the camera/game view. The Adventure cache reset used a 605,408-byte ARM64 stack frame on the common load/reset/restore path, exceeding a usual 512 KB worker stack. Windows optimized that temporary away, and the earlier successful host tests/archive did not validate this startup path.

The correction invalidates cache entries in place and reuses raster working storage outside the stack. A 64 KB native frame budget now guards the actual target compilation. All 28 local test methods pass, including the native suites on a 512 KB worker. Three load/reset/restore cycles passed for the demo and all five supplied ROMs on that worker. Hosted Linux passes 26 methods and skips the two private-ROM methods; hosted Mac constrained-stack suites and the real Swift loading queue pass. Physical phone retesting of the corrected build remains pending. See [root cause and regression coverage](ROM_LOADING_FIX.md).

## Earlier Adventure update

[Build #9](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39296849358) passed for commit `7bf94a0c4963b66e651923573a99f6f4b8f5f512`. Xcode 16.4 compiled the 102-source native library and archived the arm64 app. Hosted Swift presentation/adapter and encrypted-transport checks passed. The downloaded IPA passes digest/CRC/resource/device checks, and all 383 matching-source files equal the built commit. No commercial ROM is bundled. See [the build audit](evidence/adventure-build.json).

The supplied NTSC ROM now selects the measured [Adventure profile](ADVENTURE.md). It separates the player, gates, creatures and items from visible walls using read-only RAM and graphics from the user cartridge. A 4,373-frame ordinary-input run exercised all three game selections across five room IDs, including key pickup, castle entry, sword pickup/drop and creature encounters. There were no geometry drops; 15 startup/transition frames used generic interpretation. Reconstruction preserved serialized emulator state. All 27 local native methods pass; hosted Ubuntu passes 25 and skips the two private-ROM methods. See [captured host measurements](evidence/adventure-validation.json).

Tabletop, dragon and final vertical renders were inspected offline. Vertical mode moves gameplay silhouettes in front of castle relief so they stay visible. Physical Adventure acceptance, complete matches and real-game coverage of bridge/chalice/magnet remain pending. No commercial ROM or commercial sprite/room masks are bundled.

## Earlier Vertical world and Ice Hockey update

[Build #7](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39293266183) passed for commit `2d0aa5b26db9d01fc798c6567aa4aa59c3ede368`. The 101-source native build passes all 20 local tests, including the supplied Ice Hockey ROM; hosted Ubuntu passes 19 and skips that private-ROM test. Hosted Swift tests cover legacy settings migration, upright bottom-edge placement/tilt, side-view profiles, skater orientation and synchronized presentation, plus the existing encrypted transport regressions. Xcode 16.4 archives the arm64 iPhone app successfully. All 374 source files in the downloaded ZIP match the built commit; IPA CRC, digest, six profiles and commercial-ROM exclusion pass. See [the verification record](evidence/ice-hockey-build.json).

Vertical mode stands the game world upright while keeping horizontal-surface AR placement. The exact-hash [Ice Hockey profile](ICE_HOCKEY.md) reconstructs a thin rink, raised boards, goal frames/nets, multicolor standing skaters and visible puck candidates. A 3,600-frame local run produced no dropped geometry; four head parts appeared in 3,588 frames. Overlaps, falls and hidden puck pixels remain ambiguous. Offline tabletop/vertical geometry renders were inspected; the new features have not yet been tested on an iPhone.

## Earlier Wi-Fi multiplayer update

The user reports successful AR operation of the earlier build with the included test ROM and their own Atari ROMs on their phone. No device model, performance log or exact commercial ROM identities were supplied, so the detailed acceptance rows and commercial-profile certification remain open.

Private Wi-Fi multiplayer now implements room-code joining, host-only emulation, independent Player 2 joystick/paddle inputs, scene/original-pixel/audio streaming and shared-table ARWorldMap alignment. The native suite now has 16 passing methods, including independent joystick-port/button probes, an independent network audio tap and guest playback, and the updated homebrew's Player 2 actor. Hosted network/build verification is tracked separately from physical two-phone testing. See [LOCAL_MULTIPLAYER.md](LOCAL_MULTIPLAYER.md) and [the pending two-phone acceptance checks](DEVICE_TESTING.md#two-phone-multiplayer-acceptance-pending).

[Multiplayer build #5](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39185044963) passed for commit `e14eb626c5e9b11c9852c9763ba2d8e113e737ad`: 16 hosted native tests, protocol validation and real TLS-PSK loopback connections, followed by the arm64 iPhone archive. The downloaded IPA's digest, device executable, local-network/Bonjour permission keys, two-player fixture and ZIP CRC were verified on Windows. All 365 source ZIP files exactly match that built commit. See [the machine-readable record](evidence/multiplayer-build.json), [hosted multiplayer output](evidence/multiplayer-tests.txt) and [native runner output](evidence/multiplayer-native-tests.txt). Loopback tests do not establish physical Wi-Fi discovery, shared-table alignment, device latency or audio quality.

## Executed tests

Original baseline evidence below: Windows x64, portable Zig 0.13.0, Python 3.13.13 from the existing Blender installation. The pinned Stella tree contains 286 verified files; the native build compiles 100 sources. Twelve tests execute against the real compiled DLL:

1. Original test ROM rebuild produces identical bytes and matches its profile hash.
2. Real 160-pixel-wide video, RAM, expected TIA colors, requested cadence and 31,400 Hz audio metadata.
3. Joystick Right and Fire simultaneously change the ROM's RAM and produce core audio.
4. Generated boxes have positive three-dimensional volume and separate object roles.
5. Save/restore replay yields byte-identical framebuffer and RAM.
6. A ROM room change changes profile scene ID and wall color; an unchanged sprite reuses its ID and mesh hash.
7. Repeated cartridge loading and physical controller changes execute without crashing.
8. Reconstruction enabled versus disabled produces identical emulated RAM and framebuffer.
9. The test cartridge's TIA playfield collision flag appears in RAM.
10. An original paddle probe verifies both capacitor input channels and both Fire buttons through TIA/RIOT reads. Switching back to joystick clears stale analog events.
11. Synthetic ring geometry preserves its hole; removing its pixels removes its object immediately.
12. HUD exclusion, geometry-budget reporting and upright extrusion behave as expected. Some of these assertions share a test method; the unittest runner reports twelve methods total.

See [the saved runner output](evidence/native-tests.txt) and [the machine-readable capture](evidence/validation-report.json). Headless throughput and reconstruction timings measure this Windows process, including Python capture overhead. They are not iPhone or AR frame-rate claims.

### Hosted build verified October 18, 2026 (America/New_York)

[GitHub Actions run #1](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39179809317) passed for commit `f8a9bdda02981891afbccfe0e8dc22a050fc2229`. Ubuntu 24.04 built the 100-source native core, verified all 286 vendor files and passed all 12 tests. The `macos-15` job used Xcode 16.4 (16F6), the iPhoneOS 18.5 SDK and an iOS 16.0 deployment target to build the native arm64 library and archive the Swift application. The first Apple build succeeded without source fixes.

The downloaded IPA passed ZIP CRC checks and `scripts/verify_ipa.py` again on Windows: arm64 Mach-O, iPhoneOS platform, original homebrew cartridge, five conversion profiles and unsigned status. Its SHA-256 matches the hosted manifest. Every one of the 357 files in the matching source ZIP equals the built commit's Git blob. See [the build verification record](evidence/ios-build.json) and [the original artifact manifest](evidence/ios-artifact-manifest.json).

Xcode reported two nonblocking warnings: skipped AppIntents metadata extraction because that framework is unused, and the interface-orientation/full-screen warning. No Swift compile errors were reported. Signing, installation, runtime audio/input and physical AR acceptance have not been tested.

## ROM status

| Cartridge | Identification | Emulation tested here | 3D interpretation | iPhone/AR |
|---|---|---|---|---|
| Tabletop Test | Exact generated SHA-256 | Yes, real core | Development profile, native geometry inspected | Pending |
| Paddle Probe | Original source assembled by test | Yes | Hardware-input fixture; no game profile | Pending |
| Adventure NTSC | Exact supplied SHA-256 and Stella MD5 | Yes, 4,373 frames and save-byte invariance | Experimental measured rooms/castles, gates, player, creatures/items; incomplete gameplay coverage | New profile pending |
| Combat NTSC | Stella database MD5 | No ROM supplied | Experimental maze/vehicle/projectile candidates | Pending |
| Breakout NTSC | Two Stella database MD5s | No ROM supplied | Experimental paddle/ball/brick formations; adjacent bricks can merge | Pending |
| Pitfall! NTSC | Stella database MD5 | No ROM supplied | Experimental upright layers; semantic objects/animation incomplete | Pending |
| Ice Hockey NTSC | Exact supplied SHA-256 and Stella MD5 | Yes, 3,600 complete-frame pixel matches and save-byte invariance | Original-art voxel relief including live scores/timer/logo; no authored rink details | New profile pending |
| Unknown raw ROM | Computed SHA-256/MD5 | Depends on core/cart | Generic color components and heuristic depth, no accuracy guarantee | Pending |

The emulator's broad cartridge support is inherited from Stella; the original fixtures and exact supplied Ice Hockey and Adventure revisions were exercised here. Its older baseline does not imply current Stella accuracy or compatibility with every modern homebrew cart. The frontend intentionally excludes streaming MovieCart and data over 1 MB. Generic output may lose same-color objects against backgrounds, split multicolor sprites, merge overlapping shapes, misclassify scenery or flicker with multiplexed sprites.

## Requested milestones

| Milestone | Result |
|---|---|
| 1. iOS emulator with ROM import, controls and audio | Native core/inputs/audio tested on Windows and hosted Linux. SwiftUI/audio source Apple-compiled; device acceptance pending. |
| 2. Graphics analysis and TIA capture | Implemented and host-tested. TIA layer attribution and game-specific semantic trace interpretation remain future work. |
| 3. Homebrew 3D prototype | Real ROM -> Stella -> separated volumetric geometry works on host. Offline mesh render inspected; live local viewer endpoint verified. Browser rendering could not be inspected in this session. |
| 4. Complete real-game profile | Measured Ice Hockey and Adventure adapters implemented/tested with supplied ROMs. Experimental; complete gameplay and iPhone acceptance remain open. |
| 5. Tabletop AR | Native placement/anchor/camera/gesture source Apple-compiled; device testing pending. |
| 6. Additional profiles | Five experimental commercial profiles including measured Ice Hockey and Adventure adapters; zero full-support certifications. |
| 7. Automated IPA | Source published; hosted native tests and unsigned device archive passed. IPA and matching source downloaded and verified. Re-signing and device installation remain pending. |
| 8. Physical testing and optimization | Test procedure supplied; no phone measurements or results claimed. |

## Remaining implementation and acceptance work

- Re-sign the verified unsigned IPA, then verify audio pacing, state restoration, UIKit/SwiftUI gestures and lifecycle on an actual supported iPhone.
- Extend Ice Hockey and Adventure through complete matches, remaining objects/rooms and physical iPhone checks before considering full support; measure and author further games separately.
- Improve segmentation for flicker, multicolor actors, overlaps and same-color brick boundaries; add precise per-pixel TIA object provenance if necessary.
- Add profile-specific HUD extraction, richer geometry/animation mappings, smooth room transitions, optional rewind and validated game-speed controls. Rewind and speed changes are currently not exposed.
- Measure device power, memory, input latency and render time, then adjust mesh budgets. Real table shadows, real-world occlusion, and optional visual filters remain unverified or unimplemented.
- Verify signed export, free-account re-signing and installation/refresh on the user's device. An unsigned archive package alone cannot launch on iOS.
