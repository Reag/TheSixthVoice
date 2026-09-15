# SP1 Task 7: Blasting Powder, the Fitzgerald's fifth and last trait.
#
# Design §2.3, ruling 5 (2026-09-13):
#   1/round, when the Fitzgerald makes a successful ranged attack with a Line weapon, it may deal an
#   additional +1 bonus damage to the next character hit within that line, increasing on consecutive
#   hits.
#
# RULING 5 IN FULL, which is what this file actually pins: Line targets resolve closest-first; the
# 1st character HIT gets +0, the 2nd +1, the 3rd +2; misses in between are ignored; the 1/round is
# consumed by the first Line attack that hits at least one character, and a Line attack that hits
# nobody does not consume it. The "may" is always yes.
#
# THE WHOLE TASK TURNS ON PER-TARGET VERSUS PER-ATTACK ORDERING. The bonus comes from a
# BONUS_DAMAGE_SPECIFIC buff, whose get_values runs ONCE PER TARGET - so counting the round there
# would spend it on the first target and deny targets 2 and 3 their bonus, while the damage numbers
# still looked roughly right. The round is therefore spent by a separate hidden ATTACK_DECLARED POST
# reaction, which runs after every per-target bonus has been computed
# (event_unit_attack_declared.gd:221 executes the POST rxns at the very end of execute(), long after
# the per-roll roll_specific_bonus_damage loop at :127-145). Test 1 is the one that would fail under
# the naive implementation: it asserts the damage EACH of three targets took, not merely that a
# bonus happened somewhere.
#
# WHY EVERY DIE IS A 6 AND HIT/MISS IS CONTROLLED BY EVASION INSTEAD. Dice.CHEAT_ROLL_QUEUE is ONE
# global FIFO for every roll in the run (dice.gd:22-37) - d20s, accuracy dice and damage dice all
# pop from the same front - so a queue like [19, 19, 19] does NOT reliably hand three attack rolls a
# 19: the Inaccurate accuracy die between them eats one. (test_knock_em_down.gd's cheat_two_crits
# has the same exposure and gets away with it because nothing there asserts the SECOND roll crit.)
# Filling the queue with nothing but 6s removes the question: base_roll 6, accuracy -6, damage 2d6 =
# 12 exactly, whatever order they pop in. Hit and miss are then set per target through evasion,
# which is read fresh per attack roll and cannot be eaten by a neighbouring die. It also guarantees
# no CRIT (total_roll 0 is nowhere near attack_roll.gd:73's `>= 20`), which keeps the Fitzgerald's
# OTHER 1/round trait - Knock 'em down, a crit trigger - out of these numbers entirely.
#
# WHY THE FIRER IS TOPPED UP BETWEEN SHOTS: see top_up_the_firer() below.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## The Bizarre Cannon moved to its OWN Kit at the 2026-09-15 patch, so the character sheet could
## title the integrated-weapon box "Bizarre Cannon" rather than "Broadside"
## (weapon_mount_item.gd:101 reads the KIT's name). cp_broadside keeps the protocol.
const KIT_ID := &'mw_bizarre_cannon'
const ACTION_ID := &'action_bizarre_cannon'
const TRAIT_ID := &'mt_blasting_powder'
const USAGE_KEY := &'blasting_powder'

## A vanilla Cannon that is NOT a Line: Blast 1, so one shot can still hit two characters and the
## "no bonus" claim is observable as damage rather than only as a counter. mw_mortar carries no
## loading/ordnance tag, so a spec can just fire it.
const MORTAR_ID := &'mw_mortar'

## Read THIS MOD'S OWN compiled artifact, not the global tr(): same reasoning as
## test_bizarre_cannon.gd:46 and test_content_integrity.gd:107.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const RELIABLE_ON_MISS := 2 # the Bizarre Cannon's Reliable 2
## 2d6 with every die cheated to 6. The Bizarre Cannon is AP and the targets have armor 0, so this
## is exactly what an un-bonused hit deals.
const BASE_DAMAGE := 12

