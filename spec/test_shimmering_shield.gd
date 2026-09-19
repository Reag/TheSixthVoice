# SHIMMERING SHIELD - the second of GLIMMERING ARMAMENTS' two effects (Primrose SP1 Task 6).
#
#   "While you are in cover, melee attacks against you receive +1 Difficulty. Additionally,
#    Effervescent Immunity can stack up to a maximum of +5. If it would increase past this point, you
#    instead gain 1d3 OVERSHIELD."
#
# TWO CLAUSES, TWO MECHANISMS. The difficulty is buff_shimmering_shield_cover, a hidden BuffBonus
# subclass on the ATTACK_ROLL_INCOMING channel whose gate computes cover ITSELF. The cap is read by
# buff_effervescent_immunity.cap_for, which asks whether the holder carries the marker - so the whole
# of the second clause is three lines in Task 4's file plus the marker Task 5 applies.
#
# THE GATE COMPUTES COVER ITSELF, AND IT HAS TO, FOR TWO SEPARATE REASONS:
#  1. Incoming-roll buffs are queried BEFORE cover (attack_roll.gd:135 against :158), so the roll's
#     own answer does not exist yet when this buff is asked.
#  2. A MELEE ATTACK AT THREAT NEVER COMPUTES COVER AT ALL. ActionAttackWeapon.ignores_cover returns
#     true for a melee weapon with threat > 0 (action_attack_weapon.gd:206-212), and attack_roll.gd:
#     153-158 skips the entire cover block when it does. So the roll carries NO cover line for exactly
#     the attacks this card is about - which is what makes the card worth printing, and which
#     CORRECTS design 1.5's expected -2 to -1. test_the_engine_itself_gives_a_melee_attack_at_threat_
#     no_cover_line is the measurement, kept as a characterisation test so a future engine change
#     would surface here rather than as a mystery in the totals.
#
# MEASURED OFF THE ROLL'S OWN BREAKDOWN, not off a hit or a damage number: AttackRoll.PreAttack.create
# folds an ATTACK_ROLL_INCOMING accuracy value into a named AccuracyMod (attack_roll.gd:182-189), and
# counting the line TITLED WITH THIS CHIP'S NAME is the only way to say "this trait did it" rather
# than "the total happened to be -1". test_gravity_well.gd's preview()/lines() pair is the idiom.
#
# WHAT THE HAND-BUILT CONTEXT MUST CARRY for PreAttack.create to reach this buff, read off
# attack_roll.gd:115-135: context.target_unit (the defender, which is who the ATTACK_ROLL_INCOMING
# query is run against at :135), context.unit (the attacker or relay), context.gear and
# context.action (which BuffWeaponType-shaped gates and our own both demand), and OPTIONALLY
# context.resource - a DeclaredAttackSummary, whose source_voxels are passed to determine_cover at
# :158. With no resource the voxel list is empty and CoverCalculator falls back to the attacker's own
# occupied voxels (cover_calculator.gd:47-49), which is the same answer for every case in this file.
# SpecificAction.to_context() supplies the first four, and Context.create fills `map` from the
# attacker (context.gd:77-79) - Context.clone then copies it (:85). (test_gravity_well.gd's header
# says this context "carries no map"; that is wrong on the 1.4.3 source and is recorded as a finding.)
#
# COVER IS LAID AS SOFT-COVER GROUND rather than geometry, and that is not laziness: CoverCalculator
# ignores intervening voxels within distance 1 of the attacker when it can see the target
# (cover_calculator.gd:145-147), so a melee attacker AT THREAT can essentially never be given
# geometric cover to shoot through. The zone branch at :78-83 - every occupied tile is soft-cover
# ground - is deterministic at any range and is the only route that works for both the melee and the
# ranged cases in one fixture.
#
# EVERY REPEAT SHOT FROM ONE SHOOTER TAKES A TURN BOUNDARY, and that is not tidiness - see fire() and
# fresh_turn() below, copied from test_effervescent_immunity.gd. The brief this file was built from
# fired five shots inside one open turn; the engine silently refuses all but the first.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_shimmering_shield.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')
const Immunity := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_primrose/cp_mobian_rainbow/buff_effervescent_immunity.gd')

