# FUSIONBLEED SHURIKEN (Koremasa rank III, design section 5, ruling 31):
#
#   Auxiliary Melee, THROWN 5, HEAT SELF 1, 1 Energy + 1 Heat, Threat 1.
#   "On hit: You may also make a secondary attack against a different character within range 5 of the
#    target. Any further hits cannot repeat this effect. Attacks made this way do not cause you to take
#    any additional heat"
#
# THE ARC PROJECTOR'S SHAPE (action_arc_projector.gd:18-53): on a hit the action duplicates itself,
# marks the copy in modified_by_variants (the secondary marker plus the first target's persistent id),
# asks for a target from a PROXY standing on the first target, and queues an event_unit_attack that
# reuses the declared summary at Priority.ATTACK.secondary_attack. A directly queued attack never pays
# self-heat (unit_action.gd:227-229), which is the card's last sentence for free.
#
# THE DICE. Every number on this weapon is flat ("1", "1", "1"), so the only rolls are d20s: the
# primary's attack, then the secondary's. The fixture's tail of 3s misses evasion 10, so a test that
# names only the primary's d20 has a secondary that MISSES - and each test names what it needs.
#
# THE SECONDARY'S PROMPT is a compcon plan whose `using` carries the marked action
# (testkit/mod_choice_responder.gd records every plan prompt). The stock responder answers it with the
# first targetable unit from the proxy's own targeting set, so geometry, not a scripted answer, decides
# who the secondary hits - which is what makes the range claims below real.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_fusionbleed_shuriken.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')

const KOREMASA_TILE := Vector2i(3, 5)
## Adjacent: the first target, at threat 1.
const FIRST_TILE := Vector2i(4, 5)
## Five from the first target, SIX from the Koremasa: only a range measured from the target reaches it.
const SECOND_TILE := Vector2i(9, 5)
## Six from the first target: beyond the secondary's reach.
const TOO_FAR_TILE := Vector2i(10, 7)
## Four from the second target, nine from the first: only a CHAINED third attack could reach it.
const THIRD_TILE := Vector2i(13, 5)
## Five from the Koremasa: the thrown profile's edge.
const THROWN_TILE := Vector2i(8, 5)

const HIT := 15
const MISS := 1

var game:Gamemaster
var responder
var koremasa:Unit

## ONE FRAME FIRST, AND IT IS LOAD-BEARING. A test that never awaits (the profile tests) ends in the
## same frame it began, so the responder add_child_autoqfree gave it is only QUEUED for freeing when
## the next test starts - still connected to the choice bus. Measured: the first attacking test after
## two synchronous ones saw 11 on_choice_request listeners against 9 in every later test, both stale
## responders answered its variant prompt, and the whole activation ran twice (two attack_declared
## events, two proxies, the first target hit twice).
func before_each() -> void:
	await get_tree().process_frame
	var pair := Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	Fixture.equip(koremasa, Fixture.SHURIKEN_ID)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func weapon() -> ActionAttackWeapon:
	var kit:Kit = ContentLibrary.get_kit(Fixture.SHURIKEN_ID)
	if not Kit.is_valid(kit): return null
	return kit.get_action(Fixture.SHURIKEN_ACTION) as ActionAttackWeapon

## Throw or swing at `target` from the Koremasa's open turn with these d20s, then a tail of 3s.
func strike(target:Unit, d20s:Array[int], flags:Array = [], variant:String = '') -> void:
	await Fixture.open_turn(game, koremasa)
	Fixture.queue(d20s)
	await SpecFactory.use_solo(game, koremasa, Fixture.SHURIKEN_ID, target, flags, variant)

## Every plan prompt raised for a SECONDARY (the marked duplicate), in order.
func secondary_prompts() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	for info:Dictionary in responder.plan_prompts:
		var using = info.get('using')
		if using is SpecificAction and using.action != null and \
				using.action.modified_by_variants.has(Fixture.SHURIKEN_SECONDARY):
			found.append(info)
	return found

