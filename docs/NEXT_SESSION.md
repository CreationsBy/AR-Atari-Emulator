# Resume with physical Vertical / Ice Hockey and two-iPhone tests

## Completed October 19, 2026 (America/New_York)

The user clarified that vertical means an **upright 3D world**, not portrait app orientation. Settings → Miniature world → World orientation offers Tabletop / Vertical. Vertical pivots on the bottom edge on the existing horizontal table/floor anchor, including yaw/tilt. Side-view profiles are not rotated twice; Ice Hockey skater silhouettes stay upright. Saved preferences migrate without loss; Tabletop remains default. The host shares orientation with Player 2. Install the same new build on both phones (wire protocol version 2).

The first measured commercial profile targets the supplied 4 KB Ice Hockey NTSC ROM:
- SHA-256: `fc8b861d9cf9c9d5f7f7677f22b39d512d249697b69c1e7dcf238c5dc8f44b60`
- MD5: `a4c08c4994eb9d24fb78be1793e82e26`
- Profile `ice-hockey-ntsc-v1`; native adapter `iceHockeyNTSCv1`.

It reads original pixels and RIOT skater-position slots to reconstruct a thin ice surface with goal openings, raised boards, goal frames/nets, standing multicolor skaters and visible puck candidates. It never changes game state. The profile is experimental: overlaps, falls, hidden pucks, complete matches and physical iPhone results need coverage. See [ICE_HOCKEY.md](ICE_HOCKEY.md). Import/reopen the ROM to select it automatically.

Earlier same-Wi-Fi multiplayer remains implemented: P1 owns ROM/emulation; P2 joins by private code, receives geometry/original pixels/audio and controls port 2 without a ROM. Bonjour + encrypted TLS-PSK use Wi-Fi only. ARWorldMap sharing aligns the physical diorama with independent camera views. For Ice Hockey two-player play, select game 2 or 4 and Reset.

## Verified build

- [GitHub Actions run #7](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39293266183) passed.
- Built commit: `2d0aa5b26db9d01fc798c6567aa4aa59c3ede368`.
- Twenty local native tests pass including the supplied ROM and reconstruction save-byte invariance. Hosted Ubuntu passes 19 and skips the private commercial-ROM test. Native build: 101 sources; 286 pinned vendor files verify.
- A 3,600-frame real-ROM host run with both ports active produced zero geometry drops; four head components appeared in 3,588 frames, fewer in nine ambiguous frames, none in three startup frames. These counts are not perfect recognition or iPhone performance.
- Hosted Swift tests pass: settings migration, vertical bottom edge/tilt, side-view handling, upright skaters, wire roundtrip/version rejection and existing real TLS-PSK endpoint regressions.
- Xcode 16.4 (16F6), iPhoneOS 18.5 SDK, iOS 16 deployment target: arm64 archive and unsigned packaging passed.
- Artifact download digests and IPA/source CRCs pass. All 374 source files match built Git blobs. Six profiles, original fixture and camera/network keys verify; no commercial ROM is bundled.
- Full record: [evidence/ice-hockey-build.json](evidence/ice-hockey-build.json).
- Offline renders inspected: `build/ice-hockey/tabletop/reconstruction-3d.png` and `build/ice-hockey/vertical/reconstruction-3d.png`. They show captured geometry, not AR screenshots.

The user reported earlier single-device AR working with the test ROM and their Atari ROMs. The new Vertical/Ice Hockey features and two-phone discovery/alignment/latency/audio have not been physically tested. Do not claim those acceptance results or full commercial-profile support.

## Deliverables

- Latest IPA: `build/deliverables/AtariDiorama-UNSIGNED-requires-resigning.ipa`
- Manifest: `build/deliverables/artifact-manifest.json`
- Exact matching source for build #7: `build/deliverables/AtariDiorama-source.zip`
- Downloads, Apple/test logs and native evidence: `build/github-run-7/`
- Older builds: `build/github-run-5/` and `build/github-run-1/`.
- IPA SHA-256: `b6213c24a3c6b98fe82fb7beae07f167c15f334cc26e6cd94eb340207f850051`.

[IPA/source artifact](https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39293266183/artifacts/12205723611) expires November 2, 2026 at 12:24 PM EST (2026-11-02T17:24:32Z). Local copies remain available. Later documentation-only evidence commits are separate from the matching-source ZIP.

## Next action

Re-sign/install the IPA, reopen Ice Hockey and try Tabletop / Vertical while playing and paused. Check falls, overlaps, goals and save/load against original pixels. Then install the same build on both phones and follow [DEVICE_TESTING.md](DEVICE_TESTING.md) and [LOCAL_MULTIPLAYER.md](LOCAL_MULTIPLAYER.md). Only the host needs the cartridge; both need Camera/Local Network access and the same Wi-Fi without client isolation.

Keep supplied commercial cartridges in ignored `roms/`; never upload them or bundle them in app/source packages.

## Workspace and tools

Root: `C:\Users\spagh\OneDrive\Documents\Ai projects\games\AR Atari 2600`.
Portable Git: `.tools/mingit/cmd/git.exe`; portable GitHub CLI: `.tools/gh/bin/gh.exe`.
Python: `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`.
Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.

The GitHub plugin handles source writes, runs and artifact downloads. CLI GitHub remains unauthenticated; do not extract credentials. Publish through the connector and public Git fetch to sync main. Original history remains on `local-before-github-upload`. Git metadata writes may require escalation; use per-command safe.directory for this exact workspace only.

The preview server is stopped so the native DLL can rebuild. Restart with `scripts/Start-Preview.ps1` if needed. Capture with `scripts/capture_ice_hockey.py`. Blender evidence script accepts --input / --output / --upright after its -- separator. Do not repeat passing broad tests unless new changes or failures justify them.
