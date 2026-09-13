# SP2 Task 4: HEAER - the destroying hit that makes the body explode.
#
# Design §3.2, ruling 6. Rules sheet "Rank I":
#   System, SP 2, Limited 3, Unique. "Whenever you destroy a hostile character with a rifle,
#   launcher, or cannon you may expend a charge to make them explode violently. All characters
#   within burst 1 of the destroyed character must make an Agility save or take 1d6+1 AP kinetic
#   damage."
#
# THERE IS NO KILL TRIGGER IN THE ENGINE. ReactionBus.TRIGGER has DEATH, but death is queued a whole
# event later and by then the body is gone and the attack that did it is no longer in hand. The seam
# is a DAMAGE **POST** reaction, and the ordering inside event_unit_damage.gd's execute() is what
# makes a destruction test possible at all:
#
#     ... applies the damage to health ...
#     core.queue_reaction_events(TRIGGER.DAMAGE, TIMING.POST)   <- HEAER runs here
#     queue_structure_or_stress_if_necessary(core, unit)        <- structure is spent AFTER
#
# So at DAMAGE POST the victim's health is already at or below 0 and its structure has NOT yet been
# decremented. That is the exact reading of ruling 6 this file pins:
#   - a MECH is destroyed by this damage when health <= 0 AND current.structure <= 1
#     (event_unit_structure.gd:41 decrements, and dies at 0);
#   - a structureless character, object or deployable is destroyed when health <= 0
#     (queue_structure_or_stress_if_necessary sends every non-mech straight to event_unit_die).
# test_a_hit_that_leaves_structure_offers_nothing is the test that makes that a real gate rather
# than a bare `health <= 0`: same victim, same killing damage, three structure instead of one.
#
# SAVES ARE PINNED THROUGH HaseBlock, NOT THROUGH THE DICE QUEUE - the same trap SP1's
# test_knock_em_down.gd documents at length. The attack ahead of the blast pops an unpredictable
# number of accuracy and damage dice out of the same global Dice.CHEAT_ROLL_QUEUE, so queuing a
# specific d20 for a save would be guessing how many dice the attack ate first. An agi of +-30
# dominates whatever the save's own d20 comes up as. The blast damage die is pinned the other way,
# by a long all-sixes buffer, which is SP1's trick (test_bizarre_cannon.gd:155-164).
#
# TWO BYSTANDERS, ONE PASSING AND ONE FAILING, IN EVERY BLAST TEST. A spec where everything in the
# burst takes damage cannot tell "a save was forced" from "damage was dealt unconditionally"; the
# +30 bystander standing in the same burst and taking nothing is what makes the save real.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_heaer.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const KIT_ID := &'ms_heaer'
const DETONATE_ID := &'action_heaer_detonate'
const LICENSE_ID := &'li_fitzgerald'

## The Fitzgerald's own Cannon, built by SP2 Tasks 1-3. Its SINGLE SHOT profile is weapon_type
## CANNON, which is one of the three types HEAER answers to.
const GUN_ID := &'mw_breech_loading_swivel_gun'
const SINGLE_SHOT_ID := &'action_swivel_single_shot'

## A vanilla MELEE weapon (weapon_type 2, aim_range 0), for the profile HEAER must ignore. Its only
## action is inline on the Kit, so it is fired through SpecFactory.use_solo rather than by action id.
const MELEE_ID := &'mw_tactical_melee_weapon'

## A real vanilla deployable (entity OBJECT, is_deployable true, 10 HP): the structureless branch of
## ruling 6. dep_attack_ground_proxy is deliberately NOT used - it is a MARKER-ish object with
## is_deployable false, and the gun spawns one of its own whenever a shot is aimed at bare ground.
const DEPLOYABLE_FRAME := &'dep_jericho_cover'

const CHARGES := 3

## 1d6+1 AP kinetic with the die cheated to a 6, against a bystander the fixture gives armor 0. The
## exact number is the point: it proves the +1 and the die size are wired, not merely that "some
## damage happened".
const BLAST_DAMAGE := 7

