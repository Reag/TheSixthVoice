# GRAVITY WELL (Vauban SP1 Task 5).
#
#   "While the Vauban is in at least one space of difficult terrain, all ranged and melee attacks
#    made against it have +1 difficulty. Any adjacent allied mechs also benefit from this ability."
#
# ONE RANGE-1 AURA CARRYING ONE CONDITIONAL BUFF (design §1.5). The aura hangs the buff permanently on
# the Vauban and on every adjacent allied MECH; the buff's own gate is what asks whether the VAUBAN is
# standing in difficult ground. That is the cheaper of the two shapes - the alternative is a tracking
# pass that adds and removes the buff every time the Vauban steps on or off difficult ground - and it
# keeps the terrain question out of the aura entirely.
#
# THE CONDITION IS ALWAYS THE VAUBAN'S OWN TILES (ruling 7). A sheltered ally's ground is never
# consulted, which is what test_an_adjacent_allied_mech_is_not_sheltered_while_only_the_ally_stands_
# in_difficult_ground exists to say.
#
# MEASURED OFF THE ROLL'S OWN BREAKDOWN, not off a hit or a damage number. AttackRoll.PreAttack.create
# folds an ATTACK_ROLL_INCOMING accuracy value into a named AccuracyMod (attack_roll.gd:182-189), and
# counting the line titled with this chip's name is the only way to say "this trait did it" rather
# than "the total happened to be -1" - cover, Impaired, Engaged and the weapon's own Accurate/
# Inaccurate all land in the same total. test_diversion_rail.gd's preview()/chip_mod_count() pair is
# the idiom, verbatim.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_gravity_well.gd
extends GutTest

const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')

const TRAIT_ID := &'mt_gravity_well'
const CHIP_ID := &'buff_gravity_well'
const CHIP_NAME_KEY := 'gear.mt_gravity_well.name'

const MAP_SIZE := Vector2i(15, 9)
const VAUBAN_TILE := Vector2i(4, 4)
const ADJACENT := Vector2i(5, 4)      ## distance 1 - inside the range-1 aura
const TWO_OUT := Vector2i(6, 4)       ## distance 2 - outside it
const ADJACENT_SOUTH := Vector2i(4, 5)
const ADJACENT_WEST := Vector2i(3, 4)
const SHOOTER_TILE := Vector2i(10, 8) ## far from everyone, so nothing here is anybody's cover

var game:Gamemaster
var vauban:Unit
var shooter:Unit

func before_each() -> void:
	game = VaubanFixture.create_game(self, MAP_SIZE)
	vauban = VaubanFixture.create_vauban(game, VAUBAN_TILE)
	shooter = VaubanFixture.create_hostile(game, SHOOTER_TILE)
	VaubanFixture.equip_ranged(shooter)
	VaubanFixture.track(game)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

## Stand the Vauban in difficult ground: its own tile, and nothing else on the map.
func flood_the_vaubans_tile() -> void:
	VaubanFixture.lay_difficult(game, [VAUBAN_TILE])
	VaubanFixture.track(game)

## What a roll by `shooter` with `weapon` against `against` would compute right now - the way
## test_diversion_rail.preview() and test_hybridized_shot.accuracy_for() both read a modifier without
## firing anything.
func preview(with_gear:GearCore, against:Unit) -> AttackRoll.PreAttack:
	var specific := SpecificAction.create(shooter, with_gear, with_gear.get_solo_action())
	var context := Context.clone(specific.to_context(), {target_unit = against})
	return AttackRoll.PreAttack.create(context)

## HOW MANY of Gravity Well's own breakdown lines a roll carries. Read off the mod list rather than
## the total, for test_hybridized_shot.got_the_bonus's reason: the total is the sum of every accuracy
## source on the roll, so a test watching only the total would be measuring the map as much as the
## trait. The title is buff_core.name_text(), which is what attack_roll.gd:189 puts on the line.
func well_lines(pre:AttackRoll.PreAttack) -> int:
	var count := 0
	for mod:AttackRoll.AccuracyMod in pre.accuracy_mods:
		if mod.title_key == X.tr(CHIP_NAME_KEY) and mod.mod == -1: count += 1
	return count

func rifle_lines_against(unit:Unit) -> int:
	var pre := preview(shooter.get_gear(VaubanFixture.RANGED_ID), unit)
	gut.p('  total accuracy mods on that roll: %d' % pre.accuracy_mods_total())
	return well_lines(pre)

func has_chip(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, CHIP_ID)

# ---------------------------------------------------------------- wiring and text

