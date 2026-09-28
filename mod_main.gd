extends Node

const MOD_ID := "Reag-TheSixthVoice" ## Name of the directory that this file is in

## Vanilla resources this mod extends with a `.tres_ext.gd`, by the VANILLA path. The extension
## script lives at the mirror path inside this mod: `res/<vanilla path minus res://>_ext.gd`.
##
## Listed here rather than discovered, because the file on disk is only half the job - see
## apply_resource_extensions_directly(). spec/test_alt_frames.gd checks every alt's licence is here.
const EXTENDED_RESOURCES:Array[String] = [
	'res://content/licenses/gms/li_gms.tres', # M/K2, the Everest alt, appended to rank 1
	'res://content/licenses/ha/li_barbarossa.tres', # Subutai, the Barbarossa alt, appended to rank 2
	'res://content/licenses/horus/li_gorgon.tres', # Myconid, the Gorgon alt, appended to rank 2
	'res://content/licenses/ssc/li_mourning_cloak.tres', # Maiden's Blush, the Mourning Cloak alt, appended to rank 2
	'res://content/licenses/ha/li_iskander.tres', # Vauban, the Iskander alt, appended to rank 2
	'res://content/licenses/ipsn/li_nelson.tres', # Shackleton, the Nelson alt, appended to rank 2
	'res://content/licenses/ipsn/li_tortuga.tres', # Gloire, the Tortuga alt, appended to rank 2
	'res://content/licenses/ipsn/li_drake.tres', # Grutte Pier, the Drake alt, appended to rank 2
	'res://content/licenses/horus/li_goblin.tres', # Rakshasa, the Goblin alt, appended to rank 2
	'res://content/licenses/ssc/li_deaths_head.tres', # Lovers Knot, the Death's Head alt, appended to rank 2
	# Six Sky, the Sunzi alt, appended to rank 2. ANOTHER MOD'S licence (gavstarb-ha_sunzi), so it lives
	# at that mod's unpacked path and is OPTIONAL: extendable() drops it while it is not mounted, and
	# deferred() hands it to the late extension - see queue_late_extensions().
	'res://unpacked/gavstarb-ha_sunzi/res/content/licenses/ha/li_sunzi.tres',
	# Black Mountain, the Emperor alt, appended to rank 2. ANOTHER MOD'S licence (gavstarb-ssc_emperor),
	# the Six Sky's shape exactly: optional, dropped by extendable() while unmounted, deferred to the
	# late extension when the Emperor installs after us.
	'res://unpacked/gavstarb-ssc_emperor/res/content/licenses/ssc/li_emperor.tres',
]

## The key a LATE extension is queued on: a resource of our own, so the engine's load() of it never
## misses. Our Six Sky frame; nothing else extends it, and one carrier serves every deferred path
## (the Black Mountain's li_emperor rides the same callable). See queue_late_extensions().
const LATE_EXTENSION_CARRIER := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/mf_six_sky.tres'

## Stamped on each resource INSTANCE we have edited, so a re-activation never edits it twice. On the
## instance rather than on this node: a resource still in cache from a previous activation already
## carries our edit, and a freshly reloaded vanilla one does not.
const APPLIED_META := &'reag_sixth_voice_extended'

## The engine's mod library, by path: class_name ModLibrary exists only on 1.4.x, and nothing in
## this mod spells a version-specific class name.
const MOD_LIBRARY := 'res://engine/mod/mod_library.gd'

## Autoloads this mod extends with a `.gd_ext.gd`, by autoload name => vanilla script path.
##
## Note that not every autoload can be extended: unit_action.gd logs the install and then never
## invokes an override, for reasons nobody has found. Prove any new seam with a spec that only the
## override can pass before building content on it - spec/test_unit_relation_extension.gd is that
## spec for the first entry, spec/test_spike_unit_printer_seam.gd for the second, and
## spec/test_spike_shackleton_sp1_seam.gd (its tests at :54-64) for the third.
const EXTENDED_AUTOLOADS := {
	&'UnitRelation': 'res://engine/character/unit/service/unit_relation.gd', # Primrose: Superheavy Overwatch under Wormhole Grasp
	&'UnitPrinter': 'res://engine/character/unit/service/unit_printer.gd', # Leoleth: the Thermal Death Axe is destructible at zero charges
	&'CommonActionUtil': 'res://engine/utils/common_action_util.gd', # Shackleton: Spatial Rerouting's any-direction knockback
}

## Terms this mod's rule text uses in |markup| that the base game's glossary does not list.
const GLOSSARY_TERMS:Array[StringName] = [&'lancer.term.efficient']

