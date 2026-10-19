# Third-party notices

Atari Diorama includes Stella 2014 Libretro, an established Atari 2600 emulator.

- Source: https://github.com/libretro/stella2014-libretro
- Pinned revision: `7d1361e407e63f29e52892655069e5fb4096e691`
- Archive SHA-256: `7c9c6d1b24d374f5e72ebea3ec2159bb35ea21684c6f07fd095da4f5981054d1`
- Original authors include Bradford W. Mott, Stephen Anthony, Eckhard Stolberg, Brian Watson and the Stella Team; upstream contributors retain their copyrights.
- License: GNU GPL version 2; see `LICENSE` and `third_party/stella2014/stella/license.txt`. Per-file notices in the vendored tree also apply, including notices for libretro-common and ARM interpreter code.
- All 286 upstream files are retained and hashed in `third_party/stella2014-manifest.json`.

The original tree is unmodified. `scripts/build_native.py` makes a build copy with these clearly marked changes:

1. Read-only TIA register-write and indexed-video capture hooks.
2. A Windows guard around an unused POSIX include.
3. A controller configuration entry point using Stella's existing controller classes. It clears stale input events when switching controller hardware.

The new frontend, reconstruction engine, scripts, profiles, icon and original homebrew source are provided under GPL-2.0-or-later. When linking the GPLv2 core, the combined executable is conveyed under GPLv2. Keep this notice, all upstream notices, and the corresponding complete source/build scripts available to recipients of binaries. The workflow packages the matching source alongside its IPA. This is not a proprietary binary-only distribution.

Apple system frameworks are accessed through the iOS SDK; their SDK terms still apply. App Store distribution has not been assessed or attempted. This prototype targets personal device testing and sideloading.

The project's original test cartridge is independently authored. No commercial game ROM, commercial game asset, or 3dSen code is included. The ROM hashes used for experimental profiles come from Stella's `DefProps.hxx` database. Geod Studio's public description of hand-authored profiles informed the architecture, not the implementation. Atari, the game names and 3dSen are the property of their respective owners. This project is not affiliated with Atari or Geod Studio.