func test_the_trait_is_wired():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_gravity_well is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')
	assert_eq(kit.actions.size(), 0, 'It has no actions at all - the whole trait is the aura.')
	assert_eq(kit.passives.size(), 1, 'And exactly one passive.')
	var aura = kit.passives[0]
	assert_true(aura is PassiveAura, 'Which is a PassiveAura.')
	if aura is not PassiveAura: return
	assert_eq(aura.aura_range, 1,
		'"Adjacent" is range 1, compared against UnitRelation.distance_between at passive_aura.gd:85.')
	assert_true(aura.applies_to_self, 'The Vauban shelters itself - the card\'s first sentence.')
	assert_true(aura.applies_to_allies, 'And its adjacent allies - the second.')
	assert_false(aura.applies_to_enemies, 'Never hostiles.')
	assert_true(aura.applies_only_to_characters, 'And never markers or objects.')
	assert_true(aura.starts_active, 'On from the first tracking pass: the card has no switch.')
	assert_eq(aura.buffs.size(), 1, 'Carrying exactly one buff.')

	# assert_not_null RATHER THAN THE BRIEF'S Buff.is_valid: there IS no Buff.is_valid. Buff declares
	# only check_if_prohibited and check_required_triggering_context as statics (buff.gd:228, :258) and
	# the validity helper lives on BuffCore instead (buff_core.gd:19). Naming it is a PARSE error, and
	# GUT then SKIPS the whole script rather than failing it - the suite reads green and twelve tests
	# quietly vanish. test_sap.gd:264-268 records the identical correction, measured on 2026-09-18, and
	# test_rend.gd:118-120 and test_gather_round.gd:48-50 already use this shape. Same assertion, no
	# weakening: ContentLibrary.get_buff returns the resource or null.
	var chip:Buff = ContentLibrary.get_buff(CHIP_ID)
	assert_not_null(chip, 'buff_gravity_well is in the buffs index.')
	if chip == null: return
	assert_eq(chip.to, Buff.TO.ATTACK_ROLL_INCOMING, 'It modifies attacks made AGAINST its holder.')
	assert_eq(chip.bonus_subtype, Buff.BONUS_SUBTYPE.ACCURACY, 'By accuracy, not a flat bonus.')
	assert_eq(chip.bonus_value, -1, 'Minus one, which the card calls +1 difficulty.')
	assert_eq(chip.until, Lancer.UNTIL.MANUAL, 'Held by the aura; nothing else expires it.')
	assert_false(chip.hide_from_player,
		'VISIBLE: attack_roll.gd:189 passes base.icon RAW into the roll breakdown, so a hidden chip '
		+ 'with no icon draws a blank beside the -1.')

