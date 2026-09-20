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
const EXPECTED_VERSION := '0.7.0'

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

# ---------------------------------------------------------------- the Maiden's Blush's SP2 rows
#
# SP1 gave each of its three traits (Rend, Uncertainty Field, Fade Strike) a row-resolution guard in
# its own spec file - test_rend.test_the_effect_row_resolves and its siblings. SP2 added fourteen more
# rows (the core system, Step of Mist and Thunder, Abjuration of Metal, and the shared Efficient
# refund log) and NONE of them had one: grepping X.tr(/Translate. across every SP2 spec file returns
# zero hits (frame close review slice 5, finding I-2). Six of these fourteen reach the player through
# a call that silently falls back to the raw key on a miss (battle_log_bus.gd:24-27's log_tr, and
# Translate.action's default return_key_if_blank=true), so a dropped CSV row or a stale compiled
# localizations.en.translation puts a raw key straight into the battle log and floating over the
# board, with every other test in the suite green.
#
# Housed here rather than split across the SP2 spec files: this mod's SP2 core power spans two action
# scripts and a standalone buff with no single natural home for a shared list, and this file already
# owns the mod-wide localization guards (the glossary tests above).

## The fourteen rows SP2 added with no resolution guard, transcribed from
## localization/localizations.csv:176-189.
const SP2_LOCALIZATION_ROWS:Array[String] = [
	'gear.cp_caj_overhaul_modules.name',
	'gear.shared.efficient.refund.log',
	'gear.cp_caj_overhaul_modules.action_step_of_mist_and_thunder.name',
	'gear.cp_caj_overhaul_modules.action_step_of_mist_and_thunder.effect',
	'gear.cp_caj_overhaul_modules.action_step_of_mist_and_thunder.confirm',
	'gear.cp_caj_overhaul_modules.action_step_of_mist_and_thunder.snake_eyes.log',
	'gear.cp_caj_overhaul_modules.action_step_of_mist_and_thunder.snake_eyes.pop',
	'gear.cp_caj_overhaul_modules.action_step_of_mist_and_thunder.fizzle.log',
	'gear.buff_mist_and_thunder_invisible.name',
	'gear.buff_mist_and_thunder_invisible.effect',
	'gear.cp_caj_overhaul_modules.action_abjuration_of_metal.name',
	'gear.cp_caj_overhaul_modules.action_abjuration_of_metal.trigger',
	'gear.cp_caj_overhaul_modules.action_abjuration_of_metal.effect',
	'gear.cp_caj_overhaul_modules.action_abjuration_of_metal.no_space.log',
]

func test_the_maidens_blush_sp2_rows_resolve():
	for key:String in SP2_LOCALIZATION_ROWS:
		assert_ne(tr(key), key, '%s resolves to real text.' % key)

## The four rows the 2026-09-17 reach sub-project added for Abjuration's CONSOLATION fade. Same guard
## as SP2's list above and for the same reason: two are read through Translate.action (which defaults
## return_key_if_blank = true) and two through a literal battle-log key, so a dropped CSV row or a
## stale localizations.en.translation artifact puts the raw key in front of the player with every
## behavioural test in this mod still green.
const REACH_LOCALIZATION_ROWS:Array[String] = [
	'gear.mt_uncertainty_field.action_uncertainty_field.consolation.no_space.confirm',
	'gear.mt_uncertainty_field.action_uncertainty_field.consolation.cancelled.confirm',
	'gear.mt_uncertainty_field.action_uncertainty_field.consolation.no_space.log',
	'gear.mt_uncertainty_field.action_uncertainty_field.consolation.cancelled.log',
]

func test_the_maidens_blush_consolation_rows_resolve():
	for key:String in REACH_LOCALIZATION_ROWS:
		assert_ne(tr(key), key, '%s resolves to real text.' % key)

## The two Vauban rows no behavioural spec can falsify, housed here for the same reason as the two
## lists above (frame close review slice 5, M-2 and I-1).
##
## The frame's other rows are guarded where they are used - test_vauban_frame.gd:180-188,
## test_solfataric_breach.gd:238-242, test_sap.gd:277-279, test_gravity_well.gd:127-128,
## test_grav_amped_interference.gd:93-99, test_mastication_of_the_maar.gd:136-140. These two cannot be:
##
## - `gear.mt_maar_terrain.name` belongs to a MARKER's trait Kit, and no surface a spec in this mod can
##   reach renders its card at all.
## - `gear.buff_grav_amped_saves.name` is the same string as the protocol's own name row - one card,
##   one name - so the chip's name_text() renders identically whether it reads its own row or falls
##   through to the protocol's (translate.gd:73-76). An assertion on the rendered text could never
##   fail; an assertion that the row RESOLVES can.
const VAUBAN_LOCALIZATION_ROWS:Array[String] = [
	'gear.mt_maar_terrain.name',
	'gear.buff_grav_amped_saves.name',
]

func test_the_vaubans_unguarded_rows_resolve():
	for key:String in VAUBAN_LOCALIZATION_ROWS:
		assert_ne(tr(key), key, '%s resolves to real text.' % key)

## The Rend Axe's three rows (SP2 Task 1, Primrose). Unlike the three lists above, these ARE also
## guarded where they are used - test_rend_axe.gd's test_the_name_and_flavour_and_effect_resolve
## reads the same keys off this mod's own compiled artifact - so this entry is belt-and-braces
## consistency with the per-sub-project pattern this file keeps, not the last line of defence for an
## unreachable row the way the Vauban pair above is.
const REND_AXE_LOCALIZATION_ROWS:Array[String] = [
	'gear.mw_rend_axe.name',
	'gear.mw_rend_axe.flavor',
	'gear.mw_rend_axe.action_rend_axe.effect',
	# SP2 Task 2, the FREE profile's two rows. The .name row is NOT decoration and has no sibling on
	# action_rend_axe: an action with no name row of its own falls through to the Kit's
	# (translate.gd:73-76), which is right for the ordinary swing - one card, one name - and wrong the
	# moment there are two buttons, because both would then read "Rend Axe". Vanilla-adjacent
	# precedent in this same file: gear.mw_bizarre_cannon.action_more_black_powder.name is
	# "Bizarre Cannon (More Black Powder)" for exactly this reason.
	'gear.mw_rend_axe.action_rend_axe_free.name',
	'gear.mw_rend_axe.action_rend_axe_free.effect',
]

func test_the_rend_axes_rows_resolve():
	for key:String in REND_AXE_LOCALIZATION_ROWS:
		assert_ne(tr(key), key, '%s resolves to real text.' % key)