const FIRE_FROM := Vector2i(7, 4)
const NEAR_TILE := Vector2i(9, 4)
const MID_TILE := Vector2i(11, 4)
const FAR_TILE := Vector2i(13, 4)
## Blast 1 centred between NEAR_TILE and MID_TILE catches both and leaves FAR_TILE alone.
const BLAST_CENTRE := Vector2i(10, 4)
## Well off the y = 4 firing lane, for the one test that kills everything standing in it.
const SURVIVOR_TILE := Vector2i(2, 8)

var game:Gamemaster
var unit:Unit
var near:Unit
var mid:Unit
var far:Unit

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	# NOT FrameIsolation'd, same reasoning as test_bizarre_cannon.gd and test_knock_em_down.gd: a
	# deep duplicate of the frame would hand the unit COPIES of its trait Kits, and Kit.compcon_id is
	# a lazily-derived bare var that does not survive duplicate(), which would break the
	# unit.get_gear(&'mt_blasting_powder') lookup this whole file leans on.
	unit = FitzgeraldFixture.create_fitzgerald(game, FIRE_FROM)

	near = _make_target(NEAR_TILE)
	mid = _make_target(MID_TILE)
	far = _make_target(FAR_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

## A hostile target that always gets hit and always survives, with its own private frame.
##
## heat is set deliberately, not incidentally: test_the_bonus_is_kinetic_on_a_kinetic_weapon reads
## current.heat as its canary, and event_unit_damage.gd:204-208 CONVERTS heat damage to energy damage
## on a unit whose heat_max is 0 - which would quietly turn that test's discriminator back into HP
## damage and make it pass for the wrong reason.
func _make_target(tile:Vector2i) -> Unit:
	# health, armor and evasion (-10: every shot lands unless a test says otherwise) come from the
	# shared fixture. heat stays local to this file - it is the one stat none of the other three
	# spec files need - and the second full_repair() below is harmless: nothing has taken an action
	# against this unit yet, so there is no uses_this_round or similar state for a second repair to
	# clobber (see top_up_the_firer()'s own comment on that hazard, which applies only mid-spec).
	var target:Unit = FitzgeraldFixture.create_dummy(game, tile, -10)
	target.core.frame.stat.heat = 20
	target.core.full_repair()
	return target

func _trait_gear() -> GearCore:
	var gear := unit.get_gear(TRAIT_ID)
	return gear if GearCore.is_valid(gear) else null

func _uses() -> int:
	var gear := _trait_gear()
	return -1 if gear == null else gear.get_uses_this_round_alt(USAGE_KEY)

func fire_at(tile:Vector2i) -> void:
	await FitzgeraldFixture.open_turn(game, unit)
	await SpecFactory.use(game, unit, KIT_ID, ACTION_ID, tile)

## A SECOND shot in the same turn. The Bizarre Cannon is a full action and the Fitzgerald has one
## activation a turn, so a plain second fire_at() does not miss or fizzle - it never fires at all:
## event_gear_activate's check_specific_context fails UnitAction.is_gear_affordable and the whole
## event is ABORTED, which reads in a spec as "the trait awarded no bonus" rather than "no shot was
## taken". (Seen in this file's own RED run: the second shot dealt 0 to everybody.) Action.FLAG.
## AS_FREEBIE is the established way round it - test/gear/test_mw_autogun.gd and
## test_mt_altruism.gd both fire this way - and it skips only the action cost and the per-TURN
## counter (unit_action.gd:236), so it is the same attack in every way this file measures. In
## particular it is NOT Action.FLAG.NO_BONUS_DAMAGE, which is the flag that would suppress the very
## thing under test.
func fire_again_at(tile:Vector2i) -> void:
	await FitzgeraldFixture.open_turn(game, unit)
	await SpecFactory.use(game, unit, KIT_ID, ACTION_ID, tile, [Action.FLAG.AS_FREEBIE])

## Every die in the run comes back a 6 until the queue runs dry. See the header for why this is the
## whole dice strategy. CLEARS FIRST: Dice.cheat_attack only APPENDS, so an unspent buffer from an
## earlier shot would sit in front of this one's rolls.
func cheat_every_die_to_six() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([], buffer)

## The Bizarre Cannon's recoil costs the firer 2 AP kinetic damage per shot and the Fitzgerald has 6
## HP, so the third shot in a test would push it into STRUCTURE damage - a different event chain,
## with its own rolls off the shared dice queue, in the middle of a measurement.
##
## Writes current.health directly instead of calling full_repair()/short_repair(), which CLEAR
## uses_this_round (gear_core.gd:130-133) and would silently reset the very 1/round counter these
## tests exist to measure. It touches nothing on the targets.
##
## The heat is cleared for the same reason: the cannon is Heat 1 (Self) and the Fitzgerald's heat cap
## is 5, so a run of shots would eventually tip it into the danger zone and start a different event
## chain mid-measurement.
func top_up_the_firer() -> void:
	unit.core.current.health = unit.get_health_max()
	unit.core.current.heat = 0

func mark_damage() -> Array[int]:
	return [near.current_damage(), mid.current_damage(), far.current_damage()]

func damage_since(marked:Array[int]) -> Array[int]:
	var now := mark_damage()
	return [now[0] - marked[0], now[1] - marked[1], now[2] - marked[2]]

func make_evasive(targets:Array, evasion:int) -> void:
	for target:Unit in targets:
		target.core.frame.stat.evasion = evasion
		target.core.full_repair()

func set_entity_type(targets:Array, entity_type:int) -> void:
	for target:Unit in targets:
		target.core.frame.entity_type = entity_type
		target.core.full_repair()

## Low enough to die to a single shot of the Bizarre Cannon: 1 HP and its LAST point of structure, so
## the 12 damage takes structure to zero, which destroys the unit outright rather than rolling the
## structure table. Safe on a target - full_repair()'s uses_this_round reset is only a hazard on the
## FIRER, whose 1/round counter is what these tests measure.
func make_fragile(target:Unit) -> void:
	target.core.frame.stat.health = 1
	target.core.frame.stat.structure = 1
	target.core.full_repair()

## Makes a target read as a GRUNT to the Line's target sort without saddling it with the grunt
## statline. See test_a_grunt_nearest_the_firer_is_the_last_character_hit for why that is the honest
## fixture here rather than a dodge.
func make_grunt(target:Unit) -> void:
	target.core.templates.append(ContentLibrary.get_npc_template(&'npct_grunt'))

# ---------------------------------------------------------------- the trait

## THE TEST THIS TASK EXISTS FOR. Three characters on one line, one shot, and the damage EACH of
## them took asserted separately - which is what tells "the round is spent once per ATTACK" apart
## from "once per target". Counting the round inside the buff (the naive shape) would leave near on
## 12 and then deny mid and far their bonus, so this reads 12/12/12 instead of 12/13/14.
##
## near takes EXACTLY base damage, and that is the +0 doing its job rather than the trait being
## asleep: AttackUtil.DamageRoll.roll_bonus_damage skips a buff whose value comes back '' or '0'
## (attack_util.gd:302), so the first character hit is correctly NO BONUS ROLL AT ALL. The counter
## assertion at the end is what separates that from a dead trait - only the spend reaction can move
## it, and only a Line attack that hit a character reaches the spend reaction.
func test_a_line_hitting_three_targets_deals_plus_zero_one_two_in_distance_order() -> void:
	cheat_every_die_to_six()
	await fire_at(FAR_TILE)

	assert_eq(near.current_damage(), BASE_DAMAGE,
		'The 1st character hit takes base damage and no bonus roll at all (+0).')
	assert_eq(mid.current_damage(), BASE_DAMAGE + 1, 'The 2nd character hit takes +1.')
	assert_eq(far.current_damage(), BASE_DAMAGE + 2, 'The 3rd character hit takes +2.')
	assert_eq(_uses(), 1,
		'The spend reaction fired exactly once for the whole attack - not once per target.')

## Ruling 5: misses in between are ignored, so the third unit in the line is the SECOND character
## HIT and takes +1, not +2.
func test_hit_miss_hit_deals_plus_zero_then_plus_one() -> void:
	make_evasive([mid], 99) # the only thing that changes: this one cannot be hit

	cheat_every_die_to_six()
	await fire_at(FAR_TILE)

	assert_eq(near.current_damage(), BASE_DAMAGE, 'The 1st character hit still takes +0.')
	assert_eq(mid.current_damage(), RELIABLE_ON_MISS,
		'Fixture: the middle target was MISSED, and took only the Reliable 2.')
	assert_eq(far.current_damage(), BASE_DAMAGE + 1,
		'The far target is the 2nd character HIT, so +1: the miss was skipped, not counted.')
	assert_eq(_uses(), 1, 'An attack that hit at least one character spent the round.')

## The 1/round itself, and that a new round hands it back.
func test_a_second_line_attack_in_the_same_round_adds_nothing() -> void:
	cheat_every_die_to_six()
	await fire_at(FAR_TILE)
	var after_first := mark_damage()
	assert_eq(after_first, [BASE_DAMAGE, BASE_DAMAGE + 1, BASE_DAMAGE + 2],
		'Fixture: the first shot of the round awarded +0/+1/+2.')
	assert_eq(_uses(), 1, 'Fixture: the first shot spent the round.')

	top_up_the_firer()
	cheat_every_die_to_six()
	await fire_again_at(FAR_TILE)
	assert_eq(damage_since(after_first), [BASE_DAMAGE, BASE_DAMAGE, BASE_DAMAGE],
		'The second Line attack of the same round awards nothing to anybody.')
	assert_eq(_uses(), 1, 'And it did not spend the round a second time either.')

	# A new round (a new turn, in this spec) hands the trait back.
	await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)
	assert_eq(_uses(), 0, 'Fixture: the new round reset the usage counter.')

	var after_second := mark_damage()
	top_up_the_firer()
	cheat_every_die_to_six()
	await fire_at(FAR_TILE)
	assert_eq(damage_since(after_second), [BASE_DAMAGE, BASE_DAMAGE + 1, BASE_DAMAGE + 2],
		'Blasting Powder works again on the new round.')

