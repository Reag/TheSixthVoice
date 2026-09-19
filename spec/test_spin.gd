## FLOURISHING TWIRL, SPIN (Primrose rank III, SP4 Task 3).
##
##   "Unique, Limited 4. Spin (Quick): Choose a weapon you have mounted, all hostile characters
##    within its threat and line of sight must succeed an Agility save or take 4 kinetic damage and
##    become Impaired until the end of their next turn."
##   (specs/sixth-voice/07-primrose.md, Rank III, "System: Flourishing Twirl")
##
## THE ORDER OF activate'S FIRST FOUR STEPS IS WHAT THIS FILE MOSTLY TESTS. Rulings 4 and 19 say the
## prompt comes before the cost and that a Spin with nothing to measure costs nothing, and
## spend_actions is the only route to gear.spend_charge() (unit_action.gd:274) - so three of the
## fifteen tests below (11, 12 and the charge half of 10) exist purely to hold that order in place.
## Read res/content/gear/ssc/systems/ms_flourishing_twirl/action_spin.gd's header first.
##
## A FOURTH ORDER IS PINNED BY TEST 14, and it is a different one: the damage is executed INLINE and
## the Impaired follows it, which only a victim the 4 actually KILLS can see. Added at this task's
## review, which spotted that every hostile here is a 200 HP punching bag - the same blind spot
## action_solfataric_breach.gd already shipped once.
##
## ============================ "MOUNTED" IS NOT "EQUIPPED" ON THIS FRAME ============================
##
## PrimroseFixture.equip goes through UnitPrinter.equip_system, which files a weapon Kit in the
## loadout's `attacks` list (loadout_core.gd:116-122) - i.e. as an INTEGRATED weapon, never on a
## mount. Only MountCore.equip_primary puts one on a mount (the same call vanilla's own
## test_mw_combat_drill.gd:17 and test_cb_overpower_caliber.gd:20 use). get_all_weapons() returns
## BOTH sets, its own doc comment saying so - "No basics, but include integrated"
## (loadout_core.gd:520-525) - and the card says MOUNTED, so action_spin filters with
## get_mount_for_gear.
##
## THIS FILE THEREFORE EQUIPS AN INTEGRATED WEAPON IN before_each AND NEVER MOUNTS IT. It is a
## permanent negative control: every "the menu listed exactly these" and every "no prompt appeared"
## assertion below is also an assertion that the integrated Anti-Materiel Rifle stayed out of the
## menu. MEASURED (on the 14-test file, before test 14 was added at the review): deleting the
## get_mount_for_gear filter takes it to 5/14 - tests 2, 3, 4, 5, 7, 8, 10, 12 and 13 all go red.
## The plan predicted it would redden test 3 alone, on the assumption the integrated weapon would be
## staged in that one test; putting it in before_each instead is what turned a single pin into nine.
##
## ============================ THE THREE WEAPONS, AND WHY THESE THREE ============================
##
## Spin measures the BUFFED threat (ruling 4) and this frame's Artful Caress silently adds +1 to
## every Heavy and Superheavy MELEE weapon it carries. So a spec that wants "reaches exactly three"
## and a spec that wants "Artful Caress widened it" cannot use the same weapon, or neither can tell
## the trait from the profile:
##
##   mw_assault_rifle        MAIN   RIFLE  threat 1 -> 1   the short one; Caress ignores the type
##   mw_war_pike             MAIN   MELEE  threat 3 -> 3   the long one; Caress ignores the SIZE
##   mw_acrasial_falcata     SUPER  MELEE  threat 3 -> 4   the widened one (test 13)
##   mw_anti_materiel_rifle  HEAVY  RIFLE  threat 1 -> 1   integrated, never mounted, never offered
##
## ============================ PROVING THE RECORDER IS NOT BLIND ============================
##
## SP2 shipped a defect exactly in the shape of test 2: a prompt recorder that could not see prompts
## the base class answered, which left "no prompt appeared" green against content that raised one.
## Two things stop that here.
##
## - testkit/mod_choice_responder.gd's _answer_multiple_choice RECORDS BEFORE IT ANSWERS and is
##   reached whether or not multiple_choice_queue has anything in it (:107-131, and :81-83 falls back
##   to the inherited index) - so there is no "the base answered it" path that skips the recorder.
## - test 3 reads labels off a recorded prompt raised by THIS action through THIS helper. It is the
##   positive control for every "zero prompts" assertion in the file: if the recorder were blind to
##   Spin's prompt, test 3 could not pass.
##
## And test 2 adds a SECOND, independent witness that does not go through the prompts array at all:
## PrimroseFixture.spin always queues an answer, so a queue that comes back UNCONSUMED is direct
## evidence that nothing asked.
##
##   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spin.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const KIT_ID := &'ms_flourishing_twirl'
const ACTION_ID := &'action_spin'