## Dazzling Wind's four rows (SP2 Task 3, Primrose). Same belt-and-braces reasoning as the Rend Axe's
## list above - test_leap.gd's test_the_card_text_resolves reads the identical keys through the
## global tr(), so this entry is consistency with the per-sub-project pattern this file keeps, not
## the only guard on an otherwise-unreachable row.
const DAZZLING_WIND_LOCALIZATION_ROWS:Array[String] = [
	'gear.ms_dazzling_wind.name',
	'gear.ms_dazzling_wind.flavor',
	'gear.ms_dazzling_wind.action_leap.name',
	'gear.ms_dazzling_wind.action_leap.effect',
]

func test_the_dazzling_winds_rows_resolve():
	for key:String in DAZZLING_WIND_LOCALIZATION_ROWS:
		assert_ne(tr(key), key, '%s resolves to real text.' % key)

## Every kit this mod ships, and the actions on each kit that reach a player-facing surface, each
## naming the GLYPH FAMILY it belongs to. Filled in by each sub-project as it builds content; the
## icon pass is what makes it green.
##
## Shape: kit id => { action id => family }. A kit whose only action is the kit itself lists that
## action as KIT. A kit with no player-facing action of its own lists none.
##
## A family is a set of rows that wear ONE texture. KIT means "inherit the Kit's glyph and carry no
## icon_override at all"; any other name means "carry this family's texture", and the same name
## anywhere in this table - including on another Kit - must resolve to the identical texture. That
## is what pins cp_broadside's protocol to the charged profile on mw_bizarre_cannon.
##
## Rule and rationale: specs/2026-09-18-icon-sharing-design.md section 3. Vanilla's reference shape
## is cp_m35_mjolnir_cannon: {Kit, action_m35_mjolnir} and {action_thunder_god,
## action_thunder_god_chamber_rounds, buff_thunder_god}, the second a _spin_up variant of the first.

