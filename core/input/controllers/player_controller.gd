## Polls input and converts raw keyboard input into high-level commands.
##
## Responsibilities:
## 1. Poll Godot's Input system each frame
## 2. Convert physical keys to bitmasks (via InputMapper)
## 3. Detect button presses vs holds (via InputState)
## 4. Map input combinations to Commands (considering character facing)
## 5. Buffer commands for lenient execution
##
## Design: RefCounted owned by PlayerContext.
## Frame-synchronized: tick() called once per physics frame.
class_name PlayerController extends RefCounted

## Which player this controller belongs to (1 or 2)
var player_id: int

## Mapping of logical actions to physical keys (loaded from .tres)
var keymap: InputMapper

## Tracks input state changes for press detection
var input_state: InputState = InputState.new()

## Buffer for storing detected commands
var cmd_buffer: CommandBuffer = CommandBuffer.new()

#var last_input: InputData = null  # TODO: For display/replay

func _init(index: int) -> void:
	player_id = index
	match index:
		1:
			keymap = preload("res://core/input/mapping/p1_input_mapper.tres")
		2:
			keymap = preload("res://core/input/mapping/p2_input_mapper.tres")
		_:
			assert(false, "Invalid player index")
	
	# Verify keymap loaded successfully
	if not keymap:
		push_error("Failed to load keymap for player %d" % index)
		push_error("Make sure input mapper .tres files exist and are valid")
		return
	
	# Debug: Print loaded keymap
	print("Player %d keymap loaded successfully" % index)


## Poll all mapped inputs and convert to bitmask.
##
## Queries Godot's Input system for each action in keymap.
## Combines pressed inputs using bitwise OR.
##
## @return: Bitmask of all currently held inputs
func _poll_raw_input() -> int:
	var mask := 0

	# Directional inputs
	if Input.is_action_pressed(keymap.left):
		mask |= InputBits.LEFT
	if Input.is_action_pressed(keymap.right):
		mask |= InputBits.RIGHT
	if Input.is_action_pressed(keymap.up):
		mask |= InputBits.UP
	if Input.is_action_pressed(keymap.down):
		mask |= InputBits.DOWN

	# Action buttons
	if Input.is_action_pressed(keymap.light):
		mask |= InputBits.LIGHT
	if Input.is_action_pressed(keymap.heavy):
		mask |= InputBits.HEAVY
	if Input.is_action_pressed(keymap.dash):
		mask |= InputBits.DASH
	if Input.is_action_pressed(keymap.special1):
		mask |= InputBits.SPECIAL1
	if Input.is_action_pressed(keymap.special2):
		mask |= InputBits.SPECIAL2
	if Input.is_action_pressed(keymap.special3):
		mask |= InputBits.SPECIAL3

	return mask


## Check if input represents forward direction relative to character facing.
##
## @param input: InputData to check
## @param facing_right: Character's facing direction
## @return: true if pressing forward relative to facing
func _is_forward(input: InputData, facing_right: bool) -> bool:
	if facing_right:
		return input.held_mask & InputBits.RIGHT
	else:
		return input.held_mask & InputBits.LEFT


## Check if input represents back direction relative to character facing.
##
## @param input: InputData to check
## @param facing_right: Character's facing direction
## @return: true if pressing back relative to facing
func _is_back(input: InputData, facing_right: bool) -> bool:
	if facing_right:
		return input.held_mask & InputBits.LEFT
	else:
		return input.held_mask & InputBits.RIGHT


## Check if input has down direction.
##
## @param input: InputData to check
## @return: true if down is held
func _is_down(input: InputData) -> bool:
	return input.held_mask & InputBits.DOWN


## Check if input is down-forward (charge direction for some moves).
##
## @param input: InputData to check
## @param facing_right: Character's facing direction
## @return: true if both down and forward are held
func _is_downforward(input: InputData, facing_right: bool) -> bool:
	return _is_down(input) and _is_forward(input, facing_right)


## Check if input is down-back (common for defensive options).
##
## @param input: InputData to check
## @param facing_right: Character's facing direction
## @return: true if both down and back are held
func _is_downback(input: InputData, facing_right: bool) -> bool:
	return _is_down(input) and _is_back(input, facing_right)


