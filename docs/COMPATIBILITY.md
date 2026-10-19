# Compatibility and milestone results

Recorded 2026-10-18. This is a development prototype, not a completed or certified iOS emulator release.

## Executed tests

Windows x64, portable Zig 0.13.0, Python 3.13.13 from the existing Blender installation. The pinned Stella tree contains 286 verified files; the native build compiles 100 sources. Twelve tests execute against the real compiled DLL:

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
| Adventure NTSC | Stella database MD5 | No ROM supplied | Experimental size rules; semantic castles/dragons/items incomplete | Pending |
| Combat NTSC | Stella database MD5 | No ROM supplied | Experimental maze/vehicle/projectile candidates | Pending |
| Breakout NTSC | Two Stella database MD5s | No ROM supplied | Experimental paddle/ball/brick formations; adjacent bricks can merge | Pending |
| Pitfall! NTSC | Stella database MD5 | No ROM supplied | Experimental upright layers; semantic objects/animation incomplete | Pending |
| Unknown raw ROM | Computed SHA-256/MD5 | Depends on core/cart | Generic color components and heuristic depth, no accuracy guarantee | Pending |

The emulator's broad cartridge support is inherited from Stella; only the original fixtures were exercised here. Its older baseline does not imply current Stella accuracy or compatibility with every modern homebrew cart. The frontend intentionally excludes streaming MovieCart and data over 1 MB. Generic output may lose same-color objects against backgrounds, split multicolor sprites, merge overlapping shapes, misclassify scenery or flicker with multiplexed sprites.

## Requested milestones

| Milestone | Result |
|---|---|
| 1. iOS emulator with ROM import, controls and audio | Native core/inputs/audio tested on Windows and hosted Linux. SwiftUI/audio source Apple-compiled; device acceptance pending. |
| 2. Graphics analysis and TIA capture | Implemented and host-tested. TIA layer attribution and game-specific semantic trace interpretation remain future work. |
| 3. Homebrew 3D prototype | Real ROM -> Stella -> separated volumetric geometry works on host. Offline mesh render inspected; live local viewer endpoint verified. Browser rendering could not be inspected in this session. |
| 4. Complete real-game profile | Not achieved. Experimental JSON candidates exist; a user-supplied ROM and gameplay testing are required. |
| 5. Tabletop AR | Native placement/anchor/camera/gesture source Apple-compiled; device testing pending. |
| 6. Additional profiles | Four experimental candidates, zero validated commercial full-support profiles. |
| 7. Automated IPA | Source published; hosted native tests and unsigned device archive passed. IPA and matching source downloaded and verified. Re-signing and device installation remain pending. |
| 8. Physical testing and optimization | Test procedure supplied; no phone measurements or results claimed. |

## Remaining implementation and acceptance work

- Re-sign the verified unsigned IPA, then verify audio pacing, state restoration, UIKit/SwiftUI gestures and lifecycle on an actual supported iPhone.
- Validate at least one real-game profile against a user-provided ROM and author semantic object/room rules before marking it fully supported.
- Improve segmentation for flicker, multicolor actors, overlaps and same-color brick boundaries; add precise per-pixel TIA object provenance if necessary.
- Add profile-specific HUD extraction, richer geometry/animation mappings, smooth room transitions, optional rewind and validated game-speed controls. Rewind and speed changes are currently not exposed.
- Measure device power, memory, input latency and render time, then adjust mesh budgets. Real table shadows, real-world occlusion, and optional visual filters remain unverified or unimplemented.
- Verify signed export, free-account re-signing and installation/refresh on the user's device. An unsigned archive package alone cannot launch on iOS.
