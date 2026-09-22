# BULWARK - RAGE's face 5 (SP1 Task 11).
#
#   "5 Bulwark: All hostile characters within line of sight have +1 Difficulty on attacks against
#    characters other than you."
#
# A VISIBLE CHIP ON THE LEOLETH plus a PassiveAura on the core Kit that hangs a HIDDEN penalty on
# every hostile character in line of sight (ruling 13). The penalty is on the HOSTILE, and that is
# forced by the engine: PreAttack.create collects Buff.TO.ATTACK_ROLL from the ATTACKER
# (attack_roll.gd:134) and ATTACK_ROLL_INCOMING from the DEFENDER (:135), and this card penalises
# attacks on somebody who is neither.
#
# "OTHER THAN YOU" IS A PER-ROLL CLAUSE, so it lives in the penalty buff's check_if_passive_applies
# rather than in the aura's placement: the same hostile is penalised against an ally and not against
# the Leoleth, in the same instant.
#
# MEASURED THROUGH AttackRoll.PreAttack.accuracy_mods_total, the way test_aaaa_difficulty.gd does -
# a test that only read has_buff could not tell "the dome is up" from "the dome matters". Every
# target stands in the OPEN so cover contributes nothing to the totals.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_bulwark.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const LEOLETH_TILE := Vector2i(6, 6)
const HOSTILE_TILE := Vector2i(10, 6)
## TWO TILES FROM THE HOSTILE, DELIBERATELY NOT ADJACENT (IMPLEMENTER CORRECTION, Task 11). The
## plan's draft put the ally at Vector2i(9, 6), one tile from the hostile - and ENGAGEMENT IS
## MUTUAL AND SITS ON THE SHOOTER, so that single tile put a -1 into every accuracy total in this
## file before any Bulwark content existed. Measured on the first parsing RED run: `fixture: no
## penalty before the roll` read -1, `Shooting the LEOLETH is unpenalised` read -1 (the hostile is
## engaged by the ALLY, whatever it happens to be aiming at) and `And shoots unpenalised` read -1
## for the ally in the same way. UnitCondition.update_engaged_status applies ENGAGED from
## UnitRelation.get_engaging_units, which is adjacency (unit_relation.gd:190-200), and
## PreAttack.create then subtracts 1 for `is_engaged(unit) and action.is_difficulty_when_engaged()`
## (attack_roll.gd:173) - the rifle being ranged. This is Task 3's carry-forward one step wider:
## never stand a ranged shooter ADJACENT TO ANY HOSTILE in a spec that reads accuracy, not only
## adjacent to its target. At distance 2 the same totals read 0 (measured, the GREEN run).
const ALLY_TILE := Vector2i(8, 6)
## Behind the wall built in before_each: on the map, in range, out of sight.
const BLIND_TILE := Vector2i(6, 11)
const WALL_TILES:Array[Vector2i] = [Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9)]

const PENALTY := -1

var game:Gamemaster
var leoleth:Unit
var hostile:Unit
var ally:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	# A THREE-TILE FORBIDDEN INTERIOR (IMPLEMENTER CORRECTION, Task 11). The plan's draft called
	# SpecFactory.set_blocks_to_height(game.map_node, 3, WALL_TILES); that does not compile -
	# spec_factory.gd:175 declares the first parameter as LandscapeNode and game.map_node is a
	# MapNode3D (gamemaster.gd:27), so the whole file was IGNORED by GUT with
	# "Parse Error: Invalid argument for set_blocks_to_height(): argument 1 should be LandscapeNode
	# but is MapNode3D" (measured, first RED run: 1 ignored script, 0 tests). The landscape node is
	# game.get_landscape_node() (gamemaster.gd:266).
	#
	# AND THE BLOCKER IS THE ONE THIS MOD HAS MEASURED, not raised blocks. The plan's own comment
	# beside that line says one-tall blocks beside a size-1 unit are unreliable geometry; every
	# Sixth Voice spec that needs a real sight blocker uses a forbidden-interior setpiece instead
	# (test_spin.gd:408-411, test_solfataric_breach.gd:165-166, test_draw_fire.gd:333-334), which
	# blocks at every layer AND gives the units behind it no cover of its own
	# (test_hole_puncher.gd:189-190) - and cover would land in the very accuracy totals this file
	# reads. FitzgeraldFixture.create_game already sets forbidden_interiors_enabled, which is the
	# flag that makes an interior a full-height blocker (landscape_node.gd:608).
	SpecFactory.add_setpieces_to_landscape(
		game.get_landscape_node(), &'setpiece_forbidden_interior', WALL_TILES
	)
	game.map.calculate_los_blockers()
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	hostile = LeolethFixture.create_hostile(game, HOSTILE_TILE)
	ally = LeolethFixture.create_ally(game, ALLY_TILE)
	LeolethFixture.arm_rifle(hostile)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func preview(shooter:Unit, against:Unit) -> AttackRoll.PreAttack:
	var rifle:GearCore = shooter.get_gear(LeolethFixture.MAIN_RIFLE)
	var specific := SpecificAction.create(shooter, rifle, rifle.get_solo_action())
	return AttackRoll.PreAttack.create(Context.clone(specific.to_context(), {target_unit = against}))