## The card's numbers, transcribed once so a typo in the .tres reads as a number rather than a vague
## "feels wrong".
const SP_COST := 2
const CHARGES := 4
const DAMAGE := 4

## The Primrose's mounts, in frame order: Main, Main, Heavy (mf_primrose.tres mount_types).
const MAIN_A := 0
const MAIN_B := 1
const HEAVY := 2

## The printed and buffed threats of the three mountable weapons - see the header's table.
const RIFLE_THREAT := 1
const PIKE_THREAT := 3
const FALCATA_PRINTED := 3
const FALCATA_BUFFED := 4

## Geometry. The map is 15x9 (FitzgeraldFixture.DEFAULT_MAP_SIZE) and everything here is one row.
const PRIMROSE_TILE := Vector2i(5, 4)
const AT_ONE := Vector2i(6, 4)
const AT_THREE := Vector2i(8, 4)
const AT_FOUR := Vector2i(9, 4)
const AT_FIVE := Vector2i(10, 4)
const ALLY_TILE := Vector2i(5, 5)

## Test 8's wall: a three-tile forbidden interior between the Primrose and AT_THREE, and a second
## hostile the same distance away down a clear column. The wall shape is
## test_abjuration_of_metal.gd:283-288's, which is the mod's one proven way to stage a real sight
## blocker.
const WALL_TILES:Array[Vector2i] = [Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5)]
const IN_THE_OPEN := Vector2i(5, 7)

var game:Gamemaster
var responder
var primrose:Unit
var twirl:GearCore

## Records every event_unit_damage that lands on its holder: how much, of what type, and WHO the
## engine was told did it. Lifted verbatim from test_solfataric_breach.gd:77-100, which records why
## it is a Buff and not a signal: context.target_unit is the DAMAGER on a damage event
## (event_unit_damage.gd:35) and nothing on the victim afterwards remembers it.
##
## Does NOT call super() in activate(): Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one has to survive several hits.
class DamageRecorder extends Buff:
	var hits:Array[Dictionary] = []

	func _init() -> void:
		compcon_id = &'buff_spec_spin_damage_recorder'
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
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	primrose = Fixture.create_primrose(game, PRIMROSE_TILE)
	# EQUIPPED FIRST, MOUNTED SECOND, ALWAYS. equip() runs full_repair, which regenerates the mount
	# array from the frame (loadout_core.gd:196-214) and refills every charge - so a weapon mounted
	# before an equip is at the mercy of the inherit-and-legality pass, and a charge spent before one
	# would be silently refunded. Every test below mounts AFTER this line and equips nothing further.
	Fixture.equip(primrose, Fixture.HEAVY_RIFLE) # the integrated negative control - see the header
	twirl = Fixture.equip(primrose, KIT_ID)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## Put a weapon on one of the Primrose's three mounts and hand back its GearCore. Asserts the fit,
## because MountType.equip_primary silently returns null for a weapon the mount cannot take
## (mount_type.gd:42-48) and a null there would read downstream as "Spin ignored my weapon".
func mount(index:int, kit_id:StringName) -> GearCore:
	var gear:GearCore = primrose.core.loadout.mounts[index].equip_primary(kit_id)
	assert_true(GearCore.is_valid(gear), 'fixture: %s fits mount %d.' % [kit_id, index])
	return gear

func spin(choice_index:int = 0, flags:Array = []) -> void:
	await Fixture.spin(game, primrose, responder, choice_index, flags)

func prompts() -> Array[Dictionary]:
	return responder.multiple_choice_prompts

