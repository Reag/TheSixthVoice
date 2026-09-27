# The shared Sluagh spec fixture (SP1 Task 1). EVERY SIGNATURE HERE IS FROZEN for Tasks 2-9.
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, exactly as primrose_fixture.gd,
# vauban_fixture.gd, maidens_blush_fixture.gd, myconid_fixture.gd, subutai_fixture.gd and
# mk2_fixture.gd do: everything except create_<frame>() and this frame's own helpers is
# frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
# unit.get_gear(&'cp_cry_of_the_hosted_dead') stops finding anything. No Sluagh spec writes to the
# frame's stats.
#
# THE GAMEMASTER IS THE SHARED ONE, and here that is load-bearing rather than only 2.65x faster:
# the re-use branch of SpecFactory.setup_gamemaster builds a CampaignCore and hangs it on the map
# (spec_factory.gd:47-48), and the fresh branch returns before reaching those two lines.
# EventService.remove_unit_from_game dereferences map.campaign_core with no guard
# (event_service.gd:80), so on a fresh gamemaster the first death in a test throws before
# unit.remove_from_game(), leaving a corpse that still answers is_valid(). THE STEALING OF THE SOULS
# OF THE DEAD KILLS A UNIT IN EIGHT OF ITS TEN TESTS.
#
# NO SIZE RE-TRACKING. The Myconid's fixture ends create_myconid with UnitTile.move_to because that
# frame is size 2 and SpecFactory.create_unit adds every unit at size 1. The Sluagh IS size 1, so the
# line would be a no-op that reads as load-bearing. Deliberately absent.
#
# A BIGGER DEFAULT MAP THAN THE FITZGERALD'S, and it is the frame that decides it: the Sluagh's
# Sensors is 10 and Inexorable Formation pushes it past that, so the Stealing and Formation specs
# stand units at ranges 10, 11, 12 and 13 from the mech. On the shared 15x9 landscape a unit placed
# beyond the map has NO occupied tiles and every distance to it reads as the 1000 sentinel, so a
# "beyond Sensors" test would pass for entirely the wrong reason (memory
# lancer-tactics-spec-harness-traps).
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const FRAME_ID := &'mf_sluagh'
const LICENSE_ID := &'li_sluagh'

## The three sheet traits and the core system, in sheet order.
const WICKED_HOST_ID := &'mt_wicked_host'
const STEALING_ID := &'mt_the_stealing_of_the_souls_of_the_dead'
const FORMATION_ID := &'mt_inexorable_formation'
const CORE_ID := &'cp_cry_of_the_hosted_dead'

## The core system's three pressables and reactions.
const GUARDIAN_ID := &'action_astral_guardian'
const MARK_ACTION_ID := &'action_mark_of_the_dead'
const RETORT_ID := &'action_mark_retort'

## Every buff this frame ships in SP1. Named here so no spec re-types one and drifts.
const WICKED_HOST_CHIP := &'buff_wicked_host'
const WATCH_BUFF := &'buff_wicked_host_watch'
const FORMATION_CHIP := &'buff_inexorable_formation'
const MARK_CHIP := &'buff_mark_of_the_dead'
const SOFT_COVER_CHIP := &'buff_mark_soft_cover'

## SP2 Task 2. The rank-I weapon and its crit chip. NOT in the frame's traits array - licence gear
## lives under res/content/gear/horus/ and reaches a unit only through equip().
const REND_NEXUS := &'mw_rend_nexus'
const REND_NEXUS_CHIP := &'buff_rend_nexus'

## SP2 Tasks 5, 6 and 8. The rank-I system, its two invades, and the three buffs Grey Birds applies.
## buff_grey_birds_recentre is declared here and CREATED in Task 6; the chip is the only visible one.
const TRICKERY := &'ms_o_trickery'
const GREY_BIRDS_ID := &'action_grey_birds'
const HUNT_ID := &'action_hunt_of_the_vagrant_sowche'
const GREY_BIRDS_CHIP := &'buff_grey_birds'
const GREY_BIRDS_BAN := &'buff_grey_birds_ban'
const GREY_BIRDS_RECENTRE := &'buff_grey_birds_recentre'

## The plain vanilla rifle every Fitzgerald spec uses: MAIN, weapon_type unset so it is the archetype
## default RIFLE (3), 1d6, RELIABLE 2, aim_range 10, threat 1. It carries NO accuracy modifier, so an
## attack with it pops a d20 and nothing else off Dice.CHEAT_ROLL_QUEUE - which is what makes the
## exact queues in Tasks 2, 6 and 8 predictable.
##
## ITS RELIABLE 2 IS THE ONE TRAP, AND IT IS A FLOOR ON A HIT TOO - NOT ONLY A MISS PAYOUT. A MISS
## with it still lands 2 damage on the defender, and that damage lands AFTER the ATTACK POST
## reactions (memory lancer-tactics-spec-harness-traps). Any test whose subject is "a miss did
## nothing to the DEFENDER" uses TECH_ID instead; tests that read the ATTACKER's health (the Mark's
## retort) are unaffected.
##
## THE HIT HALF IS THE ONE THAT KEEPS BEING GOT WRONG (measured SP1 Task 2, 2026-09-20; the plan had
## it wrong and so did this header until the close). AttackUtil reduces the rolled damage and then
## tops the TOTAL back up whenever `total < reliable` - `attack_util.gd:144-147`, which sits inside
## the shared reduction path and is NOT in a miss branch. So a cheated damage die of 1 lands 2 on a
## HIT as well, and a hit and a miss become indistinguishable by the damage number. **Never cheat a
## rifle damage die below 3 in a test whose evidence is that number**: test_wicked_host.gd's
## DAMAGE_DIE = 3 and test_rend_nexus.gd's say why in the same words.
const MAIN_RIFLE := &'mw_assault_rifle'

