# RELIABLE TOP-UP - the shared payout for "increase Reliable" effects (Hazard: Weight of Fire, and
# the Statistical Compensator, which joined at SP3 - its +2 is armed per attack by a stamp on the
# DeclaredAttackSummary, because a FINISH_DAMAGE buff is gone before this POST runs). Author's ruling 2026-09-24, taken at Hazard SP1 Task 2: EXACT.
#
# WHY THIS EXISTS. The engine reads the Reliable floor ONCE, from the weapon action's own export, at
# content/events/event_unit_attack/event_unit_attack_declared.gd:82
# (`base_damage.reliable = unit.get_tiered_int(action.reliable_damage)`). A WEAPON_TAG buff adding
# &'reliable' reaches get_weapon_tags - the weapon CARD - and nothing else (measured by the Leoleth at
# its SP1 Task 9, and again here: a Reliable 2 + 2 rifle still missed for 2). Nothing writes
# DamageRollSummary.reliable afterwards and Buff.TO has no channel for it. A .gd_ext.gd on
# event_unit_attack_declared.gd is NOT an option: measured 2026-09-24, it fails to compile against the
# script's class_name (Godot #83542) at ContentLibrary's first build and leaves the event library's
# attack entry a bare RefCounted - every attack in the real game would break.
#
# SO THE BUFF STAYS FOR THE CARD, AND THIS PAYS THE DIFFERENCE AFTER THE FACT, at ATTACK_DECLARED
# POST (after every damage event of the attack has run). Per attack roll it asks the ENGINE'S OWN
# arithmetic twice - action.get_damage_for_attack on the roll's own DamageRollSummary, and on a
# duplicate whose `reliable` is raised by `extra` - so misses, low hits, crits, maximized rolls,
# bonus damage and DEAL_DOUBLE_DAMAGE all floor exactly as the engine would have floored them. The
# per-type difference goes out as ordinary event_unit_damage with vanilla's own flags
# (EventUnitAttackDeclared.get_damage_flags - AP, irreducible, halved).
#
# ARMOR IS COUNTED ONCE, BY THE ENGINE'S OWN MULTI-TYPE RULE. Each top-up carries `object =
# attack_roll`, and DamageModifications.create subtracts attack_roll.damage_reduction_from_armor from
# the target's armor (damage_modifications.gd, the "already been used elsewhere in this attack roll"
# line). That record holds the FULL armor value even when the roll's own damage was smaller than it,
# so it is first lowered to the armor the roll actually consumed - after which (dealt + top-up) meets
# armor exactly as one event of the raised amount would have. Exposed doubles both halves alike.
# RESISTANCE is the one residue: it halves each event separately, rounding UP each time, so a resisted
# top-up can land 1 more than a single resisted event would. Recorded, not fought.
#
# ONE PAYOUT PER DECLARED ATTACK. Several opted-in buffs may all trigger on the same POST; the first
# stamps the DeclaredAttackSummary and pays for ALL of them (their floors do not add linearly, so they
# must be paid together), the rest see the stamp and pass.
#
# OPTED_IN IS A WHITELIST, deliberately. The Leoleth's REACH buff (buff_rage_reach_reliable) also adds
# &'reliable', but REACH pays its own shortfall through action_reach_reliable.gd - counting it here
# would pay it twice.
#
# RefCounted, no class_name (the mod's shared-helper rule): preload it.
extends RefCounted

## The WEAPON_TAG Reliable buffs this helper pays for.
const OPTED_IN:Array[StringName] = [&'buff_weight_of_fire', &'buff_statistical_compensator']

## The gear-state-free stamp on the DeclaredAttackSummary.
const PAID_META := &'reag_reliable_topup_paid'

## The total extra Reliable the opted-in buffs give this weapon in this context - the same fold
## ActionAttackWeapon.get_weapon_tags makes, restricted to the whitelist.
static func extra_for(attacker:Unit, context:Context) -> int:
	if not Unit.is_valid(attacker): return 0
	var extra:int = 0
	for buff:BuffCore in UnitCondition.get_buffs_to(attacker, Buff.TO.WEAPON_TAG, context):
		if not OPTED_IN.has(buff.base.compcon_id): continue
		var values:Context = buff.base.get_values(buff, context)
		if values.category_str != Lancer.WEAPON_TAG.RELIABLE: continue
		extra += maxi(0, values.number)
	return extra

## True once this declared attack has been paid for.
static func is_paid(declared_context:Context) -> bool:
	return DeclaredAttackSummary.is_valid(declared_context.resource) and declared_context.resource.has_meta(PAID_META)

## Pay the top-up for one declared attack. `declared_context` is the ATTACK_DECLARED event's own
## context; `activation` is the caller's activation, whose block the damage events run in.
static func pay(activation:EventCore, declared_context:Context) -> void:
	if not DeclaredAttackSummary.is_valid(declared_context.resource): return
	var summary:DeclaredAttackSummary = declared_context.resource
	if summary.has_meta(PAID_META): return
	summary.set_meta(PAID_META, true)

	var attacker:Unit = declared_context.unit
	var action = declared_context.action
	if not Unit.is_valid(attacker) or not (action is ActionAttackWeapon): return
	var extra:int = extra_for(attacker, declared_context)
	if extra <= 0: return

	var specific := SpecificAction.from_context(declared_context)
	var is_halved:bool = declared_context.flags.has(Action.FLAG.HALF_DAMAGE)

	for attack_roll:AttackRoll in summary.attack_rolls.duplicate():
		if not AttackRoll.is_valid(attack_roll): continue
		var target:Unit = attack_roll.target_unit
		if not Unit.is_valid(target): continue # killed by the attack itself
		if not AttackUtil.DamageRollSummary.is_valid(attack_roll.damage): continue

		var dealt:Dictionary = action.get_damage_for_attack(declared_context, target, attack_roll.damage, attack_roll)
		var raised := AttackUtil.DamageRollSummary.create_duplicate(attack_roll.damage)
		raised.reliable += extra
		var should:Dictionary = action.get_damage_for_attack(declared_context, target, raised, attack_roll)

		var top_ups:Array = [] # [type, amount]
		for type in should.keys():
			var amount:int = int(should[type]) - int(dealt.get(type, 0))
			if amount > 0: top_ups.append([type, amount])
		if top_ups.is_empty(): continue

		# armor this roll really consumed: never more than the armor-bearing damage it dealt
		var armorable:int = 0
		for type in dealt.keys():
			if not [Lancer.DAMAGE_TYPE.HEAT, Lancer.DAMAGE_TYPE.BURN].has(type): armorable += int(dealt[type])
		attack_roll.damage_reduction_from_armor = mini(attack_roll.damage_reduction_from_armor, armorable)

		for index:int in top_ups.size():
			var is_last:bool = index == top_ups.size() - 1
			await activation.execute_event(&'event_unit_damage', {
				unit = target,
				number = top_ups[index][1],
				category = top_ups[index][0],
				flags = EventUnitAttackDeclared.get_damage_flags(attack_roll, specific, is_last, is_halved),
				object = attack_roll,
				target_unit = attacker,
				gear = declared_context.gear,
				action = action,
			})
			if not Unit.is_valid(target): break
