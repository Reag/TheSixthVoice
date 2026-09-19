# ARTFUL CARESS (Primrose SP1 Task 3).
#
#   "Heavy and Superheavy melee weapons on the Primrose gain +1 threat."
#
# PURE CONTENT: one trait Kit, one PassiveBuffApplicator, one plain BuffWeaponTypeBonus with no
# script. The Tokugawa's buff_limit_break_threat.tres is the file it copies (that one adds a status
# gate in a subclass; ours needs none).
#
# MEASURED THROUGH threat_distance(specific), which is the engine's own accessor and the only thing
# that reads a THREAT_RANGE buff: action_attack_weapon.gd:187-190 starts from the printed `threat` and
# runs BuffBonus.get_bonus_for_subtype over every Buff.TO.ACTION_RANGE buff on the unit. Reading the
# printed `threat` field instead would measure the resource and not the trait.
#
# THE WEAPON MUST BE EQUIPPED AS A SYSTEM, which PrimroseFixture.equip does:
# BuffWeaponType.check_if_passive_applies refuses basic gear unless allow_basic
# (buff_weapon_type.gd:55), so a weapon handed over any other route would be invisible to this trait
# for a reason that has nothing to do with its filters.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_artful_caress.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const TRAIT_ID := &'mt_artful_caress'
const BUFF_ID := &'buff_artful_caress'

const PRIMROSE_TILE := Vector2i(4, 4)

var game:Gamemaster
var primrose:Unit

func before_each() -> void:
	game = PrimroseFixture.create_game(self)
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The threat the ENGINE would use for this weapon right now, and the printed value it started from.
## Returns [printed, buffed].
func threat_of(kit_id:StringName) -> Array[int]:
	PrimroseFixture.equip(primrose, kit_id)
	var specific := PrimroseFixture.specific(primrose, kit_id)
	assert_true(SpecificAction.is_valid(specific), 'fixture: %s is equipped and has an action.' % kit_id)
	if not SpecificAction.is_valid(specific): return [0, 0]
	return [specific.action.threat, specific.action.threat_distance(specific)]

# ---------------------------------------------------------------- wiring and text

func test_the_trait_is_wired():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), '%s is in the kits index.' % TRAIT_ID)
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')
	assert_eq(kit.actions.size(), 0, 'It has no actions - the whole trait is the passive buff.')
	assert_eq(kit.passives.size(), 1, 'And exactly one passive.')
	assert_true(GearCore.is_valid(primrose.get_gear(TRAIT_ID)), 'The Primrose is wearing it.')

	var buff:Buff = ContentLibrary.get_buff(BUFF_ID)
	assert_not_null(buff, '%s is in the buffs index.' % BUFF_ID)
	if buff == null: return
	assert_true(buff is BuffWeaponTypeBonus, 'It is a PLAIN BuffWeaponTypeBonus - no subclass.')
	assert_eq(buff.get_script().resource_path, 'res://engine/character/buff/archtypes/buff_weapon_type_bonus.gd',
		'And it really is the engine archetype, not a mod script that happens to extend it.')
	assert_eq(buff.to, Buff.TO.ACTION_RANGE, 'It modifies an action range.')
	assert_eq(buff.bonus_subtype, Buff.BONUS_SUBTYPE.THREAT_RANGE,
		'Specifically THREAT range - which is what makes ruling 13 true with no gate.')
	assert_eq(buff.bonus_value, 1, 'By one.')
	assert_false(buff.overrides, 'ADDITIVE, not an override - so it stacks with Wormhole Grasp (ruling 11).')
	assert_true(buff.hide_from_player, 'And is trait plumbing, never a chip on the unit.')
	if buff is not BuffWeaponTypeBonus: return
	assert_eq(buff.weapon_sizes, [Lancer.WEAPON_SIZE.HEAVY, Lancer.WEAPON_SIZE.SUPERHEAVY] as Array[int],
		'Filtered to Heavy and Superheavy.')
	assert_eq(buff.weapon_types, [Lancer.WEAPON_TYPE.MELEE] as Array[int], 'And to melee.')

