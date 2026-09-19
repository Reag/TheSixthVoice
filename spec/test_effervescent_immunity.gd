# EFFERVESCENT IMMUNITY - the passive half of MÖBIAN RAINBOW (Primrose SP1 Task 4).
#
#   "Each time a hostile character fails an attack against you, gain +1 EVASION for the rest of the
#    scene up to a maximum of +3."
#
# TWO BUFFS, because one cannot be both. buff_effervescent_immunity is a VISIBLE Buff.TO.STATBLOCK
# chip whose get_values computes an evasion bonus from its own state; buff_effervescent_immunity_counter
# is a HIDDEN ATTACK-POST observer that writes that state. Both are applied at scene start by the
# core Kit's PassiveBuffApplicator, and both are until = MANUAL: the card says "for the rest of the
# scene".
#
# MEASURED THROUGH unit.get_evasion(), which is core.get_evasion() + state.stat_bonus.evasion
# (unit.gd:306) - the accessor every reader of evasion actually uses. state.stat_bonus is rebuilt
# ONLY by update_cached_values (unit_battle_state.gd:229-234), which is why both scripts call
# unit.update_cached_values_and_token() after touching the state; the Goblin's
# buff_symbiosis_statblock.gd does the same in its on_application and is the vanilla precedent for a
# state-driven Statblock.
#
# THE CAP-5 AND OVERSHIELD CASES LIVE IN test_shimmering_shield.gd, not here (design 1.4's last two
# spec cases). They need buff_shimmering_shield, which Task 5 creates and Task 6 completes, and the
# cap change is Shimmering Shield's own card clause. Nothing is dropped.
#
# EVERY REPEAT SHOT FROM ONE SHOOTER TAKES A TURN BOUNDARY, and that is not tidiness - see fire()
# and fresh_turn() below. The brief this file was built from fired four shots inside one open turn;
# the engine silently refuses all but the first.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_effervescent_immunity.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')
const Immunity := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_primrose/cp_mobian_rainbow/buff_effervescent_immunity.gd')

const CORE_ID := &'cp_mobian_rainbow'
const CHIP_ID := &'buff_effervescent_immunity'
const COUNTER_ID := &'buff_effervescent_immunity_counter'

const BASE_EVASION := 8 ## the sheet's, pinned by test_primrose_frame.gd

const MAP_SIZE := Vector2i(15, 9)
const PRIMROSE_TILE := Vector2i(4, 4)
const ALLY_TILE := Vector2i(5, 4)      ## adjacent, so one Blast catches both
const HOSTILE_TILE := Vector2i(10, 4)  ## well inside a rifle's aim_range 10 and clear of everyone
const SECOND_HOSTILE := Vector2i(10, 6)

var game:Gamemaster
var primrose:Unit
var hostile:Unit

func before_each() -> void:
	game = PrimroseFixture.create_game(self, MAP_SIZE)
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	hostile = PrimroseFixture.create_hostile(game, HOSTILE_TILE)
	PrimroseFixture.equip_main_rifle(hostile)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## Queue exactly these d20s, then a tail of sixes so nothing downstream drains the FIFO into real
