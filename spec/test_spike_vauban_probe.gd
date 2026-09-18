# VAUBAN SP1, THE PROBE (design §1.0): three claims the design leans on that reading could not
# settle, each measured against the 1.4.3 engine on vanilla units before any Vauban content exists.
#
# THIS IS A PROBE, NOT CONTENT. Every resource it uses is built in code, in this file, on a knockoff
# Everest; nothing under spec/ is ever scanned into ContentLibrary. Deleted once the real specs
# (test_sap.gd, test_solfataric_breach.gd) pin the same claims against the real traits - the same
# life cycle as test_spike_status_aura.gd (Myconid SP2) and test_spike_teleport_interception.gd
# (Maiden's Blush SP1).
#
# THE THREE CLAIMS, AND WHAT READING THE ENGINE PREDICTS FOR EACH (2026-09-18, Fable):
#
#  A. "A step-PRE reaction may apply Slowed to the mover, and the move truncates." Half right. The
#     STEP PRE reactions are AWAITED inside the step loop (event_unit_move.gd:198, through
#     execute_reaction_events_for_entire_katamari's core.execute_events at :334), with
#     context.target_tiles set to the tile about to be entered (:325-327) - so a reaction there can
#     apply Slowed before the step lands. But NOTHING in the move loop reads Slowed: the after-step
#     re-check has_enough_move_to_reach_end (:288-291, :440-476) compares the path's remaining cost
#     against unit.core.current.speed, and Slowed never touches current.speed - the engine's Slowed
#     is a BOOST prohibition (unit_action.gd:499) and a can-only-standard-move rule, not a halved
#     budget. Prediction: the mover is Slowed and STILL ARRIVES. (Only Immobilized aborts a voluntary
#     move mid-way, :451.) Sap's Slowed therefore bites the hostile's NEXT boost or move, not the one
#     that entered the field - which is Lancer's own reading of Slowed, so no ruling changes.
#
#  B. "statuses_changed at PRE fires for apply_status, fires again on a re-application, and never
#     fires for a buff-carried status." The third clause is WRONG by reading, and this is the
#     measurement that matters most for Solfataric Breach. The trigger is queued from
#     UnitCondition.on_status_application (unit_condition.gd:164-167), which is called AFTER the
#     StatusCondition is appended (:105-108) - so at the gate the unit ALREADY holds the status,
#     and an immune unit never reaches the gate at all (the early return at :93-99 comes first).
#     And apply_buff_alt calls on_status_application for every status in a buff's applies_statuses
#     (:758-762), so a ZONE-carried Slowed - the Myconid's cloud, the Magnetic Field Projector's
#     Immobilized - DOES fire this trigger, with the buff's from_gear as its source. What
#     distinguishes the two at the gate is unit.state.statuses: a direct application lists a
#     StatusCondition there (one per application, duplicates and all, :105), a buff-carried one
#     lists nothing and is only in the cache. So Breach's "becomes X" is NOT has_status (always true
#     at the gate): it is the count of listed StatusConditions of that type, read at the gate.
#
#  C. "At the pre-application of Grappled, 'not larger than the grappler' is decidable." Decidable
#     on the SECOND of two applications. onhit_grapple.gd:13-18 runs Katamari.attach_units first,
#     whose validate_attachments applies an UNSOURCED Grappled to each side (katamari.gd:313) while
#     is_larger_in_grapple is still stale, then recalculate_largest_unit sets the flag (:170), then
#     applies a SOURCED Grappled to each side whose source is the OTHER unit's core id. So the
#     sourced application is the one to read: get_origin_unit_for_source resolves the grappler and
#     state.is_larger_in_grapple is already right. The unsourced one names nobody.
#
# HOW THE REACTIONS GET ONTO A UNIT: test_draw_fire.gd's install_recorder() idiom - a Kit built in
# code, appended to loadout.equipped_kits, then full_repair(), which is what rebuilds
# LoadoutCore.reactions_by_trigger (loadout_core.gd:291-296); without it the reaction is invisible to
# ReactionBus.trigger_occurred.
#
# AN IN-CODE REACTION MUST CARRY AN ID, OR ITS GATE IS ASKED TWICE. Measured on this probe's first
# run (2026-09-18): every count came back exactly doubled. Action.get_id() reads original_id, else the
# resource path's basename - empty for a Resource built in code - and ReactionBus.does_reaction_trigger
# opens with `if rxn.get_id() == X.DEBUG_REACTION`, whose default is ALSO &'' (global.gd:239). The
# debug branch then calls triggers_on_event once for its print before the real evaluation calls it
# again (reaction_bus.gd:97-108). One block is still queued; only the GATE runs twice. Setting
# original_id in _init() is the fix. test_draw_fire.gd's TerrainRecorder has the same hole and
# records every tile twice - harmless there, since it only asks whether a tile was recorded at all.
#
# STATUSES ARE APPLIED THROUGH THE REAL EVENT, never SpecFactory.apply: that helper hands
# apply_status a dummy_event() whose block is not valid, and EventCore.queue_reaction_events returns
# on is_block_valid() before asking the bus (event_core.gd:60) - so a status applied that way fires
# nothing, and a probe built on it would read "never fires" for the boring reason.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_vauban_probe.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const OBSERVER_TILE := Vector2i(0, 0)
const START := Vector2i(2, 2)
## The one watched tile the step probe treats as "difficult ground" - two steps into a four-step move.
const FIELD := Vector2i(4, 2)
## A three-tall field for the knockback case, because the attacker's knockback cone offers the
## responder a choice of column-4 tiles and this probe does not care which one it takes.
const FIELD_COLUMN:Array[Vector2i] = [Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)]
const DESTINATION := Vector2i(6, 2)