## A row whose family is KIT carries no icon_override and inherits its Kit's glyph through
## Action.get_icon(kit) (action.gd:324-326 -> kit.gd:209). Banned for an action carried by more
## than one Kit: action.gd:58 caches the resolution on the shared Action instance.
const KIT := &'__kit__'
const ICON_TARGETS := {
	&'mt_weak_computer': {}, # its only action is the kit itself
	# The protocol's own row. It shares a glyph family with the charged weapon profile it unlocks
	# (action_more_black_powder, on mw_bizarre_cannon below) - pressing the protocol visibly swaps
	# that profile in, so the two wear the identical texture. The base profile inherits its own
	# Kit's glyph directly (a KIT row below) rather than sharing a named family.
	&'cp_broadside': {&'action_more_black_powder_protocol': &'action_more_black_powder'},
	# The two CANNON PROFILES moved to their own Kit at the frame close, so the character sheet
	# titles the integrated-weapon box "Bizarre Cannon" instead of "Broadside"
	# (weapon_mount_item.gd:101 reads the KIT's name). See test_integrated_weapon_names.gd.
	# action_bizarre_cannon is the Kit's own base profile and wore action_bizarre_cannon.svg a
	# second time via its own icon_override - one texture written twice under a family name equal
	# to itself. Retrofitted to KIT (icon-sharing.md section 5: KIT is absence, not duplication):
	# it now carries no icon_override at all and inherits the Kit's glyph through the engine
	# fallback. action_more_black_powder stays a named family - it spans this Kit and cp_broadside.
	&'mw_bizarre_cannon': {&'action_bizarre_cannon': KIT, &'action_more_black_powder': &'action_more_black_powder'},
	&'mt_hole_puncher': {}, # a passive trait: no action of its own, so it wears the Kit's icon
	&'mt_knock_em_down': {}, # a passive trait: no action of its own, so it wears the Kit's icon
	# Its one action (action_blasting_powder_spend) is a hidden bookkeeping reaction: reactions never
	# reach the gear bar (gear_bar.gd:145) and it overrides show_in_tooltip to false, so nothing the
	# player sees ever wears an icon for it. The Kit's own icon still has to be real.
	&'mt_blasting_powder': {},
	# SP2 Task 1. A weapon Kit, not a trait: its SINGLE SHOT profile is a separately pressable button
	# on the gear bar, so it wears its own icon rather than sharing the Kit's - same reasoning as
	# cp_broadside's three entries. Task 2 adds GRAPESHOT here for the same reason: a second,
	# separately pressable profile on the same Kit. (Task 3's hidden reload reaction gets no row, for
	# the mt_blasting_powder reason above.)
	&'mw_breech_loading_swivel_gun': {&'action_swivel_single_shot': &'action_swivel_single_shot', &'action_swivel_grapeshot': &'action_swivel_grapeshot'},
	# SP2 Task 4. Its one action (action_heaer_detonate) is a hidden bookkeeping reaction: reactions
	# never reach the gear bar (gear_bar.gd:145) and it overrides show_in_tooltip to false, so nothing
	# the player sees ever wears an icon for it. The Kit's own icon still has to be real - the system
	# is equippable, and sits in the loadout like any other.
	&'ms_heaer': {},
	# SP3 Task 1. Unlike ms_heaer, this system's one action is a QUICK the player presses on the gear
	# bar, so it wears its own icon rather than sharing the Kit's - vanilla's ms_ramjet is the shape
	# (its Kit carries no icon_override at all and its single action carries one). This mod's own
	# guard is stricter and wants both, which is SP5's job.
	&'ms_hull_break_thrusters': {&'action_full_speed_ahead': &'action_full_speed_ahead'},
	# SP3 Task 3. A weapon mod: no actions at all, so nothing but the Kit's own icon is ever shown -
	# it appears in the weapon-mod dropdown and on the modded weapon's card.
	&'wm_ripper_mod': {},
	# SP4 Task 1. A weapon Kit with a single profile, and that profile still earns its own row: it is
	# a separately pressable button on the gear bar, exactly the mw_breech_loading_swivel_gun
	# reasoning. Having only one profile does not merge the button into the Kit - the gear bar draws
	# the action, and an action with no icon_override does NOT fall back to a generic - it inherits
	# the Kit's glyph (action.gd:324-326, proved by the Task 0 probe of the icon-glyph-families
	# plan) - which is exactly what a KIT row now relies on.
	&'mw_rapier_class_carronade': {&'action_rapier_carronade': &'action_rapier_carronade'},
	# SP4 Task 3. A system whose one action is a QUICK the player presses on the gear bar, so it wears
	# its own icon as well as the Kit's - the ms_hull_break_thrusters reasoning exactly, not the
	# ms_heaer one (HEAER's only action is a hidden reaction that never reaches the gear bar).
	&'ms_grit_latch_magnets': {&'action_reinforcement_blast': &'action_reinforcement_blast'},
	# SP1 Task 1 (M/K2). A 1/scene trait whose single FREE action is a separately pressable button on
	# the gear bar, so it wears its own icon as well as the Kit's - the ms_hull_break_thrusters
	# reasoning, not the ms_heaer one.
	&'mt_rapid_stabilization_jets': {&'action_rapid_stabilization_jets': KIT},
	# SP1 Task 2 (M/K2). A pure passive: no action of its own, so it wears the Kit's icon.
	&'mt_hybridized_shot': {},
	# SP1 Task 3 (M/K2). The core system, one pressable protocol - cp_broadside's shape with one
	# button instead of three.
	&'cp_auxiliary_power_rerouter': {&'action_ors_hypercharge': &'action_ors_hypercharge'},
	# SP1 Task 4 (Subutai). Its one action is an end_turn reaction, and reactions never reach the
	# gear bar (gear_bar.gd:145) - but unlike mt_blasting_powder's and ms_heaer's hidden bookkeeping
	# reactions, this one does NOT override show_in_tooltip, so it is drawn on the trait card with
	# its own row. It therefore earns its own icon as well as the Kit's.
	&'mt_juggernaut_drive': {&'action_juggernaut_drive': KIT},
	# SP1 Task 2 (Subutai). A pure passive: no action of its own, so it wears the Kit's icon. Its
	# BuffResistDamage is an inline SubResource and carries hide_from_player, so it is correctly
	# absent from VISIBLE_BUFFS - it is never a chip on the unit.
	&'mt_reinforced_chassis': {},
	# SP2 Task 1 (Subutai). The core system. GATHER ROUND is a PROTOCOL the player presses on the
	# gear bar, so it wears its own icon as well as the Kit's - cp_auxiliary_power_rerouter's shape.
	# Task 2 appends action_diversion_rail (a pressable weapon profile) and Task 3 action_draw_fire
	# (a reaction that never reaches the gear bar, but does not override show_in_tooltip, so it is
	# drawn on the trait card with its own row - the mt_juggernaut_drive reasoning).
	&'cp_siege_engine': {&'action_gather_round': &'action_gather_round', &'action_draw_fire': &'action_draw_fire'},
	# The Rail is its OWN Kit since the frame close, so the character sheet can title the
	# integrated-weapon box "Diversion Rail" instead of "Siege Engine"
	# (weapon_mount_item.gd:101 reads the KIT's name). See test_integrated_weapon_names.gd.
	&'mw_diversion_rail': {&'action_diversion_rail': KIT},
	# SP1 Task 3 (Myconid). Pure passives: a Gaze-shaped PassiveStatIncrease and a
	# PassiveBuffApplicator carrying THREE hidden bookkeeping buffs since SP2.5 Task 1 (the third
	# relieves a non-consuming reaction's per-round cap). No actions at all, so it wears the Kit's
	# icon and lists none. All three set hide_from_player and are correctly absent from
	# VISIBLE_BUFFS - none is ever a chip on the unit.
	&'mt_symbiosis': {},
	# SP1 Task 5 (Myconid). Its one action (action_halo) is a hidden reaction: reactions never reach
	# the gear bar (gear_bar.gd:145) and it overrides show_in_tooltip to false, so nothing the player
	# sees ever wears an icon for it - the ms_heaer shape, not the mt_juggernaut_drive one. The Kit's
	# own icon still has to be real.
	&'mt_halo': {},
	# SP2 Task 3 (Myconid). The core system. FUNGAL NETWORK is a PROTOCOL the player presses on the
	# gear bar, so it wears its own icon as well as the Kit's - cp_siege_engine's and
	# cp_auxiliary_power_rerouter's shape. The Kit's FOUR passives - three PassiveAuras (SP2.5 Task 4
	# added passive_fungal_network_self) and one PassiveDynamicZone drawing the ground cloud (SP2.5
	# Task 5, passive_fungal_network_zone) - wear nothing: Passive.get_icon exists (passive.gd:20-22)
	# but nothing player-facing reads it for these, and the zone's picture is a reused VANILLA fx
	# scene, so SP3 has no art to draw for it. The chip the third aura applies
	# does, and the author's instruction is that it SHARES this Kit's icon rather than getting one of
	# its own. That sharing is the ENGINE'S DEFAULT and needs no property: BuffCore.get_icon falls
	# back to the owner gear's Kit icon when the Buff has none (buff_core.gd:81-86), and the chip's
	# owner gear is this Kit. SP3 still has to set the field, because the visible-buff guard reads it
	# raw (:398). See buff_fungal_network_active.tres, and VISIBLE_BUFFS below.
	#
	# The Pike is deliberately NOT here: it is its own mw_ Kit (ruling 9), listed separately when
	# SP2 Task 4 lands, because weapon_mount_item.gd:101 titles the character sheet's
	# integrated-weapon box from the KIT that holds the weapon action.
	&'cp_quietus_machines': {&'action_fungal_network': &'action_fungal_network'},
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
	# not the strike's. The strike's real icon does not have to be a real icon_override of its
	# own, though - it wore mw_psychopomp_fold_pike.svg a second time via its own icon_override,
	# the same file the Kit already wears, so it is a KIT row (icon-sharing.md section 5): no
	# icon_override at all, inheriting the Kit's glyph through the engine fallback. The Gyre keeps
	# its own family - a genuinely different picture for a genuinely different action.
	&'mw_psychopomp_fold_pike': {&'action_psychopomp_strike': KIT, &'action_uffish_gyre': &'action_uffish_gyre'},
	# SP1 Task 3 (Maiden's Blush). A pure passive: no action of its own, so it wears the Kit's icon
	# and lists none. Its buff_rend sets hide_from_player and is correctly absent from VISIBLE_BUFFS -
	# it is never a chip on the unit. The Kit's own icon is SP3's, so this row is one of the two that
	# make test_every_player_facing_kit_and_action_has_a_real_icon deliberately red until then.
	&'mt_rend': {},
	# SP1 Task 4 (Maiden's Blush). ITS ONE ACTION GETS NO ROW, and that is an engine consequence
	# rather than a choice: Action.show_in_tooltip (action.gd:350-353) returns false when the action's
	# own `effect` row equals the KIT's generic one, and ruling 17 makes them identical - the reaction
	# row repeats the card text verbatim. The Kit also has no `trigger` row, which is the clause
	# (action.gd:344) that would otherwise force a true. So the reaction never reaches the trait card,
	# never reaches the gear bar (reactions never do, gear_bar.gd:145), and wears no icon of its own -
	# the ms_heaer shape, not the mt_juggernaut_drive one. This CORRECTS design §1.5, which expected a
	# row here; test_uncertainty_field.test_the_rows_resolve_and_the_reaction_stays_off_the_trait_card
	# pins the engine's answer, and the two move together if the localisation ever changes.
	#
	# Its buff_uncertainty_field_break sets hide_from_player and is correctly absent from
	# VISIBLE_BUFFS. The Kit's own icon is SP3's.
	&'mt_uncertainty_field': {},
	# SP1 Task 5 (Maiden's Blush). A pure passive with NO action at all, so it wears the Kit's icon
	# and lists none. Its two buffs split: buff_fade_strike_arm is hidden bookkeeping and is correctly
	# absent from VISIBLE_BUFFS, while buff_fade_strike is the visible chip and is listed there.
	&'mt_fade_strike': {},
	# SP2 Task 3 (Maiden's Blush). The CORE SYSTEM, and EMPTY FOR NOW rather than empty on principle -
	# Step of Mist and Thunder (Task 4) and Abjuration of Metal (Task 5) both belong here and both
	# arrive with their own tasks. Unlike mt_uncertainty_field above, THOSE TWO ARE NOT `[]`: each has
	# an `.effect` row of its own and Abjuration a `.trigger` row too, while this Kit has no `.effect`
	# at all (the LCP's core description is empty, ruling 17), so the action.gd:352 clause that hides a
	# trait reaction whose effect equals its Kit's cannot fire for either of them.
	#
	# action_efficient_refund, the shared Efficient reaction, is deliberately ABSENT: it overrides
	# show_in_tooltip to false, so the reverse check below computes "should not be listed" and listing
	# it would fail. The player reads "Efficient" in the core power's own effect text, where the card
	# puts it.
	#
	# action_step_of_mist_and_thunder wore cp_caj_overhaul_modules.svg a second time via its own
	# icon_override - the same file the Kit already wears - under a family name that was just the
	# Kit's own id. Retrofitted to KIT (icon-sharing.md section 5): no icon_override of its own,
	# inheriting the Kit's glyph through the engine fallback. action_abjuration_of_metal keeps its
	# own family - it wears an unrelated glyph, a genuinely different picture.
	&'cp_caj_overhaul_modules': {&'action_step_of_mist_and_thunder': KIT, &'action_abjuration_of_metal': &'action_abjuration_of_metal'},
	# SP1 Task 3 (Vauban). ITS ONE ACTION EARNS A ROW, unlike the Maiden's Blush's Uncertainty Field,
	# and the difference is the localisation rather than the .tres. Action.show_in_tooltip
	# (action.gd:350-353) returns false when an action's own `effect` row equals the KIT's generic
	# one; here the Kit says "Gain the Solfataric Breach reaction" and the action says what it does,
	# so the trait card draws a separate reaction row and that row wears its own icon - the
	# mt_juggernaut_drive / action_draw_fire shape, not the ms_heaer one.
	#
	# NOTE WHICH CLAUSE IS NOT DOING THE WORK: the `.trigger` row is keyed on the ACTION, and
	# show_in_tooltip's trigger clause (action.gd:344) reads the KIT's own `gear.<kit>.trigger` key,
	# which this mod does not write. Same distinction the Gyre's row records.
	#
	# The Kit's icon and the action's are both SP3's, so this row is what makes
	# test_every_player_facing_kit_and_action_has_a_real_icon deliberately red until then.
	&'mt_solfataric_breach': {&'action_solfataric_breach': KIT},
	# SP1 Task 4 (Vauban). ITS ONE ACTION GETS NO ROW, for two independent reasons and by design.
	# action_sap.gd overrides show_in_tooltip to false outright (design §1.4, the Poisoned Soil
	# lesson) - and even without that, Action.show_in_tooltip (action.gd:350-353) returns false when
	# an action's own `effect` row equals the KIT's generic one, which the localisation makes true
	# here. Reactions never reach the gear bar either (gear_bar.gd:145), so nothing the player sees
	# ever wears an icon for it: the ms_heaer / mt_uncertainty_field shape, not the
	# mt_solfataric_breach one. Its buff_sap_reprieve is hidden and is correctly absent from
	# VISIBLE_BUFFS. The Kit's own icon is SP3's.
	&'mt_sap': {},
	# SP1 Task 5 (Vauban). A pure passive: no action of its own, so it wears the Kit's icon and lists
	# none. Its one buff, buff_gravity_well, is VISIBLE and is listed in VISIBLE_BUFFS below. The
	# Kit's own icon is SP3's.
	&'mt_gravity_well': {},
	# EARTH SHAKER GRAV-GEN, the core system (SP2). Its two PRESSABLE actions each reach the gear bar
	# and each needs its own icon; action_grav_amped_shock does not - it is a reaction with
	# show_in_tooltip false, the mt_sap shape. All of these are SP3's.
	&'cp_earth_shaker_grav_gen': {&'action_grav_amped_interference': &'action_grav_amped_interference', &'action_mastication_of_the_maar': &'action_mastication_of_the_maar'},
	# SP2 Task 4 (Vauban). The Maar's own trait, on the deployable frame dep_maar rather than on the
	# mech. It carries one terrain zone and no actions at all, so there is nothing here to illustrate
	# beyond the Kit's own icon, which is SP3's - the mt_gravity_well shape.
	&'mt_maar_terrain': {},
	# SP1 Task 2 (Primrose). A pure passive trait: no action of its own, so it wears the Kit's icon
	# and lists none - the mt_knock_em_down shape it is copied from. Its
	# buff_magnetic_weight_redistribution sets hide_from_player and is correctly absent from
	# VISIBLE_BUFFS; it is trait plumbing, never a chip on the unit, and nothing draws it.
	#
	# The Kit's own icon is SP5's, so THIS ROW is what makes
	# test_every_player_facing_kit_and_action_has_a_real_icon deliberately red until then - it is the
	# first new Kit of the sub-project.
	&'mt_magnetic_weight_redistribution': {},
	# SP1 Task 3 (Primrose). A pure passive trait with no script at all: no action of its own, so it
	# wears the Kit's icon and lists none. Its buff_artful_caress sets hide_from_player and is
	# correctly absent from VISIBLE_BUFFS - a THREAT_RANGE bonus is read by
	# ActionAttackWeapon.threat_distance and drawn nowhere, so it is not in
	# HIDDEN_BUFFS_NEEDING_ICONS either (unlike an ATTACK_ROLL_INCOMING chip, which
	# attack_roll.gd:189 draws with its raw icon). The Kit's own icon is SP5's.
	&'mt_artful_caress': {},
	# SP1 Task 4 and Task 5 (Primrose). MÖBIAN RAINBOW, the core system. GLIMMERING ARMAMENTS is a
	# PROTOCOL the player presses on the gear bar, so it wears its own icon as well as the Kit's -
	# cp_auxiliary_power_rerouter's and cp_quietus_machines' shape, not the ms_heaer one. Both icons
	# are SP5's.
	#
	# A NAMED FAMILY rather than KIT, because the two glyphs are genuinely different pictures: the Kit
	# is the coating and the protocol is the choice it offers. A KIT row would say they are the same
	# drawing, which the icon pass would then have to honour.
	&'cp_mobian_rainbow': {&'action_glimmering_armaments': &'action_glimmering_armaments'},
	# SP2 Task 1 (Primrose). The Rend Axe. Its attack profile is a separately pressable button on the
	# gear bar, so it needs a row - but it takes a KIT row rather than a named family, because the
	# family the design gives this weapon (design §5) is {the Kit, both attack actions}: one glyph, an
	# axe, worn by the weapon and by every way of swinging it. icon-sharing.md section 5 - KIT is
	# absence, not duplication - so the action carries NO icon_override and inherits through
	# action.gd:324-326. Task 2 adds the free profile to this same row, also KIT.
	# The Kit's own icon is SP5's, which is what makes this row deliberately red until then.
	#
	# SP2 Task 2 added action_rend_axe_free. It is a SECOND pressable button on the gear bar - the
	# card's free swing - so it needs a row of its own, and it is KIT for the same reason its sibling
	# is: the design's family for this weapon is {the Kit, both attack actions}, one axe glyph worn by
	# every way of swinging it. Note the free profile carries hide_if_disabled, which removes the
	# button at 0 charges rather than greying it - that is per-instance runtime state, not a fixed
	# shape, so _action_reaches_a_player_facing_surface deliberately has no clause for it and the row
	# is required regardless (the same reasoning gear_bar.gd:141-156 gets in that helper's header).
	&'mw_rend_axe': {&'action_rend_axe': KIT, &'action_rend_axe_free': KIT},
	# SP2 Task 3 (Primrose). Dazzling Wind. Its one action is a QUICK the player presses on the gear
	# bar, so it needs a row - and it is a KIT row for the same reason the Rend Axe's are: the design
	# gives this system ONE glyph family, {the Kit, action_leap}. vanilla's ms_ramjet is the other
	# shape (Kit bare, action carrying the icon) and is deliberately NOT what this is. The Kit's icon
	# is SP5's, which is what makes this row deliberately red until then.
	&'ms_dazzling_wind': {&'action_leap': KIT},
	# SP3 Task 1 (Primrose). The Falcata's one attack profile is the only thing the gear bar draws
	# for this Kit, so it inherits the Kit's glyph and carries no icon_override of its own - the same
	# mw_rend_axe / ms_dazzling_wind KIT shape immediately above.
	#
	# CORRECTED FROM THE PLAN'S DRAFT, which cited "the ms_ramjet shape" for this row. ms_ramjet is
	# the OPPOSITE pattern, documented at :337-339 above: "its Kit carries no icon_override at all
	# and its single action carries one" - a bare Kit plus a NAMED family on the action, not a KIT
	# row. Citing it here would have pointed a later reader at the wrong precedent for what this row
	# actually does. The Kit's own icon is SP5's, which is what makes this row deliberately red until
	# then, same as its two rank-I siblings. action_biting_retort earns its own family in Task 2.
	#
	# SP3 Task 2 added action_biting_retort, and it takes a NAMED family rather than a KIT row - the
	# cp_mobian_rainbow shape, not the mw_rend_axe one. The two glyphs are different pictures: the Kit
	# is the sword, the reaction is the cross-guard cannon answering a swing. A KIT row would say they
	# are the same drawing, which the SP5 icon pass would then have to honour.
	#
	# IT NEEDS A ROW AT ALL BECAUSE Action.show_in_tooltip(kit) ANSWERS TRUE FOR IT, which is the third
	# clause of _action_reaches_a_player_facing_surface below (a reaction never reaches the gear bar,
	# and this one is not the Kit's first weapon action, so that clause is the only one that can list
	# it). MEASURED, not assumed: spec/test_biting_retort.gd's
	# test_the_reaction_is_drawn_on_the_weapons_card calls the same function. The deciding clause is
	# action.gd:350-353 - the reaction has an `effect` row of its own, different from the Kit's - and
	# it is exactly the clause the Maiden's Blush's mt_uncertainty_field FAILS, which is why that Kit's
	# row two hundred lines above is `{}` while this one is not.
	&'mw_acrasial_falcata': {&'action_acrasial_falcata': KIT, &'action_biting_retort': &'action_biting_retort'},
	# SP3 Task 4 (Primrose). A weapon mod: no actions at all, so nothing but the Kit's own icon is
	# ever shown - it appears in the weapon-mod dropdown and on the modded weapon's card. The
	# wm_ripper_mod shape (:343 above). The Kit's own icon is SP5's, so this row is what makes
	# test_every_player_facing_kit_and_action_has_a_real_icon deliberately red until then.
	&'wm_ddmr': {},
	# SP4 Task 1 (Primrose). The Eternity Hammer, rank III. Its one attack profile is the only thing
	# the gear bar draws for this Kit, so it needs a row - and it is a KIT row, not a named family,
	# because design §5 (specs/2026-09-19-primrose-design.md:529) gives this weapon ONE glyph family,
	# {mw_eternity_hammer} - the mw_rend_axe / mw_acrasial_falcata shape immediately above, not the
	# ms_ramjet one (a bare Kit with the action carrying a NAMED icon of its own). icon-sharing.md
	# section 5 - KIT is absence, not duplication - so the action carries NO icon_override and
	# inherits through action.gd:324-326. The Kit's own icon is SP5's, which is what makes this row
	# deliberately red until then, same as every other rank-III-or-earlier weapon row above it.
	&'mw_eternity_hammer': {&'action_eternity_hammer': KIT},
	# SP4 Task 3 (Primrose). Flourishing Twirl, rank III. Its one action (Spin) is a QUICK the player
	# presses on the gear bar, so it needs a row - and it is a KIT row for the same reason Dazzling
	# Wind's is: design §5 gives this system ONE glyph family, {ms_flourishing_twirl, action_spin}
	# (specs/2026-09-19-primrose-design.md:529). vanilla's ms_ramjet is the other shape (Kit bare,
	# action carrying the icon) and is deliberately NOT what this is - the ms_dazzling_wind precedent
	# above is. The Kit's icon is SP5's, which is what makes this row deliberately red until then.
	&'ms_flourishing_twirl': {&'action_spin': KIT},
	# SP1 Task 2 (Sluagh). A pure passive trait: no action of its own, so it wears the Kit's icon and
	# lists none - the mt_knock_em_down / mt_magnetic_weight_redistribution shape. Its two buffs are
	# buff_wicked_host_watch (hidden plumbing, drawn nowhere, correctly absent from both buff tables)
	# and buff_wicked_host, which IS visible and is listed in VISIBLE_BUFFS below.
	#
	# The Kit's own icon is SP5's, so THIS ROW is what makes
	# test_every_player_facing_kit_and_action_has_a_real_icon deliberately red until then - it is the
	# first new Kit of the sub-project.
	&'mt_wicked_host': {},
	# SP1 Task 3 (Sluagh). One action, and it is a HIDDEN reaction: show_in_tooltip is overridden to
	# false and reactions never reach the gear bar (gear_bar.gd:145), so nothing the player sees ever
	# wears an icon for it and it correctly gets no row inside this dictionary - the mt_blasting_powder
	# / mt_halo / mt_sap shape. The Kit's own icon is SP5's.
	&'mt_the_stealing_of_the_souls_of_the_dead': {},
	# SP1 Task 5 (Sluagh). A pure passive trait: no action of its own, so it wears the Kit's icon and
	# lists none - the mt_gravity_well shape. Its one buff, buff_inexorable_formation, is HIDDEN and
	# is correctly absent from BOTH buff tables: nothing draws a Buff.TO.STATBLOCK buff, because
	# update_cached_values asks it for get_values() and never for an icon
	# (unit_battle_state.gd:231-234). The Kit's own icon is SP5's.
	&'mt_inexorable_formation': {},
	# SP1 Tasks 6, 7 and 8 (Sluagh). CRY OF THE HOSTED DEAD, the core system. THREE actions by the
	# end of SP1 and only SOME of them belong in the value map:
	#  - action_astral_guardian (Task 6) is a reaction with show_in_tooltip false, so it reaches no
	#    player-facing surface and is correctly ABSENT - the mt_halo / ms_heaer shape. This retires
	#    design section 5's {Kit, action_astral_guardian} glyph family: the Kit's glyph is the whole
	#    of it.
	#  - action_mark_of_the_dead (Task 7) is a QUICK action on the gear bar and gets its own glyph.
	#  - action_mark_retort (Task 8) is a reaction that DOES reach the trait card, because it has its
	#    own effect row and show_in_tooltip is not overridden (action.gd:350-353) - the
	#    action_draw_fire / action_uffish_gyre shape.
	# Every icon here is SP5's, so this row is part of what keeps
	# test_every_player_facing_kit_and_action_has_a_real_icon red until then.
	# TWO FAMILIES ON ONE KIT, so SP5 must give them genuinely different drawings or collapse them
	# into one family name here: the guard refuses two families on a Kit wearing the same texture
	# (the claimed/texture_by_family loop below), because the gear bar would draw them as one button.
	# Design section 5 currently groups the Mark, its chip, the soft-cover chip and the retort as ONE
	# glyph family, so that is a decision SP5 owes - flagged here rather than pre-empted.
	&'cp_cry_of_the_hosted_dead': {&'action_mark_of_the_dead': &'action_mark_of_the_dead', &'action_mark_retort': &'action_mark_retort'},
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
	# SP2.5 Task 4 (Myconid). The Myconid's own chip, and the only buff in this mod that is visible
	# and NOTHING else - no `to`, no statuses, no triggers. It exists to be drawn: after playtesting,
	# the author asked for a way to tell at a glance that FUNGAL NETWORK is running, and the Myconid
	# was the one unit in its own cloud wearing nothing. Visible is therefore not a choice here the
	# way it is for the three above; hide it and the buff has no reason to exist at all.
	#
	# ITS ICON IS NOT ITS OWN, AND THE ENGINE ALREADY SHARES IT. BuffCore.get_icon falls back to the
	# OWNER GEAR'S KIT icon when the Buff declares none (buff_core.gd:81-86), and this chip's owner
	# gear is cp_quietus_machines - so "shares icon with the core power" is what the game does today,
	# with no property set at all. What SP3 is satisfying here is a GUARD, not the behaviour: the
	# assertion below reads `buff.icon` RAW (:398), never Buff.get_icon(), so the fallback is
	# invisible to it and a null field fails the row however the chip actually draws. Give it the
	# same glyph as cp_quietus_machines rather than a new one; this guard checks only that the
	# Texture2D is non-null and non-placeholder and does not care whether two entries point at one
	# file.
	&'buff_fungal_network_active',
	# SP2 Task 4 (Myconid). The Gyre's on-hit chip - the reaction fires on somebody ELSE's turn, so
	# this chip is the only on-map signal the mover gets that the Pike's strike landed. Same
	# reasoning as buff_reinforcement_blast and buff_fungal_network_armor above:
	# buff_uffish_gyre_armor_reduction is the hidden half that does the actual damage reduction and
	# is deliberately ABSENT - the pair is one mechanic, and two chips for one effect would read as
	# two.
	&'buff_uffish_gyre_armor',
	# SP1 Task 5 (Maiden's Blush). The reroll chip, and it is deliberately player-visible: the trait
	# fires with no animation of its own, so the chip is the only signal on the board that the Blush
	# began its turn Invisible and still has its reroll in hand. Its hidden sibling
	# buff_fade_strike_arm is NOT listed - the pair is one mechanic, and the arming half is never a
	# chip on the unit.
	&'buff_fade_strike',
	# SP2 Task 4 (Maiden's Blush). The chip a character wears after failing Step of Mist and Thunder's
	# Systems save, and visible for the same reason buff_diversion_rail is: it is the holder's ONLY
	# warning that it is now missing the Blush on a d6 of 3 or less. The save is rolled on the Blush's
	# turn and the consequence lands on every attack the holder makes afterwards, with nothing else on
	# the board to explain it - and unlike most chips here it lasts the whole scene.
	&'buff_mist_and_thunder_invisible',
	# SP1 Task 5 (Vauban). Gravity Well's chip, and visible for two independent reasons.
	# attack_roll.gd:189 passes buff_core.base.icon RAW into the roll breakdown - NOT through
	# Buff.get_icon() - so BuffBonus's difficulty-svg fallback (buff_bonus.gd:34-42) never runs on
	# that path and a null icon draws a blank beside the -1; buff_diversion_rail is listed for exactly
	# that reason. And it is a sheltered ally's only signal that it is being sheltered at all: the
	# trait draws nothing else on the board, and the condition is the VAUBAN's ground rather than the
	# ally's, so there is nothing under the ally's feet to explain it.
	&'buff_gravity_well',
	# SP2 Task 2 (Vauban). The +1 difficulty chip GRAV-AMPED INTERFERENCE hangs on every hostile once
	# the protocol is pressed, per design ruling 11 - the author chose to see it rather than hide it.
	# It is the only on-board signal a hostile gets that its saves are worse. Icon is SP3's.
	&'buff_grav_amped_saves',
	# SP1 Task 4 (Primrose). The Effervescent Immunity chip, and visible because the NUMBER on it is
	# the mechanic: one chip carrying a running count is legible where three stacked chips are not
	# (ruling 6), and it is the only signal on the board that the Primrose is getting harder to hit.
	# Its hidden sibling buff_effervescent_immunity_counter is deliberately ABSENT - the pair is one
	# mechanic, and the observer is never a chip on the unit.
	&'buff_effervescent_immunity',
	# SP1 Task 0 (Primrose), ADOPTED HERE. The probe (spec/test_unit_relation_extension.gd) shipped
	# buff_wormhole_grasp.tres as a BARE visible Buff so the extension had a marker to read, and left
	# this row unwritten - which is why test_every_visible_buff_has_a_real_icon has been red since
	# 62a44a9 for THREE reasons at once: the size count, the missing row, and the null icon. Adopting
	# the row here takes the first two green and leaves exactly one failing assert, so the guard means
	# "no icon yet" and nothing else from now on. Task 5 fills the buff's display fields; it is already
	# a real standalone buff_*.tres and belongs in this list whoever wrote it.
	&'buff_wormhole_grasp',
	# SP1 Task 5 (Primrose). The other armament's marker, visible for the same reason its twin is: the
	# chip is the only thing on the board that says which of the two the pilot chose, and both of them
	# last the whole scene. Its hidden companion buff_shimmering_shield_cover (Task 6) is NOT listed
	# here - the pair is one mechanic, and two chips for one effect would read as two effects; it goes
	# in HIDDEN_BUFFS_NEEDING_ICONS instead, because the roll breakdown draws it.
	&'buff_shimmering_shield',
	# SP3 Task 4 (Primrose). The DDMR's on-hit chip, and visible per ruling 24: named "DDMR" -
	# the mod's own name off the card - and it is the only signal the wearer gets that its next
	# incoming attack is worse. Its sibling buff_ddmr_threat is hidden and correctly absent here -
	# a THREAT_RANGE bonus is read by ActionAttackWeapon.threat_distance and drawn nowhere, same as
	# buff_artful_caress above, so it is not in HIDDEN_BUFFS_NEEDING_ICONS either.
	&'buff_ddmr_aegis',
	# SP1 Task 2 (Sluagh). Wicked Host's +1 difficulty chip, and visible for two independent reasons
	# (ruling 9). attack_roll.gd:189 passes buff_core.base.icon RAW into the roll breakdown - NOT
	# through Buff.get_icon() - so BuffBonus's difficulty-svg fallback (buff_bonus.gd:34-42) never
	# runs on that path and a null icon draws a blank beside the -1; buff_diversion_rail,
	# buff_gravity_well and buff_ddmr_aegis are all listed for exactly that reason. And it is the
	# attacker's only warning that this particular shot is harder. Its hidden sibling
	# buff_wicked_host_watch is deliberately ABSENT - the pair is one mechanic, and the observer is
	# never a chip on the unit.
	&'buff_wicked_host',
	# SP1 Task 7 (Sluagh). The Mark's chip, and visible per ruling 14: it is the only thing on the
	# board that says the dome is up, and the dome lasts the whole scene. Its hidden companion
	# buff_mark_soft_cover is deliberately ABSENT from both tables - the pair is one mechanic, and
	# nothing draws a Buff.TO.COVER buff's own icon anyway: the roll breakdown adds the cover mod
	# with Icon.cover(preattack.cover) (attack_roll.gd:169), never with buff_core.base.icon.
	&'buff_mark_of_the_dead',
]

