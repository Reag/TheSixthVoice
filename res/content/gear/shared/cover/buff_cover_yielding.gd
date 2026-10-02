## A BuffCover that stands down while its holder already has cover at least as good from another
## COVER buff. Used by every buff of ours that hands an ALLY soft cover: buff_mark_soft_cover,
## buff_nightfare_soft_cover, buff_bulwark_cover.
##
## NOTHING CHANGES IN PLAY. Cover is max-then-collapse: CoverCalculator.determine_cover adds every
## COVER buff at the same key, target_pos (cover_calculator.gd:57-62), and keeps the highest level.
## A second soft cover buff on a unit already in soft cover adds nothing to the roll.
##
## WHY IT EXISTS: the resident talents mod's House Guard rank 3 (Shield of the Legion) fires on a miss
## only if the COVER buffs on the roll number exactly as many as PreAttack.cover_sources
## (action_shield_of_the_legion_miss.gd). Two buffs at one key count 2 against 1 and the trigger dies -
## and rank 2 (Greater Guardian) hangs a soft cover buff on every ally within range 2 of every House
## Guard pilot, so any cover of ours on that ally was always the second. Ruled 2026-10-02,
## reports/2026-10-02-house-guard-3-audit.md; pinned by spec/test_compat.gd's House Guard 3 section.
##
## THE YIELD IS DECIDED AT READ TIME, not by removing the buff: the holder keeps it, and it shelters
## again the moment the other cover goes. So there is no removal order to get wrong.
##
## AMONG OURSELVES exactly one survives, never none: a yielding buff yields to another yielding buff
## only if that one is STRONGER, or equally strong and sorts first (compcon_id, then from_gear). Two
## buffs that yielded to each other on equal terms would leave the unit with no cover at all.
extends BuffCover

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var holder := core.get_holder_unit(context.map)
	if not Unit.is_valid(holder): return true
	for other:BuffCore in holder.state.buffs:
		if other == core or not _is_live_cover(other, context): continue
		if _outranks(other, core, context): return false
	return true

## Whether `other` would be read as cover in this context, WITHOUT asking any yielding buff to yield.
## Asking would recurse: two of ours would each consult the other forever.
func _is_live_cover(other:BuffCore, context:Context) -> bool:
	if not BuffCore.is_valid(other) or other.base.to != Buff.TO.COVER: return false
	if not other.base.is_buff_context_valid_for_passive(other, context): return false
	if Buff.check_if_prohibited(other, context): return false
	if other.base.has_method(&'applies_ignoring_yield'): return other.base.applies_ignoring_yield(other, context)
	return other.base.check_if_passive_applies(other, context)

func applies_ignoring_yield(core:BuffCore, context:Context) -> bool:
	return super.check_if_passive_applies(core, context)

func _outranks(other:BuffCore, core:BuffCore, context:Context) -> bool:
	var other_level:int = other.get_values(context).category_int
	var our_level:int = core.get_values(context).category_int
	if other_level != our_level: return other_level > our_level
	if not other.base.has_method(&'applies_ignoring_yield'): return true # anyone else's cover wins a tie
	return _sort_key(other) < _sort_key(core)

static func _sort_key(core:BuffCore) -> String:
	return '%s|%s' % [core.base.compcon_id, core.from_gear]
