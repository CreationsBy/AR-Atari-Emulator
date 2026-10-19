# Architecture and invariants

```text
ROM bytes -> Stella CPU/TIA/RIOT/cartridge -> frame + RAM + TIA write trace
                                            |
                            hash-selected JSON profile / generic rules
                                            |
                              segmentation -> tracking -> local boxes
                                            |
                              cached RealityKit meshes -> ARKit anchor
```

Stella makes every gameplay decision. There is no 3D physics engine, 3D collision substitute, enemy AI or independently simulated projectile. Mesh removal follows the next emulator frame. Camera motion changes only a scene transform.

## Native core

`native/src/Emulator.cpp` implements a single-instance Libretro frontend. `AtariDiorama.h` is its C ABI. A host DLL/shared library and an iOS static library are built from the same 100 translation units. The build parses the pinned upstream source list rather than maintaining an inaccurate partial list of cartridge hardware.

One serial queue owns core loading, running, reset, state serialization and reconstruction. Frame pointers are borrowed until the next mutation. The iOS engine copies framebuffer, RAM, objects and boxes before publishing a value snapshot on the main thread. Touch/gamepad input uses native atomics. Audio is a single-producer/single-consumer ring. Overflow drops new samples and is counted; underrun supplies silence. The audio callback allocates nothing and never enters Stella.

The frontend requests the standard 24-bit palette and disables no ROM logic. Cadence is read from the core and can track PAL/NTSC changes. iOS display ticks advance up to four overdue emulated frames. A large interruption resets the host deadline instead of running an unbounded catch-up loop. Audio remains at the core's 31,400 Hz through AVAudioEngine's converter. Device timing and route changes still require iPhone validation.

Controller selection configures Stella's actual Joystick/Paddles classes. A port in absolute paddle mode uses the Libretro analog X/Y axes and the A/B buttons for its two paddles. The GUI maps the first two paddle players to the left physical port. Four paddle players, keyboards and exotic controllers are not exposed by this UI.

## Extraction

The build adds a hook at `TIA::poke` after address masking and before the write takes effect. Up to 8,192 `(CPU-cycle, register, value)` records are captured per emitted frame; overflow is explicit. Cycle values are relative to Stella's current TIA frame epoch and can restart at VSYNC within a callback interval. Multiply CPU cycles by three for TIA color clocks.

This exposes PF0–PF2, GRP0/1, missile/ball enable, color, RESP*, HMOVE/HMP*, NUSIZ*, REFP*, and other writes without changing them. The exact indexed framebuffer used by Libretro is copied before conversion to RGBA. The RIOT snapshot contains 128 bytes (`$80` corresponds to offset 0).

There is **no current per-pixel attribution mask** identifying overlapping TIA players/playfield/missiles. Traces are available for inspection and future semantic extractors; the implemented classifier uses final indexed pixel components and RAM conditions. An occluded object's hidden shape cannot be recovered from these pixels alone.

## Reconstruction

For each frame, the converter excludes explicit HUD bands, chooses a profile background or dominant border color, then finds 4-connected same-color components. It hashes the translation-invariant binary mask and applies the first matching profile rule. The fallback uses component area to assign basic wall, actor or projectile heights.

Each component is converted into horizontal runs, merging identical runs on consecutive rows. Separate shapes and holes survive. The result is a set of component-local rectangular prisms, with distinct origin and geometry hash. It never creates a single screen-sized solid from the whole framebuffer.

Tracking greedily matches color/role within a 40-pixel Manhattan bound including size differences. Objects can change IDs when crossing, flickering, joining or separating. This is a rendering cache, not game-state identity. Profiles may use a RAM room byte to reset IDs atomically at transitions. Currently room changes are immediate; a transition crossfade has not been implemented.

Coordinates use full frame width = 1 world unit and depth/height = 0.75 units. Tabletop maps screen x/y into world x/z and extrudes upward. Side-view maps x/y to upright x/y with positive z thickness. This approximate display aspect preserves a 4:3 presentation rather than treating Atari's narrow raster pixels as square physical pixels.

The global width in meters is applied to the world root. Quality budgets cap at 1,024 components/24,000 prisms, or 256/6,000 in low mode. Budget drops are reported. Component mesh resources are cached by shape/dimensions/depth; moving objects only change their entity position. A mesh packs all its prisms into one resource rather than one entity per voxel. Internal prism faces remain; a future mesher can remove them if profiling justifies it.

## iOS presentation

The default AR view uses horizontal-plane raycasts, a live center preview and a tap-created ARAnchor. The anchored world remains fixed as the physical camera moves. Scale, tilt and yaw alter the root only. Reposition/reset are explicit. Camera authorization and tracking interruptions have UI messages; backgrounding and audio interruptions pause the game.

The other views use a RealityKit virtual camera, with the same geometry and emulator. They are inspection views, separate from physical-camera AR. The scene has a virtual base and directional shadow setup. Shadows onto real-world tables, mesh-based occlusion and durable anchors across app relaunch are not implemented or verified.

SwiftUI HUD images come from the original framebuffer's profile-defined top band. The full framebuffer is an optional comparison overlay. Unknown games have no reliable HUD metadata and may extrude HUD digits until a profile supplies a crop.

Save files contain ROM SHA-256, pinned core revision, profile ID, controller type and the serialized core. Geometry and tracking IDs are reconstructed; the profile's runtime program is purely a function of RAM and static data, so it has no mutable script state to save. Save files from a changed core/profile ID are rejected. Archive and movie streaming are intentionally not exposed by the raw-ROM importer.
