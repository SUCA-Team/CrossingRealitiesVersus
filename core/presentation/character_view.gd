## Visual representation that syncs from game state.
##
## PRESENTATION LAYER - Read-only!
## Never modifies game state, only reads from PlayerSnapshot.
##
## Responsibilities:
## - Sprite rendering
## - Animation playback
## - Visual effects (particles, etc.)
## - Camera following (optional)
##
## Design: Node2D in scene tree.
## Synced every frame via sync_from_state(PlayerSnapshot).
## Has NO gameplay logic - all logic is in systems.
class_name CharacterView extends Node2D

## Visual components (add in _ready)
var sprite: Sprite2D
var anim_player: AnimationPlayer

## Character visual data
var char_data: CharacterData


func _init(char_data_: CharacterData) -> void:
	char_data = char_data_


func _ready() -> void:
	# TODO: Create visual components
	# sprite = Sprite2D.new()
	# add_child(sprite)
	# 
	# anim_player = AnimationPlayer.new()
	# add_child(anim_player)
	
	# Temporary: Create a colored rectangle to see the character
	var colored_rect = ColorRect.new()
	colored_rect.size = Vector2(80, 160)
	colored_rect.position = Vector2(-40, -160)  # Center on position
	colored_rect.color = Color(0.8, 0.3, 0.3)  # Red-ish
	add_child(colored_rect)


## Sync visual representation from game state.
##
## Called every frame by Match.tick().
## Reads PlayerSnapshot and updates visuals accordingly.
##
## @param snapshot: PlayerSnapshot with current game state
func sync_from_state(snapshot: PlayerSnapshot) -> void:
	# Position (convert from fixed-point to float)
	position.x = snapshot.position.x / 1000.0
	position.y = snapshot.position.y / 1000.0
	
	# Facing direction (flip sprite)
	scale.x = 1.0 if snapshot.facing_right else -1.0
	
	# Animation (map state ID to animation name)
	# var anim_name = _get_animation_for_state(snapshot.state_id)
	# if anim_player and anim_player.current_animation != anim_name:
	# 	anim_player.play(anim_name)
	
	# TODO: Health bar updates
	# TODO: Visual effects (hit sparks, etc.)


## Map state ID to animation name.
static func _get_animation_for_state(state_id: int) -> String:
	match state_id:
		StateMachine.StateID.IDLE:
			return "idle"
		StateMachine.StateID.RUN:
			return "run"
		StateMachine.StateID.AIR:
			return "jump"
		StateMachine.StateID.LAND:
			return "land"
		StateMachine.StateID.DASH, \
		StateMachine.StateID.DASH_RECOVERY:
			return "dash"
		StateMachine.StateID.ATTACK:
			return "attack"  # TODO: Get specific animation from current_move
		StateMachine.StateID.BLOCKSTUN:
			return "block"
		StateMachine.StateID.HITSTUN_GROUND, StateMachine.StateID.HITSTUN_AIR:
			return "hurt"
		StateMachine.StateID.KNOCKDOWN:
			return "knockdown"
		StateMachine.StateID.RECOVERY:
			return "recovery"
		_:
			return "idle"