const STEP_KIT := &'probe_vauban_step_slower'
const STATUS_KIT := &'probe_vauban_status_recorder'
const ZONE_KIT := &'probe_vauban_zone'
const ZONE_BUFF := &'buff_probe_vauban_zone'
const IMMUNITY_BUFF := &'buff_probe_vauban_immunity'

var game:Gamemaster
var observer:Unit


# =============================== THE PROBE'S THROWAWAY REACTIONS ===============================

## Sap's shape: a non-consuming step PRE reaction that Slows any OTHER unit about to step onto a
## watched tile from a tile that is not watched. Records every gate it is asked, whether or not it
## fires, so a test can read what the engine handed it.
class StepSlower extends ActionReaction:
	var field:Array[Vector2i] = []
	var fires:Array[Dictionary] = []

	func _init() -> void:
		original_id = &'action_probe_step_slower' # see the header: an id-less in-code reaction is double-gated
		triggers_on = [ReactionBus.TRIGGER.STEP]
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit]

	func get_per_round_hard_limit(_specific:SpecificAction) -> int:
		return 99

	func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		var mover:Unit = context.unit
		if mover == unit: return false
		var next:Vector2i = context.target_tiles.front() if not context.target_tiles.is_empty() else Tile.INVALID
		var entering:bool = field.has(next) and not field.has(mover.state.tile)
		var voluntary = context.resource.voluntary if MovementType.is_valid(context.resource) else null
		fires.append({
			mover = mover.core.persistent_id,
			from = mover.state.tile,
			next = next,
			voluntary = voluntary,
			knockback = context.flags.has(EventUnitMove.FLAG.IS_KNOCKBACK),
			entering = entering,
		})
		return entering

	func activate(context:Context, activation:EventCore) -> void:
		var mover:Unit = context.event.context.unit
		if not Unit.is_valid(mover): return
		UnitCondition.apply_status(activation, mover, Lancer.STATUS.SLOWED, Lancer.UNTIL.END_OF_NEXT_TURN, context.gear.persistent_id)