## The labels of the one prompt this activation raised, or an empty array if it raised none.
func labels() -> Array:
	if prompts().is_empty(): return []
	return Array(prompts()[0].labels)

func install_damage_recorder(on:Unit) -> DamageRecorder:
	var recorder := DamageRecorder.new()
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), on, BuffCore.create(recorder))
	return recorder

## A hostile that CANNOT pass the Agility save, wherever the shared dice FIFO happens to be.
## force_agility_save_to_fail, not force_save_to_fail: the frozen hull pair leaves agi at 0 and would
## be green for the wrong reason (primrose_fixture.gd:261-279 records the whole argument).
func doomed_hostile(tile:Vector2i) -> Unit:
	var hostile := Fixture.create_hostile(game, tile)
	Fixture.force_agility_save_to_fail(hostile)
	return hostile

func lucky_hostile(tile:Vector2i) -> Unit:
	var hostile := Fixture.create_hostile(game, tile)
	Fixture.force_agility_save_to_pass(hostile)
	return hostile

func is_impaired(unit:Unit) -> bool:
	return unit.has_status(Lancer.STATUS.IMPAIRED)

## How many StatusConditions of this type are on a unit, read straight off its state.
##
## FOR THE CORPSE IN TEST 15, where has_status is the wrong question: the unit is no longer valid, so
## a helper declining to find anything would read the same whether the status was never applied or
## applied and then torn off with the unit. This says "no Impaired was ever appended".
## test_solfataric_breach.gd:155-159 reads its own kill case exactly this way.
func listed(unit:Unit, status:StringName) -> int:
	var held := 0
	for condition:StatusCondition in unit.state.statuses:
		if condition.type == status: held += 1
	return held

## 1 HP and 1 structure, so the card's flat 4 is lethal. Every other hostile in this file is
## create_dummy's 200 HP punching bag, which is the point - see test 15.
## test_solfataric_breach.gd:228-231's helper, and for the same one test.
func make_fragile(unit:Unit) -> void:
	unit.core.frame.stat.health = 1
	unit.core.frame.stat.structure = 1
	unit.core.full_repair()

## Everything action_spin's own gather would collect at `reach`. Used as a VACUITY GUARD: it is the
## engine's own radius computation, so "this unit was in the set and still took nothing" is a claim
## about the save or the faction filter, not about a hostile that was simply out of range.
func gathered_at(reach:int) -> Array[Unit]:
	return UnitRelation.get_characters_within(
		primrose, reach, true,
		func(other:Unit) -> bool: return UnitRelation.are_enemies(primrose, other)
	)

# ================================================================ 1. the system as data

func test_the_licence_grants_flourishing_twirl_at_rank_three() -> void:
	# THE KIT'S PRINTED DATA RIDES ALONG HERE rather than in a fifteenth test, because the plan
	# allots this file exactly fourteen and "the system exists at rank 3" is one claim: the licence
	# grants it, and what it grants is the card's system.
	var license:UnlockTree = ContentLibrary.get_license_tree(Fixture.LICENSE_ID)
	assert_not_null(license, 'li_primrose is registered.')
	if license == null or license.rank_3 == null: return
	# has(), NEVER sort() - Array[StringName].sort() compares interned pointers, not alphabetically.
	var ids:Array[StringName] = []
	for kit:Kit in license.rank_3.granted_gear: ids.append(kit.compcon_id)
	assert_has(ids, KIT_ID, 'rank 3 grants the Flourishing Twirl.')

	# ContentLibrary.get_kit NEVER returns null - it hands back a Kit.UNKNOWN_ID placeholder - so the
	# id is what has to be asserted, not the object.
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_eq(kit.compcon_id, KIT_ID, '%s is really in the kits index.' % KIT_ID)
	assert_eq(kit.sp_cost, SP_COST, 'SP 2.')
	assert_true(kit.is_unique(), 'UNIQUE - system_tags = 1, the mw_rend_axe / wm_ddmr shape.')
	assert_eq(kit.charges_max, CHARGES, 'LIMITED 4.')
	assert_eq(kit.actions.size(), 1, 'One action.')

	var action = kit.get_action(ACTION_ID)
	assert_not_null(action, 'And it is %s.' % ACTION_ID)
	if action == null: return
	assert_true(action is ActionSystem, 'An ActionSystem.')
	assert_eq(action.get_action_type(Fixture.specific(primrose, KIT_ID)), Lancer.ACTION.QUICK, 'Quick.')
	# NOT DECORATION: a Kit whose actions share no usage group shares BOTH counters
	# (gear_core.gd:166-171, the Subutai SP2 lesson). One action today; a second would otherwise
	# inherit this one's per-turn tally.
	assert_eq(action.usage_group, &'spin', 'With its own usage group.')
	# fxg_use moved out to test 16 at Task 4; this test's job is the licence and the printed card.

