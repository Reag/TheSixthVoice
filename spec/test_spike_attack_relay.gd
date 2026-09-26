# LOVERS KNOT SPIKE 8 PROBE: the attack relay (roadmap §2 block 18, §5 row 8).
#
# THE QUESTION. Buff.TO.SET_ATTACK_ROOT and SET_ATTACK_RELAY exist; find out what they do and whether
# Gemini Charge - "redirect the shot upon contact with a character; from that character's space the
# remaining Line, Range and LOS is drawn to another character; one attack roll against all; all
# damage halved" - can be built on them.
#
# WHAT THE TWO KEYS ARE (code read, pinned by tests a and b):
#   SET_ATTACK_ROOT   unit.gd:281 - a deployable carrying it answers for its OWN shots (get_attacker
#                     returns self instead of get_owner_unit_or_self). Blame, not geometry.
#   SET_ATTACK_RELAY  action_attack.gd:120-127, read ONCE at the top of activate (:233) - swaps
#                     specific.unit for another unit for the WHOLE activation: targeting, range, LOS,
#                     the AoE origin, the summary's source_voxels, and the declared event's `unit`.
#                     One origin per attack. Throughbolt Rounds is the worked example: a proxy at
#                     the line's end, the real weapon fired from it.
#
# SO A TWO-ORIGIN SHOT IS NOT A RELAY. The relay moves the one origin; Gemini Charge keeps the first
# target AND adds a second one seen from the first target's space. The seam for that is the
# ATTACK_DECLARED PRE timing (native_reliable.gd's), where the DeclaredAttackSummary already exists
# and event_unit_attack_declared.execute has not yet duplicated all_attacked_units (:54) - so a
# unit APPENDED there gets its own event_unit_attack in the same declared attack. (Spike 3's
# finding that an added unit is never rolled was about ATTACK PRE, the per-target timing, which is
# after :54.) The picker from the contact's space is vanilla's own
# TargetActionUtil.ask_for_targets_from_proxy, with the weapon duplicated at the remaining range.
#
# PROBES.
#   a  SET_ATTACK_ROOT: an owned dummy blames its owner; with the buff, itself.
#   b  SET_ATTACK_RELAY: a relay buff on the attacker makes the declared event's unit the proxy,
#      get_attacker the attacker, source_voxels the proxy's; a target the attacker cannot see is hit.
#   c  A proxy ON the contact's tile offers what the contact sees within the remaining range, and
#      not beyond it; the attacker's own set does not offer the wall-hidden second target.
#   d  A unit appended at ATTACK_DECLARED PRE is rolled against and damaged in the SAME declared
#      attack (one ATTACK_DECLARED, two attack_rolls).
#   e  HALF_DAMAGE put on the declared context's flags at PRE halves every target's damage.
#   f  "One attack roll": a MODIFY_ATTACK_ROLL buff at auto_miss / auto_hit / turn_hit_to_crit
#      answers the second roll from the first roll's total against the second target's own defense,
#      and copies the numbers so the log shows one roll. Miss, hit and crit cases.
#   g  Cover for the appended target is measured from the summary's source_voxels - the attacker's
#      - by default; an attacker-side IGNORE_COVER scoped to that target zeroes it, and the cover
#      the card wants (from the contact's space) is one determine_cover call.
#   h  A LINE weapon: the second leg is a line of the remaining length from the contact's tile,
#      its tiles and units appended.
#
# MUTATION KNOBS (each must go red exactly where named):
#   APPEND_SECOND_TARGET := false  ->  d, e, f, g, h: the second target is never rolled
#   HALVE := false                 ->  e (6 not 3), h
#   SHARE_ROLL := false            ->  f: the second target rolls its own d20
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/spike8.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_attack_relay.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## MUTATION KNOBS. The claims under test as written.
const APPEND_SECOND_TARGET := true
const HALVE := true
const SHARE_ROLL := true

const RIFLE := &'mw_assault_rifle' # MAIN, RIFLE, 1d6, RELIABLE 2, aim_range 10
const RAIL := &'mw_rail_rifle' # MAIN, LINE 10, 1d6+1, self-heat 1 (flat)
const STAMP := &'reag_spike8_gemini'

