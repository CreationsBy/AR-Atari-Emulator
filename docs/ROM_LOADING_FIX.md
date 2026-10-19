# ROM-opening crash: ARM64 worker-stack overflow

The user reported that build #9 crashed immediately when selecting any ROM, before the camera/game view appeared. The Adventure change introduced an aggregate cache assignment in `ad_reset_adventure`, which is called by the common reconstruction reset whenever a cartridge loads, resets or restores a state. It therefore affected every cartridge, including the demo and generic profiles.

Compiling the old source for Darwin ARM64 at `-O2` produced a 605,408-byte stack frame for that reset. [Apple's threading guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/CreatingThreads/CreatingThreads.html) documents a usual 512 KB secondary-thread stack. The Windows ABI optimized the reset to a direct memory clear; the earlier main-thread host tests and successful archive did not exercise the failing conditions.

## Correction

- Invalidate cached entries in place instead of assigning a roughly 605 KB aggregate temporary. A reused sprite's mask is cleared directly before capture.
- Reuse raster working buffers outside the stack. In the same ARM64 cross-compiler output, the reset needs no explicit stack reservation and the reconstruction frame falls from 205,008 to 3,376 bytes.
- Enforce a 64 KB per-function stack-frame limit for app-authored native sources, including the actual iOS target build. GCC and Clang use their respective warning syntax; upstream Stella sources retain their existing build settings.
- Run the real native suites in a child process on a 512 KB worker stack, so stack faults fail CI without terminating its parent runner.
- On the Mac runner, run those constrained-stack fixtures and repeated load/reset/first-frame/save/restore through the actual Swift `EmulationEngine` dispatch queue before packaging.

The fix preserves visual profiles and original emulated state. Local regression tests pass, including the supplied Adventure and Ice Hockey cartridges. A separate local worker smoke test passed three load/reset/restore cycles each for the demo and all five supplied ROMs. Commercial cartridges remain local and are excluded from Git/app/source packages.

ARM64 assembly is cross-compiler evidence, not a physical iPhone crash trace. The corrected IPA still needs installation and a ROM-opening retest on the user's phone. Preserve the app's installed data when updating; there is no need to delete the ROM library for this fix.
