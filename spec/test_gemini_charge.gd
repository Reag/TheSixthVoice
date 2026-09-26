# GEMINI CHARGE - "1/round, when attacking with a Ranged or Line weapon, the Lovers Knot may redirect its
# shot upon contact with a character. Originating from that characters space, the remaining Line, Range,
# and Line of Sight is drawn to another character. Attacks made this way are made against all characters
# simultaneously with one attack roll. This counts as one attack and all damage it deals is halved."
# Design 2, rulings 7-16. Spike 8 pinned the seam (spec/test_spike_attack_relay.gd, kept as evidence).
#
# THE SHAPE. A triggered buff at ATTACK_DECLARED PRE, early priority, on the Knot's own non-melee
# single-target or Line weapon attack: a yes/no, then vanilla's proxy picker on the contact's space at
# the remaining reach, then the picked character is APPENDED to the declared summary (a Line bends:
# everything past the contact is cut), the declared flags are replaced with HALF_DAMAGE, and the round
# is stamped. A permanent hidden BuffModifyAttackRoll then gives each redirected target the contact's
# d20 FACE with its own accuracy and difficulty (ruling 9, the author's reading), after swapping the
# cover measured from the Knot for the cover measured from the leg's start (ruling 10) and asking
# invisibility itself (ruling 11).
#
# EVERY "DOES NOT" TEST CARRIES ITS CONTROL: either a positive half in the same test (a freebie second
# shot, which the per-turn soft limit would otherwise refuse in silence), or a guard that the attack
# really landed, so a shot that never fired cannot pass as a redirect correctly refused.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/gemini.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_gemini_charge.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/lovers_knot_fixture.gd')

const MAP_SIZE := Vector2i(20, 16)
const KNOT_TILE := Vector2i(1, 4)
const CONTACT_TILE := Vector2i(4, 4) # 3 from the Knot: the rifle has 7 left, the rail 7
const SECOND_TILE := Vector2i(4, 7) # 3 south of the contact
const FAR_TILE := Vector2i(4, 12) # 8 from the contact: past a remaining 7, inside the rifle's full 10
const ADJACENT_TILE := Vector2i(2, 4) # the melee control's contact
const NEAR_TILE := Vector2i(2, 6) # 2 from the adjacent contact: inside a threat-3 leg's 2
## IPS-N War Pike: MELEE, threat 3 - long enough that a leg from an adjacent contact would reach NEAR_TILE.
const PIKE := &'mw_war_pike'
const DRONE_TILE := Vector2i(4, 3) # a non-character contact, 3 from the Knot, 4 from the second
const PAST_TILE := Vector2i(6, 4) # on the rail's original line, past the contact
const LINE_AIM := Vector2i(11, 4) # the rail's first leg, due east
const LINE_SECOND_AIM := Vector2i(4, 11) # the bent leg, due south from the contact, 7 long
## Height-3 blocks between the Knot and the second target; the contact's column (x = 4) stays open.
## From the Knot the second is hidden and in HARD cover; from the contact, neither (Spike 8 test g).
const WALL:Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5), Vector2i(2, 6), Vector2i(3, 6), Vector2i(2, 7), Vector2i(3, 7)]
## A one-tall block between the contact and the second, adjacent to the second: HARD cover from the
## contact's space, nothing from the Knot's diagonal, and low enough to be seen over.
const LOW_BLOCK := Vector2i(4, 6)

const SIXES:Array[int] = [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]


# ============ IN-SPEC BUFFS ============

## Records every ATTACK_DECLARED POST the Knot makes: the whole list, AFTER every PRE (ruling 15).
class DeclaredRecorder extends Buff:
	var seen:Array[Dictionary] = []
	func _init() -> void:
		compcon_id = &'buff_spec_gemini_recorder'
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = ReactionBus.TIMING.POST
		hide_from_player = true
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.resource]
	func triggers_on_event(_core:BuffCore, unit:Unit, triggering:EventCore) -> bool:
		return triggering.context.unit.get_attacker(triggering.context) == unit
	func activate(_core:BuffCore, activation:EventCore) -> void:
		var summary:DeclaredAttackSummary = activation.context.event.context.resource
		seen.append({summary = summary, units = summary.all_attacked_units.duplicate()})

