## GEMINI CHARGE: redirect the Lovers Knot's shot from the first character it reaches to another one
## (design 2, rulings 7-16). The seam is Spike 8's: ATTACK_DECLARED PRE, where a unit APPENDED to the
## DeclaredAttackSummary is rolled against in the same declared attack, because execute() only copies
## all_attacked_units after the PRE block (event_unit_attack_declared.gd:21-23, :54). One declared
## attack, one ATTACK_DECLARED PRE/POST, one IS_FIRST_ROLL_IN_ATTACK - "this counts as one attack" is
## inherent (ruling 15) - except for the Knot's ONE-TIME roll buffs, which the engine consumes per target
## roll: onhit_gemini_one_attack makes every target read them and consumes them once, after the attack
## (Pass F task 11c, the author's report 2026-09-28 - Core Siphon's +1 had reached only the contact).
##
## IN ORDER:
##   1. The gates (triggers_on_event): the Knot itself (not a drone it owns, whose get_attacker() is the
##      Knot too), player-controlled (16c), an eligible weapon (8), a character contact (12), the round
##      unspent (7), and the declared attack not already looked at.
##   2. For each leg: the leg's weapon is the attack's own action DUPLICATED at the remaining reach (a
##      RangePattern is a shared sub-resource, so it is duplicated before its value moves). The set it may
##      aim at is measured from a proxy on the leg's start - vanilla's own "attack from a place that is
##      not ourselves" - and narrowed to characters not yet attacked (12); for a Line, to aims whose line
##      reaches one (13). An empty set ends the chain; on the first leg nothing was ever asked.
##   3. The first leg alone gets the yes/no (7, 18). Then vanilla's proxy picker, narrowed to that set
##      by buff_gemini_leg_tiles. A decline or a cancel ends the chain, and the round is only stamped
##      if a leg was committed.
##   4. Commit: a Line is cut past the contact - the shot BENDS (13) - and, under the Myriad, each leg is
##      cut again past the character the NEXT leg starts from (18); every leg's units and tiles are
##      appended; the declared flags are REPLACED with HALF_DAMAGE added (14); the record goes on the
##      summary for the three permanent buffs to read; each leg's tracer is drawn; the round is stamped.
##
## HALF_DAMAGE IS A REPLACED ARRAY, NEVER AN APPEND. Context.create keeps the activation's flags array by
## reference, so an append would halve a queued second-aux follow-up as well (context.gd:72-100, memory
## lancer-tactics-attack-relay-seam).
##
## EARLY PRIORITY. PRE reactions and buffs share one block ordered by get_priority() (lower sooner), and
## a PRE reader of the target list - the talents' NOAH ward is the resident one - sees the appended
## target only if it runs after this. It cannot change what such a reader's TRIGGER saw: the bus
## evaluates every trigger gate before any block runs.
##
## THE MYRIAD CHAIN (SP3, rulings 18-19) is already the loop's shape: under buff_form_of_the_myriad
## the leg count is 4, every leg has the weapon's full reach, and each leg starts from the character
## the previous one reached. Without the chip it is one leg at the remaining reach.
##
## A LINE BENDS AT EVERY LEG (ruling 18, confirmed by the author at the close review, 2026-09-26): once
## the next leg is committed, a Line leg keeps only what it reached up to the character the next leg
## starts from. The LAST committed leg is never cut - nothing bends it - and a leg whose next picker is
## cancelled stays whole. Exclusion follows the bend: the next leg may reach a character that lay past
## it, since the shot never touched them (the SP2 reading of ruling 12, extended).
##
## BANNED TARGETS: every aim and every leg's units are also checked against the KNOT's own
## ACTION_BANNED_UNITS (Record.is_banned) - a leg's SpecificAction is a buffless proxy's.
extends Buff

const Record := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/cp_integrated_redirection_aggregate/gemini_record.gd')

func get_priority() -> int: return Priority.ATTACK.mandatory - 1

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action, Context.PROP.resource]

func triggers_on_event(core:BuffCore, unit:Unit, triggering:EventCore) -> bool:
	var context:Context = triggering.context
	if context.unit != unit: return false
	if not unit.is_player_controlled(): return false
	var summary = context.resource
	if not DeclaredAttackSummary.is_valid(summary) or summary.has_meta(Record.ASKED): return false
	if not Record.is_eligible_weapon(unit, context.gear, context.action): return false
	var gear:GearCore = core.get_owner_gear(context.map)
	if not GearCore.is_valid(gear) or gear.get_uses_this_round_alt(Record.USAGE_KEY) > 0: return false
	return Record.find_contact(unit, summary) != null

