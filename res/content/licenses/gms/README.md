# GMS licences

Nothing new is filed here: GMS has one licence, vanilla `li_gms.tres`, and this mod only EXTENDS it.

`li_gms.tres_ext.gd` appends the M/K2 (the Everest alt) to rank 1. The engine offers every pilot
the frames of every GMS licence regardless of licence level (`pilot_core.gd`
`get_available_frames`), so a frame appended there is playable from the start.

**The file here is half the mechanism.** `mod_main.gd` lists the vanilla path in
`EXTENDED_RESOURCES` and applies this script itself, outside the engine's extension queue, because
on 1.4.x two mods extending one `.tres` through that queue silently cancel and only the
first-installed one runs — and `li_gms` is contended by three other mods in the wild. Spike 2
(`specs/2026-09-14-license-extension-feasibility.md` in the notes repo) is the record; the
mechanism is shared by every alt in this mod.

Appended, never inserted: `UnlockTree.license_name` reads `granted_frames.front()`, so the Everest
has to stay first.
