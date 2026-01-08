## Main game coordinator for a match between two players.
##
## Responsibilities:
## - Frame counting (deterministic tick rate)
## - Player context management
## - Tick coordination (input → update → collision → render)
## - Match state (running, paused, ended)
## - Win condition checking
##
## Design: Root node for match scene.
## Physics-synchronized: _physics_process ensures 60 FPS fixed update.
class_name Match extends Node

## Number of frames elapsed since match start (deterministic game time)
var frames_elapsed: int = 0

## Whether the match is actively running
var running: bool = true

## Player 1 context (contains controller, character, combat)
var p1: PlayerContext

## Player 2 context
var p2: PlayerContext

## Direct character references (for convenience)
## TODO: Remove if redundant (accessible via p1.character / p2.character)
var char1: Character
var char2: Character


## Initialize match when added to scene tree.
##
## Creates both player contexts with default character data.
## TODO: Accept CharacterData parameters for character selection.
func _ready() -> void:
	p1 = PlayerContext.new(1, self, CharacterData.new())
	p2 = PlayerContext.new(2, self, CharacterData.new())
	
	# TODO: Set opponent references
	# p1.opponent = p2
	# p2.opponent = p1
	
	# TODO: Add characters to scene tree for rendering
	# add_child(p1.character)
	# add_child(p2.character)


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
## Coordinates all game systems in order:
## 1. Player 1 input and update
## 2. Player 2 input and update
## (TODO: Collision detection, win condition checks)
func tick() -> void:
	p1.tick(frames_elapsed)
	p2.tick(frames_elapsed)
	
	# TODO: Add post-update logic
	# - Collision detection
	# - Health checks
	# - Win condition
	# - Time limit


## Start or restart the match.
##
## Resets frame counter and enables running.
## TODO: Reset player states, positions, health.
func start() -> void:
	frames_elapsed = 0
	running = true

	