## RNG. Needed here rather than the fixture's cheat_a_hit/miss because an AoE rolls a SEPARATE d20
## per attacked unit (event_unit_attack_declared.gd:54-64) and this file has to control each one.
##
## THE TWO d20s REALLY DO COME OUT FIRST, which is what makes a two-element array meaningful:
## event_unit_attack only appends its roll to the declared summary ("so it can parse out damage in a
## minute", event_unit_attack.gd:62-63) and the whole volley's damage is rolled once, afterwards, back
## in event_unit_attack_declared (:74-89). So no damage die is drawn between the two attack rolls.
func cheat_rolls(d20s:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 40: buffer.append(6)
	Dice.cheat_attack(d20s, buffer)

func chip() -> BuffCore:
	return UnitCondition.get_buff(primrose, CHIP_ID)

func stacks() -> int:
	return Immunity.stacks_on(primrose)

func bonus() -> int:
	return primrose.get_evasion() - BASE_EVASION

## Fire a weapon the shooter already carries, and PROVE the shot actually happened.
##
## THE VACUITY GUARD IS THE WHOLE POINT OF THIS WRAPPER. A second activation of one weapon inside one
## open turn is refused by the repeat-action rule - action.gd:161-163 returns a soft limit of 1 for
## anything that is not a free action, and unit_action.gd:168 is the gate - and the refusal is
## SILENT: event_gear_activate.check_specific_context just returns false, no `Gear not available`
## line is printed for it, and the caller's await returns normally. Without this assert, every
## "and nothing more happened" case in this file would pass for the boring reason.
##
## THE READ IS THE CHEAT QUEUE, because it is the one thing every attack touches whatever its
## outcome: an attack roll pops at least its d20 (dice.gd:32-35), a miss included, so a queue that
## did not shrink means no roll was made. current_damage() cannot serve - the shots this file cares
## about are misses.
func fire(shooter:Unit, weapon_id:StringName, target:Unit) -> void:
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await PrimroseFixture.attack(game, shooter, weapon_id, target)
	assert_lt(Dice.CHEAT_ROLL_QUEUE.size(), queued,
		'fixture: the shot really rolled - the cheat queue was drained.')

## End the shooter's turn and open a fresh one, so it may fire the same weapon again.
##
## PrimroseFixture.attack opens the shooter's turn only when it is not already open
## (fitzgerald_fixture.gd:125), so two calls in a row leave ONE turn open and the second shot hits the
## repeat-action rule above. A turn start is what clears it: event_turn_start.gd:42-44 runs
## UnitAction.every_new_turn_refresh over every unit on the map, and that calls reset_per_turn_usage
## (unit_action.gd:69).
##
## CALLED BEFORE THE NEXT cheat_* CALL, never after: event_turn_start.gd:89-90 rolls a d6 per
## un-recharged piece of gear, and those rolls come out of the same global cheat queue.
##
## ONLY EVER ON THE ATTACKER. Only the STARTING unit's passive-gear buffs are re-applied
## (event_turn_start.gd:99 sits inside handle_starting_unit, which is called for that unit and its
## deployables), so a hostile's turn boundary cannot touch the Primrose's chip - which is what keeps
## test_the_bonus_survives_the_turn_boundary the only test in this file that can see
## reapply_at_the_start_of_each_turn.
func fresh_turn(shooter:Unit) -> void:
	await SpecFactory.end_turn(game, shooter)
	await SpecFactory.start_turn(game, shooter)

## A hostile rifle shot that misses, fired at whoever is named.
func miss_at(shooter:Unit, target:Unit) -> void:
	PrimroseFixture.cheat_a_miss()
	await fire(shooter, PrimroseFixture.MAIN_RIFLE, target)

# ---------------------------------------------------------------- wiring and text

func test_the_core_kit_is_wired():
	var kit:Kit = ContentLibrary.get_kit(CORE_ID)
	assert_true(Kit.is_valid(kit), '%s is in the kits index.' % CORE_ID)
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'A frame trait, not equippable gear: it costs no SP and cannot be '
		+ 'unequipped. cp_broadside, cp_siege_engine and cp_quietus_machines are the same.')
	assert_eq(kit.actions.size(), 0, 'No actions yet - Task 5 appends GLIMMERING ARMAMENTS.')
	assert_eq(kit.passives.size(), 1, 'Exactly one passive.')
	var applicator = kit.passives[0]
	assert_true(applicator is PassiveBuffApplicator, 'Which is a PassiveBuffApplicator.')
	if applicator is not PassiveBuffApplicator: return
	assert_eq(applicator.applied_buffs.size(), 2, 'Applying BOTH halves of the passive at scene start.')
	assert_true(applicator.apply_at_the_start_of_combat, 'At the start of combat.')
	# THE DECISION, PINNED. See the plan's note: event_turn_start.gd:99 re-applies every listed buff
	# with reapply true, and UnitCondition.apply_buff builds a FRESH BuffCore with an empty state and
	# clears the old one (unit_condition.gd:740-747) - which would zero the counter every turn. The
	# other two Primrose traits correctly set it TRUE; their buffs carry no state.
	assert_false(applicator.reapply_at_the_start_of_each_turn,
		'And NEVER re-applied at a turn start: the counter lives in buff state, and a re-application '
		+ 'would silently reset "for the rest of the scene" every turn.')

	assert_true(UnitCondition.has_buff(primrose, CHIP_ID), 'The Primrose is wearing the chip.')
	assert_true(UnitCondition.has_buff(primrose, COUNTER_ID), 'And the hidden counter.')
	assert_eq(UnitCondition.get_buffs(primrose, CHIP_ID).size(), 1, 'Exactly one chip, not two.')

	var chip_buff:Buff = ContentLibrary.get_buff(CHIP_ID)
	assert_not_null(chip_buff, '%s is in the buffs index.' % CHIP_ID)
	if chip_buff == null: return
	assert_eq(chip_buff.to, Buff.TO.STATBLOCK, 'The chip is a STATBLOCK buff (ruling 21).')
	assert_eq(chip_buff.until, Lancer.UNTIL.MANUAL, 'For the rest of the scene.')
	assert_false(chip_buff.hide_from_player, 'VISIBLE: the number on it is the whole point.')

	var counter_buff:Buff = ContentLibrary.get_buff(COUNTER_ID)
	assert_not_null(counter_buff, '%s is in the buffs index.' % COUNTER_ID)
	if counter_buff == null: return
	assert_eq(counter_buff.to, Buff.TO.NONE, 'The counter modifies nothing itself.')
	assert_eq(counter_buff.until, Lancer.UNTIL.MANUAL, 'And also lasts the scene.')
	assert_true(counter_buff.hide_from_player, 'And is hidden - one chip carrying a number, not two.')
	assert_eq(counter_buff.triggers_on, [&'attack'] as Array[StringName], 'It watches attacks.')
	assert_eq(counter_buff.trigger_timing, ReactionBus.TIMING.POST,
		'At POST, which is the only timing that carries the roll\'s outcome (event_unit_attack.gd:123).')

