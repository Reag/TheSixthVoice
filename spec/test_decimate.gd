# DECIMATE - RAGE's face 1 (SP1 Task 7).
#
#   "1 Decimate: A Burst 1 area around you becomes difficult terrain and your critical hits deal +3
#    bonus damage."
#
# TWO HALVES, AND THEY SHARE NOTHING. The ground is a laid MARKER (the Vauban's Maar shape, ruling 8)
# carrying a PassiveTerrainZone and an expiry reaction of its own; the crit bonus is a
# BONUS_DAMAGE_SPECIFIC BuffDamage with require_crit (ruling 9).
#
# THE CRATER'S LIFETIME IS THE MARKER'S OWN TURN START. Deployables get a virtual NEW_TURN core
# alongside their owner - PRE at event_turn_start.gd:19-21, POST at :57-59 - and the owner's own POST
# roll is queued at :56, so the old crater's PRE runs BEFORE the new roll can lay another one. That
# ordering is why the expiry is a reaction on the crater rather than a lifetime on a buff.
#
# THE DICE, AND WHY THE NUMBERS BELOW ARE WHAT THEY ARE. Every weapon attack rolls its damage dice
# TWICE - once into hit_rolls and once into crit_rolls (attack_util.gd:250-251) - whether or not it
# crits, and the crit value is the highest `count` of the two sets (:255-257). mw_tactical_melee_weapon
# is 1d6+2, so a queue of [d20, 6, 1] gives hit = 6+2 = 8 and crit = max(6,1)+2 = 8. The chip's
# damage_dice is the STRING "3", which processes to {count 0, dietype 1, bonus 3} and rolls NOTHING -
# so it adds exactly 3 and pops no entry. 11 against 8 is the whole measurement.
#
# THE TARGET IS A 200 HP, 0-ARMOR DUMMY, so the numbers are the weapon's.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_decimate.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const LEOLETH_TILE := Vector2i(6, 6)
## Adjacent, so one melee target serves every attack case - and it stands INSIDE the crater, which is
## fine: difficult terrain is a factionless tile property and costs the Leoleth nothing to stand in.
const TARGET_TILE := Vector2i(7, 6)
## Two tiles out: outside a Blast 1 centred on the Leoleth.
const OUTSIDE_TILE := Vector2i(8, 6)
## Where the target waits out a rage() cycle, six tiles from the Leoleth - see park_the_target().
const PARKED_TILE := Vector2i(12, 6)

const D20_CRITS := 20
const D20_HITS := 19
## hit_rolls then crit_rolls, in that order (attack_util.gd:250-251).
const DAMAGE_HIGH := 6
const DAMAGE_LOW := 1
## 1d6+2 with a 6 showing: 8, hit or crit.
const BASE_DAMAGE := 8
const CRIT_BONUS := 3

var game:Gamemaster
var leoleth:Unit
var target:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	target = LeolethFixture.create_hostile(game, TARGET_TILE)
	LeolethFixture.arm_melee(leoleth)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The surface terrain a mover would actually price - ground plus every unit-projected zone. The mod's
## shared Terrain helper names this the one accessor to use (res/content/gear/shared/terrain/terrain.gd)
## and the pathfinder reads exactly it (pathfinder.gd:94-95).
func difficult_at(tile:Vector2i) -> bool:
	return game.map.get_surface_terrain_at(tile).is_difficult()

## Stand the target out of melee reach, so the Leoleth's OWN Toe To Toe trait does not swing at it
## while a rage() cycle ends the turn - and put it back afterwards.
##
## MEASURED AT TASK 7, and it cost a whole run to find. LeolethFixture.rage() ends the Leoleth's turn
## (leoleth_fixture.gd:322) and this frame carries Toe To Toe permanently: an END_TURN PRE reaction
## that Skirmishes for free with an unused QUICK melee weapon whenever the Leoleth has spent no
## movement (SP1 Task 2). arm_melee() in before_each supplies exactly such a weapon, so every rage()
## in this spec fired a free extra attack on the target - worth a random 0-8 damage, because rage()
## sets the cheat queue only AFTER end_turn returns. Departure 15's reach clause is the off switch:
## a weapon that can reach nothing is never offered, so parking the target six tiles out shuts the
## gate without touching the trait.
##
## UnitTile.move_to, not a movement event: nothing is spent and no engagement is evaluated, so the
## Leoleth's own speed - which is Toe To Toe's other gate - is untouched either way.
func park_the_target() -> void: LeolethFixture.step(target, PARKED_TILE)
func unpark_the_target() -> void: LeolethFixture.step(target, TARGET_TILE)

func the_burst_one_tiles() -> Array[Vector2i]:
	var tiles:Array[Vector2i] = []
	for dx:int in [-1, 0, 1]:
		for dy:int in [-1, 0, 1]: tiles.append(LEOLETH_TILE + Vector2i(dx, dy))
	return tiles

