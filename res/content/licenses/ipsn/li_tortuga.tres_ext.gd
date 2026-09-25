extends RefCounted
# Modifies the resource at: res://content/licenses/ipsn/li_tortuga.tres
#
# The Gloire is a Tortuga alt, so it is granted where the Tortuga is: li_tortuga RANK 2. A player
# needs IPS-N / Tortuga 2 to field one, exactly as for the Tortuga itself. The alt carries NONE of the
# Tortuga's traits and none of its gear (design ruling 14), so nothing else about the licence changes.
# li_nelson.tres_ext.gd line for line.
#
# APPENDED, never inserted. UnlockTree.license_name reads rank_2.granted_frames.FRONT()
# (unlock_tree.gd:28-32), and vanilla li_tortuga's rank_2 grants mf_tortuga - so inserting our frame
# at the front would rename IPS-N's own licence "Gloire" everywhere the UI shows it.
#
# This script is queued by LancerTacticsMod.add_overwrite_extend_mod_resources like any other
# .tres_ext.gd, and then mod_main.gd takes it straight back out of the engine's queue and calls it
# itself - see apply_resource_extensions_directly() there. No resident and none of the zips in
# %APPDATA%/LancerTactics/mods names li_tortuga (swept 2026-09-24, the design's Contested seams), but
# the direct-apply route is also what carries the RETENTION half of the fix, which bug 7 makes
# load-bearing regardless.

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_gloire.tres. Moving the
## frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_gloire/mf_gloire.tres'

## The frame may live at its unpacked path or at the res:// path it took over; try the first and
## rebuild the second. Same helper as the other alt licences' extensions.
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
