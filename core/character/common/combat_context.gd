## Tracks combat-related state for a player.
##
## Responsibilities:
## - Health and damage tracking
## - Meter/resource management (super meter, stamina, etc.)
## - Combo counter and scaling
## - Hitstun/blockstun frame tracking
## - Proration calculation
##
## Design: Node to allow signal emission for UI updates.
## TODO: Consider RefCounted if signals not needed.
##
## Owned by PlayerContext.
class_name CombatContext extends Node

# TODO: Add combat state variables
# var health: int = 10000
# var meter: int = 0
# var combo_count: int = 0
# var hitstun_frames: int = 0
# var blockstun_frames: int = 0
# var proration: float = 1.0
