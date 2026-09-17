extends RefCounted
# Modifies the resource at: res://content/licenses/ssc/li_mourning_cloak.tres
#
# The Maiden's Blush is a Mourning Cloak alt, so it is granted where the Mourning Cloak is:
# li_mourning_cloak RANK 2. A player needs SSC / Mourning Cloak 2 to field one, exactly as for the
# Mourning Cloak itself. Exclusivity does not arise (ruling 16): the licence grants both frames, SSC
# to SSC, so the book's "treat levels as" clause has nothing to say.
#
# APPENDED, never inserted. UnlockTree.license_name reads rank_2.granted_frames.FRONT()
# (unlock_tree.gd:28-32). Vanilla li_mourning_cloak DOES declare rank_2, granting mf_mourning_cloak -
# so inserting our frame at the front would rename SSC's own licence "Maiden's Blush" everywhere the
# UI shows it. Display order is the second reason: UnlockRank walks granted_frames in array order.
#
# This script is queued by LancerTacticsMod.add_overwrite_extend_mod_resources like any other
# .tres_ext.gd, and then mod_main.gd takes it straight back out of the engine's queue and calls it
# itself - see apply_resource_extensions_directly() there. No installed mod is known to contend for
# THIS licence (all 24 zips in %APPDATA%/LancerTactics/mods were swept on 2026-09-17 and none names
# li_mourning_cloak at all), but the direct-apply route is also what carries the RETENTION half of the
# fix, which bug 7 makes load-bearing for every extended resource regardless of contention.

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_maidens_blush.tres.
## Moving the frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_maidens_blush/mf_maidens_blush.tres'

## The frame may live at its unpacked path or at the res:// path it took over; try the first and
## rebuild the second. Same helper as li_gms.tres_ext.gd, li_barbarossa.tres_ext.gd and
## li_gorgon.tres_ext.gd.
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