## +1 accuracy on attacks against the holder, from the TARGET's side: moves the redirected target's
## own total without touching the contact's.
class IncomingAccuracy extends Buff:
	func _init() -> void:
		compcon_id = &'buff_spec_gemini_incoming_accuracy'
		to = Buff.TO.ATTACK_ROLL_INCOMING
		hide_from_player = true
	func get_values(_core:BuffCore, _context:Context) -> Context:
		return Context.create({category_str = Buff.BONUS_SUBTYPE.ACCURACY, number = 1})

## Attacks against the holder auto-hit: the contact then rolls no d20 at all.
class AutoHitMe extends BuffModifyAttackRoll:
	func _init() -> void:
		compcon_id = &'buff_spec_gemini_auto_hit_me'
		to = Buff.TO.MODIFY_ATTACK_ROLL
		step = EventUnitAttack.SEQUENCE_STEP.auto_hit
		applies_when_holder_is = APPLIES_WHEN.target
		is_onetime = false
		hide_from_player = true


# ============ FIXTURE ============

var game:Gamemaster
var responder
var knot:Unit
var contact:Unit
var recorder:DeclaredRecorder
## One entry per targeting prompt, measured INSIDE the prompt: the proxy is gone the moment the pick
## returns (memory lancer-tactics-spec-harness-traps, Koremasa SP5).
var captures:Array[Dictionary] = []

func before_each() -> void:
	await get_tree().process_frame # a synchronous test's responder must be off the bus first
	var made:Array = Fixture.create_game_with_prompts(self, MAP_SIZE)
	game = made[0]
	responder = made[1]
	responder.plan_prompt.connect(_on_plan_prompt)
	captures.clear()
	knot = Fixture.create_knot(game, KNOT_TILE)
	Fixture.equip(knot, Fixture.RANGED)
	contact = Fixture.create_dummy(game, CONTACT_TILE)
	recorder = DeclaredRecorder.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, recorder)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func _on_plan_prompt(info:Dictionary) -> void:
	var using:SpecificAction = info.using
	if not SpecificAction.is_valid(using) or not Unit.is_valid(using.unit): return
	# The same weapon from the same proxy at its FULL reach and with no Gemini scoping: the control that
	# shows the leg's own set was narrowed by the redirect, not by the geometry.
	var original:Action = using.gear.get_solo_action()
	captures.append({
		origin = using.unit.tile(),
		yesnos_before = responder.yesno_prompts.size(),
		reach = using.action.get_target_range(using),
		targetable = UnitTargeting.get_tiles_targetable(using),
		unscoped = UnitTargeting.get_tiles_targetable(SpecificAction.create(using.unit, using.gear, original)),
	})

