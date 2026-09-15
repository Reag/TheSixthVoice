extends RefCounted
# Modifies the resource at: res://content/licenses/ha/li_barbarossa.tres
#
# The Subutai is a Barbarossa alt, so it is granted where the Barbarossa is: li_barbarossa RANK 2.
# (The M/K2's li_gms extension writes to rank_1 instead, because the Everest is granted there and
# GMS frames are available at any licence level; nothing like that applies here. A player needs
# Harrison Armory / Barbarossa 2 to field a Subutai, exactly as for the Barbarossa itself.)
#
# APPENDED, never inserted, and here that is load-bearing in a way it was NOT for li_gms.
# UnlockTree.license_name reads rank_2.granted_frames.FRONT() (unlock_tree.gd:28-32). Vanilla
# li_gms declares only rank_1, so its name is '???' whatever a mod does; vanilla li_barbarossa DOES
# declare rank_2, granting mf_barbarossa - so inserting our frame at the front would rename
# Harrison's own licence "Subutai" everywhere the UI shows it. Display order is the second reason:
# UnlockRank walks granted_frames in array order (unlock_rank.gd:12, :19).
#
# This script is queued by LancerTacticsMod.add_overwrite_extend_mod_resources like any other
# .tres_ext.gd, and then mod_main.gd takes it straight back out of the engine's queue and calls it
# itself - see apply_resource_extensions_directly() there. That matters MORE here than for li_gms:
# fateofman-imi_alt_frames extends li_barbarossa through the queue, and the engine's merge keeps
# only the first-installed mod's callable per path, silently.

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_subutai.tres. Moving
## the frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_subutai/mf_subutai.tres'

## The frame may live at its unpacked path or at the res:// path it took over; try the first and
## rebuild the second. Same helper as li_gms.tres_ext.gd.
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
