# GREENLIGHT PROJECTION (Leoleth rank III, design ruling 18):
#
#   "Choose one MELEE weapon: 1/round, after you hit a character with this weapon, you take 1 Burn
#    and the target takes 3 Burn."
#
#   Flavour: "Split the sun with thy furious blows!"
#
# THE DDMR'S SHAPE VERBATIM (res/content/gear/ssc/systems/wm_ddmr/): a Kit whose only passive is a
# PassiveWeaponMod carrying ONE on_hit_effects entry, and an OnHitEffect subclass whose should_abort
# IS the round limit. PassiveWeaponMod.on_hit_effects is collected and fired unconditionally beside
# the weapon's own effects (event_unit_attack.gd:43-45), already scoped to the weapon the mod is
# fitted to, so there is no per-passive gate upstream of should_abort's own true/false.
#
# THE COUNTER LIVES ON THE MOD'S OWN GearCore, not the weapon's: equip_weapon_mod appends the mod to
# `systems` (loadout_core.gd:356-362) and every full_repair rebuilds compcon_id_to_gear from
# get_all_gear(), so unit.get_gear(&'wm_greenlight_projection') resolves it exactly as any other
# equipped system. test_the_units_own_get_gear_resolves_the_fitted_mod is the measurement that
# proves it rather than trusting it - a null read there would leave the gate permanently OPEN or
# permanently CLOSED with no error either way.
#
# BURN IGNORES ARMOR, which is what makes "you take 1 Burn" mean anything on an armor-1 frame:
# damage_modifications.gd:89-90 exempts HEAT and BURN from the armor subtraction outright. The
# number therefore lands whole, and event_unit_damage.gd:121-122 adds it to state.burn as well as
# dealing it.
#
# "A CHARACTER" IS is_character() - a drone included (rulings.md, mod-wide row of 2026-09-27,
# reversing row 301/ruling 22): unit.gd:116-119. FIX (2026-09-22): neither should_abort nor on_hit
# checked this before, so a hit on a non-character (a wreck, a barrel) both burned it and silently
# spent the 1/round against a real mech later that round.
# test_hitting_a_drone_burns_it_and_spends_the_round below is the measurement, using a DRONE
# deliberately rather than an inert OBJECT - a drone is a character and an object is not, so the two
# now read differently and the test proves which predicate the gate actually uses.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_greenlight_projection.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const LEOLETH_TILE := Vector2i(6, 6)
const VICTIM_TILE := Vector2i(7, 6)
const DRONE_TILE := Vector2i(6, 7) ## also adjacent to LEOLETH_TILE; distinct from VICTIM_TILE so both can exist at once

const TARGET_BURN := 3
const SELF_BURN := 1