# ================================================================ 2. one weapon, no prompt

func test_with_one_mounted_weapon_no_prompt_appears_and_its_threat_is_used() -> void:
	mount(MAIN_B, Fixture.LONG_MELEE) # the War Pike: threat 3, and Artful Caress does not widen it
	var reached := doomed_hostile(AT_THREE)
	var beyond := doomed_hostile(AT_FOUR)

	await spin()

	# TWO INDEPENDENT WITNESSES THAT NOTHING ASKED - see the file header on SP2's defect.
	assert_eq(prompts().size(), 0, 'No menu was raised: with one mounted weapon Spin takes it.')
	assert_eq(responder.multiple_choice_queue.size(), 1,
		'And the queued answer came back unconsumed, which is the witness that does not go through '
		+ 'the prompt recorder at all.')
	# AND THERE REALLY WAS A SECOND WEAPON ON THE UNIT - before_each equipped one, integrated. Without
	# these two lines "no menu was raised" would be equally true of a Primrose carrying one weapon in
	# total, and the mount filter would go unpinned in this test.
	var integrated:GearCore = primrose.get_gear(Fixture.HEAVY_RIFLE)
	assert_true(GearCore.is_valid(integrated), 'fixture: the Primrose carries a second weapon.')
	assert_null(primrose.core.loadout.get_mount_for_gear(integrated),
		'On no mount, which is why it was never a two-weapon pick.')

	assert_true(is_impaired(reached), 'A hostile at exactly the weapon\'s threat of 3 was reached.')
	assert_eq(reached.current_damage(), DAMAGE, 'And took the card\'s 4.')
	assert_false(is_impaired(beyond), 'One tile further out, nobody was touched.')
	assert_eq(beyond.current_damage(), 0, 'At all.')

# ================================================================ 3. two weapons, the menu

func test_with_two_mounted_weapons_the_prompt_lists_both() -> void:
	mount(MAIN_A, Fixture.MAIN_RIFLE)  # Assault Rifle, threat 1
	mount(MAIN_B, Fixture.LONG_MELEE)  # War Pike, threat 3

	await spin(0)

	assert_eq(prompts().size(), 1, 'Exactly one menu was raised.')
	if prompts().is_empty(): return
	var entries:Array = labels()
	# THE CONTENT, NOT THE COUNT ALONE. A count of two would be equally true of a menu listing the
	# same weapon twice, or of one listing the integrated rifle instead of the pike.
	assert_eq(entries.size(), 2, 'Two entries: the two MOUNTED weapons, and not the integrated one.')
	if entries.size() != 2: return

	var term:String = X.tr('lancer.term.threat')
	assert_true(str(entries[0]).begins_with(X.tr('gear.mw_assault_rifle.name')),
		'The first entry is the weapon on the first mount, by its own name: %s' % entries[0])
	assert_true(str(entries[1]).begins_with(X.tr('gear.mw_war_pike.name')),
		'The second is the weapon on the second mount: %s' % entries[1])
	# EACH LABEL CARRIES ITS OWN NUMBER. Built from the pieces rather than compared against one more
	# call to label_for(), which would only prove the script agrees with itself.
	assert_true(str(entries[0]).ends_with('(%s %d)' % [term, RIFLE_THREAT]),
		'And the rifle is offered at its threat of 1: %s' % entries[0])
	assert_true(str(entries[1]).ends_with('(%s %d)' % [term, PIKE_THREAT]),
		'While the pike is offered at its threat of 3: %s' % entries[1])
	assert_ne(entries[0], entries[1], 'So the two entries are genuinely distinguishable in the menu.')
	assert_eq(Array(prompts()[0].disabled_reasons), ['', ''],
		'Neither is greyed out: every mounted weapon qualifies (ruling 4).')

