# Shared mechanics

Helpers used by more than one frame. Roadmap §4 is the registry; the rule there is that **a helper
is born with its first consumer**, in its own sub-folder, with its own specs — and its interface is
frozen the moment that sub-project ships, recorded in roadmap §4 and in memory
`sixth-voice-build-state`. A later frame that needs more extends the helper in its own sub-project,
with every earlier spec still green.

The shape is the Draugr's: a static-function script plus whatever `.tres` it needs, no autoload, no
`class_name` (a `class_name` script cannot be reliably extended — Godot #83542 — and every consumer
reaches it by `preload` anyway).

Planned, none built yet:

| Family | Born with | Consumers |
|---|---|---|
| Overshield | 4 Myconid | Sluagh, Hazard, Naga, Primrose, Black Mountain |
| Teleport | 5 Maiden's Blush | Purple Thorn, Leoleth, Sluagh, Koremasa, Six Sky |
| Efficient (core-power refund) | 5 Maiden's Blush | Lovers Knot, Black Mountain |
| Difficult terrain | 6 Vauban | Leoleth, Shackleton |
| Lock-on consumed hook | 7 Naga | Black Mountain |
| Attack redirection | 3 Subutai | Sluagh, Rakshasa, Lovers Knot — shape set by that frame's spike |

Nothing with a vanilla precedent belongs here: limited weapons that attack without charges follow
the Injector Drill, and `mt_guardian` / `mt_fragile` / `mt_slow` / `mt_exposed_reactor` are vanilla
trait Kits to be referenced, not reimplemented.