## Holds every resource named in EXTENDED_RESOURCES alive for the life of the mod. Load-bearing;
## see apply_resource_extensions_directly(). An instance var, not static: this node lives exactly as
## long as the mod is active, and ModApplier.execute_unload_all_mods queue_free()s every embassy
## node, so the array dies with the mod and needs no explicit release.
var _retained_resources:Array[Resource] = []

# Runs when this mod is activated (whenever active mods are changed).
#
# _init rather than _ready only to match the sibling mods; on 1.4.3 either would do. Both run inside
# ModApplier.install_mod - start_installing_mod() precedes add_mod_embassy_node(), whose add_child
# fires _ready synchronously, and record_installed_mod() comes after both. (Do NOT read the engine's
# own comment there - "the mod will not show up as installed during its _ready()" - as meaning
# _ready falls outside the window. It means the opposite: the mod is still marked INSTALLING then.)
#
# What actually matters for apply_resource_extensions_directly() is only that this runs while the
# mod is still INSTALLING - before apply_installed_queued_extensions, which happens after every mod
# is installed. Both hooks clear that.
func _init() -> void:
	ModLoaderLog.info("Activating.", MOD_ID)

	# Adds the translations from your localization/localizations.csv
	LancerTacticsMod.add_translations(MOD_ID)

	# Automatically scans everything in your mod's res/ directory, and:
	# 1. Adds any new RESOURCES (.tres, .tscn, images) or SCRIPTS (.gd) to the virtual
	#    filesystem if there was no vanilla corresponding file.
	# 2. Overwrites any RESOURCES that already existed at those corresponding locations
	# 3. Installs any SCRIPTS (.gd) that already existed as a script_extension. (Warning: cannot extend class_name scripts)
	LancerTacticsMod.add_overwrite_extend_mod_resources(MOD_ID)

	apply_resource_extensions_directly()
	register_glossary_terms()

## Applies every `.tres_ext.gd` in EXTENDED_RESOURCES ourselves, during install, and takes our
## entries back OUT of the queue the engine would have applied them from. Two upstream bugs, both
## unfixed as of 1.4.3, and both proven by spike 2 (specs/2026-09-14-license-extension-feasibility.md):
##
## 1. THE QUEUE COLLISION. ModApplier.apply_installed_queued_extensions (mod_applier.gd:219-220)
##    folds every installed mod's queued_resource_modifications into ONE Dictionary keyed by target
##    resource path, with Dictionary.merge - which keeps the first value per key and throws the rest
##    away. So when two mods extend the same .tres through the queue, only the FIRST-INSTALLED mod's
##    callable ever runs: no warning, no log line. Swept against the live zips 2026-09-28, only
##    li_gms is contended through the queue - by gavstarb-gms_1st_party and our own Crisis Core
##    Catalog. fateofman-imi_alt_frames also appends to li_gms, li_barbarossa and li_goblin, but
##    from its own mod_main._init, NOT the queue, so it composes with us in any order; every other
##    licence here is uncontended today. A lost coin toss ships an alt frame that is registered, has
##    a name and a sprite, and cannot be picked. Measured 2026-09-14: with a stock queue-path
##    competitor installed one slot before us, the M/K2 was dropped from li_gms while the frame
##    itself loaded fine.
##
##    THE FIX: erase our key from our own queue, so the contended dictionary sees only the other
##    mod's entry and applies it normally, and edit the resource here instead. Order stops
##    mattering: whoever runs second calls load(path), gets the SAME cached instance, and appends to
##    it. The engine's apply_extension also does a plain load(), so a queue-path mod after us edits
##    our retained instance too.
##
## 2. RETENTION. _ModLoaderResourceExtension._save_resource dropped the line that kept the extended
##    resource alive (1.3.3 appended it to ModLoaderStore.extended_resources; 1.4.x appends nothing),
##    so once the last reference goes the cache entry evaporates and the next load() reads the
##    UNEXTENDED file off disk. _retained_resources holds the very instance we edit, for the life of
##    this node. Timing is the whole trick: this runs during install, so the instance held here is
##    the one every later load() - the engine's queue, ContentLibrary - returns.
##
## Same shape as Reag-CrisisCoreCatalogEvolved's apply_license_extension_directly(), generalised
## over the list, and without CCC's 1.3.3 guard: this mod is 1.4.x-only.
func apply_resource_extensions_directly() -> void:
	var library = load(MOD_LIBRARY)
	if not library.is_mod_being_installed(MOD_ID):
		ModLoaderLog.error('Not installing; resource extensions were not applied.', MOD_ID)
		return
	var mod = library.get_mod_being_installed()
	for vanilla_path:String in extendable(EXTENDED_RESOURCES):
		# Stand down from the shared queue whether or not the engine got as far as filling it.
		mod.queued_resource_modifications.erase(vanilla_path)
		extend_one(vanilla_path, _retained_resources)
	queue_late_extensions(mod.queued_resource_modifications, deferred(EXTENDED_RESOURCES), _retained_resources)