func activate(core:BuffCore, activation:EventCore) -> void:
	var declared:EventCore = activation.context.event
	var context:Context = declared.context
	var knot:Unit = core.get_holder_unit(activation.context.map)
	var core_gear:GearCore = core.get_owner_gear(activation.context.map)
	var summary:DeclaredAttackSummary = context.resource
	if not Unit.is_valid(knot) or not GearCore.is_valid(core_gear): return
	summary.set_meta(Record.ASKED, true)

	var weapon := SpecificAction.create(knot, context.gear, context.action)
	var contact := Record.find_contact(knot, summary)
	if contact == null: return
	var line := Record.is_line(weapon)
	var full_reach:int = context.action.get_target_range(weapon)

	# What the shot reaches before it bends: everything up to and including the contact (ruling 13).
	var reach_to_contact:int = UnitRelation.distance_between(knot, contact)
	var kept_tiles:Array[Vector2i] = summary.all_attacked_tiles.duplicate()
	var kept_units:Array[Unit] = summary.all_attacked_units.duplicate()
	if line:
		reach_to_contact = contact_distance_along_line(knot, contact, summary.all_attacked_tiles)
		Util.filter(kept_tiles, func(tile:Vector2i) -> bool: return Tile.distance(knot.tile(), tile) <= reach_to_contact)
		Util.filter(kept_units, func(unit:Unit) -> bool:
			return Unit.is_valid(unit) and unit.occupied_tiles().any(func(tile:Vector2i) -> bool: return kept_tiles.has(tile)))

	var myriad:bool = UnitCondition.has_buff(knot, Record.MYRIAD_CHIP)
	var max_legs:int = Record.MYRIAD_LEGS if myriad else 1
	var excluded:Array[Unit] = kept_units.duplicate() # the Knot itself is refused by is_new_character
	var legs:Array[Dictionary] = [] # {start:Unit, start_voxels, units, tiles, end} (+ bent_units, bent_tiles, bent_end for a Line)
	var start:Unit = contact

	for leg_index:int in max_legs:
		var reach:int = full_reach if myriad else full_reach - reach_to_contact
		if reach <= 0 or not Unit.is_valid(start): break
		var leg := make_leg(context.action, reach, line)
		var allowed := allowed_aims(knot, context.gear, leg, start, reach, line, excluded)
		if allowed.is_empty(): break

		if leg_index == 0:
			var confirmed := await ask_yes_no(core, knot, contact)
			if activation.abort_without_unit(knot): return
			if not confirmed: break

		leg.set_meta(Record.LEG_TILES, Tile.to_bitwise_array(allowed))
		var plan:CompconPlan = await TargetActionUtil.ask_for_targets_from_proxy(
			activation, knot, context.gear, leg, start.tile(), start.get_size())
		if activation.abort_without_unit(knot): return
		if plan == null or plan.aborted: break

		var reached := resolve_leg(knot, context.gear, leg, plan, start, reach, line, allowed, excluded)
		if reached.units.is_empty(): break
		if line and not legs.is_empty(): bend(legs.back()) # this leg is committed: the previous one bends here
		reached.start = start
		reached.start_voxels = UnitTile.get_occupied_voxels(start)
		legs.append(reached)
		excluded.append_array(reached.bent_units if line else reached.units)
		start = reached.next_start

	if legs.is_empty(): return
	commit(knot, core_gear, context, summary, contact, line, kept_tiles, kept_units, legs)


## The weapon again, at `reach`. A duplicate, so the Kit's own action and every other unit's copy of this
## weapon are untouched; and its RangePattern is duplicated too before its value moves, because a
## sub-resource is shared until it is.
static func make_leg(action:ActionAttackWeapon, reach:int, line:bool) -> ActionAttackWeapon:
	var leg:ActionAttackWeapon = action.create_duplicate_for_variant()
	if line:
		leg.range_pattern = leg.range_pattern.duplicate()
		leg.range_pattern.value = reach
	else:
		leg.aim_range = reach
	return leg

