# Ice Hockey: first NTSC 3D profile

This profile targets the supplied 4 KB Activision ROM, selected by measured hashes:

- SHA-256: `fc8b861d9cf9c9d5f7f7677f22b39d512d249697b69c1e7dcf238c5dc8f44b60`
- MD5: `a4c08c4994eb9d24fb78be1793e82e26` (also in the pinned Stella database)
- Profile: `ice-hockey-ntsc-v1`; native adapter: `iceHockeyNTSCv1`

Import that ROM or reopen its existing library entry after updating. The profile is selected automatically. Cartridge files remain in the local ignored `roms/` folder and are excluded from Git, the app and source packages.

## Reconstruction

The captured 160×210 frame shows ice at x32–127/y42–186, with black goal openings at x64–95. The profile makes a thin ice surface preserving those openings, raised edge boards and goal frames/nets. Thickness and net strands are authored visual interpretations; the original ROM still controls collisions and scoring.

Four sorted skater slots expose X at RIOT offsets `$39..$3C` and inverted raster Y at `$35..$38`. The adapter reads those slots and groups the visible head, jersey and leg colors around their foot anchors. The original pixel silhouettes become upright multicolor volumes on the ice. Nearest matching team/position tracks parts between frames; identities can be ambiguous when teammates overlap or cross.

Small black components inside the ice become low puck candidates. Hidden pucks may disappear; the renderer does not predict paths or change possession. Score and timer graphics remain in the original-pixel HUD. The bottom logo is excluded from world geometry and remains in the complete original-frame comparison.

This profile is **experimental**. Overlapping/fallen skaters, occluded puck pixels, goal transitions, other revisions/TV standards and monochrome colors need more coverage. Unrecognized dimensions/ice palettes fall back to the profile's generic rules. This is not full-support certification.

## Vertical mode and multiplayer

Choose **Settings → Miniature world → World orientation → Vertical** to stand the whole scene upright on its bottom edge, including when tilted. **Tabletop** restores the existing mode. Placement still uses a horizontal table/floor anchor; wall-plane detection is not required. Side-view profiles that already use an upright pixel plane are not rotated twice. Existing preferences migrate with tabletop as the default.

The host's orientation is synchronized in Wi-Fi multiplayer. Install the same updated build on both phones because the scene protocol changed. Each still uses its own physical AR camera.

For two-player Ice Hockey, use SELECT to choose game 2 or 4, then RESET, as described in [Activision's original manual](https://www.atariage.com/manual_html_page.php?SoftwareLabelID=242).

## Observed host checks

The supplied ROM ran for 3,600 frames with Select/Reset, movement and Fire on both ports. No geometry was dropped. Four visible head parts appeared in 3,588 frames, fewer during nine overlap/pose frames, and none during three startup frames. These are interpretation counts rather than perfect player recognition. Reconstruction left emulator save bytes unchanged.

Twenty local native test methods passed, including rink openings/nets, upright multicolor parts, puck candidates, HUD exclusion, moving-part mesh reuse, budgets and the supplied ROM. CI runs original synthetic fixtures and skips the commercial-ROM test. Vertical transforms, preference migration and orientation synchronization are also covered by the hosted Swift tests. Physical iPhone acceptance for these new features remains pending.

Run `scripts/capture_ice_hockey.py` with the project Python to reproduce captures, box geometry and the report under `build/ice-hockey/`. `scripts/render_evidence.py` accepts `--input`, `--output` and `--upright` after Blender's `--` separator. Its renders show captured geometry and are not AR screenshots.