# ================================================================ 4. the pick is the reach

func test_the_picked_weapons_threat_is_the_one_used() -> void:
	mount(MAIN_A, Fixture.MAIN_RIFLE) # threat 1 -> index 0
	mount(MAIN_B, Fixture.LONG_MELEE) # threat 3 -> index 1
	var hostile := doomed_hostile(AT_THREE)

	# THE SHORT WEAPON FIRST, so the second half cannot be green by accident: if picking the rifle
	# already reached three tiles, the pike half below would prove nothing.
	await spin(0)
	assert_eq(prompts().size(), 1, 'fixture: the menu really was raised.')
	assert_false(is_impaired(hostile), 'Picking the threat-1 rifle does not reach three tiles.')
	assert_eq(hostile.current_damage(), 0, 'Nothing at all happened to it.')

	# THE SAME TURN, THE SAME HOSTILE, THE SAME TILE - only the pick changes.
	#
	# THE SECOND PRESS IS A FREEBIE, AND IT HAS TO BE. A QUICK is refused a second time in one turn
	# however many action points are left: can_activate_gear fails is_under_per_turn_limit
	# (unit_action.gd:116) and event_gear_activate aborts the whole event before activate() is ever
	# reached. Measured at this task - the first draft pressed twice unflagged and the second press
	# vanished with a bare "specific: invalid" abort and no "[ Gear not available ]" line, because
	# the unavailable REASON is NONE and it is the affordability half that refuses. AS_FREEBIE
	# short-circuits that (:114) and still spends the charge (:274).
	await spin(1, [Action.FLAG.AS_FREEBIE])
	assert_eq(prompts().size(), 2, 'fixture: and a second menu for the second press.')
	assert_true(is_impaired(hostile), 'Picking the threat-3 pike does.')
	assert_eq(hostile.current_damage(), DAMAGE, 'For the card\'s 4.')

# ================================================================ 5-7. what a save decides

func test_a_hostile_in_threat_and_sight_takes_four_kinetic_and_is_impaired_on_a_failed_save() -> void:
	mount(MAIN_B, Fixture.LONG_MELEE)
	var hostile := doomed_hostile(AT_THREE)
	var recorder := install_damage_recorder(hostile)

	await spin()

	assert_eq(recorder.hits.size(), 1, 'Exactly one damage event landed on it.')
	if recorder.hits.is_empty(): return
	assert_eq(recorder.hits[0].number, DAMAGE, 'Four.')
	assert_eq(recorder.hits[0].category, Lancer.DAMAGE_TYPE.KINETIC, 'Kinetic, as the card says.')
	# ATTRIBUTION. The damage event's target_unit is WHO DEALT it (event_unit_damage.gd:35), and it
	# is what feeds every "you damaged them" hook downstream.
	assert_eq(recorder.hits[0].damager, primrose.core.persistent_id,
		'And the engine was told the PRIMROSE did it.')
	assert_true(is_impaired(hostile), 'And it is Impaired.')

func test_a_passed_save_takes_nothing() -> void:
	mount(MAIN_B, Fixture.LONG_MELEE)
	var hostile := lucky_hostile(AT_THREE)

	# VACUITY GUARD, BEFORE THE PRESS. The engine's own radius computation says this hostile is in
	# the set action_spin gathers - so "it took nothing" below is a claim about the SAVE and not
	# about a hostile that was quietly out of range all along.
	assert_has(gathered_at(PIKE_THREAT), hostile, 'fixture: it is inside the pike\'s threat and in sight.')

	await spin()

	assert_eq(twirl.charges_current, CHARGES - 1, 'fixture: the Spin really happened.')
	assert_eq(hostile.current_damage(), 0, 'A passed save takes no damage.')
	assert_false(is_impaired(hostile), 'And no Impaired either - the card ties both to the failure.')

