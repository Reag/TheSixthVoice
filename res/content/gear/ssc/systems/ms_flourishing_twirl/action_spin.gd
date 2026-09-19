## FLOURISHING TWIRL, SPIN (Primrose rank III, SP4 Task 3).
##
##   "Spin (Quick): Choose a weapon you have mounted, all hostile characters within its threat and
##    line of sight must succeed an Agility save or take 4 kinetic damage and become Impaired until
##    the end of their next turn."
##   (specs/sixth-voice/07-primrose.md, Rank III, "System: Flourishing Twirl";
##    localizations.csv gear.ms_flourishing_twirl.action_spin.effect)
##
## NO ATTACK ROLL ANYWHERE (ruling 19). This is a radius and a save, not an attack, so nothing here
## touches accuracy, cover or evasion and the chosen weapon contributes exactly one number: its
## threat. The weapon is a measuring stick, not a thing being swung.
##
## ================== THE ORDER OF THE FIRST FOUR STEPS IS THE WHOLE OF RULING 4 ==================
##
## This is the same shape as this frame's own cp_mobian_rainbow/action_glimmering_armaments.gd, and
## for the same reason. Read that file beside this one.
##
##   1. build the entries        - one per MOUNTED weapon action with printed threat
##   2. label them               - "<name> (<Threat> N)", N the BUFFED threat
##   3. pick                     - auto with one entry, prompt with more, RETURN on a cancel
##   4. spend_actions            - and ONLY here
##
## spend_actions is the ONLY route to gear.spend_charge() (unit_action.gd:274, reached through
## UnitAction.spend_actions_gain_heat from Action.spend_actions, action.gd:144-147). So every early
## return above it is free, and that is the point rather than an accident: a Spin with no mounted
## weapon, and a Spin whose prompt the player backs out of, are the two ways a player could lose one
## of four charges for nothing. test_cancelling_the_prompt_spends_nothing and
## test_spin_with_no_mounted_weapon_spends_nothing are what hold the order in place; moving
## spend_actions above the prompt reddens the first of them and nothing else.
##
## ================== "A WEAPON YOU HAVE MOUNTED" IS A FILTER, NOT A SYNONYM ==================
##
## loadout_core.gd:521-525 is explicit in its own doc comment - "No basics, but include integrated" -
## so get_all_weapons() returns the integrated weapons (a Solidcore, an omnigun, anything printed
## into the `attacks` list) AS WELL AS the ones sitting in mounts. The card says MOUNTED, so the
## integrated half is filtered back out with get_mount_for_gear(gear) != null (loadout_core.gd
## :419-422, which walks the mounts and asks each whether it holds this exact GearCore).
##
## This matters to a Primrose specifically: PrimroseFixture.equip and UnitPrinter.equip_system put a
## weapon Kit in `attacks` (loadout_core.gd:116-122 files anything with has_attack() there), i.e.
## INTEGRATED, and only MountCore.equip_primary/equip_secondary put one on a mount. So "equipped" and
## "mounted" are genuinely different sets on this frame and the filter is doing real work.
##
## ONE ENTRY PER WEAPON ACTION, NOT PER WEAPON. kit.get_weapon_actions() (kit.gd:129-132) returns
## every ActionAttackWeapon on the Kit, and a Kit can carry more than one profile - this mod's own
## mw_rend_axe carries action_rend_axe and action_rend_axe_free, and vanilla's mw_variable_sword
## carries two blade profiles. Two profiles can print two different threats, so collapsing them onto
## the Kit would mean the menu quietly picking one of them for the player.
##
## `action.threat > 0` IS THE THROWN GATE, NOT A "DOES THIS WEAPON HAVE THREAT" GATE. Every weapon in
## the engine has a threat - the export defaults to 1 (action_attack_weapon.gd:16) - so this filter
## drops nothing off a printed profile. What it DOES drop is a Thrown variant, which the engine
## builds by duplicating the action and setting threat = 0 (action_attack_weapon.gd:349-372); those
## are never in kit.actions in the first place, so today the gate is a guard rather than a filter.
## Kept because a threat-0 entry would offer the player a Spin that reaches nobody, and because a
## future profile could legitimately print 0.
##
## ================== THE LABEL READS THE **BUFFED** THREAT (ruling 4) ==================
##
## N is action.threat_distance(specific), which starts from the printed `threat` and runs
## BuffBonus.get_bonus_for_subtype over every Buff.TO.ACTION_RANGE / THREAT_RANGE buff on the unit
## (action_attack_weapon.gd:187-190). That is what makes Artful Caress (+1 to Heavy and Superheavy
## melee), the DDMR (+1 to its host weapon) and Wormhole Grasp (+1 to everything) all widen a Spin
## without a line of code here.
##
## THIS IS THE OPPOSITE OF BITING RETORT'S GATE, WHICH READS THE **PRINTED** threat (SP3's ruling),
## AND THE DIFFERENCE IS DELIBERATE. They are different questions:
##   - Biting Retort asks "is this weapon a melee weapon at all?", a question about the PROFILE, and
##     a buffed number would let a +1 threat buff turn a gun into a sword.
##   - Spin asks "how far does this weapon reach right now?", a question about the BOARD, and the
##     printed number would silently ignore three of this frame's own cards.
## A later reader WILL be tempted to make these two consistent. They already are consistent; they are
## answering different questions. test_under_artful_caress_the_falcatas_spin_reaches_one_tile_further
## is the pin on this side.
##
## THE LABEL'S NUMBER AND THE GATHER'S RADIUS ARE THE SAME VARIABLE, not two calls that happen to
## agree. Each entry's reach is measured once, when the entry is built, and the same integer is both
## printed in the menu and handed to get_characters_within. A player who reads "(Threat 4)" and gets
## a radius of 3 has been lied to by the UI, and a shared variable is the only way that cannot
## happen across the await in between.
##
## ================== THE GATHER: require_los = TRUE, UNLIKE EVERY SIBLING ==================
##
## The card says "within its threat AND LINE OF SIGHT", in so many words, so require_los is true -
## which routes the question through UnitRelation.can_see (unit_relation.gd:62, :206-216).
##
## That is the OPPOSITE of this frame's two neighbours, and the difference is the card's, not a
## preference: ms_dazzling_wind/action_leap.gd and mw_eternity_hammer/onhit_eternity_hammer.gd both
## pass false because both cards say only "adjacent", and at distance 1 sight is very nearly always
## true anyway. Spin reaches up to four tiles, so here it is a difference a player really will see.
## test_a_hostile_out_of_sight_is_untouched stages a wall and pins it.
##
## get_characters_within FILTERS TO is_character() (unit_relation.gd:42), which the card's "hostile
## CHARACTERS" wants and which is also load-bearing against the engine's save edge: make_saves ->
## make_agility_save SHORT-CIRCUITS A NON-CHARACTER TO false, the FAILURE branch, without rolling
## (unit_hasecheck.gd:47-48, "noncharacters always fail; doesn't even count as a force"). An ungated
## radius would therefore auto-damage and auto-Impair every hostile crate and mine in reach with no
## save on screen. onhit_eternity_hammer.gd records the same edge from the other side.
##
## whos_asking IS LEFT AT ITS DEFAULT, and that is correct here where it was NOT on the Hammer. The
## radius, the can_affect check and the LOS check should all be answered from the PRIMROSE, because
## the Primrose is the centre of the spin - and unit_relation.gd:55 defaults whos_asking to `unit`,
## which is already the Primrose. The Hammer measures from its TARGET and therefore has to pass the
## attacker separately.
##
## ================== THE SAVES ARE BATCHED, AND THAT IS WHY THE LOOP IS SAFE ==================
##
## UnitHasecheck.make_saves(..., Lancer.HASE.AGI, ...) rolls every unit's save and returns
## { passed:[], failed:[] } (unit_hasecheck.gd:62 is the doc comment saying so, :63-73 the body). It
## re-validates on the way in (:66), re-checks
## the unit after its own save (:68) and runs Util.filter(..., Unit.is_valid) over BOTH arrays before
## returning (:71-72) - so the `failed` array handed back cannot contain a corpse, which is more than
## a hand-rolled loop would give.
##
## THE [Lancer.STATUS.IMPAIRED] FLAG TELLS THE SAVE WHAT IT IS PUSHING AGAINST. It reaches the
## event_unit_save context as `array`, "the statuses we're pushing against" (unit_hasecheck.gd
## :83-89), which is what lets a unit immune to Impaired, or a buff that cares about being pushed
## towards one, see this coming. It does NOT change the roll, and NOTHING IN THIS SUITE
## DISCRIMINATES IT: deleting the argument leaves test_spin.gd at 14/14 with the identical 94
## asserts (measured at this task, as the plan asked). Recorded rather than quietly dropped - the
## same argument action_leap.gd and action_full_speed_ahead.gd make for their own
## [Lancer.STATUS.PRONE], and inventing an immunity test to manufacture coverage would be measuring
## UnitCondition rather than this card.
##
## THE PER-VICTIM LOOP USES Unit.is_valid, NOT activation.abort_without_unit. abort_without_unit SETS
## the activation's aborted flag (event_core.gd:26-32), so one victim dying to its own 4 kinetic would
## cancel the Spin for everybody still standing. onhit_eternity_hammer.gd's bystander loop makes the
## same choice for the same reason; action_solfataric_breach.gd and action_leap.gd may use the abort
## form because each has exactly one victim.
##
## THE DAMAGE IS EXECUTED INLINE, NOT QUEUED, and the Impaired follows it. Queued, the 4 kinetic would
## land only after activate() returned (event_core.gd:71-75 against :84-88), which would put the
## Impaired on a unit that is about to die - the card's "take 4 kinetic damage AND become Impaired"
## reads as one beat in that order. action_solfataric_breach.gd:196-207 records the identical
## decision.
##
## IT ALSO RECORDS THE HAZARD, AND THIS FILE FELL INTO IT ONCE. The ordering is observable ONLY in a
## test whose victim the damage actually KILLS: the Breach's first draft kept all 18 of its tests
## green with queue_event in place, because every one of them had a surviving target. Every hostile
## in test_spin.gd was a 200 HP punching bag at Task 3, so the same hole was open here; the review
## found it and test_a_victim_the_spin_kills_is_never_impaired closes it. MEASURED at the fix wave:
## with `await activation.execute_event(...)` below swapped for `activation.queue_event(...)`,
## test_spin.gd goes 14/15 and that test is the only red.
##
## ================== WIRING fxg_use IS NOT ENOUGH; THE CALL IS THE FX ==================
##
## SETTLED AT TASK 4 (ruling 20): `fxg_use = fxg_spin.tscn` on action_spin.tres AND
## `await run_system_fxgs(unit)` in activate below, because the wiring alone is inert. An earlier
## draft of this header said Spin falls back to the ActionSystem default fxg_base_activation in the
## meantime. IT DOES NOT, and a reader who believed it would have wired fxg_use and watched nothing
## happen. `fxg_use` and the DEFAULT_ACTIVATE_FXG fallback are read ONLY inside
## ActionSystem.run_system_fxgs (action_system.gd:70-105, the fallback at :95-97), and NOTHING calls
## that automatically: Action.activate is a bare assert (action.gd:102-103) and all ~60 call sites
## under engine/ and content/ are actions invoking it from their own activate
## (archtypes/action_system_movement.gd:108, archtypes/action_system_deploy.gd:71,
## archtypes/action_system_apply_buff.gd:127, and so on). An ActionSystem subclass that overrides
## activate and does not call it is SILENT, however its fxg_use is wired.
##
## SO THE CALL IS WHAT NO SPEC CAN SEE. test_spin.gd asserts the wiring - action.fxg_use is the
## scene - and that assertion stays green with the call deleted. The FX tester and the author's eye
## are the acceptance (ruling 20):
##
##   "D:/DEV/Godot_v4.7.2-stable_win64_console.exe" --path D:/DEV/lancer-tactics-modkit res://ui/page/fx_group_tester/fx_group_tester.tscn
##
## THE SAME OMISSION IS STILL LIVE ON THIS FRAME. cp_mobian_rainbow/action_glimmering_armaments.gd
## sets fxg_use = fxg_super_activation.tscn and never calls run_system_fxgs, so that protocol's FX
## has never played. Out of SP4's scope; recorded here and at the frame close, not fixed at Task 4.
extends ActionSystem