## The confirmation the player is asked. Asserted as TEXT, not as a key, so this also pins that the
## localization row exists and reached the compiled artifact: an unscanned csv would leave tr()
## handing back the raw key and this string would not match.
const CONFIRM_TEXT := 'Expend a HEAER charge?'

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

# The map is the fixture's default 15x9, so x 0..14 and y 0..8.
const FIRE_FROM := Vector2i(4, 4)
const VICTIM_TILE := Vector2i(9, 4)
## Burst 1 of a size-1 victim at (9,4) is the 3x3 block x 8..10, y 3..5. Both bystanders sit in it
## and off the firing line along y = 4, so neither can give the victim cover or eat the shot.
const DOOMED_TILE := Vector2i(9, 3)   # agi -30: always fails the save
const SPARED_TILE := Vector2i(9, 5)   # agi +30: always passes it
## Well outside the burst, and off the firing line.
const BYSTANDER_TILE := Vector2i(4, 8)

## Adjacent to the Fitzgerald, for the melee profile (aim_range 0).
const MELEE_VICTIM_TILE := Vector2i(5, 4)
const MELEE_DOOMED_TILE := Vector2i(5, 3)

var game:Gamemaster
var unit:Unit
var watcher:PromptWatcher

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	unit = FitzgeraldFixture.create_fitzgerald(game, FIRE_FROM)
	# EQUIP EVERYTHING BEFORE TOUCHING ANY GEAR STATE. unit.core.equip_system is not a bare append:
	# it goes through UnitPrinter.equip_system, which calls full_repair(), and GearCore.full_repair()
	# clears every equipped gear's state dictionary and refills its charges regardless of
	# resets_on_repair. A test that spent a charge and then equipped something else would silently
	# get the charge back. (SP2 Task 3 hit this as a near-false-pass.)
	unit.core.equip_system(GUN_ID)
	unit.core.equip_system(MELEE_ID)
	unit.core.equip_system(KIT_ID)
	SpecFactory.apply_passive_buffs(unit)
	watcher = add_child_autoqfree(PromptWatcher.new())

	# THE FRESH GAMEMASTER HAS NO CAMPAIGN, AND A DEATH NEEDS ONE. FitzgeraldFixture.create_game
	# passes make_fresh_gamemaster = true, and THAT branch of SpecFactory.setup_gamemaster
	# (spec_factory.gd:29-32) returns before the two lines that build a CampaignCore and hang it on
	# the map. No other Fitzgerald spec kills anything, so nothing has needed it - but this is the
	# first file whose whole subject is a unit dying, and EventService.remove_unit_from_game
	# (event_service.gd:80) calls context.map.campaign_core.get_lancer_by_id() with no guard. Without
	# the two lines below the FIRST death in a test throws "Nonexistent function 'get_lancer_by_id'
	# in base 'Nil'" - which GUT counts as a failure - and, worse, the error aborts
	# remove_unit_from_game four lines before unit.remove_from_game(), so the corpse stays on the map
	# and Unit.is_valid() keeps answering true for something the battle log has already announced as
	# destroyed. Both measured in this file's first RED run.
	#
	# Kept LOCAL to this spec rather than pushed into FitzgeraldFixture: Task 0's contract is that the
	# fixture behaves identically for the four SP1 specs, and none of them needs this.
	game.campaign_core = CampaignCore.create(SpecFactory.create_campaign_base())
	game.map.campaign_core = game.campaign_core

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

## Kit.is_valid, NOT `kit is Kit`. ContentLibrary.get_kit (content_library.gd:231-236) logs an error
## and then hands back the PLACEHOLDER kit (mt_missing_mechsystem) for an id it does not know, and
## that placeholder's sp_cost and charges_max are both 0 - so `kit is Kit` is true, and an
## `sp_cost == 0` assertion passes, for a system that does not exist. Kit.is_valid rejects it.
func _kit() -> Kit:
	var kit = ContentLibrary.get_kit(KIT_ID)
	return kit if Kit.is_valid(kit) else null

func _gear() -> GearCore:
	var gear := unit.get_gear(KIT_ID)
	return gear if GearCore.is_valid(gear) else null

