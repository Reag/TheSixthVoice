# Content integrity for The Sixth Voice.
#
# A standing spec, built in SP0 against an EMPTY mod and never rewritten: every later sub-project
# adds its ids to the tables below and this file guards them. It is about wiring rather than
# behaviour - is everything registered, under the right index, with localization and an icon to
# match. Behaviour specs belong beside each ability as it is built.
#
# The tables are deliberately empty right now. That is not the same as the file asserting nothing:
# the mod-is-loaded, manifest, localization and glossary tests all bite today, and they are the ones
# that fail silently in play rather than loudly in a run.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const ModContentAudit := preload('res://testkit/mod_content_audit.gd')
const ModResources := preload('res://testkit/mod_resources.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const MOD_ID := 'Reag-TheSixthVoice'

# ModUtil and ModLibrary are class_name scripts that exist only on the 1.4 line. This mod targets
# 1.4.x only, but naming them directly would make the whole file fail to PARSE on any other engine -
# and GUT skips an unparsable script instead of failing it, so the suite would go green and smaller.
# Reaching them by path costs nothing and keeps the failure mode loud.
const MOD_UTIL := 'res://engine/mod/mod_util.gd'
const MOD_LIBRARY := 'res://engine/mod/mod_library.gd'

## Every ContentLibrary index this mod will ever contribute to. Walked by the audit and the icon
## guard so a new index cannot be added without the guards noticing.
const OUR_INDEXES:Array[StringName] = [&'frames', &'kits', &'buffs', &'licenses']

## The version this release ships. Bumped deliberately, once per release - it is not meant to track
## every commit. The number itself is not decided here: specs/2026-09-13-sixth-voice-roadmap.md §2
## is the source of truth for which release is current, and this const is just that number copied
## into a place a spec can see it.
const EXPECTED_VERSION := '0.3.0'

func test_the_mod_is_actually_loaded():
	# Everything below passes vacuously if the mod did not install, so this is the gate.
	assert_true(Compat.is_mod_active(MOD_ID), '%s is loaded and active.' % MOD_ID)

func test_no_resource_is_filed_under_the_wrong_index():
	# ContentLibrary sorts by FILENAME PREFIX, not by script class and not by folder. A Buff named
	# bt_* lands in the kits index and get_buff can never find it - no warning, no log line.
	# See testkit/mod_content_audit.gd.
	var problems := ModContentAudit.find_misfiled_resources(MOD_ID)
	for problem:String in problems: gut.p('  %s' % problem)
	assert_eq(problems.size(), 0, 'Every resource landed in the right ContentLibrary index.')

func test_the_manifest_names_the_running_engine():
	# 1.4.1 changed ModUtil.is_likely_compatible_with_game_version from "older than the game is fine"
	# to !=, on major and minor, and on PATCH too for any mod declaring requires_restart - which this
	# one does. So EVERY modkit patch release silently un-declares this mod: the player gets a
	# version-mismatch warning in Mod Manage and on mod.io, with nothing in a normal test run to say
	# so. The check is an any() over the array, so the fix is always to APPEND the new version to
	# compatible_game_version, never to replace what is there.
	# ASSERTED ON THE ARRAY, not only through the engine call, and that distinction is the whole
	# point of this test. is_mod_likely_compatible_with_game_version (mod_util.gd:124-127) does
	#
	#     mod_compatible_versions.append(manifest.mod_meta.game_version)
	#     mod_compatible_versions.append_array(manifest.compatible_game_version)
	#
	# and then an any() over the result - so `mod_meta.game_version` ALONE satisfies it, and a stale
	# compatible_game_version sails through. `mod_meta` is written by the upload machinery, and
	# ModManifest.deserialize falls back to ModMeta.create() - which sets game_version to the CURRENT
	# engine - when the key is absent, at which point the engine call could never fail at all.
	#
	# Caught in review 2026-09-13, after a mutation run that changed both values at once and so could
	# not tell them apart.
	var library = load(MOD_LIBRARY)
	var manifest = library.get_manifest(StringName(MOD_ID))
	assert_not_null(manifest, '%s has a manifest.' % MOD_ID)
	if manifest == null: return
	var declared:Array = Array(manifest.compatible_game_version)
	assert_true(declared.has(Compat.version_label()),
		'compatible_game_version %s names %s.' % [declared, Compat.version_label()])
	# The engine's own verdict too, so a future change to how it reads the manifest also shows up.
	var mod_util = load(MOD_UTIL)
	assert_true(
		mod_util.is_mod_likely_compatible_with_game_version(manifest),
		'The engine agrees this mod is compatible with %s.' % Compat.version_label()
	)

func test_the_manifest_version_matches_the_release_this_mod_claims_to_be():
	# Nothing else in this file reads version_number, which is exactly how "0.0.1" - the SP0
	# skeleton placeholder - survived five sub-projects and several reviews unnoticed. This guard
	# exists so the next stale version fails a test instead of shipping quietly on a store listing
	# that claims something newer.
	var library = load(MOD_LIBRARY)
	var manifest = library.get_manifest(StringName(MOD_ID))
	assert_not_null(manifest, '%s has a manifest.' % MOD_ID)
	if manifest == null: return
	assert_eq(manifest.version_number, EXPECTED_VERSION,
		'manifest.json version_number matches EXPECTED_VERSION - bump both together next release.')

func test_this_mods_translation_reached_the_translation_server():
	# NOT a test of what Mod Manage displays. Mod Manage shows ModCore.tr_label()
	# (mod_core.gd:80-84), which returns manifest.title with no translation lookup at all - nothing
	# in the engine reads a `mod.*` key. The row is vestigial, inherited from Thy Hubris.
	#
	# It is kept as a canary, and it is the ONLY test that proves
	# LancerTacticsMod.add_translations actually registered our artifact with the TranslationServer.
	# The glossary test below loads the .translation file directly, which proves the file is right
	# but says nothing about whether tr() can see it.
	assert_ne(tr('mod.reag_thesixthvoice.name'), 'mod.reag_thesixthvoice.name',
		'tr() resolves a key that only this mod supplies, so our translation is registered.')

# ---------------------------------------------------------------- the glossary
#
# The supplement's Efficient tag (Maiden's Blush, Lovers Knot, Black Mountain) is not in the base
# game's glossary json, so |Efficient| in rule text renders as coloured text with no hover unless
# mod_main.register_glossary_terms appends the key and the CSV carries both rows. It ships in the
# skeleton, ahead of its first consumer, so the seam is proven on this engine before a frame leans
# on it (author's call, 2026-09-13).
#
# WHY THESE THREE TESTS AND NOT ONE. The obvious check - ask GlossaryItem whether the term resolves -
# CANNOT FAIL IN A TESTKIT RUN, because Thy Hubris is loaded alongside us and registers
# `lancer.term.efficient` itself, with its own CSV rows. Verified 2026-09-13 by emptying this mod's
# GLOSSARY_TERMS and re-running: the global lookup stayed green. Both the glossary cache and tr() are
# GLOBAL, so neither can say which mod supplied the term - and a player with only this mod installed
# would get a dead label. So the two tests that have to discriminate read THIS MOD'S OWN files, and
# the end-to-end one is kept for what it is worth with that limitation written down.

const OUR_MOD_MAIN := 'res://unpacked/Reag-TheSixthVoice/mod_main.gd'
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

func test_this_mod_registers_the_efficient_term_itself():
	# Reads our own mod_main rather than the shared glossary cache, so another mod registering the
	# same term cannot cover for us.
	var script:Script = load(OUR_MOD_MAIN)
	assert_not_null(script, 'mod_main.gd loads.')
	if script == null: return
	var terms:Array = script.get_script_constant_map().get('GLOSSARY_TERMS', [])
	assert_has(terms, &'lancer.term.efficient', 'This mod declares the term in GLOSSARY_TERMS.')

func test_this_mods_own_translation_carries_both_glossary_rows():
	# Loads THIS MOD'S compiled artifact directly, for two reasons. It is the only way to attribute a
	# row to us rather than to Thy Hubris. And it is the check for the staleness trap: Translate loads
	# `localizations.en.translation`, NOT the csv beside it, and `filesystem_manage(op="reimport")`
	# refreshes the filesystem entry WITHOUT regenerating the artifact - only op="scan" does. So a
	# correct CSV can sit next to an artifact that has never heard of these keys.
	#
	# The artifact is an OptimizedTranslation, which hashes its keys, so grep cannot answer this and a
	# zero hit is not evidence of anything. get_message can.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	# Driven off GLOSSARY_TERMS, not a hardcoded list, so the second term somebody registers cannot
	# ship without its CSV rows.
	var terms:Array = load(OUR_MOD_MAIN).get_script_constant_map().get('GLOSSARY_TERMS', [])
	assert_false(terms.is_empty(), 'GLOSSARY_TERMS is not empty, so this test has something to check.')
	for term:StringName in terms:
		for key:String in [String(term), '%s.desc' % term]:
			assert_ne(translation.get_message(key), StringName(''),
				'Our own artifact carries %s.' % key)

func test_the_efficient_term_resolves_end_to_end():
	# The real behaviour, with the caveat above: green here does NOT prove this mod supplied the term
	# while Thy Hubris is loaded. It is still worth running - it is the only test that exercises the
	# priming call in register_glossary_terms and the ".desc must exist" rule inside
	# find_key_from_label, and it would catch an engine change that broke the mechanism for everybody.
	# Matching is case-insensitive, so |efficient| in a rule row resolves to the same entry.
	assert_eq(GlossaryItem.find_key_from_label('Efficient'), 'lancer.term.efficient',
		'|Efficient| links to its own glossary entry.')
	assert_eq(GlossaryItem.find_key_from_label('efficient'), 'lancer.term.efficient', 'Either case.')

## Every kit and player-facing buff this mod ships, and the actions on each kit that need their own
## icon. Filled in by each sub-project as it builds content; the icon pass is what makes it green.
##
## Shape: kit id => the action ids on that kit that are player-facing. A kit whose only action is
## the kit itself wears the kit's icon, so it lists none.
const ICON_TARGETS := {
	&'mt_weak_computer': [], # its only action is the kit itself
	# Three buttons on one Kit: the base weapon profile, the MORE BLACK POWDER protocol, and the
	# second weapon profile the protocol unlocks. Each is separately pressable, so each wears its own
	# icon rather than sharing the Kit's.
	&'cp_broadside': [&'action_more_black_powder_protocol'],
	# The two CANNON PROFILES moved to their own Kit at the frame close, so the character sheet
	# titles the integrated-weapon box "Bizarre Cannon" instead of "Broadside"
	# (weapon_mount_item.gd:101 reads the KIT's name). See test_integrated_weapon_names.gd.
	&'mw_bizarre_cannon': [&'action_bizarre_cannon', &'action_more_black_powder'],
	&'mt_hole_puncher': [], # a passive trait: no action of its own, so it wears the Kit's icon
	&'mt_knock_em_down': [], # a passive trait: no action of its own, so it wears the Kit's icon
	# Its one action (action_blasting_powder_spend) is a hidden bookkeeping reaction: reactions never
	# reach the gear bar (gear_bar.gd:145) and it overrides show_in_tooltip to false, so nothing the
	# player sees ever wears an icon for it. The Kit's own icon still has to be real.
	&'mt_blasting_powder': [],
	# SP2 Task 1. A weapon Kit, not a trait: its SINGLE SHOT profile is a separately pressable button
	# on the gear bar, so it wears its own icon rather than sharing the Kit's - same reasoning as
	# cp_broadside's three entries. Task 2 adds GRAPESHOT here for the same reason: a second,
	# separately pressable profile on the same Kit. (Task 3's hidden reload reaction gets no row, for
	# the mt_blasting_powder reason above.)
	&'mw_breech_loading_swivel_gun': [&'action_swivel_single_shot', &'action_swivel_grapeshot'],
	# SP2 Task 4. Its one action (action_heaer_detonate) is a hidden bookkeeping reaction: reactions
	# never reach the gear bar (gear_bar.gd:145) and it overrides show_in_tooltip to false, so nothing
	# the player sees ever wears an icon for it. The Kit's own icon still has to be real - the system
	# is equippable, and sits in the loadout like any other.
	&'ms_heaer': [],
	# SP3 Task 1. Unlike ms_heaer, this system's one action is a QUICK the player presses on the gear
	# bar, so it wears its own icon rather than sharing the Kit's - vanilla's ms_ramjet is the shape
	# (its Kit carries no icon_override at all and its single action carries one). This mod's own
	# guard is stricter and wants both, which is SP5's job.
	&'ms_hull_break_thrusters': [&'action_full_speed_ahead'],
	# SP3 Task 3. A weapon mod: no actions at all, so nothing but the Kit's own icon is ever shown -
	# it appears in the weapon-mod dropdown and on the modded weapon's card.
	&'wm_ripper_mod': [],
	# SP4 Task 1. A weapon Kit with a single profile, and that profile still earns its own row: it is
	# a separately pressable button on the gear bar, exactly the mw_breech_loading_swivel_gun
	# reasoning. Having only one profile does not merge the button into the Kit - the gear bar draws
	# the action, and an action with no icon_override falls back to a generic, which is what this
	# guard exists to catch.
	&'mw_rapier_class_carronade': [&'action_rapier_carronade'],
	# SP4 Task 3. A system whose one action is a QUICK the player presses on the gear bar, so it wears
	# its own icon as well as the Kit's - the ms_hull_break_thrusters reasoning exactly, not the
	# ms_heaer one (HEAER's only action is a hidden reaction that never reaches the gear bar).
	&'ms_grit_latch_magnets': [&'action_reinforcement_blast'],
	# SP1 Task 1 (M/K2). A 1/scene trait whose single FREE action is a separately pressable button on
	# the gear bar, so it wears its own icon as well as the Kit's - the ms_hull_break_thrusters
	# reasoning, not the ms_heaer one.
	&'mt_rapid_stabilization_jets': [&'action_rapid_stabilization_jets'],
	# SP1 Task 2 (M/K2). A pure passive: no action of its own, so it wears the Kit's icon.
	&'mt_hybridized_shot': [],
	# SP1 Task 3 (M/K2). The core system, one pressable protocol - cp_broadside's shape with one
	# button instead of three.
	&'cp_auxiliary_power_rerouter': [&'action_ors_hypercharge'],
	# SP1 Task 4 (Subutai). Its one action is an end_turn reaction, and reactions never reach the
	# gear bar (gear_bar.gd:145) - but unlike mt_blasting_powder's and ms_heaer's hidden bookkeeping
	# reactions, this one does NOT override show_in_tooltip, so it is drawn on the trait card with
	# its own row. It therefore earns its own icon as well as the Kit's.
	&'mt_juggernaut_drive': [&'action_juggernaut_drive'],
	# SP1 Task 2 (Subutai). A pure passive: no action of its own, so it wears the Kit's icon. Its
	# BuffResistDamage is an inline SubResource and carries hide_from_player, so it is correctly
	# absent from VISIBLE_BUFFS - it is never a chip on the unit.
	&'mt_reinforced_chassis': [],
	# SP2 Task 1 (Subutai). The core system. GATHER ROUND is a PROTOCOL the player presses on the
	# gear bar, so it wears its own icon as well as the Kit's - cp_auxiliary_power_rerouter's shape.
	# Task 2 appends action_diversion_rail (a pressable weapon profile) and Task 3 action_draw_fire
	# (a reaction that never reaches the gear bar, but does not override show_in_tooltip, so it is
	# drawn on the trait card with its own row - the mt_juggernaut_drive reasoning).
	&'cp_siege_engine': [&'action_gather_round', &'action_draw_fire'],
	# The Rail is its OWN Kit since the frame close, so the character sheet can title the
	# integrated-weapon box "Diversion Rail" instead of "Siege Engine"
	# (weapon_mount_item.gd:101 reads the KIT's name). See test_integrated_weapon_names.gd.
	&'mw_diversion_rail': [&'action_diversion_rail'],
	# SP1 Task 3 (Myconid). Pure passives: a Gaze-shaped PassiveStatIncrease and a
	# PassiveBuffApplicator carrying THREE hidden bookkeeping buffs since SP2.5 Task 1 (the third
	# relieves a non-consuming reaction's per-round cap). No actions at all, so it wears the Kit's
	# icon and lists none. All three set hide_from_player and are correctly absent from
	# VISIBLE_BUFFS - none is ever a chip on the unit.
	&'mt_symbiosis': [],
	# SP1 Task 5 (Myconid). Its one action (action_halo) is a hidden reaction: reactions never reach
	# the gear bar (gear_bar.gd:145) and it overrides show_in_tooltip to false, so nothing the player
	# sees ever wears an icon for it - the ms_heaer shape, not the mt_juggernaut_drive one. The Kit's
	# own icon still has to be real.
	&'mt_halo': [],
	# SP2 Task 3 (Myconid). The core system. FUNGAL NETWORK is a PROTOCOL the player presses on the
	# gear bar, so it wears its own icon as well as the Kit's - cp_siege_engine's and
	# cp_auxiliary_power_rerouter's shape. The Kit's two PassiveAuras are passives and wear nothing.
	#
	# The Pike is deliberately NOT here: it is its own mw_ Kit (ruling 9), listed separately when
	# SP2 Task 4 lands, because weapon_mount_item.gd:101 titles the character sheet's
	# integrated-weapon box from the KIT that holds the weapon action.
	&'cp_quietus_machines': [&'action_fungal_network'],
	# SP2 Task 4 (Myconid). Its own mw_ Kit (ruling 9), listed separately from cp_quietus_machines
	# for the same reason as mw_diversion_rail above: weapon_mount_item.gd:101 titles the character
	# sheet's integrated-weapon box from the KIT that holds the weapon action, so a strike living on
	# the core Kit would title the box "QUIETUS MACHINES" instead of the weapon's own name.
	#
	# BOTH ACTIONS EARN A ROW, and for different reasons. The strike is the weapon profile
	# weapon_mount_item.gd:71 always draws for an integrated mount's first weapon action
	# (core.kit.get_weapon_actions()[0], with no is_situationally_activated or show_in_tooltip check
	# of its own), so it needs a real icon on the character sheet even though
	# is_situationally_activated keeps it off the gear bar (gear_bar.gd:149) and off the trait card
	# (ActionAttack.show_in_tooltip, action_attack.gd:90). The Gyre's `.trigger` row does NOT reach the
	# BASE Action.show_in_tooltip's trigger clause (action.gd:344) - that clause reads the KIT's own
	# `gear.mw_psychopomp_fold_pike.trigger` key, which this mod does not have; the mod's trigger row
	# is action-keyed instead. It draws because its own `.effect` row is non-empty and differs from
	# the Kit's generic one (action.gd:350-353) - the mt_juggernaut_drive / action_draw_fire shape,
	# not the strike's.
	&'mw_psychopomp_fold_pike': [&'action_psychopomp_strike', &'action_uffish_gyre'],
}
## Player-facing buffs. A buff with hide_from_player needs no icon and does not belong here.
##
## Only STANDALONE buff_*.tres files reach this list: ModResources reads the mod's `buffs` index, and
## a Buff carried as an inline SubResource on a Kit, action or passive never enters it.
##
## THAT IS A HOUSE RULE, NOT JUST A NOTE. A player-visible Buff MUST live in its own buff_*.tres
## file. mech_info.gd:34 renders every buff without hide_from_player as a status chip, so an inline
## one is on screen and needs an icon exactly as much as a standalone one - but this guard cannot
## see it, so the SP5 icon pass could watch both icon tests go green and still ship a blank chip.
## Whole-branch review, 2026-09-13: mt_weak_computer carried its BuffSkillSave inline (copied from
## vanilla mt_exposed_reactor's shape) and was exactly that hole; it is now
## res/content/frames/ipsn/mf_fitzgerald/buff_weak_computer.tres. Nineteen more frames copy the
## Fitzgerald, so the standalone shape is the one to copy. Inline is still fine for a buff that sets
## hide_from_player - Knock 'em down's and Hole Puncher's are standalone only because they carry
## their own scripts.
##
## Hole Puncher's three buffs (buff_hole_puncher_arcing / _ignore_cover / _soft_cover) are all
## hide_from_player - they are trait plumbing, never a chip on the unit - so they are deliberately
## absent here, and the count assertion below is what keeps that honest: unhide one and this list
## stops matching.
## buff_weak_computer is player-visible on purpose: the Fitzgerald wears it permanently, and the
## drawback being legible as a chip on the unit is the point of it. Its name and effect text need no
## CSV rows of their own - Translate.buff (translate.gd:65-77) falls through to the owner gear's
## keys, so the chip reads "Weak Computer" off gear.mt_weak_computer.name exactly as it did while the
## buff was inline.
## SP4 Task 3 is the FIRST TIME THIS ARRAY HAS MOVED SINCE SP1. buff_reinforcement_blast is
## deliberately player-visible (it is SP4's only visible buff): the armor chip on each unit in the
## blast is the sole on-map signal that REINFORCEMENT BLAST landed, since the system draws nothing
## else. Its sibling buff_reinforcement_blast_reduction, added by Task 4, is hidden and must NOT be
## listed here - the two together are one mechanic, and showing both would put two chips on every
## target for one effect.
const VISIBLE_BUFFS:Array[StringName] = [
	&'buff_more_black_powder', &'buff_weak_computer', &'buff_reinforcement_blast',
	# SP1 Task 1 and Task 3 (M/K2) - deliberately player-visible, and they are the only on-map signal
	# that either ability is running.
	&'buff_rapid_stabilization_jets', &'buff_ors_hypercharge',
	# SP2 Task 1 (Subutai). The chip is the only on-map signal that the core power is up and Draw
	# Fire is live; Draw Fire itself reads it by id, so it has to exist as a standalone buff_*.tres
	# whether or not it were visible.
	&'buff_gather_round',
	# SP2 Task 2 (Subutai). The on-hit chip. Visible for two independent reasons: it is the target's
	# only warning that it is at +2 difficulty, and attack_roll.gd:189 passes buff_core.base.icon
	# RAW into the roll breakdown - NOT through Buff.get_icon(), so BuffBonus's accuracy-svg fallback
	# never runs on that path and a null icon draws a blank beside the -2.
	&'buff_diversion_rail',
	# SP2 Task 3 (Myconid). All three of FUNGAL NETWORK's player-facing chips. The cloud draws nothing
	# else on the map, so these are the only signal that the zone exists at all - one on each sheltered
	# ally (two chips, because the immunity and the armor are separate promises of the card) and one on
	# each choked hostile.
	#
	# buff_fungal_network_armor_reduction is the hidden half of the armor grant and is deliberately
	# ABSENT: the pair is one mechanic, and two chips for one effect would read as two effects. Same
	# reasoning as buff_reinforcement_blast_reduction above.
	&'buff_fungal_network_immunity', &'buff_fungal_network_armor', &'buff_fungal_network_spores',
	# SP2 Task 4 (Myconid). The Gyre's on-hit chip - the reaction fires on somebody ELSE's turn, so
	# this chip is the only on-map signal the mover gets that the Pike's strike landed. Same
	# reasoning as buff_reinforcement_blast and buff_fungal_network_armor above:
	# buff_uffish_gyre_armor_reduction is the hidden half that does the actual damage reduction and
	# is deliberately ABSENT - the pair is one mechanic, and two chips for one effect would read as
	# two.
	&'buff_uffish_gyre_armor',
]

func test_every_player_facing_kit_and_action_has_a_real_icon():
	# A kit or action without icon_override falls back to the generic glyph, which reads as "this
	# gear is unfinished" in the gear bar. The placeholder check is the other half: an icon pass that
	# wired the stand-in everywhere would otherwise sail through.
	#
	# The subject is the mod's OWN contributions, not ICON_TARGETS, so a kit added without a table
	# row cannot slip past unchecked - that is what the size assertion pins, and it is also what
	# makes this test assert something while the mod is still empty. It reads through
	# testkit/mod_resources.gd rather than ContentLibrary.get_all, which loads every installed mod
	# and fails on a stranger's parse error.
	var kits:Array[Resource] = ModResources.load_ours(MOD_ID, &'kits')
	assert_eq(ICON_TARGETS.size(), kits.size(), 'ICON_TARGETS lists every kit this mod ships.')
	for kit:Kit in kits:
		# The count above is not enough on its own: a stale row for a deleted kit plus a new kit with
		# no row balances it, and `ICON_TARGETS.get(id, [])` would then silently check no actions on
		# the new kit. This is what makes the pairing exact.
		assert_true(ICON_TARGETS.has(kit.compcon_id),
			'%s is listed in ICON_TARGETS.' % kit.resource_path.get_file())
		_assert_real_icon(kit.icon_override, kit.compcon_id)
		var listed:Array = ICON_TARGETS.get(kit.compcon_id, [])
		var by_id := {}
		for action:Action in kit.actions: by_id[action.get_id()] = action
		for action_id:StringName in listed:
			assert_true(by_id.has(action_id), '%s carries %s.' % [kit.compcon_id, action_id])
			if not by_id.has(action_id): continue
			_assert_real_icon(by_id[action_id].icon_override, '%s.%s' % [kit.compcon_id, action_id])

func test_every_visible_buff_has_a_real_icon():
	# Same shape: driven by what the mod contributed, so VISIBLE_BUFFS cannot fall behind. A buff
	# with hide_from_player needs no icon and is not counted.
	var visible:Array[Buff] = []
	for buff:Buff in ModResources.load_ours(MOD_ID, &'buffs'):
		if not buff.hide_from_player: visible.append(buff)
	assert_eq(VISIBLE_BUFFS.size(), visible.size(), 'VISIBLE_BUFFS lists every player-facing buff.')
	for buff:Buff in visible:
		assert_true(VISIBLE_BUFFS.has(buff.compcon_id),
			'%s is listed in VISIBLE_BUFFS.' % buff.resource_path.get_file())
		_assert_real_icon(buff.icon, buff.compcon_id)

## Buffs that are hidden from the chip list but STILL need an icon, because something other than the
## status bar draws them.
##
## The case this exists for is an accuracy or difficulty buff: attack_roll.gd:189 passes
## `buff_core.base.icon` RAW into the roll breakdown - not through Buff.get_icon(), so
## BuffBonus's accuracy-svg fallback is never consulted on that path - and a null there draws a blank
## beside the +1 while every other guard in this file stays green.
##
## Unlike the two tables above, this one is NOT size-checked against a mod index: "hidden" is the
## normal case for trait plumbing (Hole Puncher ships three hidden buffs that draw nothing anywhere)
## and a count assertion here would demand a row for every one of them. The entries are therefore
## added by hand, by whoever builds a hidden buff that something draws. SP1 Task 2 is the first.
const HIDDEN_BUFFS_NEEDING_ICONS:Array[StringName] = [&'buff_hybridized_shot']

func test_every_hidden_buff_that_is_still_drawn_has_a_real_icon():
	# This list is hand-maintained and, unlike ICON_TARGETS and VISIBLE_BUFFS, NOT size-checked
	# against a mod index (see above), so nothing else would notice it being emptied. Without this
	# guard the loop below would simply have no body, and GUT scores a test that asserted nothing as
	# RISKY, not FAILED (gut.gd:820-821 and, on the parameterized path, gut.gd:580-581; the run
	# summary prints it as 'Did not assert' at summary.gd:121-122). The failing-test count would not
	# move, so a deleted row would take the gate with it in silence. Same guard, same reason, as
	# test_this_mods_own_translation_carries_both_glossary_rows above.
	assert_false(HIDDEN_BUFFS_NEEDING_ICONS.is_empty(),
		'HIDDEN_BUFFS_NEEDING_ICONS is not empty, so this test has something to check.')
	var by_id := {}
	for buff:Buff in ModResources.load_ours(MOD_ID, &'buffs'): by_id[buff.compcon_id] = buff
	for buff_id:StringName in HIDDEN_BUFFS_NEEDING_ICONS:
		assert_true(by_id.has(buff_id), "%s is one of this mod's buffs." % buff_id)
		if not by_id.has(buff_id): continue
		_assert_real_icon(by_id[buff_id].icon, buff_id)

func test_the_mod_reports_what_it_contributed():
	# SP1 through SP5 have all landed, so this is no longer just a report: every index this mod
	# claims in OUR_INDEXES must actually carry at least one resource. The gut.p census is kept - it
	# is still useful for eyeballing a run - but the pass/fail now rides on the counts it prints,
	# not only on the mod being active.
	for index_name:StringName in OUR_INDEXES:
		var count:int = ModResources.our_paths_in(MOD_ID, index_name).size()
		gut.p('  %-10s %d' % [index_name, count])
		assert_gt(count, 0, '%s has at least one of ours in the %s index.' % [MOD_ID, index_name])

## An icon has to exist AND not be a stand-in. Shared by the kit, action and buff guards.
func _assert_real_icon(icon:Texture2D, label:String) -> void:
	assert_not_null(icon, '%s has an icon.' % label)
	if icon == null: return
	assert_false(icon.resource_path.contains('placeholder'),
		'%s does not wear the placeholder icon.' % label)
