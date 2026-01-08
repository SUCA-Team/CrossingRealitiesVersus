## High-level command representing a player action intent.
##
## Commands are derived from raw input by PlayerController._map_command().
## They abstract button combinations into gameplay-meaningful actions.
## Buffered in CommandBuffer for lenient execution timing.
##
## Design: Commands decouple input detection from execution, allowing:
## - Input buffering during lockout periods
## - Priority ordering (ultimates > specials > normals)
## - Frame-window leniency for execution
class_name Command extends RefCounted

## All possible command types mapped from input combinations.
##
## Naming convention: BUTTON_MODIFIER or SPECIAL_TYPE
## _E suffix = Enhanced/EX versions (costs meter/stamina)
enum Type {
	NULL,  # No command
	
	## Light attack variants
	LIGHT_NEUTRAL,   # Light button alone
	LIGHT_DOWN,      # Down + Light
	LIGHT_BACK,      # Back + Down + Light
	LIGHT_FORWARD,   # Forward + Down + Light
	
	## Heavy attack variants
	HEAVY_NEUTRAL,   # Heavy button alone
	HEAVY_DOWN,      # Down + Heavy
	
	## Dash command variants
	DASH,            # Dash button alone
	HEAVYDASH,       # Down + Dash
	GRAB,            # Forward + Down + Dash
	EVADE,           # Back + Down + Dash
	
	## Movement
	JUMP,            # Up input
	#JUMP_AIR,      # TODO: Double jump
	
	## Special moves (grounded)
	SPECIAL1_NEUTRAL,
	SPECIAL2_NEUTRAL,
	SPECIAL3_NEUTRAL,
	SPECIAL1_DOWN,
	SPECIAL2_DOWN,
	SPECIAL3_DOWN,
	
	## Enhanced specials (costs resources)
	SPECIAL1_NEUTRAL_E,
	SPECIAL2_NEUTRAL_E,
	SPECIAL3_NEUTRAL_E,
	SPECIAL1_DOWN_E,
	SPECIAL2_DOWN_E,
	SPECIAL3_DOWN_E,
	
	## Super/Ultimate moves (button combinations)
	SUPER12,         # Special1 + Special2
	SUPER23,         # Special2 + Special3
	SUPER13,         # Special1 + Special3
	ULTIMATE         # Special1 + Special2 + Special3
}

## The command type this represents
var type: Type

## Frame number when this command was detected (for buffer expiration)
var frame: int


## Create a new command with the specified type and frame.
##
## @param _type: Command.Type enum value
## @param _frame: Frame number from Match.frames_elapsed
func _init(_type: Type, _frame: int) -> void:
	type = _type
	frame = _frame