## Ruling 5: a Line attack that hits nobody does not consume the 1/round.
func test_a_line_attack_that_misses_everyone_leaves_the_round_unconsumed() -> void:
	make_evasive([near, mid, far], 99)

	cheat_every_die_to_six()
	await fire_at(FAR_TILE)

	assert_eq(mark_damage(), [RELIABLE_ON_MISS, RELIABLE_ON_MISS, RELIABLE_ON_MISS],
		'Fixture: every target was missed, and took only the Reliable 2.')
	assert_eq(_uses(), 0, 'A Line attack that missed everyone did not spend the round.')

	# ...and the round really is still there to spend. full_repair() below resets their damage, so
	# these are absolute numbers again.
	make_evasive([near, mid, far], -10)
	top_up_the_firer()
	cheat_every_die_to_six()
	await fire_again_at(FAR_TILE)

	assert_eq(mark_damage(), [BASE_DAMAGE, BASE_DAMAGE + 1, BASE_DAMAGE + 2],
		'The next Line attack of the same round still gets its full bonus.')
	assert_eq(_uses(), 1, 'And that one spent the round.')

## Ruling 5's other half, in its hardest case: the 1/round is consumed by the first Line attack that
## HITS at least one character - whether or not any of them are still standing when the bookkeeping
## gets asked.
##
## THE TEST FOR REVIEW FINDING 1. Damage is applied at event_unit_attack_declared.gd:192; the spend
## reaction runs at :221, by which time the dead are off the map. Every "is this a unit" helper in
## the engine is alive-gated - get_all_hit_units() filters on Unit.is_valid
## (declared_attack_summary.gd:51), which demands unit.is_alive (unit.gd:86) - so an implementation
## that asked get_all_hit_units() got an EMPTY list here, left the round unspent, and paid the trait
## out all over again on the next Line shot of the same round. Nothing exotic on an Artillery frame
## firing down a lane of grunts. The fix reads the FRAME (frame.gd:100), which answers the question
## for a corpse as readily as for a survivor.
##
## The enemy off the line is not decoration: without it the entire hostile faction dies mid-test and
## the scene ends underneath the measurement.
##
## AND NEITHER IS THE CAMPAIGN CORE. setup_gamemaster's make_fresh_gamemaster path returns at
## spec_factory.gd:32, before the CampaignCore that the ordinary path builds at :47-48 - and
## EventService.remove_unit_from_game dereferences map.campaign_core on its way out
## (event_service.gd:80), one line ABOVE the unit.remove_from_game() at :85. So on a fresh gamemaster
## a death aborts halfway: three red "Nonexistent function 'get_lancer_by_id' in base 'Nil'" engine
## errors, and three corpses still answering true to Unit.is_valid - which would have made this test
## pass against the very bug it exists to catch. Measured, not guessed: that is exactly what the
## first run of this test did.
func test_a_line_that_kills_every_character_it_hits_still_spends_the_round() -> void:
	game.campaign_core = CampaignCore.create(SpecFactory.create_campaign_base())
	game.map.campaign_core = game.campaign_core

	var survivor:Unit = SpecFactory.create_unit(game.map, SURVIVOR_TILE, Faction.AI_ENEMY)
	for doomed:Unit in [near, mid, far]: make_fragile(doomed)

	cheat_every_die_to_six()
	await fire_at(FAR_TILE)

	assert_false(Unit.is_valid(near), 'Fixture: the shot killed the near target.')
	assert_false(Unit.is_valid(mid), 'Fixture: and the middle one.')
	assert_false(Unit.is_valid(far), 'Fixture: and the far one.')
	assert_true(Unit.is_valid(survivor),
		'Fixture: the enemy off the line survived, so the scene did not end mid-test.')
	assert_eq(_uses(), 1,
		'The attack hit three characters, so it spent the round. Killing them does not hand it back.')

