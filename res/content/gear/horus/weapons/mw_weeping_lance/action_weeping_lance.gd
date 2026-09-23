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
##  - can_target_unit: only a Locked On target ("consume Lock On" is the condition of the whole card);
##  - modify_pre_attack_data: the -1 that cancels buff_lock_consumed's +1 ("forgo the +1");
##  - action_weeping_lance_autoconsume.gd: the consume is MANDATORY, so the lock is really consumed and
##    the roll carries consumed_lock for BATS and THE BLOOD OF THE CREATURE.
##
## THE ENTRY IS GREYED OUT when no hostile on the map is Locked On (author, SP4): VariantAction.is_disabled
## keeps it visible and unpickable, so it never opens a targeting screen with nothing in it.
## The AI never picks it - generate_composed_action with no choices takes each group's index 0, the
## blank (event_gear_activate.gd:82-91).
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
	if is_forgo(specific.action) and not potential_target.has_status(Lancer.STATUS.LOCKON): return false
	return true

## Runs last in PreAttack.create (attack_roll.gd:192), after buff_lock_consumed's +1 was added.
func modify_pre_attack_data(context:Context, pre_attack_data:AttackRoll.PreAttack) -> void:
	super.modify_pre_attack_data(context, pre_attack_data)
	if is_forgo(context.action):
		pre_attack_data.add_mod(tr('gear.mw_weeping_lance.name'), -1, get_icon())