func test_the_impairment_lasts_until_the_end_of_the_targets_next_turn() -> void:
	mount(MAIN_B, Fixture.LONG_MELEE)
	var hostile := doomed_hostile(AT_THREE)

	await spin()

	# SOURCED TO THE SYSTEM, which is what lets the chip name itself on the target's status bar and
	# what a future "while impaired by Flourishing Twirl" clause would key on.
	var condition:StatusCondition = UnitCondition.get_status(
		hostile, Lancer.STATUS.IMPAIRED, twirl.persistent_id
	)
	assert_not_null(condition, 'The Impaired is sourced to the Flourishing Twirl gear.')
	if condition == null: return
	assert_eq(condition.until, Lancer.UNTIL.END_OF_NEXT_TURN, 'Until the end of their next turn.')

# ================================================================ 8. line of sight

func test_a_hostile_out_of_sight_is_untouched() -> void:
	# require_los = TRUE, unlike the Leap's and the Hammer's radii: the card says "within its threat
	# AND LINE OF SIGHT" in so many words, and at a reach of three that is a difference a player will
	# actually see. The blocker is a real one - a three-tile forbidden interior, the shape
	# test_abjuration_of_metal.gd:283-288 already proves blinds tiles behind it - rather than a
	# Blinded Primrose, which would test can_see's OTHER clause (unit_relation.gd:210-211).
	SpecFactory.add_setpieces_to_landscape(
		game.get_landscape_node(), &'setpiece_forbidden_interior', WALL_TILES
	)
	game.map.calculate_los_blockers()

	mount(MAIN_B, Fixture.LONG_MELEE)
	var hidden := doomed_hostile(AT_THREE)     # straight through the wall
	var seen := doomed_hostile(IN_THE_OPEN)    # the same distance, down a clear column

	# THE STAGING IS ASSERTED BEFORE IT IS USED. Without these three lines "the hidden one took
	# nothing" would be equally true of a wall that blocks nothing and a hostile standing out of
	# range - which is precisely the vacuous shape this task was told to refuse to ship.
	assert_eq(UnitRelation.distance_between(primrose, hidden), PIKE_THREAT,
		'fixture: the hidden hostile is inside the pike\'s threat.')
	assert_false(UnitRelation.can_see(primrose, hidden), 'fixture: and the wall really blinds it.')
	assert_true(UnitRelation.can_see(primrose, seen), 'fixture: while the other one is in plain sight.')

	await spin()

	assert_false(is_impaired(hidden), 'The hostile behind the wall is untouched.')
	assert_eq(hidden.current_damage(), 0, 'It took nothing.')
	assert_true(is_impaired(seen), 'While the one in the open, the same distance away, did not escape.')
	assert_eq(seen.current_damage(), DAMAGE, 'And took the card\'s 4.')

# ================================================================ 9. friendly fire

func test_an_ally_within_threat_is_untouched() -> void:
	mount(MAIN_B, Fixture.LONG_MELEE)
	var ally := Fixture.create_ally(game, ALLY_TILE)
	var hostile := doomed_hostile(AT_ONE)
	Fixture.force_agility_save_to_fail(ally) # so nothing but the faction filter can save it

	await spin()

	assert_true(is_impaired(hostile), 'VACUITY: the hostile beside us was caught.')
	assert_false(is_impaired(ally), 'The ally beside us was not.')
	assert_eq(ally.current_damage(), 0, 'And took nothing, though its Agility save is hopeless too.')

# ================================================================ 10-12. what a Spin costs

func test_a_charge_is_spent() -> void:
	mount(MAIN_B, Fixture.LONG_MELEE)
	var hostile := doomed_hostile(AT_THREE)
	assert_eq(twirl.charges_current, CHARGES, 'fixture: four to start with.')

	await spin()

	assert_true(is_impaired(hostile), 'VACUITY: the Spin really resolved.')
	assert_eq(twirl.charges_current, CHARGES - 1, 'One of four charges is gone.')

