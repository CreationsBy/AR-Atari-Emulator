# Resume with phone test of original-art Ice Hockey

## Completed October 19, 2026 (America/New_York)

The user requested score/timer/Activision logo in the 3D world and removal of invented scenery. Ice Hockey now selects `ice-hockey-ntsc-v2` / `iceHockeyNTSCv2` for the same exact supplied NTSC hashes. Reopen the ROM after updating. The profile ID changed; v1 profile-bound saves may be rejected. The imported ROM library is unchanged.

The entire live original frame is pixel-derived voxel geometry, including both scores, timer, logo, rink/goal openings, skater silhouettes, sticks and visible puck. Authored boards/posts/net strands, fixed rink geometry, RAM-derived standing poses and presentation pedestal are removed. All artwork retains source pixel positions/shapes/colors; only extrusion depth is added. Text uses shallow relief to preserve tiny glyph holes from oblique angles. The optional original-frame comparison remains; the automatic separate score HUD is disabled.

Tabletop and Vertical use one common raster plane. Ice Hockey actors/text are no longer independently counterrotated; Adventure's transforms remain intact. This profile uses unlit RealityKit colors. The material existential must be qualified `any RealityKit.Material` because SwiftUI also defines Material. Same-build Wi-Fi guests apply the same rendering rules.

## Verified current build

- [GitHub Actions build #14](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39320563294) passed.
- Built commit: `8ac791b6c03a40c34937a09e2e87e52d5eead113`.
- All 32 local native methods pass. Hosted Ubuntu passes 30 and skips the two private-ROM methods. Hosted Mac constrained suites pass 29 and skip two; actual Swift loading queue, profile/HUD/plane checks and TLS regressions pass.
- Xcode 16.4, iPhoneOS 18.5 SDK, iOS 16 target: ARM64 native stack budget, unlit renderer compilation and unsigned archive pass.
- A 3,600-frame supplied-ROM run matched all 120,960,000 RGBA source pixels exactly under independent box-footprint projection, with zero missing/extra/overlapping footprints or geometry drops. Peak: 68 objects / 389 boxes, within both quality presets.
- Score/timer geometry exists in 3,598 frames; logo in 3,597; startup blanks remain blank. Glyph updates remove old pixels immediately; no unseen puck or pose is predicted.
- Artifact digests/CRCs pass. All 401 matching-source files equal built Git blobs; six profiles, original fixture and permissions verify. Commercial ROMs are excluded.
- Full record: [evidence/ice-hockey-faithful-build.json](evidence/ice-hockey-faithful-build.json).

Accuracy scope: exact original-raster footprints/colors in checked frames. The original is 2D; depth/perspective/antialiasing are not original 3D ground truth. Do not claim arbitrary AR camera screenshots are pixel-identical or that physical acceptance passed.

## Deliverables and next action

- IPA: `build/deliverables/AtariDiorama-UNSIGNED-requires-resigning.ipa`
- Exact matching source: `build/deliverables/AtariDiorama-source.zip`; manifest alongside.
- Downloads and full logs: `build/github-run-14/`. Earlier #11/#9/#7/#5/#1 retained separately.
- IPA SHA-256: `82368c916387b2e48d3d7eb0d0fdbf57b38201236fee66d682f77649251361c5`.

[IPA/source artifact](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39320563294/artifacts/12220630598) expires November 2, 2026 at 3:38 PM EST (2026-11-02T20:38:56Z). Local copies remain available. Later documentation/evidence commits are separate from the exact source ZIP.

Re-sign/install, reopen Ice Hockey and test both orientations: world score/timer/logo, readable changing glyphs, original rink openings/poses/colors and no added boards/nets/pedestal. Check the optional original comparison, ambient changes and Reset/save/load. Physical phone results are not yet reported. Install the same build on both phones for shared presentation; use game 2 or 4 and Reset for two-player Ice Hockey.

Local `build/ice-hockey-faithful/` contains the report, raw/projection PNG pairs, scenes and inspected tabletop/vertical offline renders. They are not AR screenshots. `scripts/capture_ice_hockey.py` reproduces the checks; `scripts/verify_scene_pixels.py` is the independent projector. Earlier v1 captures remain at `build/ice-hockey/`. See [ICE_HOCKEY.md](ICE_HOCKEY.md) and [DEVICE_TESTING.md](DEVICE_TESTING.md).

## Preserved crash fix and other features

Build #9 had crashed immediately when opening any ROM. The common Adventure aggregate reset allocated 605,408 stack bytes under Darwin ARM64. The fix invalidates entries in place and keeps raster workspace off stack; the reset no longer makes that allocation. The app-authored native 64 KB frame limit and 512 KB worker regression remain enabled. Do not restore aggregate assignment to the large cached sprite array. See [ROM_LOADING_FIX.md](ROM_LOADING_FIX.md). The previous baseline AR worked according to the user; that is not new-profile acceptance.

Adventure remains its measured experimental adapter; stock Adventure is single-player. P1-host/P2-guest same-Wi-Fi multiplayer, no guest ROM, original audio and shared ARWorldMap remain implemented. Physical discovery/alignment/latency/audio acceptance is pending. See [ADVENTURE.md](ADVENTURE.md) and [LOCAL_MULTIPLAYER.md](LOCAL_MULTIPLAYER.md).

## Workspace / tools

Root: `C:\Users\spagh\OneDrive\Documents\Ai projects\games\AR Atari 2600`.
Git: `.tools/mingit/cmd/git.exe`. Connected GitHub plugin handles writes/runs/downloads; CLI GitHub remains unauthenticated. Never extract credentials. Publish through connector and public Git fetch. Use per-command safe.directory for this exact root; Git metadata writes may need escalation.

Python: `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`; Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`. Native DLL rebuilt; preview is stopped. `scripts/Start-Preview.ps1` restarts it if needed. Do not repeat broad passing checks without new changes/failures.

Keep supplied commercial cartridges in ignored `roms/`; never upload or bundle them.