func test_the_rows_resolve_and_the_chip_has_its_own_card():
	for key:String in ['gear.cp_mobian_rainbow.name', 'gear.cp_mobian_rainbow.flavor',
			'gear.cp_mobian_rainbow.effect',
			'gear.buff_effervescent_immunity.name', 'gear.buff_effervescent_immunity.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

	# THE CHIP MUST HAVE ROWS OF ITS OWN, and this is the guard (memory lancer-tactics-buff-card-
	# fallback). Translate.buff falls through to the owner Kit's FIRST ACTION (translate.gd:73-76) and
	# then to the Kit's own rows - and from Task 5 this Kit's first action is GLIMMERING ARMAMENTS, so
	# a chip with no rows would render the PROTOCOL's card on the Primrose's own status bar. The
	# fallback SUCCEEDS, so no tr()-resolution guard would ever fire; only this comparison does.
	var core:BuffCore = chip()
	assert_not_null(core, 'fixture: the chip is on the unit.')
	if core == null: return
	assert_eq(core.name_text(), X.tr('gear.buff_effervescent_immunity.name'),
		'The chip is titled off its OWN name row.')
	assert_ne(core.name_text(), X.tr('gear.cp_mobian_rainbow.name'),
		'And not off the core Kit\'s, which is what the fallback would give it.')

# ---------------------------------------------------------------- what counts

func test_one_hostile_miss_raises_evasion_by_one():
	assert_eq(bonus(), 0, 'fixture: no bonus before anything happens.')
	await miss_at(hostile, primrose)
	assert_eq(stacks(), 1, 'One miss, one stack.')
	assert_eq(bonus(), 1, 'And +1 EVASION, read through the accessor the engine reads.')

func test_three_misses_reach_plus_three_and_a_fourth_changes_nothing():
	# THE CAP. Four misses, and a turn boundary on the HOSTILE between each - see fresh_turn(): the
	# repeat-action rule refuses a second shot from one weapon inside one open turn, and refuses it
	# silently. Nothing in this trait is per-round or per-turn, and only the STARTING unit's passive
	# buffs are re-applied, so a boundary on the attacker cannot reset anything the Primrose carries.
	for i:int in 4:
		if i > 0: await fresh_turn(hostile)
		await miss_at(hostile, primrose)
	assert_eq(stacks(), 3, 'The counter stops at three.')
	assert_eq(bonus(), 3, 'And so does the bonus - the card\'s maximum of +3.')

func test_a_hit_changes_nothing():
	# THE POSITIVE CONTROL IS IN THE SAME TEST: the same shooter, the same weapon, one that misses.
	# Without it "the hit raised nothing" would be satisfied by a wholly dead trait.
	PrimroseFixture.cheat_a_hit()
	await fire(hostile, PrimroseFixture.MAIN_RIFLE, primrose)
	assert_gt(primrose.current_damage(), 0, 'fixture: the shot landed.')
	assert_eq(bonus(), 0, 'A HIT is not a failed attack.')

	await fresh_turn(hostile)
	await miss_at(hostile, primrose)
	assert_eq(bonus(), 1, 'CONTROL: the same shooter missing does raise it.')

func test_an_allys_miss_changes_nothing():
	# "a HOSTILE character". An ally shooting at the Primrose and missing is the friendly-fire case.
	var ally:Unit = PrimroseFixture.create_ally(game, ALLY_TILE)
	PrimroseFixture.equip_main_rifle(ally)

	await miss_at(ally, primrose)

	assert_eq(bonus(), 0, 'An ALLY missing buys the Primrose nothing.')
	await SpecFactory.end_turn(game, ally)
	await miss_at(hostile, primrose)
	assert_eq(bonus(), 1, 'CONTROL: a hostile missing does.')

func test_a_miss_by_the_primrose_itself_counts_for_nothing():
	# The other direction: the Primrose's own missed shot buys it nothing.
	#
	# THIS TEST DOES NOT PIN `context.target_unit == holder`, and the record is here so nobody chases
	# it again. Measured 2026-09-19 (Task 4 mutation 3): neutralising that clause leaves this test
	# GREEN and reddens test_a_blast_that_catches_the_primrose_counts_exactly_once alone. The case is
	# OVER-DETERMINED - when the Primrose shoots someone else, `attacker == unit` and
	# `are_enemies(unit, attacker)` each refuse it on their own, before target_unit is ever the
	# deciding term. The blast test is what actually pins the clause, because there the Primrose IS
	# one of several attacked units and only target_unit can tell its roll from the ally's.
	# What this test does pin is the OUTCOME, which is worth a test of its own whichever clause
	# delivers it.
	PrimroseFixture.equip_main_rifle(primrose)
	PrimroseFixture.cheat_a_miss()
	await fire(primrose, PrimroseFixture.MAIN_RIFLE, hostile)

	assert_eq(bonus(), 0, 'The Primrose missing somebody else is not an attack against the Primrose.')

	# THE POSITIVE CONTROL, and this file's own house rule: a "nothing happened" assertion needs a
	# neighbour that makes something happen, or a dead trait satisfies it. The Primrose's turn is
	# ended first so only one unit is ever mid-turn - and it is never STARTED again here, so this test
	# still cannot see reapply_at_the_start_of_each_turn.
	await SpecFactory.end_turn(game, primrose)
	await miss_at(hostile, primrose)
	assert_eq(bonus(), 1, 'CONTROL: a hostile missing the Primrose does raise it.')

func test_a_missed_tech_attack_counts():
	# Ruling 6: "every attack roll, WEAPON OR TECH". Both go through event_unit_attack
	# (event_unit_attack.gd:40 takes context.action as ActionAttack), so this needs no clause in the
	# gate - and this test is what proves the gate did not grow one by accident.
	#
	# ms_fragment_signal needs no equipping: it is in every mech's basic loadout and its single action
	# is an ActionAttackTech, rolled against E-Defence rather than Evasion.
	var tech:GearCore = hostile.get_gear(PrimroseFixture.TECH_ID)
	assert_true(GearCore.is_valid(tech), 'fixture: every mech carries ms_fragment_signal.')
	if not GearCore.is_valid(tech): return
	assert_true(tech.get_solo_action() is ActionAttackTech, 'fixture: and its action is a tech attack.')

	PrimroseFixture.cheat_a_miss()
	await fire(hostile, PrimroseFixture.TECH_ID, primrose)

	assert_eq(bonus(), 1, 'A missed TECH attack counts exactly as a missed weapon attack does.')

func test_a_blast_that_catches_the_primrose_counts_exactly_once():
	# Ruling 6's "each roll of an AoE separately", from the Primrose's side: one shot, two attacked
	# units, two SEPARATE event_unit_attack events (event_unit_attack_declared.gd:54-64 queues one per
	# unit in all_attacked_units) - and only the one whose target_unit is the Primrose can count.
	#
	# TWO SHOTS, and the first is the precondition. An all-hitting volley proves BOTH units really are
	# in the blast - without it, "exactly one stack" would be satisfied by a blast that only ever
	# reached the Primrose - and proves in passing that hits raise nothing.
	#
	# THE DESIGN'S WORDING IS "misses the Primrose and HITS an ally". Pinning which of the two rolls
	# resolves first would make this test a hostage to all_attacked_units ordering, which is
	# aoe_calculator's business and not this trait's; the ally's outcome being irrelevant is pinned by
	# test_an_allys_miss_changes_nothing instead. Both halves of the design case are covered, in two
	# places, with no ordering assumption.
	var ally:Unit = PrimroseFixture.create_ally(game, ALLY_TILE)
	PrimroseFixture.equip(hostile, PrimroseFixture.BLAST_LAUNCHER)

	cheat_rolls([19, 19])
	await fire(hostile, PrimroseFixture.BLAST_LAUNCHER, ally)
	assert_gt(ally.current_damage(), 0, 'fixture: the blast reached the ally.')
	assert_gt(primrose.current_damage(), 0, 'fixture: and the Primrose beside it.')
	assert_eq(bonus(), 0, 'Two hits raise nothing.')

	# A NEW TURN AND A RELOAD, because the RPG is both `loading` and `ordnance`
	# (mw_rocket_propelled_grenade.tres). unit_action.gd:276 empties it on use and :151 refuses an
	# unloaded weapon - a refusal AS_FREEBIE does not lift, unlike the ordnance-phase one at :146 -
	# while the ordnance phase itself is re-opened only by a turn start (event_turn_start.gd:83).
	# event_gear_reload.gd:28 is the entire substance of a reload, one assignment, so doing it here by
	# hand is the reload action and nothing more.
	await fresh_turn(hostile)
	var launcher:GearCore = hostile.get_gear(PrimroseFixture.BLAST_LAUNCHER)
	assert_true(GearCore.is_valid(launcher), 'fixture: the launcher is still equipped.')
	if GearCore.is_valid(launcher): launcher.is_loaded = true

	cheat_rolls([1, 1])
	await fire(hostile, PrimroseFixture.BLAST_LAUNCHER, ally)

	assert_eq(stacks(), 1,
		'One blast that catches the Primrose is ONE failed attack against it, however many units it hit.')

# ---------------------------------------------------------------- lifetime

func test_the_bonus_survives_the_turn_boundary():
	# "FOR THE REST OF THE SCENE", and this is the ONLY test in the suite that would notice
	# reapply_at_the_start_of_each_turn being true on the core Kit's applicator: it is the only one
	# that ever starts the PRIMROSE's turn after a stack has been earned. event_turn_start.gd:99
	# re-applies every listed buff with reapply = true, and UnitCondition.apply_buff builds a FRESH
	# BuffCore with an empty state dictionary and clears the old one (unit_condition.gd:740-747).
	await miss_at(hostile, primrose)
	await fresh_turn(hostile)
	await miss_at(hostile, primrose)
	assert_eq(stacks(), 2, 'fixture: two misses, two stacks.')

	await SpecFactory.end_turn(game, hostile)
	await SpecFactory.start_turn(game, primrose)
	await SpecFactory.end_turn(game, primrose)
	await SpecFactory.start_turn(game, hostile)

	assert_eq(stacks(), 2, 'Two full turn starts later, the counter is untouched.')
	assert_eq(bonus(), 2, 'And so is the bonus.')
	assert_eq(UnitCondition.get_buffs(primrose, CHIP_ID).size(), 1,
		'And there is still exactly ONE chip - not a fresh one stacked beside the old.')

func test_the_counter_buff_survives_its_own_activation():
	# Buff.activate's DEFAULT body clears the buff off the unit (buff.gd:254-255), so the counter must
	# NOT call super - it has to survive every miss for the whole scene. Without this test, a counter
	# that called super would pass test_one_hostile_miss_raises_evasion_by_one and fail every other
	# case for a reason nobody would attribute to the missing override.
	await miss_at(hostile, primrose)
	assert_true(UnitCondition.has_buff(primrose, COUNTER_ID),
		'The counter is still on the unit after firing once.')
	await fresh_turn(hostile)
	await miss_at(hostile, primrose)
	assert_eq(stacks(), 2, 'And it fires again: two misses, two stacks.')

func test_two_hostiles_share_one_counter():
	# The counter is per-PRIMROSE, not per-attacker: "each time a hostile character fails an attack",
	# from anyone. Two shooters, one running total.
	var second:Unit = PrimroseFixture.create_hostile(game, SECOND_HOSTILE)
	PrimroseFixture.equip_main_rifle(second)

	await miss_at(hostile, primrose)
	await SpecFactory.end_turn(game, hostile)
	await miss_at(second, primrose)

	assert_eq(stacks(), 2, 'Two different hostiles, two stacks on one counter.')
	assert_eq(bonus(), 2, 'And +2 EVASION.')
