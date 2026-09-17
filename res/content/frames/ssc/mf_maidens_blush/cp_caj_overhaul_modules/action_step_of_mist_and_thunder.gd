## STEP OF MIST AND THUNDER: the Maiden's Blush folds anywhere it can see the shape of.
##
##   "Roll 2d6. You teleport to a free space within a Range equal to what you rolled, without
##    requiring line of sight. Characters adjacent to the space you teleport to must make a Systems
##    save or treat you as Invisible until the end of the scene. If you roll two 1s you teleport to a
##    space of the GM's choice. This teleportation cannot be prevented. This ability is Efficient and
##    will refund 1 Core Point at the end of any scene in which this ability was used."
##
## "THIS TELEPORTATION CANNOT BE PREVENTED" IS THE EXPENSIVE CLAUSE, and what it costs was measured
## rather than reasoned (SP2 probe, 2026-09-17; the full four-way table is in teleport.gd's perform
## half header). Two things have to be true at once:
##
##   - the movement type must be INVOLUNTARY, because both Immobilized gates test
##     movement_type.voluntary - Pathfinder.create (pathfinder.gd:333) and
##     EventUnitMove.has_enough_move_to_reach_end (event_unit_move.gd:451, run at :156 and :288);
##   - the move must carry an explicit PATH, because undergo_move builds a pathfinder of its own when
##     it is handed a target tile (event_unit_move.gd:139-145) and Pathfinder.create is where every
##     MOVEMENT_RESTRICTION ban is read and intersected (:345-352), with no voluntariness check on
##     that read.
##
## Involuntariness alone beats Immobilized and loses to an Interdiction Field; the path alone beats
## the Field and loses to Immobilized. Teleport.move(activation, unit, tile) does both, and is tagged
## as the mech's OWN so Uncertainty Field can still offer the fade (ruling 4).
##
## THE ORDER OF activate() IS THE RULING. Reading down: a declined confirm costs nothing; a cancelled
## pick costs nothing; everything after spend_actions costs the quick action and the core point
## whatever happens next - a fade, a fizzle, a boxed-in snake eyes. That is deliberate and the author
## chose it (ruling 4): Step is NOT exempt from the frame's own trait, and Efficient softens the cost
## to a single scene.
extends ActionSystem

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const Efficient := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/efficient/efficient.gd')

const DISTANCE_DICE:String = '2d6'

## "A space of the GM's choice" on snake eyes (ruling 9): a random standable tile within this many
## spaces, no line of sight, no picker.
const SNAKE_EYES_RANGE:int = 2