## Charges left in HEAER, or -1 when the system does not exist. -1 rather than 0 on purpose: a
## missing system must never read as a spent one, which is the exact confusion that would let this
## whole file pass vacuously.
func charges_left() -> int:
	var gear := _gear()
	return gear.charges_current if gear != null else -1

## A mech that this one shot will destroy: 5 HP against Single Shot's cheated 8, armor 0, evasion
## -10 so the shot cannot miss, and ONE structure, so health <= 0 means the next event kills it.
##
## FACTION IS A PARAMETER, NOT ALWAYS AI_ENEMY (whole-branch review, finding 4): ruling 6 requires a
## HOSTILE character, and every call site before the review left this at the AI_ENEMY default, so
## nothing in this file ever exercised the are_enemies gate - deleting it
## (action_heaer_detonate.gd:94) would have passed every test here just the same.
func make_victim(tile:Vector2i, structure:int = 1, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var victim := SpecFactory.create_unit(game.map, tile, faction)
	FrameIsolation.isolate_frame(victim)
	victim.core.frame.stat.health = 5
	victim.core.frame.stat.armor = 0
	victim.core.frame.stat.evasion = -10
	victim.core.frame.stat.structure = structure
	victim.core.full_repair()
	return victim

## A bystander with a rigged Agility save. 40 HP so the blast cannot kill it (a death mid-blast
## would change what the rest of the burst sees), armor 0 by default so the damage number is the
## blast's own.
##
## ARMOR IS A PARAMETER (whole-branch review, finding 5): every bystander before the review was
## armor 0, where DAMAGE_FLAG.AP is invisible - stripping it from the queued blast damage
## (action_heaer_detonate.gd:221) left every blast test in this file green regardless.
func make_bystander(
	tile:Vector2i, agi:int, faction:Faction.SIDE = Faction.AI_ENEMY, armor:int = 0
) -> Unit:
	var bystander := SpecFactory.create_unit(game.map, tile, faction)
	FrameIsolation.isolate_frame(bystander)
	bystander.core.frame.stat.health = 40
	bystander.core.frame.stat.armor = armor
	bystander.core.frame.stat.evasion = 20 # never caught by a stray attack roll; only by the blast
	bystander.core.frame.hase = HaseBlock.create(0, agi, 0, 0)
	bystander.core.full_repair()
	return bystander

## The vanilla Jericho cover, hostile, cut down to 5 HP so one Single Shot destroys it.
func make_deployable(tile:Vector2i) -> Unit:
	var dep := SpecFactory.create_unit(game.map, tile, Faction.AI_ENEMY)
	dep.core.frame = ContentLibrary.get_mech_frame(DEPLOYABLE_FRAME)
	FrameIsolation.isolate_frame(dep)
	dep.core.frame.stat.health = 5
	dep.core.frame.stat.armor = 0
	dep.core.frame.stat.evasion = -10
	dep.core.full_repair()
	return dep

## Fire SINGLE SHOT at a UNIT, never at a tile. Single Shot has no range_pattern, so a supplied tile
## is taken as an aimed-at-the-ground shot: the engine spawns a dep_attack_ground_proxy and the
## attack resolves against the PROXY. test_swivel_gun.gd measured that; passing the Unit puts it in
## context.target_units, which ask_for_targets_alt turns into the attacked tiles directly.
func shoot(victim:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)
	await SpecFactory.use(game, unit, GUN_ID, SINGLE_SHOT_ID, victim)

func stab(victim:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)
	await SpecFactory.use_solo(game, unit, MELEE_ID, victim)

## A guaranteed hit whose damage die is a 6, with a long buffer behind it. The hit is guaranteed by
## the victim's evasion, not by the dice; the queue only fixes the numbers. The buffer has to outlast
## the attack AND every save d20 and blast damage die the explosion then rolls - a short one lets a
## real random d6 through and the exact BLAST_DAMAGE assertion becomes a coin flip. Clears first:
## Dice.cheat_attack only APPENDS.
func cheat_a_hit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([19], [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6])

## Every yes/no the player was asked that was HEAER's own. Filtered by title rather than counted
## raw, so an unrelated engine confirmation (a friendly-fire warning, a roll intervention) can never
## be mistaken for the offer - and so that a missing localization row, which would leave the title as
## the bare key, fails here instead of passing quietly.
func heaer_offers() -> Array[Dictionary]:
	var ours:Array[Dictionary] = []
	for info:Dictionary in watcher.kinds(PromptWatcher.KIND.yesno):
		if str(info.title) == CONFIRM_TEXT: ours.append(info)
	return ours

# ---------------------------------------------------------------- the Kit

func test_heaer_is_registered_granted_at_rank_1_and_has_display_text() -> void:
	var kit := _kit()
	assert_not_null(kit, '%s loads as a valid Kit through ContentLibrary.' % KIT_ID)
	if kit == null: return
	assert_eq(kit.compcon_id, KIT_ID, 'And it is filed under its own id, not the missing-gear stub.')
	assert_false(kit.is_trait, 'It is an equippable system, not a frame trait.')
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.charges_max, CHARGES, 'Limited 3.')
	assert_true(kit.is_unique(), 'Unique.')

	var license = ContentLibrary.get_license_tree(LICENSE_ID)
	assert_true(license is UnlockTree, 'fixture: %s loads.' % LICENSE_ID)
	if not (license is UnlockTree) or license.rank_1 == null: return
	var granted:Array = license.rank_1.granted_gear.map(func(g:Kit) -> StringName: return g.compcon_id)
	assert_has(granted, KIT_ID, 'Licence rank 1 grants HEAER, beside the Swivel Gun.')

	assert_not_null(_gear(), 'A Fitzgerald that equipped it carries it as gear.')
	assert_eq(charges_left(), CHARGES, 'And it starts with three charges.')

	# The compiled ARTIFACT, not the csv: Translate reads localizations.en.translation and never the
	# csv beside it, so an edited-but-unscanned csv leaves a correct-looking source file next to an
	# artifact that has never heard of these keys.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in [
		'gear.%s.name' % KIT_ID,
		'gear.%s.effect' % KIT_ID,
		'gear.%s.%s.confirm' % [KIT_ID, DETONATE_ID],
	]:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)