const MAP_SIZE := Vector2i(20, 16)
const KNOT_TILE := Vector2i(1, 4)
const CONTACT_TILE := Vector2i(4, 4) # 3 from the Knot: the rifle has 7 left, the rail 7
const SECOND_TILE := Vector2i(4, 7) # 3 south of the contact, behind the wall from the Knot
const FAR_TILE := Vector2i(4, 12) # 8 south of the contact: past a remaining 7, inside a full 10
const RELAY_TILE := Vector2i(4, 5) # a free tile the second target is visible from (test b)
const DRONE_TILE := Vector2i(8, 1)
const LINE_AIM := Vector2i(11, 4) # the rail's first leg, due east
const LINE_SECOND_AIM := Vector2i(4, 11) # the second leg, due south from the contact
## Height-3 blocks between the Knot and the second target; the contact's column (x = 4) stays open.
const WALL:Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5), Vector2i(2, 6), Vector2i(3, 6), Vector2i(2, 7), Vector2i(3, 7)]


# ============ RUNTIME BUFFS ============

class RootBuff extends Buff:
	func _init() -> void:
		compcon_id = &'buff_spike8_root'
		to = Buff.TO.SET_ATTACK_ROOT
		hide_from_player = true

class RelayTo extends Buff:
	var relay:Unit
	func _init(_relay:Unit) -> void:
		relay = _relay
		compcon_id = &'buff_spike8_relay'
		to = Buff.TO.SET_ATTACK_RELAY
		is_onetime = true
		hide_from_player = true
	func get_values(_core:BuffCore, _context:Context) -> Context:
		return Context.create({unit = relay})

## Attacker-side IGNORE_COVER for ONE target only (test g).
class IgnoreCoverAgainst extends Buff:
	var target:Unit
	func _init(_target:Unit) -> void:
		target = _target
		compcon_id = &'buff_spike8_ignore_cover'
		to = Buff.TO.IGNORE_COVER
		hide_from_player = true
	func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
		return context.target_unit == target

## Records every ATTACK_DECLARED the holder makes, at one timing.
class DeclaredRecorder extends Buff:
	var seen:Array[Dictionary] = []
	func _init(timing:ReactionBus.TIMING) -> void:
		compcon_id = &'buff_spike8_recorder_%s' % Util.enum_to_str(ReactionBus.TIMING, timing)
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = timing
		hide_from_player = true
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.resource]
	func triggers_on_event(_core:BuffCore, unit:Unit, triggering:EventCore) -> bool:
		return triggering.context.unit.get_attacker(triggering.context) == unit
	func activate(_core:BuffCore, activation:EventCore) -> void:
		var context:Context = activation.context.event.context
		var summary:DeclaredAttackSummary = context.resource
		seen.append({
			unit = context.unit,
			attacker = context.unit.get_attacker(context),
			source = summary.source_voxels.duplicate(),
			summary = summary,
		})

## "One attack roll against all": at the second (and later) target's auto_miss / auto_hit /
## turn_hit_to_crit steps, answer from the FIRST roll's total against THIS target's own defense, and
## copy the numbers onto the roll so the log reads as one roll. One buff for all three steps -
## three would collide on apply_buff_alt's same-id/same-to/same-until replacement. Not one-time
# (check_buffs_for_step consumes what it uses); FINISH_DAMAGE outlives every per-target roll.
class SharedRoll extends BuffModifyAttackRoll:
	func _init() -> void:
		compcon_id = &'buff_spike8_shared_roll'
		to = Buff.TO.MODIFY_ATTACK_ROLL
		until = Lancer.UNTIL.FINISH_DAMAGE
		is_onetime = false
		hide_from_player = true
		applies_when_holder_is = APPLIES_WHEN.attacker

	static func first_roll_for(summary, target:Unit) -> AttackRoll:
		if not DeclaredAttackSummary.is_valid(summary) or not summary.has_meta(STAMP): return null
		if summary.attack_rolls.is_empty(): return null
		var first:AttackRoll = summary.attack_rolls[0]
		if not AttackRoll.is_valid(first) or first.target_unit == target: return null
		return first

	func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
		if core.get_holder_unit(context.map) != context.unit: return false
		var per_target:EventCore = context.event
		var first := first_roll_for(per_target.context.resource, context.target_unit)
		if first == null: return false
		var roll:AttackRoll = context.object
		var hit := first.total_roll >= roll.pre.target_defense
		var crit := hit and first.total_roll >= 20
		match context.category_int:
			EventUnitAttack.SEQUENCE_STEP.auto_miss: return not hit
			EventUnitAttack.SEQUENCE_STEP.auto_hit: return hit
			EventUnitAttack.SEQUENCE_STEP.turn_hit_to_crit: return crit
		return false

	func confirm_modification(_core:BuffCore, roll:AttackRoll, activation:EventCore) -> bool:
		var first := first_roll_for(activation.context.resource, roll.target_unit)
		if first == null: return false
		roll.base_roll = first.base_roll
		roll.accuracy_roll = first.accuracy_roll
		roll.total_roll = first.total_roll
		return true