## Extends one resource by path, in place, stamps it and holds it in `retained`. Shared by the direct
## route and the late one; `retained` is the node's _retained_resources (an Array is a reference).
static func extend_one(vanilla_path:String, retained:Array) -> void:
	var resource:Resource = load(vanilla_path)
	if resource == null:
		ModLoaderLog.error('Cannot extend %s: it did not load.' % vanilla_path, MOD_ID)
		return
	if resource.has_meta(APPLIED_META):
		retained.append(resource)
		return
	var extension_path := extension_script_path_for(vanilla_path)
	var extender_script:Script = load(extension_path)
	if extender_script == null:
		ModLoaderLog.error('Cannot extend %s: %s did not load.' % [vanilla_path, extension_path], MOD_ID)
		retained.append(resource)
		return
	# THE RETURN VALUE IS THE CONTRACT, AND IT IS CHECKED - the engine's own path checks it
	# (addons/mod_loader/internal/resource_extension.gd:20-32: a falsy return is ModLoaderLog.fatal,
	# and the RETURNED object is what gets take_over_path'd). An extension that returns a different
	# instance - a duplicate(), a wholesale replacement - or null is a real shape, and discarding
	# the return would retain the UN-extended original while still logging success. li_gms's
	# extension mutates in place and returns the same object, so nothing changes today; this exists
	# because EXTENDED_RESOURCES is meant to grow, and the next alt frame's author gets a signal
	# rather than a silent no-op. Note the retention now happens AFTER the call, on whatever came
	# back, for the same reason.
	var extended:Resource = extender_script.new().modify_resource(resource)
	if extended == null:
		ModLoaderLog.error('Cannot extend %s: %s returned null.' % [vanilla_path, extension_path], MOD_ID)
		retained.append(resource)
		return
	if extended != resource: extended.take_over_path(vanilla_path)
	retained.append(extended)
	extended.set_meta(APPLIED_META, true)
	ModLoaderLog.info('Applied %s directly, outside the shared extension queue.' % extension_path.get_file(), MOD_ID)

## THE LATE EXTENSION: another mod's resource that is not mounted YET. Frame close, 2026-09-27.
##
## ModApplier installs one mod at a time and mounts each zip only as it installs it
## (mod_applier.gd:110-113, :139-141). The engine means optional_dependencies to put the other mod
## first, and it cannot: modset.gd:253 assigns an int to the typed dependency_importance Dictionary,
## a runtime error that aborts check_dependencies_recursive, so the sort falls back to the player's
## Load priority and then to list order. A player with The Sixth Voice above HA Sunzi installs us
## FIRST, li_sunzi does not exist yet, and the engine's own queue skips our .tres_ext.gd with a print
## (lancer_tactics_mod.gd:180-183). Nothing else would ever apply it: the Six Sky would be registered
## and never grantable, with no error anywhere, and no test run can see it (every resident is mounted
## from disk before anything installs).
##
## So we queue a callable of our own on LATE_EXTENSION_CARRIER. The engine runs every queued
## extension after the last mod is installed and before ContentLibrary.initialize
## (mod_applier.gd:116, :121), by which time the other mod's pack is mounted if it is installed at all.
## The carrier always loads, so the callable is always called with a real resource and never has to
## return null (a ModLoaderLog.fatal). Without the other mod, extend_late finds nothing and does nothing.
## The key is ours alone, so the queue's merge (mod_applier.gd:219-220) never drops it.
##
## The player-side workaround, in the mod description too: give The Sixth Voice a higher Load priority
## than HA Sunzi. Once Wickworks fixes modset.gd:253 the declared optional dependency orders the two
## and this path simply finds the licence already stamped.
static func queue_late_extensions(queue:Dictionary, paths:Array[String], retained:Array) -> void:
	if paths.is_empty(): return
	queue.get_or_add(LATE_EXTENSION_CARRIER, []).append(extend_late.bind(paths, retained))

## Called by the engine's queue with the carrier; extends every path that now exists, and hands the
## carrier back untouched.
static func extend_late(carrier:Resource, paths:Array[String], retained:Array) -> Resource:
	for path:String in paths:
		if ResourceLoader.exists(path): extend_one(path, retained)
	return carrier

## The other-mod entries of `paths` that are not mounted yet: what extendable() drops.
static func deferred(paths:Array[String]) -> Array[String]:
	var waiting:Array[String] = []
	for path:String in paths:
		if path.begins_with('res://unpacked/') and not ResourceLoader.exists(path): waiting.append(path)
	return waiting