# ---------------------------------------------------------------- the blast

func test_a_cannon_kill_offers_the_prompt_and_detonates_the_body() -> void:
	var victim := make_victim(VICTIM_TILE)
	var doomed := make_bystander(DOOMED_TILE, -30)
	var spared := make_bystander(SPARED_TILE, 30)
	var distant := make_bystander(BYSTANDER_TILE, -30)

	cheat_a_hit()
	await shoot(victim)

	assert_eq(heaer_offers().size(), 1, 'The player was asked, once, whether to spend a charge.')
	assert_eq(charges_left(), CHARGES - 1, 'Accepting spent exactly one charge.')
	assert_false(Unit.is_valid(victim), 'The victim was destroyed by the shot.')

	# The two halves that make the save real: one bystander in the burst took the blast, the other,
	# standing in the same burst, passed its Agility save and took nothing.
	assert_eq(doomed.core.current.health, 40 - BLAST_DAMAGE,
		'The bystander that failed its Agility save took 1d6+1.')
	assert_eq(spared.core.current.health, 40,
		'The bystander that passed its Agility save took nothing - so a save was really rolled.')
	assert_eq(distant.core.current.health, 40, 'And burst 1 is burst 1: two tiles away is out of it.')
	assert_eq(unit.core.current.health, unit.get_health_max(),
		'The Fitzgerald, well outside the burst, is untouched.')

func test_a_declined_prompt_spends_no_charge_and_does_no_damage() -> void:
	SpecFactory.current_responder.chosen_yesnos = false
	var victim := make_victim(VICTIM_TILE)
	var doomed := make_bystander(DOOMED_TILE, -30)

	cheat_a_hit()
	await shoot(victim)

	assert_eq(heaer_offers().size(), 1, 'It was still offered...')
	assert_eq(charges_left(), CHARGES, '...but declining spent nothing.')
	assert_eq(doomed.core.current.health, 40, 'And nothing exploded.')

