# Resume the GitHub upload and first iOS build

The user has installed the GitHub plugin and connected the repository. The old
chat began before installation and never received GitHub tools. Do not ask the
user to install or connect it again without checking the new chat's capabilities.
OpenAI's plugin instructions say to start a new chat after installation:
https://learn.chatgpt.com/docs/plugins#install-and-use-a-plugin

## Authorized objective

Continue the Atari 2600 3D/AR emulator project. The user explicitly supplied
https://github.com/CreationsBy/AR-Atari-Emulator as the destination, said it had no
files, and subsequently connected it. Push the existing source and run the
unsigned GitHub Actions iOS workflow. Fix compile failures, rerun relevant checks,
and obtain a downloadable device IPA for Windows re-signing. No Apple signing
credentials are needed for this first unsigned build. Never claim the unsigned
IPA can launch without signing, or that AR was tested without a real device.

## Current workspace

- Root: `C:\Users\spagh\OneDrive\Documents\Ai projects\games\AR Atari 2600`
- Branch: `main`; implementation commit: `92f7e58`.
- Origin: `https://github.com/CreationsBy/AR-Atari-Emulator.git`.
- No push has succeeded. The attempted terminal push failed for missing GitHub
  credentials. The terminal's GitHub CLI is not authenticated; a plugin connection
  must not be assumed to authenticate CLI Git automatically.
- Portable Git: `.tools/mingit/cmd/git.exe`.
- Portable GitHub CLI: `.tools/gh/bin/gh.exe`.
- Python already present:
  `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`.
- Existing native DLL: `build/native-host/AtariDiorama.dll`.
- New chats should check for AGENTS.md and applicable GitHub skills/tools first.
- The sandbox may require escalation for Git metadata writes. Use a per-command
  `-c safe.directory=<this exact workspace>` if Git reports the sandbox user's
  ownership differs. Do not disable ownership checks globally.

## What is verified

Twelve native test methods pass against the real compiled Stella core. They cover
ROM execution, TIA capture, original audio, simultaneous input, both paddle
capacitor channels and Fire buttons, hardware collision flags, deterministic save
replay, rendering with no gameplay side effects, segmentation holes, geometry
budgets, HUD exclusion and upright extrusion. Read `docs/COMPATIBILITY.md` and
`docs/evidence/native-tests.txt`. Vendor integrity and actionlint also passed.

The iOS SwiftUI/RealityKit/ARKit application and hosted packaging/signing workflow
exist in source but have not yet been Apple-compiled. Four commercial game
profiles are explicitly unvalidated experiments; only original homebrew fixtures
are supplied. No commercial ROMs are bundled. The scene is genuine per-object
volumetric reconstruction, never a replacement gameplay simulation.

## Next actions

1. Use the now-available GitHub plugin/connector capabilities and follow any
   applicable plugin instructions. Verify access to the exact destination.
2. Inspect remote branches before pushing; it was initially public and empty.
   Preserve any changes the user has since made. The first push should include
   the actual `.github/workflows/ios.yml`, not only a source ZIP.
3. Push `main` through an authorized publishing path. If using CLI, check actual
   CLI authentication; do not extract or print any credentials.
4. Monitor the `Build and verify iOS prototype` workflow. A push to main runs the
   default unsigned route; manual dispatch can explicitly choose `unsigned`.
5. Resolve native Linux/macOS or Swift/Xcode failures and rerun. Sources are in
   `ios/`, native build scripts in `scripts/`, and XcodeGen configuration is
   `ios/project.yml`.
6. Download and inspect the IPA artifact/manifest. Its unsigned filename must
   retain `UNSIGNED-requires-resigning`. Provide the build URL and artifact.
7. Update README/compatibility evidence only for results actually observed.

The complete original request is also in the conversation's attachment:
`C:\Users\spagh\.codex\attachments\b85cd9c2-b5fb-4fcb-8977-5418d8361528\Pasted text.txt`.

## Existing deliverables

- `build/deliverables/AtariDiorama-source.zip`
- `build/deliverables/AtariDiorama-Windows-preview.zip`
- `docs/BUILD_WINDOWS.md`: remote build, certificates/profiles and Windows sideloading
- `docs/PROFILES.md`: profile format, mask hashes and read-only runtime program
- `docs/DEVICE_TESTING.md`: unexecuted physical iPhone acceptance procedure

The local preview may still be running at http://127.0.0.1:8260. It runs actual
Stella through a localhost Python server and a separate WebGL inspection viewer.
Stop that process before rebuilding its DLL on Windows (a loaded DLL is locked).
Do not repeat the whole implementation or broad native testing unless a change
or new failure justifies it. The next milestone is the real hosted Apple build.