const MARKER := &'buff_shimmering_shield'
const COVER_CHIP := &'buff_shimmering_shield_cover'
const CHIP_NAME_KEY := 'gear.buff_shimmering_shield.name'
const IMMUNITY_CHIP := &'buff_effervescent_immunity' ## the counter's visible chip, read for its card text

## Vanilla SSC Markerlight's chip: to = &"ignore_cover", and its own gate asks that the context's
## category is SOFT cover and that the holder is the defender
## (content/gear/ssc/systems/ms_markerlight/buff_markerlight_no_cover.gd:8-14).
const MARKERLIGHT := &'buff_markerlight_no_cover'

const BASE_EVASION := 8

const MAP_SIZE := Vector2i(15, 9)
const PRIMROSE_TILE := Vector2i(4, 4)
const ADJACENT := Vector2i(5, 4)      ## inside threat for every melee weapon here
const SHOOTER_TILE := Vector2i(10, 4) ## inside a rifle's aim_range 10, far from anybody's cover
const SECOND_PRIMROSE := Vector2i(4, 6)

var game:Gamemaster
var responder
var primrose:Unit
var brawler:Unit  ## a hostile standing in threat, for the melee cases
var shooter:Unit  ## a hostile at range, for the ranged control

## Has the shooter already fired this test? Read by miss() / miss_then_d3() to decide whether a turn
## boundary is needed first. See fresh_turn().
var shooter_has_fired := false

func before_each() -> void:
	var pair := PrimroseFixture.create_game_with_prompts(self, MAP_SIZE)
	game = pair[0]
	responder = pair[1]
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	brawler = PrimroseFixture.create_hostile(game, ADJACENT)
	shooter = PrimroseFixture.create_hostile(game, SHOOTER_TILE)
	PrimroseFixture.equip_heavy_melee(brawler)
	PrimroseFixture.equip_main_rifle(shooter)
	shooter_has_fired = false

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

## Make exactly `tiles` soft-cover ground, and everything else clean.
##
## LOCAL TO THIS FILE, not on PrimroseFixture: it is the only spec in the sub-project that needs
## terrain at all, and the fixture's surface is frozen. VaubanFixture.lay_difficult is the shape, and
## its header carries the correction this copies: SpecFactory.set_terrain writes map.ground_terrain,
## which calculate_surface_merged_terrain_and_height_at never reads - only ground_surface_terrain and
## the dynamic layer reach the surface (map_state.gd:474-478). Writes the WHOLE map, so calling it
## twice REPLACES rather than adds.
func lay_soft_cover(tiles:Array[Vector2i]) -> void:
	var block := TerrainBlockData.new()
	block.cover = TerrainData.COVER.SOFT
	for y:int in game.map.size.y:
		for x:int in game.map.size.x:
			var tile := Vector2i(x, y)
			game.map.ground_surface_terrain[tile] = block if tile in tiles else TerrainBlockData.BLANK
			game.map.calculate_surface_merged_terrain_and_height_at(tile)

func cover_the_primrose() -> void:
	lay_soft_cover([PRIMROSE_TILE])
	assert_eq(CoverCalculator.determine_cover(primrose, shooter).total, Lancer.COVER.SOFT,
		'fixture: the Primrose really is in soft cover.')

func raise_shield() -> void:
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.SHIELD_INDEX)
	assert_true(UnitCondition.has_buff(primrose, MARKER), 'fixture: the marker landed.')

## What a roll by `attacker` with `weapon_id` against the Primrose would compute right now.
func preview(attacker:Unit, weapon_id:StringName) -> AttackRoll.PreAttack:
	var specific := PrimroseFixture.specific(attacker, weapon_id)
	return AttackRoll.PreAttack.create(Context.clone(specific.to_context(), {target_unit = primrose}))

## The same, for an arbitrary SpecificAction - used for the thrown variant.
func preview_specific(specific:SpecificAction) -> AttackRoll.PreAttack:
	return AttackRoll.PreAttack.create(Context.clone(specific.to_context(), {target_unit = primrose}))