func second_at(tile:Vector2i = SECOND_TILE, evasion:int = 10, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	return Fixture.create_dummy(game, tile, evasion, faction)

func plan_unit(unit:Unit) -> CompconPlan: return CompconPlan.create([unit.tile()], [], [unit])
func plan_tile(tile:Vector2i) -> CompconPlan: return CompconPlan.create([tile])

## Fire `kit_id` from `shooter` (the Knot by default) at `target` (a Unit, or a tile for a Line or a
## Blast), with the d20s first and a tail of sixes for every other die. `picks` answer the targeting
## prompts in order. CLEARS THE QUEUE FIRST.
func fire(kit_id:StringName, target, d20s:Array[int], picks:Array[CompconPlan] = [], flags:Array = [],
		shooter:Unit = null) -> void:
	if shooter == null: shooter = knot
	await Fixture.open_turn(game, shooter)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack(d20s, SIXES)
	responder.chosen_plan_queue.assign(picks)
	await SpecFactory.use_solo(game, shooter, kit_id, [target], flags)

## A second shot in the same turn: the per-turn soft limit refuses the same weapon twice in silence, and
## AS_FREEBIE waives only activation legality, never Gemini's own round (harness traps, Primrose SP1).
func fire_again(kit_id:StringName, target, d20s:Array[int], picks:Array[CompconPlan] = []) -> void:
	await fire(kit_id, target, d20s, picks, [Action.FLAG.AS_FREEBIE])

func last_summary() -> DeclaredAttackSummary:
	if recorder.seen.is_empty(): return null
	return recorder.seen.back().summary

func roll_against(target:Unit, summary:DeclaredAttackSummary = null) -> AttackRoll:
	if summary == null: summary = last_summary()
	if summary == null: return null
	for roll:AttackRoll in summary.attack_rolls:
		if roll.target_unit == target: return roll
	return null

func yesnos() -> int: return responder.yesno_prompts.size()
func picks() -> int: return responder.plan_prompts.size()


# ============ THE SHAPE ============

func test_the_core_system_carries_gemini_charge() -> void:
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	assert_true(Kit.is_valid(kit), 'The core system is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.passives.size(), 1, 'One passive: the buff applicator.')
	if kit.passives.is_empty(): return
	var applicator = kit.passives[0]
	assert_true(applicator is PassiveBuffApplicator, 'It applies buffs.')
	var ids:Array[String] = []
	for buff:Buff in applicator.applied_buffs: ids.append(String(buff.compcon_id))
	ids.sort()
	assert_eq(ids, ['buff_gemini_charge', 'buff_gemini_ignore_cover', 'buff_gemini_leg_tiles', 'buff_gemini_shared_roll'],
		'Four hidden buffs: the trigger, the shared roll, the scoped cover, the scoped picker.')

	var trigger:Buff = ContentLibrary.get_buff(Fixture.GEMINI_BUFF)
	assert_not_null(trigger, 'buff_gemini_charge is in the buffs index.')
	if trigger == null: return
	assert_eq(trigger.triggers_on, [ReactionBus.TRIGGER.ATTACK_DECLARED] as Array[StringName], 'It triggers on the declared attack.')
	assert_eq(trigger.trigger_timing, ReactionBus.TIMING.PRE, 'At PRE, before execute copies the target list (ruling 15).')
	assert_lt(trigger.get_priority(), Priority.ATTACK.mandatory,
		'Before every other PRE block, so a reader later in the block sees the appended target (compat).')
	var shared:Buff = ContentLibrary.get_buff(Fixture.GEMINI_SHARED_ROLL)
	assert_true(shared is BuffModifyAttackRoll, 'The shared roll is a BuffModifyAttackRoll.')
	if shared: assert_false(shared.is_onetime, 'Not one-time: check_buffs_for_step consumes what it uses.')
	var cover:Buff = ContentLibrary.get_buff(Fixture.GEMINI_IGNORE_COVER)
	assert_true(cover != null and cover.to == Buff.TO.IGNORE_COVER, 'The scoped cover buff is an IGNORE_COVER.')
	var tiles:Buff = ContentLibrary.get_buff(Fixture.GEMINI_LEG_TILES)
	assert_true(tiles != null and tiles.to == Buff.TO.ACTION_TILES, 'The scoped picker buff is an ACTION_TILES.')
	for buff:Buff in [trigger, shared, cover, tiles]:
		if buff: assert_true(buff.hide_from_player, '%s is plumbing, never a chip.' % buff.compcon_id)

func test_the_knot_holds_the_four_buffs() -> void:
	for id:StringName in [Fixture.GEMINI_BUFF, Fixture.GEMINI_SHARED_ROLL, Fixture.GEMINI_IGNORE_COVER, Fixture.GEMINI_LEG_TILES]:
		assert_true(UnitCondition.has_buff(knot, id), 'The Knot holds %s from the start.' % id)


# ============ THE OFFER (ruling 7) ============

func test_a_redirect_asks_yes_no_then_picks_from_the_contacts_space() -> void:
	var second := second_at()
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(yesnos(), 1, 'One yes/no.')
	assert_eq(captures.size(), 1, 'Then one pick.')
	if captures.is_empty(): return
	assert_eq(captures[0].yesnos_before, 1, 'The yes/no came BEFORE the pick.')
	assert_eq(captures[0].origin, CONTACT_TILE, 'The pick is made from the contact\'s space.')
	assert_eq(second.current_damage(), 3, 'The second target is hit: 6 halved.')
	assert_eq(contact.current_damage(), 3, 'The contact too: all damage it deals is halved.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'The round is spent.')
	var summary := last_summary()
	assert_eq(summary.attack_rolls.size() if summary else -1, 2, 'One declared attack, two rolls (ruling 15).')
	assert_eq(recorder.seen.size(), 1, 'It counts as ONE attack.')

func test_declining_the_yes_no_costs_nothing() -> void:
	var second := second_at()
	responder.yesno_queue.assign([false])
	await fire(Fixture.RANGED, contact, [14])
	assert_eq(yesnos(), 1, 'Asked.')
	assert_eq(picks(), 0, 'Declined: no picker.')
	assert_eq(contact.current_damage(), 6, 'A plain shot: full damage.')
	assert_eq(second.current_damage(), 0, 'Nobody else touched.')
	assert_eq(Fixture.gemini_uses(knot), 0, 'The round is kept: only an append spends it.')
	# CONTROL: the round kept above is there to spend.
	await fire_again(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(second.current_damage(), 3, 'The same round, a yes: redirected.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'And the round spent then.')

func test_cancelling_the_pick_costs_nothing() -> void:
	var second := second_at()
	await fire(Fixture.RANGED, contact, [14], [CompconPlan.create_aborted()])
	assert_eq(yesnos(), 1, 'Asked.')
	assert_eq(picks(), 1, 'Offered the pick.')
	assert_eq(contact.current_damage(), 6, 'Cancelled: a plain shot, full damage.')
	assert_eq(second.current_damage(), 0, 'Nobody else touched.')
	assert_eq(Fixture.gemini_uses(knot), 0, 'The round is kept.')
	await fire_again(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(second.current_damage(), 3, 'CONTROL: the same round, a pick: redirected.')


# ============ ELIGIBILITY (rulings 7, 8, 12, 16c) ============

func test_no_character_within_the_remaining_reach_raises_no_prompt() -> void:
	var far := second_at(FAR_TILE)
	await fire(Fixture.RANGED, contact, [14])
	assert_gt(contact.current_damage(), 0, 'Guard: the shot landed.')
	assert_eq(yesnos(), 0, 'The only other character is past the remaining 7: no yes/no.')
	assert_eq(picks(), 0, 'And no picker.')
	assert_eq(far.current_damage(), 0, 'Untouched.')
	# CONTROL: a character inside the reach is offered, the same round.
	var second := second_at()
	await fire_again(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(yesnos(), 1, 'Now there is someone to redirect to.')

func test_a_blast_weapon_is_not_offered() -> void:
	var second := second_at()
	Fixture.equip(knot, Fixture.BLAST)
	var blast:ActionAttackWeapon = knot.get_gear(Fixture.BLAST).get_solo_action()
	assert_eq(blast.range_pattern.pattern if blast.range_pattern else -1, Lancer.AOE_TYPE.BLAST, 'Fixture: a Blast weapon.')
	await fire(Fixture.BLAST, CONTACT_TILE, [14])
	assert_gt(contact.current_damage(), 0, 'Guard: the blast landed.')
	assert_eq(yesnos(), 0, 'A Blast has no single contact: not offered (ruling 8).')
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(yesnos(), 1, 'CONTROL: the rifle, the same round, is offered.')

func test_a_melee_weapon_is_not_offered() -> void:
	# THE WAR PIKE, NOT THE SWORD. A threat-1 sword at an adjacent contact leaves the leg 0 reach, so the
	# pre-check refuses before the ranged gate is ever asked - measured: deleting the gate left this test
	# green with the sword. Threat 3 leaves the leg 2, and NEAR_TILE is inside it.
	var second := second_at()
	var near := second_at(NEAR_TILE)
	var adjacent := Fixture.create_dummy(game, ADJACENT_TILE)
	Fixture.equip(knot, PIKE)
	var pike:ActionAttackWeapon = knot.get_gear(PIKE).get_solo_action()
	assert_eq(pike.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Fixture: a melee weapon.')
	assert_gt(pike.threat - UnitRelation.distance_between(knot, adjacent), UnitRelation.distance_between(adjacent, near) - 1,
		'Fixture: its leg would reach the near character, so only the ranged gate can refuse it.')
	await fire(PIKE, adjacent, [14])
	assert_gt(adjacent.current_damage(), 0, 'Guard: the pike landed.')
	assert_eq(near.current_damage(), 0, 'Nobody else touched.')
	assert_eq(yesnos(), 0, 'Melee is not "a Ranged or Line weapon".')
	await fire(Fixture.RANGED, adjacent, [19], [plan_unit(second)])
	assert_eq(yesnos(), 1, 'CONTROL: the rifle at the same adjacent contact is offered.')

func test_a_drone_the_knot_owns_is_not_offered() -> void:
	# get_attacker() of an owned drone IS the Knot, so only "the declared unit is the Knot itself" can
	# refuse this - the drone is not the Lovers Knot attacking.
	var second := second_at()
	var drone := Fixture.create_dummy(game, Vector2i(1, 2), 10, Faction.PLAYER)
	Fixture.equip(drone, Fixture.RANGED)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	drone.state.set_owner(knot)
	assert_eq(drone.get_attacker(), knot, 'Fixture: the drone answers to the Knot.')
	await fire(Fixture.RANGED, contact, [14], [], [], drone)
	assert_gt(contact.current_damage(), 0, 'Guard: the drone\'s shot landed.')
	assert_eq(yesnos(), 0, 'A drone\'s attack is not offered.')
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(yesnos(), 1, 'CONTROL: the Knot\'s own shot is.')

func test_a_contact_that_is_not_a_character_is_not_offered() -> void:
	var second := second_at()
	var drone := Fixture.create_hostile_drone(game, DRONE_TILE)
	assert_false(drone.is_actor(), 'Fixture: a drone is not a character (ruling 3).')
	await fire(Fixture.RANGED, drone, [14])
	assert_gt(drone.current_damage(), 0, 'Guard: the shot landed.')
	assert_eq(yesnos(), 0, '"Upon contact with a character": a drone is not one.')
	await fire_again(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(yesnos(), 1, 'CONTROL: a character contact, the same round, is offered.')

func test_an_ai_controlled_knot_never_redirects() -> void:
	knot.remove_from_game()
	contact.remove_from_game()
	knot = Fixture.create_knot(game, KNOT_TILE, Faction.AI_ENEMY)
	Fixture.equip(knot, Fixture.RANGED)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, recorder)
	contact = Fixture.create_dummy(game, CONTACT_TILE, 10, Faction.PLAYER)
	var second := second_at(SECOND_TILE, 10, Faction.PLAYER)
	assert_true(UnitCondition.has_buff(knot, Fixture.GEMINI_BUFF), 'Fixture: the AI Knot holds Gemini Charge.')
	await fire(Fixture.RANGED, contact, [14])
	assert_gt(contact.current_damage(), 0, 'Guard: the shot landed.')
	assert_eq(contact.current_damage(), 6, 'Not halved: no redirect (ruling 16c).')
	assert_eq(second.current_damage(), 0, 'Nobody else touched.')
	assert_eq(Fixture.gemini_uses(knot), 0, 'And no round spent.')


# ============ RANGE AND THE PICKER'S SET (ruling 12) ============

func test_the_pick_offers_what_the_contact_sees_within_the_remaining_range() -> void:
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 3, WALL)
	var second := second_at()
	var far := second_at(FAR_TILE)
	UnitTile.update_tracking_and_statuses(game.map)
	var from_knot := UnitTargeting.get_tiles_targetable(SpecificAction.create(knot, knot.get_gear(Fixture.RANGED), knot.get_gear(Fixture.RANGED).get_solo_action()))
	assert_false(from_knot.has(SECOND_TILE), 'Fixture: the wall hides the second target from the Knot.')
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(captures.size(), 1, 'One pick.')
	if captures.is_empty(): return
	var capture:Dictionary = captures[0]
	assert_eq(capture.reach, 7, 'The remaining range: 10 - 3.')
	assert_true(capture.targetable.has(SECOND_TILE), 'The wall-hidden target is offered from the contact.')
	assert_false(capture.targetable.has(FAR_TILE), 'The one 8 from the contact is past the remaining 7.')
	assert_false(capture.targetable.has(CONTACT_TILE), 'The contact is not offered again (each character once).')
	assert_false(capture.targetable.has(KNOT_TILE), 'Nor the Knot itself.')
	# CONTROL: the same weapon from the same space, at its full reach and unscoped.
	assert_true(capture.unscoped.has(FAR_TILE), 'CONTROL: at the full 10 the far target WOULD be offered.')
	assert_true(capture.unscoped.has(CONTACT_TILE), 'CONTROL: and the contact would.')
	assert_true(capture.unscoped.has(KNOT_TILE), 'CONTROL: and the Knot would.')
	assert_eq(second.current_damage(), 3, 'The hidden target is hit.')
	assert_eq(far.current_damage(), 0, 'The far one is not.')


# ============ A LINE BENDS (ruling 13) ============

func test_a_line_bends_at_the_contact() -> void:
	var second := second_at()
	var past := second_at(PAST_TILE)
	Fixture.equip(knot, Fixture.LINE)
	await fire(Fixture.LINE, LINE_AIM, [14], [plan_tile(LINE_SECOND_AIM)])
	assert_eq(captures.size(), 1, 'One pick, from the contact.')
	if not captures.is_empty(): assert_eq(captures[0].reach, 7, 'Line 10, 3 used.')
	var summary := last_summary()
	if summary == null:
		fail_test('the attack must have been declared')
		return
	assert_eq(summary.all_attacked_units, [contact, second] as Array[Unit], 'The contact, then the leg: nobody past the contact.')
	assert_eq(past.current_damage(), 0, 'The shot changed direction at the contact: the unit past it is not hit.')
	assert_eq(contact.current_damage(), 4, '1d6+1 = 7, halved up to 4.')
	assert_eq(second.current_damage(), 4, 'The leg\'s character too.')
	assert_true(summary.all_attacked_tiles.has(Vector2i(3, 4)), 'The first leg up to the contact stays.')
	assert_false(summary.all_attacked_tiles.has(Vector2i(5, 4)), 'The first tile past the contact is cut.')
	assert_false(summary.all_attacked_tiles.has(PAST_TILE), 'And the rest.')
	assert_true(summary.all_attacked_tiles.has(Vector2i(4, 5)), 'The leg starts beside the contact.')
	assert_true(summary.all_attacked_tiles.has(LINE_SECOND_AIM), 'And runs the remaining 7.')
	assert_false(summary.all_attacked_tiles.has(Vector2i(4, 12)), 'And not an eighth tile.')

func test_a_line_with_no_character_on_any_leg_is_not_offered() -> void:
	Fixture.equip(knot, Fixture.LINE)
	await fire(Fixture.LINE, LINE_AIM, [14])
	assert_gt(contact.current_damage(), 0, 'Guard: the rail landed.')
	assert_eq(yesnos(), 0, 'No leg could reach another character: not offered.')
	var second := second_at()
	await fire_again(Fixture.LINE, LINE_AIM, [14], [plan_tile(LINE_SECOND_AIM)])
	assert_eq(yesnos(), 1, 'CONTROL: with one within reach, it is.')
	assert_gt(second.current_damage(), 0, 'And hit.')


# ============ ONE D20 FACE, EACH TARGET'S OWN DICE (rulings 9-11) ============

func test_the_redirected_target_shares_the_contacts_d20() -> void:
	var second := second_at()
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	var first := roll_against(contact)
	var roll := roll_against(second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_eq(first.base_roll, 14, 'The contact rolled the cheated 14.')
	assert_eq(roll.base_roll, 14, 'The redirected target carries the SAME d20 face.')
	assert_eq(roll.total_roll, 14, 'With no dice of its own, the same total.')
	assert_true(roll.hit, '14 beats evasion 10.')
	assert_false(roll.crit, 'Not a crit.')

func test_a_higher_evasion_misses_on_the_same_face_and_reliable_is_halved() -> void:
	var second := second_at(SECOND_TILE, 15)
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	var first := roll_against(contact)
	var roll := roll_against(second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_true(first.hit, 'The contact (evasion 10) is hit by 14.')
	assert_false(roll.hit, 'The redirected target (evasion 15) is missed by the same 14: its OWN defense.')
	assert_eq(roll.base_roll, 14, 'The miss shows the shared face.')
	assert_eq(second.current_damage(), 1, 'The rifle\'s Reliable 2 on a miss, halved: 1 (ruling 14).')

func test_the_redirected_targets_own_cover_from_the_contact_changes_only_its_total() -> void:
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 1, [LOW_BLOCK])
	var second := second_at()
	UnitTile.update_tracking_and_statuses(game.map)
	assert_eq(CoverCalculator.determine_cover(second, knot).total, Lancer.COVER.NONE, 'Fixture: from the Knot, no cover.')
	assert_eq(CoverCalculator.determine_cover(second, knot, UnitTile.get_occupied_voxels(contact)).total, Lancer.COVER.HARD,
		'Fixture: from the contact\'s space, HARD cover.')
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	var first := roll_against(contact)
	var roll := roll_against(second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_eq(first.pre.cover, Lancer.COVER.NONE, 'The contact: no cover.')
	assert_eq(first.total_roll, 14, 'The contact: 14.')
	assert_eq(roll.pre.cover, Lancer.COVER.HARD, 'The redirected target: HARD, measured from the contact (ruling 10).')
	assert_eq(roll.pre.accuracy_mods_total(), -2, 'Hard cover is two difficulty.')
	assert_eq(roll.base_roll, 14, 'The same face.')
	assert_eq(roll.total_roll, 14 + roll.accuracy_roll, 'Its total is the face plus its OWN dice.')
	assert_lt(roll.accuracy_roll, 0, 'The difficulty dice were rolled for it alone.')
	assert_false(roll.hit, 'Two sixes of difficulty: 8 misses evasion 10.')

func test_cover_measured_from_the_knot_is_not_applied_to_the_redirected_target() -> void:
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 3, WALL)
	var second := second_at()
	UnitTile.update_tracking_and_statuses(game.map)
	assert_eq(CoverCalculator.determine_cover(second, knot).total, Lancer.COVER.HARD, 'Fixture: from the Knot, HARD.')
	assert_eq(CoverCalculator.determine_cover(second, knot, UnitTile.get_occupied_voxels(contact)).total, Lancer.COVER.NONE,
		'Fixture: from the contact, none.')
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	var roll := roll_against(second)
	if roll == null:
		fail_test('the redirected roll must exist')
		return
	assert_eq(roll.pre.cover, Lancer.COVER.NONE, 'The Knot\'s cover is suppressed for the redirected target.')
	assert_eq(roll.pre.accuracy_mods_total(), 0, 'No difficulty from it.')
	assert_true(roll.hit, '14 hits.')

func test_a_total_of_20_crits_the_redirected_target_only() -> void:
	var second := second_at()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), second, IncomingAccuracy.new())
	await fire(Fixture.RANGED, contact, [17], [plan_unit(second)])
	var first := roll_against(contact)
	var roll := roll_against(second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_false(first.crit, 'The contact: 17, a hit.')
	assert_eq(roll.base_roll, 17, 'The same face.')
	assert_eq(roll.total_roll, 23, 'Plus its own accuracy die: 23.')
	assert_true(roll.crit, 'A total of 20 or more crits (ruling 9).')

func test_an_invisible_redirected_target_is_missed_on_a_low_invisibility_roll() -> void:
	var second := second_at()
	SpecFactory.apply(second, Lancer.STATUS.INVISIBLE)
	await fire(Fixture.RANGED, contact, [19, 1], [plan_unit(second)])
	var first := roll_against(contact)
	var roll := roll_against(second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_true(first.hit, 'The contact is hit.')
	assert_false(roll.hit, 'The Invisible redirected target is missed on a 1 (ruling 11).')
	assert_true(roll.roll_modifications.has(&'invisibility'), 'And the roll says why.')

func test_an_invisible_redirected_target_is_hit_on_a_high_invisibility_roll() -> void:
	var second := second_at()
	SpecFactory.apply(second, Lancer.STATUS.INVISIBLE)
	await fire(Fixture.RANGED, contact, [19, 6], [plan_unit(second)])
	var roll := roll_against(second)
	if roll == null:
		fail_test('the redirected roll must exist')
		return
	assert_true(roll.hit, 'CONTROL: a 6 on the invisibility die, and the shared face hits.')
	assert_eq(roll.base_roll, 19, 'With the shared face.')
	assert_false(roll.roll_modifications.has(&'invisibility'), 'Not an invisibility miss.')

func test_a_contact_that_rolled_no_d20_leaves_the_redirected_target_its_own_roll() -> void:
	var second := second_at()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), contact, AutoHitMe.new())
	await fire(Fixture.RANGED, contact, [3], [plan_unit(second)])
	var first := roll_against(contact)
	var roll := roll_against(second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_true(first.hit, 'The contact was auto-hit.')
	assert_eq(first.base_roll, 0, 'Without a d20.')
	assert_eq(roll.base_roll, 3, 'So the redirected target rolled its own: the queued 3.')
	assert_false(roll.hit, '3 misses.')


# ============ ONCE PER ROUND (ruling 7) ============

func test_one_redirect_a_round() -> void:
	var second := second_at()
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(second.current_damage(), 3, 'Fixture: the first shot redirected.')
	var contact_before:int = contact.current_damage()
	await fire_again(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_gt(contact.current_damage(), contact_before, 'Guard: the second shot landed.')
	assert_eq(yesnos(), 1, 'The second shot the same round is not offered.')
	assert_eq(second.current_damage(), 3, 'And the second target is untouched by it.')
	# CONTROL: the Knot's own next turn opens a new round (ruling 3).
	await Fixture.cycle_turn(game, knot)
	assert_eq(Fixture.gemini_uses(knot), 0, 'Fixture: the round reset.')
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(yesnos(), 2, 'A new round: offered again.')
	assert_eq(second.current_damage(), 6, 'And redirected again.')


# ============ A POST READER SEES BOTH (ruling 15, compat) ============

func test_a_post_reader_sees_the_appended_target() -> void:
	var second := second_at()
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(recorder.seen.size(), 1, 'One ATTACK_DECLARED POST.')
	if recorder.seen.is_empty(): return
	assert_eq(recorder.seen[0].units, [contact, second] as Array[Unit], 'It sees the contact and the redirected target.')