# ---------------------------------------------------------------- the wiring

func test_the_crit_chip_is_wired_as_ruling_9_says():
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.DECIMATE_CHIP)
	assert_not_null(buff, '%s loads as a Buff.' % LeolethFixture.DECIMATE_CHIP)
	if buff == null: return
	assert_true(buff is BuffDamage, 'It is a BuffDamage.')
	if not (buff is BuffDamage): return
	assert_eq(buff.to, Buff.TO.BONUS_DAMAGE_SPECIFIC,
		'The SPECIFIC channel: require_crit is honoured only against an AttackRoll in context.object '
		+ '(buff_damage.gd:20, :26), and only that channel supplies one per target.')
	assert_eq(buff.damage_dice, '3', 'Three flat - a string with no dice in it, so it rolls nothing.')
	assert_true(buff.require_crit, 'On a CRIT only.')
	assert_false(buff.require_hit, 'require_hit is redundant beside require_crit and is left off.')
	assert_true(buff.inherit_type_from_attack, 'The bonus is the weapon\'s own damage type.')
	assert_false(buff.can_apply_to_tech_attacks, 'And a tech crit gets nothing (ruling 9, recorded).')
	assert_eq(buff.until, Lancer.UNTIL.START_OF_TURN, 'It lasts until the start of the next turn.')
	assert_false(buff.hide_from_player, 'VISIBLE: it is one of the six face chips.')

func test_the_marker_frame_and_its_two_traits_are_registered():
	var dep:Frame = ContentLibrary.get_mech_frame(LeolethFixture.DECIMATE_FRAME_ID)
	assert_not_null(dep, '%s loads as a Frame.' % LeolethFixture.DECIMATE_FRAME_ID)
	if dep == null: return
	assert_eq(dep.entity_type, Frame.ENTITY.MARKER,
		'A MARKER, not an OBJECT: a hole in the ground takes no attacks and blocks no line of sight, '
		+ 'and PassiveAura.update_unit skips markers outright (passive_aura.gd:25).')
	assert_false(dep.is_obstruction, 'And it obstructs nothing.')
	assert_true(dep.is_deactivated_on_owner_death,
		'THE ONE LINE THAT DIFFERS FROM THE MAAR: left at its default TRUE (frame.gd:65), so the '
		+ 'crater dies with the Leoleth - ruling 8.')
	var trait_ids:Array[StringName] = []
	for kit:Kit in dep.traits: trait_ids.append(kit.compcon_id)
	assert_eq(trait_ids, [LeolethFixture.DECIMATE_ZONE_ID, LeolethFixture.DECIMATE_EXPIRY_ID] as Array[StringName],
		'It carries the terrain zone and its own expiry, in that order.')

func test_the_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['frame.dep_decimate.name', 'gear.mt_decimate_terrain.name',
			'gear.buff_rage_decimate_crit.name', 'gear.buff_rage_decimate_crit.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.buff_rage_decimate_crit.name'), 'Decimate', 'The chip is named off the table.')
	assert_eq(X.tr('gear.buff_rage_decimate_crit.effect'),
		'A |Burst| 1 area around you becomes |difficult terrain| and your |critical hits| deal +3 |bonus damage|.',
		'And its effect row is that face\'s line from the table, verbatim.')

# ---------------------------------------------------------------- the ground