## How many of the roll's breakdown lines are THIS CHIP'S. Read off the mod list rather than the
## total, for test_hybridized_shot's reason: the total is the sum of every accuracy source on the
## roll, so a test watching only the total would be measuring the map as much as the trait. The title
## is buff_core.name_text(), which is what attack_roll.gd:189 puts on the line.
func shield_lines(pre:AttackRoll.PreAttack) -> int:
	var count := 0
	for mod:AttackRoll.AccuracyMod in pre.accuracy_mods:
		if mod.title_key == X.tr(CHIP_NAME_KEY) and mod.mod == -1: count += 1
	return count

## How many VANILLA COVER lines the roll carries. attack_roll.gd:169 titles a cover line with
## Lancer.cover_name(cover), which is a RAW KEY ('lancer.cover.soft') and not a translation - so this
## compares against the key, deliberately, and not against X.tr of it.
func cover_lines(pre:AttackRoll.PreAttack) -> int:
	var count := 0
	for mod:AttackRoll.AccuracyMod in pre.accuracy_mods:
		if mod.title_key == Lancer.cover_name(Lancer.COVER.SOFT): count += 1
	return count

func bonus() -> int:
	return primrose.get_evasion() - BASE_EVASION

## End the shooter's turn and open a fresh one, so it may fire the same weapon again.
##
## PrimroseFixture.attack opens the shooter's turn only when it is not already open
## (fitzgerald_fixture.gd:124-125), so two calls in a row leave ONE turn open and the second shot hits
## the per-turn soft limit (action.gd:161-163, gated at unit_action.gd:168) - which refuses SILENTLY:
## no `Gear not available` line, only `[ ABORT event_gear_activate ] ... specific: invalid`, and the
## caller's await returns normally. A turn start is what clears it: event_turn_start.gd:42-44 runs
## UnitAction.every_new_turn_refresh over every unit, and that calls reset_per_turn_usage.
##
## CALLED BEFORE THE NEXT cheat_* CALL, never after: event_turn_start.gd:89-90 rolls a d6 per
## un-recharged piece of gear, and those rolls come out of the same global cheat queue - which would
## eat the queued 1 and the queued d3 in miss_then_d3().
##
## ONLY EVER ON THE SHOOTER. Only the STARTING unit's passive-gear buffs are re-applied
## (event_turn_start.gd:99 sits inside handle_starting_unit), and the Primrose's counter is
## until = MANUAL with its cap re-read on every miss, so a hostile's turn boundary cannot disturb
## anything these tests measure.
func fresh_turn(unit:Unit) -> void:
	await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

## Fire a weapon the shooter already carries, and PROVE the shot actually happened.
##
## THE VACUITY GUARD IS THE WHOLE POINT OF THIS WRAPPER (test_effervescent_immunity.gd's fire(),
## verbatim). Without it every "reach +5" assertion below would pass for the boring reason: a silently
## refused second activation leaves the counter exactly where the first shot put it.
##
## THE READ IS THE CHEAT QUEUE, because it is the one thing every attack touches whatever its
## outcome: an attack roll pops at least its d20 (dice.gd:32-35), a miss included, so a queue that did
## not shrink means no roll was made. current_damage() cannot serve - every shot here is a miss.
func fire(attacker:Unit, weapon_id:StringName, target:Unit) -> void:
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await PrimroseFixture.attack(game, attacker, weapon_id, target)
	assert_lt(Dice.CHEAT_ROLL_QUEUE.size(), queued,
		'fixture: the shot really rolled - the cheat queue was drained.')

## A hostile rifle shot at the Primrose that misses. Used for the cap cases.
func miss() -> void:
	if shooter_has_fired: await fresh_turn(shooter)
	shooter_has_fired = true
	PrimroseFixture.cheat_a_miss()
	await fire(shooter, PrimroseFixture.MAIN_RIFLE, primrose)

