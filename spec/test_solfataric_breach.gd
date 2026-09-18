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
# AN IMMUNE UNIT NEVER REACHES THE GATE ON THE DIRECT PATH (unit_condition.gd:93-99 returns before the
# append) - but it DOES on the buff-carried one, which is why the gate carries an immunity clause after
# all. apply_buff_alt appends the buff and calls on_status_application for every entry of
# applies_statuses (:757, :760-761) with NO immunity check, and get_buffs_that_apply_status (:809-818)
# does not filter immunity either - so the count would read 1 while get_current_statuses (:375-382),
# which DOES filter it, leaves the unit holding nothing.
# test_a_zone_carried_slowed_on_an_immune_hostile_does_not_fire is what pins that clause.
#
# STATUSES ARE APPLIED THROUGH THE REAL EVENT, never SpecFactory.apply: that helper hands apply_status
# a dummy_event() whose block is not valid, and EventCore.queue_reaction_events returns on
# is_block_valid() before asking the bus (event_core.gd:60) - so a status applied that way fires
# nothing, and a spec built on it would read "never fires" for the boring reason.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_solfataric_breach.gd
extends GutTest

const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')
## Only for create_dummy at a chosen evasion and faction, which VaubanFixture.create_ally fixes at 10.
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

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
const IMMUNITY_BUFF := &'buff_spec_breach_immunity'

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

## Takes the engine's per-round reaction cap off its holder entirely.
##
## THE SHAPE IS VANILLA'S OWN: the Tortuga's buff_hyper_reflex_mode_additional_overwatch is a plain
## Buff with to = &'action_per_round' whose get_values returns a number, and
## UnitAction.is_under_per_round_limit starts from get_per_round_hard_limit and ADDS every such buff's
## value before comparing (unit_action.gd:170-175). Unlike the Tortuga's this one is unconditional -
## the test below wants the cap GONE, not moved to a different action, because the cap is precisely
## the thing standing between it and the rule it means to exercise.
class CapLifter extends Buff:
	func _init() -> void:
		compcon_id = &'buff_spec_breach_cap_lifter'
		to = Buff.TO.ACTION_PER_ROUND
		until = Lancer.UNTIL.MANUAL
		hide_from_player = true

	func get_values(_core:BuffCore, _context:Context) -> Context:
		return Context.create({number = 9})

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
## (unit_condition.gd:757 appends the buff, :760-761 runs the status loop; :758 is on_application
## and :759 the source line - corrected 2026-09-18), which is exactly the case §0.6a reverses.
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

## Make a unit immune to Slowed the way shipped content does - the probe's own shape
## (test_spike_vauban_probe.gd test_b), and the shape of the Aegis' buff_defense_net_status_immunity
## and the Priest's buff_empowered_investiture_immunity, both of which carry
## immune_to_statuses = [impaired, slowed] under content/frames/npc/.
##
## apply_buff, not apply, and a dummy_event is enough: nothing here has to fire a trigger, it only has
## to be on the unit before the cloud reaches it.
func make_immune_to_slowed(target:Unit) -> void:
	var immunity := BuffStatusImmunity.new()
	immunity.compcon_id = IMMUNITY_BUFF
	immunity.to = Buff.TO.STATUS_IMMUNITY
	immunity.immune_to_statuses = [Lancer.STATUS.SLOWED]
	immunity.hide_from_player = true
	UnitCondition.apply_buff(SpecFactory.dummy_event(), target, immunity)

## Low enough for the cheated 1d6 to finish: 1 HP and its LAST point of structure, so the 6 takes
## structure to zero and destroys the unit outright rather than rolling the structure table.
## test_blasting_powder.gd's make_fragile, verbatim and for the same reason.
##
## A DEATH IS SAFE IN THIS FIXTURE, which is not true of every spec: EventService.remove_unit_from_game
## dereferences map.campaign_core with no guard (event_service.gd:80), and the re-use branch of
## SpecFactory.setup_gamemaster is the one that builds a CampaignCore and hangs it on the map
## (spec_factory.gd:47-48). VaubanFixture.create_game takes that branch - see its header.
func make_fragile(target:Unit) -> void:
	target.core.frame.stat.health = 1
	target.core.frame.stat.structure = 1
	target.core.full_repair()

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
	# (action_reaction.gd:69 - :66 is is_jammable(), corrected 2026-09-18), so there is deliberately no
	# get_per_round_hard_limit override to pin.
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

