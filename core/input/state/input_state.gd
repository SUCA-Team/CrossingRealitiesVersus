## Tracks input state changes between frames for press detection.
##
## Maintains previous and current input masks to detect "just pressed" inputs.
## Essential for distinguishing held inputs from newly pressed ones.
##
## Design: RefCounted helper owned by PlayerController.
## Bitmasking allows efficient press detection: current & ~previous
class_name InputState extends RefCounted

## Input mask from the previous frame
var prev_mask: int = 0

## Input mask for the current frame
var curr_mask: int = 0


## Update state with new input mask, shifting current to previous.
##
## Called once per frame in PlayerController.tick() before polling.
##
## @param new_mask: Bitmask of currently held inputs from Input.is_action_pressed()
func update(new_mask: int) -> void:
	prev_mask = curr_mask
	curr_mask = new_mask


## Calculate bitmask of inputs pressed this frame (but not last frame).
##
## Uses bitwise AND with negated previous: current & ~previous
## Example: current=0b0011, previous=0b0001 → pressed=0b0010
##
## @return: Bitmask where each set bit represents a newly pressed input
func pressed() -> int:
	return curr_mask & ~prev_mask


## Check if a specific input is currently held.
##
## @param input_bit: InputBits constant to check (e.g., InputBits.LIGHT)
## @return: true if the input bit is set in current mask
func held(input_bit: int) -> bool:
	return curr_mask & input_bit


## Check if a specific input was just pressed this frame.
##
## Combines pressed() mask with the specific bit to check.
##
## @param input_bit: InputBits constant to check
## @return: true if the input was pressed this frame (not held last frame)
func just_pressed(input_bit: int) -> bool:
	return pressed() & input_bit
