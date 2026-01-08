## Container for all player-specific state and components.
##
## Central coordination point that owns:
## - PlayerController (input polling and command detection)
## - Character (visual and game logic)
## - CombatContext (health, meter, combo tracking)
##
## Design Pattern: This avoids circular dependencies.
## Controller receives context as parameter (not saved).
## Character saves context reference (needs it in multiple methods).
##
## RefCounted: Not in scene tree, owned by Match.
class_name PlayerContext extends RefCounted

## Player number (1 or 2)
var player_id: int

## Reference to Match for frame counter and opponent access
var match_: Match

## The character instance (visual + logic)
var character: Character

## Input polling and command detection
var controller: PlayerController

#var cmd_buffer: CommandBuffer  # Moved to controller

## Combat state tracking (health, meter, combo count, etc.)
var combat: CombatContext

## Reference to opponent's PlayerContext (set by Match after both created)
var opponent: PlayerContext


## Initialize player context with all components.
##
## Called by Match during setup. Creates controller, combat, and character.
##
## @param _player_id: Player number (1 or 2)
## @param _match: Reference to Match node
## @param _char_data: CharacterData resource for this player's character
func _init(
	_player_id: int,
	_match: Match,
	_char_data: CharacterData,
) -> void:
	player_id = _player_id
	match_ = _match
	
	# Create controller (loads input mapper)
	controller = PlayerController.new(_player_id)

	# Create combat tracking
	#cmd_buffer = CommandBuffer.new()  # Now owned by controller
	combat = CombatContext.new()

	# Create character instance
	character = Character.new(_char_data)


## Main tick function coordinating all player systems.
##
## Called once per physics frame by Match.tick().
## Orchestrates input → commands → character update flow.
##
## @param frame: Current frame number from Match.frames_elapsed
func tick(frame: int) -> void:
	# Step 1: Poll input and detect commands
	controller.tick(self, frame)
	
	# Step 2: Update character (state machine, moves, hitboxes)
	character.tick(self, frame)