func test_a_one_lays_a_crater_under_the_leoleth_and_hangs_the_chip():
	assert_null(LeolethFixture.marker(game), 'fixture: no crater before the roll.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_DECIMATE)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.DECIMATE_CHIP), 'The crit chip landed.')
	var crater:Unit = LeolethFixture.marker(game)
	assert_not_null(crater, 'And a crater was laid.')
	if crater == null: return
	assert_eq(crater.tile(), LEOLETH_TILE, 'Under the Leoleth, where it stood at the roll.')

func test_the_burst_one_around_it_becomes_difficult_terrain():
	# BLAST 1 CENTRED ON A SIZE-1 UNIT'S TILE IS THE CARD'S BURST 1 EXACTLY (ruling 8). The two
	# patterns differ only for an origin with a footprint: AoeCalculator.burst iterates
	# range(-radius, center_size + radius) and blast iterates range(-radius, radius + 1), which is the
	# same nine tiles when center_size is 1 - and a crater has no footprint to project from, which is
	# why the Maar uses BLAST too.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_DECIMATE)
	for tile:Vector2i in the_burst_one_tiles():
		assert_true(difficult_at(tile), '%s is difficult ground.' % tile)
	assert_false(difficult_at(OUTSIDE_TILE), 'And two tiles out is not - the blast is radius 1.')

func test_the_crater_is_factionless_and_owned_by_the_leoleth():
	# Terrain.lay builds the unit with Faction.NONE and then calls UnitAction.set_deployable_owner
	# (terrain.gd's lay body). FACTIONLESS matters: a crater on the player's side would be a hostile
	# character to the AI and a target for everything.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_DECIMATE)
	var crater:Unit = LeolethFixture.marker(game)
	assert_not_null(crater, 'fixture: the crater landed.')
	if crater == null: return
	assert_eq(crater.get_faction(), Faction.NONE, 'It belongs to no side.')
	assert_eq(crater.get_owner_unit(), leoleth, 'But the Leoleth is recorded as its owner.')
	assert_false(crater.is_character(), 'And it is not a character - nothing on this frame answers to it.')

func test_the_crater_dies_at_the_leoleths_next_turn_start_and_the_ground_clears():
	# THE LIFETIME, and the ORDER inside it. The crater's own NEW_TURN PRE runs at
	# event_turn_start.gd:19-21, and the owner's NEW_TURN POST - the roll that could lay a NEW crater -
	# is queued at :56. So the old one is always gone before the new one lands, with no special case
	# for rolling a 1 twice.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_DECIMATE)
	assert_not_null(LeolethFixture.marker(game), 'fixture: the crater is down.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_REACH)
	assert_null(LeolethFixture.marker(game), 'It died at the Leoleth\'s next turn start.')
	for tile:Vector2i in the_burst_one_tiles():
		assert_false(difficult_at(tile), '%s is clean ground again.' % tile)

func test_the_crater_dies_with_the_leoleth():
	# is_deactivated_on_owner_death is left at its default TRUE, and
	# EventService.remove_unit_from_game queues event_unit_die on every owned MARKER that has it
	# (event_service.gd:56-63). This is the ONE line where Decimate differs from the Vauban's Maar,
	# which sets it false so the crater outlives its owner.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_DECIMATE)
	assert_not_null(LeolethFixture.marker(game), 'fixture: the crater is down.')
	await LeolethFixture.kill(game, leoleth)
	assert_null(LeolethFixture.marker(game), 'The crater died with its owner.')

func test_the_chip_is_gone_at_the_next_turn_start():
	# THE BEHAVIOURAL PROOF OF TASK 6's POST, and the reason that task's mutation 3 was reported as
	# under-determined. Every face chip is until = START_OF_TURN, which handle_starting_unit clears at
	# event_turn_start.gd:76 - between the PRE await (:14) and the POST queue (:56). At POST the
	# previous turn's chip has already been cleared and the new one survives; at PRE the chip would be
	# applied and then wiped in the same event.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_DECIMATE)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.DECIMATE_CHIP), 'fixture: the chip is held.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_REACH)
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.DECIMATE_CHIP),
		'And the previous face\'s chip is gone - which only POST can deliver.')

# ---------------------------------------------------------------- the crit

func test_a_crit_deals_three_more_and_a_plain_hit_does_not():
	# ONE TEST FOR BOTH, because the two queues differ by exactly one number and the pair is the claim.
	park_the_target()
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_DECIMATE,
		[D20_CRITS, DAMAGE_HIGH, DAMAGE_LOW] as Array[int])
	unpark_the_target()
	assert_eq(target.current_damage(), 0,
		'fixture: Toe To Toe did not swing during the rage cycle - see park_the_target().')
	await SpecFactory.use_solo(game, leoleth, LeolethFixture.MELEE_KIT, target)
	assert_eq(target.current_damage(), BASE_DAMAGE + CRIT_BONUS,
		'A crit deals 1d6+2 (8 with a 6 showing) plus the chip\'s flat 3.')

	# A SECOND SWING IN THE SAME TURN, as a freebie, so the per-turn soft limit does not silently eat
	# it (action.gd:161-163). Pair it with a real assertion that it happened - which the number is.
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.assign([D20_HITS, DAMAGE_HIGH, DAMAGE_LOW] as Array[int])
	await SpecFactory.use_solo(game, leoleth, LeolethFixture.MELEE_KIT, target, [Action.FLAG.AS_FREEBIE])
	assert_eq(target.current_damage(), BASE_DAMAGE + CRIT_BONUS + BASE_DAMAGE,
		'And a plain HIT adds only the weapon\'s 8 - require_crit refused the bonus.')

func test_a_crit_without_the_chip_gets_nothing():
	# THE CONTROL. Without it, "a crit deals 11" says nothing about the chip: it might simply be what a
	# crit with this weapon deals. Same queue, same weapon, no RAGE.
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.DECIMATE_CHIP), 'fixture: no chip.')
	await LeolethFixture.open_turn(game, leoleth)
	LeolethFixture.queue([D20_CRITS, DAMAGE_HIGH, DAMAGE_LOW])
	await SpecFactory.use_solo(game, leoleth, LeolethFixture.MELEE_KIT, target)
	assert_eq(target.current_damage(), BASE_DAMAGE, 'A bare crit deals the weapon\'s 8 and no more.')
