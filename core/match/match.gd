## Main game coordinator for a match between two players.
##
## NEW ARCHITECTURE:
## - Uses PlayerSnapshot for game state (not Character)
## - Systems process state (StateMachine, PhysicsSystem, CombatSystem)
## - CharacterView syncs visuals from state (presentation layer)
##
## Responsibilities:
## - Frame counting (deterministic tick rate)
## - State management (PlayerSnapshots)
## - System coordination (tick order)
## - Visual sync
##
## Design: Root node for match scene.
## Physics-synchronized: _physics_process ensures 60 FPS fixed update.
class_name Match extends Node

## Number of frames elapsed since match start (deterministic game time)
var frames_elapsed: int = 0

## Whether the match is actively running
var running: bool = true

## ============ GAME STATE (Core) ============
## Player 1 complete game state
var p1_state: PlayerSnapshot

## Player 2 complete game state
var p2_state: PlayerSnapshot

## ============ PRESENTATION LAYER ============
## Player 1 visual representation
var p1_view: CharacterView

## Player 2 visual representation
var p2_view: CharacterView

## ============ INPUT LAYER ============
## Player controllers (still used for input polling)
var p1_controller: PlayerController
var p2_controller: PlayerController

## ============ CHARACTER DATA ============
## Character definitions (moves, stats)
var p1_char_data: CharacterData
var p2_char_data: CharacterData

## Initialize match when added to scene tree.
##
## NEW ARCHITECTURE:
## 1. Create game state (PlayerSnapshots)
## 2. Create visual representations (CharacterViews)
## 3. Create input controllers
## 4. Initialize systems
func _ready() -> void:
	# Load character data (TODO: From character select screen)
	p1_char_data = CharacterData.new()
	p2_char_data = CharacterData.new()
	
	# Create game state
	p1_state = PlayerSnapshot.new(1)
	p2_state = PlayerSnapshot.new(2)
	
	# Set initial positions (fixed-point)
	p1_state.position = Vector2i(200000, PhysicsSystem.GROUND_Y)  # 200px
	p2_state.position = Vector2i(600000, PhysicsSystem.GROUND_Y)  # 600px
	p2_state.facing_right = false
	
	# Initialize health from character data
	p1_state.health = p1_char_data.max_hp
	p1_state.max_health = p1_char_data.max_hp
	p2_state.health = p2_char_data.max_hp
	p2_state.max_health = p2_char_data.max_hp
	
	# Create visual representations
	p1_view = CharacterView.new(p1_char_data)
	p2_view = CharacterView.new(p2_char_data)
	add_child(p1_view)
	add_child(p2_view)
	
	# Sync visuals to initial state
	p1_view.sync_from_state(p1_state)
	p2_view.sync_from_state(p2_state)
	
	# Create input controllers
	p1_controller = PlayerController.new(1)
	p2_controller = PlayerController.new(2)
	
	print("Match initialized!")
	print("P1 State: pos=%s, health=%d" % [p1_state.position, p1_state.health])
	print("P2 State: pos=%s, health=%d" % [p2_state.position, p2_state.health])


## Physics process runs at fixed 60 FPS.
##
## Ensures deterministic game logic independent of rendering framerate.
## This is critical for:
## - Frame-perfect inputs
## - Consistent hitbox timing
## - Replay accuracy
## - Potential netcode implementation
##
## @param _delta: Time since last physics frame (unused, we count frames)
func _physics_process(_delta: float) -> void:
	if running:
		frames_elapsed += 1
		tick()


