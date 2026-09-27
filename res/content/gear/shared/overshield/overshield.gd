# OVERSHIELD: the mod's shared reader and granter. Born with the Myconid's Halo (SP1 Task 4).
#
# FROZEN INTERFACE (roadmap 4, and design 1.3 of the Myconid). Five functions, exactly these names
# and signatures. Five later frames consume them - Sluagh, Hazard, Naga, Primrose, Black Mountain -
# so a rename is five frames' worth of churn. A later frame that needs MORE extends this file in its
# own sub-project, with every earlier spec still green; "granted by" tracking is explicitly not born
# here, and is assigned to Black Mountain's SP1.
#
# ADDITIONS ARE ALLOWED AND TWO HAVE LANDED. The Sluagh (SP1 Task 4) needed grant() to refresh the
# target's cached stats after the event, because its Inexorable Formation reads Overshield through a
# STATBLOCK buff and nothing else rebuilds that cache. No signature moved; see grant()'s own header.
#
# THE BLACK MOUNTAIN (SP1, 2026-09-27, design rulings 5-6) added the planned "GRANTED BY" tracking -
# THREE public functions, grant_by / increase_by / is_granted_by, and the hidden mark
# buff_overshield_granted_by.tres beside this file - and changed ONE frozen body: increase() now puts
# `boolean = true` in the event data it fires (see increase()'s header; the resident Emperor mod reads
# it). The five frozen signatures did not move. spec/test_overshield.gd pins all EIGHT public
# functions and fails on a ninth; the underscore-prefixed helpers below are private by convention and
# outside that count.
#
# No class_name (lancer-tactics-gdscript skill, and res/content/gear/shared/README.md): global class
# names are registered from project.godot's class list, which is built at startup, so one declared in
# a script a mod loads at runtime is never registered and cannot be referenced by that name at all.
# Callers preload this file. Same shape as Thy Hubris' infection.gd, which is the mod-side precedent
# for the whole pattern.
#
# THE ONE ENGINE RULE WORTH KNOWING: event_unit_overshield sets
# state.overshield = max(0, max(old, amount)) (event_unit_overshield.gd:15). It NEVER adds. Every
# card that says "gains OVERSHIELD equal to X" wants exactly that, which is what grant() is; the
# handful that say "increases by that much instead" want increase(), which is the same event handed
# current + X.
extends RefCounted

const OVERSHIELD_EVENT := &'event_unit_overshield'

## The "granted by" mark (Black Mountain SP1, ruling 5): hidden, until = LOSE_OVERSHIELD, applied with
## from_gear = the granter's gear, so BuffCore.get_owner_unit() names the granter. Looked up through
## ContentLibrary at call time rather than preloaded, so a broken mark file cannot take THIS file's
## parse down and the five consumers with it.
const GRANTED_BY_MARK := &'buff_overshield_granted_by'

## This unit's overshield. 0 for anything that is not a live Unit - every consumer calls this from
## inside a reaction gate, which the bus runs for every unit's every gear on every event, so a null
## here would be an error storm rather than a wrong answer. Unit.is_valid includes is_alive, so a
## DEAD unit reads 0 here too, not whatever overshield it held before dying.
static func current(unit:Unit) -> int:
	if not Unit.is_valid(unit): return 0
	return unit.state.overshield

## True only above zero - see current() for what makes a unit read as having none.
static func has(unit:Unit) -> bool:
	return current(unit) > 0

## Grant `amount` overshield, the engine's way: the target ends with max(what it had, amount).
##
## amount <= 0 IS A NO-OP AND FIRES NO EVENT. The event always plays a popcorn and writes a battle
## log line (event_unit_overshield.gd:17-22), so a zero grant would put "now has 0 overshield" on
## screen and in the log - which is what a Grit 0 pilot's Halo would do on every hit it took.
##
## Runs the event on the caller's own block when there is one, and through the level when there is
## not. Infection.apply's idiom, for the same reason: a caller inside a live activation wants its
## event ordered inside that activation, and a caller holding a spec's dummy event (or no event at
## all) has no block to queue onto.
##
## IT REFRESHES THE TARGET'S CACHED STATS AFTERWARDS - THE FIRST ADDITION TO THIS FROZEN FILE (the
## Sluagh, SP1 Task 4, ruling 12). Its Inexorable Formation is a Buff.TO.STATBLOCK buff whose
## get_values reports the holder's CURRENT Overshield as a sensor-range bonus, and state.stat_bonus
## is rebuilt only by UnitBattleState.update_cached_values (unit_battle_state.gd:229-234), which
## event_unit_overshield never calls - its whole body is one assignment, a popcorn and a log line.
## The reaction bus has no overshield trigger to hang a listener on (reaction_bus.gd:9-42), so
## without this line every gain through this helper would be invisible to that frame's Sensors until
## something unrelated rebuilt the cache. Overshield the Sluagh gains from a VANILLA or third-party
## source is still seen only at the next rebuild; that lag is recorded and cosmetic (design 1.4).
##
## NO EVENT IS PASSED TO THE REFRESH, and that matters. update_cached_values_and_token(event) with a
## NON-null event runs UnitTile.move_to(self, tile, true, event) -> update_tracking_and_statuses
## (unit.gd:158-160, unit_tile.gd:12), a MAP-WIDE pass that re-evaluates every aura, engagement and
## water status on every unit and can queue real events. On every Overshield grant in the game that
## would be both expensive and wrong: a shield gain is not a tile update. The bare form refreshes the
## cached values and the token and stops, which is what buff_effervescent_immunity does for the same
## reason.
##
## increase() INHERITS THIS AND DOES NOT REPEAT IT. Both public functions run the same private
## _fire(); increase's own amount <= 0 guard means the value it passes is always positive, so _fire
## can never take its early return without doing the refresh.
## test_increase_refreshes_the_cache_too_by_inheriting_grants is the pin.
##
## THE EVENT DATA CARRIES NO `boolean` FROM HERE, deliberately (Black Mountain ruling 6): the resident
## Emperor mod's Imperial Vestment reads a plain grant to an Emperor as "add this to what it holds,
## capped" - the Emperor's own card - and that is meant to land. Only increase() says otherwise.
static func grant(event:EventCore, target:Unit, amount:int) -> void:
	await _fire(event, target, amount, false)

