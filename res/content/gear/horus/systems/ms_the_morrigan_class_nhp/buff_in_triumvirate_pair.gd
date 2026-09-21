## THE PAIR: "your chosen ally is always treated as being adjacent to you while within your
## Sensors, regardless of actual distance between you". Design ruling 23; spike section 6.
##
## A BUFF ON A CHANNEL OF OUR OWN. to = &'reag_adjacent_to' is read by ONE reader: the fourth banner
## in this mod's unit_relation.gd_ext.gd, which appends the partner to adjacent_characters(holder)
## while the owner's live Sensors still reach. talents' House Guard reads &'adjacency_range' and
## would also read it in ITS override - so this is deliberately NOT that channel (compat-seams.md,
## the Sixth Voice row).
##
## ONE CORE ON EACH END, EACH NAMING THE OTHER, because is_adjacent(a, b) is
## adjacent_characters(a).has(b) (unit_relation.gd:7-8) - one-sided. action_project_shield.gd is
## vanilla's precedent for the two-core-with-state shape. State PARTNER_KEY holds the partner's
## persistent id (BuffCore.set_state refuses a Unit, buff_core.gd:140); from_gear is the NHP on both,
## so get_owner_unit is the SLUAGH on either end - which is what the banner measures Sensors from.
##
## on_clear REFRESHES TRACKING, AND ERASES ITSELF FIRST. The Mark's soft-cover aura re-evaluates
## only from UnitTile.update_tracking_and_statuses (unit_tile.gd:15-24) or from a buff applied /
## cleared by aura-bearing gear (unit_condition.gd:713-715, :986-988) - and the NHP holds no aura.
## So when this pair expires the far ally's cover would linger until somebody moved. The refresh is
## here; but clear_buff calls on_clear BEFORE erasing the core (unit_condition.gd:979-980, Wickworks'
## own "comes before actually falling off... hm."), so a refresh made here would still SEE this
## buff and re-shelter the ally. Hence the erase: clear_buff erases again at :980 and Array.erase
## on an absent element is a no-op. Measured by test_in_triumvirate's "cover leaves" case.
##
## THE OWNER-SIDE CORE IS THE CLOCK FOR ALL THREE CHIPS, and that is card fidelity chosen over
## vanilla's edge (controller ruling, 2026-09-21). "Until the end of your next turn" is the SLUAGH'S
## next turn, and only the Sluagh's own core measures it correctly: turn_count ticks at the HOLDER's
## turn start (unit_condition.gd:24, for the STARTING unit alone, event_turn_start.gd:76), so the
## Sluagh's core reads 1 at its next turn start and clear_owners_turn_statuses clears it at the end
## of that turn (:62) - exactly the card. The ALLY's two chips carry the same until, but their
## turn_count ticks on the ALLY's turn, so an ally that has not started a turn since the press would
## keep them one Sluagh turn-end longer (lancer.gd:52's own warning; measured before this cascade
## existed). So they follow the owner's core instead of their own tick: when the Sluagh's core goes,
## it takes every buff from this gear off every other unit with it.
##
## NO RECURSION, and the asymmetry is what guarantees it: the cascade is gated on the holder BEING
## the owner, and the ally-side cores never are, so their own on_clear does the erase and the
## tracking refresh and stops. activate_for_target's re-target loop already clears every unit and
## stays idempotent under this - the cascade just gets there first and the loop finds nothing left.
extends Buff

const PARTNER_KEY := 'partner'

func on_clear(event:EventCore, core:BuffCore, unit:Unit) -> void:
	if not Unit.is_valid(unit) or unit.map == null: return
	unit.state.buffs.erase(core)
	if unit == core.get_owner_unit(unit.map):
		for other:Unit in unit.map.get_all_units():
			if other != unit: UnitCondition.clear_buffs_owned_by(event, other, core.from_gear)
	UnitTile.update_tracking_and_statuses(unit.map, event)
