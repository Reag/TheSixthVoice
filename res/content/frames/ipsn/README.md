# IPS-N frames

One folder per frame, named for its resource: `mf_<frame>/mf_<frame>.tres`, with that frame's
traits and core power in sub-folders beside it (`mf_fitzgerald/mt_hole_puncher/`,
`mf_fitzgerald/cp_broadside/`). The mirror path is what registers the resource, so this folder maps
onto `res://content/frames/ipsn/` and the manufacturer is IPS-N by path alone — nothing declares it.

**The filename prefix decides the ContentLibrary index, not the script class and not the folder.**
`mf_` is a frame, `mt_` a trait Kit, `cp_` a core-power Kit, `ms_` a system, `mw_` a weapon,
`wm_` a weapon mod, `buff_` a Buff, `action_` an Action, `onhit_` an on-hit effect,
`statblock_` a Statblock. A file named wrong is filed under the wrong index in silence.
`spec/test_content_integrity.gd` is what catches it.

Frames from this supplement, by roadmap order: Fitzgerald (1, full licence), Hazard (12, full
licence), Shackleton (13, Nelson alt), Gloire (14, Tortuga alt), Grutte Pier (15, Drake alt).