## Breach's shape: a non-consuming statuses_changed PRE reaction that records what the GATE sees for
## every status applied anywhere on the map, then what its ACTIVATION sees. `gate_listed` is the
## number of StatusConditions of that type in unit.state.statuses at the gate; `gate_sourced` how
## many of those carry a source; `gate_has` is the cache the unit itself answers from.
class StatusRecorder extends ActionReaction:
	var fires:Array[Dictionary] = []

	func _init() -> void:
		original_id = &'action_probe_status_recorder' # see the header: an id-less in-code reaction is double-gated
		triggers_on = [ReactionBus.TRIGGER.STATUSES_CHANGED]
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.category]

	func get_per_round_hard_limit(_specific:SpecificAction) -> int:
		return 99

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		var receiver:Unit = context.unit
		var status:StringName = context.category_str
		var listed := 0
		var sourced := 0
		for condition:StatusCondition in receiver.state.statuses:
			if condition.type != status: continue
			listed += 1
			if condition.source != &'': sourced += 1
		var origin:Unit = UnitRelation.get_origin_unit_for_source(StringName(context.string), context.map)
		fires.append({
			receiver = receiver.core.persistent_id,
			status = status,
			source = context.string,
			until = context.flags.front() if not context.flags.is_empty() else -1,
			gate_has = receiver.has_status(status),
			gate_listed = listed,
			gate_sourced = sourced,
			gate_larger = receiver.state.is_larger_in_grapple,
			origin = origin.core.persistent_id if Unit.is_valid(origin) else &'',
			act_has = null,
		})
		return true

	func activate(context:Context, _activation:EventCore) -> void:
		var triggering:Context = context.event.context
		if not Unit.is_valid(triggering.unit): return
		# The activation belongs to the earliest gate entry for the same receiver and status that has
		# not yet been activated; reactions run in queue order, so this pairs them correctly.
		for fire:Dictionary in fires:
			if fire.act_has != null: continue
			if fire.receiver != triggering.unit.core.persistent_id or fire.status != triggering.category_str: continue
			fire.act_has = triggering.unit.has_status(triggering.category_str)
			return

	func fires_for(unit:Unit, status:StringName) -> Array[Dictionary]:
		var matching:Array[Dictionary] = []
		for fire:Dictionary in fires:
			if fire.receiver == unit.core.persistent_id and fire.status == status: matching.append(fire)
		return matching


# =============================== FIXTURE ===============================

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	observer = SpecFactory.create_unit(game.map, OBSERVER_TILE)
	SpecFactory.apply_passive_buffs(observer)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The install_recorder() idiom (test_draw_fire.gd): full_repair() is what indexes the reaction.
func install(reaction:ActionReaction, on:Unit, kit_id:StringName) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append(reaction)
	on.core.loadout.equipped_kits.append(kit)
	on.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

## A hostile character with evasion 0, so every basic attack aimed at it lands, and speed 4 so a
## four-step standard move exactly spends it.
func hostile(tile:Vector2i) -> Unit:
	var unit := FitzgeraldFixture.create_dummy(game, tile, 0, Faction.AI_ENEMY)
	unit.core.frame.stat.speed = 4
	unit.core.full_repair()
	return unit

## Apply a status THROUGH THE REAL EVENT, so the reaction bus is actually asked (see the header).
func apply(target:Unit, status:StringName, source:String, until:Lancer.UNTIL = Lancer.UNTIL.END_OF_NEXT_TURN) -> void:
	await game.execute_event(&'event_unit_apply_status', {unit = target, category = status, flags = [until], string = source})

## Sixty sixes after the one d20, so nothing drains the FIFO into real RNG (test_draw_fire.gd).
func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

func entering_fires(slower:StepSlower) -> Array[Dictionary]:
	var matching:Array[Dictionary] = []
	for fire:Dictionary in slower.fires:
		if fire.entering: matching.append(fire)
	return matching


# ===================== A. A STEP-PRE REACTION CAN SLOW THE MOVER =====================

func test_a_the_gate_is_handed_the_tile_about_to_be_entered_and_the_mover_is_slowed_before_it_lands() -> void:
	var slower := StepSlower.new()
	slower.field = [FIELD]
	install(slower, observer, STEP_KIT)
	var mover := hostile(START)

	await SpecFactory.move(game, mover, DESTINATION, MovementType.create_for_standard_move(mover))

	var entries := entering_fires(slower)
	assert_eq(entries.size(), 1, 'exactly one step entered the field')
	if entries.is_empty(): return
	assert_eq(entries[0].next, FIELD, 'the gate saw the tile about to be entered in context.target_tiles')
	assert_eq(entries[0].from, Vector2i(3, 2), 'and the mover still stood on the tile before it')
	assert_true(entries[0].voluntary, 'a standard move is voluntary')
	assert_false(entries[0].knockback, 'and is not a knockback')
	assert_true(mover.has_status(Lancer.STATUS.SLOWED), 'the reaction Slowed the mover')
	assert_true(UnitCondition.has_status(mover, Lancer.STATUS.SLOWED, observer.get_gear(STEP_KIT).persistent_id),
		'sourced to the reacting gear')

