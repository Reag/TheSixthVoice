## THE PSYCHOPOMP FOLD PIKE'S STRIKE - the attack the Uffish Gyre makes, and the only way this
## weapon ever attacks.
##
##   Weapon card: "PFP// \"PSYCHOPOMP\" Fold Pike. Main Melee, SP 0, no damage, Threat 8.
##    Effect: Gain the Uffish Gyre reaction, which is the only way you can attack with this weapon."
##   Reaction:   "Make a melee attack against evasion 8, on hit the allied character gains +2 armor
##    until the start of their next turn."
##
## THE LATCH DRONE SHAPE (design ruling 10). content/frames/ipsn/mf_lancaster/cp_latch_drone/
## action_latch_drone.gd is vanilla's own "attack an ALLY against a fixed defence and deal no damage"
## action, and its four overrides are copied here in shape: can_crit, get_damage_for_attack,
## modify_pre_attack_data and can_target_unit. What is NOT copied is its health and repair clauses -
## the Latch Drone refuses an ally at full health and refuses when neither side has a repair to
## spend, because it is a repair. The Gyre is armor, which a healthy ally wants as much as a hurt
## one, so both clauses are dropped.
##
## THE FIXED 8 IS THE LAST WORD ON THE ROLL, AND THAT IS WHY IT IS DONE HERE. AttackRoll.PreAttack
## seeds target_defense from AttackUtil.calculate_target_defense at attack_roll.gd:139 and then
## spends fifty lines modifying the roll - cover (:153-169), Impaired (:171-172), engagement
## (:173-174), the Prone accuracy bonus (:176-178), every ATTACK_ROLL buff (:182-190) - before calling
## `action.modify_pre_attack_data(context, preattack)` at attack_roll.gd:192, the LAST statement in
## create() before it returns. Writing target_defense there therefore overwrites whatever the
## attacked unit's Evasion, Stunned status or buffs had made of it. Vanilla's comment on that line
## names this exact use ("latch drone evasion 8").
##
## WHAT THIS IS NOT: AttackUtil.calculate_target_defense ends with a bare `return 8`
## (attack_util.gd:46) that looks like the same number and is NOT what this uses. That line is
## unreachable - the match above it covers both members of AttackRoll.ATTACK_TYPE, which has exactly
## two, WEAPON and TECH (attack_roll.gd:5). Recorded because a reader who deletes the override below
## and sees an 8 in a log could conclude the engine does this for free; it does not, and
## test_the_strike_rolls_against_8_whatever_the_evasion goes RED without the override.
##
## COVER AND PRONE, THE TWO DIVERGENCES FROM THE LATCH DRONE (design ruling 10). A fixed 8 makes the
## ally's defensive state irrelevant, so neither of the two engine mechanisms that would still move
## the roll may apply:
##
##   - COVER adds difficulty rather than defence, so modify_pre_attack_data does not cancel it:
##     attack_roll.gd:153-169 adds a cover mod when `not action.ignores_cover(context)`. NO OVERRIDE
##     IS WRITTEN FOR IT, and the reason is worth stating so nobody adds one as "defence in depth":
##     ActionAttackWeapon.ignores_cover already returns true for any MELEE weapon with threat > 0
##     (action_attack_weapon.gd:206-212), and this weapon is MELEE with threat 8. An explicit
##     `return true` here would be dead code that also hid the fact that the engine's own melee rule
##     is what covers it. test_cover_on_the_ally_adds_no_difficulty pins the behaviour; its mutation
##     is an override returning false.
##   - PRONE is an accuracy bonus for the ATTACKER (attack_roll.gd:176-178), and it is NOT covered by
##     any melee rule, so the override below is real and load-bearing. ActionAttack's default returns
##     true (action_attack.gd:45); the Sniper's anti-materiel rifle
##     (content/frames/npc/npcc_sniper/anti_materiel_rifle/action_anti_materiel_rifle_sniper.gd:6) is
##     vanilla's only precedent and this is the same one-liner.
##
## LINE OF SIGHT IS OFF, ON THE .tres, NOT HERE. The card's "This does not require line of sight or a
## clear path between you and the target" is one sentence covering the trigger AND the strike, so the
## .tres sets requires_line_of_sight_baseline = false; see its own comment for what that changes and
## what it was measured against.
##
## GRIT STILL ADDS, AND IMPAIRED STILL SUBTRACTS. Nothing here touches the attacker's side of the
## roll: the pilot's Grit is the weapon attack's flat bonus and a Myconid standing in something
## unpleasant still takes its -1 (attack_roll.gd:171-172). That is the card, which says "make a melee
## attack" and not "hit automatically".
##
## THE ACTIVATION GATE IS starts_hibernating, NOT AN is_available_to_activate OVERRIDE. See the .tres
## and action_uffish_gyre.gd's header for the whole account; in short, the engine's own hibernation
## flag already refuses this action everywhere the card needs it refused, including the Gyre's own
## AS_FREEBIE follow-up, so no code is needed here. There is deliberately no override below.
extends ActionAttackWeapon