## The Gemini Charge stand-in: at ATTACK_DECLARED PRE on the holder's own ranged weapon attack,
## pick a second target from the first character's space at the remaining range, append it to the
## summary, halve the attack, and hang the shared-roll buff.
class GeminiStandIn extends Buff:
	var picks_seen := 0
	var last_remaining := -1
	func _init() -> void:
		compcon_id = &'buff_spike8_gemini'
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = ReactionBus.TIMING.PRE
		hide_from_player = true

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action, Context.PROP.resource]

	static func first_character(summary:DeclaredAttackSummary) -> Unit:
		for unit:Unit in summary.all_attacked_units:
			if Unit.is_valid(unit) and unit.is_character(): return unit
		return null

	func triggers_on_event(_core:BuffCore, unit:Unit, triggering:EventCore) -> bool:
		var context:Context = triggering.context
		if context.unit.get_attacker(context) != unit: return false
		if not (context.action is ActionAttackWeapon): return false
		if UnitAction.is_melee_weapon(context.action, context.gear): return false
		if context.resource.has_meta(STAMP): return false
		return first_character(context.resource) != null

	func activate(core:BuffCore, activation:EventCore) -> void:
		var triggering:EventCore = activation.context.event
		var context:Context = triggering.context
		var knot:Unit = core.get_holder_unit(activation.context.map)
		var summary:DeclaredAttackSummary = context.resource
		var action:ActionAttackWeapon = context.action
		var contact:Unit = first_character(summary)
		summary.set_meta(STAMP, true)

		# "the remaining Line, Range and Line of Sight": the weapon again, shortened by the first leg
		var specific := SpecificAction.create(knot, context.gear, action)
		var remaining:int = action.get_target_range(specific) - UnitTile.distance_to(knot, contact.tile())
		last_remaining = remaining
		if remaining <= 0: return
		var leg:ActionAttackWeapon = action.create_duplicate_for_variant()
		if leg.range_pattern:
			leg.range_pattern = leg.range_pattern.duplicate() # a sub-resource, shared until duplicated
			leg.range_pattern.value = remaining
		else:
			leg.aim_range = remaining

		# vanilla's own "attack from a place that is not ourselves"
		var plan:CompconPlan = await TargetActionUtil.ask_for_targets_from_proxy(
			activation, knot, context.gear, leg, contact.tile(), contact.get_size())
		picks_seen += 1
		if plan == null or plan.aborted: return
		if plan.target_tiles.is_empty() and plan.target_units.is_empty(): return

		var new_units:Array[Unit] = []
		var new_tiles:Array[Vector2i] = []
		if leg.range_pattern: # a Line: the second leg's tiles, and whoever stands on them
			new_tiles = AoeCalculator.line(contact.tile(), plan.target_tiles[0], remaining, knot.map.shape)
			new_units.assign(knot.map.get_all_units_at_tiles(new_tiles, knot))
		else:
			new_units.assign(plan.target_units)
			for unit:Unit in plan.target_units: new_tiles.append_array(unit.occupied_tiles())
		Util.filter(new_units, func(unit:Unit) -> bool:
			return unit != contact and not summary.all_attacked_units.has(unit) and action.can_target_unit(unit, specific))

		if APPEND_SECOND_TARGET:
			for unit:Unit in new_units: summary.all_attacked_units.append(unit)
			for tile:Vector2i in new_tiles: Util.append_nonduplicate(summary.all_attacked_tiles, tile)
		if HALVE and not context.flags.has(Action.FLAG.HALF_DAMAGE):
			context.flags = context.flags.duplicate() + [Action.FLAG.HALF_DAMAGE]
		if SHARE_ROLL: UnitCondition.apply_buff(activation, knot, SharedRoll.new())


# ============ FIXTURE ============

var game:Gamemaster
var knot:Unit
var rifle:GearCore
var contact:Unit
var second:Unit
var gemini:GeminiStandIn
var declared:DeclaredRecorder