func test_cancelling_the_prompt_spends_nothing() -> void:
	# RULING 4 + THE RULING-1 ORDERING. choose_from_multiple_choice returns -1 on a cancel
	# (choice_bus.gd:138-141) and activate returns BEFORE spend_actions, which is the only route to
	# gear.spend_charge() (unit_action.gd:274). Moving spend_actions above the prompt reddens this
	# test and, by the plan's prediction and this run's measurement, only this test.
	mount(MAIN_A, Fixture.MAIN_RIFLE)
	mount(MAIN_B, Fixture.LONG_MELEE)
	var hostile := doomed_hostile(AT_THREE)
	var actions_before:int = primrose.state.actions

	await spin(Fixture.CANCEL_INDEX)

	assert_eq(prompts().size(), 1, 'fixture: the menu really was raised, and then declined.')
	assert_eq(twirl.charges_current, CHARGES, 'No charge was spent.')
	assert_eq(primrose.state.actions, actions_before, 'Nor the Quick.')
	assert_eq(primrose.state.actions, UnitAction.current_total(primrose),
		'The turn\'s whole allowance is still there.')
	assert_false(is_impaired(hostile), 'And nobody was spun at.')

func test_spin_with_no_mounted_weapon_spends_nothing() -> void:
	# NOTHING IS MOUNTED, but before_each left an INTEGRATED Anti-Materiel Rifle on the loadout - so
	# this is the get_mount_for_gear filter under test and not an empty loadout. A Spin with nothing
	# to measure is not a charge the player should lose, so activate returns before spend_actions.
	var integrated:GearCore = primrose.get_gear(Fixture.HEAVY_RIFLE)
	assert_true(GearCore.is_valid(integrated), 'fixture: the Primrose does carry a weapon.')
	assert_null(primrose.core.loadout.get_mount_for_gear(integrated),
		'fixture: and it is INTEGRATED, on no mount at all.')
	var hostile := doomed_hostile(AT_ONE)
	var actions_before:int = primrose.state.actions

	await spin()

	assert_eq(prompts().size(), 0, 'No menu: there was nothing to choose between.')
	assert_eq(twirl.charges_current, CHARGES, 'No charge was spent.')
	assert_eq(primrose.state.actions, actions_before, 'Nor the Quick.')
	assert_false(is_impaired(hostile), 'And the hostile standing right beside us is untouched.')
	assert_eq(hostile.current_damage(), 0, 'Entirely.')

# ================================================================ 13. the compat case

func test_under_artful_caress_the_falcatas_spin_reaches_one_tile_further() -> void:
	# THE ONE TEST THAT PROVES THE LABEL AND THE RADIUS READ THE **BUFFED** THREAT (ruling 4). Every
	# other weapon in this file prints what it measures; the Falcata is Superheavy melee, so the
	# frame's own Artful Caress adds +1 through Buff.TO.ACTION_RANGE / THREAT_RANGE
	# (action_attack_weapon.gd:187-190). Swap threat_distance(specific) for the printed action.threat
	# and this is the test that goes red.
	var falcata := mount(HEAVY, Fixture.FALCATA)
	var specific := SpecificAction.create(primrose, falcata, falcata.kit.get_weapon_actions()[0])
	assert_eq(specific.action.threat, FALCATA_PRINTED, 'fixture: the Falcata PRINTS threat 3.')
	assert_eq(specific.action.threat_distance(specific), FALCATA_BUFFED,
		'fixture: and Artful Caress makes it 4.')

	var further := doomed_hostile(AT_FOUR)
	var beyond := doomed_hostile(AT_FIVE)

	await spin()

	assert_eq(prompts().size(), 0, 'fixture: one mounted weapon, so no menu.')
	assert_true(is_impaired(further), 'A hostile at FOUR - the buffed threat - is caught.')
	assert_eq(further.current_damage(), DAMAGE, 'For the card\'s 4.')
	assert_false(is_impaired(beyond), 'One further out is not: the buff widens by one, not by two.')
	assert_eq(beyond.current_damage(), 0, 'And took nothing.')

# ================================================================ 14. the ordering