## Map raw input to high-level commands and add to buffer.
##
## Detects button presses combined with directional modifiers.
## Priority order matters: specific combinations before generic.
##
## TODO: Complete implementation
## - Add all Command.Type mappings
## - Implement priority ordering (complex commands first)
## - Add air vs ground state checks
## - Detect simultaneous button presses for supers/ultimate
##
## @param facing_right: Character's facing direction
## @param input: Current frame's InputData
func _map_command(facing_right: bool, input: InputData) -> void:
	# ============ MULTI-BUTTON DETECTION (Real Fighting Game Approach) ============
	# Key insight: Check combinations FIRST, then mask out those buttons from singles
	# This prevents "Special1" from firing when you're doing "SUPER12"
	
	var s1_active = (input.held_mask & InputBits.SPECIAL1)
	var s2_active = (input.held_mask & InputBits.SPECIAL2)
	var s3_active = (input.held_mask & InputBits.SPECIAL3)
	var s1_pressed = (input.pressed_mask & InputBits.SPECIAL1)
	var s2_pressed = (input.pressed_mask & InputBits.SPECIAL2)
	var s3_pressed = (input.pressed_mask & InputBits.SPECIAL3)
	
	# Track which special buttons were consumed by combos
	var special_buttons_consumed = 0
	
	# ============ ULTIMATE - All 3 special buttons ============
	if s1_active and s2_active and s3_active:
		if s1_pressed or s2_pressed or s3_pressed:
			var cmd = Command.new(Command.Type.ULTIMATE, input.frame)
			cmd_buffer.push(cmd)
			print("P%d INPUT: ULTIMATE (frame %d)" % [player_id, input.frame])
			return  # Combo detected, don't check anything else
	
	# ============ SUPER MOVES - 2 button combinations ============
	# SUPER12 - Special1 + Special2
	if s1_active and s2_active:
		if s1_pressed or s2_pressed:
			var cmd = Command.new(Command.Type.SUPER12, input.frame)
			cmd_buffer.push(cmd)
			print("P%d INPUT: SUPER12 (frame %d)" % [player_id, input.frame])
			return  # Combo detected, don't check singles
	
	# SUPER23 - Special2 + Special3
	if s2_active and s3_active:
		if s2_pressed or s3_pressed:
			var cmd = Command.new(Command.Type.SUPER23, input.frame)
			cmd_buffer.push(cmd)
			print("P%d INPUT: SUPER23 (frame %d)" % [player_id, input.frame])
			return
	
	# SUPER13 - Special1 + Special3
	if s1_active and s3_active:
		if s1_pressed or s3_pressed:
			var cmd = Command.new(Command.Type.SUPER13, input.frame)
			cmd_buffer.push(cmd)
			print("P%d INPUT: SUPER13 (frame %d)" % [player_id, input.frame])
			return
	
	# ============ SINGLE BUTTON COMMANDS ============
	# If we reach here, no multi-button combo was detected
	# Singles fire immediately with no delay
	
	# ============ MOVEMENT ============
	if input.pressed_mask & InputBits.UP:
		var cmd = Command.new(Command.Type.JUMP, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: JUMP (frame %d)" % [player_id, input.frame])
		return
	
	# ============ LIGHT ATTACKS (specific to general) ============
	if _is_forward(input, facing_right) and (input.pressed_mask & InputBits.LIGHT):
		var cmd = Command.new(Command.Type.LIGHT_FORWARD, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: LIGHT_FORWARD (frame %d)" % [player_id, input.frame])
		return
	
	if _is_back(input, facing_right) and (input.pressed_mask & InputBits.LIGHT):
		var cmd = Command.new(Command.Type.LIGHT_BACK, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: LIGHT_BACK (frame %d)" % [player_id, input.frame])
		return
	
	if _is_down(input) and (input.pressed_mask & InputBits.LIGHT):
		var cmd = Command.new(Command.Type.LIGHT_DOWN, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: LIGHT_DOWN (frame %d)" % [player_id, input.frame])
		return
	
	if input.pressed_mask & InputBits.LIGHT:
		var cmd = Command.new(Command.Type.LIGHT_NEUTRAL, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: LIGHT_NEUTRAL (frame %d)" % [player_id, input.frame])
		return
	
	# ============ HEAVY ATTACKS ============
	if _is_down(input) and (input.pressed_mask & InputBits.HEAVY):
		var cmd = Command.new(Command.Type.HEAVY_DOWN, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: HEAVY_DOWN (frame %d)" % [player_id, input.frame])
		return
	
	if input.pressed_mask & InputBits.HEAVY:
		var cmd = Command.new(Command.Type.HEAVY_NEUTRAL, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: HEAVY_NEUTRAL (frame %d)" % [player_id, input.frame])
		return
	
	# ============ DASH VARIANTS ============
	if _is_forward(input, facing_right) and (input.pressed_mask & InputBits.DASH):
		var cmd = Command.new(Command.Type.GRAB, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: GRAB (frame %d)" % [player_id, input.frame])
		return
	
	if _is_back(input, facing_right) and (input.pressed_mask & InputBits.DASH):
		var cmd = Command.new(Command.Type.EVADE, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: EVADE (frame %d)" % [player_id, input.frame])
		return
	
	if _is_down(input) and (input.pressed_mask & InputBits.DASH):
		var cmd = Command.new(Command.Type.HEAVYDASH, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: HEAVYDASH (frame %d)" % [player_id, input.frame])
		return
	
	if input.pressed_mask & InputBits.DASH:
		var cmd = Command.new(Command.Type.DASH, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: DASH (frame %d)" % [player_id, input.frame])
		return
	
	# ============ ENHANCED SPECIALS (check modifier held for EX version) ============
	# Check if Dash button is HELD (not pressed) for enhanced versions
	var is_enhanced = input.held_mask & InputBits.DASH
	
	# Special 1
	if _is_down(input) and (input.pressed_mask & InputBits.SPECIAL1):
		var cmd_type = Command.Type.SPECIAL1_DOWN_E if is_enhanced else Command.Type.SPECIAL1_DOWN
		var cmd = Command.new(cmd_type, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: %s (frame %d)" % [player_id, Command.Type.keys()[cmd_type], input.frame])
		return
	
	if input.pressed_mask & InputBits.SPECIAL1:
		var cmd_type = Command.Type.SPECIAL1_NEUTRAL_E if is_enhanced else Command.Type.SPECIAL1_NEUTRAL
		var cmd = Command.new(cmd_type, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: %s (frame %d)" % [player_id, Command.Type.keys()[cmd_type], input.frame])
		return
	
	# Special 2
	if _is_down(input) and (input.pressed_mask & InputBits.SPECIAL2):
		var cmd_type = Command.Type.SPECIAL2_DOWN_E if is_enhanced else Command.Type.SPECIAL2_DOWN
		var cmd = Command.new(cmd_type, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: %s (frame %d)" % [player_id, Command.Type.keys()[cmd_type], input.frame])
		return
	
	if input.pressed_mask & InputBits.SPECIAL2:
		var cmd_type = Command.Type.SPECIAL2_NEUTRAL_E if is_enhanced else Command.Type.SPECIAL2_NEUTRAL
		var cmd = Command.new(cmd_type, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: %s (frame %d)" % [player_id, Command.Type.keys()[cmd_type], input.frame])
		return
	
	# Special 3
	if _is_down(input) and (input.pressed_mask & InputBits.SPECIAL3):
		var cmd_type = Command.Type.SPECIAL3_DOWN_E if is_enhanced else Command.Type.SPECIAL3_DOWN
		var cmd = Command.new(cmd_type, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: %s (frame %d)" % [player_id, Command.Type.keys()[cmd_type], input.frame])
		return
	
	if input.pressed_mask & InputBits.SPECIAL3:
		var cmd_type = Command.Type.SPECIAL3_NEUTRAL_E if is_enhanced else Command.Type.SPECIAL3_NEUTRAL
		var cmd = Command.new(cmd_type, input.frame)
		cmd_buffer.push(cmd)
		print("P%d INPUT: %s (frame %d)" % [player_id, Command.Type.keys()[cmd_type], input.frame])
		return


## Main tick function called every frame.
##
## Flow:
## 1. Poll raw input from keyboard
## 2. Update input state (for press detection)
## 3. Create InputData snapshot
## 4. Map input to commands
## 5. (Debug: print buffered commands)
##
## @param facing_right: Which direction the character is facing (for forward/back detection)
## @param frame: Current frame number from Match.frames_elapsed
func tick(facing_right: bool, frame: int) -> void:
	# Step 1: Get current input mask
	var raw: int = _poll_raw_input()
	
	# Step 2: Update state for press detection
	input_state.update(raw)
	
	# Step 3: Create input snapshot
	var input: InputData = InputData.new(player_id, frame,
			input_state.curr_mask, input_state.pressed())
	
	# Step 4: Convert to commands
	_map_command(facing_right, input)
