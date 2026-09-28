## FORM OF THE MYRIAD's chip (design 3, rulings 18-20; Pass E, Lovers Knot item 4). The ability is still
## two readers of its id - buff_gemini_charge.gd chains up to 4 legs at the weapon's full reach while it
## is held, and Precision Venting stands its round gate down and leaves the round uncounted - and both
## read the id through UnitCondition.has_buff, which keys on the .tres basename: renaming it kills both.
##
## ITS ONE HOOK: THE RESTORED GEMINI ROUND ENDS WITH IT (ruling 19 as the author fixed it, Pass E).
## action_form_of_the_myriad.gd clears a spent Gemini round when it applies the chip and writes the
## count it cleared onto this core under RESTORED_KEY. When the chip goes, the round is stamped again -
## unless the Myriad's turn already spent it, which stamped it itself. So the turn keeps its two
## Geminis, and no reaction Gemini opens later that round. The owner gear is the core system: Gemini's
## applicator and the Myriad share it.
##
## on_clear is NOT AWAITED (buff.gd:176) and runs for every clear, however it happens; nothing here
## awaits, and a chip cleared early (the Knot destroyed) re-stamps a round nobody can use. THE SAME IS
## TRUE OF ANY EARLY CLEAR, not only the harmless destroyed case: an enemy that strips the chip mid-turn
## (a status-clearing effect, say) re-stamps the round right there, so that turn's second Gemini - the
## one the still-open Myriad turn was meant to keep - is lost, not merely spent a beat sooner.
##
## THE OWNER IS READ FROM THE HOLDER'S OWN LOADOUT (Pass F final review, a VANILLA BUG on
## MapState.get_gear_by_id, map_state.gd:261-264, reports/2026-09-27-map-state-source-lookup.md): the
## engine's own lookup returns - and caches - null the moment ANY unit earlier in the map's unit list
## than the chip's holder carries a buff with situational gear, whatever id was actually asked for; the
## search stops there and never reaches the holder. The cache starts empty after every load
## (map_state.gd:102), so this could misfire on a freshly loaded save. The chip's holder is always its
## own owner (apply_buff stamps core.from_gear to the acting gear, and the chip is applied to that same
## unit), so on_clear reads unit.core.loadout directly instead of going through the buggy map lookup -
## the Koremasa magnet's find_kit_holder pattern (buff_makibishi_attached.gd), simplified because here
## the holder and the owner are already the same unit.
extends Buff

const Record := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/cp_integrated_redirection_aggregate/gemini_record.gd')

## The Gemini uses the Myriad cleared, on this chip's BuffCore state.
const RESTORED_KEY := 'reag_myriad_restored_gemini'

func on_clear(event:EventCore, core:BuffCore, unit:Unit) -> void:
	if int(core.get_state(RESTORED_KEY, 0)) <= 0: return
	if not Unit.is_valid(unit): return
	var gear:GearCore = unit.core.loadout.get_by_persistent_id(core.from_gear)
	if not GearCore.is_valid(gear): return
	if gear.get_uses_this_round_alt(Record.USAGE_KEY) == 0:
		gear.increment_action_usage(Record.USAGE_KEY, false)