## The card gives no damage at all, and this is how the Latch Drone spells "no damage" on an attack.
##
## MEASURED REDUNDANT AT HEAD, KEPT ANYWAY (mutation 14, 2026-09-16: replacing this body with
## `return super(...)` reddened NOTHING). With no damage_dice on the .tres, the base's
## `damage_data.get_for_attack_roll(attack_roll)` (action_attack.gd:77) has nothing to hand back, so
## the two agree today. It stays for two reasons: it is what vanilla's own no-damage attack does, and
## it is the line that keeps the card true if a damage number is ever added to the .tres for a
## variant or a mod-on-mod. That the TEST discriminates is measured separately - mutation 14b returns
## a real 3 kinetic from this function and test_no_damage_is_ever_dealt goes RED.
func get_damage_for_attack(context:Context, attacked_unit:Unit, damage_data:AttackUtil.DamageRollSummary, attack_data:AttackRoll) -> Dictionary:
	return {}

## A crit on an ally is meaningless here: there is no damage to double and the on-hit effect already
## fires on a plain hit (OnHitEffect.STAGE.ON_HIT). Vanilla's Latch Drone makes the same call, and
## without this a natural 20 would print a crit banner over a friendly unit for no mechanical reason.
func can_crit(context:Context) -> bool: return false

## "against evasion 8". Runs LAST in PreAttack.create (attack_roll.gd:192) - see the header.
func modify_pre_attack_data(context:Context, pre_attack_data:AttackRoll.PreAttack) -> void:
	pre_attack_data.target_defense = 8

## "the allied character". super() first, so the engine's own refusals still stand - it is super()
## that refuses SELF for a non-AoE action (action_attack_weapon.gd:228) and a hidden unit
## (:229), and that honours an ACTION_BANNED_UNITS buff (:238-239).
##
## THE SELF CLAUSE BELOW IS THEREFORE BELT-AND-BRACES ON 1.4.3 AND IS KEPT ANYWAY, for the reason
## action_uffish_gyre.gd's own `mover != unit` clause is kept: the two halves of this mechanic must
## agree about who may be struck, and a reader of either file should not have to hold
## action_attack_weapon.gd's non-AoE branch in their head to see that a Myconid never pikes itself.
## It costs one comparison.
func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not super.can_target_unit(potential_target, specific): return false
	if potential_target == specific.unit: return false
	if not potential_target.is_character(): return false
	return UnitRelation.are_allies(specific.unit, potential_target)

## A fixed 8 makes the ally's own defensive state irrelevant, and Prone is the one piece of that
## state the engine still folds into the roll - as +1 accuracy for the ATTACKER
## (attack_roll.gd:176-178), which no melee or cover rule cancels. See the header.
func is_accuracy_against_prone() -> bool: return false

## THE TWO-STAGE FLAG, and the reason this override exists at all.
##
## Action.FLAG.SKIP_PLAYER_DECISIONS gates two different things that the Gyre wants different
## answers to, and it gates them at two different MOMENTS of one activation:
##
##   action_attack.gd:235   get_attack_plan(...)    -> target_action_util.gd:150 -> :162, the screen
##   action_attack.gd:247   confirm_friendly_fire   -> target_action_util.gd:433
##   action_attack.gd:249   confirm_aoe_no_targets  -> target_action_util.gd:440
##   action_attack.gd:262   spend_actions           -> committed
##
## The Gyre wants the SCREEN (it is the player s only chance to decline a reaction that costs the
## round s use) and does not want the WARNING (it asks whether to attack an ally, on somebody else s
## turn, about an attack whose entire effect is to give that ally armor - SP2.5 Task 2, and still
## the ruling). So the flag is absent for the first read and present for the other two: the reaction
## stops passing it, and this override appends it the moment the screen has returned.
##
## activation.context IS the Context activate() was handed, on BOTH branches of
## event_gear_activate.gd - the plain branch passes core.context as the parameter (:80) and the
## composed branch assigns core.context = composed_context before passing it (:88-91) - and
## get_attack_plan reads it back as `var context := activation.context` (action_attack.gd:132). So
## appending here is appending to the same array action_attack.gd:247 is about to read.
## test_the_flag_is_absent_for_the_screen_and_present_for_the_confirm pins that.
##
## THE MUTATION DOES NOT LEAK, checked rather than assumed. context.flags is the child event s own
## array, built fresh by choose_and_use (common_action_util.gd:693-710); the follow-up attack builds
## a fresh followup_flags of its own and does not inherit it (action_attack_weapon.gd:69-74); and of
## every SKIP_PLAYER_DECISIONS reader in the tree, the only one besides the three above that reads a
## live context.flags is ms_lightning_generator/action_lightning_generator.gd:20, on its own action.
## common_action_util.gd:330 (confirm_use_alt) is reached from confirm_use,
## confirm_use_against_disambiguated_target and ActionReactionMovement, never from ActionAttack,
## which has no confirm_use call at all.
##
## THE GUARD IS NOT DECORATION. choose_and_use appends this flag itself for a non-player actor
## (common_action_util.gd:703), so on an NPC Myconid it is already present and the has() check is
## what keeps this a no-op there instead of a duplicate entry.
##
## AN ABORTED PLAN RETURNS UNTOUCHED, because action_attack.gd:236 is about to abort the whole
## activation on it and appending to a context nothing will read is noise.
func get_attack_plan(activation:EventCore, specific:SpecificAction) -> CompconPlan:
	var plan:CompconPlan = await super(activation, specific)
	if plan == null or plan.aborted: return plan
	if not activation.context.flags.has(Action.FLAG.SKIP_PLAYER_DECISIONS):
		activation.context.flags.append(Action.FLAG.SKIP_PLAYER_DECISIONS)
	return plan
