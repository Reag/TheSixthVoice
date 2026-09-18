# SOLFATARIC BREACH (Vauban SP1 Task 3).
#
#   "Reaction, 1/round.
#    Trigger: A hostile character within Sensors and line of sight becomes Slowed or Immobilized.
#    Effect: They take 1d6 Kinetic damage and become impaired until the end of their next turn."
#
# ABSORBS TWO OF THE THREE CLAIMS OF spec/test_spike_vauban_probe.gd (design §1.0), which Task 6
# deletes: what the statuses_changed PRE gate can see, and which of a grapple's two Grappled
# applications can name the grappler. Everything the probe measured against a throwaway in-code
# reaction is re-measured here against the real trait.
#
# WHAT "BECOMES" MEANS, AND WHY IT IS NOT has_status (design §0.5 as corrected by the probe): the
# trigger is queued from UnitCondition.on_status_application (unit_condition.gd:167), AFTER the
# StatusCondition is appended at :105 - so at the gate the target already answers has_status true for
# every application, first or fifth. What IS readable is how many instances it holds: listed
# StatusConditions of that type plus buffs whose applies_statuses carries it. Exactly one means this
# application is the becoming.
#
# AN IMMUNE UNIT NEVER REACHES THE GATE (unit_condition.gd:93-99 returns before the append), so there
# is no immunity clause here and adding one would be dead code.
#
# STATUSES ARE APPLIED THROUGH THE REAL EVENT, never SpecFactory.apply: that helper hands apply_status
# a dummy_event() whose block is not valid, and EventCore.queue_reaction_events returns on
# is_block_valid() before asking the bus (event_core.gd:60) - so a status applied that way fires
# nothing, and a spec built on it would read "never fires" for the boring reason.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_solfataric_breach.gd
extends GutTest

const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')

const TRAIT_ID := &'mt_solfataric_breach'
const ACTION_ID := &'action_solfataric_breach'

const MAP_SIZE := Vector2i(15, 9)
const VAUBAN_TILE := Vector2i(2, 4)
const NEAR := Vector2i(4, 4)       ## distance 2 - inside Sensors 8, in plain sight
const SECOND := Vector2i(4, 6)     ## another in-sight hostile, for the 1/round cases
const THIRD := Vector2i(2, 6)
const FAR := Vector2i(12, 4)       ## distance 10 - OUTSIDE Sensors 8
const BEHIND_WALL := Vector2i(8, 4)  ## distance 6, inside Sensors, but the wall blocks sight
const CLOUD_TILE := Vector2i(6, 7)   ## where the in-code Slowing aura sits
const CLOUD_EDGE := Vector2i(5, 7)   ## adjacent to it: inside the range-1 aura
const CLOUD_AWAY := Vector2i(3, 7)   ## two tiles from the cloud: outside it, and still in sight

## A column of forbidden interior spanning the map north to south: blocks sight at every layer and
## gives no cover of its own. Everything east of x=5 is unseen from the Vauban at (2,4).
## forbidden_interiors_enabled is set true by FitzgeraldFixture.create_game - see its header for why
## the flag has to be true BEFORE the wall is placed.
const WALL:Array[Vector2i] = [
	Vector2i(5,0), Vector2i(5,1), Vector2i(5,2), Vector2i(5,3),
	Vector2i(5,4), Vector2i(5,5),
]

const SOURCE := 'spec_breach_source'
const CLOUD_KIT := &'mt_spec_slowing_cloud'
const CLOUD_BUFF := &'buff_spec_slowing_cloud'

var game:Gamemaster
var vauban:Unit