func test_the_rows_resolve_and_the_chip_borrows_the_kits_name():
	for key:String in ['gear.mt_gravity_well.name', 'gear.mt_gravity_well.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

	# THE CHIP HAS NO ROWS OF ITS OWN, AND THAT IS THE ENGINE'S OWN FALLBACK rather than an omission:
	# Translate.buff falls through to the owner gear's keys when the buff has none
	# (translate.gd:64-77), and this chip's owner gear is mt_gravity_well. buff_weak_computer already
	# relies on it. Pinned here because attack_roll.gd:189 titles the breakdown line with
	# name_text(), so a fallback that stopped working would put a raw key on every roll.
	var chips:Array[BuffCore] = UnitCondition.get_buffs(vauban, CHIP_ID)
	assert_eq(chips.size(), 1, 'The Vauban is wearing exactly one chip.')
	if chips.is_empty(): return
	assert_eq(chips[0].name_text(), X.tr(CHIP_NAME_KEY),
		'And it is titled "Gravity Well", off the Kit\'s own name row.')

# ---------------------------------------------------------------- the Vauban itself

func test_on_clean_ground_an_attack_on_the_vauban_carries_no_gravity_well_line():
	# THE CONTROL EVERY OTHER TEST HERE LEANS ON. The chip is on the Vauban permanently; what changes
	# is whether its gate lets it apply.
	assert_true(has_chip(vauban), 'The chip is held even on clean ground - only the gate moves.')
	assert_eq(rifle_lines_against(vauban), 0, 'And it contributes nothing.')

func test_on_difficult_ground_an_attack_on_the_vauban_is_at_one_difficulty():
	flood_the_vaubans_tile()
	assert_eq(rifle_lines_against(vauban), 1, 'One Gravity Well line of -1 on the incoming roll.')

# ---------------------------------------------------------------- adjacent allies

func test_an_adjacent_allied_mech_is_sheltered_while_the_vauban_stands_in_difficult_ground():
	var ally := VaubanFixture.create_ally(game, ADJACENT)
	VaubanFixture.track(game)
	assert_true(has_chip(ally), 'The aura hangs the chip on an adjacent ally.')
	assert_eq(rifle_lines_against(ally), 0, 'CONTROL: on clean ground it contributes nothing.')

	flood_the_vaubans_tile()

	assert_eq(rifle_lines_against(ally), 1, 'With the Vauban in the field, the ally is sheltered too.')

func test_an_adjacent_allied_mech_is_not_sheltered_while_only_the_ally_stands_in_difficult_ground():
	# RULING 7 in one test: the condition is the VAUBAN's own tiles, always. The ally's ground is
	# never consulted, however deep it is standing.
	var ally := VaubanFixture.create_ally(game, ADJACENT)
	VaubanFixture.lay_difficult(game, [ADJACENT])
	VaubanFixture.track(game)
	assert_true(has_chip(ally), 'fixture: it holds the chip.')

	assert_eq(rifle_lines_against(ally), 0, 'Standing in the field itself buys the ally nothing.')
	assert_eq(rifle_lines_against(vauban), 0, 'And the Vauban, on clean ground, gets nothing either.')

func test_an_adjacent_allied_drone_never_gets_the_buff():
	# The card says MECHS. applies_only_to_characters is not enough: a drone IS a character
	# (frame.gd:100), and only is_mech() excludes it (unit.gd:118) - which is why the aura carries a
	# script at all.
	var drone := VaubanFixture.create_drone(game, ADJACENT_SOUTH)
	var mech := VaubanFixture.create_ally(game, ADJACENT)
	flood_the_vaubans_tile()

	assert_true(drone.is_character(), 'fixture: the drone is a character, so the flag alone passes it.')
	assert_false(drone.is_mech(), 'fixture: and is not a mech.')
	assert_false(has_chip(drone), 'So it never gets the chip.')
	assert_eq(rifle_lines_against(drone), 0, 'And attacks on it are unmodified.')
	assert_true(has_chip(mech), 'CONTROL: the allied MECH beside it does.')

func test_an_adjacent_hostile_never_gets_the_buff():
	var hostile := VaubanFixture.create_hostile(game, ADJACENT_WEST)
	flood_the_vaubans_tile()

	assert_false(has_chip(hostile), 'applies_to_enemies is false: a hostile standing next to it gets nothing.')
	assert_eq(rifle_lines_against(hostile), 0, 'And attacks on it are unmodified.')

func test_an_ally_two_tiles_out_never_gets_the_buff():
	var near_ally := VaubanFixture.create_ally(game, ADJACENT)
	var far_ally := VaubanFixture.create_ally(game, TWO_OUT)
	flood_the_vaubans_tile()

	assert_true(has_chip(near_ally), 'CONTROL: one tile out is adjacent.')
	assert_false(has_chip(far_ally), 'Two tiles out is not, and aura_range is 1.')
	assert_eq(rifle_lines_against(far_ally), 0, 'So attacks on it are unmodified.')

# ---------------------------------------------------------------- what it does not touch

func test_a_tech_attack_is_untouched():
	# "All ranged and melee attacks" are WEAPON attacks (ruling 7). ms_fragment_signal is in every
	# player mech's basic loadout and its one action is an ActionAttackTech, so this needs no
	# equipping and no new content - and it is the negative control for the buff's one type check.
	flood_the_vaubans_tile()
	var tech:GearCore = shooter.get_gear(VaubanFixture.TECH_ID)
	assert_true(GearCore.is_valid(tech), 'fixture: every mech carries ms_fragment_signal.')
	if not GearCore.is_valid(tech): return
	assert_true(tech.get_solo_action() is ActionAttackTech, 'fixture: and its action is a tech attack.')

	assert_eq(well_lines(preview(tech, vauban)), 0, 'A tech attack carries no Gravity Well line.')
	assert_eq(rifle_lines_against(vauban), 1, 'CONTROL: a weapon attack on the same target does.')

# ---------------------------------------------------------------- lifetime

func test_the_chip_clears_when_the_ally_leaves_range():
	var ally := VaubanFixture.create_ally(game, ADJACENT)
	VaubanFixture.track(game)
	assert_true(has_chip(ally), 'fixture: adjacent, so it holds the chip.')

	await SpecFactory.move(game, ally, TWO_OUT, MovementType.create_for_involuntary(ally))

	assert_false(has_chip(ally), 'PassiveAura.update_unit strips it on leaving range (passive_aura.gd:55-59).')

func test_the_chip_clears_when_the_vauban_dies():
	var ally := VaubanFixture.create_ally(game, ADJACENT)
	VaubanFixture.track(game)
	assert_true(has_chip(ally), 'fixture: the ally holds the chip.')

	await game.execute_event(&'event_unit_die', {unit = vauban})

	assert_false(Unit.is_valid(vauban), 'fixture: the Vauban really died.')
	assert_false(has_chip(ally),
		'EventService.remove_unit_from_game clears a dead unit\'s outgoing buffs off everyone else '
		+ '(event_service.gd:71).')