var game:Gamemaster
var leoleth:Unit
var victim:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	victim = LeolethFixture.create_hostile(game, VICTIM_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ------------------------------------------------------------------ helpers

## An attack the Leoleth makes and lands: [d20, then 4s]. A damage roll pops TWO dice - the hit
## column and the crit column - so a uniform tail is the only readable way to cheat one.
func queue_a_hit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var rolls:Array[int] = [19]
	for i:int in 60: rolls.append(4)
	Dice.CHEAT_ROLL_QUEUE.assign(rolls)

func queue_a_miss() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var rolls:Array[int] = [1]
	for i:int in 60: rolls.append(4)
	Dice.CHEAT_ROLL_QUEUE.assign(rolls)

func mod_kit() -> Kit: return ContentLibrary.get_kit(LeolethFixture.GREENLIGHT_ID)

func weapon_mod_passive() -> PassiveWeaponMod:
	var kit:Kit = mod_kit()
	if not Kit.is_valid(kit): return null
	# get_passives is typed Array[Passive] whatever it filters for (kit.gd:157), so the narrowing
	# happens here - an Array[PassiveWeaponMod] local would not even PARSE.
	var found:Array[Passive] = kit.get_passives(PassiveWeaponMod)
	return found[0] as PassiveWeaponMod if not found.is_empty() else null

## Arm the Leoleth with the plain vanilla MAIN melee weapon and fit the mod to it.
func arm_and_fit() -> GearCore:
	var weapon := LeolethFixture.arm_melee(leoleth)
	LeolethFixture.fit_greenlight(leoleth, weapon)
	return weapon

## One swing with the turn already open, so nothing is cycled and Toe To Toe never gets its
## END_TURN PRE offer (see test_automatic_retaliation.gd's spend_a_space header - a free Skirmish
## with this same weapon would be a second hit and a second round's worth of burn).
func swing(flags:Array = []) -> void:
	await SpecFactory.use_solo(game, leoleth, LeolethFixture.MELEE_KIT, victim, flags)

# ------------------------------------------------------------------ the wiring

func test_the_kit_is_a_unique_mod_costing_two_sp():
	var kit:Kit = mod_kit()
	assert_true(Kit.is_valid(kit), '%s is in the kits index.' % LeolethFixture.GREENLIGHT_ID)
	if not Kit.is_valid(kit): return
	assert_eq(kit.system_tags, 1, 'UNIQUE (kit.gd:30).')
	assert_eq(kit.sp_cost, 2, 'SP 2, off the sheet.')
	assert_true(kit.actions.is_empty(), 'No actions of its own - a mod is all passive.')

func test_it_fits_melee_weapons_of_every_size():
	var mod := weapon_mod_passive()
	if mod == null: return fail_test('the Kit carries a PassiveWeaponMod.')
	# Lancer.WEAPON_TYPE is { CQB, CANNON, MELEE, RIFLE, LAUNCHER, NEXUS } (lancer.gd:107).
	assert_eq(mod.allowed_types, [Lancer.WEAPON_TYPE.MELEE] as Array[int],
		'"Choose one MELEE weapon" - and nothing else.')
	# Lancer.WEAPON_SIZE is { AUX, MAIN, HEAVY, SUPERHEAVY, NONE } (lancer.gd:104). The sheet lists
	# all four, so the mod must not filter on size at all.
	assert_eq(mod.allowed_sizes, [
		Lancer.WEAPON_SIZE.AUX, Lancer.WEAPON_SIZE.MAIN,
		Lancer.WEAPON_SIZE.HEAVY, Lancer.WEAPON_SIZE.SUPERHEAVY,
	] as Array[int], 'Auxiliary, Main, Heavy and Superheavy - every size the card lists.')

func test_the_mod_carries_exactly_one_on_hit_effect_that_fires_on_a_hit():
	var mod := weapon_mod_passive()
	if mod == null: return fail_test('the Kit carries a PassiveWeaponMod.')
	assert_eq(mod.on_hit_effects.size(), 1, 'One effect, which is the whole card.')
	if mod.on_hit_effects.is_empty(): return
	var effect:OnHitEffect = mod.on_hit_effects[0]
	assert_eq(effect.apply_on, OnHitEffect.STAGE.ON_HIT, '"after you HIT a character".')
	assert_false(effect.save_to_avoid, 'No save on this card.')
	assert_true(effect.buffs.is_empty(), 'And no buff in the middle - the burn is dealt directly.')

func test_the_units_own_get_gear_resolves_the_fitted_mod():
	# THE MEASUREMENT, not an assumption: onhit_greenlight.gd's should_abort reads
	# unit.get_gear(&'wm_greenlight_projection') to find its own round counter, and the entire
	# 1/round gate is dead code if that resolves null.
	var weapon := arm_and_fit()
	var fitted:GearCore = leoleth.get_gear(LeolethFixture.GREENLIGHT_ID)
	assert_true(GearCore.is_valid(fitted), 'The mod resolves through the unit\'s own gear cache.')
	if not GearCore.is_valid(fitted): return
	# mod_ids holds the mod's PERSISTENT id, not its compcon_id (gear_core.gd:389-396): a mech may
	# carry two copies of one mod on two weapons, and the kit id could not tell them apart.
	assert_true(weapon.is_weapon_mod_attached(fitted.persistent_id),
		'And the weapon knows it wears it.')
	assert_eq(fitted.from_gear_this_mod_is_attached_to(leoleth.core.loadout), weapon,
		'The link reads the same way round from the mod.')

func test_the_loadout_builder_refuses_a_rifle():
	# The control that proves the mod filters on TYPE. The assault rifle is MAIN-sized, which the
	# size list allows, so only allowed_types can be refusing it.
	var rifle := LeolethFixture.arm_rifle(leoleth)
	var fitted:GearCore = leoleth.core.loadout.equip_weapon_mod(LeolethFixture.GREENLIGHT_ID, rifle)
	assert_null(fitted, 'RIFLE is not MELEE - equip_weapon_mod refuses it (loadout_core.gd:344-351, '
		+ 'gated on PassiveWeaponMod.is_applicable_to).')
	assert_true(rifle.mod_ids.is_empty(), 'And the rifle carries no mod at all.')

func test_it_fits_a_superheavy_melee_weapon():
	var drill := LeolethFixture.equip(leoleth, LeolethFixture.SUPERHEAVY_MELEE)
	var fitted:GearCore = leoleth.core.loadout.equip_weapon_mod(LeolethFixture.GREENLIGHT_ID, drill)
	assert_true(GearCore.is_valid(fitted), 'SUPERHEAVY is on the card\'s list, unlike the DDMR\'s.')

# ------------------------------------------------------------------ the burn

func test_a_hit_burns_the_target_three_and_the_leoleth_one():
	arm_and_fit()
	await LeolethFixture.open_turn(game, leoleth)
	queue_a_hit()
	await swing()
	assert_eq(victim.state.burn, TARGET_BURN, '"the target takes 3 Burn".')
	assert_eq(leoleth.state.burn, SELF_BURN,
		'"you take 1 Burn" - and it lands whole on an armor-1 frame, because burn ignores armor '
		+ '(damage_modifications.gd:89-90).')

func test_a_miss_burns_nobody():
	arm_and_fit()
	await LeolethFixture.open_turn(game, leoleth)
	queue_a_miss()
	await swing()
	assert_eq(victim.state.burn, 0, 'No hit, no burn for the target...')
	assert_eq(leoleth.state.burn, 0, '...and none for the Leoleth either.')

func test_a_second_hit_in_the_same_round_burns_nobody_further():
	arm_and_fit()
	await LeolethFixture.open_turn(game, leoleth)
	queue_a_hit()
	await swing()
	assert_eq(victim.state.burn, TARGET_BURN, 'fixture: the first hit burned.')
	var damage_after_first:int = victim.core.get_health_max() - victim.core.current.health

	# THE VACUITY GUARD, AS FREEBIE: without Action.FLAG.AS_FREEBIE the per-turn soft limit silently
	# refuses a second activation of the same Kit in the same turn (action.gd:161-163) and the await
	# returns normally with nothing logged, so "no more burn" would pass because no second swing
	# happened at all. The damage assertion below is what discriminates the two.
	queue_a_hit()
	await swing([Action.FLAG.AS_FREEBIE])
	assert_gt(victim.core.get_health_max() - victim.core.current.health, damage_after_first,
		'VACUITY GUARD: the second swing really landed.')
	assert_eq(victim.state.burn, TARGET_BURN, '"1/round" - and no more burn for the target...')
	assert_eq(leoleth.state.burn, SELF_BURN, '...nor a second point for the Leoleth.')

## A drone is a character (rulings.md, mod-wide row of 2026-09-27, reversing row 301/ruling 22):
## unit.gd:116-119. Uses a DRONE deliberately, not LeolethFixture.create_hostile_object: an OBJECT
## still fails is_character(), so the two now read differently and this proves which predicate
## onhit_greenlight.gd's gate actually uses.
func test_hitting_a_drone_burns_it_and_spends_the_round():
	var drone:Unit = LeolethFixture.create_drone(game, DRONE_TILE, Faction.AI_ENEMY)
	assert_true(drone.is_character(), 'fixture: a drone IS a character to the engine...')
	assert_false(drone.is_actor(), '...though still not an actor - attribution is unaffected.')
	arm_and_fit()
	await LeolethFixture.open_turn(game, leoleth)
	queue_a_hit()
	await SpecFactory.use_solo(game, leoleth, LeolethFixture.MELEE_KIT, drone, [])
	assert_eq(drone.state.burn, TARGET_BURN,
		'A drone is a character (ruling 2026-09-27), so the hit burns it like any other target.')
	assert_eq(leoleth.state.burn, SELF_BURN, 'And the Leoleth takes its own point too.')

	# THE VACUITY GUARD, as in test_a_second_hit_in_the_same_round_burns_nobody_further: without
	# Action.FLAG.AS_FREEBIE the per-turn soft limit refuses a second activation of the same Kit this
	# turn outright (action.gd:161-163) and the swing below would prove nothing.
	queue_a_hit()
	await swing([Action.FLAG.AS_FREEBIE])
	assert_eq(victim.state.burn, 0,
		'"1/round" - the drone already spent it, so a REAL character hit right after gets nothing.')
	assert_eq(leoleth.state.burn, SELF_BURN, 'And the Leoleth takes no second point either.')

func test_the_next_round_burns_again():
	arm_and_fit()
	await LeolethFixture.open_turn(game, leoleth)
	queue_a_hit()
	await swing()
	assert_eq(victim.state.burn, TARGET_BURN, 'fixture: the first hit burned.')

	# THE LEOLETH'S OWN TURN, not a global event_round_new: GearCore.uses_this_round is cleared by
	# reset_per_round_usage inside new_turn_refresh, which runs for the STARTING unit only
	# (unit_action.gd:78, :87-88).
	#
	# The Leoleth's movement is spent first so Toe To Toe does not take its free Skirmish at
	# END_TURN PRE - that swing carries this very weapon, and it would spend the new round's charge
	# before the test's own hit could.
	leoleth.core.current.speed -= 1
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, leoleth)

	queue_a_hit()
	await swing()
	assert_eq(victim.state.burn, TARGET_BURN * 2, 'A new round buys the target another 3...')
	assert_eq(leoleth.state.burn, SELF_BURN * 2, '...and the Leoleth another 1.')