## Core game loop tick called every physics frame.
##
## NEW ARCHITECTURE FLOW:
## 1. Input - Poll controllers and generate commands
## 2. State Machine - Process commands and state transitions
## 3. Physics - Apply movement, gravity, collision
## 4. Combat - Check hitbox collisions
## 5. Presentation - Sync visuals from state
func tick() -> void:
	# ============ 1. INPUT ============
	# Poll controllers with facing information
	p1_controller.tick(p1_state.facing_right, frames_elapsed)
	p2_controller.tick(p2_state.facing_right, frames_elapsed)
	
	# Get commands from buffers
	var p1_cmd = p1_controller.cmd_buffer.pop(frames_elapsed)
	var p2_cmd = p2_controller.cmd_buffer.pop(frames_elapsed)
	
	# ============ 2. STATE MACHINE ============
	var p1_transition = StateMachine.tick(p1_state, p1_cmd, p2_state, p1_char_data)
	var p2_transition = StateMachine.tick(p2_state, p2_cmd, p1_state, p2_char_data)
	
	if p1_transition:
		var old_move = p1_state.current_move
		var old_frame = p1_state.state_frame
		StateMachine.apply_transition(p1_state, p1_transition)
		
		# Debug: Print state transition with move info
		var move_name = "none"
		if p1_state.current_move:
			move_name = p1_state.current_move.name if p1_state.current_move.name else "unnamed_move"
		
		print("═══ P1 F%d ═══" % frames_elapsed)
		print("  Command: %s" % (Command.Type.keys()[p1_cmd.type] if p1_cmd else "none"))
		print("  State: %s → %s" % [StateMachine.StateID.keys()[p1_state.state_id], StateMachine.StateID.keys()[p1_state.state_id]])
		print("  Move: %s" % move_name)
		print("  Frame: %d → %d %s" % [old_frame, p1_state.state_frame, "(RESET)" if p1_state.state_frame == 0 else "(INHERITED)"])
		print("  Phase: %s" % StateMachine.get_attack_phase(p1_state))
	
	if p2_transition:
		var old_move = p2_state.current_move
		var old_frame = p2_state.state_frame
		StateMachine.apply_transition(p2_state, p2_transition)
		
		# Debug: Print state transition with move info
		var move_name = "none"
		if p2_state.current_move:
			move_name = p2_state.current_move.name if p2_state.current_move.name else "unnamed_move"
		
		print("═══ P2 F%d ═══" % frames_elapsed)
		print("  Command: %s" % (Command.Type.keys()[p2_cmd.type] if p2_cmd else "none"))
		print("  State: %s" % StateMachine.StateID.keys()[p2_state.state_id])
		print("  Move: %s" % move_name)
		print("  Frame: %d → %d %s" % [old_frame, p2_state.state_frame, "(RESET)" if p2_state.state_frame == 0 else "(INHERITED)"])
		print("  Phase: %s" % StateMachine.get_attack_phase(p2_state))
	
	# Increment state frame counters
	p1_state.state_frame += 1
	p2_state.state_frame += 1
	
	# Debug: Print current state info for attacking players
	if p1_state.state_id == StateMachine.StateID.ATTACK and p1_state.current_move:
		var phase = StateMachine.get_attack_phase(p1_state)
		print("  P1 Attacking: %s [%d/%d] %s" % [
			p1_state.current_move.name if p1_state.current_move.name else "unnamed",
			p1_state.state_frame,
			p1_state.current_move.startup_frames + p1_state.current_move.active_frames + p1_state.current_move.recovery_frames,
			phase.to_upper()
		])
	
	if p2_state.state_id == StateMachine.StateID.ATTACK and p2_state.current_move:
		var phase = StateMachine.get_attack_phase(p2_state)
		print("  P2 Attacking: %s [%d/%d] %s" % [
			p2_state.current_move.name if p2_state.current_move.name else "unnamed",
			p2_state.state_frame,
			p2_state.current_move.startup_frames + p2_state.current_move.active_frames + p2_state.current_move.recovery_frames,
			phase.to_upper()
		])
	
	# ============ 3. PHYSICS ============
	PhysicsSystem.tick(p1_state, p1_char_data)
	PhysicsSystem.tick(p2_state, p2_char_data)
	
	# ============ 4. COMBAT ============
	var hits = CombatSystem.check_collisions(p1_state, p2_state)
	for hit in hits:
		if hit.defender_id == 2:
			CombatSystem.apply_hit(p2_state, p1_state, hit, false)
		else:
			CombatSystem.apply_hit(p1_state, p2_state, hit, false)
	
	# Check combo resets
	CombatSystem.check_combo_reset(p1_state, p2_state)
	CombatSystem.check_combo_reset(p2_state, p1_state)
	
	# ============ 5. PRESENTATION ============
	p1_view.sync_from_state(p1_state)
	p2_view.sync_from_state(p2_state)
	
	# Reset frame flags
	p1_state.reset_frame_flags()
	p2_state.reset_frame_flags()


## Start or restart the match.
##
## Resets frame counter and enables running.
## TODO: Reset player states, positions, health.
func start() -> void:
	frames_elapsed = 0
	running = true
