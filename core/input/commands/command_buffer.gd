## Stores detected commands for buffered execution.
##
## Allows players to input commands slightly before they can execute,
## making the game feel more responsive. Commands expire after COMMAND_WINDOW frames.
##
## Design: RefCounted owned by PlayerController.
## Pop removes and returns valid commands within frame window.
class_name CommandBuffer extends RefCounted

## Maximum number of commands to store (prevents memory bloat)
const BUFFER_SIZE: int = 20

## Frame window for command validity (3 frames = 50ms at 60 FPS)
## Commands older than this are discarded
const COMMAND_WINDOW: int = 3

## Internal storage for buffered commands (oldest to newest)
var buffer: Array[Command] = []


## Add a new command to the buffer.
##
## Called by PlayerController._map_command() when input is detected.
## TODO: Implement BUFFER_SIZE limit to prevent unbounded growth.
##
## @param cmd: Command to buffer
func push(cmd: Command) -> void:
	buffer.append(cmd)
	if buffer.size() > BUFFER_SIZE:
		buffer.pop_front()


## Remove and return the first valid command within the frame window.
##
## Searches buffer for a command that's within COMMAND_WINDOW frames.
## Clears entire buffer if no valid command found (prevents stale inputs).
##
## @param current_frame: Current frame number from Match.frames_elapsed
## @return: Valid Command or null if buffer is empty/expired
func pop(current_frame: int) -> Command:
	for i in range(buffer.size()):
		var c := buffer[i]
		# Check if command is fresh enough
		if current_frame - c.frame <= COMMAND_WINDOW:
			buffer.remove_at(i)
			return c
	# No valid command found, clear stale buffer
	buffer.clear()
	return null