func test_a_second_breach_re_applies_the_impaired_on_a_still_impaired_target():
	# DESIGN §1.3: the Impaired this trait applies is an ORDINARY status, so a second Breach lands a
	# second one rather than refreshing the first - and two listed StatusConditions is what that looks
	# like. Recorded as a gap by the SP1 review on the grounds that it needed a cross-round shape; it
	# does, and the file already has the vocabulary.
	#
	# THE SECOND BECOMING MUST BE A DIFFERENT STATUS. instances_held counts per status
	# (action_solfataric_breach.gd's own comment), so a second Slowed on a still-Slowed target is
	# refused - that is the test directly above. Immobilized is the other literal status on the card
	# and the target holds none of it, so it is a first holding and a real becoming.
	#
	# start_turn IS WHAT MAKES THE ROUND FRESH, exactly as above: UnitAction.new_turn_refresh ->
	# reset_per_round_usage (unit_action.gd:73-78, :87-88) hands back both the point and the round, and
	# an END_OF_NEXT_TURN status on the TARGET is untouched by the VAUBAN's turn start - which is the
	# second fixture assertion, and the premise the whole test rests on.
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)

	await apply(target, Lancer.STATUS.SLOWED)
	assert_eq(listed(target, Lancer.STATUS.IMPAIRED), 1, 'fixture: the first Breach Impaired it.')
	await SpecFactory.start_turn(game, vauban)
	assert_true(target.has_status(Lancer.STATUS.IMPAIRED), 'fixture: and it is STILL Impaired.')

	await apply(target, Lancer.STATUS.IMMOBILIZED)

	assert_eq(listed(target, Lancer.STATUS.IMPAIRED), 2,
		'Design §1.3: the Impaired is a real status, so a second Breach applies a second one.')
	assert_eq(target.current_damage(), 12, 'And it takes a second cheated 1d6.')

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
	# THE SECOND REACTION POINT ALONE IS NOT ENOUGH, AND THE CAP LIFTER IS WHAT MAKES THIS
	# DISCRIMINATE. With the point alone the chain is DOUBLY guaranteed - by the round cap AND by
	# Impaired's absence from CARD_STATUSES - so adding IMPAIRED to CARD_STATUSES left this test green
	# and only the point economy was ever being asserted. spend_actions records the round use, and
	# is_under_per_round_limit refuses the second Breach whatever the gate says.
	#
	# BUT THAT CAP IS RAISABLE IN-SPEC, which the earlier "opening a second round from inside
	# activate() is not a thing a spec can reach" missed: is_under_per_round_limit starts from
	# get_per_round_hard_limit and then ADDS every TO.ACTION_PER_ROUND buff on the unit
	# (unit_action.gd:170-175), which is vanilla's own Tortuga mechanism. With the cap gone and a
	# second point in hand, a second Breach would fire if and only if Impaired were on the card - so
	# the chain rule is the only thing left refusing it. The fixture assertion AFTER the first Breach
	# is what says the cap really is off; without it this would be the doubly-guaranteed test again.
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)
	vauban.core.current.reactions = 2
	UnitCondition.apply_buff(SpecFactory.dummy_event(), vauban, CapLifter.new())

	await apply(target, Lancer.STATUS.SLOWED)

	assert_true(breached(target), 'fixture: it fired once.')
	assert_true(UnitAction.is_under_per_round_limit(SpecificAction.from_id(vauban, TRAIT_ID, ACTION_ID)),
		'fixture: and the round cap is LIFTED even with that use recorded, so nothing but the trigger '
		+ 'set can refuse a second Breach.')
	assert_eq(listed(target, Lancer.STATUS.IMPAIRED), 1,
		'Impaired is not on the card, so the Breach\'s own Impaired cannot feed another Breach.')
	assert_eq(target.current_damage(), 6, 'And exactly once - 6 damage, not 12.')
	assert_eq(vauban.core.current.reactions, 1, 'Spending exactly one of the two points.')