# ---------------------------------------------------------------- the wiring

func test_the_chip_and_the_aura_are_wired_as_ruling_13_says():
	var chip:Buff = ContentLibrary.get_buff(LeolethFixture.BULWARK_CHIP)
	assert_not_null(chip, '%s loads as a Buff.' % LeolethFixture.BULWARK_CHIP)
	if chip == null: return
	assert_eq(chip.until, Lancer.UNTIL.START_OF_TURN, 'The chip lasts until the next turn start.')
	assert_false(chip.hide_from_player, 'VISIBLE: one of the six face chips.')
	assert_eq(chip.to, Buff.TO.NONE, 'And it has no channel of its own - the AURA reads it by id.')

	var kit:Kit = ContentLibrary.get_kit(LeolethFixture.CORE_ID)
	assert_not_null(kit, 'fixture: the core Kit loads.')
	if kit == null: return
	assert_true(kit.has_passive_type(PassiveAura),
		'The core Kit carries a PassiveAura - which is also what makes applying the chip FROM this '
		+ 'Kit re-run every aura in the same event (unit_condition.gd:703-715).')
	var auras:Array[Passive] = kit.get_passives(PassiveAura)
	assert_eq(auras.size(), 1, 'Exactly one.')
	if auras.is_empty(): return
	var aura:PassiveAura = auras[0]
	assert_eq(aura.aura_range, 99, 'Range 99: line of sight is the bound, not a radius.')
	assert_true(aura.applies_only_when_in_los, 'And LOS is asked explicitly (passive_aura.gd:87).')
	assert_false(aura.applies_to_self, 'Never on the Leoleth itself...')
	assert_false(aura.applies_to_allies, '...nor on its allies...')
	assert_true(aura.applies_to_enemies, '...only on hostiles.')
	assert_not_null(aura.requires_buff, 'It is gated on a buff...')
	if aura.requires_buff == null: return
	assert_eq(aura.requires_buff.compcon_id, LeolethFixture.BULWARK_CHIP, '...and that buff is the chip.')
	assert_eq(aura.buffs.size(), 1, 'It places exactly one buff...')
	if aura.buffs.is_empty(): return
	assert_eq(aura.buffs[0].compcon_id, LeolethFixture.BULWARK_PENALTY, '...the difficulty penalty.')

func test_the_penalty_buff_is_wired():
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.BULWARK_PENALTY)
	assert_not_null(buff, '%s loads as a Buff.' % LeolethFixture.BULWARK_PENALTY)
	if buff == null: return
	assert_true(buff is BuffBonus, 'It is a BuffBonus subclass.')
	if not (buff is BuffBonus): return
	assert_eq(buff.to, Buff.TO.ATTACK_ROLL,
		'to = attack_roll: the ATTACKER\'s channel. There is no INCOMING channel that could carry '
		+ 'this card, because the penalised attack is against somebody who is neither the Leoleth '
		+ 'nor the attacker.')
	assert_eq(buff.bonus_subtype, Buff.BONUS_SUBTYPE.ACCURACY, 'An accuracy subtype...')
	assert_eq(buff.bonus_value, PENALTY, '...of -1, which is +1 difficulty.')
	assert_true(buff.hide_from_player,
		'HIDDEN on the hostile (plan J, flagged for the author): the Leoleth\'s own chip is the '
		+ 'signal, and the Mark\'s soft cover is the precedent - plumbing beside a visible chip.')

func test_the_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.buff_rage_bulwark.name', 'gear.buff_rage_bulwark.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.buff_rage_bulwark.name'), 'Bulwark', 'Named off the table.')
	assert_eq(X.tr('gear.buff_rage_bulwark.effect'),
		'All hostile |characters| within |line of sight| have +1 |Difficulty| on attacks against characters other than you.',
		'And its effect row is that face\'s line, verbatim.')

# ---------------------------------------------------------------- the dome