## A miss whose FOLLOWING die - the overflow's 1d3 - is pinned to `d3`.
##
## A TECH ATTACK, NOT THE RIFLE, AND THAT IS A MEASURED CORRECTION TO THIS TASK'S BRIEF. The brief's
## miss_then_d3 fired mw_assault_rifle, which is RELIABLE 2: a Lancer Reliable weapon deals its flat
## damage even on a MISS, and event_unit_attack_declared applies it AFTER the ATTACK/POST reactions
## have already granted the Overshield. Measured in this task's RED run: the overflow granted exactly
## the cheated 3 ("now has 3 overshield"), then the same shot's Reliable 2 landed, was reduced to 1 by
## the Primrose's armor 1, and ATE one point of it - so the assertion read 2. The second clause of
## ruling 7 ("a lower roll leaves a higher Overshield unchanged") is not merely off by one under that
## confound, it is untestable: every further shot removes another point, so nothing can ever be
## "unchanged". The Primrose also has health 8, and eight Reliable misses would kill it mid-test.
##
## ms_fragment_signal is a vanilla ActionAttackTech in EVERY mech's basic loadout with no damage value
## at all, so a missed tech attack touches neither hit points nor Overshield - and ruling 6 already
## counts it: "every attack roll, WEAPON OR TECH" goes through the one event_unit_attack, which is
## what test_effervescent_immunity.test_a_missed_tech_attack_counts pins, from the same tile at the
## same distance. miss() keeps the rifle, where the Reliable point is harmless.
##
## Only two values are queued and both are drawn: nothing in these tests puts an accuracy modifier on
## the roll, so Dice.roll_d6_accuracy(0) returns 0 without rolling (dice.gd:86-88), and a tech attack
## rolls no damage.
##
## THE TURN BOUNDARY COMES FIRST AND THE CHEAT SECOND. A turn start rolls recharge d6s off the same
## global queue, so cheating before the cycle would feed the queued 1 and d3 to the recharge rolls.
func miss_then_d3(d3:int) -> void:
	if shooter_has_fired: await fresh_turn(shooter)
	shooter_has_fired = true
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([1], [d3])
	await fire(shooter, PrimroseFixture.TECH_ID, primrose)

# ---------------------------------------------------------------- wiring and text

func test_the_shield_bundle_is_wired():
	var marker:Buff = ContentLibrary.get_buff(MARKER)
	assert_not_null(marker, '%s is in the buffs index.' % MARKER)
	if marker == null: return
	assert_eq(marker.until, Lancer.UNTIL.MANUAL, 'The marker lasts the scene.')
	assert_false(marker.hide_from_player, 'And is visible.')

	var chip:Buff = ContentLibrary.get_buff(COVER_CHIP)
	assert_not_null(chip, '%s is in the buffs index.' % COVER_CHIP)
	if chip == null: return
	assert_true(chip is BuffBonus, 'The cover half is a BuffBonus subclass.')
	assert_eq(chip.to, Buff.TO.ATTACK_ROLL_INCOMING, 'It modifies attacks made AGAINST its holder.')
	assert_eq(chip.bonus_subtype, Buff.BONUS_SUBTYPE.ACCURACY,
		'By ACCURACY - "+1 Difficulty" in Lancer is a difficulty DIE, not a -1 to the total.')
	assert_eq(chip.bonus_value, -1, 'Minus one.')
	assert_false(chip.is_onetime, 'And it is not consumed: it applies to EVERY qualifying attack.')
	assert_eq(chip.until, Lancer.UNTIL.MANUAL, 'For the rest of the scene, like its marker.')
	assert_true(chip.hide_from_player,
		'HIDDEN: the marker is the chip the player reads, and two chips for one effect would read as '
		+ 'two effects. It still needs an icon, which is why it is in HIDDEN_BUFFS_NEEDING_ICONS.')
	assert_eq(chip.localization_key_override, 'buff_shimmering_shield',
		'It borrows the marker\'s rows, so the roll breakdown line reads "Shimmering Shield".')

func test_the_rows_resolve_and_the_breakdown_line_reads_like_the_card():
	await raise_shield()
	var cores:Array[BuffCore] = UnitCondition.get_buffs(primrose, COVER_CHIP)
	assert_eq(cores.size(), 1, 'The Primrose is wearing exactly one cover chip.')
	if cores.is_empty(): return
	# THE LOCALIZATION OVERRIDE IS WHAT PUTS A READABLE WORD ON THE ROLL. Translate.buff prepends
	# 'gear' to a bare override (translate.gd:50-52), so this resolves gear.buff_shimmering_shield.name
	# - the marker's own row, one string in one place. Without it the chip would fall through to the
	# owner Kit's first action and the breakdown would read "GLIMMERING ARMAMENTS".
	assert_eq(cores[0].name_text(), X.tr(CHIP_NAME_KEY),
		'And it is titled "Shimmering Shield", off the marker\'s name row.')
	assert_ne(cores[0].name_text(), X.tr('gear.cp_mobian_rainbow.action_glimmering_armaments.name'),
		'Not the protocol\'s name, which is what the fallback would give it.')