func test_a_melee_kill_offers_nothing() -> void:
	var victim := make_victim(MELEE_VICTIM_TILE)
	var doomed := make_bystander(MELEE_DOOMED_TILE, -30)

	cheat_a_hit()
	await stab(victim)

	assert_false(Unit.is_valid(victim), 'fixture: the melee weapon destroyed it just the same.')
	assert_eq(heaer_offers().size(), 0, 'A Melee kill is not a rifle, launcher or cannon kill.')
	assert_eq(charges_left(), CHARGES, 'No charge was spent.')
	assert_eq(doomed.core.current.health, 40, 'And nothing in the burst was touched.')

func test_a_hit_that_leaves_structure_offers_nothing() -> void:
	# RULING 6's WHOLE POINT. Identical damage, identical victim, identical burst - the only
	# difference is that this one has three structure, so the hit takes it to 0 HP without destroying
	# it. A gate written as a bare `health <= 0` passes every other test in this file and fails here.
	var survivor := make_victim(VICTIM_TILE, 3)
	var doomed := make_bystander(DOOMED_TILE, -30)

	cheat_a_hit()
	await shoot(survivor)

	assert_true(Unit.is_valid(survivor), 'fixture: it structured rather than died.')
	assert_eq(heaer_offers().size(), 0, 'Reaching 0 HP is not being destroyed.')
	assert_eq(charges_left(), CHARGES, 'No charge was spent.')
	assert_eq(doomed.core.current.health, 40, 'And nothing in the burst was touched.')

func test_at_zero_charges_nothing_is_offered() -> void:
	# Set AFTER every equip in before_each, for the full_repair() reason spelled out there.
	var gear := _gear()
	assert_not_null(gear, 'fixture: HEAER is equipped.')
	if gear == null: return
	gear.charges_current = 0

	var victim := make_victim(VICTIM_TILE)
	var doomed := make_bystander(DOOMED_TILE, -30)

	cheat_a_hit()
	await shoot(victim)

	assert_false(Unit.is_valid(victim), 'fixture: the shot still destroyed it.')
	assert_eq(heaer_offers().size(), 0, 'An empty system does not ask.')
	assert_eq(doomed.core.current.health, 40, 'And nothing exploded.')

func test_a_destroyed_deployable_counts() -> void:
	# Ruling 6's structureless branch: a non-mech has no structure to lose, so
	# queue_structure_or_stress_if_necessary sends it straight to event_unit_die at 0 HP.
	var dep := make_deployable(VICTIM_TILE)
	var doomed := make_bystander(DOOMED_TILE, -30)
	var spared := make_bystander(SPARED_TILE, 30)

	cheat_a_hit()
	await shoot(dep)

	assert_false(Unit.is_valid(dep), 'The deployable was destroyed by the shot.')
	assert_eq(heaer_offers().size(), 1, 'Destroying it offered the charge.')
	assert_eq(charges_left(), CHARGES - 1, 'Which was spent.')
	assert_eq(doomed.core.current.health, 40 - BLAST_DAMAGE, 'And the burst went off around it.')
	assert_eq(spared.core.current.health, 40, 'Save still rolled.')

## WHOLE-BRANCH REVIEW, FINDING 4, gate 3 (action_heaer_detonate.gd:94,
## `if not UnitRelation.are_enemies(unit, victim): return false`). "Whenever you destroy a HOSTILE
## character" - a Fitzgerald that guns down its own ally must not be offered the charge. Every other
## test in this file kills an AI_ENEMY victim, so deleting this gate would have passed the suite
## just the same; make_victim's faction argument (above) is what makes this test possible.
##
## Mutation-tested 2026-09-13: with `if not UnitRelation.are_enemies(unit, victim): return false`
## deleted from action_heaer_detonate.gd and the scoped spec re-run, this test went red
## (heaer_offers().size() came back 1, not 0) while every other test in the file stayed green.
## Restored immediately after.
func test_killing_an_allied_victim_offers_nothing() -> void:
	var victim := make_victim(VICTIM_TILE, 1, Faction.PLAYER)
	var doomed := make_bystander(DOOMED_TILE, -30)

	cheat_a_hit()
	await shoot(victim)

	assert_false(Unit.is_valid(victim), 'fixture: the shot destroyed the ally just the same.')
	assert_eq(heaer_offers().size(), 0, 'An allied kill is not a HOSTILE kill: nothing is offered.')
	assert_eq(charges_left(), CHARGES, 'No charge was spent.')
	assert_eq(doomed.core.current.health, 40, 'And nothing exploded.')