## The card's numbers.
const DAMAGE:int = 4

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	# Captured HERE, once, as a plain StringName rather than read back off context.gear inside the
	# per-victim loop below. A String is a value, not a reference: copying it out now, while the
	# check above still guarantees it is real, means nothing later in this function - however many
	# awaits and reactions it crosses - can turn the apply_status call at the bottom of a lap into a
	# dangling deref. See the loop for what used to go wrong here (fix wave 2).
	var gear_id:StringName = gear.persistent_id
	var specific := SpecificAction.from_context(context)
	if not SpecificAction.is_valid(specific): return

	# ------------------------------------------------------- 1 & 2. the entries, and their labels
	var entries:Array[Dictionary] = collect_mounted_profiles(unit)

	# ------------------------------------------------------- 3. the pick
	# NO MOUNTED WEAPON: return BEFORE spend_actions. A Spin with nothing to measure is not a charge
	# the player should lose, and it is not a prompt about nobody either (action_leap.gd:63 makes the
	# same call for its own empty radius).
	if entries.is_empty(): return

	var chosen:Dictionary = entries[0]
	if entries.size() > 1:
		var labels:Array = []
		for entry:Dictionary in entries: labels.append(entry.label)
		# BrochureCore.create normalises plain Strings into its {text, disabled_reason} dictionaries
		# (brochure_core.gd:26-28), which is the shape vanilla's own callers pass. can_cancel = true:
		# the third argument, and the reason the -1 below is reachable at all.
		var index:int = await choice_bus.choose_from_multiple_choice(specific, labels, true)
		# Cancelled (choice_bus.gd:138-141 returns -1), or the unit died mid-prompt. BEFORE the spend.
		if index < 0: return
		if activation.abort_without_unit(unit): return
		# Defensive: a responder or a future picker handing back an out-of-range index would otherwise
		# take the whole activation down on the next line. Treated as a cancel, which is the safe way
		# to be wrong about a cost.
		if index >= entries.size(): return
		chosen = entries[index]

	# ------------------------------------------------------- 4. the cost
	spend_actions(activation)

	# ------------------------------------------------------- 4b. the spin itself
	# AFTER THE SPEND, ON PURPOSE. Every return above this line is a Spin that never happened - no
	# mounted weapon, or a prompt the player backed out of - and a mech that whips round for a cancel
	# is a lie about what it just cost. Before the radius, because the FX's own preamble is the beat
	# the saves land on (fxg_spin.tscn sets preamble_mode DURATION 0.45, matching spin_node.gd's
	# SPIN_DURATION), and run_system_fxgs awaits exactly that preamble and no longer
	# (common_action_util.gd:867-869).
	#
	# THIS LINE IS THE FX, NOT THE fxg_use WIRING. Nothing in the engine calls run_system_fxgs
	# automatically - see the "WIRING fxg_use IS NOT ENOUGH" header section for the finding.
	# MEASURED at Task 4: commented out, test_spin.gd stays 16/16 on the identical 105 asserts. The
	# screen is the only thing that goes still, which is why the FX tester is the acceptance.
	await run_system_fxgs(unit)
	# The await crosses real frames, so re-check before measuring the board off `unit`. Vanilla guards
	# its own FX awaits the same way ("guard against quitting the game mid-activation",
	# common_action_util.gd:869, :886).
	if activation.abort_without_unit(unit): return

	# ------------------------------------------------------- 5. the radius
	var reach:int = chosen.reach
	var hostiles:Array[Unit] = UnitRelation.get_characters_within(
		unit, reach, true,
		func(other:Unit) -> bool: return UnitRelation.are_enemies(unit, other)
	)
	if hostiles.is_empty(): return

	# ------------------------------------------------------- 6. the saves
	# `:=` rather than a declared Dictionary: make_saves returns Dictionary[StringName, Array] and
	# vanilla's own two callers infer it the same way (action_seeker_volley_rainmaker.gd:35,
	# action_immolate_witch.gd:17).
	var results := await UnitHasecheck.make_saves(
		activation, hostiles, specific, Lancer.HASE.AGI, [Lancer.STATUS.IMPAIRED]
	)
	if activation.abort_without_unit(unit): return

	# ------------------------------------------------------- 7. what a failure costs
	for victim:Unit in results.failed:
		# BOTH GUARDS RE-RUN EVERY LAP, and the gear one deliberately so. Re-reading gear validity is
		# not trusting the top-of-function check: the saves above are a full event chain, and so is
		# each damage event below, and a reaction inside any of them could destroy this system before
		# a LATER lap reaches its own event_unit_damage call, which still carries gear = context.gear
		# three lines down (fix wave 2: this guard no longer stands in for a persistent_id re-check -
		# that value is now read once into gear_id before the loop, at the top of this function, so it
		# can no longer go stale mid-loop. What this guard still protects is the event dict below: a
		# guard hoisted above the loop, the shape the first draft had, would cover victim 1's event and
		# then hand every later victim's event a freed gear as its damage source). onhit_eternity_
		# hammer.gd:187-188 makes the same argument for its own per-lap SpecificAction re-check, and
		# its comment is the one to read: checking at the TOP of the lap rather than after the damage
		# is the difference that matters.
		#
		# `return`, not `continue`, for the gear: a Spin whose system no longer exists has nothing left
		# to deal damage FROM, and no later lap could do better. The VICTIM check is a `continue`
		# because the next victim is still perfectly reachable - see the header.
		if not Unit.is_valid(victim): continue
		if not GearCore.is_valid(context.gear): return
		await activation.execute_event(&'event_unit_damage', {
			unit = victim,
			number = DAMAGE,
			category = Lancer.DAMAGE_TYPE.KINETIC,
			target_unit = unit, # the damage event's target_unit is WHO DEALT it, not who takes it
			gear = context.gear,
			action = self,
			flags = [EventService.DAMAGE_FLAG.SAVE_FAILED],
		})
		# Killed by its own 4. `continue`, not abort_without_unit - see the header.
		if not Unit.is_valid(victim): continue
		# gear_id, not context.gear.persistent_id: this used to be the exact read that ran AFTER the
		# await above with nothing re-guarding it - the gap fix wave 2 closed. See the top of this
		# function for where it is captured and why a captured value closes the gap for good instead
		# of just moving it one guard later.
		UnitCondition.apply_status(
			activation, victim,
			Lancer.STATUS.IMPAIRED, Lancer.UNTIL.END_OF_NEXT_TURN,
			gear_id
		)