func test_a_victim_the_spin_kills_is_never_impaired() -> void:
	# THE ONE CASE IN WHICH "INLINE, NOT QUEUED" IS OBSERVABLE, and it has to be built on purpose.
	# activate awaits the 4 kinetic INLINE and then `continue`s on a victim that did not survive it,
	# so a hostile the 4 finishes is gone before the Impaired is reached and never gets one. Swap that
	# await for activation.queue_event and the damage runs only after activate() has returned
	# (event_core.gd:71-75 against :84-88) - at which point the victim is still standing, takes the
	# Impaired, and dies afterwards.
	#
	# EVERY OTHER HOSTILE IN THIS FILE HAS 200 HP, which is create_dummy's punching bag and exactly
	# the hole action_solfataric_breach.gd:201-207 records this mod falling into once already: that
	# trait's first draft kept all 18 of its tests green under the same mutation, because none of them
	# killed anything. This task's review said the same hole was open here. It was.
	#
	# MEASURED at the fix wave, mutation in place: 14/15, and this is the only red.
	mount(MAIN_B, Fixture.LONG_MELEE)
	var doomed := doomed_hostile(AT_ONE)
	make_fragile(doomed)
	var sturdy := doomed_hostile(AT_THREE)

	# THE STAGING IS ASSERTED BEFORE IT IS USED. Both are really in the set the Spin gathers, so
	# neither half below can be green because somebody was quietly out of range.
	assert_has(gathered_at(PIKE_THREAT), doomed, 'fixture: the fragile hostile is inside the pike\'s threat.')
	assert_has(gathered_at(PIKE_THREAT), sturdy, 'fixture: and so is the one that will survive its 4.')

	await spin()

	assert_false(Unit.is_valid(doomed), 'The card\'s flat 4 finished a 1 HP, 1 structure hostile.')
	# listed(), NOT is_impaired(): see the helper - on a corpse the two questions are different.
	assert_eq(listed(doomed, Lancer.STATUS.IMPAIRED), 0,
		'And no Impaired was ever appended to it: the damage ran inline, so the loop saw the death '
		+ 'before it reached the status.')
	# THE SPIN DID NOT STOP THERE. This is the `continue`-rather-than-abort_without_unit choice in
	# action_spin's loop, though only weakly: results.failed is walked in gather order, so a mutation
	# to the abort form would redden this line only when the corpse happens to come first.
	assert_true(is_impaired(sturdy), 'While the hostile that survived its 4 is Impaired as usual.')
	assert_eq(sturdy.current_damage(), DAMAGE, 'For the card\'s 4.')
	assert_eq(twirl.charges_current, CHARGES - 1, 'And the Spin cost its charge either way.')

# ================================================================ 15. the card text

func test_the_name_and_flavour_and_effect_resolve() -> void:
	for key:String in ['gear.ms_flourishing_twirl.name', 'gear.ms_flourishing_twirl.flavor',
			'gear.ms_flourishing_twirl.action_spin.name', 'gear.ms_flourishing_twirl.action_spin.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

# ================================================================ 16. the use-FX

## RULING 20 PUTS EXACTLY ONE THING IN A TEST HERE: that the action carries fxg_spin.tscn. Everything
## about how the spin LOOKS - the duration, the four quadrant flips, whether it reads as a whip or a
## stutter - is judged by the author through the FX tester, which hot-reloads:
##
##   "D:/DEV/Godot_v4.7.2-stable_win64_console.exe" --path D:/DEV/lancer-tactics-modkit res://ui/page/fx_group_tester/fx_group_tester.tscn
##
## AND THIS TEST CANNOT SEE THE HALF THAT MATTERS MOST. Wiring fxg_use is inert on its own: nothing
## in the engine calls ActionSystem.run_system_fxgs, so action_spin.activate has to call it itself
## (action_system.gd:70-105; the header of action_spin.gd has the full finding). Delete that call and
## this test stays green while the screen stays still. Recorded rather than papered over with a
## spec that would have to instantiate an FxGroup to say anything real.
func test_the_spin_action_carries_its_own_use_fx() -> void:
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	var action = kit.get_action(ACTION_ID)
	assert_not_null(action, '%s is on the kit.' % ACTION_ID)
	if action == null: return
	# ActionSystem.fxg_use is a PackedScene, not an id (action_system.gd:16) - so the assertion is on
	# the scene itself, and on its path, rather than on a ContentLibrary lookup.
	assert_not_null(action.fxg_use, 'Spin carries a use-FX.')
	if action.fxg_use == null: return
	assert_true(action.fxg_use.resource_path.ends_with('fxg_spin.tscn'),
		'And it is fxg_spin.tscn, not the engine default: %s' % action.fxg_use.resource_path)