## The gate is on the range PATTERN, not on the weapon type: a Cannon that is not a Line does
## nothing. Fired with mw_mortar (Blast 1) rather than a single-target weapon on purpose - a
## single-target shot would hit exactly one character, whose bonus is +0 either way, so "no bonus"
## would be unobservable in damage and this test could only ever check the counter.
func test_a_non_line_cannon_shot_adds_nothing() -> void:
	unit.core.equip_system(MORTAR_ID)
	SpecFactory.apply_passive_buffs(unit)

	cheat_every_die_to_six()
	await FitzgeraldFixture.open_turn(game, unit)
	await SpecFactory.use_solo(game, unit, MORTAR_ID, BLAST_CENTRE)

	assert_gt(near.current_damage(), 0, 'Fixture: the blast caught the near target.')
	assert_gt(mid.current_damage(), 0, 'Fixture: the blast caught the middle target too.')
	assert_eq(near.current_damage(), mid.current_damage(),
		'Both characters took the same damage: the second one got no +1 from a non-Line Cannon.')
	assert_eq(far.current_damage(), 0, 'Fixture: Blast 1 did not reach the far target.')
	assert_eq(_uses(), 0, 'A non-Line Cannon shot did not spend the round either.')

## inherit_type_from_attack. The bonus damage is KINETIC because the Bizarre Cannon is.
##
## THE FLAG IS PINNED DIRECTLY RATHER THAN INFERRED. An earlier draft set the buff resource's own
## damage_type to HEAT so that a broken inheritance would show up as heat damage instead of HP
## damage - a canary. That was test scaffolding living in a shipped content file, asserting something
## false about the mechanic to whoever copies it as a template, and it bought nothing the assertion
## below does not buy honestly: damage_type is read only when INHERIT_TYPE is absent
## (attack_util.gd:299-300), so with the flag on it is dead weight either way. The resource now
## carries the KINETIC default, and the flag itself is asserted here.
##
## The behavioural half stays, because the flag being true is not proof the engine honoured it: with
## inheritance working the +1 lands as HP damage and no heat, and if it broke while the flag still
## read true the bonus would arrive as whatever damage_type says (event_unit_damage.gd:102-103 routes
## HEAT to the heat track, never to HP).
func test_the_bonus_is_kinetic_on_a_kinetic_weapon() -> void:
	var buff:Buff = ContentLibrary.get_buff(&'buff_blasting_powder')
	assert_not_null(buff, 'fixture: the buff resource is in ContentLibrary.')
	assert_true(buff is BuffDamage, 'fixture: and it is a BuffDamage.')
	if buff is BuffDamage:
		assert_true(buff.inherit_type_from_attack,
			"The bonus inherits the attack's damage type - which is what makes it kinetic here.")
		assert_eq(buff.damage_type, Lancer.DAMAGE_TYPE.KINETIC,
			'And the unused fallback type is the plain KINETIC default, not a test canary: a content'
			+ ' file must not claim a damage profile the trait does not have.')

	assert_gt(mid.get_heat_max(), 0,
		'fixture: the target HAS a heat track, so stray heat damage would show up there rather than'
		+ ' being converted to energy damage and landing on HP after all.')

	cheat_every_die_to_six()
	await fire_at(FAR_TILE)

	assert_eq(mid.current_damage(), BASE_DAMAGE + 1, 'The +1 landed as HP damage, i.e. as kinetic.')
	assert_eq(far.current_damage(), BASE_DAMAGE + 2, 'And so did the +2.')
	assert_eq(mid.core.current.heat, 0, "None of the bonus arrived as the buff's own declared HEAT.")
	assert_eq(far.core.current.heat, 0, 'Nor on the far target.')

