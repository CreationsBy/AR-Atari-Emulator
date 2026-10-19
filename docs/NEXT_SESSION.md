# Resume with device signing and acceptance

## Completed October 18, 2026 (America/New_York)

- Source and the actual workflow are published on `main` at https://github.com/CreationsBy/AR-Atari-Emulator.
- GitHub Actions unsigned build #1 passed: https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39179809317.
- Built commit: `f8a9bdda02981891afbccfe0e8dc22a050fc2229`; source tree: `89d783e39848460ef65b309d6aca7a0fefb64695`.
- Hosted Ubuntu built all 100 native sources, verified all 286 vendor files, and passed all 12 native test methods.
- Hosted macOS successfully built the arm64 native library and Swift application archive with Xcode 16.4 (16F6), iPhoneOS 18.5 SDK, and iOS 16.0 deployment target.
- The first Apple build passed without source fixes. Two nonblocking warnings are recorded in `docs/evidence/ios-build.json`.
- Downloaded the IPA, matching source ZIP, native evidence, Apple logs and result bundle. Verified GitHub artifact ZIP digests, IPA ZIP CRC, arm64 Mach-O/device platform/resources, five profiles and unsigned status. All 357 source ZIP files exactly matched the built commit's Git blobs.

## Deliverables

- `build/deliverables/AtariDiorama-UNSIGNED-requires-resigning.ipa`
- `build/deliverables/artifact-manifest.json`
- `build/deliverables/AtariDiorama-source.zip` (exact source from build #1; later documentation updates are separate)
- `build/deliverables/AtariDiorama-Windows-preview.zip` (previous host preview)
- Original downloads, extracted evidence and Apple logs: `build/github-run-1/`
- Committed verification record: `docs/evidence/ios-build.json`
- Committed original IPA manifest: `docs/evidence/ios-artifact-manifest.json`

IPA SHA-256: `ce86039e85bc5bc2d76b19d6ec4ce4bf13201b8d9b3a7ef9c0f2f39b97293c06`.

Hosted IPA/source artifact: https://github.com/CreationsBy/AR-Atari-Emulator/actions/runs/39179809317/artifacts/12155528893.
It expires November 1, 2026, 7:15 PM EST (2026-11-02T00:15:31Z). The local copy remains available.

## Next milestone

Re-sign the unsigned IPA using the user's chosen signing tool, install it on a supported iPhone and execute `docs/DEVICE_TESTING.md`. `docs/BUILD_WINDOWS.md` documents the Windows signing/sideloading routes. No Apple credentials were used for the build. Never claim this unsigned package launches without signing, or that physical iPhone/AR behavior has been tested.

The four commercial-game profiles remain explicitly unvalidated experiments. Only original homebrew fixtures are included. Do not repeat broad native testing unless a new change or failure justifies it.

## Workspace and GitHub access

Root: `C:\Users\spagh\OneDrive\Documents\Ai projects\games\AR Atari 2600`.
Portable Git: `.tools/mingit/cmd/git.exe`; portable CLI: `.tools/gh/bin/gh.exe`.
The GitHub plugin is connected and supports repository writes, workflow inspection and artifact downloads. Terminal GitHub CLI is still unauthenticated; do not assume the plugin authenticates Git.

The plugin published an initial README commit followed by the exact committed source tree. Local `main` was aligned to the identical remote tree and tracks `origin/main`. The original local implementation/history is preserved at branch `local-before-github-upload`. Documentation evidence was subsequently committed separately with CI skipped because application and workflow sources did not change.

Git metadata writes may need sandbox escalation. If required, use a per-command `-c safe.directory=<this exact workspace>`; never disable ownership checks globally. Public fetches work with portable Git. Use the connected plugin for publishing without extracting credentials.

Python: `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`.
The old local preview may still run at http://127.0.0.1:8260; stop it before rebuilding its DLL on Windows.