func before_each() -> void:
	game = Fixture.create_game(self, MAP_SIZE)
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 3, WALL)
	knot = SpecFactory.create_unit(game.map, KNOT_TILE, Faction.PLAYER)
	rifle = knot.core.equip_system(RIFLE)
	knot.core.full_repair()
	contact = Fixture.create_dummy(game, CONTACT_TILE, 10)
	second = Fixture.create_dummy(game, SECOND_TILE, 10)
	UnitTile.update_tracking_and_statuses(game.map)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func arm_gemini() -> void:
	gemini = GeminiStandIn.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, gemini)
	declared = DeclaredRecorder.new(ReactionBus.TIMING.POST)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, declared)

func fire(weapon:GearCore, plans:Array[CompconPlan]) -> void:
	SpecFactory.current_responder.chosen_plan_queue.assign(plans)
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(),
		gear = weapon,
		unit = knot,
	})

func plan_unit(unit:Unit) -> CompconPlan: return CompconPlan.create([unit.tile()], [], [unit])
func plan_tile(tile:Vector2i) -> CompconPlan: return CompconPlan.create([tile])

func last_summary() -> DeclaredAttackSummary:
	if declared == null or declared.seen.is_empty(): return null
	return declared.seen.back().summary

func roll_against(summary:DeclaredAttackSummary, target:Unit) -> AttackRoll:
	if summary == null: return null
	for roll:AttackRoll in summary.attack_rolls:
		if roll.target_unit == target: return roll
	return null


# ============ a, b: WHAT THE TWO KEYS DO ============

func test_a_set_attack_root_makes_an_owned_unit_answer_for_its_own_shots() -> void:
	var drone := Fixture.create_dummy(game, DRONE_TILE, 10, Faction.PLAYER)
	drone.state.set_owner(knot)
	assert_eq(drone.get_attacker(), knot, 'FACT: an owned unit blames its owner (get_owner_unit_or_self)')
	UnitCondition.apply_buff(SpecFactory.dummy_event(), drone, RootBuff.new())
	assert_eq(drone.get_attacker(), drone, 'SET_ATTACK_ROOT: it answers for itself (unit.gd:281)')
	assert_eq(knot.get_attacker(), knot, 'a unit with no owner is its own attacker either way')

func test_b_set_attack_relay_moves_the_whole_attacks_origin_to_the_relay() -> void:
	var recorder := DeclaredRecorder.new(ReactionBus.TIMING.PRE)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, recorder)
	var proxy := TargetActionUtil.create_targeting_proxy(RELAY_TILE, knot, 1)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, RelayTo.new(proxy))
	Dice.CHEAT_ROLL_QUEUE.assign([19, 6])
	await fire(rifle, [plan_unit(second)])

	assert_eq(recorder.seen.size(), 1, 'one declared attack')
	if recorder.seen.size() != 1: return
	var seen:Dictionary = recorder.seen[0]
	assert_eq(seen.unit, proxy, 'RELAY: the declared event\'s unit is the relay')
	assert_eq(seen.attacker, knot, 'RELAY: get_attacker resolves through the proxy\'s owner to the Knot')
	assert_eq(seen.source, UnitTile.get_occupied_voxels(proxy), 'RELAY: source_voxels (cover origin) are the relay\'s')
	assert_eq(second.current_damage(), 6, 'the target the Knot cannot see is hit from the relay')
	assert_false(UnitCondition.has_buff(knot, &'buff_spike8_relay'), 'the one-time relay buff is consumed at activate (:126)')
	proxy.remove_from_game()


# ============ c: THE PICKER FROM THE CONTACT'S SPACE ============

