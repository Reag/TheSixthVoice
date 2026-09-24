# HAZARD SP3 PROBE (design §3.0, amended by SP1): the Statistical Compensator's "+2 Reliable" is
# paid by the shared reliable_topup.gd at ATTACK_DECLARED POST, so whatever carries the +2 must
# still be readable THERE - not merely where the engine reads `reliable` (:82).
#
# PROBE A - the ruled carrier. A WEAPON_TAG buff with until = FINISH_DAMAGE, hung on the attacker at
# ATTACK_DECLARED PRE, is still on the attacker at ATTACK_DECLARED POST. Code read says NO:
# event_unit_attack_declared.gd:203-205 clears the OWNER's FINISH_DAMAGE buffs at the end of
# execute(), which runs before the POST reactions. Measured here rather than believed.
#
# PROBE B - the fallback's carrier. Meta set at PRE on the event's DeclaredAttackSummary
# (context.resource, created in action_attack.gd BEFORE the event, get_required_context :12) is the
# same object at POST, and the next attack gets a fresh summary without it.
#
# PROBE C - a reaction on a WEAPON-MOD Kit is reached at ATTACK_DECLARED PRE, and the firing
# weapon's get_weapon_mod is that Kit's gear. Mod gear lives in loadout.systems
# (loadout_core.gd:360), which get_all_gear walks - no vanilla weapon mod carries an action, so
# this is measured, not assumed.
#
# MUTATION. STAMP_AT_PRE := false - probe B's POST read must go red. MOD_ATTACHED := false - probe
# C's "is the mod" assertion must go red.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/x.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_hazard_sp3_seams.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## MUTATION KNOBS. The claims under test as written.
const STAMP_AT_PRE := true
const MOD_ATTACHED := true

const RIFLE := &'mw_assault_rifle' # MAIN, RELIABLE 2, 1d6, aim_range 10
const STAMP := &'reag_spike_sp3_stamp'
const PROBE_BUFF := &'buff_spike_hazard_sp3_finish_damage'


class ProbeBuff extends BuffWeaponTypeTag:
	func _init() -> void:
		compcon_id = PROBE_BUFF
		to = Buff.TO.WEAPON_TAG
		added_tag = Lancer.WEAPON_TAG.RELIABLE
		added_tag_value = 2
		until = Lancer.UNTIL.FINISH_DAMAGE
		hide_from_player = true


## Records what it sees at one timing of ATTACK_DECLARED, on its holder's own attacks.
class Watcher extends ActionReaction:
	var seen:Array[Dictionary] = []
	var mod_gear:GearCore
	var hang_buff:bool = false
	var stamp:bool = false

	func _init(timing:ReactionBus.TIMING) -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = timing
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.gear, Context.PROP.resource]

	func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		return triggering_event.context.unit == unit

	func activate(context:Context, activation:EventCore) -> void:
		var declared:Context = context.event.context
		var unit:Unit = declared.unit
		var summary = declared.resource
		seen.append({
			summary = summary,
			has_stamp = summary.has_meta(STAMP),
			has_buff = UnitCondition.has_buff(unit, PROBE_BUFF),
			weapon_mod = declared.gear.get_weapon_mod(unit.core.loadout),
		})
		if stamp and STAMP_AT_PRE: summary.set_meta(STAMP, true)
		if hang_buff: UnitCondition.apply_buff(activation, unit, ProbeBuff.new())


var game:Gamemaster
var shooter:Unit
var target:Unit


func before_each() -> void:
	game = Fixture.create_game(self)
	shooter = SpecFactory.create_unit(game.map, Vector2i(4, 4), Faction.PLAYER)
	shooter.core.equip_system(RIFLE)
	shooter.core.full_repair()
	target = Fixture.create_dummy(game, Vector2i(7, 4), 10, Faction.AI_ENEMY)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


## Fit a knockoff mod Kit carrying both watchers, the way equip_weapon_mod does it (:355-361).
func fit_mod(pre:Watcher, post:Watcher) -> GearCore:
	var kit := Kit.new()
	kit.compcon_id = &'wm_spike_hazard_sp3'
	kit.actions.append_array([pre, post] as Array[Action])
	var mod_passive := PassiveWeaponMod.new()
	kit.passives.append(mod_passive)
	shooter.core.loadout.equipped_kits.append(kit)
	var mod_gear := GearCore.create(kit)
	shooter.core.loadout.systems.append(mod_gear)
	if MOD_ATTACHED: shooter.get_gear(RIFLE).add_mod(mod_gear)
	# the bus reads loadout.reactions_by_trigger and get_weapon_mod reads persistent_id_to_gear -
	# both caches, rebuilt here as a real loadout regeneration would
	shooter.core.loadout.regenerate_caches()
	pre.mod_gear = mod_gear
	post.mod_gear = mod_gear
	return mod_gear

func shoot_miss() -> void:
	if shooter.state.is_taking_turn: await SpecFactory.end_turn(game, shooter)
	await SpecFactory.start_turn(game, shooter)
	# every die a 1: the d20 misses evasion 10, so only RELIABLE lands
	Dice.CHEAT_ROLL_QUEUE.assign(range(40).map(func(_i): return 1))
	await SpecFactory.use_solo(game, shooter, RIFLE, target)


func test_a_reaction_on_a_weapon_mod_kit_is_reached_and_names_the_mod():
	var pre := Watcher.new(ReactionBus.TIMING.PRE)
	var post := Watcher.new(ReactionBus.TIMING.POST)
	var mod_gear := fit_mod(pre, post)
	await shoot_miss()
	assert_eq(pre.seen.size(), 1, 'CLAIM C: the mod Kit\'s PRE reaction runs once per declared attack.')
	assert_eq(post.seen.size(), 1, 'The POST one too.')
	if pre.seen.is_empty(): return
	assert_eq(pre.seen[0].weapon_mod, mod_gear, 'CLAIM C: the firing weapon\'s get_weapon_mod is this Kit\'s gear.')

func test_a_finish_damage_buff_hung_at_pre_is_gone_by_post():
	var pre := Watcher.new(ReactionBus.TIMING.PRE)
	pre.hang_buff = true
	var post := Watcher.new(ReactionBus.TIMING.POST)
	fit_mod(pre, post)
	await shoot_miss()
	assert_eq(post.seen.size(), 1, 'LIVENESS: POST ran.')
	if post.seen.is_empty(): return
	# PROBE A. Recorded either way; the design's ruled carrier needs TRUE here.
	assert_false(post.seen[0].has_buff, 'PROBE A (measured): the attacker\'s FINISH_DAMAGE buff is cleared BEFORE ATTACK_DECLARED POST (:203-205).')

func test_a_stamp_on_the_declared_summary_survives_pre_to_post_and_not_to_the_next_attack():
	var pre := Watcher.new(ReactionBus.TIMING.PRE)
	pre.stamp = true
	var post := Watcher.new(ReactionBus.TIMING.POST)
	fit_mod(pre, post)
	await shoot_miss()
	pre.stamp = false
	await shoot_miss()
	assert_eq(post.seen.size(), 2, 'LIVENESS: two attacks, two POSTs.')
	if post.seen.size() < 2: return
	assert_same(post.seen[0].summary, pre.seen[0].summary, 'CLAIM B: PRE and POST see the same DeclaredAttackSummary.')
	assert_true(post.seen[0].has_stamp, 'CLAIM B: the PRE stamp is readable at POST.')
	assert_false(post.seen[1].has_stamp, 'CLAIM B: the next attack\'s summary is fresh.')