func test_a_a_slowed_mover_still_completes_the_move_it_was_slowed_during() -> void:
	# DESIGN CORRECTION UNDER TEST. Design §1.0 expects "the step that entered the field still
	# lands, the remainder aborts", on the belief that Slowed halves the budget. It does not:
	# has_enough_move_to_reach_end reads current.speed only (event_unit_move.gd:468-476), and nothing
	# in the move loop reads Slowed. Speed 4, four steps of cost 1: the mover arrives with 0 left.
	var slower := StepSlower.new()
	slower.field = [FIELD]
	install(slower, observer, STEP_KIT)
	var mover := hostile(START)

	await SpecFactory.move(game, mover, DESTINATION, MovementType.create_for_standard_move(mover))

	gut.p('  the Slowed mover ended at %s with %d speed left' % [mover.tile(), mover.core.current.speed])
	assert_true(mover.has_status(Lancer.STATUS.SLOWED), 'fixture: the mover was Slowed mid-move')
	assert_eq(mover.tile(), DESTINATION, 'and still arrived: Slowed does not shorten the move it lands during')
	assert_eq(mover.core.current.speed, 0, 'having spent all four of its speed')

func test_a_control_without_a_watched_tile_nobody_is_slowed() -> void:
	# The mutation, as a test: an empty field means the gate refuses every step, so the Slowed above
	# was the reaction's doing and not something the move does on its own.
	var slower := StepSlower.new()
	install(slower, observer, STEP_KIT)
	var mover := hostile(START)

	await SpecFactory.move(game, mover, DESTINATION, MovementType.create_for_standard_move(mover))

	assert_gt(slower.fires.size(), 0, 'the gate was asked on every step')
	assert_eq(entering_fires(slower).size(), 0, 'and refused every one')
	assert_false(mover.has_status(Lancer.STATUS.SLOWED), 'so nobody was Slowed')
	assert_eq(mover.tile(), DESTINATION, 'and the move completed')

func test_a_an_involuntary_move_into_the_field_is_seen_as_involuntary_and_still_slowed() -> void:
	var slower := StepSlower.new()
	slower.field = [FIELD]
	install(slower, observer, STEP_KIT)
	var mover := hostile(START)

	await SpecFactory.move(game, mover, DESTINATION, MovementType.create_for_involuntary(mover))

	var entries := entering_fires(slower)
	assert_eq(entries.size(), 1, 'the involuntary move entered the field once')
	if entries.is_empty(): return
	assert_eq(entries[0].next, FIELD, 'with the tile about to be entered in context.target_tiles')
	assert_false(entries[0].voluntary, 'and the MovementType says involuntary')
	assert_true(mover.has_status(Lancer.STATUS.SLOWED), 'the mover was Slowed')
	assert_eq(mover.tile(), DESTINATION, 'an involuntary move spends no speed, so nothing shortens it')

func test_a_a_ram_knockback_into_the_field_is_seen_as_a_flagged_involuntary_step() -> void:
	# The real knockback path: event_unit_pick_move -> event_unit_move with the knocked unit as
	# context.unit (its REAL core, not a katamari passenger's virtual one) and IS_KNOCKBACK set.
	var slower := StepSlower.new()
	slower.field = FIELD_COLUMN.duplicate()
	install(slower, observer, STEP_KIT)
	var rammer := FitzgeraldFixture.create_dummy(game, START, 10, Faction.PLAYER)
	var mover := hostile(Vector2i(3, 2))
	queue_dice(15)

	await SpecFactory.use_solo(game, rammer, &'mw_ram', mover)

	assert_eq(mover.tile().x, 4, 'fixture: the Ram knocked the hostile one tile east, into column 4')
	assert_true(mover.has_status(Lancer.STATUS.PRONE), 'fixture: and Prone, so the Ram really landed')
	var entries := entering_fires(slower)
	assert_eq(entries.size(), 1, 'the knockback step entered the field once')
	if entries.is_empty(): return
	assert_true(FIELD_COLUMN.has(entries[0].next), 'with the tile about to be entered in context.target_tiles')
	assert_false(entries[0].voluntary, 'as an involuntary move')
	assert_true(entries[0].knockback, 'carrying IS_KNOCKBACK')
	assert_true(mover.has_status(Lancer.STATUS.SLOWED), 'and the mover was Slowed')


# ===================== B. STATUSES_CHANGED PRE, AND WHAT THE GATE CAN SEE =====================