func test_c_a_proxy_on_the_contacts_tile_offers_what_the_contact_sees_within_the_remaining_range() -> void:
	# a non-AoE weapon offers only tiles that HOLD a target (unit_targeting.gd:98-115), so the far
	# dummy has to exist before anything is asked
	var far := Fixture.create_dummy(game, FAR_TILE, 10)
	UnitTile.update_tracking_and_statuses(game.map)
	var action:ActionAttackWeapon = rifle.get_solo_action()
	var from_knot := UnitTargeting.get_tiles_targetable(SpecificAction.create(knot, rifle, action))
	assert_true(from_knot.has(CONTACT_TILE), 'the Knot sees the contact')
	assert_false(from_knot.has(SECOND_TILE), 'the wall hides the second target from the Knot')
	assert_lte(UnitTile.distance_to(knot, FAR_TILE), 10, 'FACT: by distance alone the far target is inside the Knot\'s own 10 (Chebyshev triangle: contact-relative reach never exceeds the weapon\'s reach) - the redirect buys sight and a second body, never distance')

	var proxy := TargetActionUtil.create_targeting_proxy(CONTACT_TILE, knot, 1)
	var leg:ActionAttackWeapon = action.create_duplicate_for_variant()
	leg.aim_range = 7 # 10 - 3
	var from_contact := UnitTargeting.get_tiles_targetable(SpecificAction.create(proxy, rifle, leg))
	assert_true(from_contact.has(SECOND_TILE), 'from the contact\'s own tile the second target is in range and sight')
	assert_false(from_contact.has(FAR_TILE), 'the far target, 8 from the contact, is past the remaining 7')
	assert_true(from_contact.has(CONTACT_TILE), 'FACT: the contact, standing on the proxy\'s tile, is itself offered - production must exclude it')

	var full:ActionAttackWeapon = action.create_duplicate_for_variant()
	var from_contact_full := UnitTargeting.get_tiles_targetable(SpecificAction.create(proxy, rifle, full))
	assert_true(from_contact_full.has(FAR_TILE), 'control: at the weapon\'s full 10 the far target IS offered - the range really was the remaining 7')
	proxy.remove_from_game()
	far.remove_from_game()


# ============ d, e: APPEND AT ATTACK_DECLARED PRE ============

func test_d_a_unit_appended_at_attack_declared_pre_is_rolled_in_the_same_declared_attack() -> void:
	arm_gemini()
	Dice.CHEAT_ROLL_QUEUE.assign([19, 6])
	await fire(rifle, [plan_unit(contact), plan_unit(second)])

	assert_eq(gemini.picks_seen, 1, 'the stand-in asked once, from the contact\'s space')
	assert_eq(gemini.last_remaining, 7, 'the remaining range was 10 - 3')
	assert_eq(declared.seen.size(), 1, 'ONE declared attack (counts as one attack)')
	var summary := last_summary()
	if summary == null: return
	assert_eq(summary.attack_rolls.size(), 2, 'two attack rolls on the one summary')
	assert_eq(summary.all_attacked_units, [contact, second] as Array[Unit], 'the contact first, the appended second')
	var roll := roll_against(summary, second)
	assert_not_null(roll, 'the appended unit got its own event_unit_attack')
	if roll: assert_true(roll.hit, 'and it was hit')
	assert_gt(second.current_damage(), 0, 'and damaged, in the same attack')
	assert_gt(contact.current_damage(), 0, 'the contact still took its own hit')

func test_e_half_damage_on_the_declared_context_at_pre_halves_every_target() -> void:
	arm_gemini()
	Dice.CHEAT_ROLL_QUEUE.assign([19, 6])
	await fire(rifle, [plan_unit(contact), plan_unit(second)])
	assert_eq(contact.current_damage(), 3, 'the contact: 6 halved')
	assert_eq(second.current_damage(), 3, 'the second target: 6 halved')

func test_e2_control_without_the_stand_in_the_rifle_deals_full_damage_to_one_target() -> void:
	Dice.CHEAT_ROLL_QUEUE.assign([19, 6])
	await fire(rifle, [plan_unit(contact)])
	assert_eq(contact.current_damage(), 6, 'control: a plain shot is 6')
	assert_eq(second.current_damage(), 0, 'control: nobody else is touched')


# ============ f: ONE ATTACK ROLL ============