## Ruling 5 says "the next CHARACTER hit", so an object in the line takes no bonus - the same call
## the author made for Knock 'em down in Task 6 review finding 1.
##
## SELF-CALIBRATING, and deliberately so: it never says how much damage an object takes from this
## weapon, only that the object takes the SAME amount on a shot where the bonus is available as on
## one where it is not (the second shot of the same round, with the round already spent). So it
## cannot be fooled by objects taking damage differently from mechs.
##
## It also pins the ORDERING with an object in the line. common_action_util.gd:474-480 sorts objects
## (and grunts) to the BACK of all_attacked_units, so the far character is the 2nd character hit and
## takes +1 - if objects resolved in distance order instead, it would be the 3rd unit hit and this
## would read +2.
func test_an_object_in_the_line_takes_no_bonus_damage() -> void:
	set_entity_type([mid], Frame.ENTITY.OBJECT)
	assert_false(mid.is_character(), 'fixture: the middle target is no longer a character.')

	var before_first := mark_damage()
	cheat_every_die_to_six()
	await fire_at(FAR_TILE)
	var first := damage_since(before_first)
	assert_eq(_uses(), 1, 'Fixture: the first shot spent the round, so the second gets no bonus.')

	var before_second := mark_damage()
	top_up_the_firer()
	cheat_every_die_to_six()
	await fire_again_at(FAR_TILE)
	var second := damage_since(before_second)

	assert_gt(second[1], 0, 'Fixture: the object was hit by both shots.')
	assert_eq(first[1], second[1], 'The object took no bonus damage on the bonused shot.')
	assert_eq(first[0], second[0], 'The 1st character hit took +0, as always.')
	assert_eq(first[2], second[2] + 1,
		'The far character is the 2nd CHARACTER hit and took +1 - the object neither took a bonus'
		+ ' nor consumed its place in the order.')

