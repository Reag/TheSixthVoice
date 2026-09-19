## BITING RETORT: the Acrasial Falcata answers a swing before it lands.
##
##   "Biting Retort (Reaction, 1/round)
##    Trigger: A hostile character within line of sight attempts to hit you with a melee attack.
##    Effect:  The attack is made with +1 Difficulty. If the attack misses, the attacker takes 3 AP
##             Kinetic damage and must succeed a Hull save or be knocked prone."
##
## THIS FILE IS THE FIRST SENTENCE AND THE TRIGGER. The riposte - the second sentence - cannot be
## decided here, and that is an engine fact rather than a style choice; see "the split" below.
##
## ============================ WHY THIS IS AN ATTACK **PRE** REACTION ============================
##
## The +1 Difficulty has to be on the defender BEFORE the roll is built. event_unit_attack.gd awaits
## the PRE reactions in execute_preblock (:31-32) and only calls AttackRoll.create at :53, and
## AttackRoll.PreAttack.create folds every ATTACK_ROLL_INCOMING accuracy buff it finds into a named
## AccuracyMod (attack_roll.gd:181-189). So a buff applied inside a PRE reaction is read by the roll,
## and a buff applied at POST is read by nothing.
##
## This is content/frames/ha/mf_saladin/mt_warp_shield/action_warp_shield.gd byte for byte, plus one
## override. Its buff_warp_shield.tres and ours are the same five properties.
##
## THE SPLIT. The riposte needs the roll's outcome, which does not exist until after the PRE reaction
## has returned - so it is a separate observer applied from this same activate(), and design 3.1's
## chosen mechanism for it does not work. SP3 Task 0's probe measured that a buff with
## until = FINISH_ATTACK_ROLL and trigger_timing = POST fires ZERO times, because
## event_unit_attack.gd:120 clears every FINISH_ATTACK_ROLL buff off the unit and :123 queues the POST
## reactions on the very next line - so the observer is gone before anything asks it. Ruling 25 is the
## replacement - a hidden, self-clearing END_OF_THIS_TURN observer - and it is applied beside the
## difficulty buff at the bottom of this file. buff_biting_retort_riposte.gd is where it lives and
## where the reasoning for every one of its properties is recorded.
##
## ============================ THE 1/ROUND IS THE ENGINE'S ============================
##
## THERE IS DELIBERATELY NO get_per_round_hard_limit OVERRIDE HERE. ActionReaction returns
## `1 if requires_reaction_available() else 99` (action_reaction.gd:69), and requires_reaction_available
## follows `consumes_rxn`, which this .tres leaves at its default TRUE. So the card's 1/round is
## already the engine's answer, and an override would be an inert line that reads as load-bearing.
## (The Maiden's Blush's mt_uncertainty_field DOES override it, and correctly: that reaction consumes
## no reaction point, so its limit would otherwise be 99. Same archetype family, opposite answer,
## because of one property.)
##
## THE usage_group IS NOT DECORATION. GearCore keys its per-round counter by Action.usage_group and
## falls back to the KIT's compcon_id when an action declares none (gear_core.gd:166-168). This Kit's
## other action - the Falcata's own attack profile - declares none, so without the explicit group the
## two would share one counter and a single swing of the weapon would push
## UnitAction.is_under_per_round_limit (unit_action.gd:170-171) past this reaction's cap of 1. The
## reaction would then be silently unoffered for the rest of any round the Primrose attacked in, which
## is most of them. spec/test_biting_retort.gd's
## test_swinging_the_falcata_does_not_spend_the_reactions_round is the pin. (mw_rend_axe's
## action_rend_axe_free.tres names its own group for the same reason, and is where the shape is from.)
##
## ============================ THE OFFER, AND WHAT DECLINING COSTS ============================
##
## There is no engine-level reaction prompt: ReactionBus queues the activation and asks nobody
## (reaction_bus.gd:52-58). The CommonActionUtil.confirm_use call below IS the offer, and returning
## BEFORE spend_actions is the whole of what "declining is free" means - the reaction point is still
## in hand for a later swing in the same round.
##
## ============================ RULING 8, AND WHY IT READS THE RAW `threat` ============================
##
## "Melee attack" means a melee weapon used AT THREAT, never its thrown variant - the same reading
## Shimmering Shield and Magnetic Weight Redistribution are held to. A throw is the SAME action with
## `threat` forced to 0 (action_attack_weapon.gd:349-372), so weapon_types = [MELEE] on the .tres
## cannot tell the two apart and this override has to.
##
## IT READS `action.threat`, NOT threat_distance(specific), AND THAT IS A MEASURED CHOICE.
## SpecificAction.from_context(the triggering context) IS valid here - event_unit_attack.gd's
## get_required_context (:10-21) demands unit, gear and action, and
## spec/test_biting_retort.gd's test_both_threat_readings_are_available_at_pre_and_they_disagree_about_
## a_throw measures it from inside the poll itself - so threat_distance() was available and was not
## chosen. It was rejected because it folds in the ATTACKER's own THREAT_RANGE buffs
## (action_attack_weapon.gd:187-190): Artful Caress widens a thrown Heavy melee weapon exactly as it
## widens a swung one, so threat_distance() answers 1 for a weapon whose printed threat is 0, and a
## gate written on it would offer this reaction against a throw. The raw field is also what the engine
## itself uses to recognise a throw, in both places it needs to: get_target_range (:197-201) and
## ignores_cover (:206-212).
extends ActionReactionAttacked