## A vanilla TECH attack, and it needs no equipping: ms_fragment_signal is in every player mech's
## basic loadout (content/gear/basic/basic_loadout_mech_player.tres:5) and its single action is an
## ActionAttackTech. Two jobs here: it is the PURE miss (a tech miss deals nothing at all), and it is
## the case that proves allow_tech and allow_basic are set on both of this frame's reactions - it is
## a tech attack AND it is basic gear, so it needs both flags to trigger anything.
const TECH_ID := &'ms_fragment_signal'

## Vanilla Scan, also in every player mech's basic loadout (:21). Its action overrides
## get_target_range to specific.unit.get_sensor_range() (action_scan.gd:4-5), which makes it the
## cheapest honest reader of the live Sensors value for Inexorable Formation's spec.
const SCAN_ID := &'ms_scan'

## The Goblin's HARD cover buff (content/frames/horus/mf_goblin/cp_instinct_rig/buff_symbiosis_cover.tres:
## cover = 2, to = &"cover"). Used by ONE test, for the max-then-zero half of ruling 14: an ally
## already in hard cover keeps hard when the Mark's soft cover lands on it too. A vanilla buff rather
## than terrain, because a one-tall block beside a size-1 unit is exactly the geometry test_draw_fire
## measured as unreliable, and this needs no geometry at all.
const HARD_COVER_BUFF := &'buff_symbiosis_cover'

const DEFAULT_MAP_SIZE := Vector2i(30, 12)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A Sluagh with its traits' passive buffs applied. PLAYER faction, which SpecFactory's own default
## gives us and which is load-bearing twice over: every hostile/ally relation in the ability specs
## depends on it, and CommonActionUtil.confirm_use returns true WITHOUT asking when the unit is not
## player-controlled (common_action_util.gd:304) - which would make the Mark's retort prompt
## invisible to test_mark_retort.gd.
static func create_sluagh(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	return unit

## A FrameIsolation'd punching bag: 200 HP so it never dies mid-spec, armor 0 so damage numbers are
## the weapon's, and a caller-chosen evasion. Defaults to evasion 10 ("only hit when we say"), which
## is also the Sluagh's own evasion - so one cheated d20 decides a hit or a miss against either.
##
## THE evasion ARGUMENT DOES NOT MOVE E-DEFENCE, which stays at statblock_default.tres's 8 - this
## function never writes it. A SMART weapon rolls against E-DEF (action_attack_weapon.gd:250-252),
## so the argument is INERT for one and the sentence above is false in that case: the d20 that
## decides a Nightfare Nexus hit is being compared against 8, not against the evasion you passed.
## See test_nightfare_nexus.gd's D20_HITS. (Close review slice 5, M-2.)
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.AI_ENEMY)

## An enemy-faction CHARACTER: the shooter in almost every test here.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return create_dummy(game, tile, evasion)

## A friendly CHARACTER - the ally Astral Guardian shields and the Mark shelters.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

