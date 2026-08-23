# Parallel Belt Builder Implementation Notes

`SPEC.md` is the source of truth. This file only records implementation choices
that help keep the current code aligned with that specification.

## Drawing Tool

PBB uses a hidden selection-tool cursor rather than recording real belts. The
tool uses a transparent dummy entity for initial interaction and a dummy
transport-belt for drag position events. Dummy entities are destroyed
immediately and must not remain as real belts in the world.

The implementation was designed with Belt Draw as a reference for interaction
ideas, but no Belt Draw source code is copied into this repository.

## Runtime State

Per-player state is stored in `storage.players[player_index]`. Current runtime
modes are:

* `idle`
* `drawing`
* `placing`

`placing` is a valid current state while the drag-finished plan is being placed
and must not be treated as an obsolete recording-mode value during ordinary
normalization.

Old recording-mode fields such as `path`, `recording`, `placing`, and
`belt_type` are treated as legacy save data and are removed during migration.

## Geometry

Raw anchored segments are expanded into axis-aligned segments. After expansion,
consecutive segments with the same direction, on the same line, and sharing an
endpoint are normalized into a single internal segment. Anchor operations remain
visible to the user as editing actions; this normalization is only for internal
geometry.

Lane generation rejects geometric collapse separately from world placement
collisions. Tile reuse within a lane or between generated lanes is treated as a
path collapse and rejects the plan before placement.

## Belt Catalog

Transport-belt prototypes are discovered dynamically, but GUI candidates must
have a valid placement item from `items_to_place_this`. PBB dummy belts and
other non-user-placeable internal prototypes are excluded from the GUI list.

Prototype discovery is cached at runtime and invalidated on initialization and
configuration changes.

## Placement

Normal placement uses physical entities when possible. If an entry has no
placement item or the player lacks that item, it falls back to a ghost for that
entry. Editor and cheat-mode placement may place physical entities without a
placement item.

Existing same-name, same-direction belts and equivalent belt ghosts are reused
without consuming items.

## Preview Lifecycle

Preview render objects are per-player and are destroyed on Clear, Cancel, GUI
close, player removal, surface change, and player leaving the game. The current
plan can remain in storage after a player leaves; when the player rejoins, the
GUI and preview are regenerated if a plan is still present.
