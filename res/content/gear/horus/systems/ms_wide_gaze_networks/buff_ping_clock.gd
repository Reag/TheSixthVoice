## PING'S CLOCK (frame close, author decision 1, 2026-09-23): the NAGA-side clock that ends one
## Ping's window at "the end of your next turn" whatever the turn order. The Sluagh's In Triumvirate
## met the same edge and settled it the same way (rulings row 285, buff_in_triumvirate_pair.gd's
## "owner-side core is the clock"): until = 7 (END_OF_OWNERS_NEXT_TURN) on a buff HELD BY THE OWNER
## ticks on the owner's own turn start (unit_condition.gd:24) and clears at the end of the owner's next
## turn (:62, event_turn_end.gd:62), which is exactly the card's clock.
##
## ONE CLOCK PER PING, KEYED TO ITS CHIP. The Naga may Ping one target and then another, or the same
## target again next turn - a later Ping replaces the earlier chip (apply_buff_alt,
## unit_condition.gd:741-747) and its window must run from the LATER Ping. So the clock stacks
## (multiple_copies_can_stack) and names the one chip it ends by that chip's persistent_id; a clock
## whose chip is already gone (replaced, consumed by the Naga's death) finds nothing and does nothing.
## The Sluagh needs no key because its re-target clears the old pair first.
##
## Hidden: the window's own chip, buff_ping, is what the player reads.
extends Buff

const TARGET_KEY := 'target'
const CHIP_KEY := 'chip'

func on_clear(event:EventCore, core:BuffCore, unit:Unit) -> void:
	if not Unit.is_valid(unit) or unit.map == null: return
	var target:Unit = unit.map.get_unit_by_id(StringName(core.get_state(TARGET_KEY, '')))
	if not Unit.is_valid(target): return
	var chip_id := StringName(core.get_state(CHIP_KEY, ''))
	for chip:BuffCore in target.state.buffs.duplicate():
		if chip.persistent_id == chip_id: UnitCondition.clear_buff(event, target, chip)
