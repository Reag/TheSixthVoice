## Shredded, on a crit, until the START of the target's next turn.
##
## A WHOLE SCRIPT FOR ONE RETURN VALUE, and vanilla says so itself: the chain axe's
## content/gear/ipsn/weapons/mw_chain_axe/onhit_chain_axe.gd carries the comment "a little silly we
## made a full script for this... but I don't think there's a lot of onhiteffects with non-standard
## durations that don't also have other stuff going on". This file is that shape exactly, and this
## mod's own onhit_swivel_grapeshot.gd:57 is the second instance of it.
##
## WHY THE OVERRIDE IS LOAD-BEARING. OnHitEffect's default is StatusType.get_standard_until(status)
## (on_hit_effect.gd:91-92), and content/statuses/status_shredded.tres:11 declares
## standard_until = 1 = Lancer.UNTIL.END_OF_NEXT_TURN. The card asks for the START of that turn -
## a strictly shorter window that ends before the target acts rather than after. Delete this file's
## body and the Shredded silently lasts a full extra turn; nothing would fail to compile.
##
## WHOSE TURN. Lancer.UNTIL.START_OF_TURN is the turn of the unit CARRYING the status (the target);
## START_OF_OWNERS_TURN would be the Primrose's, and is the wrong one. lancer.gd:46-52.
##
## NOT GATED ON THREAT. Ruling 22 (author, 2026-09-19): the card's on-crit line has no melee
## qualifier, so a thrown crit shreds too. That is the default - should_abort never looks at threat
## (on_hit_effect.gd:54-73) - so there is deliberately no override of it here.
extends OnHitEffect

func get_applied_duration_for_statuses(status:StringName, context:Context, attacked_unit:Unit) -> Lancer.UNTIL:
	return Lancer.UNTIL.START_OF_TURN