func test_a_zone_carried_slowed_fires_and_fires_again_on_re_entry():
	# DESIGN §0.6a, the reversal. A status carried by a buff never passes through apply_status, and
	# design §0.6 recorded as fact that it therefore never fires this trigger. apply_buff_alt calls
	# on_status_application for every entry of applies_statuses (unit_condition.gd:757 appends, :760-761
	# is the loop; corrected 2026-09-18), and that
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

func test_a_zone_carried_slowed_on_an_immune_hostile_does_not_fire():
	# THE OTHER HALF OF §0.6a, and the one the design missed. The zone path fires this trigger for an
	# IMMUNE unit too: apply_buff_alt appends the buff and calls on_status_application for every entry
	# of applies_statuses (unit_condition.gd:757, :760-761) with no immunity check anywhere in it, and
	# get_buffs_that_apply_status (:809-818) does not filter immunity either - so the gate's count reads
	# 1. What the unit actually HOLDS is computed by get_current_statuses (:375-382), which DOES filter
	# immunity, so the answer there is nothing at all. Without the gate's own immunity clause the
	# Vauban Breaches a hostile for a becoming that never happened.
	#
	# NOT A HYPOTHETICAL: the Aegis' buff_defense_net_status_immunity and the Priest's
	# buff_empowered_investiture_immunity are both immune_to_statuses = [impaired, slowed], and a
	# Slowing cloud beside either of them is shipped content meeting shipped content.
	#
	# THE DIRECT PATH NEEDS NO SUCH CLAUSE, and the probe measured that separately
	# (test_spike_vauban_probe.gd test_b_an_immune_unit_never_reaches_the_gate): apply_status returns at
	# :93-99 before the append, so the trigger is never queued at all.
	queue_sixes()
	place_slowing_cloud(CLOUD_TILE)
	var target := VaubanFixture.create_hostile(game, CLOUD_AWAY)
	make_immune_to_slowed(target)
	assert_true(UnitCondition.is_immune_to_status(target, Lancer.STATUS.SLOWED), 'fixture: immune to Slowed.')
	assert_eq(vauban.core.current.reactions, 1, 'fixture: and the Vauban is holding its reaction point.')

	await SpecFactory.move(game, target, CLOUD_EDGE, MovementType.create_for_involuntary(target))

	# THE FIXTURE SELF-CHECK THAT MAKES THIS DISCRIMINATE. The cloud's buff really is on the target, so
	# instances_held() really would count 1 and the gate really was asked - the refusal below is the
	# immunity clause and nothing else.
	assert_eq(UnitCondition.get_buffs_that_apply_status(target, Lancer.STATUS.SLOWED).size(), 1,
		'fixture: the cloud buff landed, so the gate was asked with a count of one.')
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'It never becomes Slowed - it is immune.')
	assert_eq(target.current_damage(), 0, 'So no Breach damage.')
	assert_false(breached(target), 'And no Impaired.')
	assert_eq(vauban.core.current.reactions, 1, 'And the reaction point was never spent.')

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