## One dictionary per MOUNTED weapon profile that prints a threat: { reach, label }.
##
## THE REACH IS MEASURED HERE AND NOWHERE ELSE, so the number in the menu and the number handed to
## get_characters_within are the same integer rather than two calls across an await - see the header.
##
## THE CHOSEN WEAPON'S SpecificAction IS DELIBERATELY NOT CARRIED FORWARD. Spin never swings it: the
## weapon contributes one integer and nothing else, and the save's own forcing action is the SPIN
## (so the battle log and every save-side buff see the system, which is what the card describes).
## Keeping the weapon in the dictionary would be an inert field that reads as load-bearing, and the
## next reader would wonder which of the two SpecificActions the saves are attributed to.
func collect_mounted_profiles(unit:Unit) -> Array[Dictionary]:
	var entries:Array[Dictionary] = []
	var loadout:LoadoutCore = unit.core.loadout
	for weapon:GearCore in loadout.get_all_weapons():
		if not GearCore.is_valid(weapon): continue
		# "a weapon you have MOUNTED" - get_all_weapons includes the integrated ones too.
		if loadout.get_mount_for_gear(weapon) == null: continue
		for weapon_action:ActionAttackWeapon in weapon.kit.get_weapon_actions():
			if weapon_action.threat <= 0: continue
			var weapon_specific := SpecificAction.create(unit, weapon, weapon_action)
			var reach:int = weapon_action.threat_distance(weapon_specific)
			entries.append({reach = reach, label = label_for(weapon_specific, reach)})
	return entries

## "<name> (<Threat> N)", e.g. "Acrasial Falcata (Threat 4)".
##
## Action.name(specific) (action.gd:332 -> Translate.action, translate.gd:19-47) resolves the
## profile's own name row when it has one and falls back to the Kit's name when it does not - so a
## one-profile weapon reads as its own name and mw_rend_axe's second profile reads "Rend Axe (Free)",
## with no per-weapon wiring here. `lancer.term.threat` is the engine's own glossary row for the word
## (assets/localization/localizations.csv:6850), so the menu is translated wherever the game is.
func label_for(weapon_specific:SpecificAction, reach:int) -> String:
	return '%s (%s %d)' % [weapon_specific.action.name(weapon_specific), X.tr('lancer.term.threat'), reach]