## Records every event_unit_damage that lands on its holder: how much, what type, and WHO the engine
## was told did it. The only way to assert attribution - context.target_unit is the damager on a
## damage event (event_unit_damage.gd:35, "if a unit was the one to damage us"), and nothing on the
## victim afterwards remembers it.
##
## Does NOT call super() in activate(): Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one has to survive several hits.
class DamageRecorder extends Buff:
	var hits:Array[Dictionary] = []

	func _init() -> void:
		compcon_id = &'buff_spec_breach_damage_recorder'
		to = Buff.TO.NONE
		triggers_on = [ReactionBus.TRIGGER.DAMAGE]
		trigger_timing = ReactionBus.TIMING.POST
		until = Lancer.UNTIL.MANUAL
		hide_from_player = true

	func get_required_triggering_context() -> Array[Context.PROP]:
		return []

	func triggers_on_event(_core:BuffCore, holder:Unit, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if context.unit != holder: return false
		hits.append({
			number = context.number,
			category = context.category_int,
			damager = context.target_unit.core.persistent_id if Unit.is_valid(context.target_unit) else &'',
		})
		return false

	func activate(_core:BuffCore, _activation:EventCore) -> void:
		pass

func before_each() -> void:
	game = VaubanFixture.create_game(self, MAP_SIZE)
	vauban = VaubanFixture.create_vauban(game, VAUBAN_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

## Apply a status THROUGH THE REAL EVENT, so the reaction bus is actually asked (see the header).
func apply(target:Unit, status:StringName, source:String = SOURCE,
		until:Lancer.UNTIL = Lancer.UNTIL.END_OF_NEXT_TURN) -> void:
	await game.execute_event(&'event_unit_apply_status',
		{unit = target, category = status, flags = [until], string = source})

## One fixed d20 and then sixty sixes, so nothing drains the FIFO into real RNG and Breach's own 1d6
## always rolls a 6 (test_draw_fire.gd's idiom, and the probe's).
func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

## Sixty sixes and no d20 at all, for the cases that roll no attack: Breach's 1d6 is then a 6 and the
## damage assertions below are exact.
func queue_sixes() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([], buffer)

## How many StatusConditions of `status` the target LISTS - the gate's own discriminator, and the
## only way to say "the Slowed is not listed" without also asserting the target holds no other status.
func listed(target:Unit, status:StringName) -> int:
	var held := 0
	for condition:StatusCondition in target.state.statuses:
		if condition.type == status: held += 1
	return held

func breached(target:Unit) -> bool:
	return UnitCondition.has_status(target, Lancer.STATUS.IMPAIRED, vauban.get_gear(TRAIT_ID).persistent_id)

func place_wall() -> void:
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', WALL)
	game.map.calculate_los_blockers() # vanilla's test_map_sightlines.gd re-pushes the blockers the same way

## A unit carrying a range-1 aura whose one buff APPLIES Slowed rather than applying it as a status -
## the Myconid's Fungal Network cloud in miniature, and the probe's own idiom. Nothing here goes
## through UnitCondition.apply_status; the trigger is fired from apply_buff_alt instead
## (unit_condition.gd:758-762), which is exactly the case §0.6a reverses.
##
## THE CARRIER IS AN ALLY, NOT A DUMMY, and that is load-bearing rather than cosmetic: the aura sets
## applies_to_enemies with applies_to_allies false, and VaubanFixture.create_dummy is AI_ENEMY - the
## same faction as the hostile that walks into it, which makes them ALLIES and the aura silently
## applies nothing. The probe hung its zone on the PLAYER-faction observer for this reason. It also
## models §0.6a's actual case: the Myconid is the Vauban's ally and its cloud Slows enemies.
func place_slowing_cloud(tile:Vector2i) -> Unit:
	var cloud := VaubanFixture.create_ally(game, tile)
	var zone_buff := Buff.new()
	zone_buff.compcon_id = CLOUD_BUFF
	zone_buff.applies_statuses = [Lancer.STATUS.SLOWED]
	zone_buff.hide_from_player = true
	var aura := PassiveAura.new()
	aura.buffs = [zone_buff]
	aura.aura_range = 1
	aura.applies_to_self = false
	aura.applies_to_allies = false
	aura.applies_to_enemies = true
	var kit := Kit.new()
	kit.compcon_id = CLOUD_KIT
	kit.is_trait = true
	kit.passives.append(aura)
	cloud.core.loadout.equipped_kits.append(kit)
	cloud.core.full_repair()
	VaubanFixture.track(game)
	return cloud

func install_damage_recorder(on:Unit) -> DamageRecorder:
	var recorder := DamageRecorder.new()
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), on, BuffCore.create(recorder))
	return recorder

# ---------------------------------------------------------------- wiring and text