## Additive: the target ends with what it had PLUS amount. For the cards that say "increases by that
## much instead" - Black Mountain's Exalt, Fell the Mighty, DOOMED (frame close finding M-4: Dread
## Harbinger's 1d6 is a plain grant(), max semantics per ruling 9 - it is not an increase_by caller).
##
## Built on the same private path as grant() rather than on state.overshield directly, so it inherits
## the no-op, the validity guard, the event plumbing and the cache refresh rather than re-deriving them.
##
## IT PUTS `boolean = true` IN THE EVENT DATA - THE SECOND CHANGE TO THIS FROZEN FILE'S BEHAVIOUR
## (Black Mountain SP1, ruling 6, a COMPAT fix; the signature did not move). Vanilla never reads
## `boolean` on this event (optional props are not checked, event_base.gd:17-19, :48), so on a stock
## game the flag is inert. The resident gavstarb-ssc_emperor's event_unit_overshield.gd_ext.gd declares
## it optional with the comment "true if the overshield number is current overshield plus a value", and
## its Imperial Vestment reads it exactly so (action_imperial_vestment.gd:14-22): when the shielded
## unit is the Emperor it rewrites the number to min(current + delta, 6 + Grit), where delta is the
## whole number WITHOUT the flag and (number - current) WITH it. Without the flag an Emperor ally
## holding 2 that we increase by 1 would end at 2 + 3 = 5 - MEASURED (probe P2, 2026-09-27), and the
## flag turns it into the 3 the card means. spec/test_overshield.gd pins the data; spec/test_compat.gd
## pins the Emperor's number under the resident.
static func increase(event:EventCore, target:Unit, amount:int) -> void:
	if amount <= 0 or not Unit.is_valid(target): return
	await _fire(event, target, current(target) + amount, true)

## The pilot's Grit: half licence level, ROUNDED UP (PilotCore.get_grit -> Util.half -> ceili,
## util.gd:14-15; the engine's own glossary row for lancer.term.grit says "rounded up" too). So only
## licence level 0 is Grit 0.
##
## Guarded the Aceso way (action_aceso_stabilizer.gd:9): deployables, drones and NPC props have no
## pilot at all, and a gate that dereferenced one would throw from inside a reaction poll.
static func grit(unit:Unit) -> int:
	if not Unit.is_valid(unit): return 0
	if not PilotCore.is_valid(unit.core.pilot): return 0
	return unit.core.pilot.get_grit()