func test_b_a_first_application_fires_once_and_the_unit_already_holds_the_status_at_the_gate() -> void:
	# DESIGN CORRECTION UNDER TEST. Design §0.5 says "becomes" is "checked at the pre-application
	# timing, when the status is not yet on the unit". The trigger is queued from
	# on_status_application (unit_condition.gd:167), AFTER the append at :105 - so the gate sees it.
	var recorder := StatusRecorder.new()
	install(recorder, observer, STATUS_KIT)
	var target := hostile(START)

	await apply(target, Lancer.STATUS.SLOWED, 'probe_source')

	var fires := recorder.fires_for(target, Lancer.STATUS.SLOWED)
	assert_eq(fires.size(), 1, 'the gate was asked exactly once')
	if fires.is_empty(): return
	assert_true(fires[0].gate_has, 'ENGINE FACT: at PRE the unit already answers has_status true')
	assert_eq(fires[0].gate_listed, 1, 'one StatusCondition of that type is listed at the gate')
	assert_eq(fires[0].gate_sourced, 1, 'and it carries its source')
	assert_eq(fires[0].source, 'probe_source', 'context.string is the source id')
	assert_eq(fires[0].until, Lancer.UNTIL.END_OF_NEXT_TURN, 'context.flags.front() is the until')
	assert_true(fires[0].act_has, 'and the activation ran, with the status still held')

func test_b_a_re_application_fires_again_and_the_gate_counts_two_listed_copies() -> void:
	var recorder := StatusRecorder.new()
	install(recorder, observer, STATUS_KIT)
	var target := hostile(START)

	await apply(target, Lancer.STATUS.SLOWED, 'probe_source')
	await apply(target, Lancer.STATUS.SLOWED, 'probe_source')

	var fires := recorder.fires_for(target, Lancer.STATUS.SLOWED)
	assert_eq(fires.size(), 2, 'a re-application fires the trigger again')
	if fires.size() < 2: return
	assert_true(fires[1].gate_has, 'has_status is true either way, so it cannot tell the two apart')
	assert_eq(fires[1].gate_listed, 2, 'but the listed count can: two StatusConditions at the second gate')
	assert_eq(fires[0].gate_listed, 1, 'against one at the first')

func test_b_an_immune_unit_never_reaches_the_gate() -> void:
	# apply_status returns before the append on immunity (unit_condition.gd:93-99), so the trigger is
	# never queued: Breach needs no immunity guard of its own, the engine has already refused.
	var recorder := StatusRecorder.new()
	install(recorder, observer, STATUS_KIT)
	var target := hostile(START)
	var immunity := BuffStatusImmunity.new()
	immunity.compcon_id = IMMUNITY_BUFF
	immunity.to = Buff.TO.STATUS_IMMUNITY
	immunity.immune_to_statuses = [Lancer.STATUS.SLOWED]
	immunity.hide_from_player = true
	UnitCondition.apply_buff(SpecFactory.dummy_event(), target, immunity)
	assert_true(UnitCondition.is_immune_to_status(target, Lancer.STATUS.SLOWED), 'fixture: the target is immune to Slowed')

	await apply(target, Lancer.STATUS.SLOWED, 'probe_source')

	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'fixture: nothing was applied')
	assert_eq(recorder.fires_for(target, Lancer.STATUS.SLOWED).size(), 0, 'and the gate was never asked')

func test_b_a_buff_carried_status_DOES_reach_the_gate_with_nothing_listed_and_the_gear_as_source() -> void:
	# DESIGN CORRECTION UNDER TEST. Design §0.6 records as fact that a status carried by a zone buff
	# "never passes through apply_status, so it never fires this trigger". apply_buff_alt calls
	# on_status_application for every entry in applies_statuses (unit_condition.gd:758-762), and that
	# is the function that queues the trigger. What differs is what the gate can see: nothing is
	# listed in unit.state.statuses, only the cache answers true.
	var recorder := StatusRecorder.new()
	install(recorder, observer, STATUS_KIT)
	var zone_buff := Buff.new()
	zone_buff.compcon_id = ZONE_BUFF
	zone_buff.applies_statuses = [Lancer.STATUS.SLOWED]
	zone_buff.hide_from_player = true
	var aura := PassiveAura.new()
	aura.buffs = [zone_buff]
	aura.aura_range = 1
	aura.applies_to_self = false
	aura.applies_to_allies = false
	aura.applies_to_enemies = true
	var zone_kit := Kit.new()
	zone_kit.compcon_id = ZONE_KIT
	zone_kit.is_trait = true
	zone_kit.passives.append(aura)
	observer.core.loadout.equipped_kits.append(zone_kit)
	observer.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)
	var target := hostile(Vector2i(4, 4)) # well outside range 1 of (0,0)
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'fixture: outside the zone, not Slowed')

	# A REAL move, so the aura pass that applies the buff runs with a valid event core (:246).
	await SpecFactory.move(game, target, Vector2i(1, 1), MovementType.create_for_involuntary(target))

	assert_true(UnitCondition.has_buff(target, ZONE_BUFF), 'fixture: the zone buff landed on entry')
	assert_true(target.has_status(Lancer.STATUS.SLOWED), 'fixture: and the unit reads as Slowed')
	var fires := recorder.fires_for(target, Lancer.STATUS.SLOWED)
	assert_eq(fires.size(), 1, 'ENGINE FACT: a buff-carried status fires statuses_changed PRE')
	if fires.is_empty(): return
	assert_true(fires[0].gate_has, 'the cache says Slowed at the gate')
	assert_eq(fires[0].gate_listed, 0, 'but NOTHING is listed in unit.state.statuses - the discriminator')
	assert_eq(fires[0].source, String(observer.get_gear(ZONE_KIT).persistent_id), 'sourced to the gear that owns the buff')
	assert_eq(fires[0].origin, observer.core.persistent_id, 'which get_origin_unit_for_source resolves to the aura unit')
	assert_eq(fires[0].until, Lancer.UNTIL.MANUAL, 'carried statuses are MANUAL')


