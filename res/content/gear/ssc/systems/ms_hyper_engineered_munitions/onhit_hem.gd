## HYPER ENGINEERED MUNITIONS' ON-HIT (SP4 Task 1, design ruling 14), delivered by
## buff_loaded_munitions. Two .tres of this one script:
##   onhit_hem_damage - `ap_damage = 1`: "the target takes 1 AP Kinetic damage" (the Shrike Armor's
##                      call, action_shrike_armor.gd:39-42). No save.
##   onhit_hem_impair - `statuses [impaired]`, `save_to_avoid`, `save_type HULL`: "must succeed on a
##                      Hull save or become Impaired until the end of their next turn" - Impaired's
##                      standard until is END_OF_NEXT_TURN, which OnHitEffect applies by default.
## TWO EFFECTS BECAUSE should_abort RUNS THE SAVE and a passed save skips the whole effect: one
## effect would let a passed Hull save cancel the AP point too.
##
## "WHENEVER YOU HIT A HOSTILE CHARACTER": both gate on the victim being an ACTOR (the mod-wide
## row 301 / ruling 16 - a drone is_character() but not is_actor()) and an enemy of the attacker.
## A hit on an object or an ally does nothing, and forces no save.
##
## THE AP POINT IS ITS OWN DAMAGE EVENT, dealt by the Thorn (generate_damage_events blames
## get_attacker), so it is "damage dealt" to Vigil and Rend - both dedupe per declared attack.
extends OnHitEffect

@export var ap_damage:int = 0

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if not Unit.is_valid(attacked_unit) or not Unit.is_valid(activation.context.unit): return true
	var attacker:Unit = activation.context.unit.get_attacker(activation.context)
	if not Unit.is_valid(attacker): return true
	if not attacked_unit.is_character(): return true
	if not UnitRelation.are_enemies(attacker, attacked_unit): return true
	return await super(stage, activation, attacked_unit)

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	if ap_damage <= 0 or not Unit.is_valid(attacked_unit): return
	CommonActionUtil.queue_damage_events(
		activation, SpecificAction.from_context(activation.context), [attacked_unit],
		ap_damage, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.AP]
	)