func test_the_protocol_applies_both_halves_of_the_shield():
	await raise_shield()
	assert_true(UnitCondition.has_buff(primrose, MARKER), 'The visible marker.')
	assert_true(UnitCondition.has_buff(primrose, COVER_CHIP), 'And the hidden cover chip.')
	assert_false(UnitCondition.has_buff(primrose, PrimroseFixture.WORMHOLE_GRASP),
		'And not a trace of the other armament.')

# ---------------------------------------------------------------- the difficulty

func test_a_melee_attack_at_threat_on_a_covered_primrose_is_at_one_difficulty():
	cover_the_primrose()
	assert_eq(shield_lines(preview(brawler, PrimroseFixture.HEAVY_MELEE)), 0,
		'CONTROL: no marker, no line.')

	await raise_shield()

	var pre := preview(brawler, PrimroseFixture.HEAVY_MELEE)
	assert_eq(shield_lines(pre), 1, 'One Shimmering Shield line of -1 on the incoming roll.')
	# THE CORRECTED TOTAL. Design 1.5 expected -2; a melee attack at threat carries NO cover line at
	# all (see the file header and the test below), so the shield's -1 is the whole of it.
	assert_eq(pre.accuracy_mods_total(), -1, 'And it is the ONLY modifier on the roll: -1, not -2.')

func test_the_engine_itself_gives_a_melee_attack_at_threat_no_cover_line():
	# A CHARACTERISATION TEST, not a pin of this trait - and it is the measurement that corrected the
	# design. ActionAttackWeapon.ignores_cover returns true for a melee weapon with threat > 0
	# (action_attack_weapon.gd:206-212) and attack_roll.gd:153-158 skips the whole cover block when it
	# does. So cover has never applied to a melee attack at threat in this engine, which is exactly why
	# the card is worth printing. No mutation of any Primrose file reddens this; it is kept because an
	# engine change here would otherwise surface as a mystery in the totals of the test above.
	cover_the_primrose()

	var melee := preview(brawler, PrimroseFixture.HEAVY_MELEE)
	assert_eq(melee.cover, Lancer.COVER.NONE, 'The roll records NO cover for a melee attack at threat.')
	assert_eq(cover_lines(melee), 0, 'And draws no cover line.')

	var ranged := preview(shooter, PrimroseFixture.MAIN_RIFLE)
	assert_eq(ranged.cover, Lancer.COVER.SOFT, 'CONTROL: the same ground DOES give a rifle soft cover.')
	assert_eq(cover_lines(ranged), 1, 'And draws one cover line.')

func test_a_melee_attack_at_threat_on_an_uncovered_primrose_is_unmodified():
	# The control that makes the cover clause mean something: same marker, same weapon, clean ground.
	await raise_shield()
	assert_eq(CoverCalculator.determine_cover(primrose, brawler).total, Lancer.COVER.NONE,
		'fixture: the Primrose is standing in the open.')

	var pre := preview(brawler, PrimroseFixture.HEAVY_MELEE)
	assert_eq(shield_lines(pre), 0, 'Out of cover, the shield contributes nothing.')
	assert_eq(pre.accuracy_mods_total(), 0, 'And the roll is unmodified.')

func test_a_ranged_attack_on_a_covered_primrose_takes_cover_and_not_the_shield():
	# "MELEE attacks against you". The rifle still gets its own vanilla cover penalty, which is the
	# engine's business and not the card's.
	cover_the_primrose()
	await raise_shield()

	var pre := preview(shooter, PrimroseFixture.MAIN_RIFLE)
	assert_eq(shield_lines(pre), 0, 'The shield does not touch a ranged attack.')
	assert_eq(cover_lines(pre), 1, 'Which still takes vanilla soft cover.')
	assert_eq(pre.accuracy_mods_total(), -1, 'For a total of -1, all of it cover.')

