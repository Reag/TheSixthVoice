# THE THERMAL DEATH AXE'S STANDARD PROFILE (Leoleth rank II, design ruling 15).
#
#   "You may attack with this weapon without expending or requiring charges"
#
# ONE OVERRIDE COVERS THE SENTENCE. Action.consumes_charges (action.gd:108) defaults to true and is
# read in exactly two places: unit_action.gd:153 refuses the action with REASON.NO_CHARGES when the
# gear is empty ("without requiring"), and :274 spends one on every use ("without expending").
# Thy Hubris' action_injector_drill.gd is the in-house precedent; vanilla's are one line each
# (action_turret_attack.gd:11, action_recall.gd:43).
#
# The Thunderous profile beside this one is SCRIPTLESS: the same two engine lines, with the default
# left true, ARE "spend 1 charge to use the Thunderous profile". The recharge is
# action_tda_recharge.gd, and "can be destroyed even if it has no charges remaining" is
# res/engine/character/unit/service/unit_printer.gd_ext.gd.
extends ActionAttackWeapon

func consumes_charges(_specific:SpecificAction) -> bool: return false
