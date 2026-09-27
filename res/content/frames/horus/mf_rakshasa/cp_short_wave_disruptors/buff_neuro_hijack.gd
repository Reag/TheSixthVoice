## NEURO-HIJACK, the listener (design 4, rulings 26-31):
##
##   "For the rest of the scene, whenever a hostile character within Sensors targets you with an attack
##    and has another valid character to target, they must first pass a Systems save. On a failure,
##    they cannot attack you and must choose a different target for that attack at +1 Difficulty. If a
##    character succeeds their save they are unaffected by this ability for the rest of the turn."
##
## A VISIBLE chip on the Rakshasa, until MANUAL (the scene - Gather Round's shape), hung by the protocol
## action_neuro_hijack. It listens at the PER-TARGET event_unit_attack ATTACK PRE through the reaction
## bus, which polls every buff on every unit (reaction_bus.gd:57-63) - so the holder test in should_ask
## is load-bearing, not a rare-case guard. No reaction point, no 1/round.
##
## THE SEAM IS SPIKE 3'S PER-ROLL SWAP (memory lancer-tactics-attack-redirection-seam), NOT Draw Fire's
## summary recentre. EventBlock.execute runs every per-target event's preblock (= these PRE reactions)
## before any execute (event_block.gd:92-107), and event_unit_attack.execute reads context.target_unit
## only afterwards (:39) and builds the roll from it (:53). So writing target_unit here moves evasion,
## cover, damage and on-hit in one line; the summary's entry is replaced IN PLACE for its later readers.
## Range and line of sight are never re-checked against the new target - which is why the candidates
## below are taken from the attacker's OWN targetable set. Ruling 31: the shared redirect helper is NOT
## extracted here; this is the per-roll seam, not the recentre the helper would serve.
##
## AN AREA ATTACK (the action has a range pattern) is ruling 29's other branch: the Rakshasa's own
## per-target event is ABORTED - EventBlock skips an aborted event's execute (:105) - and the other
## caught characters resolve normally. Their preblocks may already have run; their EXECUTES have not, so
## the +1 Difficulty applied here still reaches every one of their rolls.
##
## +1 DIFFICULTY is buff_neuro_hijack_difficulty on the attacker: an ATTACK_ROLL BuffBonus of -1 scoped
## to this declared attack's summary id. Not FINISH_ATTACK_ROLL: an earlier roll of the same AoE would
## wipe it before the later ones (event_unit_attack.gd:118-120).
extends Buff

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_rakshasa/cp_short_wave_disruptors/short_wave_disruptors.gd')

const HIJACK_ACTION := &'action_neuro_hijack'
const EXEMPT_BUFF := &'buff_neuro_hijack_exempt'
const DIFFICULTY_BUFF := &'buff_neuro_hijack_difficulty'
## The key buff_neuro_hijack_difficulty reads to scope itself to one declared attack.
const SUMMARY_KEY := 'summary_id'
## "Asks once per Rakshasa per declared attack" (ruling 27): a Silver-Tongue-style reroll against a new
## target builds a SECOND event_unit_attack on the same summary (event_unit_attack.gd:327-336), and
## ATTACK PRE fires again for it. The stamp records the save's OUTCOME, because the two outcomes want
## opposite things of a roll that comes back onto the Rakshasa:
##   PASSED - leave it alone. The exemption already stops a second ask; the stamp only agrees.
##   FAILED - "they cannot attack you" still holds for the whole attack, so the roll is moved off again
##     (must_move_again), WITHOUT a second save and without a second +1 Difficulty - the summary-scoped
##     one already covers every roll of this attack. A reroll's candidates exclude only its current
##     target and the attacker (buff_weapon_type_reroll_miss.gd:62-63; an area reroll reuses
##     all_attacked_units, which still names the Rakshasa), so this case is reachable.
##   ASKED - written before the save is rolled and left only if the save never resolved; treated like
##     PASSED, the pre-outcome behaviour.
const STAMP_PREFIX := 'reag_neuro_hijack_asked_'
const ASKED := &'asked'
const PASSED := &'passed'
const FAILED := &'failed'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.target_units, Context.PROP.action, Context.PROP.resource]

func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	return should_ask(unit, triggering_event.context) or must_move_again(unit, triggering_event.context)