## The chip that carries the +1 Difficulty. Its own file, because apply_buff_id resolves through
## ContentLibrary and because a Buff in a `buff_*.tres` is the only kind this mod's content-integrity
## guards can see.
##
## IT IS HIDDEN, WHERE THE WARP SHIELD'S TWIN IS VISIBLE, and that divergence is deliberate. The buff
## exists only between this activation and event_unit_attack.gd:114's consume_buffs - a fraction of
## one event - so a status chip for it is a flicker on the token, not information. What the player
## actually reads is the roll's own breakdown line, and attack_roll.gd:189 draws THAT from
## `buff_core.base.icon` and `buff_core.name_text()` whether or not the buff is hidden. This mod's own
## buff_shimmering_shield_cover is the same shape for the same reason, down to the
## localization_key_override, and it is listed in test_content_integrity.gd's
## HIDDEN_BUFFS_NEEDING_ICONS - as this one is - precisely because a hidden buff that the roll still
## draws still needs a real icon.
##
## THE OVERRIDE POINTS AT THIS ACTION'S OWN ROWS: `mw_acrasial_falcata.action_biting_retort`, so the
## breakdown line reads "Biting Retort" and no new string is invented. Translate.buff honours a dotted
## override verbatim (translate.gd:49-52 -> Translate.key(['gear', <override>, property])), which is
## the same "kit and action in it" form Translate.action documents at :22-24. Without it the chip
## would fall through the owner gear to gear.mw_acrasial_falcata.name and the line would read
## "Acrasial Falcata", naming the weapon rather than the reaction that was just accepted.
const DIFFICULTY_BUFF:StringName = &'buff_biting_retort_difficulty'

## THE RIPOSTE, armed here and decided at ATTACK POST. SP3 Task 3 built it as ruling 25 specifies:
## a hidden, self-clearing buff with until = END_OF_THIS_TURN, NOT the design's FINISH_ATTACK_ROLL,
## which Task 0's probe measured firing zero times. buff_biting_retort_riposte.gd carries the whole
## argument and every citation; the short version is event_unit_attack.gd:120 clearing one line before
## :123 queues.
##
## APPLIED TO THE DEFENDER - us - not to the attacker, because it is OUR observer: it watches the roll
## that is about to be made against us and then hits back. The attacker never carries anything.
##
## THROUGH apply_buff_id AND NOT apply_buff, so `from_gear` is stamped with this activation's own gear
## (action.gd:375-376). The riposte needs that: core.get_owner_gear(map) is where it gets the Falcata
## back, which is both the save's forcing gear and the Prone's source id.
const RIPOSTE_BUFF:StringName = &'buff_biting_retort_riposte'

## OVERRIDE BUT CALL SUPER. The archetype does every other gate declaratively from the .tres -
## require_unit_to_be, require_attacker_relation, require_attacker_to_be_in_los, weapon_types,
## allow_basic - and refuses anything that is not an ActionAttackWeapon or ActionAttackTech outright
## (action_reaction_attacked.gd:112-128). The `is ActionAttackWeapon` line below is therefore already
## true by the time it runs; it is kept because the next line dereferences `.threat`, and a typed read
## that depends on a gate two files away is exactly the kind of thing that fails silently later.
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var action:Action = triggering_event.context.action
	if action is not ActionAttackWeapon: return false
	return action.threat > 0 # ruling 8: a throw is threat 0 and is not a melee attack

func activate(context:Context, activation:EventCore) -> void:
	var triggering_context:Context = context.event.context
	var defender:Unit = triggering_context.target_unit
	var declared_attack_summary:DeclaredAttackSummary = triggering_context.resource

	# THE OFFER. Showing the incoming attack's own tiles and its SpecificAction as the secondary is
	# what puts "what is about to hit you" on the confirmation screen, and is the Warp Shield's call
	# unchanged.
	var confirmed := await CommonActionUtil.confirm_use(
		context,
		[defender],
		declared_attack_summary.all_attacked_tiles,
		SpecificAction.from_context(triggering_context)
	)
	if activation.abort_when(not confirmed): return
	spend_actions(activation)

	apply_buff_id(activation, defender, DIFFICULTY_BUFF)
	apply_buff_id(activation, defender, RIPOSTE_BUFF)
