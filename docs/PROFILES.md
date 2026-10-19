# Authoring conversion profiles

Profiles are independent visual interpretations. Start with a known cartridge and its frame/RAM captures. Do not implement game rules in a profile.

## Selection and confidence

Every imported ROM gets a SHA-256 and an MD5. Exact SHA-256 profiles take the same matching path as known MD5s from Stella's ROM database; arbitrary filenames never choose a commercial profile. Dedicated original fixtures use SHA-256. Commercial entries presently use known database MD5s, identify specific revisions and remain `experimental`.

Add a JSON file to `profiles/`, following the [schema](profile.schema.json). The iOS build bundles that entire folder. The existing package verifier expects five profiles; update that expected count deliberately when adding a new one. Run `scripts/validate_project.py`, update captures and bump `id` whenever incompatible interpretation data changes. No filename matching or unverified hash guessing is permitted.

Confidence labels are `development`, `experimental`, `generic` and `full`. Only mark `full` after the relevant rooms, objects, HUD, controllers and transitions have been exercised on the actual ROM and a device acceptance report records them. No existing commercial profile has that status.

## Coordinates and first-match rules

Each rule sees a same-color connected component. Bounds and centroid predicates are normalized to framebuffer width/height. `minWidth`/`maxWidth` and their height equivalents refer to a component's bounding box, not its pixel count. `colorIndex` is a raw TIA palette byte (its low bit is ignored). Rules run in array order, and the first match wins. Keep narrow projectile/player rules ahead of broad scenery rules.

`height` is the extrusion dimension, measured relative to full frame width = 1. `elevation` offsets the object's origin above the tabletop, or along the depth axis for `sideView`. The global depth slider multiplies thickness, while the world-width setting scales everything to meters. Role integers are 0 generic, 1 wall, 2 actor, 3 projectile, 4 platform, 5 scenery. Roles label interpretation and tracking; they never affect collisions.

For example:

```json
{
  "name": "Known blue actor",
  "colorIndex": 132,
  "role": 2,
  "maxWidth": 0.08,
  "maxHeight": 0.18,
  "height": 0.045,
  "elevation": 0
}
```

The optional `pattern` is a 16-character hexadecimal FNV-1a-64 mask hash, displayed in the iOS inspector and geometry capture. The input is component width and height as two little-endian uint32 values, followed by row-major mask bytes (0/1). It excludes translation and color, so a moving silhouette can keep its mesh. Pixel-level animation changes its pattern, and the renderer selects/reuses the matching cached mesh. Scale changes, reflection and duplicated sprites are already visible in the final pixels; exact-mask rules must account for those distinct patterns.

`backgroundIndex` can explicitly select a TIA index; `-1` selects the dominant border color. The generic border heuristic can erase meaningful same-color background objects, so set it explicitly for dedicated profiles where possible. `hudTop` and `hudBottom` exclude normalized bands before segmentation. The iOS top HUD overlay uses original pixels; bottom-band display needs extending if a new game uses it.

`sceneRAMOffset` optionally identifies one room byte within the 128-byte RIOT snapshot. Use offsets 0–127, not absolute CPU addresses; `$85` is offset 5. A byte change resets object tracking immediately. For unknown games leave `-1` rather than inventing an address. Current transitions are immediate, with no crossfade.

## Runtime profile program

For room-dependent geometry, an optional bounded instruction array can read RAM and override a matching rule's visual height/elevation:

```json
"program": [
  {"ramOffset": 5, "mask": 1, "equals": 1, "ruleIndex": 3, "height": 0.16}
]
```

This means: when `(RAM[5] & 1) == 1`, change rule 3's height. Instructions run after static rule creation and before segmentation rules are applied. At most 128 run per frame; invalid indices are skipped by the Swift runtime. The program is stateless and deterministic, so loading a state reconstructs it from restored RAM. There is no arbitrary network, filesystem, JavaScript or game-state write access. More complex semantic interpreters can be added as native profile adapters, preserving the read-only contract. The Swift program path awaits an Apple build/device test.

## Inspect a new ROM

1. Import your own legally obtained ROM. Keep the default generic label.
2. Inspect the original raster and scene side by side. Record exact ROM hashes and the core revision.
3. In the iOS inspector, pause on useful frames, copy mask hashes and RAM, and export diagnostics. The Windows capture tool also exports an entire trace CSV and exact box geometry for the original fixture.
4. Correlate motion, PF/GRP/enable/position/color/NUSIZ/reflection writes and RAM transitions. TIA registers are multiplexed over scanlines; one register does not necessarily mean one persistent game object.
5. Author roles, background, HUD and scene boundaries. Test every room and sprite animation state, including carrying/overlap and disappearing objects.
6. Save/restore at transitions and verify geometry reconstructs without moving the AR anchor. Keep the unmodified original framebuffer for every regression capture.

The existing Adventure, Combat, Breakout and Pitfall! files provide initial size/perspective hypotheses, not completed semantic maps. For example, same-color adjacent Breakout bricks currently form a single component; they shrink/disappear with actual ROM pixels but are not yet identified as individual bricks. A true game-specific interpreter must solve that before claiming complete conversion.