func activate(core:BuffCore, activation:EventCore) -> void:
	var triggering:EventCore = activation.context.event
	var context:Context = triggering.context
	var map:MapState = activation.context.map
	var rakshasa:Unit = core.get_holder_unit(map)
	# RE-ASKED, not trusted from the poll: the bus collects every PRE reaction before running any
	# (reaction_bus.gd:46-64), so another one - a Subutai's Draw Fire, a second Rakshasa - may already
	# have moved this roll off us.
	var again := must_move_again(rakshasa, context)
	if not again and not should_ask(rakshasa, context): return
	var specific := SpecificAction.from_context(context)
	var summary:DeclaredAttackSummary = context.resource
	var area := is_area(specific, summary)
	var candidates := alternatives(rakshasa, context)
	var attacker:Unit = context.unit.get_attacker(context)
	var forcing:SpecificAction = core.get_owner_specific(map, HIJACK_ACTION)
	if not SpecificAction.is_valid(forcing): return
	if again:
		# This attack already failed its save (ruling 27's stamp): moved off again, never re-asked.
		effect_bus.play_text(core.name_text(), rakshasa.tile())
		await move_off(triggering, rakshasa, specific, summary, attacker, candidates, forcing, area)
		return
	summary.set_meta(stamp_key(rakshasa), ASKED)

	# The full trifecta (Rakshasa, core gear, protocol), so Worm Code sees a failure (ruling 29).
	var saved:bool = await UnitHasecheck.make_systems_save(activation, attacker, forcing)
	summary.set_meta(stamp_key(rakshasa), PASSED if saved else FAILED)
	if not Unit.is_valid(attacker) or not Unit.is_valid(rakshasa): return
	if saved:
		# Keyed by from_gear, so two Rakshasas stay independent (ruling 30).
		UnitCondition.apply_buff_id(activation, attacker, EXEMPT_BUFF, forcing.gear)
		return

	# Recorded, not fought (ruling 31): the tracer and muzzle FX already played at the Rakshasa
	# (action_attack.gd:265), so a pop names what happened.
	effect_bus.play_text(core.name_text(), rakshasa.tile())
	apply_difficulty(activation, attacker, forcing.gear, summary)
	await move_off(triggering, rakshasa, specific, summary, attacker, candidates, forcing, area)

## "They cannot attack you and must choose a different target for that attack." An area attack's
## per-target event is aborted (ruling 29); a single-target roll moves to a pick from `candidates`, and
## is aborted when nobody is left to attack instead.
static func move_off(triggering:EventCore, rakshasa:Unit, specific:SpecificAction, summary:DeclaredAttackSummary,
		attacker:Unit, candidates:Array[Unit], forcing:SpecificAction, area:bool) -> void:
	if area:
		triggering.set_aborted()
		return
	var new_target:Unit = await pick(specific, attacker, candidates, forcing)
	if not Unit.is_valid(new_target): new_target = candidates.front() if not candidates.is_empty() else null
	if not Unit.is_valid(new_target):
		triggering.set_aborted() # "they cannot attack you", and nobody is left to attack instead
		return
	triggering.context.target_unit = new_target
	var index := summary.all_attacked_units.find(rakshasa)
	if index >= 0: summary.all_attacked_units[index] = new_target

## Every gate of rulings 27 and 28, asked of one per-target attack context.
static func should_ask(rakshasa:Unit, context:Context) -> bool:
	if not is_hijackable(rakshasa, context): return false
	if context.resource.has_meta(stamp_key(rakshasa)): return false
	if is_immune(context): return false
	return not alternatives(rakshasa, context).is_empty()

## A roll of an attack whose save against this Rakshasa already FAILED, back on the Rakshasa (ruling
## 27's stamp): moved off without asking. No "another valid character" gate - with nobody left, the
## roll is aborted instead of let through.
static func must_move_again(rakshasa:Unit, context:Context) -> bool:
	if not is_hijackable(rakshasa, context): return false
	if context.resource.get_meta(stamp_key(rakshasa), &'') != FAILED: return false
	return not is_immune(context)

## The gates both questions share: a hostile character within Sensors, not exempt, attacking the Rakshasa.
static func is_hijackable(rakshasa:Unit, context:Context) -> bool:
	if not Unit.is_valid(rakshasa) or context == null: return false
	if not DeclaredAttackSummary.is_valid(context.resource): return false
	if context.target_unit != rakshasa: return false
	if not Unit.is_valid(context.unit) or not Action.is_valid(context.action): return false
	var attacker:Unit = context.unit.get_attacker(context)
	# "A hostile character": is_character(), a drone included (ruling 2026-09-27).
	if not Unit.is_valid(attacker) or attacker == rakshasa or not attacker.is_character(): return false
	if not UnitRelation.are_enemies(rakshasa, attacker): return false
	# "Within Sensors": the Rakshasa's live Sensors, measured the way Draw Fire measures it.
	if UnitRelation.distance_between(rakshasa, attacker) > rakshasa.get_sensor_range(): return false
	var gear:GearCore = rakshasa.get_gear(Core.CORE_ID)
	if not GearCore.is_valid(gear): return false
	return not UnitCondition.has_buff(attacker, EXEMPT_BUFF, gear.persistent_id)