func test_the_trait_is_wired():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_solfataric_breach is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait, so it costs no SP and cannot be unequipped.')
	assert_eq(kit.passives.size(), 0, 'It carries no passives - the whole trait is the reaction.')
	assert_eq(kit.actions.size(), 1, 'And exactly one action.')
	var action = kit.get_action(ACTION_ID)
	assert_not_null(action, 'The Kit carries action_solfataric_breach.')
	if action == null: return
	assert_true(action is ActionReaction, 'It is a reaction.')
	assert_eq(action.triggers_on, [&'statuses_changed'] as Array[StringName], 'On statuses_changed.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.PRE,
		'At PRE, which for this trigger means APPLIED rather than removed (reaction_bus.gd:31).')
	assert_true(action.consumes_rxn,
		'A REAL reaction: the point is spent, so a Jammed or Stunned Vauban cannot Breach.')
	assert_eq(action.usage_group, &'action_solfataric_breach', 'With its own usage group.')
	# The card's "1/round" is the engine's own default for a consuming reaction
	# (action_reaction.gd:66), so there is deliberately no get_per_round_hard_limit override to pin.
	var specific := SpecificAction.from_id(vauban, TRAIT_ID, ACTION_ID)
	assert_eq(action.get_per_round_hard_limit(specific), 1, 'And the engine\'s own 1/round.')
	assert_true(GearCore.is_valid(vauban.get_gear(TRAIT_ID)), 'The Vauban is wearing it.')

func test_the_rows_resolve_and_the_reaction_earns_its_own_trait_card_row():
	for key:String in ['gear.mt_solfataric_breach.name', 'gear.mt_solfataric_breach.effect',
			'gear.mt_solfataric_breach.action_solfataric_breach.name',
			'gear.mt_solfataric_breach.action_solfataric_breach.trigger',
			'gear.mt_solfataric_breach.action_solfataric_breach.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

	# THE REACTION DOES GET ITS OWN ROW ON THE TRAIT CARD, unlike the Maiden's Blush's Uncertainty
	# Field, and the difference is the localisation rather than anything in the .tres.
	# Action.show_in_tooltip (action.gd:341-353) returns false when the action's own `effect` equals
	# the KIT's generic one; here the Kit says "Gain the Solfataric Breach reaction" and the action
	# says what it does, so they differ and the card draws both.
	#
	# NOTE WHICH CLAUSE IS *NOT* DOING THE WORK: the trigger row is keyed on the ACTION
	# (gear.mt_solfataric_breach.action_solfataric_breach.trigger), and show_in_tooltip's trigger
	# clause at :344 reads the KIT's own `gear.<kit>.trigger` key, which this mod does not write. The
	# Gyre's header records the same distinction.
	#
	# This is what makes ICON_TARGETS[&'mt_solfataric_breach'] carry the action, and the two move
	# together: give the reaction the Kit's exact text and both have to flip.
	assert_ne(X.tr('gear.mt_solfataric_breach.action_solfataric_breach.effect'),
		X.tr('gear.mt_solfataric_breach.effect'),
		'The reaction\'s effect text differs from the Kit\'s generic one.')
	assert_true(Translate.gear('mt_solfataric_breach', 'trigger', false).is_empty(),
		'The KIT has no trigger row - the trigger is keyed on the action.')
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	if not Kit.is_valid(kit): return
	var action = kit.get_action(ACTION_ID)
	if action == null: return
	assert_true(action.show_in_tooltip(kit),
		'So the engine draws a separate reaction row on the trait card, and it needs its own icon.')

# ---------------------------------------------------------------- what counts as "becomes"

func test_a_first_slowed_fires_the_breach():
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)

	await apply(target, Lancer.STATUS.SLOWED)

	assert_true(breached(target), 'The Breach fired and the target is Impaired, sourced to the trait.')
	assert_eq(target.current_damage(), 6, 'And took the 1d6 - cheated to a 6.')

func test_a_first_immobilized_fires_the_breach():
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)

	await apply(target, Lancer.STATUS.IMMOBILIZED)

	assert_true(breached(target), 'Immobilized is the other literal status on the card.')