## Where a Line drawn from `origin` first meets `contact`: the nearest of the contact's tiles that the
## line crossed. A Line is drawn in rings of Chebyshev distance from its origin (aoe_calculator.gd:143),
## so everything at a greater distance is past the contact. The first bend measures from the Knot, every
## later one from the leg's start.
static func contact_distance_along_line(origin:Unit, contact:Unit, tiles:Array[Vector2i]) -> int:
	var best := -1
	for tile:Vector2i in contact.occupied_tiles():
		if not tiles.has(tile): continue
		var distance:int = Tile.distance(origin.tile(), tile)
		if best < 0 or distance < best: best = distance
	return best if best >= 0 else UnitRelation.distance_between(origin, contact)

## A committed Line leg that another leg continues from: cut past the character it bends at (ruling 18).
static func bend(leg:Dictionary) -> void:
	leg.units = leg.bent_units
	leg.tiles = leg.bent_tiles
	leg.end = leg.bent_end

static func line_tiles(knot:Unit, start:Unit, aim:Vector2i, reach:int) -> Array[Vector2i]:
	return AoeCalculator.line(start.tile(), aim, reach, knot.map.shape)

## Every aim the leg may take, measured from a proxy on the leg's start with the leg's own weapon: for
## a single-target weapon the tiles of each character it could redirect to, for a Line each aim whose
## line reaches one. Measured BEFORE the yes/no, so the player is never asked about a leg with nowhere
## to go (ruling 7). The proxy is removed before anything is asked; the picker makes its own.
static func allowed_aims(knot:Unit, gear:GearCore, leg:ActionAttackWeapon, start:Unit, reach:int, line:bool,
		excluded:Array[Unit]) -> Array[Vector2i]:
	var proxy := TargetActionUtil.create_targeting_proxy(start.tile(), knot, start.get_size())
	var specific := SpecificAction.create(proxy, gear, leg)
	var allowed:Array[Vector2i] = []
	for tile:Vector2i in UnitTargeting.get_tiles_targetable(specific):
		if line:
			var on_leg:Array = knot.map.get_all_units_at_tiles(line_tiles(knot, start, tile, reach), knot)
			if on_leg.any(func(unit:Unit) -> bool:
				return Record.is_new_character(unit, knot, excluded) and not Record.is_banned(knot, gear, leg, unit)):
				allowed.append(tile)
		else:
			for unit:Unit in knot.map.get_all_units_at_tile(tile, proxy):
				if (Record.is_new_character(unit, knot, excluded) and leg.can_target_unit(unit, specific)
						and not Record.is_banned(knot, gear, leg, unit)):
					allowed.append(tile)
					break
	if Unit.is_valid(proxy): proxy.remove_from_game()
	return allowed

## "Use Gemini Charge?" - the author's explicit prompt before the picker (ruling 7).
func ask_yes_no(core:BuffCore, knot:Unit, contact:Unit) -> bool:
	var brochure := BrochureCore.create({
		title = core.name_text(),
		description = core.effect_text(),
		show_continue = false,
	})
	return await choice_bus.quick_yesno_for({
		tile = contact.tile(),
		title = tr('battle.confirm.use').format({action = Util.formatted_color(
			core.name_text(), Colors.get_action_color(Action.FLAVOR.WEAPON))}),
		brochure = brochure,
		whois = contact,
	})

