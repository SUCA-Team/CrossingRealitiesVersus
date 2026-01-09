## Physics system for deterministic character movement.
##
## Uses fixed-point math (Vector2i with x1000 scaling) to ensure
## identical physics calculations across different machines.
##
## Handles:
## - Gravity
## - Velocity application
## - Ground collision
## - Friction
## - Stage bounds
##
## Design: Stateless processor (RefCounted).
## Reads and modifies PlayerSnapshot state.
class_name PhysicsSystem extends RefCounted

## Gravity acceleration (fixed-point, x1000)
## 980 = 0.98 pixels per frame² at 60 FPS
const GRAVITY: int = 980

## Ground Y position (fixed-point, x1000)
const GROUND_Y: int = 400000  # 400 pixels

## Stage width bounds (fixed-point, x1000)
const STAGE_LEFT: int = 50000   # 50 pixels
const STAGE_RIGHT: int = 750000  # 750 pixels

## Friction multiplier (0-1000, where 1000 = no friction)
const GROUND_FRICTION: int = 900  # 90% of velocity retained

## Air friction (less than ground)
const AIR_FRICTION: int = 980  # 98% of velocity retained


## Process physics for one player for one frame.
##
## @param state: PlayerSnapshot to update
## @param char_data: CharacterData with physics parameters
static func tick(state: PlayerSnapshot, char_data: CharacterData) -> void:
	# Apply gravity if airborne
	if not state.is_grounded:
		state.velocity.y += int(char_data.gravity * 1000)  # Convert to fixed-point
	
	# Apply velocity to position
	state.position.x += state.velocity.x / 1000
	state.position.y += state.velocity.y / 1000
	
	# Ground collision check
	_check_ground_collision(state)
	
	# Apply friction
	_apply_friction(state)
	
	# Bounds check (keep player in stage)
	_enforce_stage_bounds(state)


## Check and handle ground collision.
static func _check_ground_collision(state: PlayerSnapshot) -> void:
	if state.position.y >= GROUND_Y:
		state.position.y = GROUND_Y
		state.velocity.y = 0
		state.is_grounded = true
	else:
		state.is_grounded = false


## Apply friction to slow down character.
static func _apply_friction(state: PlayerSnapshot) -> void:
	# Only apply friction in neutral states
	# Attacks, dashes, etc. have their own momentum
	if state.state_id == StateMachine.StateID.IDLE or \
	   state.state_id == StateMachine.StateID.RUN:
		
		if state.is_grounded:
			state.velocity.x = state.velocity.x * GROUND_FRICTION / 1000
		else:
			state.velocity.x = state.velocity.x * AIR_FRICTION / 1000


## Keep player within stage boundaries.
static func _enforce_stage_bounds(state: PlayerSnapshot) -> void:
	if state.position.x < STAGE_LEFT:
		state.position.x = STAGE_LEFT
		state.velocity.x = 0
	elif state.position.x > STAGE_RIGHT:
		state.position.x = STAGE_RIGHT
		state.velocity.x = 0


## Apply horizontal movement based on run speed.
## Call this when player is holding directional input.
static func apply_run_movement(state: PlayerSnapshot, direction: int, char_data: CharacterData) -> void:
	# direction: -1 = left, 1 = right
	var run_speed_fixed = int(char_data.walk_speed * 1000)  # TODO: rename walk_speed to run_speed in CharacterData
	state.velocity.x = direction * run_speed_fixed


## Apply jump force.
static func apply_jump(state: PlayerSnapshot, char_data: CharacterData) -> void:
	if state.is_grounded:
		state.velocity.y = int(char_data.jump_force * 1000)  # Negative = upward
		state.is_grounded = false


## Apply dash momentum.
static func apply_dash(state: PlayerSnapshot, direction: int, char_data: CharacterData) -> void:
	# direction: -1 = back, 1 = forward
	var dash_speed_fixed = int(char_data.dash_speed * 1000)
	state.velocity.x = direction * dash_speed_fixed


## Apply knockback from being hit.
static func apply_knockback(state: PlayerSnapshot, knockback: Vector2i) -> void:
	state.velocity.x = knockback.x
	state.velocity.y = knockback.y
	state.is_grounded = false  # Knockback always launches
