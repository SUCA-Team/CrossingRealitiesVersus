## Data-driven state machine using enum IDs instead of State objects.
##
## Processes state transitions based on:
## - Current state
## - Input commands
## - Frame counting
## - Opponent state
##
## Design: Stateless processor (RefCounted).
## All state stored in PlayerSnapshot, not in this class.
## This enables deterministic re-simulation for rollback.
class_name StateMachine extends RefCounted

## All possible states a character can be in.
## Using enum IDs (not State objects) for:
## - Easy serialization (just an int)
## - No polymorphism overhead
## - Clear state listing
enum StateID {
	## ============ UNIVERSAL STATES ============
	IDLE,               # Standing still
	RUN,                # Running (direction in velocity)
	
	## ============ MOVEMENT ============
	AIR,           # In the air (falling or jumping)
	LAND,            # Landing recovery frames
	
	DASH,            # Active dash (can cancel into attacks)
	DASH_RECOVERY,      # Dash ending lag
	
	## ============ DEFENSIVE ============
	BLOCK,              # Blocking
	BLOCKSTUN,          # Blocking an attack
	HITSTUN_GROUND,     # Hit while grounded
	HITSTUN_AIR,        # Hit while airborne
	KNOCKDOWN,          # Lying on ground
	RECOVERY,             # Getting up from knockdown
	
	## ============ ATTACKS ============
	## Single state for all attacks!
	## Phase (startup/active/recovery) tracked by:
	## - current_move: MoveData reference
	## - state_frame: Current frame in the move
	## Note: BACK/FORWARD attack modifiers (e.g., LIGHT_FORWARD)
	## are determined by relative player positions, not facing_right
	ATTACK,          # Performing any attack
	
	## ============ SPECIALS (if they need unique behavior) ============
	## Only create separate states if they have special mechanics
	## Otherwise, use ATTACKING with MoveData
	# SPECIAL_PROJECTILE,   # Future: If projectile attacks need unique logic
	# SPECIAL_COMMAND_GRAB, # Future: If grabs need unique collision
	# SPECIAL_COUNTER,      # Future: If counter states need unique logic
}


## Result of state transition logic.
## Tells Match what state to transition to and with what move data.
class StateTransition:
	var next_state: StateID
	var move_data: MoveData  # If starting an attack
	var reset_frame: bool = true  # Reset state_frame counter?
	
	func _init(_next_state: StateID, _move_data: MoveData = null, _reset: bool = true):
		next_state = _next_state
		move_data = _move_data
		reset_frame = _reset


## Process state machine for one frame.
##
## Checks for:
## 1. Automatic state progressions (startup → active → recovery)
## 2. Command input transitions
## 3. Physics-based transitions (landing, etc.)
##
## @param state: PlayerSnapshot with current state
## @param cmd: Command from input buffer (can be null)
## @param opponent: Opponent's PlayerSnapshot (for distance checks, etc.)
## @param char_data: CharacterData with move definitions
## @return: StateTransition if changing state, null otherwise
static func tick(
	state: PlayerSnapshot,
	cmd: Command,
	opponent: PlayerSnapshot,
	char_data: CharacterData
) -> StateTransition:
	
	# Decrement lockout timers
	state.tick_lockout()
	
	# Check if still in lockout (can't act)
	if state.lockout_frames > 0:
		return null  # No transition possible
	
	# Auto-progress attack states (startup → active → recovery → idle)
	var auto_transition = _check_auto_progression(state)
	if auto_transition:
		return auto_transition
	
	# Handle command input (if player inputted something)
	if cmd:
		var cmd_transition = _handle_command(state, cmd, char_data)
		if cmd_transition:
			return cmd_transition
	
	# Handle physics-based transitions (landing, etc.)
	var physics_transition = _check_physics_transitions(state)
	if physics_transition:
		return physics_transition
	
	return null  # No state change


## Check if current state should auto-progress to next phase.
## Example: Attack phases tracked by state_frame vs MoveData frame counts
static func _check_auto_progression(state: PlayerSnapshot) -> StateTransition:
	match state.state_id:
		StateID.ATTACK:
			if not state.current_move:
				# No move data? Return to idle
				return StateTransition.new(StateID.IDLE, null, true)
			
			# Calculate total attack duration
			var total_frames = (state.current_move.startup_frames + 
							   state.current_move.active_frames + 
							   state.current_move.recovery_frames)
			
			# Attack complete? Return to appropriate state
			if state.state_frame >= total_frames:
				var next_state = StateID.AIR if state.is_airborne() else StateID.IDLE
				return StateTransition.new(next_state, null, true)
		
		StateID.LAND:
			# TODO: Get landing frames from CharacterData
			if state.state_frame >= 4:
				return StateTransition.new(StateID.IDLE, null, true)
		
		StateID.DASH:
			# TODO: Get dash active frames from CharacterData
			if state.state_frame >= 15:
				return StateTransition.new(StateID.DASH_RECOVERY, null, true)
		
		StateID.DASH_RECOVERY:
			# TODO: Get dash recovery from CharacterData
			if state.state_frame >= 8:
				return StateTransition.new(StateID.IDLE, null, true)
	
	return null