## The entries of `paths` this install can actually extend. A path under res://unpacked/ belongs to
## ANOTHER MOD (the Six Sky's li_sunzi, spike 9), which a player may not have: dropped here when it does
## not exist, so the load() below never misses and never writes a ModLoaderLog.error into the log of
## every player without that mod. A vanilla path is always kept - a missing one IS an error.
##
## Read at install time, when it may NOT yet be true: optional_dependencies is meant to install the
## other mod first and does not (modset.gd:253), so a path dropped here goes to deferred() and the late
## extension instead.
static func extendable(paths:Array[String]) -> Array[String]:
	var kept:Array[String] = []
	for path:String in paths:
		if path.begins_with('res://unpacked/') and not ResourceLoader.exists(path): continue
		kept.append(path)
	return kept

## res://content/licenses/gms/li_gms.tres => res://unpacked/<this mod>/res/content/licenses/gms/li_gms.tres_ext.gd
## res://unpacked/gavstarb-ha_sunzi/res/content/licenses/ha/li_sunzi.tres => res://unpacked/<this mod>/res/unpacked/gavstarb-ha_sunzi/res/content/licenses/ha/li_sunzi.tres_ext.gd
## The unpacked path is where a zip install lands too (ProjectSettings.load_resource_pack keeps it).
static func extension_script_path_for(vanilla_path:String) -> String:
	return 'res://unpacked/%s/res/%s_ext.gd' % [MOD_ID, vanilla_path.trim_prefix('res://')]

## Terms the mod uses in its rule text that the base game's glossary does not list.
##
## GlossaryItem.process_glossed_text turns |markup| into a link only when find_key_from_label can
## resolve the label to a key in cached_term_keys, and that list is loaded from the game's own
## glossary json, which has no "efficient" entry. Appending to the cache is how the first-party
## HORUS alts mod does it.
##
## The priming call is load-bearing: cached_term_keys is filled lazily on the first lookup, so
## appending before that happens would be overwritten by the fill. find_key_from_label also refuses
## any key whose ".desc" row is missing, so both CSV rows have to exist for this to do anything.
func register_glossary_terms() -> void:
	GlossaryItem.find_key_from_label('') # force the lazy cache fill before we append to it
	for term:StringName in GLOSSARY_TERMS:
		if not GlossaryItem.cached_term_keys.has(term): GlossaryItem.cached_term_keys.append(term)

# Runs when this mod's node is added to the tree (whenever active mods are changed)
func _ready() -> void:
	reload_extended_autoloads.call_deferred()

## Re-applies our autoload script extensions to the live autoload nodes, because the engine does not.
##
## UPSTREAM BUG, unfixed as of 1.4.3. Mods are installed AFTER the autoloads already exist, and
## ModApplier.apply_script_changes_to_autoload_nodes only reloads an autoload whose PLAIN .gd a mod
## replaced: it matches each mod file's vanilla path against the autoload table, and a `.gd_ext.gd`
## file's vanilla path ends in ".gd_ext.gd", which matches nothing. So the autoload node keeps its
## pre-extension script and not one override ever runs - with the install logged as a success.
##
## Deferred from _ready on purpose: ModApplier.execute_apply_modset installs every mod and then
## applies all queued script extensions synchronously, so by the time this runs, load(vanilla_path)
## already returns the extended script via take_over_path. Self-disabling: once Wickworks fixes the
## matching, the node already holds the extended script and the comparison below skips it.
func reload_extended_autoloads() -> void:
	for autoload_name:StringName in EXTENDED_AUTOLOADS:
		var node:Node = get_tree().root.get_node_or_null(NodePath(autoload_name))
		if node == null: continue
		var extended:Script = load(EXTENDED_AUTOLOADS[autoload_name])
		if extended == null:
			# Guarded because the consequence of not guarding is severe and silent: a null here would
			# fail the comparison below (the node HAS a script), and the set_script(null) that follows
			# would strip the autoload of its script permanently, in the real game, at load time.
			ModLoaderLog.error('Cannot reload autoload %s: %s did not load.'
				% [autoload_name, EXTENDED_AUTOLOADS[autoload_name]], MOD_ID)
			continue
		if node.get_script() == extended: continue # already right (engine fixed, or nothing extended it)
		node.set_script(null)
		node.set_script(extended)
		ModLoaderLog.info('Reloaded autoload %s with its script extension.' % autoload_name, MOD_ID)

# Runs when this mod is deactivated due to user input or the normal mod reset/reactivate sequence.
# Should undo any non-standard stuff you've done in _init or _ready.
#func deactivate() -> void:
	#ModLoaderLog.info("Deactivating", MOD_ID)

# This only runs on game startup when this mod is enabled; use it to make any manual changes to the game
# that are outside of the LancerTacticsMod normal enable/disable sequence that should NOT be reverted when
# active mods change. This will be run AFTER all mods' _init and _ready functions.
func on_first_initialization() -> void:
	ModLoaderLog.info("On game start for substantial mod.", MOD_ID)
