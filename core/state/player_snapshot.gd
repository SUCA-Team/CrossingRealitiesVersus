## Complete game state for a single player at a specific frame.
##
## Contains all state needed to represent player's gameplay status.
## Pure data class (RefCounted) with NO Node references.
## Designed for deterministic gameplay and future rollback support.
##
## Core vs Rollback:
## - ✅ Core: All state variables, helper methods
## - 🌐 Rollback: serialize()/clone() methods (TODO: Phase 4)
class_name PlayerSnapshot extends RefCounted

## ============ IDENTITY ============
var player_id: int  # 1 or 2

## ============ PHYSICS STATE (Fixed-point for determinism) ============
## Position in world space (x1000 scaling for determinism)
## Use fixed-point to avoid floating point drift
var position: Vector2i = Vector2i(0, 0)

## Velocity (x1000 scaling)
var velocity: Vector2i = Vector2i(0, 0)

## Is character touching ground
var is_grounded: bool = true

## Which direction character faces (true = right, false = left)
var facing_right: bool = true

## ============ RESOURCES ============
var health: float = 1000
var max_health: float = 1000

var meter: float = 0.0  # 0-100, for supers/EX moves
var stamina: int = 100  # 0-100, for dashes/specials
var max_stamina: int = 100

## Frame when stamina regeneration unlocks (after using stamina)
var stamina_locked_until: int = 0

## ============ STATE MACHINE ============
## Current state as enum ID (not State object - this is data-driven)
var state_id: int = 0  # StateID.IDLE when StateMachine exists

## Number of frames spent in current state
var state_frame: int = 0

## Frames remaining where player cannot act (hitstun, recovery, etc.)
var lockout_frames: int = 0

## Frames remaining of invulnerability
var invulnerable_frames: int = 0

## Reference to active move data (for frame counting)
var current_move: MoveData = null

## ============ COMBAT STATE ============
## Current combo count (resets on opponent recovery)
var combo_count: int = 0

## Juggle points used in current combo (limits air combos)
var juggle_points_used: int = 0

## Damage an opponent this frame (for meter gain, passive triggers)
var damage_this_frame: bool = false

## Took damage this frame (for combo counter increment)
var hit_this_frame: bool = false

## Blocked this frame
var blocked_this_frame: bool = false

## ============ ACTIVE ENTITIES ============
## Active hitboxes from current move (TODO: Use HitboxSnapshot in Phase 2)
var hitboxes: Array = []  # Array[HitboxSnapshot] when implemented

## Active projectiles (TODO: Use ProjectileSnapshot in Phase 2)
var projectiles: Array = []  # Array[ProjectileSnapshot] when implemented

## Active status effects (TODO: Use StatusSnapshot in Phase 3)
var statuses: Array = []  # Array[StatusSnapshot] when implemented

## ============ PASSIVE ABILITIES ============
## Cooldown timers for passive abilities
## Key = passive_id (String), Value = frames_remaining (int)
var passive_cooldowns: Dictionary = {}


## Initialize snapshot with player ID.
func _init(_player_id: int = 1) -> void:
	player_id = _player_id


## Check if player is airborne (not grounded).
func is_airborne() -> bool:
	return not is_grounded


## Check if player can act (not in lockout).
func can_act() -> bool:
	return lockout_frames <= 0


## Check if player can take damage (not invulnerable).
func can_be_hit() -> bool:
	return invulnerable_frames <= 0


## Decrement lockout timer each frame.
func tick_lockout() -> void:
	if lockout_frames > 0:
		lockout_frames -= 1
	if invulnerable_frames > 0:
		invulnerable_frames -= 1


## Reset hit flags (call at end of frame).
func reset_frame_flags() -> void:
	damage_this_frame = false
	hit_this_frame = false
	blocked_this_frame = false


## Get hurtbox rectangle for collision detection.
## TODO: Make this data-driven from CharacterData
func get_hurtbox() -> Rect2i:
	var size = Vector2i(80000, 160000)  # 80px x 160px in fixed-point
	return Rect2i(
		position.x - size.x / 2,
		position.y - size.y,
		size.x,
		size.y
	)


## 🌐 ROLLBACK-SPECIFIC - Implement in Phase 4
## Serialize state to Dictionary for network transmission.
# func serialize() -> Dictionary:
# 	return {
# 		"player_id": player_id,
# 		"position": [position.x, position.y],
# 		"velocity": [velocity.x, velocity.y],
# 		# ... all state
# 	}


## 🌐 ROLLBACK-SPECIFIC - Implement in Phase 4  
## Create deep copy for snapshot history.
# func clone() -> PlayerSnapshot:
# 	var copy = PlayerSnapshot.new(player_id)
# 	copy.position = position
# 	copy.velocity = velocity
# 	# ... copy all state
# 	return copy
