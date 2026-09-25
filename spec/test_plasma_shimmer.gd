# PLASMA SHIMMER (Koremasa trait, design 1.2 and ruling 17):
#
#   "While it's in the DANGER ZONE, attacks against the Koremasa have +1 Difficulty."
#
# A defender-side BuffBonus on the Koremasa - to = attack_roll_incoming, accuracy -1 - whose gate is
# the Koremasa's own DANGERZONE status, i.e. heat >= half the cap, rounded up: 4 of its 8
# (unit_condition.gd:591-597). EVERY attack, tech attacks included (ruling 17): both go through the
# same AttackRoll.PreAttack.create (event_unit_attack.gd:53), so the one gate covers both.
#
# MEASURED OFF THE ROLL'S OWN BREAKDOWN, the Gravity Well's idiom: PreAttack.create folds an
# ATTACK_ROLL_INCOMING accuracy value into a named AccuracyMod titled buff_core.name_text()
# (attack_roll.gd:182-189). The preview here also carries `map`, which the real roll's context does
# (attack_roll.gd:135) - the gap test_gravity_well.gd's header records does not apply to this gate,
# which reads context.target_unit, but the map is passed anyway so the two contexts differ in nothing
# this buff could read.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_plasma_shimmer.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')

const KOREMASA_TILE := Vector2i(4, 4)
const SHOOTER_TILE := Vector2i(10, 4)
const ALLY_TILE := Vector2i(5, 6)

var game:Gamemaster
var koremasa:Unit
var shooter:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	shooter = Fixture.create_hostile(game, SHOOTER_TILE)
	Fixture.equip(shooter, Fixture.RIFLE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func preview(kit_id:StringName, against:Unit) -> AttackRoll.PreAttack:
	var gear:GearCore = shooter.get_gear(kit_id)
	var specific := SpecificAction.create(shooter, gear, gear.get_solo_action())
	var context := Context.clone(specific.to_context(), {target_unit = against, map = game.map})
	return AttackRoll.PreAttack.create(context)

## How many Plasma Shimmer lines a roll carries, read off the mod list rather than the total.
func shimmer_lines(pre:AttackRoll.PreAttack) -> int:
	var count := 0
	for mod:AttackRoll.AccuracyMod in pre.accuracy_mods:
		if mod.title_key == X.tr('gear.mt_plasma_shimmer.name') and mod.mod == -1: count += 1
	return count

# ---------------------------------------------------------------- wiring

func test_the_trait_is_wired():
	var kit:Kit = ContentLibrary.get_kit(Fixture.SHIMMER_ID)
	assert_true(Kit.is_valid(kit), 'mt_plasma_shimmer is in the kits index.')
	var chip = ContentLibrary.get_buff(Fixture.SHIMMER_BUFF)
	assert_true(chip is BuffBonus, 'buff_plasma_shimmer is a BuffBonus.')
	if not chip is BuffBonus: return
	assert_eq(chip.to, Buff.TO.ATTACK_ROLL_INCOMING, 'On attack rolls made AGAINST its holder.')
	assert_eq(chip.bonus_subtype, Buff.BONUS_SUBTYPE.ACCURACY, 'By accuracy, not a flat bonus.')
	assert_eq(chip.bonus_value, -1, '+1 Difficulty.')
	assert_false(chip.hide_from_player, 'VISIBLE: attack_roll.gd:189 draws base.icon raw beside the -1.')
	assert_eq(chip.until, Lancer.UNTIL.MANUAL, 'MANUAL: the trait owns its lifetime.')

func test_the_chip_is_on_the_koremasa_and_titled_by_the_kit():
	var chips:Array[BuffCore] = UnitCondition.get_buffs(koremasa, Fixture.SHIMMER_BUFF)
	assert_eq(chips.size(), 1, 'The Koremasa wears exactly one chip.')
	if chips.is_empty(): return
	assert_eq(chips[0].name_text(), X.tr('gear.mt_plasma_shimmer.name'),
		'Titled "Plasma Shimmer" off the Kit\'s own name row (Translate.buff falls through to the owner gear).')

# ---------------------------------------------------------------- the gate

func test_below_the_danger_zone_a_weapon_attack_carries_no_line():
	Fixture.set_heat(game, koremasa, 3)
	assert_false(koremasa.has_status(Lancer.STATUS.DANGERZONE), 'fixture: 3 of 8 is not the Danger Zone.')
	assert_eq(shimmer_lines(preview(Fixture.RIFLE, koremasa)), 0, 'No Plasma Shimmer line at 3 heat.')

func test_in_the_danger_zone_a_weapon_attack_is_at_one_difficulty():
	Fixture.set_heat(game, koremasa, 4)
	assert_true(koremasa.has_status(Lancer.STATUS.DANGERZONE), 'fixture: 4 of 8 IS the Danger Zone.')
	assert_eq(shimmer_lines(preview(Fixture.RIFLE, koremasa)), 1, 'One Plasma Shimmer line, -1, at 4 heat.')

func test_in_the_danger_zone_a_tech_attack_is_at_one_difficulty_too():
	# Ruling 17: RAW "attacks". The Gravity Well excluded tech only because its card said "ranged and
	# melee"; this card does not.
	Fixture.set_heat(game, koremasa, 4)
	var tech:GearCore = shooter.get_gear(Fixture.TECH)
	assert_true(GearCore.is_valid(tech) and tech.get_solo_action() is ActionAttackTech,
		'fixture: ms_fragment_signal is basic gear and a tech attack.')
	assert_eq(shimmer_lines(preview(Fixture.TECH, koremasa)), 1, 'The Invade carries the line too.')

func test_below_the_danger_zone_a_tech_attack_carries_no_line():
	Fixture.set_heat(game, koremasa, 3)
	assert_eq(shimmer_lines(preview(Fixture.TECH, koremasa)), 0, 'No line on the Invade at 3 heat.')

func test_leaving_the_danger_zone_drops_the_line_again():
	Fixture.set_heat(game, koremasa, 5)
	assert_eq(shimmer_lines(preview(Fixture.RIFLE, koremasa)), 1, 'In the Danger Zone at 5.')
	Fixture.set_heat(game, koremasa, 0)
	assert_eq(shimmer_lines(preview(Fixture.RIFLE, koremasa)), 0, 'Out again once cooled.')

func test_an_ally_near_a_hot_koremasa_is_not_sheltered():
	# The chip is the Koremasa's own, not an aura. A second unit is never asked about.
	var ally:Unit = Fixture.create_ally(game, ALLY_TILE)
	Fixture.set_heat(game, koremasa, 4)
	assert_false(UnitCondition.has_buff(ally, Fixture.SHIMMER_BUFF), 'The ally wears no chip.')
	assert_eq(shimmer_lines(preview(Fixture.RIFLE, ally)), 0, 'And a shot at the ally carries no line.')

func test_the_koremasas_own_attacks_are_untouched():
	# Defender-side only: a hot Koremasa shooting the hostile does not pay its own trait.
	Fixture.equip(koremasa, Fixture.RIFLE)
	Fixture.set_heat(game, koremasa, 4)
	var gear:GearCore = koremasa.get_gear(Fixture.RIFLE)
	var specific := SpecificAction.create(koremasa, gear, gear.get_solo_action())
	var pre := AttackRoll.PreAttack.create(Context.clone(specific.to_context(), {target_unit = shooter, map = game.map}))
	assert_eq(shimmer_lines(pre), 0, 'The Koremasa\'s own shot carries no Plasma Shimmer line.')