func test_the_rows_resolve():
	for key:String in ['gear.mt_artful_caress.name', 'gear.mt_artful_caress.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

# ---------------------------------------------------------------- what it widens

func test_a_superheavy_melee_weapons_threat_is_one_further():
	var pair := threat_of(PrimroseFixture.SUPERHEAVY_MELEE)
	assert_eq(pair[0], 1, 'Fixture: the Combat Drill prints threat 1.')
	assert_eq(pair[1], 2, 'Artful Caress makes it 2.')

func test_a_heavy_melee_weapons_threat_is_one_further():
	var pair := threat_of(PrimroseFixture.HEAVY_MELEE)
	assert_eq(pair[0], 1, 'Fixture: the Heavy Melee Weapon prints threat 1.')
	assert_eq(pair[1], 2, 'Artful Caress makes it 2.')

# ---------------------------------------------------------------- what it does not

func test_a_main_melee_weapons_threat_is_unchanged():
	var pair := threat_of(PrimroseFixture.MAIN_MELEE)
	assert_eq(pair[1], pair[0], 'A MAIN melee weapon is the right type and the wrong size.')

func test_a_heavy_rifles_threat_is_unchanged():
	# THE CONTROL THAT PROVES THE TYPE FILTER IS DOING WORK. Every weapon in the engine has a threat -
	# the export defaults to 1 (action_attack_weapon.gd:16) - so a rifle really does have a threat
	# distance for this buff to widen, and only weapon_types stops it.
	var pair := threat_of(PrimroseFixture.HEAVY_RIFLE)
	assert_eq(pair[0], 1, 'Fixture: even a rifle prints threat 1 - the export default.')
	assert_eq(pair[1], pair[0], 'A HEAVY rifle is the right size and the wrong type.')

func test_a_heavy_melee_weapons_thrown_range_is_unchanged():
	# RULING 13: "Artful Caress touches THREAT only; a thrown Heavy melee weapon keeps its printed
	# thrown range." This is a property of the SUBTYPE rather than of any gate - thrown_distance reads
	# Buff.BONUS_SUBTYPE.THROWN_RANGE (action_attack_weapon.gd:192-195) and this buff declares
	# THREAT_RANGE - so no filter could ever make it true or false.
	#
	# THE CASE HAS TO BE CONSTRUCTED. No vanilla Heavy or Superheavy melee weapon carries the Thrown
	# tag (grepped 2026-09-19: mw_tactical_knife and mw_shock_knife are AUX, mw_war_pike is MAIN), and
	# the Rend Axe that SP2 adds to this frame is MAIN too - so this is the only place the ruling can
	# be tested at all. create_duplicate_for_variant is the engine's own copier
	# (action.gd:94-99) and nothing here can reach the shared ContentLibrary Action.
	var gear:GearCore = PrimroseFixture.equip_heavy_melee(primrose)
	var base := PrimroseFixture.specific(primrose, PrimroseFixture.HEAVY_MELEE)
	var throwable:ActionAttackWeapon = base.action.create_duplicate_for_variant()
	throwable.thrown = 3
	var specific := SpecificAction.create(primrose, gear, throwable)

	assert_eq(specific.action.threat_distance(specific), 2,
		'Fixture: it is still a Heavy melee weapon, so its THREAT is widened.')
	assert_eq(specific.action.thrown_distance(specific), 3,
		'But its printed thrown range is untouched: a threat_range buff cannot reach it (ruling 13).')

	# And the same weapon actually THROWN - threat 0 - keeps that thrown range too.
	var thrown := PrimroseFixture.thrown_variant(specific)
	assert_eq(thrown.action.thrown_distance(thrown), 3, 'Thrown, it still reaches exactly 3.')
	assert_eq(thrown.action.get_target_range(thrown), 3,
		'And get_target_range reads the THROWN value once threat is 0 (action_attack_weapon.gd:198-201) '
		+ '- so the widened threat never reaches the player as a throw range.')