func test_the_counter_is_written_under_the_key_the_card_is_named_for():
	# The gate reads and writes one string on the mod's own GearCore. If the reader and the writer
	# ever disagree the card becomes unlimited, silently - so the key itself is pinned.
	arm_and_fit()
	var fitted:GearCore = leoleth.get_gear(LeolethFixture.GREENLIGHT_ID)
	if not GearCore.is_valid(fitted): return fail_test('the mod is fitted.')
	assert_eq(fitted.get_uses_this_round_alt(LeolethFixture.GREENLIGHT_USAGE_KEY), 0,
		'Nothing spent before the first hit.')
	await LeolethFixture.open_turn(game, leoleth)
	queue_a_hit()
	await swing()
	assert_eq(fitted.get_uses_this_round_alt(LeolethFixture.GREENLIGHT_USAGE_KEY), 1,
		'And exactly one use recorded after it.')
	assert_eq(fitted.get_uses_this_turn_alt(LeolethFixture.GREENLIGHT_USAGE_KEY), 0,
		'increment_action_usage\'s second argument is FALSE - nothing reads a per-TURN count under '
		+ 'this key, and writing one would be a third counter nobody reads.')

func test_an_unmodded_weapon_burns_nobody():
	# The control for the whole file: the same weapon, the same swing, no mod fitted.
	LeolethFixture.arm_melee(leoleth)
	await LeolethFixture.open_turn(game, leoleth)
	queue_a_hit()
	await swing()
	assert_gt(victim.core.get_health_max() - victim.core.current.health, 0, 'The swing landed...')
	assert_eq(victim.state.burn, 0, '...and burned nobody, because nothing was fitted.')