func test_a_second_slowed_while_the_first_is_still_held_does_not_fire():
	# The corrected reading, in one test. has_status is true at BOTH gates, so anything built on it
	# would fire twice; the count of instances held is what separates them (one, then two).
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)

	await apply(target, Lancer.STATUS.SLOWED)
	var after_first := target.current_damage()
	assert_true(breached(target), 'fixture: the first application fired.')
	# A FRESH ROUND FIRST, AND THIS LINE IS WHAT MAKES THE TEST MEAN ANYTHING. The first Breach spends
	# the reaction point and records the round use, so without it the second application is refused by
	# the ECONOMY and this test passes against ANY gate. Measured 2026-09-18: with this line absent,
	# mutating the gate's `== 1` to `>= 1` left all 18 tests green - the central ruling of this trait
	# was pinned by nothing. The Vauban's own turn start hands back both the point and the round
	# (UnitAction.new_turn_refresh / reset_per_round_usage, unit_action.gd:66-88), which leaves the
	# gate as the only thing that can still refuse a status the target is visibly holding.
	await SpecFactory.start_turn(game, vauban)
	assert_true(target.has_status(Lancer.STATUS.SLOWED), 'fixture: and the first Slowed is still held.')
	await apply(target, Lancer.STATUS.SLOWED)

	assert_eq(target.current_damage(), after_first,
		'A re-application of a status the target already holds is not a becoming.')

func test_a_status_that_is_not_on_the_card_never_fires():
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)

	await apply(target, Lancer.STATUS.PRONE)
	await apply(target, Lancer.STATUS.SHREDDED, SOURCE, Lancer.UNTIL.MANUAL)
	await apply(target, Lancer.STATUS.IMPAIRED)

	assert_eq(target.current_damage(), 0, 'Prone, Shredded and Impaired are not Slowed or Immobilized.')
	assert_false(breached(target), 'So nothing was Breached.')
	# AND THE CONTROL, in the same test: the fixture can fire, so the three above were refused by the
	# gate rather than by something being wrong with the setup.
	await apply(target, Lancer.STATUS.SLOWED)
	assert_true(breached(target), 'CONTROL: the same target, Slowed, is Breached.')

func test_a_breach_applied_impaired_cannot_feed_another_breach():
	# The one closed loop worth pinning: Breach applies Impaired, and Impaired is not in the trigger
	# set, so a Breach can never chain off its own effect.
	#
	# THE SECOND REACTION POINT IS WHAT MAKES THIS DISCRIMINATE. With the frame's one point, a second
	# Breach would be refused by the economy whatever the gate said, and the test would pass against a
	# trait that DID chain. Two points is not a shape the game produces; it is a fixture that removes
	# the only other explanation.
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)
	vauban.core.current.reactions = 2

	await apply(target, Lancer.STATUS.SLOWED)

	assert_true(breached(target), 'fixture: it fired once.')
	assert_eq(target.current_damage(), 6, 'And exactly once - 6 damage, not 12.')
	assert_eq(vauban.core.current.reactions, 1, 'Spending exactly one of the two points.')

func test_a_zone_carried_slowed_fires_and_fires_again_on_re_entry():
	# DESIGN §0.6a, the reversal. A status carried by a buff never passes through apply_status, and
	# design §0.6 recorded as fact that it therefore never fires this trigger. apply_buff_alt calls
	# on_status_application for every entry of applies_statuses (unit_condition.gd:758-762), and that
	# is the function that queues the trigger - so it does fire, with NOTHING listed in state.statuses
	# and the owning gear as the source. Ruled card-literally: the hostile "becomes Slowed".
	queue_sixes()
	place_slowing_cloud(CLOUD_TILE)
	var target := VaubanFixture.create_hostile(game, CLOUD_AWAY)
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'fixture: outside the cloud, not Slowed.')

	# A REAL move, so the aura pass that applies the buff runs with a valid event core.
	await SpecFactory.move(game, target, CLOUD_EDGE, MovementType.create_for_involuntary(target))

	assert_true(target.has_status(Lancer.STATUS.SLOWED), 'fixture: the cloud Slowed it.')
	# COUNTED FOR SLOWED, not over the whole list. Measured here 2026-09-18: by this line the target
	# lists [engaged, engaged, impaired] - standing beside the cloud engages it and the Breach has
	# already applied its own Impaired - so state.statuses is never empty and an emptiness assertion
	# could only ever fail. What the discriminator actually says is that no StatusCondition of THIS
	# status was appended: the Slowed lives in the buff.
	assert_eq(listed(target, Lancer.STATUS.SLOWED), 0,
		'fixture: and nothing is LISTED - the status lives in the buff, which is the whole point.')
	assert_true(breached(target), 'The Breach fired on a zone-carried Slowed.')
	var after_first := target.current_damage()

	# Leave, which clears the aura buff, and come back: a new becoming.
	await SpecFactory.move(game, target, CLOUD_AWAY, MovementType.create_for_involuntary(target))
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'fixture: leaving the cloud clears it.')
	await SpecFactory.start_turn(game, vauban) # give the reaction back; the 1/round is tested elsewhere
	await SpecFactory.move(game, target, CLOUD_EDGE, MovementType.create_for_involuntary(target))

	assert_gt(target.current_damage(), after_first, 'Re-entering the cloud is a new becoming.')

