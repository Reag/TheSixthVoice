extends RefCounted
# Modifies the resource at: res://content/licenses/horus/li_goblin.tres
#
# The Rakshasa is a Goblin alt, so it is granted where the Goblin is: li_goblin RANK 2, like every
# other alt of ours on a rank-2 frame (li_gorgon.tres_ext.gd's reasoning, design ruling 2). A player
# needs HORUS / Goblin 2 to field a Rakshasa, exactly as for the Goblin itself.
#
# APPENDED, never inserted. UnlockTree.license_name reads rank_2.granted_frames.FRONT()
# (unlock_tree.gd:28-32), so inserting our frame first would rename HORUS' own licence "Rakshasa"
# everywhere the UI shows it; and UnlockRank walks granted_frames in array order (unlock_rank.gd:12,
# :19), so appending also keeps the Goblin first in the picker.
#
# A THIRD-PARTY MOD CONTENDS FOR THIS LICENCE: fateofman-imi_alt_frames ships its own
# li_goblin.tres_ext.gd, appending the Cambion to this very rank through the ENGINE'S QUEUE. That is
# exactly the collision the queue drops silently (memory mod-extension-queue-collision), and why this
# script, like every licence extension here, is taken back out of the queue and applied directly by
# mod_main.apply_resource_extensions_directly(): both frames survive whatever the install order.
# test_rakshasa_frame.gd's OTHER_EXTENDERS row is the pin; it skips while that mod is parked.
# The direct-apply route also carries the RETENTION half of the fix, which bug 7 makes load-bearing
# for every extended resource regardless of contention.

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_rakshasa.tres. Moving
## the frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_rakshasa/mf_rakshasa.tres'

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