## Handle command input and determine if it causes a state transition.
## Context-aware: same command does different things based on current state.
static func _handle_command(
	state: PlayerSnapshot,
	cmd: Command,
	char_data: CharacterData
) -> StateTransition:
	
	# ============ STARTUP CANCELS (Combo Detection Window) ============
	# If currently attacking and in startup frames (first 3 frames),
	# allow cancelling into super/ultimate/enhanced moves
	# This solves the "double-fire" problem elegantly!
	if state.state_id == StateID.ATTACK and state.current_move:
		var in_startup = state.state_frame < state.current_move.startup_frames
		var startup_cancel_window = state.state_frame < 3  # 3 frame window
		
		if in_startup and startup_cancel_window:
			# Check if this is a super/ultimate/enhanced command
			match cmd.type:
				Command.Type.ULTIMATE, \
				Command.Type.SUPER12, \
				Command.Type.SUPER23, \
				Command.Type.SUPER13, \
				Command.Type.SPECIAL1_NEUTRAL_E, \
				Command.Type.SPECIAL1_DOWN_E, \
				Command.Type.SPECIAL2_NEUTRAL_E, \
				Command.Type.SPECIAL2_DOWN_E, \
				Command.Type.SPECIAL3_NEUTRAL_E, \
				Command.Type.SPECIAL3_DOWN_E:
					# Allow cancelling into super/enhanced!
					# IMPORTANT: Don't reset state_frame - inherit the current frame
					# This prevents "free startup frames" by cancelling
					# TODO: Get actual super/enhanced move data from char_data
					var old_move_name = state.current_move.name if state.current_move.name else "unnamed"
					print("⚡ STARTUP CANCEL ⚡")
					print("  From: %s (frame %d)" % [old_move_name, state.state_frame])
					print("  To:   %s (inheriting frame %d)" % [Command.Type.keys()[cmd.type], state.state_frame])
					return StateTransition.new(StateID.ATTACK, state.current_move, false)  # false = don't reset frame!
	
	# Context-aware command processing
	# Same command (e.g., LIGHT_ATTACK) does different things based on state
	
	match [state.state_id, cmd.type]:
		# IDLE state transitions
		[StateID.IDLE, Command.Type.LIGHT_NEUTRAL]:
			if char_data.neutral_light:
				return StateTransition.new(StateID.ATTACK, char_data.neutral_light)
		
		[StateID.IDLE, Command.Type.LIGHT_FORWARD]:
			if char_data.forward_light:
				return StateTransition.new(StateID.ATTACK, char_data.forward_light)
		
		[StateID.IDLE, Command.Type.LIGHT_BACK]:
			if char_data.back_light:
				return StateTransition.new(StateID.ATTACK, char_data.back_light)
		
		[StateID.IDLE, Command.Type.LIGHT_DOWN]:
			if char_data.down_light:
				return StateTransition.new(StateID.ATTACK, char_data.down_light)
		
		[StateID.IDLE, Command.Type.HEAVY_NEUTRAL]:
			if char_data.neutral_heavy:
				return StateTransition.new(StateID.ATTACK, char_data.neutral_heavy)
		
		[StateID.IDLE, Command.Type.HEAVY_DOWN]:
			if char_data.down_heavy:
				return StateTransition.new(StateID.ATTACK, char_data.down_heavy)
		
		[StateID.IDLE, Command.Type.JUMP]:
			return StateTransition.new(StateID.AIR, null)
		
		[StateID.IDLE, Command.Type.DASH]:
			return StateTransition.new(StateID.DASH, null)
		
		# AIRBORNE state transitions
		[StateID.AIR, Command.Type.LIGHT_NEUTRAL], \
		[StateID.AIR, Command.Type.LIGHT_FORWARD], \
		[StateID.AIR, Command.Type.LIGHT_BACK], \
		[StateID.AIR, Command.Type.LIGHT_DOWN]:
			# All light attacks use aerial version when airborne
			if char_data.air_light:
				return StateTransition.new(StateID.ATTACK, char_data.air_light)
		
		[StateID.AIR, Command.Type.HEAVY_NEUTRAL], \
		[StateID.AIR, Command.Type.HEAVY_DOWN]:
			# All heavy attacks use aerial version when airborne
			if char_data.air_heavy:
				return StateTransition.new(StateID.ATTACK, char_data.air_heavy)
		
		# TODO: Add more command mappings
		# - Attack cancels (normal → special)
		# - Dash cancels
		# - Jump cancels
		# - Special moves
		# - Supers
	
	return null  # Command not valid in current state


## Check physics-based state transitions (landing, etc.).
static func _check_physics_transitions(state: PlayerSnapshot) -> StateTransition:
	# Landing transition
	if state.state_id == StateID.AIR and state.is_grounded:
		return StateTransition.new(StateID.LAND, null)
	
	return null


## Get which phase of attack the player is currently in.
## Returns: "startup", "active", "recovery", or "none"
static func get_attack_phase(state: PlayerSnapshot) -> String:
	if state.state_id != StateID.ATTACK or not state.current_move:
		return "none"
	
	var startup_end = state.current_move.startup_frames
	var active_end = startup_end + state.current_move.active_frames
	
	if state.state_frame < startup_end:
		return "startup"
	elif state.state_frame < active_end:
		return "active"
	else:
		return "recovery"


## Check if player is in active frames (for hitbox generation).
static func is_in_active_frames(state: PlayerSnapshot) -> bool:
	return get_attack_phase(state) == "active"
	# - Leaving ground (jump startup → airborne)
	# - Dash ending
	# - Knockdown recovery


## Apply a state transition to the snapshot.
## Updates state_id, state_frame, current_move, and related fields.
static func apply_transition(state: PlayerSnapshot, transition: StateTransition) -> void:
	state.state_id = transition.next_state
	state.current_move = transition.move_data
	
	if transition.reset_frame:
		state.state_frame = 0
	
	# Set lockout frames based on move data
	if transition.move_data:
		var total_frames = (
			transition.move_data.startup_frames +
			transition.move_data.active_frames +
			transition.move_data.recovery_frames
		)
		state.lockout_frames = total_frames