func test_a_thrown_melee_attack_on_a_covered_primrose_takes_cover_and_not_the_shield():
	# RULING 8: "melee attack" means a melee weapon used AT THREAT, never its thrown variant. A throw
	# is threat 0 (action_attack_weapon.gd:349-372), and the same line that makes it a throw also makes
	# ignores_cover false - so a throw is the one melee attack that DOES take cover, and the one the
	# shield refuses. Both halves in one test.
	cover_the_primrose()
	await raise_shield()
	var thrown := PrimroseFixture.thrown_variant(PrimroseFixture.specific(brawler, PrimroseFixture.HEAVY_MELEE))
	assert_eq(thrown.action.threat, 0, 'fixture: the thrown variant really has threat 0.')

	var pre := preview_specific(thrown)
	assert_eq(shield_lines(pre), 0, 'The shield refuses a throw (ruling 8).')
	assert_eq(cover_lines(pre), 1, 'And a throw, unlike a melee attack at threat, does take cover.')

func test_a_covered_primrose_under_markerlight_gets_neither():
	# RULING 8's second clause. The card's "while you are in cover" is read as "while you can BENEFIT
	# from cover", so a defender carrying an IGNORE_COVER chip gets nothing - which is the same answer
	# the roll gives a RANGED attack at attack_roll.gd:161-163.
	#
	# THE STATED REASON IN DESIGN 1.5 IS CORRECTED, though the ruling stands: for a melee attack at
	# threat the roll never reaches :161-163 at all, because it skipped the whole cover block. The
	# clause is the author's ruling and keeps the shield agreeing with the rest of the engine about who
	# benefits from cover; it is not a mirror of anything the roll does on this path.
	cover_the_primrose()
	await raise_shield()
	SpecFactory.apply_buff(primrose, MARKERLIGHT)
	assert_true(UnitCondition.has_buff(primrose, MARKERLIGHT), 'fixture: the Markerlight chip landed.')

	assert_eq(shield_lines(preview(brawler, PrimroseFixture.HEAVY_MELEE)), 0,
		'A Markerlighted Primrose gets no shield.')
	var ranged := preview(shooter, PrimroseFixture.MAIN_RIFLE)
	assert_eq(cover_lines(ranged), 0,
		'CONTROL: and the engine zeroes its vanilla cover too (attack_roll.gd:161-163), so the two '
		+ 'agree.')

func test_the_shield_does_nothing_without_the_marker():
	# The chip is applied BY the protocol, so without a press it is not on the unit at all - but the
	# assertion is worth making explicitly, because it is what says the effect is gated on the CHOICE
	# and not on the frame.
	cover_the_primrose()
	assert_false(UnitCondition.has_buff(primrose, COVER_CHIP), 'Unpressed, the chip is absent.')
	assert_eq(shield_lines(preview(brawler, PrimroseFixture.HEAVY_MELEE)), 0, 'And contributes nothing.')

	# And choosing the OTHER armament does not bring it either.
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.WORMHOLE_INDEX)
	assert_false(UnitCondition.has_buff(primrose, COVER_CHIP), 'Nor does Wormhole Grasp.')
	assert_eq(shield_lines(preview(brawler, PrimroseFixture.HEAVY_MELEE)), 0, 'Still nothing.')

# ---------------------------------------------------------------- the cap (design 1.4's last cases)

