# GMS frames

One folder per frame, named for its resource: `mf_<frame>/mf_<frame>.tres`, with that frame's
traits and core power in sub-folders beside it. The mirror path is what registers the resource, so
this folder maps onto `res://content/frames/gms/` and the manufacturer is GMS by path alone.

**The filename prefix decides the ContentLibrary index, not the script class and not the folder.**
`mf_` is a frame, `mt_` a trait Kit, `cp_` a core-power Kit, `buff_` a Buff, `action_` an Action.
A file named wrong is filed under the wrong index in silence; `spec/test_content_integrity.gd`
catches it.

From this supplement: **M/K2** (2, Everest alt). It is granted by extending vanilla `li_gms.tres`,
not by a licence of its own — see `res/content/licenses/gms/README.md`. `mf_mk2.tres`'s path is a
hardcoded string in that extension, so moving the frame breaks the grant silently;
`spec/test_alt_frames.gd` is what notices.
