extends RefCounted
# Modifies the resource at: res://content/licenses/gms/li_gms.tres
#
# The M/K2 is an Everest alt, so it is granted where the Everest is: li_gms rank 1. The engine
# offers every pilot the frames of every GMS licence at rank 3 regardless of licence level
# (pilot_core.gd get_available_frames), so a frame appended here is playable from the start.
#
# APPENDED, never inserted, so the Everest stays first - but NOT for the reason an earlier version
# of this comment gave. UnlockTree.license_name does read granted_frames.front(), but off rank_2
# (unlock_tree.gd:28-32), and vanilla li_gms.tres declares ONLY rank_1 (li_gms.tres:53) - so
# license_name() returns '???' for this licence whatever we do here. The real reason is display
# order: UnlockRank builds its granted-frame name and description lists by walking granted_frames
# in array order (unlock_rank.gd:12, :19), so inserting would put the M/K2 ahead of the Everest on
# vanilla's own licence card.
#
# This script is queued by LancerTacticsMod.add_overwrite_extend_mod_resources like any other
# .tres_ext.gd, and then mod_main.gd takes it straight back out of the engine's queue and calls it
# itself - see apply_resource_extensions_directly() there for why (two mods extending one path
# through the queue silently cancel).

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_mk2.tres. Moving the
## frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/gms/mf_mk2/mf_mk2.tres'

## The frame may live at its unpacked path or at the res:// path it took over; try the first and
## rebuild the second. Same helper as the walkthrough's alt-frames chapter and CCC's extension.
func sload(file:String) -> Resource:
	if ResourceLoader.exists(file): return ResourceLoader.load(file)
	return ResourceLoader.load('res://' + file.split('/res/')[1])

# Apply any changes to the given resource here and they'll be saved in the virtual filesystem over the original.
# Must return the changed resource.
func modify_resource(resource:Resource) -> Resource:
	var license:UnlockTree = resource
	var frame:Frame = sload(FRAME_PATH)
	if license == null or license.rank_1 == null or frame == null: return resource
	if not license.rank_1.granted_frames.has(frame): license.rank_1.granted_frames.append(frame)
	return resource