func test_the_cap_rises_to_five_under_the_shield():
	# "Effervescent Immunity can stack up to a maximum of +5." The whole clause is
	# buff_effervescent_immunity.cap_for asking whether the holder carries the marker - so this is the
	# test that proves the two halves of the core system talk to each other.
	#
	# THE CONTROL IS A SECOND PRIMROSE with no marker, in the same game and the same round: it reports
	# the base cap while the first reports the raised one, which no "the cap is 5" assertion alone
	# could distinguish from "the cap was always 5".
	var unshielded:Unit = PrimroseFixture.create_primrose(game, SECOND_PRIMROSE)
	assert_eq(Immunity.cap_for(unshielded), Immunity.BASE_CAP, 'fixture: an unmarked Primrose caps at 3.')

	await raise_shield()
	assert_eq(Immunity.cap_for(primrose), Immunity.SHIELDED_CAP, 'Under the shield the cap is 5.')
	assert_eq(Immunity.cap_for(unshielded), Immunity.BASE_CAP,
		'And its neighbour, in the same round, still caps at 3.')

	for i:int in 3: await miss()
	assert_eq(bonus(), 3, 'Three misses reach +3, which the base cap would also allow.')

	await miss()
	await miss()
	assert_eq(Immunity.stacks_on(primrose), 5, 'The fourth and fifth are the ones the shield buys.')
	assert_eq(bonus(), 5, 'And the bonus really is +5, read through the accessor.')

	# AND THE CHIP SAYS SO. effect_text is cap-aware through the same cap_for
	# (buff_effervescent_immunity.gd:76-78), so this is the one assertion that reads the raised cap the
	# way a PLAYER does - by hovering the chip. It is also the reason the row carries no fixed maximum:
	# a row ending "up to a maximum of +3" would render "+5 ... maximum of +3" right here.
	var rendered:String = UnitCondition.get_buff(primrose, IMMUNITY_CHIP).effect_text()
	assert_string_contains(rendered, '+5',
		'The chip renders the raised bonus, not a value clamped to the base cap.')
	assert_false(rendered.contains('maximum'),
		'And names no fixed maximum, which under this shield would contradict the number beside it.')

func test_the_sixth_miss_grants_1d3_overshield():
	# RULING 7: "If it would increase past this point, you instead gain 1d3 OVERSHIELD." Through the
	# shared helper's grant(), which is max-semantics: event_unit_overshield sets
	# state.overshield = max(0, max(old, amount)) and NEVER adds (event_unit_overshield.gd:15).
	#
	# THE SIXTH FAILED ATTACK IS A TECH ATTACK, not a sixth rifle shot - see miss_then_d3()'s header
	# for the measurement. Ruling 6 counts it identically; the rifle's Reliable 2 would eat a point of
	# the very Overshield this test reads.
	await raise_shield()
	for i:int in 5: await miss()
	assert_eq(Immunity.stacks_on(primrose), 5, 'fixture: at the raised cap.')
	assert_eq(primrose.state.overshield, 0, 'fixture: and holding no Overshield yet.')

	await miss_then_d3(3)

	assert_eq(Immunity.stacks_on(primrose), 5, 'The counter does not move past five.')
	assert_eq(bonus(), 5, 'Nor does the bonus.')
	assert_eq(primrose.state.overshield, 3, 'The overflow became 1d3 Overshield - cheated to a 3.')

func test_a_further_miss_leaves_a_higher_overshield_unchanged():
	# The other half of ruling 7, and the reason grant() is the right helper rather than increase():
	# "you instead GAIN 1d3 Overshield" is the engine's max semantics, so a roll below what the
	# Primrose already holds changes nothing. Overshield.grant's own header says every "gains
	# OVERSHIELD" card wants exactly this.
	# THE ORDER IS 1 -> 3 -> 1 AND THAT IS THE WHOLE DESIGN OF THIS TEST (SP1 final review, I4). The
	# shape it replaced ran 3 -> 1 -> 3 and expected 3 every time, which a regression that let the
	# overflow fire ONCE and never again - a 1/scene guard added to the overflow branch, say - would
	# have passed unchanged. Opening on a 1 makes the first grant's value load-bearing, the 3 that
	# follows proves a LATER overflow still fires AND can raise, and the closing 1 is the max clause.
	await raise_shield()
	for i:int in 5: await miss()
	await miss_then_d3(1)
	assert_eq(primrose.state.overshield, 1, 'The first overflow grants exactly what it rolled - a 1.')

	await miss_then_d3(3)
	assert_eq(primrose.state.overshield, 3,
		'A LATER overflow still fires, and a higher roll raises it - so it is not a once-only grant.')

	await miss_then_d3(1)
	assert_eq(primrose.state.overshield, 3, 'A 1d3 of 1 does not reduce a 3 - grant() takes the max.')
