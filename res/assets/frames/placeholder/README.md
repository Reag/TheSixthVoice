# Placeholder frame art

`mf_placeholder.png` is the stand-in sprite a frame points at until the author drops in commissioned
art. **No `.tres` in this mod references it today** — the Fitzgerald, the M/K2 and the Subutai all
carry real art — but eighteen of the supplement's twenty-one frames are still to be built, and each
one arrives unarted, so the files stay. 80×80 RGBA, the vanilla size-1 frame dimension
(`assets/frames/ipsn/mf_blackbeard/ipsn_blackbeard.png`). A size-½ frame still occupies one tile and
uses 80×80, so this file serves those too.

Measured across vanilla `assets/frames/`: **93 files at 80×80, 39 at 160×160 (size 2), 3 at 240×240**
(the Barbarossa, size 3). A size-2 or size-3 frame in this supplement needs its own placeholder at
the matching dimension rather than this one scaled.

`mf_placeholder_160.png` is the same art at 160×160 (nearest-neighbour 2×), for **size-2** frames.
The Subutai was the first of them. A size-3 frame will need a 240×240 sibling; do not point a size-2
or size-3 frame at the 80×80 file, which renders at half scale on the board.

Art never blocks a release (roadmap §6). A sprite drop-in needs no session: replace the file, run
the headless import, commit the regenerated `.import` sidecar.

```
<godot console binary> --headless --path <modkit root> --import
```

**The sidecar has to be committed.** It names a `.ctex` under `res://.godot/imported/`, and
`ModToolZipBuilder.build_zip` reads it to pull the compiled texture into the release zip — so an
untracked sidecar means a clean clone builds a zip with no art. A missing `.ctex` is worse than an
ugly sprite: the `.tres` referencing it fails to load and the frame drops out of ContentLibrary
without an error a player would ever see.

This is the frame *sprite*, not an *icon*. Gear icons are SVGs under `res/assets/frames/icons/`,
drawn in each frame's icon pass, and `spec/test_content_integrity.gd` refuses a placeholder there.