func test_a_hostile_in_sight_attacking_an_ally_rolls_at_one_difficulty():
	assert_eq(preview(hostile, ally).accuracy_mods_total(), 0, 'fixture: no penalty before the roll.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_BULWARK)
	assert_true(LeolethFixture.has(hostile, LeolethFixture.BULWARK_PENALTY),
		'The aura reached the hostile in the same event that hung the chip.')
	assert_eq(preview(hostile, ally).accuracy_mods_total(), PENALTY,
		'And its shot at an ally is at -1.')

func test_the_same_hostile_attacking_the_leoleth_rolls_at_zero():
	# "OTHER THAN YOU", in the same instant as the test above. The clause is in the penalty buff's own
	# check_if_passive_applies, not in the aura's placement - the chip is still on the hostile.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_BULWARK)
	assert_true(LeolethFixture.has(hostile, LeolethFixture.BULWARK_PENALTY), 'fixture: the chip is on it.')
	assert_eq(preview(hostile, leoleth).accuracy_mods_total(), 0,
		'Shooting the LEOLETH is unpenalised - the card exempts it by name.')

func test_a_hostile_out_of_line_of_sight_is_untouched():
	var blind:Unit = LeolethFixture.create_hostile(game, BLIND_TILE)
	LeolethFixture.arm_rifle(blind)
	assert_false(UnitRelation.can_see(leoleth, blind),
		'fixture: the wall really blocks sight. If this fails the geometry is wrong, not the content.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_BULWARK)
	assert_true(LeolethFixture.has(hostile, LeolethFixture.BULWARK_PENALTY), 'fixture: the dome IS up.')
	assert_false(LeolethFixture.has(blind, LeolethFixture.BULWARK_PENALTY),
		'But a hostile behind the wall gets nothing - applies_only_when_in_los.')
	assert_eq(preview(blind, ally).accuracy_mods_total(), 0, 'And its shot at an ally is unpenalised.')

func test_an_allied_character_is_never_penalised():
	LeolethFixture.arm_rifle(ally)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_BULWARK)
	assert_false(LeolethFixture.has(ally, LeolethFixture.BULWARK_PENALTY),
		'applies_to_allies is false, so a friend in sight gets nothing.')
	assert_eq(preview(ally, hostile).accuracy_mods_total(), 0, 'And shoots unpenalised.')

func test_a_hostile_drone_is_not_penalised():
	# RULING 22. applies_only_to_characters would NOT do this: PassiveAura's own clause is
	# moving_unit.is_character() (passive_aura.gd:73), which is TRUE for a drone (unit.gd:116). The
	# narrowing is in can_apply_buff_to_unit.
	var drone:Unit = LeolethFixture.create_drone(game, Vector2i(11, 6), Faction.AI_ENEMY)
	LeolethFixture.arm_rifle(drone)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_BULWARK)
	assert_true(LeolethFixture.has(hostile, LeolethFixture.BULWARK_PENALTY), 'fixture: the dome IS up.')
	assert_false(LeolethFixture.has(drone, LeolethFixture.BULWARK_PENALTY),
		'A hostile DRONE is a character but not an actor, and this card says characters.')

func test_the_penalty_vanishes_with_the_chip():
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_BULWARK)
	assert_true(LeolethFixture.has(hostile, LeolethFixture.BULWARK_PENALTY), 'fixture: the dome is up.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_REACH)
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.BULWARK_CHIP), 'The chip is gone...')
	assert_false(LeolethFixture.has(hostile, LeolethFixture.BULWARK_PENALTY),
		'...and PassiveAura.update_unit strips the penalty with it (passive_aura.gd:55-59).')
	assert_eq(preview(hostile, ally).accuracy_mods_total(), 0, 'And the shot is clean again.')

func test_a_hostile_that_walks_into_sight_is_caught_by_the_dome():
	# THE OTHER HALF OF THE AURA: it is not a one-shot placement. PassiveAura.update_unit is called
	# from UnitTile.update_tracking_and_statuses (unit_tile.gd:24), which UnitTile.move_to runs for
	# the mover (:10-13). LeolethFixture.step is that call.
	var blind:Unit = LeolethFixture.create_hostile(game, BLIND_TILE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_BULWARK)
	assert_false(LeolethFixture.has(blind, LeolethFixture.BULWARK_PENALTY), 'fixture: out of sight.')
	LeolethFixture.step(blind, Vector2i(11, 6))
	LeolethFixture.track(game)
	assert_true(LeolethFixture.has(blind, LeolethFixture.BULWARK_PENALTY),
		'Stepping into sight puts it under the dome.')
