extends RefCounted
# Modifies the resource at: res://content/licenses/ssc/li_deaths_head.tres
#
# The Lovers Knot is a Death's Head alt, so it is granted where the Death's Head is: li_deaths_head
# RANK 2, like every other alt of ours on a rank-2 frame (li_gorgon.tres_ext.gd's reasoning, design
# ruling 2). A player needs SSC / Death's Head 2 to field a Lovers Knot, exactly as for the Death's Head.
#
# APPENDED, never inserted. UnlockTree.license_name reads rank_2.granted_frames.FRONT()
# (unlock_tree.gd:28-32), so inserting our frame first would rename SSC's own licence "Lovers Knot"
# everywhere the UI shows it; and UnlockRank walks granted_frames in array order (unlock_rank.gd:12,
# :19), so appending also keeps the Death's Head first in the picker.
#
# NO OTHER MOD EXTENDS THIS LICENCE (swept 2026-09-26: nothing in unpacked/, none of the 25 installed
# zips). This script is still taken out of the engine's queue and applied directly by
# mod_main.apply_resource_extensions_directly(), like every licence extension here, because the queue
# drops a second extender of the same resource silently (memory mod-extension-queue-collision) and a
# contender could arrive with any later release. The direct-apply route also carries the RETENTION half
# of the fix, which bug 7 makes load-bearing for every extended resource regardless of contention.

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_lovers_knot.tres. Moving
## the frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/mf_lovers_knot.tres'

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