## An allied DRONE: a character (ruling 2026-09-27, mod-wide - a drone IS a character; see the
## canonical paragraph below). Used to build the positive "a drone counts" cases, and the owned/
## unowned pair where a card's clause is about ATTRIBUTION rather than membership.
##
## "CHARACTER" ON THIS FRAME, AND ACROSS THE MOD, IS Unit.is_character() - a drone included (the
## LCP's own DRONE tag: "Drones are Size 1/2 characters"). This REVERSES row 301 (2026-09-21, which
## read "character" as `is_actor()`). A drone is therefore sheltered by the Mark's dome, guarded by
## Astral Guardian, arms the Mark's retort, opens the Eyes, grants on the Stealing, can be the Hunt's
## closest character, and is a legal In Triumvirate partner or Crown target - all in its own right,
## not only through an owner. The canonical statement lives in the production header of
## res/content/frames/horus/mf_sluagh/mt_the_stealing_of_the_souls_of_the_dead/action_stealing_of_the_souls.gd.
##
## ATTRIBUTION IS UNCHANGED AND IS A DIFFERENT QUESTION: where a card asks WHO did something, the
## actor still resolves through `Unit.get_attacker()` first - ruling 70's Draw Fire resolution - so an
## OWNED hostile drone's hit still arms mt_wicked_host as its owner's, exactly as before. `own_drone`
## below builds that case; an unowned drone now ALSO passes the character test in its own right,
## rather than being the control it used to be.
##
## WHAT IS STILL EXCLUDED is an OBJECT, a WRECK or a MARKER, and create_hostile_object below is the
## control for that half - is_character() is already false for those (unit.gd:110, frame.gd:100),
## with no clause of ours involved.
##
## THE ENGINE FLAGS NOW DELIVER THIS DIRECTLY. `require_defender_to_be_character`
## (action_reaction_attacked.gd:95), `PassiveAura.applies_only_to_characters` (passive_aura.gd:73)
## and `ActionSystemTargetUnit.requires_target_character` (action_system_target_unit.gd:16) are ALL
## `is_character()`, which a drone passes - and every content-side clause that used to narrow that to
## is_actor() has been flipped to match. Every spec that reads a drone still keeps its
## `assert_true(drone.is_character())` / `assert_false(drone.is_actor())` pair as an ENGINE FACT: the
## second line no longer decides the outcome anywhere on this frame, but both are still true.
##
## Built by flipping is_drone on an ALREADY-ISOLATED frame rather than by loading a vanilla drone
## frame, the Vauban fixture's reasoning verbatim: create_dummy calls FrameIsolation.isolate_frame,
## which deep-duplicates the Frame AND its Statblock, so this write cannot reach the shared
## ContentLibrary copy. It also keeps the unit's stats identical to every other dummy, so the only
## thing that differs between the drone case and the ally case is the one flag under test.
static func create_drone(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	return FitzgeraldFixture.create_drone(game, tile, faction)

## Give a drone an OWNER, so Unit.get_attacker() resolves its shots to that owner.
##
## THIS IS THE ENGINE'S OWN CALL, not a hand-written field: UnitBattleState.set_owner writes
## deployable_owner_id (unit_battle_state.gd:255-261, inheriting the owner's own owner when it has
## one), get_owner_unit reads it back through map.get_unit_by_id (unit.gd:264-268), and
## get_attacker -> get_owner_unit_or_self is what ruling 70 resolves through (unit.gd:270-282).
##
## AN UNOWNED DRONE gets get_attacker() returning itself (the default create_drone gives) - which
## used to be the control for the Wicked Host pair before ruling 2026-09-27 (mod-wide) made a drone a
## character in its own right; an unowned drone now ALSO arms what it hits. own_drone still isolates
## the OWNED half, ruling 70's attribution, unaffected by the membership ruling.
static func own_drone(drone:Unit, owner:Unit) -> Unit:
	drone.state.set_owner(owner)
	return drone

## A hostile OBJECT - a Jericho cover on the enemy side. THE POINT IS THAT IT IS NOT A CHARACTER:
## Frame.ENTITY.OBJECT makes Unit.is_character() false (unit.gd:116 -> frame.gd:100), so the
## Stealing's "hostile character is destroyed" gate must let this death pass unanswered even though
## it IS hostile. A hostile MECH and a friendly object each fail to separate the two clauses on their
## own; this is the case that does.
static func create_hostile_object(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_deployable(game, tile, 10, 0, 10, Faction.AI_ENEMY)

## A hostile character cheap enough to destroy with one shot, when a test wants the death to come
## from an ATTACK rather than from a hand-driven event: 5 HP, 1 structure, evasion -10.
##
## Most Stealing tests do NOT use this - they call kill() instead, because every damage kill fires
## `structured` BEFORE `death` and rolls an unseeded structure-table d6 (memory
## lancer-tactics-spec-harness-traps), which is four extra moving parts for a trait that only cares
## that a death happened.
static func create_victim(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var victim := SpecFactory.create_unit(game.map, tile, faction)
	FrameIsolation.isolate_frame(victim)
	victim.core.frame.stat.health = 5
	victim.core.frame.stat.armor = 0
	victim.core.frame.stat.evasion = -10
	victim.core.frame.stat.structure = 1
	victim.core.full_repair()
	return victim

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Put a Kit on a unit as a SYSTEM, and hand back its GearCore. IDEMPOTENT.
##
## THE IDEMPOTENCE IS LOAD-BEARING, not tidiness. UnitPrinter.equip_system calls full_repair
## (unit_printer.gd:180), which sets core.has_core_power = true (:76) and rebuilds the loadout, and
## SpecFactory.apply_passive_buffs calls full_repair again and re-applies every passive buff from
## scratch. So a spec that equipped a weapon AFTER pressing the Mark would silently refund the core
## power and re-arm the whole frame.
##
## THE RULE EVERY SLUAGH SPEC FOLLOWS: equip everything first, press the Mark LAST, and never equip
## again inside a test that has already pressed.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	return FitzgeraldFixture.equip(unit, kit_id)

static func arm_rifle(unit:Unit) -> GearCore: return equip(unit, MAIN_RIFLE)

## Fire the rifle at a target, CYCLING the attacker's turn first.
##
## THE CYCLE IS NOT DECORATION, and neither is its direction. Action.get_per_turn_soft_limit caps any
## non-free action at one use per turn (action.gd:161-163), and the second use_solo in one turn aborts
## at event_gear_activate's check_specific_context with NO "Gear not available" line - only
## "[ ABORT event_gear_activate ] ... specific: invalid" - so the shot silently never happens and a
## "the second hit did nothing" assertion passes for the boring reason (memory
## lancer-tactics-spec-harness-traps). Ending and restarting the ATTACKER's turn clears it.
##
## AND IT DOES NOT DISTURB THE SLUAGH'S OWN 1/ROUND. uses_this_round is cleared by
## UnitAction.new_turn_refresh -> reset_per_round_usage, which runs only at the turn start of the
## unit whose turn it is - so cycling the shooter's turn leaves Astral Guardian's spent round spent.
## That is Draw Fire ruling 3 read from the other side, and it is what lets test_astral_guardian.gd
## fire two hostile shots inside one round.
static func shoot(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	if attacker.state.is_taking_turn: await SpecFactory.end_turn(game, attacker)
	await SpecFactory.start_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, MAIN_RIFLE, target)

## The same, with the vanilla tech attack. Needs no equipping (it is basic gear) and deals NO damage
## of its own, which is the only way to land a genuinely empty miss on an 8 HP frame.
##
## AN INVADE AGAINST AN ALLY AUTO-HITS (action_attack_tech.gd's is_invade branch), which is what
## test_wicked_host.gd's "an allied attack applies nothing" case rides on: the hit is guaranteed, so
## a green there is about the hostility gate and not about the dice.
static func invade(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	if attacker.state.is_taking_turn: await SpecFactory.end_turn(game, attacker)
	await SpecFactory.start_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, TECH_ID, target)

## A SECOND rifle shot from an attacker whose turn is ALREADY open, cycling nothing.
##
## THE ONE CASE shoot() CANNOT SERVE, and it is a measured distinction rather than a stylistic one.
## core.current.reactions is restored by UnitAction.every_new_turn_refresh, which event_turn_start
## runs for EVERY unit on the map at ANY unit's turn start - its own comment says "this is applied to
## ALL units, including the starting one" (event_turn_start.gd:42-44). So shoot()'s turn cycle hands
## the DEFENDER its reaction point back between two shots, and a test about the Mark's reaction
## spending that point would be vacuous.
##
## gear.uses_this_round is different: reset_per_round_usage runs inside new_turn_refresh, for the
## STARTING unit only (event_turn_start.gd:79, unit_action.gd:78, :87-88). That is why Astral
## Guardian's 1/round tests can use shoot() freely - it is point-free and only the tally binds it.
##
## Action.FLAG.AS_FREEBIE is what lets the second shot happen at all inside one turn: it bypasses the
## attacker's per-turn soft limit at unit_action.gd:114 (via event_gear_activate.gd:45,51) and
## touches nothing on the defending side. Memory lancer-tactics-spec-harness-traps records the idiom
## and its vacuity guard - pair it with an assertion that the second shot really fired.
static func shoot_again(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await SpecFactory.use_solo(game, attacker, MAIN_RIFLE, target, [Action.FLAG.AS_FREEBIE])

## Load the dice FIFO with EXACTLY these numbers, then a long tail of 1s.
##
## THE WHOLE QUEUE, EXPLICITLY, because on this frame the order is the test. Dice.roll_d6() pops from
## the same global FIFO as an attack roll (dice.gd:33-35), and Astral Guardian's d6 is rolled at
## ATTACK POST - i.e. after the attack's d20 and BEFORE the attack's damage dice
## (event_unit_attack.gd:123, then event_unit_attack_declared.gd:74). So the queue for a guardian
## test reads [d20, the guardian's d6, the rifle's damage d6].
##
## AND IN A CASE WHERE THE REACTION IS CORRECTLY REFUSED, THE DAMAGE DIE IS THE **SECOND** ENTRY, NOT
## THE THIRD. Nothing pops the middle slot when no d6 is rolled, so a negative case written with the
## positive case's queue reads the GUARDIAN's number as its damage and fails against a build that is
## working (measured SP1 Task 6, and again at Task 9 - ledger lines 110 and 128). THE IDIOM EVERY
## NEGATIVE CASE ON THIS FRAME USES: write the SAME number in both slots, so the damage read is
## identical whether or not a die was popped first and the assertion is about the gate rather than
## about queue alignment. Soft cover and the two accuracy chips pop entries in that same middle
## region, for the same reason.
##
## THE TAIL IS 1s, NOT 6s, AND THAT IS THIS FRAME: the Sluagh has 8 HP and 0 armor, so a stray
## cheated six is a quarter of its health and two of them end a test early. Every other fixture in
## this mod tails with sixes because its subject is a 200 HP dummy.
##
## CLEARS FIRST. Dice.cheat_attack only APPENDS (dice.gd:13-17), so a leftover from an earlier shot
## would be handed to the next roll in place of its own first value - test_knock_em_down.gd records a
## real run lost to exactly that.
static func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 60: all.append(1)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## A guaranteed HIT that is never a crit, against any evasion this fixture hands out (10 or less):
## base_roll 19 minus the worst-case -6 accuracy die is 13, always short of attack_roll.gd's
## total_roll >= 20 crit threshold.
static func cheat_a_hit() -> void: queue([19])

## A guaranteed MISS: base_roll 1 cannot beat any evasion this fixture hands out.
static func cheat_a_miss() -> void: queue([1])

## Give a unit a pilot Grit, which is what the Stealing grants Overshield equal to.
##
## PilotCore.get_grit() is Util.half(license_level), and Util.half is CEILI (util.gd:14-15) - so
## licence level 0 is the only Grit 0, and 1 and 2 are both Grit 1. SpecFactory.create_unit hands out
## a PilotCore with license_level 0, so a fixture unit has Grit 0 until this is called - which makes
## "Grit 0 grants nothing" the default rather than something a test has to arrange.
##
## Takes the GRIT the caller wants and derives the level, so no spec does the rounding in its head.
## Delegates to FitzgeraldFixture.set_grit (close-out Pass D), which every fixture already preloads -
## so a Sluagh spec still never preloads the Myconid's fixture to get one function.
static func set_grit(unit:Unit, grit:int) -> void:
	FitzgeraldFixture.set_grit(unit, grit)

## Put Overshield on a unit through the shared helper, the way production does.
##
## THROUGH A DUMMY EVENT, which has no live block - so it takes the helper's SECOND path, through
## X.current_level() (overshield.gd:82-84). That is the path every spec takes and the one
## test_overshield.gd established; the live-block path is exercised for real by the Stealing's and
## Astral Guardian's own activations.
static func grant_overshield(unit:Unit, amount:int) -> void:
	await Overshield.grant(SpecFactory.dummy_event({unit = unit}), unit, amount)

## Press the Mark, turn and all. CALL THIS LAST - see equip()'s header.
##
## SpecFactory.use(game, unit, kit_id, action_id) rather than use_solo(): this Kit carries THREE
## actions by the end of SP1 and use_solo fires the FIRST one, whichever that is.
##
## THE TURN IS NOT DECORATION even though the Mark is a QUICK rather than a PROTOCOL: a QUICK action
## spends an activation, and UnitAction refuses one outside a turn. The stock ChoiceBusResponder
## answers the confirm prompt ActionSystemApplyBuff raises (spec_factory.gd:376, chosen_yesnos
## defaults true).
static func press_mark(game:Gamemaster, sluagh:Unit) -> void:
	await open_turn(game, sluagh)
	await SpecFactory.use(game, sluagh, CORE_ID, MARK_ACTION_ID)

## Run the tracking pass: re-evaluate every aura on the map.
##
## THIS IS WHAT HANGS AN AURA BUFF. PassiveAura.update_unit is called from
## UnitTile.update_tracking_and_statuses (unit_tile.gd:24) and from nowhere else a spec reaches;
## SpecFactory.apply_passive_buffs only marks the gear's aura ACTIVE (unit_condition.gd:878-880), it
## does not place anything. Pressing the Mark does not need this - applying a buff from gear that
## holds a PassiveAura runs the pass itself (unit_condition.gd:712-715 -> :775 -> unit.gd:158-160) -
## but a test that MOVES somebody afterwards does.
static func track(game:Gamemaster) -> void:
	UnitTile.update_tracking_and_statuses(game.map)

## Move a unit to a tile and re-run the tracking pass, which move_to does for us (unit_tile.gd:10-13).
## The aura tests walk an ally in and out of the Sluagh's adjacency with this.
static func step(unit:Unit, tile:Vector2i) -> void:
	UnitTile.move_to(unit, tile)

## Destroy a unit outright, without an attack.
##
## A DIRECT event_unit_die, DELIBERATELY. Every damage kill fires `structured` before `death` and
## rolls an unseeded structure-table d6 - for a low-structure fixture, four of six outcomes kill it
## and two do not (memory lancer-tactics-spec-harness-traps) - which is four moving parts for a trait
## that only cares that a death happened, at a known distance, to a known kind of unit.
static func kill(game:Gamemaster, unit:Unit) -> void:
	await game.execute_event(&'event_unit_die', {unit = unit})

## Destroy a unit by meltdown, which is a different EVENT that ends in the same one: event_unit_meltdown
## executes event_unit_die itself at :63 after its 4d6 burst. Ruling 11 says a meltdown counts, and
## this is the only way to ask.
static func meltdown(game:Gamemaster, unit:Unit) -> void:
	await game.execute_event(&'event_unit_meltdown', {unit = unit})

## SP2 Task 2. Equip the rank-I weapon. arm_rifle's shape, on the mod's own gear.
static func arm_rend_nexus(unit:Unit) -> GearCore: return equip(unit, REND_NEXUS)

## Fire the Rend Nexus at a target, opening a turn for the shooter first.
##
## THE TURN CYCLE IS NOT DECORATION, for the reason shoot()'s own header (:226-239) gives:
## Action.get_per_turn_soft_limit caps any non-free action at one use per turn (action.gd:161-163),
## and a second use_solo in one turn aborts at event_gear_activate's check_specific_context with NO
## "Gear not available" line - so the shot silently never happens and a "nothing changed" assertion
## passes for the boring reason.
##
## IT POPS THREE ENTRIES OFF Dice.CHEAT_ROLL_QUEUE: the d20, then the damage dice TWICE
## (attack_util.gd:250-251 rolls hit_rolls and crit_rolls separately, on a miss as much as on a crit),
## and NO accuracy die, because the weapon sets no attack_accuracy and roll_d6_accuracy(0) returns 0
## without rolling (dice.gd:87-88). queue() tails with 1s, so [d20] alone is a legal queue here.
static func nexus_shot(game:Gamemaster, sluagh:Unit, target:Unit) -> void:
	if sluagh.state.is_taking_turn: await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, sluagh)
	await SpecFactory.use_solo(game, sluagh, REND_NEXUS, target)

## SP2 Task 5. Equip the rank-I system.
static func equip_trickery(unit:Unit) -> GearCore: return equip(unit, TRICKERY)

## Invade with THE FLIGHT OF THE CRESCENT OF GREY BIRDS.
##
## POPS ONE ENTRY off Dice.CHEAT_ROLL_QUEUE: the d20 (attack_roll.gd:67) and nothing else - a tech
## attack's damage_dice is the flat string '2' (action_attack_tech.gd:17), so roll_dice's loop body
## never runs, and no accuracy die is popped without an accuracy modifier (dice.gd:87-88).
## cheat_a_hit()/cheat_a_miss() are therefore complete queues for it.
##
## The turn cycle is shoot()'s, for the reason its header (:226-239) gives - except that an INVADE
## has no per-turn soft limit at all (action_attack_tech.gd:13-15 returns 99 for one), so the guard
## here is about the ACTIVATION being legal rather than about the second use being swallowed.
static func grey_birds(game:Gamemaster, sluagh:Unit, target:Unit) -> void:
	if sluagh.state.is_taking_turn: await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, sluagh)
	await SpecFactory.use(game, sluagh, TRICKERY, GREY_BIRDS_ID, target)

## SP2 Task 8. A game whose responder can answer a SEQUENCE of prompts and hand back the one it
## installed - maidens_blush_fixture.create_game_with_prompt_queues (:97-102), verbatim except
## for the map size default.
##
## WHY THE STOCK RESPONDER IS NOT ENOUGH FOR HUNT. SpecFactory.ChoiceBusResponder answers a unit
## pick with chosen_unit or units[0] and RECORDS NOTHING (spec_factory.gd:397-405), so "a single
## closest character raised no prompt at all" is unassertable through it - and that is the whole of
## the difference between ruling 5's tie case and its auto-pick case. testkit/mod_choice_responder.gd
## records every unit prompt in unit_prompts and answers from unit_queue, and records every targeting
## prompt in plan_prompts, which is the only way to read back WHICH TILES the card offered.
##
## add_responder = false is what stops TWO responders answering the same request.
static func create_game_with_prompt_queues(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	return FitzgeraldFixture.create_game_with_prompt_queues(test, map_size)

## Invade with HUNT OF THE VAGRANT SOWCHE.
##
## POPS TWO ENTRIES off Dice.CHEAT_ROLL_QUEUE: the invade's d20 (attack_roll.gd:67), then the forced
## Systems save's. Neither pops an accuracy die without a modifier (dice.gd:87-88), and a tech
## attack's flat '2' damage rolls nothing. queue() tails with 1s, so queue([19]) is a hit AND a
## failed save; a PASS must be queued explicitly.
##
## AN AUTOHIT POPS NOTHING AT ALL, which is the one case that breaks that arithmetic:
## EventUnitAttack.execute_attack_roll_sequence returns at its autohit branch (:148-154) before
## AttackRoll.roll_attack is reached, so on an ALLIED target the FIRST queued entry is the save's.
static func hunt(game:Gamemaster, sluagh:Unit, target:Unit) -> void:
	if sluagh.state.is_taking_turn: await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, sluagh)
	await SpecFactory.use(game, sluagh, TRICKERY, HUNT_ID, target)

## SP3 Task 1. The rank-II Auxiliary weapon and the soft-cover chip it hangs on its TARGET.
##
## THE CHIP GOES ON THE TARGET, not on the Sluagh - the opposite of REND_NEXUS_CHIP one card over,
## which onhit_rend_nexus.tres sends to the attacker with apply_buffs_to_self. It is VISIBLE (author,
## 2026-09-21), unlike SOFT_COVER_CHIP above, which is hidden because buff_mark_of_the_dead stands
## beside it as the signal; this weapon leaves no companion chip, so its own is the only marker.
const NIGHTFARE_NEXUS := &'mw_nightfare_nexus'
const NIGHTFARE_CHIP := &'buff_nightfare_soft_cover'

## SP3 Task 1. Equip the rank-II weapon. arm_rend_nexus's shape, on the other Nexus.
static func arm_nightfare_nexus(unit:Unit) -> GearCore: return equip(unit, NIGHTFARE_NEXUS)

## Fire the Nightfare Nexus at a target, opening a turn for the shooter first.
##
## IT POPS EXACTLY ONE ENTRY OFF Dice.CHEAT_ROLL_QUEUE - the d20 (attack_roll.gd:67) - AND THAT IS
## THE DIFFERENCE FROM nexus_shot, which pops THREE. This weapon's damage is the flat string '3', so
## Dice.process_dice_string returns count 0 and roll_dice's loop body never runs (dice.gd:22-35), the
## same reason a tech attack's flat '2' costs no entry; and it sets no attack_accuracy, so
## roll_d6_accuracy(0) returns 0 without rolling (dice.gd:87-88). Do not copy nexus_shot's
## three-entry comment onto this helper - a queue written for three would hand the wrong number to
## the next roll, and queue()'s tail of 1s makes that silent.
##
## THE TURN CYCLE IS NOT DECORATION, for the reason shoot()'s own header (:226-239) gives:
## Action.get_per_turn_soft_limit caps any non-free action at one use per turn (action.gd:161-163),
## and a second use_solo in one turn aborts at event_gear_activate's check_specific_context with NO
## "Gear not available" line - so the shot silently never happens and a "nothing changed" assertion
## passes for the boring reason.
static func nightfare_shot(game:Gamemaster, sluagh:Unit, target:Unit) -> void:
	if sluagh.state.is_taking_turn: await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, sluagh)
	await SpecFactory.use_solo(game, sluagh, NIGHTFARE_NEXUS, target)

## SP3 Tasks 3 and 4. The rank-II LIMITED 3 shield system and its two actions.
##
## IT SHIPS NO BUFFS. Both actions write state.overshield through the shared helper and the Crown
## adds one damage event; there is no chip, which is why no *_CHIP constant sits beside these.
const TWILIGHT_SWARM := &'ms_twilight_swarm'
const DAMNATION_ID := &'action_damnation_of_the_host'
const CROWN_ID := &'action_crown_of_restless_dead'

## SP3 Task 3. Equip the rank-II system. equip_trickery's shape.
static func equip_twilight_swarm(unit:Unit) -> GearCore: return equip(unit, TWILIGHT_SWARM)

## Press DAMNATION OF THE HOST, opening a turn for the Sluagh if it has none.
##
## SpecFactory.use rather than use_solo: the Kit carries TWO actions by Task 4 and use_solo fires
## whichever is first.
##
## IT DOES NOT CYCLE THE TURN, and that is the opposite choice from nightfare_shot() and shoot().
## A QUICK TECH action on a PLAYER mech has no per-turn soft limit at all - ActionSystem's override
## returns 99 for it (the repeat-action rule explicitly exempts quick tech) - so three Damnations
## inside one turn is legal, and the only thing that stops a fourth is the charge. Cycling here
## would hide that, and it would also hand the Sluagh's own per-round counters back, which the
## Crown's tests depend on NOT happening.
##
## IT POPS ONE ENTRY off Dice.CHEAT_ROLL_QUEUE: the d6 (dice.gd:90). Nothing else - it is not an
## attack, so no d20 and no accuracy die.
static func damnation(game:Gamemaster, sluagh:Unit) -> void:
	if not sluagh.state.is_taking_turn: await open_turn(game, sluagh)
	await SpecFactory.use(game, sluagh, TWILIGHT_SWARM, DAMNATION_ID)

## Press CROWN OF RESTLESS DEAD at an ally, opening a turn for the Sluagh if it has none.
##
## ITS 1/ROUND IS THE ENGINE'S: Action.get_per_round_hard_limit returns 1 for any FREE action
## (action.gd:156-158), and gear.uses_this_round is cleared by UnitAction.new_turn_refresh ->
## reset_per_round_usage, which runs only at the turn start of the unit whose turn it is
## (event_turn_start.gd:79, unit_action.gd:78, :87-88). So a second Crown inside one Sluagh turn is
## refused, and cycling the SLUAGH'S OWN turn is what clears it - unlike shoot(), which cycles the
## SHOOTER'S turn and is therefore useless for this.
##
## THE TALLY IS PER USAGE GROUP, AND THE CROWN CARRIES ITS OWN. GearCore.get_usage_group_for_action
## falls back to the KIT id when an action names no group (gear_core.gd:166-168), so without
## usage_group = &"crown_of_restless_dead" on the .tres a single Damnation would fill the Crown's
## one slot for the round. test_a_damnation_does_not_consume_crowns_one_per_round is the pin.
static func crown(game:Gamemaster, sluagh:Unit, ally:Unit) -> void:
	if not sluagh.state.is_taking_turn: await open_turn(game, sluagh)
	await SpecFactory.use(game, sluagh, TWILIGHT_SWARM, CROWN_ID, ally)

## SP4 Task 1. The rank-III tech system that lends the Sluagh a reaction, and the chip that says so.
const BLEAKSHADOW_GATE := &'ms_bleakshadow_gate'
const GATE_ACTION_ID := &'action_activate_bleakshadow_gate'
const EYES_ID := &'action_eyes_of_night'
const GATE_CHIP := &'buff_bleakshadow_gate'
const EYES_BONUS := &'buff_eyes_of_night_bonus'

## SP4 Task 4. The rank-III NHP and the quick tech that names a partner.
const MORRIGAN := &'ms_the_morrigan_class_nhp'
const TRIUMVIRATE_ID := &'action_in_triumvirate'
const PAIR_CHIP := &'buff_in_triumvirate_pair'
const WARD_CHIP := &'buff_in_triumvirate_ward'
const ADJACENT_TO := &'reag_adjacent_to'

## SP4 Task 1. Equip the rank-III system. equip_trickery's / equip_twilight_swarm's shape.
static func equip_gate(unit:Unit) -> GearCore: return equip(unit, BLEAKSHADOW_GATE)

## Press ACTIVATE BLEAKSHADOW GATE, opening a turn for the Sluagh if it has none.
##
## SpecFactory.use rather than use_solo: the Kit carries TWO actions from Task 2 on (the activate
## and the reaction) and use_solo fires whichever is first - which IS the activate, today, but the
## explicit id is used anyway so this helper does not silently start firing the reaction instead the
## day the Kit's actions array is reordered.
##
## IT DOES NOT CYCLE THE TURN, damnation()'s choice for the same reason: a QUICK TECH action on a
## PLAYER mech has no per-turn soft limit at all (the repeat-action rule explicitly exempts quick
## tech, action_system.gd:44), so cycling here would hide that and would also hand the Sluagh's own
## per-round counters back for no reason.
##
## POPS NOTHING off Dice.CHEAT_ROLL_QUEUE - it is not an attack and not a save, just a self-applied
## marker buff.
##
## THE TURN IT OPENS DOES POP, THOUGH, and every Eyes of Night case calls this helper before it
## queues: event_turn_start's recharge loop rolls a d6 for each non-basic gear that is not yet
## recharged (event_turn_start.gd:89-91), so opening the Sluagh's turn here eats one entry per such
## item on the loadout. Harmless while the queue is filled AFTER this call (the file's own order);
## queue first and the d20 is swallowed. triumvirate() carries the same caveat.
static func open_gate(game:Gamemaster, sluagh:Unit) -> void:
	if not sluagh.state.is_taking_turn: await open_turn(game, sluagh)
	await SpecFactory.use(game, sluagh, BLEAKSHADOW_GATE, GATE_ACTION_ID)

## SP4 Task 4. Equip the rank-III NHP. equip_trickery's shape, on the Morrígan.
static func equip_morrigan(unit:Unit) -> GearCore: return equip(unit, MORRIGAN)

## Press IN TRIUMVIRATE naming an ally, opening a turn for the Sluagh if it has none.
##
## THE ACTIVATION POPS NOTHING off Dice.CHEAT_ROLL_QUEUE, and that is the CORRECTED reading - this
## header guessed one entry for the self-heat and asked to be measured. gain_self_heat calls
## Dice.roll_string(self_heat_dice) (unit_action.gd:291-294), and roll_string on the flat string "2"
## goes through process_dice_string, which parses it as a BONUS and returns count 0 (dice.gd:98-112),
## so roll_dice's loop body never runs (:22-35). nightfare_shot's flat "3" and grey_birds'
## tech-attack "2" reasoning applies here after all.
##
## BUT THE TURN THIS HELPER OPENS DOES POP, AND THAT IS WHAT THE FIRST MEASUREMENT CAUGHT (2026-09-21,
## test_in_triumvirate case 2): event_turn_start's recharge loop rolls a d6 for EVERY non-basic gear
## that is not yet recharged (event_turn_start.gd:89-91) - one entry with the Morrígan alone
## equipped, more with a fuller loadout. So a spec that queues before calling this must either open
## the Sluagh's turn itself first (what case 2 does) or count those rolls. The same caveat applies to
## open_gate() and damnation() above, whose headers speak only for their own activations.
##
## DOES NOT CYCLE THE TURN, damnation()'s and open_gate()'s reasoning: a quick tech has no per-turn
## soft limit on a player mech.
static func triumvirate(game:Gamemaster, sluagh:Unit, ally:Unit) -> void:
	if not sluagh.state.is_taking_turn: await open_turn(game, sluagh)
	await SpecFactory.use(game, sluagh, MORRIGAN, TRIUMVIRATE_ID, ally)

## Put this mod's own soft-cover chip (SOFT_COVER_CHIP, the Mark's BuffCover) on a unit, so an attack
## against it computes pre.cover == SOFT. Named for what a spec reads: "a covered enemy". The same
## buff test_mark_of_the_dead.gd's aura hangs on a sheltered ally - reused here rather than declaring
## a second SOFT cover buff, since Eyes of Night only needs SOME soft-cover source on the roll.
static func cover(unit:Unit) -> void:
	SpecFactory.apply_buff(unit, SOFT_COVER_CHIP)