func test_f_the_second_target_is_answered_from_the_first_targets_roll() -> void:
	arm_gemini()
	Dice.CHEAT_ROLL_QUEUE.assign([14, 6])
	await fire(rifle, [plan_unit(contact), plan_unit(second)])
	var summary := last_summary()
	var first := roll_against(summary, contact)
	var roll := roll_against(summary, second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_eq(first.base_roll, 14, 'the contact rolled the cheated 14')
	assert_eq(roll.base_roll, 14, 'the second target carries the SAME d20')
	assert_eq(roll.total_roll, first.total_roll, 'and the same total')
	assert_true(roll.hit, '14 beats evasion 10')
	assert_false(roll.crit, 'not a crit')
	assert_eq(second.current_damage(), 3, 'hit, halved')

func test_f2_a_higher_evasion_on_the_second_target_turns_the_shared_roll_into_a_miss() -> void:
	second.core.frame.stat.evasion = 15
	second.core.full_repair()
	arm_gemini()
	Dice.CHEAT_ROLL_QUEUE.assign([14, 6])
	await fire(rifle, [plan_unit(contact), plan_unit(second)])
	var summary := last_summary()
	var first := roll_against(summary, contact)
	var roll := roll_against(summary, second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_true(first.hit, 'the contact (evasion 10) is hit by 14')
	assert_false(roll.hit, 'the second target (evasion 15) is missed by the same 14')
	assert_eq(roll.base_roll, 14, 'the miss still shows the shared d20')
	assert_eq(second.current_damage(), 1, 'FACT: a miss still deals the rifle\'s Reliable 2, and "all damage halved" halves that too: 1')

func test_f3_a_natural_20_crits_both() -> void:
	arm_gemini()
	Dice.CHEAT_ROLL_QUEUE.assign([20, 6, 6])
	await fire(rifle, [plan_unit(contact), plan_unit(second)])
	var summary := last_summary()
	var first := roll_against(summary, contact)
	var roll := roll_against(summary, second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_true(first.crit, 'the contact crits on 20')
	assert_true(roll.crit, 'the second target crits on the shared 20 (turn_hit_to_crit)')
	assert_eq(roll.base_roll, 20, 'shared d20')


# ============ g: COVER FOR THE APPENDED TARGET ============

func test_g_cover_for_the_appended_target_is_measured_from_the_knot_by_default() -> void:
	arm_gemini()
	Dice.CHEAT_ROLL_QUEUE.assign([19, 6])
	await fire(rifle, [plan_unit(contact), plan_unit(second)])
	var roll := roll_against(last_summary(), second)
	if roll == null:
		fail_test('the second roll must exist')
		return
	assert_eq(roll.pre.cover, Lancer.COVER.HARD, 'DEFAULT: cover is computed from source_voxels (the Knot), and the wall is in the way')
	var from_contact := CoverCalculator.determine_cover(second, knot, UnitTile.get_occupied_voxels(contact))
	assert_eq(from_contact.total, Lancer.COVER.NONE, 'what the card wants: from the contact\'s space there is no cover')

func test_g2_an_attacker_side_ignore_cover_scoped_to_the_appended_target_zeroes_it() -> void:
	arm_gemini()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, IgnoreCoverAgainst.new(second))
	Dice.CHEAT_ROLL_QUEUE.assign([19, 6])
	await fire(rifle, [plan_unit(contact), plan_unit(second)])
	var summary := last_summary()
	var first := roll_against(summary, contact)
	var roll := roll_against(summary, second)
	if first == null or roll == null:
		fail_test('both rolls must exist')
		return
	assert_eq(roll.pre.cover, Lancer.COVER.NONE, 'the scoped IGNORE_COVER skips the cover calculation for the second target')
	assert_eq(first.pre.cover, Lancer.COVER.NONE, 'the contact had none anyway - the buff did not touch its roll')


# ============ h: A LINE WEAPON ============

func test_h_a_line_weapon_continues_as_a_line_of_the_remaining_length_from_the_contact() -> void:
	var rail := knot.core.equip_system(RAIL)
	knot.core.full_repair()
	arm_gemini()
	Dice.CHEAT_ROLL_QUEUE.assign([19, 6])
	await fire(rail, [plan_tile(LINE_AIM), plan_tile(LINE_SECOND_AIM)])

	assert_eq(gemini.picks_seen, 1, 'asked once from the contact\'s space')
	assert_eq(gemini.last_remaining, 7, 'Line 10, 3 used')
	var summary := last_summary()
	if summary == null: return
	assert_true(summary.all_attacked_units.has(contact), 'the contact, on the first leg')
	assert_true(summary.all_attacked_units.has(second), 'the second target, on the second leg')
	assert_true(summary.all_attacked_tiles.has(Vector2i(4, 5)), 'the second leg starts beside the contact')
	assert_true(summary.all_attacked_tiles.has(LINE_SECOND_AIM), 'and runs the remaining 7 to (4, 11)')
	assert_false(summary.all_attacked_tiles.has(Vector2i(4, 12)), 'and not an eighth tile')
	assert_eq(summary.attack_rolls.size(), 2, 'both rolled in the one attack')
	assert_eq(contact.current_damage(), 4, '1d6+1 = 7, halved up to 4')
	assert_eq(second.current_damage(), 4, 'the same for the second target')
