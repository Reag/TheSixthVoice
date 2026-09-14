## The Fitzgerald's integrated Bizarre Cannon, base profile.
##
## "On attack: You take 2 AP Kinetic damage and are knocked back 2 spaces, away from the direction
## of fire." Both halves fire whether the shot hits or misses, which is why this hangs off
## activate() and not an OnHitEffect.
##
## The recoil magnitudes are @export PROPERTIES, not consts, on purpose. GDScript resolves a
## `const` against the script the *reference* is written in, not the runtime type - so if
## activate() below read consts, a subclass redeclaring them would change nothing about what this
## activate() actually uses, and there would be no way for a second profile (MORE BLACK POWDER:
## 3 AP self-damage, 3-space knockback, any direction) to differ without either doubling the recoil
## (calling super.activate() re-runs THIS activate(), firing the base recoil before its own) or
## skipping the attack entirely (not calling super at all). Exporting them as resource data means
## activate() never needs overriding for a new profile: a subclass's .tres sets its own values and
## only recoil_origin_tiles() needs a method override.
extends ActionAttackWeapon

@export var recoil_damage_dice:String = '2'
@export var recoil_knockback:int = 2

func activate(context:Context, activation:EventCore) -> void:
	await super.activate(context, activation) # make the attack
	# An aborted activation is a shot that was never fired: ActionAttack.activate bails before
	# spend_actions when the targeting is cancelled, so there is no cost and there must be no
	# recoil either. Vanilla guards its own followup attacks the same way
	# (action_attack_weapon.gd:61, the `(not activation.aborted) and` line).
	if activation.aborted: return
	if not Unit.is_valid(context.unit) or not GearCore.is_valid(context.gear): return
	recoil(context, activation, recoil_damage_dice, recoil_knockback, recoil_origin_tiles(context))

## The tiles the knockback is measured AWAY from. CommonActionUtil.generate_knockback_events
## computes its cone away from origin_tiles, so handing it the far end of the line we just fired
## pushes us back along the barrel. Overridden by More Black Powder, which is knocked back in any
## direction and therefore passes its own tiles.
##
## READ OFF THE DECLARED ATTACK FIRST, NOT context.target_tile. context.target_tiles is only an
## incoming targeting HINT (event_gear_activate.gd:22-23): a spec or the AI may supply it, but when
## a player aims the shot the tiles are picked inside ActionAttack.get_attack_plan and land in
## plan.target_tiles, never back on the context - so in real play context.target_tile is
## Tile.INVALID. What IS always set by the time super.activate() returns is context.resource, the
## DeclaredAttackSummary (action_attack.gd:251-259), whose all_attacked_tiles hold the whole fired
## line. Taking the tile furthest from the firer is how vanilla itself finds the far end of a line
## (action_attack.gd:212). The two context lookups below are kept as a fallback for a caller that
## supplied a target and somehow produced no summary.
func recoil_origin_tiles(context:Context) -> Array[Vector2i]:
	var far:Vector2i = Tile.INVALID

	if DeclaredAttackSummary.is_valid(context.resource) and Unit.is_valid(context.unit):
		var declared:DeclaredAttackSummary = context.resource
		var fired_tiles:Array[Vector2i] = declared.all_attacked_tiles
		if fired_tiles.is_empty(): fired_tiles = declared.directly_attacked_tiles
		if not fired_tiles.is_empty():
			far = Tile.get_furthest_pair_between(context.unit.occupied_tiles(), fired_tiles).to

	if far == Tile.INVALID: far = context.target_tile
	if far == Tile.INVALID and Unit.is_valid(context.target_unit): far = context.target_unit.tile()
	if far == Tile.INVALID: return []
	return [far] as Array[Vector2i]

## Shared by both profiles: queues the self-damage, then the shove.
##
## SOURCE order here is self-damage then shove, but that is not RESOLUTION order. The self-damage
## is queued at Priority.ATTACK.self_damage (= 6, priority.gd:36); queue_events for the shove takes
## the default block_priority = 0 (event_core.gd:91) - and a LOWER priority number resolves first
## ("Lower is sooner, higher is later (-1 runs before 1)", action_reaction.gd:70), so 0 beats 6 and
## the KNOCKBACK actually happens before the wound lands, not after. This matches vanilla:
## action_attack_weapon.gd:337 queues its own KNOCKBACK-tag shove at the same default priority, so
## the ordering here is idiomatic, not a bug - do not "fix" it by re-priming the shove.
##
## ASSUMPTION: this wounds and shoves context.unit, the SAME unit recoil_origin_tiles() measured
## the fired line from. ActionAttack.activate can relay an attack through another unit
## (action_attack.gd:234, specific.unit = get_attacker_relay(...)), which would leave the fired
## tiles measured from the relay while the recoil origin and this wound are computed against
## context.unit. No relay exists for an integrated trait weapon today, and wounding the frame that
## fired is the intended reading of the rules, so this is left as-is - but a future relay buff on
## this weapon needs to reconcile which unit each half applies to before it silently draws the line
## from one unit and computes the shove against another's position.
##
## An EMPTY origin_tiles is not passed through. generate_knockback_events defaults an empty array to
## the acting unit's own tiles (common_action_util.gd:130), which opens a cone in EVERY direction -
## so "we could not work out which way we fired" would silently become "shoved somewhere at random"
## rather than failing. More Black Powder wants that all-directions cone and asks for it explicitly,
## by passing its own tiles.
static func recoil(
	context:Context, activation:EventCore, damage_dice:String, knockback:int, origin_tiles:Array[Vector2i]
) -> void:
	var unit:Unit = context.unit
	activation.queue_event(&'event_unit_damage', {
		unit = unit,
		number = Action.roll_damage(damage_dice, unit),
		category = Lancer.DAMAGE_TYPE.KINETIC,
		target_unit = unit, # let the damage event know WHO has done this
		flags = [EventService.DAMAGE_FLAG.AP, EventService.DAMAGE_FLAG.SELF_INFLICTED],
	}, Priority.ATTACK.self_damage)

	if origin_tiles.is_empty(): return
	var specific := SpecificAction.create(unit, context.gear, context.action)
	activation.queue_events(CommonActionUtil.generate_knockback_events(unit, knockback, specific, origin_tiles))
