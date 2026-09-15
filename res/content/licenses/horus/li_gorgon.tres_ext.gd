extends RefCounted
# Modifies the resource at: res://content/licenses/horus/li_gorgon.tres
#
# The Myconid is a Gorgon alt, so it is granted where the Gorgon is: li_gorgon RANK 2. (The M/K2's
# li_gms extension writes to rank_1 instead, because the Everest is granted there and GMS frames are
# available at any licence level; nothing like that applies here. A player needs HORUS / Gorgon 2 to
# field a Myconid, exactly as for the Gorgon itself. Exclusivity does not arise: the licence grants
# both frames, HORUS to HORUS, so the book's "treat levels as" clause has nothing to say.)
#
# APPENDED, never inserted. UnlockTree.license_name reads rank_2.granted_frames.FRONT()
# (unlock_tree.gd:28-32). Vanilla li_gms declares only rank_1, so its name is '???' whatever a mod
# does; vanilla li_gorgon DOES declare rank_2, granting mf_gorgon - so inserting our frame at the
# front would rename HORUS' own licence "Myconid" everywhere the UI shows it. Display order is the
# second reason: UnlockRank walks granted_frames in array order (unlock_rank.gd:12, :19).
#
# This script is queued by LancerTacticsMod.add_overwrite_extend_mod_resources like any other
# .tres_ext.gd, and then mod_main.gd takes it straight back out of the engine's queue and calls it
# itself - see apply_resource_extensions_directly() there. No third-party mod is known to contend
# for THIS licence (the six parked in lancer-tactics-claude/.bk were checked on 2026-09-15 and none
# ships a li_gorgon.tres_ext.gd), but the direct-apply route is also what carries the RETENTION half
# of the fix, which bug 7 makes load-bearing for every extended resource regardless of contention.

## The frame's path is a hardcoded string, so it does NOT follow a move of mf_myconid.tres. Moving
## the frame breaks this silently; spec/test_alt_frames.gd is what notices.
const FRAME_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_myconid/mf_myconid.tres'

## The frame may live at its unpacked path or at the res:// path it took over; try the first and
## rebuild the second. Same helper as li_gms.tres_ext.gd and li_barbarossa.tres_ext.gd.
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