## What a committed leg reaches. The plan is re-checked against the set the picker was narrowed to, so
## a pick of the contact or the Knot - which the harness, unlike the real picker, would pass - adds
## nothing. For a single-target weapon, the picked character; for a Line, every unit on the leg not yet
## attacked (every character on it is hit, ruling 13), and the leg continues from the first character -
## with, for a Line, the part up to that character kept aside as bent_* in case another leg follows. A
## unit the Knot may not target is skipped, as the engine drops it from an AoE (action_attack.gd:172).
static func resolve_leg(knot:Unit, gear:GearCore, leg:ActionAttackWeapon, plan:CompconPlan, start:Unit,
		reach:int, line:bool, allowed:Array[Vector2i], excluded:Array[Unit]) -> Dictionary:
	var reached := {units = [] as Array[Unit], tiles = [] as Array[Vector2i], next_start = null, end = start.tile()}
	if line:
		if plan.target_tiles.is_empty() or not allowed.has(plan.target_tiles[0]): return reached
		var tiles := line_tiles(knot, start, plan.target_tiles[0], reach)
		reached.tiles.assign(tiles)
		if not tiles.is_empty(): reached.end = tiles.back()
		var nearest := -1
		for unit:Unit in knot.map.get_all_units_at_tiles(tiles, knot):
			if not Unit.is_valid(unit) or unit == knot or excluded.has(unit) or reached.units.has(unit): continue
			if Record.is_banned(knot, gear, leg, unit): continue
			reached.units.append(unit)
			if not Record.is_new_character(unit, knot, excluded): continue
			var distance:int = UnitRelation.distance_between(start, unit)
			if nearest < 0 or distance < nearest:
				nearest = distance
				reached.next_start = unit
		if reached.next_start == null:
			reached.units.clear() # no character on it: not a leg (ruling 13)
			return reached
		var bend_at := contact_distance_along_line(start, reached.next_start, tiles)
		var bent_tiles:Array[Vector2i] = []
		bent_tiles.assign(tiles.filter(func(tile:Vector2i) -> bool: return Tile.distance(start.tile(), tile) <= bend_at))
		var bent_units:Array[Unit] = []
		bent_units.assign(reached.units.filter(func(unit:Unit) -> bool:
			return unit.occupied_tiles().any(func(tile:Vector2i) -> bool: return bent_tiles.has(tile))))
		reached.bent_tiles = bent_tiles
		reached.bent_units = bent_units
		reached.bent_end = reached.next_start.tile()
	else:
		var picked:Array[Unit] = []
		picked.assign(plan.target_units)
		if picked.is_empty():
			for tile:Vector2i in plan.target_tiles: picked.append_array(knot.map.get_all_units_at_tile(tile, knot))
		for unit:Unit in picked:
			if not Record.is_new_character(unit, knot, excluded): continue
			if Record.is_banned(knot, gear, leg, unit): continue
			if not unit.occupied_tiles().any(func(tile:Vector2i) -> bool: return allowed.has(tile)): continue
			reached.units.append(unit)
			reached.tiles.append_array(unit.occupied_tiles())
			reached.next_start = unit
			reached.end = unit.tile()
			break
	return reached

static func commit(knot:Unit, core_gear:GearCore, context:Context, summary:DeclaredAttackSummary, contact:Unit,
		line:bool, kept_tiles:Array[Vector2i], kept_units:Array[Unit], legs:Array[Dictionary]) -> void:
	if line: # the shot bends at the contact: nothing past it is attacked (ruling 13)
		summary.all_attacked_tiles.assign(kept_tiles)
		summary.all_attacked_units.assign(kept_units)
	var record_legs := {}
	for leg:Dictionary in legs:
		for unit:Unit in leg.units:
			Util.append_nonduplicate(summary.all_attacked_units, unit)
			record_legs[unit.core.persistent_id] = leg.start_voxels
		for tile:Vector2i in leg.tiles: Util.append_nonduplicate(summary.all_attacked_tiles, tile)
	summary.set_meta(Record.RECORD, {contact = contact, legs = record_legs})

	if not context.flags.has(Action.FLAG.HALF_DAMAGE):
		var flags:Array = context.flags.duplicate()
		flags.append(Action.FLAG.HALF_DAMAGE)
		context.flags = flags

	draw_legs(context, legs)
	core_gear.increment_action_usage(Record.USAGE_KEY, false)

## Each leg's tracer, drawn by hand from its start: the engine drew the first one to the original
## target before PRE (action_attack.gd:265). Throughbolt's shape, not awaited
## (action_throughbolt_line.gd:76-85).
static func draw_legs(context:Context, legs:Array[Dictionary]) -> void:
	var action:ActionAttackWeapon = context.action
	for leg:Dictionary in legs:
		var from:Unit = leg.start
		if not Unit.is_valid(from): continue
		CommonActionUtil.run_attack_and_target_fx(
			action.get_attack_fxg(context.gear, action), from,
			action.get_target_fxg(context.gear, action), [leg.end],
			null, [],
			[
				CommonActionUtil.RUN_FX_FLAGS.skip_awaiting_use_preamble,
				CommonActionUtil.RUN_FX_FLAGS.skip_awaiting_target_preamble,
			]
		)