# ------------------------------------------------------------------ the card

func test_the_card_text_is_the_lcp_verbatim():
	var id:StringName = LeolethFixture.GREENLIGHT_ID
	assert_eq(X.tr('gear.%s.name' % id), 'GreenLight Projection', 'The name off the sheet.')
	assert_eq(X.tr('gear.%s.flavor' % id), 'Split the sun with thy furious blows!',
		'The LCP\'s own one-line flavour.')
	# assert_eq against the FULL row, not .contains() fragments (fixed 2026-09-22):
	# check_content.py cannot see a weapon mod at all, so this is the ONLY pin on this text, and
	# three .contains() checks would still pass if the row were rewritten to swap the burn numbers
	# (e.g. "you take 3 Burn and the target takes 1 Burn" still contains '1/round' and '3 |Burn|').
	# The pipes are the row exactly as authored (localization/localizations.csv:530) - do not strip
	# them, tr() does not either (precedent: test_aaaa_difficulty.gd:94, test_in_triumvirate.gd:626).
	assert_eq(X.tr('gear.%s.effect' % id),
		'Choose one |melee| weapon: 1/round, after you hit a character with this weapon, you take 1 '
		+ '|Burn| and the target takes 3 |Burn|.',
		'The LCP\'s effect row, verbatim, pipes included.')