# ---------------------------------------------------------------- grappled

func test_a_grapple_by_an_equal_sized_unit_fires_the_breach():
	# PROBE CLAIM C, against the real trait. One grapple applies Grappled TWICE: first UNSOURCED from
	# Katamari.validate_attachments (katamari.gd:313), while is_larger_in_grapple is still stale and
	# nobody is nameable, then SOURCED to the grappler from onhit_grapple.gd:18 after
	# recalculate_largest_unit. The gate reads the sourced one and ignores the unsourced one.
	queue_dice(15)
	var grappler := VaubanFixture.create_ally(game, Vector2i(4, 5))
	var target := VaubanFixture.create_hostile(game, NEAR, 0)

	await SpecFactory.use_solo(game, grappler, &'mw_grapple', target)

	assert_true(target.has_status(Lancer.STATUS.GRAPPLED), 'fixture: the grapple landed.')
	assert_true(UnitCondition.is_immobilized(target),
		'fixture: equal sizes, so the engine reads the target as Immobilized (unit_condition.gd:413-418).')
	assert_true(breached(target), 'Which is what the card means by "becomes Immobilized" (ruling 5).')

func test_a_grapple_of_a_larger_target_does_not_fire_the_breach():
	queue_dice(15)
	var grappler := VaubanFixture.create_ally(game, Vector2i(4, 5))
	var target := VaubanFixture.create_hostile(game, NEAR, 0)
	SpecFactory.change_size(target, 2)

	await SpecFactory.use_solo(game, grappler, &'mw_grapple', target)

	assert_true(target.has_status(Lancer.STATUS.GRAPPLED), 'fixture: the grapple still landed.')
	assert_true(target.state.is_larger_in_grapple, 'fixture: and the size-2 target is the larger one.')
	assert_false(UnitCondition.is_immobilized(target), 'So the engine does not read it as Immobilized.')
	assert_false(breached(target), 'And the Breach does not fire.')

# ---------------------------------------------------------------- who and where

func test_a_hostile_outside_sensors_is_not_breached():
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, FAR)
	assert_gt(UnitRelation.distance_between(vauban, target), vauban.get_sensor_range(),
		'fixture: it really is beyond Sensors 8.')

	await apply(target, Lancer.STATUS.SLOWED)

	assert_false(breached(target), 'Out of Sensors, out of reach.')
	assert_eq(target.current_damage(), 0, 'And untouched.')

func test_a_hostile_out_of_line_of_sight_is_not_breached():
	queue_sixes()
	place_wall()
	var target := VaubanFixture.create_hostile(game, BEHIND_WALL)
	assert_lt(UnitRelation.distance_between(vauban, target), vauban.get_sensor_range(),
		'fixture: it IS within Sensors - so sight is the only thing that can refuse it.')
	assert_false(UnitRelation.can_see(vauban, target), 'fixture: and the wall blocks sight.')

	await apply(target, Lancer.STATUS.SLOWED)

	assert_false(breached(target), 'No sight, no Breach.')

func test_an_ally_and_the_vauban_itself_are_never_breached():
	queue_sixes()
	var ally := VaubanFixture.create_ally(game, NEAR)

	await apply(ally, Lancer.STATUS.SLOWED)
	await apply(vauban, Lancer.STATUS.SLOWED)

	assert_false(breached(ally), 'The card says HOSTILE character.')
	assert_eq(ally.current_damage(), 0, 'And the ally took nothing.')
	assert_false(breached(vauban), 'And the Vauban does not Breach itself.')

