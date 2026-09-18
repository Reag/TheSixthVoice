extends RefCounted
# Modifies the resource at: res://content/licenses/ha/li_iskander.tres
#
# The Vauban is an Iskander alt, so it is granted where the Iskander is: li_iskander RANK 2. A player
# needs Harrison Armory / Iskander 2 to field one, exactly as for the Iskander itself. The alt carries
# NONE of the Iskander's four traits and none of its gear (design ruling 14), so nothing else about
# the licence changes.
#
# APPENDED, never inserted. UnlockTree.license_name reads rank_2.granted_frames.FRONT()
# (unlock_tree.gd:28-32). Vanilla li_iskander DOES declare rank_2, granting mf_iskander - so inserting
# our frame at the front would rename Harrison's own licence "Vauban" everywhere the UI shows it.
# Display order is the second reason: UnlockRank walks granted_frames in array order.
#
# This script is queued by LancerTacticsMod.add_overwrite_extend_mod_resources like any other
# .tres_ext.gd, and then mod_main.gd takes it straight back out of the engine's queue and calls it
# itself - see apply_resource_extensions_directly() there. No installed mod is known to contend for
# THIS licence (all 24 zips in %APPDATA%/LancerTactics/mods were swept on 2026-09-18 and none names
# li_iskander at all), but the direct-apply route is also what carries the RETENTION half of the fix,
# which bug 7 makes load-bearing for every extended resource regardless of contention.

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_vauban.tres. Moving the
## frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_vauban/mf_vauban.tres'

## The frame may live at its unpacked path or at the res:// path it took over; try the first and
## rebuild the second. Same helper as li_gms.tres_ext.gd, li_barbarossa.tres_ext.gd,
## li_gorgon.tres_ext.gd and li_mourning_cloak.tres_ext.gd.
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
