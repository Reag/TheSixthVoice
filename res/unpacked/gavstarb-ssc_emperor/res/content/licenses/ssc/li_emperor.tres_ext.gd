extends RefCounted
# Modifies the resource at: res://unpacked/gavstarb-ssc_emperor/res/content/licenses/ssc/li_emperor.tres
#
# THE SECOND LICENCE WE EXTEND THAT ANOTHER MOD ADDS (the Six Sky's li_sunzi was the first, spike 9).
# The Emperor is not in Lancer Tactics (KTB); the third-party mod gavstarb-ssc_emperor adds it, and its
# li_emperor exists ONLY at that mod's own unpacked path - the mirrored res://content/licenses/ssc/
# li_emperor.tres never exists, because a NEW file is added under its own path rather than taking one
# over. A zip install keeps the same path (ProjectSettings.load_resource_pack), so this one target
# serves both.
#
# The Black Mountain is an Emperor alt, so it is granted where the Emperor is: li_emperor RANK 2, like
# every other alt of ours on a rank-2 frame (design ruling 2). A player needs SSC / Emperor 2 to field
# a Black Mountain.
#
# APPENDED, never inserted. UnlockTree.license_name reads rank_2.granted_frames.FRONT()
# (unlock_tree.gd:28-32), so inserting our frame first would rename the Emperor licence "Black Mountain".
#
# OPTIONAL, AND ORDER-DEPENDENT. li_emperor does not exist while the Emperor's zip is not mounted: for
# a player without the mod, and ALSO for one whose list installs us before it (vanilla modset.gd:253
# keeps optional_dependencies from ordering anything). Either way mod_main.extendable() drops the entry
# and the engine's own queue skips this script with a plain print (lancer_tactics_mod.gd:180-183);
# mod_main.queue_late_extensions() then applies it after every mod is installed, if the file exists by
# then - the Six Sky's Critical, already built, carrying a list.
#
# NO OTHER MOD EXTENDS THIS LICENCE (swept 2026-09-27: nothing in unpacked/, and of the 26 installed
# zips only gavstarb-ssc_emperor.zip itself carries the file). Applied directly anyway, like every
# licence extension here: the queue drops a second extender silently (memory
# mod-extension-queue-collision), and bug 7 makes the retention load-bearing.

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_black_mountain.tres. Moving
## the frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_black_mountain/mf_black_mountain.tres'

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