## Blinkspace's gate, kept: a mech riding somebody else's stack-up cannot fold out of it
## (action_blinkspace_jump.gd:6). The GRAPPLED non-rider case is a different one and the probe
## measured it - an unpreventable Step does leave the grip, and the rulings record that.
func can_be_used_while_stackup_rider() -> bool: return false

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	var specific := SpecificAction.from_context(context)

	# 1. THE CONFIRM. Player-controlled only, the Blinkspace idiom
	# (action_blinkspace_jump.gd:12-19): CommonActionUtil's own confirm helpers return true without
	# asking for an AI unit anyway, but asking the bus directly keeps the prompt's wording ours.
	if unit.is_player_controlled():
		var confirmed:bool = await choice_bus.quick_yesno_for({
			tile = unit.tile(),
			title = name(specific),
			description = Translate.action(gear.kit, self, 'confirm'),
			whois = unit,
		})
		if not confirmed: return

	await run_system_fxgs(unit)
	if activation.abort_without_unit(unit): return

	# 2. THE ROLL.
	var dice:Dictionary = Dice.process_dice_string(DISTANCE_DICE)
	var rolls:Array[int] = Dice.roll_dice(dice)
	var total:int = Dice.sum_rolls(rolls, dice)
	effect_bus.play_d6(total, unit.tile())
	battle_log.log_tr('battle.generic_roll.log', {dice = DISTANCE_DICE, result = total})

	# READ THE INDIVIDUAL ROLLS, NOT THE TOTAL. With 2d6 only 1+1 sums to 2, so a total test would
	# happen to work - and would silently become wrong the first time a consumer changed the dice.
	# The card says "two 1s"; this says two 1s.
	var snake_eyes:bool = rolls.size() == 2 and rolls.all(func(roll:int) -> bool: return roll == 1)

	# 3. THE DESTINATION.
	var tile:Vector2i
	if snake_eyes:
		battle_log.log_unit(&'gear.cp_caj_overhaul_modules.action_step_of_mist_and_thunder.snake_eyes.log', unit)
		effect_bus.play_text(Translate.action(gear.kit, self, 'snake_eyes.pop'), unit.tile())
		tile = pick_random_tile(Teleport.candidate_tiles(unit, SNAKE_EYES_RANGE, false))
	else:
		var tiles := Teleport.candidate_tiles(unit, total, false)
		tile = await Teleport.pick_tile(context, activation, tiles)
		# A CANCELLED PICK SPENDS NOTHING, which is Blinkspace's behaviour and the reason the spend is
		# below this line rather than above the roll.
		if tile == Tile.INVALID: return
		if activation.abort_without_unit(unit): return

	# 4. THE SPEND, and the Efficient stamp with it. Everything past here is paid for.
	spend_actions(activation)
	Efficient.mark_used(gear)

	# A boxed-in snake eyes has nowhere to go and fizzles here: spent, stamped, unmoved (ruling 9).
	# It cannot happen on an ordinary roll, because an empty tile set makes pick_tile return INVALID
	# and the branch above already returned.
	if tile == Tile.INVALID:
		battle_log.log_unit(&'gear.cp_caj_overhaul_modules.action_step_of_mist_and_thunder.fizzle.log', unit)
		return

	# 5. THE TELEPORT. Own-involuntary and by path - see the header.
	var move:EventCore = await Teleport.move(activation, unit, tile)
	# UNCERTAINTY FIELD TOOK IT (ruling 4). The point and the action stay spent, the stamp stays set,
	# and NO adjacent character saves - the card's save is a consequence of arriving, and nobody
	# arrived.
	if move == null or move.aborted: return
	if activation.abort_without_unit(unit): return

	# 6. THE SAVES, measured from where we landed.
	#
	# ALLIES INCLUDED, as written (ruling 13). An ally's chip is inert except against ally-targeting
	# attacks such as the Myconid's Uffish Gyre, and the card says "characters", not "hostiles".
	#
	# get_characters_within(unit, 1, false) is the ENGINE'S OWN radius through distance_between, which
	# is the frame's Contested seams ruling: gavstarb-talents_1st_party's House Guard widens
	# `adjacent_characters` and never touches this, so its adjacency does not reach here.
	# spec/test_compat.gd pins that in both directions.
	for character:Unit in UnitRelation.get_characters_within(unit, 1, false):
		if not Unit.is_valid(character): continue
		var passed:bool = await UnitHasecheck.make_systems_save(activation, character, specific)
		if passed: continue
		UnitCondition.apply_buff(
			activation, character,
			ContentLibrary.get_buff(&'buff_mist_and_thunder_invisible'),
			gear
		)

## One of the given tiles, drawn THROUGH Dice so a spec can fix it (ruling 9). Tile.INVALID when the
## mech is boxed in.
##
## Dice.roll_dice rather than Array.pick_random for exactly that reason: pick_random uses Godot's own
## RNG, which CHEAT_ROLL_QUEUE cannot reach, and a random destination no spec can pin is a test that
## asserts "it went somewhere".
func pick_random_tile(tiles:Array[Vector2i]) -> Vector2i:
	if tiles.is_empty(): return Tile.INVALID
	var dice:Dictionary = Dice.process_dice_string('1d%d' % tiles.size())
	var roll:int = Dice.sum_rolls(Dice.roll_dice(dice), dice)
	return tiles[clampi(roll - 1, 0, tiles.size() - 1)]