func test_every_player_facing_kit_and_action_has_a_real_icon():
	# A Kit without icon_override falls back to the generic glyph, which reads as "this gear is
	# unfinished" in the gear bar. An action without icon_override does NOT fall back to a generic -
	# it inherits its Kit's glyph (the KIT family, below) - and only reaches the generic itself if
	# the Kit's own icon_override is missing too. The placeholder check is the other half: an icon
	# pass that wired the stand-in everywhere would otherwise sail through.
	#
	# The subject is the mod's OWN contributions, not ICON_TARGETS, so a kit added without a table
	# row cannot slip past unchecked - that is what the size assertion pins, and it is also what
	# makes this test assert something while the mod is still empty. It reads through
	# testkit/mod_resources.gd rather than ContentLibrary.get_all, which loads every installed mod
	# and fails on a stranger's parse error.
	var kits:Array[Resource] = ModResources.load_ours(MOD_ID, &'kits')
	assert_eq(ICON_TARGETS.size(), kits.size(), 'ICON_TARGETS lists every kit this mod ships.')

	# How many of this mod's Kits carry each Action. A KIT row inherits through
	# Action.icon_from_kit, which action.gd:58 caches on the SHARED Action resource and never
	# invalidates - so an Action on two Kits would show whichever Kit asked first, on BOTH. Vanilla
	# obeys this silently: action_redeploy (9 Kits) and action_takeoff (6) carry their own icons,
	# and every shared action that inherits is hidden bookkeeping that never draws.
	var kits_per_action := {}
	for kit:Kit in kits:
		for action:Action in kit.actions:
			kits_per_action[action.resource_path] = kits_per_action.get(action.resource_path, 0) + 1

	# family name => [texture, the row that first claimed it]. Accumulated across the WHOLE table,
	# so a family can span Kits - which is what pins cp_broadside's protocol to the charged profile
	# on mw_bizarre_cannon.
	var family_texture := {}

	for kit:Kit in kits:
		# The count above is not enough on its own: a stale row for a deleted kit plus a new kit
		# with no row balances it, and `ICON_TARGETS.get(id, {})` would then silently check no
		# actions on the new kit. This is what makes the pairing exact.
		assert_true(ICON_TARGETS.has(kit.compcon_id),
			'%s is listed in ICON_TARGETS.' % kit.resource_path.get_file())
		_assert_real_icon(kit.icon_override, kit.compcon_id)
		var listed:Dictionary = ICON_TARGETS.get(kit.compcon_id, {})
		var by_id := {}
		for action:Action in kit.actions: by_id[action.get_id()] = action
		var texture_by_family := {}
		for action_id:StringName in listed:
			assert_true(by_id.has(action_id), '%s carries %s.' % [kit.compcon_id, action_id])
			if not by_id.has(action_id): continue
			var action:Action = by_id[action_id]
			var label:String = '%s.%s' % [kit.compcon_id, action_id]
			var family:StringName = listed[action_id]
			if family == KIT:
				assert_null(action.icon_override,
					'%s is a KIT row, so it carries NO icon_override and inherits the Kit glyph.' % label)
				assert_not_null(kit.icon_override,
					'%s inherits from %s, which therefore needs an icon_override of its own.'
						% [label, kit.compcon_id])
				assert_eq(kits_per_action.get(action.resource_path, 0), 1,
					'%s is carried by exactly one Kit, so inheriting is safe (action.gd:58 caches it).'
						% label)
				assert_eq(action.get_icon(kit), kit.icon_override,
					'%s is a KIT row: the engine fallback it depends on (action.gd:324-326 -> kit.gd:209) must actually resolve to the Kit glyph, or it renders a generic grey box.'
						% label)
				continue
			_assert_real_icon(action.icon_override, label)
			if action.icon_override == null: continue
			assert_ne(action.icon_override, kit.icon_override,
				"%s and its own Kit %s both wear %s - a row duplicating its Kit's glyph should be a KIT row instead."
					% [label, kit.compcon_id, action.icon_override.resource_path])
			if family_texture.has(family):
				assert_eq(action.icon_override, family_texture[family][0],
					'%s wears the same texture as %s - they are one family (%s).'
						% [label, family_texture[family][1], family])
			else:
				family_texture[family] = [action.icon_override, label]
			if not texture_by_family.has(family): texture_by_family[family] = action.icon_override
		# Two families on ONE Kit must look different, or the gear bar draws two buttons the player
		# cannot tell apart. Rows INSIDE a family may coincide - vanilla's action_thunder_god and
		# action_thunder_god_chamber_rounds do exactly that.
		var claimed := {}
		for family:StringName in texture_by_family:
			var tex:Texture2D = texture_by_family[family]
			assert_false(claimed.has(tex),
				'%s: family %s wears the same texture as family %s - the gear bar draws them as one button.'
					% [kit.compcon_id, family, claimed.get(tex, &'-')])
			claimed[tex] = family
		# Added at the MYCONID FRAME CLOSE, 2026-09-16 (close review slice 5, finding B): the checks
		# above only look at what IS listed - nothing compares it against kit.actions, so an action
		# quietly dropped from ICON_TARGETS is invisible to every assertion above this line. Walk
		# the OTHER direction - every action the Kit actually carries - and assert its presence in
		# `listed` agrees with whether the engine would ever draw it with an icon of its own. See
		# _action_reaches_a_player_facing_surface's header for the three surfaces and the rule.
		var first_weapon_action:Action = null
		var weapon_actions:Array[ActionAttackWeapon] = kit.get_weapon_actions() # kit.gd:129-132
		if not weapon_actions.is_empty(): first_weapon_action = weapon_actions[0]
		for action:Action in kit.actions:
			var should_be_listed:bool = _action_reaches_a_player_facing_surface(action, kit, first_weapon_action)
			assert_eq(listed.has(action.get_id()), should_be_listed,
				'%s.%s is listed in ICON_TARGETS exactly when it reaches a player-facing surface.'
					% [kit.compcon_id, action.get_id()])