# ===================== C. GRAPPLED: WHICH APPLICATION CAN NAME THE GRAPPLER =====================

func test_c_a_grapple_applies_grappled_twice_and_only_the_sourced_one_names_the_grappler() -> void:
	var recorder := StatusRecorder.new()
	install(recorder, observer, STATUS_KIT)
	var grappler := FitzgeraldFixture.create_dummy(game, START, 10, Faction.PLAYER)
	var target := hostile(Vector2i(3, 2))
	queue_dice(15)

	await SpecFactory.use_solo(game, grappler, &'mw_grapple', target)

	assert_true(target.has_status(Lancer.STATUS.GRAPPLED), 'fixture: the grapple landed')
	assert_true(Katamari.create(grappler).are_attached(grappler, target), 'fixture: and the two are attached')
	var fires := recorder.fires_for(target, Lancer.STATUS.GRAPPLED)
	assert_eq(fires.size(), 2, 'Grappled is applied to the target TWICE by one grapple')
	if fires.size() < 2: return
	gut.p('  unsourced application: %s' % [fires[0]])
	gut.p('  sourced application:   %s' % [fires[1]])
	assert_eq(fires[0].source, '', 'the first, from Katamari.validate_attachments, has no source')
	assert_eq(fires[0].origin, &'', 'so it names nobody')
	assert_eq(fires[0].gate_sourced, 0, 'and nothing sourced is listed yet')
	assert_eq(fires[1].source, String(grappler.core.persistent_id), 'the second, from onhit_grapple, is sourced to the grappler')
	assert_eq(fires[1].origin, grappler.core.persistent_id, 'and get_origin_unit_for_source resolves it')
	assert_eq(fires[1].gate_listed, 2, 'with both copies listed at its gate')
	assert_eq(fires[1].gate_sourced, 1, 'one of them sourced')
	assert_false(fires[1].gate_larger, 'equal sizes: the attacker wins the tie, so the target is NOT larger at the sourced gate')
	assert_true(UnitCondition.is_immobilized(target), 'which is exactly the engine reading of Immobilized')

func test_c_a_larger_target_reads_is_larger_in_grapple_true_at_the_sourced_gate() -> void:
	var recorder := StatusRecorder.new()
	install(recorder, observer, STATUS_KIT)
	var grappler := FitzgeraldFixture.create_dummy(game, START, 10, Faction.PLAYER)
	var target := hostile(Vector2i(3, 2))
	SpecFactory.change_size(target, 2) # occupies (3,2) (4,2) (3,3) (4,3); still adjacent to (2,2)
	queue_dice(15)

	await SpecFactory.use_solo(game, grappler, &'mw_grapple', target)

	assert_true(target.has_status(Lancer.STATUS.GRAPPLED), 'fixture: the grapple landed')
	var fires := recorder.fires_for(target, Lancer.STATUS.GRAPPLED)
	assert_eq(fires.size(), 2, 'two applications again')
	if fires.size() < 2: return
	assert_true(fires[1].gate_larger, 'the size-2 target IS larger at the sourced gate')
	assert_false(UnitCondition.is_immobilized(target), 'and is not Immobilized by the grapple')
	assert_eq(fires[1].origin, grappler.core.persistent_id, 'while the grappler is still nameable')