# ---------------------------------------------------------------- "granted by" (Black Mountain SP1)
#
# The card that needs it: An End to All Things - "when an allied character with OVERSHIELD you
# granted makes a successful attack roll ...". Lancer's Overshield does not stack, so "whose" is
# undefined the moment a larger grant from somebody else lands; the author took the SIMPLE lifetime
# (ruling 5): the mark lives WHILE ANY OVERSHIELD REMAINS on the target, whoever topped it up. That is
# the engine's own lifetime for "attached to this Overshield" - Lancer.UNTIL.LOSE_OVERSHIELD
# ("aceso stabilizer, emperor eventually", lancer.gd:55): event_unit_damage clears every buff carrying
# it the moment damage zeroes the shield (event_unit_damage.gd:175-177), and the resident Emperor's two
# clears do the same. THAT IS NOT EVERY PATH (frame close finding 1, Important): TWO vanilla routes
# write state.overshield down WITHOUT that clear -
#   (a) HEAT on a unit with heat cap <= 0 (a pilot on foot): event_unit_damage's HEAT branch calls
#       heat(), which turns heat into damage(unit, amount, ENERGY) when get_heat_max() <= 0, and
#       damage() spends Overshield first - that whole branch never touches LOSE_OVERSHIELD.
#   (b) THE PEGASUS'S USHABTI OMNIGUN (action_fire_omnigun.gd:60) calls
#       EventUnitDamage.damage(target_unit, amount, KINETIC) DIRECTLY, skipping the event (and its
#       clear) entirely.
# Either can zero a marked unit's shield and leave the mark stale. is_granted_by() closes the READ
# side (it checks has(unit) first, so a unit with no Overshield never reads as "granted by" anyone
# regardless of a stale mark); a foreign grant landing on a still-stale mark could still re-credit it
# to the wrong granter, which is recorded as a remaining gap rather than fixed here.
#
# THE MARK IS APPLIED ONLY WHEN THE GRANT TOOK: after the event, the target holds Overshield, and
# either it holds MORE than before or the amount asked was at least what it held (a grant equal to
# the current shield "refreshes" it - the max rule made it a no-op on the number, not on the card). A
# grant that lost to a larger existing shield marks nothing: the Black Mountain did not grant that.
#
# from_gear = the granter's gear, so get_owner_unit() names the granter and apply_buff_alt's
# same-source replacement (unit_condition.gd:741-747) REFRESHES rather than stacks when the same gear
# grants again. Two Black Mountains granting one ally each hold their own mark. The engine's default
# is_cleared_on_owner_death ends the mark with the granter (event_service.gd:71): nothing of the
# granter's is left to key on it, which is also ruling 13's reading of DOOMED after the Black
# Mountain dies.
#
# A NULL OR INVALID granter_gear DEGRADES TO THE PLAIN CALL WITH NO MARK. DOOMED's +1 after the Black
# Mountain's death takes exactly this path (ruling 13): the buff still fires, its owner gear no
# longer resolves, the ally still gains the shield, and nobody is marked.

## grant() plus the mark. The five frozen signatures are untouched; this is an addition (ruling 5).
static func grant_by(event:EventCore, target:Unit, amount:int, granter_gear:GearCore) -> void:
	if amount <= 0 or not Unit.is_valid(target): return
	var before := current(target)
	await grant(event, target, amount)
	_mark_if_took(event, target, before, amount, granter_gear)

## increase() plus the mark. The amount "asked" of the engine is before + amount, so an increase that
## the engine (or the Emperor's cap) left at the old number still marks: the ally holds Overshield and
## the Black Mountain just added to it.
static func increase_by(event:EventCore, target:Unit, amount:int, granter_gear:GearCore) -> void:
	if amount <= 0 or not Unit.is_valid(target): return
	var before := current(target)
	await increase(event, target, amount)
	_mark_if_took(event, target, before, before + amount, granter_gear)

## Does `unit` hold Overshield that `granter` granted (through grant_by / increase_by) and has not
## lost since? False for an invalid unit, an invalid granter, a unit with no Overshield RIGHT NOW
## (frame close finding 1, Important - see the "granted by" section header: two vanilla paths can
## zero state.overshield without clearing the mark, so the mark alone is not proof), or a mark whose
## owner cannot be resolved (the granter's gear is gone). Cheap enough for a reaction gate: it walks
## the unit's own buffs.
static func is_granted_by(unit:Unit, granter:Unit) -> bool:
	if not Unit.is_valid(unit) or not Unit.is_valid(granter): return false
	if not has(unit): return false
	for mark:BuffCore in UnitCondition.get_buffs(unit, GRANTED_BY_MARK):
		if mark.get_owner_unit(unit.map) == granter: return true
	return false

# ---------------------------------------------------------------- private

## The one path every grant takes - grant()'s body before the Black Mountain split it, unchanged
## except for the `additive` flag that becomes `boolean = true` on the event (see increase()).
static func _fire(event:EventCore, target:Unit, amount:int, additive:bool) -> void:
	if amount <= 0 or not Unit.is_valid(target): return
	var data := {unit = target, number = amount}
	if additive: data.boolean = true
	if event != null and event.is_block_valid():
		await event.execute_event(OVERSHIELD_EVENT, data)
	else:
		var level := X.current_level()
		if level != null: await level.execute_event(OVERSHIELD_EVENT, data)
	# Re-checked: the event ran, and something reacting to it could in principle have removed the
	# target from the game.
	if Unit.is_valid(target): target.update_cached_values_and_token()

## Hang the "granted by" mark if the grant took (see the section header for the rule).
static func _mark_if_took(event:EventCore, target:Unit, before:int, asked:int, granter_gear:GearCore) -> void:
	if not GearCore.is_valid(granter_gear) or not Unit.is_valid(target): return
	var now := current(target)
	if now <= 0: return
	if not (now > before or asked >= before): return
	var mark_base:Buff = ContentLibrary.get_buff(GRANTED_BY_MARK)
	if mark_base == null: return
	var mark := BuffCore.create(mark_base, granter_gear.persistent_id)
	# apply_buff_alt reads event.context; a caller with no event gets the same stand-in a spec's
	# dummy event is (SpecFactory.dummy_event is EventCore.create(&'event_delay', ...)).
	var carrier:EventCore = event if (event != null and event.context != null) else EventCore.create(&'event_delay', {unit = target})
	UnitCondition.apply_buff_alt(carrier, target, mark)