func test_a_hostile_that_grapples_a_larger_unit_is_itself_breached():
	# THE OTHER HALF OF §0.6a, AND THE ONE NOTHING PINNED (ruling R2: keep the card-literal reading, add
	# the test). A grapple applies Grappled to BOTH parties - onhit_grapple.gd:17 to the ATTACKING unit,
	# sourced to its victim, and :18 to the attacked unit - and both run after recalculate_largest_unit
	# at :14. So a hostile that grabs something LARGER than itself is, by the engine's own definition
	# (UnitCondition.is_immobilized, unit_condition.gd:413-418), Immobilized by its own grapple, and the
	# card says a hostile that "becomes Immobilized" is Breached. No narrowing was taken.
	#
	# THE SIDES ARE THE MIRROR OF THE TEST ABOVE, and that is the whole construction: there the
	# GRAPPLER was the ally and the oversized victim the hostile, so nothing hostile was ever the
	# smaller party. Here the grappler is the hostile and the oversized victim is the ally - identical
	# tiles, opposite factions. The victim is built at evasion 0 through FitzgeraldFixture directly,
	# the way VaubanFixture.create_ally does but for the hit: create_ally fixes evasion at 10 and this
	# grapple has to land on a cheated 15.
	#
	# ORDER MATTERS AND IS NOT ASSUMED: :17 runs before :18, so the grappler reaches the gate first and
	# the 1/round cap cannot be what hides it. The ally victim is never Breached at all - are_enemies
	# refuses it - so the point is still there when the grappler's own application arrives.
	queue_dice(15)
	var grappler := VaubanFixture.create_hostile(game, Vector2i(4, 5), 0)
	var victim := FitzgeraldFixture.create_dummy(game, NEAR, 0, Faction.PLAYER)
	SpecFactory.change_size(victim, 2)

	await SpecFactory.use_solo(game, grappler, &'mw_grapple', victim)

	assert_true(grappler.has_status(Lancer.STATUS.GRAPPLED), 'fixture: the grapple landed.')
	assert_false(grappler.state.is_larger_in_grapple,
		'fixture: and the GRAPPLER is the smaller of the two, holding a size-2 unit.')
	assert_true(UnitCondition.is_immobilized(grappler),
		'fixture: which is the engine\'s own Immobilized (unit_condition.gd:413-418).')
	assert_false(breached(victim), 'fixture: the ally it grabbed is not hostile, so it is not Breached.')
	assert_true(breached(grappler), '§0.6a, ruling R2: so Breach fires on the GRAPPLER, card-literally.')
	assert_gt(grappler.current_damage(), 0, 'Taking the 1d6 for grabbing something bigger than itself.')

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
	# THE VAUBAN HALF IS CHARACTERISATION, NOT A PIN, and saying so is the honest record.
	# UnitRelation.are_enemies is a faction compare (unit_relation.gd:361-362) and a faction is never
	# its own enemy, so the gate refuses the self case on that clause alone; neutralising
	# action_solfataric_breach.gd's explicit `target == unit` guard leaves this test green (measured
	# 2026-09-18) and no test can separate the two. The guard stays as documentation of the card's
	# "hostile" reading. What this half asserts is the BEHAVIOUR, not which line produces it.
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

func test_a_breach_that_kills_its_target_never_applies_the_impaired():
	# THE ORDERING, AND THE ONLY CASE IN WHICH IT IS OBSERVABLE. activate() awaits the damage INLINE and
	# then returns on abort_without_unit(target), so a hostile the 1d6 finishes is dead before the
	# Impaired is reached and never gets it. Swap that await for queue_event - vanilla's Lesson of the
	# Open Door shape - and the damage runs after activate() returns, which puts the Impaired on a unit
	# that is about to die: measured, this is the ONE test of the twenty that moves under that mutation,
	# which is exactly why it exists. Every other test here has a 200 HP target.
	#
	# THE POINT IS STILL SPENT, and that is the card's reading rather than an accident: spend_actions
	# runs before the damage on purpose (see activate's own comment), so a Breach that kills costs the
	# Vauban its reaction just the same.
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)
	make_fragile(target)

	await apply(target, Lancer.STATUS.SLOWED)

	assert_false(Unit.is_valid(target), 'The cheated 1d6 finished it.')
	# LISTED, not breached(): the corpse keeps its state, so this reads the StatusConditions themselves
	# and says "no Impaired was ever appended" rather than "a helper declined to find one".
	assert_eq(listed(target, Lancer.STATUS.IMPAIRED), 0,
		'And nothing Impaired the corpse - abort_without_unit returned before the status.')
	assert_false(breached(target), 'Which is what the trait-sourced read says too.')
	assert_eq(vauban.core.current.reactions, 0, 'The point was spent all the same - paid before the damage.')

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
	# an unaffordable one before triggers_on_event is ever asked (reaction_bus.gd:121 - :118 is the
	# trigger_timing compare; corrected 2026-09-18). That is also what makes a Jammed or Stunned Vauban
	# unable to Breach (unit_action.gd:139-140 for Stunned and :142 for Jammed - :141 is Dazed and :144
	# is the protocol gate, neither of them this; corrected 2026-09-18), which the
	# card's "Reaction" carries for free.
	queue_sixes()
	var target := VaubanFixture.create_hostile(game, NEAR)
	vauban.core.current.reactions = 0

	await apply(target, Lancer.STATUS.SLOWED)

	assert_false(breached(target), 'No reaction point, no Breach.')
	assert_eq(target.current_damage(), 0, 'And no damage.')
