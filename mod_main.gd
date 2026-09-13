extends Node

const MOD_ID := "Reag-TheSixthVoice" ## Name of the directory that this file is in

## Vanilla resources this mod extends with a `.tres_ext.gd`, by the VANILLA path.
##
## Empty until the first alt frame (M/K2 appends its frame to li_gms rank 1). Listed here rather
## than discovered, because the entry is only half the job - see retain_extended_resources().
const EXTENDED_RESOURCES:Array[String] = []

## Autoloads this mod extends with a `.gd_ext.gd`, by autoload name => vanilla script path.
##
## Empty for now. Note that not every autoload can be extended: unit_action.gd logs the install and
## then never invokes an override, for reasons nobody has found. Prove any new seam with a spec that
## only the override can pass before building content on it.
const EXTENDED_AUTOLOADS := {}

## Terms this mod's rule text uses in |markup| that the base game's glossary does not list.
const GLOSSARY_TERMS:Array[StringName] = [&'lancer.term.efficient']

## Holds every resource named in EXTENDED_RESOURCES alive for the life of the mod. Load-bearing;
## see retain_extended_resources(). An instance var, not static: this node lives exactly as long as
## the mod is active, and ModApplier.execute_unload_all_mods queue_free()s every embassy node, so
## the array dies with the mod and needs no explicit release.
var _retained_resources:Array[Resource] = []

# Runs when this mod is activated (whenever active mods are changed).
#
# _init rather than _ready only to match the sibling mods; on 1.4.3 either would do. Both run inside
# ModApplier.install_mod - start_installing_mod() precedes add_mod_embassy_node(), whose add_child
# fires _ready synchronously, and record_installed_mod() comes after both. (Do NOT read the engine's
# own comment there - "the mod will not show up as installed during its _ready()" - as meaning
# _ready falls outside the window. It means the opposite: the mod is still marked INSTALLING then.)
#
# What actually matters for retain_extended_resources() is only that this runs before
# apply_installed_queued_extensions, which happens after every mod is installed. Both hooks clear that.
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

	retain_extended_resources()
	register_glossary_terms()

## Keeps every resource we extend with a `.tres_ext.gd` alive, because the engine no longer does.
##
## UPSTREAM BUG, unfixed as of 1.4.3. _ModLoaderResourceExtension._save_resource
## (addons/mod_loader/internal/resource_extension.gd) dropped the line that retained the extended
## resource - 1.3.3 appended it to ModLoaderStore.extended_resources, 1.4.x appends nothing. The
## applier's own reference is a local, so the moment it goes out of scope the resource-cache entry
## evaporates and the next load() reads the UNEXTENDED file straight off disk. The extension is
## applied, reports success, and then silently un-happens. (Its scene twin, bug 6, is the same story
## in _ModLoaderSceneExtension._save_scene; this mod extends no scenes yet.)
##
## The fix is to hold a real reference. Timing is the whole trick: this runs during install, BEFORE
## ModApplier applies the queued modifications, so the extension mutates the very object held here
## and the cache entry has something to survive on. Loading it afterwards would be too late - it
## would cache a fresh, unextended copy and pin THAT.
##
## Not CCC's other half. CCC also queues its extension by hand, because 1.4.0's extend_resource
## stripped the wrong suffix and skipped it (bug 1). That was fixed in 1.4.1 and this mod is
## 1.4.x-only, so the engine queues the extension correctly and only the retention is missing.
func retain_extended_resources() -> void:
	for path:String in EXTENDED_RESOURCES:
		var resource:Resource = load(path)
		if resource == null:
			ModLoaderLog.error('Cannot retain %s: it did not load.' % path, MOD_ID)
			continue
		_retained_resources.append(resource)

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
