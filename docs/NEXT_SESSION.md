# Resume with the two-iPhone multiplayer device test

## Completed October 18, 2026 (America/New_York)

Private, same-Wi-Fi multiplayer is implemented and built. Player 1 hosts the ROM and runs Stella; Player 2 enters a private eight-character code, receives scene/original pixels/original audio, and controls the second joystick or paddle without a ROM. Bonjour discovery and TLS-PSK use Wi-Fi only; no server, cellular route, Bluetooth transport or ROM transfer is used.

ARWorldMap sharing aligns the same physical diorama while each phone renders from its own camera. The host controls shared placement/size/rotation/tilt. Input heartbeats, a 500 ms input timeout, bounded frame/audio queues, disconnect handling and room rejoining are implemented.

The included Tabletop Test ROM now lets Player 2 take over the red actor on their first input; Player 1 controls blue. Each player's Fire produces its own original TIA tone. Reset returns the red actor to autonomous movement until another P2 input.

## Verified build

- GitHub Actions run #5 passed: https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39185044963.
- Built commit: `e14eb626c5e9b11c9852c9763ba2d8e113e737ad`.
- All 16 native tests pass on Windows and hosted Ubuntu, including both joystick ports, both paddle channels/buttons, the network audio tap, guest playback with no initialized core/ROM, and real 6507 P2 demo gameplay.
- Hosted Mac tests passed: room-code/protocol bounds, actual encrypted two-endpoint TLS, wrong-code rejection, bidirectional input/geometry/pixels/PCM/map blobs, ACK backpressure, retained audio bounds, third-peer rejection and disconnect/rejoin.
- Xcode 16.4 (16F6), iPhoneOS 18.5 SDK, iOS 16 deployment target: arm64 iPhone archive and unsigned packaging passed.
- Downloaded all artifacts, verified their SHA-256 digests and IPA CRC/structure/device executable/resources/local-network permissions, and confirmed all 365 matching-source ZIP files equal the built commit's Git blobs.
- Full verification: `docs/evidence/multiplayer-build.json`.

The user reports the earlier single-device build's AR worked with the test ROM and their Atari ROMs on their phone. That does not validate this new multiplayer build's real Wi-Fi discovery, shared-table alignment, latency or audio quality. Those require two physical iPhones.

## Deliverables

- Latest IPA: `build/deliverables/AtariDiorama-UNSIGNED-requires-resigning.ipa`
- Latest manifest: `build/deliverables/artifact-manifest.json`
- Exact matching source for build #5: `build/deliverables/AtariDiorama-source.zip`
- Complete downloads, extracted Apple/test logs and native evidence: `build/github-run-5/`
- Earlier build #1 remains under `build/github-run-1/` for comparison.

IPA SHA-256: `d5a479768921ef092e5b9eaf1cfe465db845f13ee1ad85d4a8a53bb97e6359dc`.

IPA/source artifact: https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39185044963/artifacts/12157618280.
It expires November 1, 2026, 8:25 PM EST (2026-11-02T01:25:18Z). The local copy remains available. Later documentation evidence commits are separate from the matching source ZIP.

## Next action

Re-sign and install the same new build on both iPhones. Follow `docs/LOCAL_MULTIPLAYER.md` and the two-phone checks in `docs/DEVICE_TESTING.md`. Only the host needs the cartridge. Both phones must allow Camera and Local Network access and use Wi-Fi without client isolation. Have the host place and scan a textured table, then have Player 2 aim at the same area until alignment finishes.

Never claim the unsigned IPA can launch without re-signing, or that physical multiplayer/AR acceptance passed without results. Do not label the commercial JSON profiles fully validated based on the user's general smoke report.

## Workspace and tools

Root: `C:\Users\spagh\OneDrive\Documents\Ai projects\games\AR Atari 2600`.
Portable Git: `.tools/mingit/cmd/git.exe`; portable GitHub CLI: `.tools/gh/bin/gh.exe`.
Python: `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`.

The GitHub plugin is connected and supports source writes, run inspection and artifact downloads. Terminal GitHub CLI is still unauthenticated. Do not extract credentials. Publish through the connector, and use public Git fetches to synchronize local `main`, which tracks `origin/main`. The original local pre-upload history remains at `local-before-github-upload`.

Git metadata writes may require sandbox escalation. Use a per-command `-c safe.directory=<this exact workspace>` if needed, not a global ownership bypass.

The old preview server was stopped to unlock its DLL; the native library was rebuilt and tested. Restart with `scripts/Start-Preview.ps1` if needed.

## Build debugging notes

The initial networking compile needed explicit main-actor hops from Network.framework Sendable callbacks. Hosted transport testing needed default IP parameters with a direct loopback endpoint, plus waiting for a ready listener with an assigned nonzero port; using a loopback interface requirement prevented connections. The app still constructs the transport with a strict Wi-Fi interface requirement. These fixes and all tests are in the successful built commit.

Do not repeat broad native checks unless new changes/failures justify them. Device acceptance is the next milestone.
