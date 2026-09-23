## WEEPING LANCE, the Naga's rank-III weapon (SP4 Task 1, design ruling 18).
##
## "When you attack with this weapon and consume Lock On, you may choose to forgo the +1 Accuracy
##  from Lock On. If you do, the weapon damage becomes 2d6 + 4."
##
## THE CHOICE IS A VARIANT SUB-MENU (author, ruling 18): "No modification" is the plain 1d6+3 profile,
## FORGO is the 2d6+4 one. It must come BEFORE targeting because nothing later can reach either half:
## there is no damage-dice buff channel (get_damage_dice is per action, action_attack_weapon.gd:95)
## and no accuracy change after PreAttack.
##
## BUILT ON THE WEAPON'S OWN get_alternate_actions, NOT A BUFF (a departure from the design's
## mechanism, not its behaviour). The design hung a hidden buff_weeping_lance_variants from a
## PassiveBuffApplicator; vanilla weapons that own their sub-menu override this virtual instead
## (mw_ghoul_nexus, mw_plasma_thrower, mw_pinaka_missiles), which needs no passive, no buff and no
## compcon_id gate. The Thrown sub-menu still comes from super, so a thrown forgo is one pick of each.
##
## THE FORGO PROFILE, READ FROM ITS MARKER. VariantActionGroup appends the variant's key to
## modified_by_variants on the composed duplicate (variant_action_group.gd:117), so is_forgo() is how
## every other half of the card recognises it:
##  - can_target_unit: only a Locked On HOSTILE ("consume Lock On" is the condition of the whole card,
##    and vanilla's consume refuses a non-enemy, action_consume_lock_on.gd:62-67 - a Locked On ally
##    would consume nothing and still take the -1 and the 2d6+4);
##  - modify_pre_attack_data: the -1 that cancels buff_lock_consumed's +1 ("forgo the +1"), added ONLY
##    when that +1 is among the PreAttack's applied buffs. The real roll's PreAttack is built after the
##    consume and carries it, so it nets exactly 0; the attack preview builds its PreAttack from this
##    same forgo action BEFORE any consume (attack_preview.gd:46-48, action = specific.action at :119),
##    when there is no +1 to cancel, and an unconditional -1 showed the swing at net -1;
##  - action_weeping_lance_autoconsume.gd: the consume is MANDATORY, so the lock is really consumed and
##    the roll carries consumed_lock for BATS and THE BLOOD OF THE CREATURE.
##
## THE ENTRY IS GREYED OUT when no hostile on the map is Locked On (author, SP4): VariantAction.is_disabled
## keeps it visible and unpickable, so it never opens a targeting screen with nothing in it.
## THE AI CAN PICK IT (corrected at the frame close, 2026-09-23; the earlier claim here was wrong).
## The AI does not go through the sub-menu: ai_action_decider.gd:78 enumerates
## VariantActionGroup.get_variant_specifics, which composes EVERY variant into its own specific
## (variant_action_group.gd:95-99) and never reads is_disabled. So an AI or Hand-Over-Control Naga
## weighs the forgo profile like any other attack; can_target_unit still limits it to a Locked On
## hostile and the autoconsume still consumes. Accepted by the author; no behaviour change.
extends ActionAttackWeapon

const FORGO := &'weeping_lance_forgo'
const FORGO_DICE := '2d6+4'
const GROUP := &'weeping_lance'

static func is_forgo(action:Action) -> bool:
	return Action.is_valid(action) and action.modified_by_variants.has(FORGO)

## Is any hostile of `unit` on the map Locked On right now?
static func any_locked_hostile(unit:Unit) -> bool:
	if not Unit.is_valid(unit): return false
	for other:Unit in unit.map.get_all_units():
		if Unit.is_valid(other) and other.has_status(Lancer.STATUS.LOCKON) and UnitRelation.are_enemies(unit, other):
			return true
	return false

func get_alternate_actions(specific:SpecificAction, action_flags:Array = []) -> Array[VariantActionGroup]:
	var alternate_actions:Array[VariantActionGroup] = []
	var variant_group := VariantActionGroup.create(
		GROUP,
		tr('gear.mw_weeping_lance.name'),
		tr('gear.mw_weeping_lance.effect'),
		get_icon(),
		true, # blankable: the blank IS the plain profile
	)
	variant_group.append(VariantAction.create(
		FORGO,
		tr('gear.mw_weeping_lance.name'),
		tr('gear.mw_weeping_lance.effect'),
		get_icon(),
		func(modified_weapon:ActionAttackWeapon):
			modified_weapon.damage_dice = FORGO_DICE,
		not any_locked_hostile(specific.unit),
	))
	alternate_actions.append(variant_group)
	alternate_actions.append_array(super.get_alternate_actions(specific, action_flags))
	return alternate_actions

func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not super.can_target_unit(potential_target, specific): return false
	if is_forgo(specific.action) and not (
		potential_target.has_status(Lancer.STATUS.LOCKON) and UnitRelation.are_enemies(specific.unit, potential_target)
	): return false
	return true

## Runs last in PreAttack.create (attack_roll.gd:192), after the applied buffs' accuracy was added
## (:182-189). The -1 cancels buff_lock_consumed's +1, so it goes in only when that buff is among
## applied_buffs (collected from the target's ATTACK_ROLL_INCOMING buffs at :135) - see the header.
func modify_pre_attack_data(context:Context, pre_attack_data:AttackRoll.PreAttack) -> void:
	super.modify_pre_attack_data(context, pre_attack_data)
	if is_forgo(context.action) and carries_consumed_lock(pre_attack_data):
		pre_attack_data.add_mod(tr('gear.mw_weeping_lance.name'), -1, get_icon())

static func carries_consumed_lock(pre_attack_data:AttackRoll.PreAttack) -> bool:
	return pre_attack_data.applied_buffs.any(func(buff_core:BuffCore) -> bool:
		return BuffCore.is_valid(buff_core) and buff_core.base.compcon_id == &'buff_lock_consumed')
