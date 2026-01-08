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
			keymap = load("res://utils/input_mapper/p1_input_mapper.tres")
		2:
			keymap = load("res://utils/input_mapper/p2_input_mapper.tres")
		_:
			assert(false, "Invalid player index")


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
## @param ctx: PlayerContext for character facing direction
## @return: true if pressing forward relative to facing
func _is_forward(input: InputData, ctx: PlayerContext) -> bool:
	if ctx.character.facing_right:
		return input.held_mask & InputBits.RIGHT
	else:
		return input.held_mask & InputBits.LEFT


## Check if input represents back direction relative to character facing.
##
## @param input: InputData to check
## @param ctx: PlayerContext for character facing direction
## @return: true if pressing back relative to facing
func _is_back(input: InputData, ctx: PlayerContext) -> bool:
	if ctx.character.facing_right:
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
## @param ctx: PlayerContext for character facing direction
## @return: true if both down and forward are held
func _is_downforward(input: InputData, ctx: PlayerContext) -> bool:
	return _is_down(input) and _is_forward(input, ctx)


## Check if input is down-back (common for defensive options).
##
## @param input: InputData to check
## @param ctx: PlayerContext for character facing direction
## @return: true if both down and back are held
func _is_downback(input: InputData, ctx: PlayerContext) -> bool:
	return _is_down(input) and _is_back(input, ctx)


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
## @param ctx: PlayerContext for lockout/facing checks
## @param input: Current frame's InputData
func _map_command(ctx: PlayerContext, input: InputData) -> void:
	# TODO: Check lockout state
	#if ctx.lockout:
		#return

	# Light attack variants (most specific first)
	if _is_downforward(input, ctx) and (input.pressed_mask & InputBits.LIGHT):
		cmd_buffer.push(Command.new(Command.Type.LIGHT_FORWARD, input.frame))
		return  # Don't also trigger neutral

	if _is_downback(input, ctx) and (input.pressed_mask & InputBits.LIGHT):
		cmd_buffer.push(Command.new(Command.Type.LIGHT_BACK, input.frame))
		return

	# Neutral light (no modifier)
	if input.pressed_mask & InputBits.LIGHT:
		cmd_buffer.push(Command.new(Command.Type.LIGHT_NEUTRAL, input.frame))

	# TODO: Add remaining command mappings
	# - Heavy variants
	# - Dash variants (dash, heavy dash, grab, evade)
	# - Specials (neutral, down, enhanced)
	# - Supers (button combinations)


## Main tick function called every frame.
##
## Flow:
## 1. Poll raw input from keyboard
## 2. Update input state (for press detection)
## 3. Create InputData snapshot
## 4. Map input to commands
## 5. (Debug: print buffered commands)
##
## @param ctx: PlayerContext for character state access
## @param frame: Current frame number from Match.frames_elapsed
func tick(ctx: PlayerContext, frame: int) -> void:
	# Step 1: Get current input mask
	var raw: int = _poll_raw_input()
	
	# Step 2: Update state for press detection
	input_state.update(raw)
	
	# Step 3: Create input snapshot
	var input: InputData = InputData.new(player_id, frame,
			input_state.curr_mask, input_state.pressed())
	
	# Step 4: Convert to commands
	_map_command(ctx, input)
	
	# Debug: Show buffered commands
	for i in cmd_buffer.buffer:
		print(i.type)
	