func lost(unit:Unit, before:int) -> int: return before - unit.core.current.health

## The proxy is removed from the map the moment the pick returns (target_action_util.gd:276), so its
## targeting can only be read WHILE the secondary's prompt is open. The base responder awaits a frame
## before answering, so this handler runs first. Fills `seen` with the targetable tiles and
## `can_target` with {unit: bool} for each of `units`.
func watch_the_secondary(seen:Dictionary, units:Array[Unit]) -> void:
	responder.plan_prompt.connect(func(info:Dictionary) -> void:
		var using = info.get('using')
		if not (using is SpecificAction and using.action.modified_by_variants.has(Fixture.SHURIKEN_SECONDARY)):
			return
		seen.tiles = UnitTargeting.get_tiles_targetable(using)
		var verdicts := {}
		for unit:Unit in units: verdicts[unit] = using.action.can_target_unit(unit, using)
		seen.can_target = verdicts
		seen.threat = using.action.threat
		seen.ignores_cover = using.action.ignores_cover(using.to_context({}))
	)

# ---------------------------------------------------------------- the profile

func test_the_shuriken_is_an_aux_melee_energy_weapon_thrown_five():
	var kit:Kit = ContentLibrary.get_kit(Fixture.SHURIKEN_ID)
	assert_true(Kit.is_valid(kit), 'mw_fusionbleed_shuriken is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.sp_cost, 0, 'SP 0.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	var attack := weapon()
	assert_not_null(attack, 'The action is action_fusionbleed_shuriken, an ActionAttackWeapon.')
	if attack == null: return
	assert_eq(attack.weapon_size, Lancer.WEAPON_SIZE.AUX, 'Auxiliary.')
	assert_eq(attack.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Melee.')
	assert_eq(attack.damage_type, Lancer.DAMAGE_TYPE.ENERGY, 'Energy.')
	assert_eq(attack.damage_dice, '1', '1 Energy.')
	assert_eq(attack.threat, 1, 'Threat 1.')
	assert_eq(attack.thrown, 5, 'THROWN 5.')
	assert_eq(attack.tags, [&'thrown'] as Array[StringName], 'THROWN and no other weapon tag.')
	assert_eq(attack.self_heat_dice, '1', 'HEAT SELF 1.')

func test_the_shuriken_also_deals_one_heat():
	var attack := weapon()
	assert_not_null(attack, 'fixture: the action loads.')
	if attack == null: return
	assert_eq(attack.additional_damage_values.size(), 1, 'One additional damage value.')
	if attack.additional_damage_values.is_empty(): return
	var extra:DamageValue = attack.additional_damage_values[0]
	assert_eq(extra.dice, '1', '1...')
	assert_eq(extra.type, Lancer.DAMAGE_TYPE.HEAT, '...Heat.')

# ---------------------------------------------------------------- the secondary

func test_a_hit_makes_a_secondary_against_a_character_five_from_the_target():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var second := Fixture.create_hostile(game, SECOND_TILE)
	var first_hp := first.core.current.health
	var second_hp := second.core.current.health
	await strike(first, [HIT, HIT])
	assert_eq(lost(first, first_hp), 1, 'The first target takes 1 Energy.')
	assert_eq(secondary_prompts().size(), 1, 'One secondary was offered.')
	assert_eq(lost(second, second_hp), 1,
		'The secondary hit a character SIX from the Koremasa and five from the target: 1 Energy.')
	assert_eq(second.core.current.heat, 1, 'And its 1 Heat.')

func test_the_secondary_rolls_its_own_attack():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var second := Fixture.create_hostile(game, SECOND_TILE)
	var second_hp := second.core.current.health
	await strike(first, [HIT, MISS])
	assert_eq(secondary_prompts().size(), 1, 'LIVENESS: the secondary was offered.')
	assert_eq(lost(second, second_hp), 0, 'A missed secondary deals nothing.')
	assert_eq(second.core.current.heat, 0, 'Not even its Heat.')

func test_the_secondary_reaches_five_from_the_target_and_no_further():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var second := Fixture.create_hostile(game, SECOND_TILE)
	var too_far := Fixture.create_hostile(game, TOO_FAR_TILE)
	var seen := {}
	watch_the_secondary(seen, [])
	await strike(first, [HIT, HIT])
	assert_true(seen.has('tiles'), 'LIVENESS: the secondary was offered.')
	if not seen.has('tiles'): return
	assert_has(seen.tiles, second.tile(), 'Five from the target is in reach.')
	assert_does_not_have(seen.tiles, too_far.tile(), 'Six from the target is not.')

func test_the_secondary_cannot_pick_the_first_target_or_the_koremasa():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var second := Fixture.create_hostile(game, SECOND_TILE)
	var seen := {}
	watch_the_secondary(seen, [first, second, koremasa])
	await strike(first, [HIT, HIT])
	assert_true(seen.has('can_target'), 'LIVENESS: the secondary was offered.')
	if not seen.has('can_target'): return
	assert_true(seen.can_target[second], '"a different character": the second may be picked.')
	assert_false(seen.can_target[first], 'But not the first target again.')
	assert_false(seen.can_target[koremasa], 'Nor the Koremasa itself.')

## Ruling 31 names range 5 but not what kind of attack the secondary is; the build's reading (the
## action's header): a THROW at a character up to 5 away, so threat 0 - Lancer's thrown attack takes
## cover (action_attack_weapon.gd:206-212), where a melee attack at threat would ignore it.
func test_the_secondary_is_a_throw_that_respects_cover():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	Fixture.create_hostile(game, SECOND_TILE)
	var seen := {}
	watch_the_secondary(seen, [])
	await strike(first, [HIT, HIT])
	assert_true(seen.has('threat'), 'LIVENESS: the secondary was offered.')
	if not seen.has('threat'): return
	assert_eq(seen.threat, 0, 'The secondary runs at threat 0: a throw.')
	assert_false(seen.ignores_cover, 'So cover counts against it.')

func test_the_secondary_picks_characters_only():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	Fixture.create_hostile(game, SECOND_TILE)
	var cover := Fixture.FitzgeraldFixture.create_deployable(game, FIRST_TILE + Vector2i(2, 2), 10, 0, 5)
	var seen := {}
	watch_the_secondary(seen, [cover])
	await strike(first, [HIT, HIT])
	assert_true(seen.has('can_target'), 'LIVENESS: the secondary was offered.')
	if not seen.has('can_target'): return
	assert_false(seen.can_target[cover], '"a different CHARACTER": a deployable two from the target is not one.')

func test_a_secondary_hit_offers_no_third():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var second := Fixture.create_hostile(game, SECOND_TILE)
	var third := Fixture.create_hostile(game, THIRD_TILE)
	var third_hp := third.core.current.health
	await strike(first, [HIT, HIT, HIT])
	assert_eq(secondary_prompts().size(), 1, '"Any further hits cannot repeat this effect": one secondary only.')
	assert_eq(lost(third, third_hp), 0, 'The character only a chain could reach is untouched.')

func test_the_koremasa_takes_one_heat_not_two():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var second := Fixture.create_hostile(game, SECOND_TILE)
	var second_hp := second.core.current.health
	var before := Fixture.heat(koremasa)
	await strike(first, [HIT, HIT])
	assert_eq(lost(second, second_hp), 1, 'LIVENESS: the secondary landed.')
	assert_eq(Fixture.heat(koremasa) - before, 1, 'HEAT SELF 1 for the throw, nothing for the secondary.')

func test_a_miss_offers_nothing():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var second := Fixture.create_hostile(game, SECOND_TILE)
	var second_hp := second.core.current.health
	await strike(first, [MISS, HIT])
	assert_eq(secondary_prompts().size(), 0, 'A miss: no secondary.')
	assert_eq(lost(second, second_hp), 0, 'And nobody else is hit.')

func test_no_character_in_reach_raises_no_prompt():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var first_hp := first.core.current.health
	await strike(first, [HIT])
	assert_eq(lost(first, first_hp), 1, 'LIVENESS: the hit landed.')
	assert_eq(secondary_prompts().size(), 0, 'Nobody within 5 of the target: nothing to ask.')

func test_the_secondary_is_optional():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var second := Fixture.create_hostile(game, SECOND_TILE)
	var first_hp := first.core.current.health
	var second_hp := second.core.current.health
	responder.plan_prompt.connect(func(info:Dictionary) -> void:
		var using = info.get('using')
		if using is SpecificAction and using.action.modified_by_variants.has(Fixture.SHURIKEN_SECONDARY):
			responder.abort_all = true
	)
	await strike(first, [HIT, HIT])
	assert_eq(secondary_prompts().size(), 1, 'LIVENESS: the secondary was offered.')
	assert_eq(lost(first, first_hp), 1, 'Cancelling keeps the first hit.')
	assert_eq(lost(second, second_hp), 0, 'And attacks nobody else.')
	assert_true(Unit.is_valid(koremasa), 'And the Koremasa is fine.')

## Ruling 31: the no-chain rule is the shuriken's own marker, NOT Action.FLAG.IS_FOLLOWUP - an
## auxiliary weapon fired as a mount's follow-up already carries that flag (action_attack_weapon.gd:69-72)
## and must still get its secondary.
func test_an_aux_follow_up_still_gets_its_secondary():
	var first := Fixture.create_hostile(game, FIRST_TILE)
	var second := Fixture.create_hostile(game, SECOND_TILE)
	var second_hp := second.core.current.health
	await strike(first, [HIT, HIT], [Action.FLAG.IS_FOLLOWUP])
	assert_eq(secondary_prompts().size(), 1, 'A follow-up throw still offers a secondary.')
	assert_eq(lost(second, second_hp), 1, 'And it lands.')

# ---------------------------------------------------------------- thrown

func test_a_thrown_hit_at_five_offers_a_secondary():
	var target := Fixture.create_hostile(game, THROWN_TILE)
	var second := Fixture.create_hostile(game, THROWN_TILE + Vector2i(4, 0))
	var target_hp := target.core.current.health
	var second_hp := second.core.current.health
	await strike(target, [HIT, HIT], [], 'thrown')
	assert_eq(lost(target, target_hp), 1, 'THROWN 5: the throw lands five away.')
	assert_eq(secondary_prompts().size(), 1, 'A thrown hit offers a secondary too.')
	assert_eq(lost(second, second_hp), 1, 'And it lands.')

func test_the_secondary_leaves_no_second_thrown_weapon():
	var target := Fixture.create_hostile(game, THROWN_TILE)
	var second := Fixture.create_hostile(game, THROWN_TILE + Vector2i(4, 0))
	var second_hp := second.core.current.health
	await strike(target, [HIT, HIT], [], 'thrown')
	assert_eq(lost(second, second_hp), 1, 'LIVENESS: the secondary landed.')
	assert_eq(Fixture.units_of_frame(game, &'dep_thrown_weapon').size(), 1,
		'One shuriken on the ground: the throw spawns it, the secondary does not.')

# ---------------------------------------------------------------- the card

func test_the_card_rows_resolve():
	for key:String in ['gear.mw_fusionbleed_shuriken.name', 'gear.mw_fusionbleed_shuriken.flavor',
			'gear.mw_fusionbleed_shuriken.on_hit']:
		assert_ne(X.tr(key), key, '%s resolves.' % key)
	assert_eq(X.tr('gear.mw_fusionbleed_shuriken.name'), 'Fusionbleed shuriken', 'The name, LCP casing.')