## Whether ACTION would be drawn with an icon of its own by some real player-facing surface, rather
## than borrowing the Kit's - i.e. whether it belongs in ICON_TARGETS at all. Three surfaces do
## this, and each clause below transcribes that surface's actual gate rather than guessing, so the
## rule tracks the engine instead of drifting from it as new content lands:
##
##  1. The character sheet's integrated-weapon box always draws a Kit's FIRST weapon action, with no
##     is_situationally_activated or show_in_tooltip check of its own
##     (weapon_mount_item.gd:53,71 - `var attack:ActionAttackWeapon = core.kit.get_weapon_actions()[0]`,
##     gated only on the Kit having at least one weapon action). This is the one surface
##     is_situationally_activated does NOT hide an action from - it is why action_psychopomp_strike
##     needs a row despite being off both the gear bar and the trait card (ruling 9).
##  2. The gear bar draws every action that is not a reaction and not situationally activated
##     (gear_bar.gd:141-156's collect_gear_actions, the ActionReaction / is_situationally_activated
##     clauses at :145/:149 - its hibernating and hide_if_disabled clauses are per-instance runtime
##     state, not a fixed shape, so they have no equivalent here).
##  3. The trait card draws whatever Action.show_in_tooltip(kit) returns. Called directly rather
##     than re-derived: it already reads live translation state (action.gd:341-353) and is
##     overridden per archetype (action_attack.gd:90 is `return not is_situationally_activated`),
##     which is what earns action_draw_fire, action_juggernaut_drive and action_uffish_gyre their
##     rows despite being reactions that never reach the gear bar (path 2 above always excludes a
##     reaction, so this path is the only one that can list one).
##
## A hidden bookkeeping reaction (mt_blasting_powder's, ms_heaer's, mt_halo's) fails all three and is
## correctly unlisted; the Pike's strike is caught only by path 1, and the Gyre only by path 3 - both
## load-bearing, not redundant.
##
## first_weapon_action is kit.get_weapon_actions()[0], or null - passed in so it is computed once per
## Kit rather than once per action.
func _action_reaches_a_player_facing_surface(action:Action, kit:Kit, first_weapon_action:Action) -> bool:
	if action == first_weapon_action: return true
	if action is not ActionReaction and not action.is_situationally_activated: return true
	return action.show_in_tooltip(kit)

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
const HIDDEN_BUFFS_NEEDING_ICONS:Array[StringName] = [
	&'buff_hybridized_shot',
	# SP1 Task 6 (Primrose). Shimmering Shield's cover half is hidden - the marker is the chip the
	# player reads, and two chips for one effect would read as two effects - but attack_roll.gd:189
	# draws it anyway, passing buff_core.base.icon RAW into the roll breakdown rather than through
	# Buff.get_icon(), so BuffBonus's difficulty-svg fallback never runs on that path and a null icon
	# leaves a blank beside the -1. Its icon is SP5's, so this row is what makes this test deliberately
	# red until then.
	&'buff_shimmering_shield_cover',
	# SP3 Task 2 (Primrose). Biting Retort's +1 Difficulty chip, and the same case one card over: it
	# is hidden because it lives only between the PRE reaction and event_unit_attack.gd:114's
	# consume_buffs - a chip for it would be a flicker on the token, not information - while
	# attack_roll.gd:189 draws it in the roll breakdown regardless, from buff_core.base.icon RAW rather
	# than through Buff.get_icon(), so BuffBonus's difficulty-svg fallback never runs there and a null
	# leaves a blank beside the -1. It diverges from vanilla's own buff_warp_shield.tres, which is
	# visible; the reasoning is in action_biting_retort.gd's DIFFICULTY_BUFF docstring. Its icon is
	# SP5's, so this row is what makes this test deliberately red until then.
	&'buff_biting_retort_difficulty',
]

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