## "CLOSEST-FIRST" MEANS DISTANCE ORDER, AND THE TRAIT TAKES IT BACK FROM THE ENGINE.
## Author ruling, frame close 2026-09-14, replacing the pin this test used to carry.
##
## action_attack.gd:174 sorts a Line's targets through
## CommonActionUtil.sort_deployables_and_grunts_to_back (common_action_util.gd:474-480), whose second
## clause (:477) pushes npct_grunt units to the BACK. Grunts ARE characters, so in ENGINE order a
## grunt standing NEAREST the firer is the LAST character hit, and would collect the LARGEST bonus
## while the mech behind it was paid as though the grunt were not there. That reverses ruling 5
## ("targets resolve closest-first") and the card's "down the line", and a grunt screen is easy to
## walk into, so the author ruled the card wins: buff_blasting_powder.hit_index re-sorts by distance
## from the shot's origin before taking the index.
##
## This test is the proof, and it is the ONLY test in the file that can be: every other line in here
## stands mechs in a row, where engine order and distance order agree. Deleting the sort_custom from
## hit_index turns the three numbers below back into 12 / 13 / 14.
##
## THE GRUNT TEMPLATE IS APPENDED WITHOUT A full_repair(), on purpose and not as a dodge. The sort's
## only question is UnitPrinter.has_template(core, &'npct_grunt') (:477), which reads core.templates
## directly - so this unit is a grunt to every line of code under test. The template's 1 HP / 1
## structure override reaches a unit through core.bonus instead, and bonus is rebuilt only by
## UnitPrinter.recalculate_bonuses, which nothing in an attack calls. A genuinely 1-HP grunt would
## die to the shot and take the damage readout this test is built on with it.
func test_a_grunt_nearest_the_firer_is_still_paid_first() -> void:
	make_grunt(near)
	assert_true(UnitPrinter.has_template(near.core, &'npct_grunt'),
		'fixture: the nearest target is a grunt as far as the target sort is concerned.')
	assert_eq(near.get_health_max(), 200,
		'fixture: and still tough enough to survive the shot and report what it took.')

	cheat_every_die_to_six()
	await fire_at(FAR_TILE)

	assert_eq(near.current_damage(), BASE_DAMAGE,
		'The NEAREST character is paid first and takes +0, grunt or not. In raw engine order it'
		+ ' would be last and take +2.')
	assert_eq(mid.current_damage(), BASE_DAMAGE + 1,
		'The middle target is the 2nd character along the line: +1. In engine order it would be 1st,'
		+ ' at +0.')
	assert_eq(far.current_damage(), BASE_DAMAGE + 2,
		'And the far target is the 3rd: +2. In engine order it would be 2nd, at +1.')
	assert_eq(_uses(), 1, 'The attack spent the round like any other.')

	# The grunt's PLACE is what moved, not the size of the payout: the escalation is still exactly
	# +0/+1/+2 over three characters, so the ruling re-orders the line without making the trait
	# worth more or less against a screen than against three mechs.
	assert_eq(
		near.current_damage() + mid.current_damage() + far.current_damage(),
		(BASE_DAMAGE * 3) + 0 + 1 + 2,
		'Three characters still share exactly +0, +1 and +2 between them.')

