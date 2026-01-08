## Visual representation and game logic for a playable character.
##
## Responsibilities:
## - Visual rendering (sprite, animations)
## - Physics/movement
## - State machine coordination
## - Hitbox/hurtbox management
## - Move execution
##
## Design: Node2D for scene tree integration.
## Receives character data (moves, stats) at initialization.
## Owned by scene tree but referenced by PlayerContext.
class_name Character extends Node2D

## Character configuration (moves, stats, etc.)
var char_data: CharacterData

## Which direction the character is facing (true = right, false = left)
## Used for input interpretation (forward/back relative to facing)
var facing_right: bool = true


## Initialize character with data.
##
## Called by PlayerContext during setup.
##
## @param char_data_: CharacterData resource defining moves and stats
func _init(char_data_: CharacterData) -> void:
	char_data = char_data_


## Called when character is added to scene tree.
##
## TODO: Initialize visual components
## - Sprite setup
## - Animation player
## - Hitbox/hurtbox areas
func _ready() -> void:
	pass


## Frame-synchronized update function.
##
## Called once per physics frame by PlayerContext.tick().
##
## TODO: Implement core game logic
## - Update state machine
## - Process active hitboxes
## - Update animations
## - Handle move execution
##
## @param player_ctx: PlayerContext for access to input buffer, combat state
## @param frame: Current frame number from Match.frames_elapsed
func tick(player_ctx: PlayerContext, frame: int) -> void:
	pass
