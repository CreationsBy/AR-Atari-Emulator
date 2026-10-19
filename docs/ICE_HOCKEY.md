# Ice Hockey: original-frame 3D relief

Reopen the supplied NTSC ROM to select `ice-hockey-ntsc-v2` / `iceHockeyNTSCv2` automatically.

- SHA-256: `fc8b861d9cf9c9d5f7f7677f22b39d512d249697b69c1e7dcf238c5dc8f44b60`
- MD5: `a4c08c4994eb9d24fb78be1793e82e26`; size 4,096 bytes.

## Original artwork in the world

The complete live frame becomes volumetric pixel geometry: both scores, timer, original rink and goal openings, skaters, sticks, puck and Activision logo. Text uses the ROM's actual changing pixel shapes, not a replacement font, scoreboard or separate score UI. The optional original-frame comparison remains available.

The previous authored boards, posts and net strands are removed. The fixed rink surface and RAM-derived standing-skater reinterpretation are replaced by visible pixel masks. Skaters retain their original raster silhouettes and positions. No hidden puck, pose, line, goal structure or scenery is invented. Depth is the only added dimension; black background, ice and foreground artwork have different thin extrusion heights. Score/timer/logo glyphs use shallow relief so deep side faces do not obscure their one-pixel holes at oblique angles.

Tabletop uses the original raster in X/Z; Vertical stands that same relief upright. Characters and lettering stay in that common plane rather than being independently counterrotated. No extra presentation pedestal is drawn for this profile. Ice Hockey uses unlit materials so ambient-light settings do not recolor its artwork. The shared guest receives the same geometry; install the same updated build on both phones for these presentation rules.

The new profile ID replaces v1 because its interpretation changed. Earlier profile-bound saves may be rejected; the imported ROM library stays intact. No cartridge bytes, commercial sprite masks or ROM graphics are bundled in source or the app.

## Verified accuracy and its limits

`scripts/verify_scene_pixels.py` independently projects native box footprints back to the source raster. It rejects non-pixel-aligned boxes, missing pixels, duplicates/overlap and any geometry outside the original frame, then compares every original RGBA value.

Across 3,600 supplied-ROM frames, **all 120,960,000 source pixels matched exactly**, with zero missing, extra or overlapping pixels and zero geometry drops. Score/timer geometry appears whenever drawn (3,598 frames); logo geometry appears in 3,597 frames. Initial blank frames remain blank. Peak scene size was 68 objects / 389 boxes, below both quality presets' budgets. These are host measurements, not iPhone FPS.

All 32 local native methods pass, including updated glyph removal, original goal holes, thin pixel lines, palette changes, no-RAM rendering, low-quality budgets and the real supplied ROM. The crash fix's 512 KB worker-stack suite and native stack budget remain enabled. Public CI skips the two private-ROM methods.

This establishes exact shape/color coverage in the original raster plane for the checked frames. The original game is 2D: extrusion height, perspective, parallax and screen antialiasing are not original 3D ground truth. It is not a claim that an arbitrary physical AR camera image is pixel-identical to the framebuffer. Physical iPhone visual acceptance remains pending, so the profile stays experimental.

## Run and inspect

Choose Settings → Miniature world → World orientation → Tabletop / Vertical. For two players, the host selects game 2 or 4 and resets. Only the host needs the ROM.

Run `scripts/capture_ice_hockey.py` with the project Python and compiled library. New captures, original/projection PNG pairs, scene geometry and the report go to `build/ice-hockey-faithful/`; earlier v1 captures remain separate. `scripts/render_evidence.py` can render the captured relief in Blender with `--input`, `--output` and optional `--upright` after Blender's `--`. Those are offline renders, not iPhone screenshots.
