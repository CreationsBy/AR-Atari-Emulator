# Resume with phone retest of corrected ROM-opening build

## Crash fix completed October 19, 2026 (America/New_York)

The user reports that the Adventure build #9 crashed immediately when selecting any ROM, before the camera/game view. The unconditional `ad_reset_adventure` aggregate cache assignment generated a 605,408-byte Darwin ARM64 stack frame. It is called during common load/reset/restore even for demo/generic ROMs, exceeding a usual 512 KB secondary-thread stack. Windows optimized this away, so earlier tests missed it. Do not call build #9 device-working.

The fix invalidates cache entries in place and reuses raster workspace outside the stack. Reused masks are explicitly cleared before capture. Cross-compiled ARM64 reset now has no explicit stack reservation; reconstruction falls from 205,008 to 3,376 bytes. This is compiler evidence, not a phone crash trace. App-authored native functions now have an enforced 64 KB stack-frame budget on host and actual iOS target builds (GCC/Clang-specific flags). See [ROM_LOADING_FIX.md](ROM_LOADING_FIX.md).

## Verified current build

- [Build #11](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39299234767) passed.
- Built commit: `1ce8b7674034bc6724178c5ab904bf989b011cc5`.
- Local: 28 methods pass, including native suites in a child process with a 512 KB worker stack. Three load/reset/restore cycles also pass for demo, Adventure, Ice Hockey, Bowling, Boxing and Frogger on that worker.
- Hosted Linux: 26 methods pass, two private-ROM tests skip. Hosted Mac: 25 native methods pass and two skip on a 512 KB worker; four actual Swift EmulationEngine queue load/reset/first-frame/save/restore cycles pass, as do presentation/protocol/TLS regressions.
- Xcode 16.4, iPhoneOS 18.5 SDK, iOS 16 deployment target: ARM64 native frame budget, archive and unsigned IPA pass. The native library has 102 sources.
- All artifact download digests and source/IPA CRCs pass. All 390 source files match built Git blobs; six profiles, original fixture and camera/network resources verify. Commercial ROMs are excluded.
- Evidence: [evidence/rom-opening-build.json](evidence/rom-opening-build.json).

## Deliverables and next action

- Corrected IPA: `build/deliverables/AtariDiorama-UNSIGNED-requires-resigning.ipa`
- Matching source: `build/deliverables/AtariDiorama-source.zip`; manifest alongside.
- Complete downloads/logs: `build/github-run-11/`. Older #9/#7/#5/#1 retained separately.
- IPA SHA-256: `6e71f9dfbea06138fbdd8e71019c840ba4d40aa34074158d305d4a36f2894bce`.

[Corrected IPA/source artifact](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39299234767/artifacts/12212140538) expires November 2, 2026 at 1:05 PM EST (2026-11-02T18:05:57Z). Local copies remain available. Documentation/evidence commits after the built commit are intentionally separate from the exact matching-source ZIP.

Re-sign/install the corrected build over the existing app, preserving its library. Retest opening the demo and supplied cartridges on the user's phone first. Physical retest has NOT yet been reported. Do not claim device acceptance from the compiler/host checks. The earlier baseline single-device AR had worked according to the user, but build #9 regressed ROM opening.

## Features preserved

Settings → Miniature world → World orientation offers Tabletop / Vertical (upright 3D world, not portrait orientation). Adventure's measured `adventure-ntsc-v2` adapter uses read-only visible pixels/RAM/private cartridge graphics for rooms/castles, player, gates, creatures and items. Vertical foreground placement keeps gameplay silhouettes visible; Tabletop positions remain unchanged. Ice Hockey retains its measured rink/skater/puck profile. Both are experimental pending broad gameplay and physical acceptance. See [ADVENTURE.md](ADVENTURE.md) and [ICE_HOCKEY.md](ICE_HOCKEY.md).

Private same-Wi-Fi multiplayer remains: P1 owns ROM/emulation; P2 joins by private code, receives geometry/pixels/audio and controls port 2 without a ROM. Shared ARWorldMap supports independent camera viewpoints. Install the same current build on both phones. Stock Adventure is single-player; its guest can spectate, not control a second adventurer. Physical discovery/alignment/latency/audio remain pending; see [DEVICE_TESTING.md](DEVICE_TESTING.md).

## Workspace / tools

Root: `C:\Users\spagh\OneDrive\Documents\Ai projects\games\AR Atari 2600`.
Git: `.tools/mingit/cmd/git.exe`. Connected GitHub plugin handles writes/runs/downloads; CLI GitHub remains unauthenticated. Never extract credentials. Publish through connector, public Git fetch to sync main. Use per-command safe.directory for this exact root; Git metadata writes may require escalation. Original branch remains `local-before-github-upload`.

Python: `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`. Native DLL rebuilt; preview is stopped. Restart `scripts/Start-Preview.ps1` if needed. Local crash investigation/evidence lives in ignored `build/crash-fix/`. The two direct worker invocations are `python -m unittest discover -s tests -v` and `python tests/test_worker_stack.py --worker`.

Keep supplied commercial cartridges in ignored `roms/`; never upload or bundle them. Do not repeat broad passing tests without new changes/failures.
