# IPS-N licences

`li_<frame>.tres`, an `UnlockTree` with `rank_1` / `rank_2` / `rank_3`, each an `UnlockRank`
carrying `granted_gear` and `granted_frames`. By convention the frame itself is granted at rank 2
(`UnlockTree.license_name` reads `rank_2.granted_frames.front()` to name the licence, so a licence
with an empty rank 2 shows as `???`).

**A full-licence frame gets a new file here. An alt frame does not.** Per the author's
2026-09-13 directive, an alt extends the base licence in place with a `.tres_ext.gd` beside the
vanilla path — never a cloned licence. The extension's effect is dropped by upstream bug 7 unless
something holds a reference, so every extended path is listed in `mod_main.gd`'s
`EXTENDED_RESOURCES`.

From this supplement: `li_fitzgerald.tres` (1) and `li_hazard.tres` (12) are new files here;
Shackleton, Gloire and Grutte Pier extend `li_nelson`, `li_tortuga` and `li_drake` instead.
