extends RefCounted
# Modifies the resource at: res://unpacked/gavstarb-ha_sunzi/res/content/licenses/ha/li_sunzi.tres
#
# THE FIRST LICENCE WE EXTEND THAT ANOTHER MOD ADDS (spike 9, 2026-09-16). The Sunzi is not in Lancer
# Tactics (Long Rim); the third-party mod gavstarb-ha_sunzi adds it, and its li_sunzi exists ONLY at
# that mod's own unpacked path - the mirrored res://content/licenses/ha/li_sunzi.tres never exists,
# because a NEW file is added under its own path rather than taking one over. A zip install keeps the
# same path (ProjectSettings.load_resource_pack), so this one target serves both.
#
# The Six Sky is a Sunzi alt, so it is granted where the Sunzi is: li_sunzi RANK 2, like every other alt
# of ours on a rank-2 frame (design ruling 2). A player needs HA / Sunzi 2 to field a Six Sky.
#
# APPENDED, never inserted. UnlockTree.license_name reads rank_2.granted_frames.FRONT()
# (unlock_tree.gd:28-32), so inserting our frame first would rename the Sunzi licence "Six Sky".
#
# OPTIONAL. A player without the Sunzi mod has no li_sunzi at all. mod_main.extendable() drops this
# entry from EXTENDED_RESOURCES for them, so apply_resource_extensions_directly() never tries to load a
# missing file and logs no error; and the engine's own queue skips it with a plain print
# (LancerTacticsMod.extend_resource, lancer_tactics_mod.gd:179-181).
#
# NO OTHER MOD EXTENDS THIS LICENCE (swept 2026-09-26: nothing in unpacked/, none of the 26 installed
# zips). Applied directly anyway, like every licence extension here: the queue drops a second extender
# silently (memory mod-extension-queue-collision), and bug 7 makes the retention load-bearing.

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_six_sky.tres. Moving the
## frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/mf_six_sky.tres'

## The frame may live at its unpacked path or at the res:// path it took over; try the first and
## rebuild the second. Same helper as every other licence extension in this mod.
func sload(file:String) -> Resource:
	if ResourceLoader.exists(file): return ResourceLoader.load(file)
	return ResourceLoader.load('res://' + file.split('/res/')[1])

# Apply any changes to the given resource here and they'll be saved in the virtual filesystem over the original.
# Must return the changed resource.
func modify_resource(resource:Resource) -> Resource:
	var license:UnlockTree = resource
	var frame:Frame = sload(FRAME_PATH)
	if license == null or license.rank_2 == null or frame == null: return resource
	if not license.rank_2.granted_frames.has(frame): license.rank_2.granted_frames.append(frame)
	return resource