# ---------------------------------------------------------------- the effect

func test_the_damage_is_1d6_kinetic_attributed_to_the_vauban():
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)
	var recorder := install_damage_recorder(target)

	await apply(target, Lancer.STATUS.SLOWED)

	assert_eq(recorder.hits.size(), 1, 'Exactly one damage event landed on the target.')
	if recorder.hits.is_empty(): return
	assert_eq(recorder.hits[0].number, 6, 'The cheated 1d6 - six.')
	assert_eq(recorder.hits[0].category, Lancer.DAMAGE_TYPE.KINETIC, 'Kinetic, as the card says.')
	assert_eq(recorder.hits[0].damager, vauban.core.persistent_id,
		'And the engine was told the VAUBAN did it, which is what feeds every "you damaged them" hook.')

func test_the_impaired_lasts_until_the_end_of_the_targets_next_turn():
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)

	await apply(target, Lancer.STATUS.SLOWED)

	var condition:StatusCondition = UnitCondition.get_status(target, Lancer.STATUS.IMPAIRED,
		vauban.get_gear(TRAIT_ID).persistent_id)
	assert_not_null(condition, 'The Impaired is sourced to the Breach gear.')
	if condition == null: return
	assert_eq(condition.until, Lancer.UNTIL.END_OF_NEXT_TURN, 'Until the end of their next turn.')

# ---------------------------------------------------------------- the round

func test_only_one_breach_a_round():
	queue_sixes()
	var first := VaubanFixture.create_hostile(game, NEAR)
	var second := VaubanFixture.create_hostile(game, SECOND)

	await apply(first, Lancer.STATUS.SLOWED)
	# GIVE THE POINT BACK, so the refusal below can only be the ROUND CAP. Without this line the
	# second application would be refused by is_gear_affordable for want of a reaction point
	# (unit_action.gd:182) and this test would say nothing about get_per_round_hard_limit at all.
	vauban.core.current.reactions = 1
	await apply(second, Lancer.STATUS.SLOWED)

	assert_true(breached(first), 'The first qualifying application fires.')
	assert_false(breached(second), 'The second does not - the engine\'s 1/round hard limit refuses it.')
	assert_eq(second.current_damage(), 0, 'And the second hostile took nothing.')
	assert_eq(vauban.core.current.reactions, 1, 'The point we handed back was never spent.')

func test_a_breach_is_available_again_after_the_vaubans_own_turn():
	# What "1/round" actually means off-turn, and it is the engine's rather than the card's:
	# uses_this_round is cleared by UnitAction.new_turn_refresh -> reset_per_round_usage
	# (unit_action.gd:73-78, :87-88), which runs only at the VAUBAN'S OWN turn start, while the
	# reaction POINT refreshes at every unit's turn start (every_new_turn_refresh, :66-70). So two
	# Breaches inside one game round are possible, one on each side of the Vauban's turn. Draw Fire's
	# test_a_draw_is_available_again_after_the_subutais_own_turn pins the same property.
	queue_sixes()
	var first := VaubanFixture.create_hostile(game, NEAR)
	var second := VaubanFixture.create_hostile(game, SECOND)
	var third := VaubanFixture.create_hostile(game, THIRD)

	await apply(first, Lancer.STATUS.SLOWED)
	await apply(second, Lancer.STATUS.SLOWED)
	assert_false(breached(second), 'fixture: the round is spent.')

	await SpecFactory.start_turn(game, vauban)
	await apply(third, Lancer.STATUS.SLOWED)

	assert_true(breached(third), 'The Vauban\'s own turn start gives the Breach back.')

func test_a_vauban_with_no_reaction_point_does_not_breach():
	# consumes_rxn = true is what makes this a REAL reaction, and UnitAction.can_activate_gear refuses
	# an unaffordable one before triggers_on_event is ever asked (reaction_bus.gd:118). That is also
	# what makes a Jammed or Stunned Vauban unable to Breach (unit_action.gd:141-142, :144), which the
	# card's "Reaction" carries for free.
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)
	vauban.core.current.reactions = 0

	await apply(target, Lancer.STATUS.SLOWED)

	assert_false(breached(target), 'No reaction point, no Breach.')
	assert_eq(target.current_damage(), 0, 'And no damage.')
