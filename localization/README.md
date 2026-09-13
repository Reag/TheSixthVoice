# Localization conventions

`localizations.csv` is `id,en`, one row per key, blocks separated by a bare `,` row. Conventions are
Thy Hubris', so the two mods read the same in play.

## The compiled artifact is what the game reads, not the CSV

The CSV is an *imported* asset (`importer="csv_translation"`) that generates
`localizations.en.translation` beside it, and `Translate.add_translation_from_file` globs the
directory for `*.translation` and loads those — the csv path it is handed only locates the folder.

So **a spec asserting on `tr()` reads the compiled artifact, and will happily pass against text you
just deleted.** After every CSV edit, run `filesystem_manage(op="scan")` in the running editor and
confirm the artifact's mtime and size actually moved. `op="reimport"` does **not** do this: it
reports success and refreshes the filesystem entry without running the import.

The artifact is an `OptimizedTranslation`, so multi-word strings are invisible to `grep` — a zero
hit is not evidence of anything. Use mtime and size, or a spec.

## Key shapes

| Key | What it names |
|---|---|
| `mod.reag_thesixthvoice.name` | the mod, in Mod Manage |
| `frame.<mf_id>.name` / `.flavor` / `.flavor.short` | a frame |
| `gear.<kit_id>.name` / `.effect` / `.trigger` / `.flavor` | a kit: trait, core power, system, weapon, weapon mod |
| `gear.<kit_id>.<action_id>.name` / `.effect` | one action on a multi-action kit |
| `gear.<buff_id>.name` / `.effect` | a player-facing buff |
| `lancer.term.<term>` + `lancer.term.<term>.desc` | a glossary term |

The id is the resource's **filename without extension**, which is also what decides its
ContentLibrary index — so a renamed `.tres` is a renamed localization key.

## Wiki markup

`|term|` renders as a glossary link when the term resolves. `|Label=gear.<kit>.<action>|` links
arbitrary text to a specific kit or action — use it whenever rule text names another ability of the
same frame, so the player can read it without leaving the tooltip.

## Glossary terms

A term needs **both** rows: `lancer.term.<term>` and `lancer.term.<term>.desc`.
`GlossaryItem.find_key_from_label` refuses any key whose `.desc` row is missing, so a term with only
a name silently renders as plain text.

It also needs registering in `mod_main.gd`'s `GLOSSARY_TERMS` — the base game's glossary json has no
entry for any of these, and `cached_term_keys` is what the lookup consults.

`Efficient` is registered and defined here because the supplement uses it (Maiden's Blush, Lovers
Knot, Black Mountain). The Fitzgerald does not, but the term ships in the skeleton so the glossary
seam is proven on 1.4.3 before a frame depends on it — the author's call, 2026-09-13.