## WHOLE-BRANCH REVIEW, FINDING 4, gate 1 (action_heaer_detonate.gd:74,
## `if context.target_unit != unit: return false`). "Whenever YOU destroy" is about this mech's own
## gun - a kill made by some other unit entirely must not set the Fitzgerald's own HEAER off, even
## when the victim is genuinely hostile. Every other test's kill is the Fitzgerald's own, so
## deleting this gate would have passed the suite just the same.
##
## Mutation-tested 2026-09-13: with `if context.target_unit != unit: return false` deleted from
## action_heaer_detonate.gd and the scoped spec re-run, this test went red (heaer_offers().size()
## came back 1, not 0) while every other test in the file stayed green. Restored immediately after.
func test_a_kill_by_a_different_unit_offers_the_fitzgerald_nothing() -> void:
	var other := FitzgeraldFixture.create_dummy(game, Vector2i(4, 2), -10, Faction.PLAYER)
	other.core.equip_system(GUN_ID)
	SpecFactory.apply_passive_buffs(other)

	var victim := make_victim(VICTIM_TILE)
	var doomed := make_bystander(DOOMED_TILE, -30)

	cheat_a_hit()
	await FitzgeraldFixture.open_turn(game, other)
	await SpecFactory.use(game, other, GUN_ID, SINGLE_SHOT_ID, victim)

	assert_false(Unit.is_valid(victim), "fixture: the OTHER unit's shot destroyed it just the same.")
	assert_eq(heaer_offers().size(), 0,
		"The Fitzgerald's own HEAER was not offered another unit's kill.")
	assert_eq(charges_left(), CHARGES, 'No charge was spent.')
	assert_eq(doomed.core.current.health, 40, 'And nothing exploded.')

## WHOLE-BRANCH REVIEW, FINDING 5 (action_heaer_detonate.gd:221,
## `flags = [DAMAGE_FLAG.AP, DAMAGE_FLAG.SAVE_FAILED]`). Rules text: "1d6+1 AP kinetic damage". Every
## OTHER blast test's bystanders are armor 0, where AP is invisible (damage_modifications.gd:103
## only skips the armor reduction when AP is set AND armor is > 0) - stripping the flag would have
## left every one of them green regardless.
##
## Mutation-tested 2026-09-13: with `EventService.DAMAGE_FLAG.AP` deleted from the flags array in
## action_heaer_detonate.gd and the scoped spec re-run, this test went red (armored took 40 - 5, not
## 40 - 7) while every other test in the file stayed green. Restored immediately after.
func test_the_blast_is_ap_and_ignores_armor() -> void:
	var victim := make_victim(VICTIM_TILE)
	var armored := make_bystander(DOOMED_TILE, -30, Faction.AI_ENEMY, 2)

	cheat_a_hit()
	await shoot(victim)

	assert_eq(armored.core.current.health, 40 - BLAST_DAMAGE,
		'An armor-2 bystander still takes the full 1d6+1: the blast ignores armor because it is AP.')

func test_the_blast_catches_an_ally_in_burst_1() -> void:
	# Ruling 12's sibling, design §3.2: "allies and self included - the pilot chose it". A spec that
	# only ever puts hostiles in the burst cannot tell "we filter allies out" from "no ally was ever
	# standing there", which is why this test exists even though the design does not list it.
	var victim := make_victim(VICTIM_TILE)
	var ally := make_bystander(DOOMED_TILE, -30, Faction.PLAYER)
	var spared_ally := make_bystander(SPARED_TILE, 30, Faction.PLAYER)

	cheat_a_hit()
	await shoot(victim)

	assert_eq(heaer_offers().size(), 1, 'fixture: the charge was offered and taken.')
	assert_eq(ally.core.current.health, 40 - BLAST_DAMAGE,
		'A friendly standing in the burst takes the blast like anyone else.')
	assert_eq(spared_ally.core.current.health, 40, 'And gets its Agility save like anyone else.')