## Ruling 5 again: the round is spent by an attack that hits at least one CHARACTER. A line that
## only broke some scenery has not used the trait up.
func test_a_line_that_hits_only_objects_leaves_the_round_unconsumed() -> void:
	set_entity_type([near, mid, far], Frame.ENTITY.OBJECT)

	cheat_every_die_to_six()
	await fire_at(FAR_TILE)

	assert_gt(near.current_damage(), RELIABLE_ON_MISS, 'Fixture: the shot hit the near object.')
	assert_gt(mid.current_damage(), RELIABLE_ON_MISS, 'Fixture: and the middle one.')
	assert_gt(far.current_damage(), RELIABLE_ON_MISS, 'Fixture: and the far one.')
	assert_eq(_uses(), 0, 'Hitting only objects did not spend the round.')

	# ...and the round is still there. full_repair() resets their damage, so absolute numbers again.
	set_entity_type([near, mid, far], Frame.ENTITY.CHARACTER)
	top_up_the_firer()
	cheat_every_die_to_six()
	await fire_again_at(FAR_TILE)

	assert_eq(mark_damage(), [BASE_DAMAGE, BASE_DAMAGE + 1, BASE_DAMAGE + 2],
		'The trait was still unspent and paid out in full.')
	assert_eq(_uses(), 1, 'And that attack spent it.')

# ---------------------------------------------------------------- display text

## The trait ships a name and an effect row, and they are in the COMPILED artifact rather than only
## in the csv beside it. Translate.add_translation_from_file globs the folder for *.translation and
## loads THOSE (engine/utils/translate.gd:200), and the artifact is only regenerated by an import -
## so an edited csv with a stale artifact renders every one of this trait's strings as its raw key,
## in a mod that is otherwise entirely green. Same guard, same reasoning, as test_bizarre_cannon.gd.
func test_the_trait_has_display_text() -> void:
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in ['gear.%s.name' % TRAIT_ID, 'gear.%s.effect' % TRAIT_ID]:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)

	# The hidden halves stay hidden: neither the bookkeeping reaction nor the buff is a thing the
	# player reads, so neither may acquire rule text of its own. A `trigger` row in particular would
	# drag the reaction back into the Kit tooltip through Action.show_in_tooltip's trigger clause
	# (action.gd:344), undoing the override in action_blasting_powder_spend.gd.
	for key:String in [
		'gear.%s.action_blasting_powder_spend.name' % TRAIT_ID,
		'gear.%s.trigger' % TRAIT_ID,
		'gear.buff_blasting_powder.name',
	]:
		assert_eq(translation.get_message(key), StringName(''),
			'%s is deliberately absent: that half of the trait is not player-facing.' % key)