## "Has another valid character to target" (ruling 28).
##   SINGLE-TARGET: every character on the attacker's own targetable set that passes its
##     can_target_unit - the reticle's computation, which the player's picker and the AI both use -
##     minus the Rakshasa, the attacker, and anybody this declared attack already targets (a second
##     roll against a unit already being attacked is not "a different target"). The attacker's own
##     allies are included (RAW, the author's fork). Walked in map order, so the list is deterministic.
##   AREA: every other character the attack already caught.
static func alternatives(rakshasa:Unit, context:Context) -> Array[Unit]:
	var candidates:Array[Unit] = []
	var specific := SpecificAction.from_context(context)
	if not SpecificAction.is_valid(specific): return candidates
	var summary:DeclaredAttackSummary = context.resource
	var attacker:Unit = context.unit.get_attacker(context)
	var excluded:Array[Unit] = [rakshasa, attacker, context.unit]
	if is_area(specific, summary):
		for caught:Unit in summary.all_attacked_units:
			if excluded.has(caught) or not Unit.is_valid(caught) or not caught.is_character(): continue
			Util.append_nonduplicate(candidates, caught)
		return candidates
	var tiles:Array[Vector2i] = UnitTargeting.get_tiles_targetable(specific)
	for other:Unit in rakshasa.map.get_all_characters():
		if excluded.has(other) or not Unit.is_valid(other) or not other.is_character(): continue
		if summary.all_attacked_units.has(other): continue
		if not other.occupied_tiles().any(func(tile:Vector2i) -> bool: return tiles.has(tile)): continue
		if not specific.action.can_target_unit(other, specific): continue
		candidates.append(other)
	return candidates

## A range pattern means an area attack; none means single-target - the same test
## buff_grey_birds_recentre.gd makes (action.gd:204-206 returns reqs.range_pattern, null when unset).
static func is_area(specific:SpecificAction, summary:DeclaredAttackSummary) -> bool:
	return specific.action.get_range_pattern_for_targets(
		specific, specific.unit.tile(), summary.directly_attacked_tiles) != null

## The Sniper AMR's immunity (ruling 27) reads the ROLL - its cover - through context.object
## (action_anti_materiel_rifle_sniper.gd:7-10), and at ATTACK PRE there is no roll yet: event_unit_attack
## builds it at :53. So the question is asked of a PROVISIONAL roll built the engine's own way, which
## only reads buffs and geometry. Without it the immunity always answers false here.
static func is_immune(context:Context) -> bool:
	var action := context.action as ActionAttack
	if action == null: return false
	var probe := Context.clone(context, {
		object = AttackRoll.create(context.target_unit, AttackRoll.PreAttack.create(context)),
	})
	return action.is_immune_to_automisses_and_redirects(probe)

## Ruling 29: a player-controlled attacker is asked, mandatorily, with vanilla's own retarget prompt
## (the reroll-against-a-new-target picker, event_unit_attack.gd:321). An AI attacker takes the top of
## its own target score (AiActionDecider.get_unit_score_dictionary, the ranking
## TargetActionUtil.disambiguate_target_units' AI branch sorts by); a tie keeps the earlier candidate.
static func pick(specific:SpecificAction, attacker:Unit, candidates:Array[Unit], forcing:SpecificAction) -> Unit:
	if candidates.is_empty(): return null
	if candidates.size() == 1: return candidates.front()
	if attacker.is_player_controlled():
		var chosen:Unit = await choice_bus.choose_unit(candidates, false, specific, forcing)
		return chosen if candidates.has(chosen) else null
	var behavior:AiBehavior = specific.action.get_ai_behavior(specific)
	if behavior == null: return candidates.front()
	var scores := AiActionDecider.get_unit_score_dictionary(behavior, specific, 10.0)
	var best:Unit = candidates.front()
	for candidate:Unit in candidates:
		if scores.get(candidate.core.persistent_id, 0.0) > scores.get(best.core.persistent_id, 0.0):
			best = candidate
	return best

static func apply_difficulty(activation:EventCore, attacker:Unit, gear:GearCore, summary:DeclaredAttackSummary) -> void:
	var difficulty := BuffCore.create(ContentLibrary.get_buff(DIFFICULTY_BUFF), gear.persistent_id)
	difficulty.set_state(SUMMARY_KEY, String(summary.id))
	UnitCondition.apply_buff_alt(activation, attacker, difficulty)

static func stamp_key(rakshasa:Unit) -> StringName:
	return StringName(STAMP_PREFIX + String(rakshasa.core.persistent_id))
