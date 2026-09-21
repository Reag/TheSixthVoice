## INEXORABLE FORMATION: the Sluagh's shield is also its reach.
##
##   "The Sluagh increases its Sensors equal to its OVERSHIELD."
##
## Buff.TO.STATBLOCK, so the bonus lands in state.stat_bonus and every reader of Sensors sees it:
## Unit.get_sensor_range() is core.get_sensor_range() + state.stat_bonus.sensor_range (unit.gd:305),
## with twenty-five readers in engine and content - Scan, Search, tech attack range, every
## target_range_is_sensors action, Eye of Horus, and all four of this frame's own Sensors reads.
## The Effervescent Immunity chip's shape, and the Goblin's buff_symbiosis_statblock.gd is vanilla's.
##
## ONE ENGINE GATE IS DELIBERATELY NOT REACHED AND THAT IS RECORDED, NOT FIXED (ruling 12):
## unit_relation.gd:256 measures a tech reaction's range off unit_core.get_sensor_range(), which is
## FRAME-ONLY and sees no stat_bonus at all. Three things read it, not two: the Goblin's Reactive
## Code, the NPC Commander's Press the Attack, and - OUTSIDE THE BASE GAME - Thy Hubris' Injector
## Drill (action_injector_drill.gd:111, which passes the drill's own WIELDER as from_unit). The
## Sluagh ships none of the three, so the divergence is inert on the frame itself; the one real
## consequence is cross-mod, and it is bounded: a Sluagh pilot who also holds the Thy Hubris licence
## and equips that drill offers its free tech follow-up at BASE Sensors, i.e. short by whatever
## Overshield the dome is holding. Recorded, accepted, not fixed (ruling 12).
##
## get_values IS CALLED WITH A BARE CONTEXT. unit_battle_state.gd:232 calls buff.get_values() with no
## argument, so BuffCore.get_values builds Context.create({}) and context.map falls back to X.map()
## (context.gd:76-80). get_owner_unit(context.map) therefore resolves through the live map, which is
## the same fallback buff_gravity_well.gd relies on.
##
## THE OWNER IS THE HOLDER HERE, deliberately: the chip is applied by the Sluagh's OWN trait Kit
## through its PassiveBuffApplicator, so BuffCore.from_gear names gear on the Sluagh and
## get_owner_unit finds the Sluagh. get_holder_unit would give the same answer at the cost of a scan
## over every unit on the map (buff_core.gd:129-133), on every stat refresh.
##
## TWO REFRESH PATHS, AND THIS FILE OWNS ONLY ONE OF THEM.
##  - A GAIN is refreshed by the shared helper: Overshield.grant ends with
##    target.update_cached_values_and_token() (SP1 Task 4). Every grant in this mod goes through it.
##  - A LOSS is not. event_unit_damage spends the shield inside damage() (:119 -> :215-218) and
##    rebuilds no cache, so this buff listens on DAMAGE / POST for its OWN holder and refreshes there.
##    The timing works because the spend is at :119 and the POST reactions are queued at :196.
##  - Overshield from a VANILLA or third-party source (an Aceso, an Argonaut, ssc_emperor's own
##    triggers) is seen at the next cache rebuild, which any buff, status or move causes. Recorded
##    lag, cosmetic, ruling 12.
##
## activate() DOES NOT CALL super. Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255) and this one is the trait itself - it has to survive every hit for the whole
## scene. buff_effervescent_immunity_counter.gd carries the same note.
extends Buff

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

func get_values(core:BuffCore, context:Context) -> Context:
	var block := Statblock.new()
	block.sensor_range = Overshield.current(core.get_owner_unit(context.map))
	return Context.create({ object = block })

## stat_bonus is rebuilt only by update_cached_values, and a status-less buff application does not
## trigger one - so without this the trait would report nothing until something else happened to
## refresh the cache. buff_effervescent_immunity.on_application is the same line for the same reason.
func on_application(_event:EventCore, _core:BuffCore, unit:Unit) -> void:
	unit.update_cached_values_and_token()

## Only OUR OWN holder's damage. The bus runs this gate for every unit's every buff on every damage
## event in the game, so the first clause is the one that keeps it cheap as well as correct.
func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	return triggering_event.context.unit == unit

func activate(_core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	unit.update_cached_values_and_token()
