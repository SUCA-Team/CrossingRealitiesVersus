class_name CharacterData extends Resource

# ============ IDENTITY ============
@export_group("Identity")
@export var character_name: String = "Character"
@export var character_id: String = "char_000"
@export_multiline var description: String = ""
@export var portrait: Texture2D
@export var full_art: Texture2D
@export var character_scene: PackedScene  # Fighter scene

# ============ STATS ============
@export_group("Stats")
@export var max_hp: int = 1000
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 30.0  # per second

# ============ PHYSICS ============
@export_group("Physics")
@export var walk_speed: float = 200.0
@export var dash_speed: float = 400.0
@export var heavy_dash_speed: float = 500.0
@export var jump_force: float = -400.0
@export var gravity: float = 980.0
@export var air_jumps: int = 1
@export var weight: float = 1.0  # Affects knockback (0.8 = light, 1.2 = heavy)

# ============ MOVES ============
@export_group("Moves")
@export_subgroup("Normals")
@export var neutral_light: MoveData
@export var forward_light: MoveData
@export var back_light: MoveData
@export var down_light: MoveData
@export var air_light: MoveData
@export var neutral_heavy: MoveData
@export var down_heavy: MoveData
@export var air_heavy: MoveData

@export_subgroup("Specials")
# Skill 1
@export var skill1_neutral: MoveData
@export var skill1_down: MoveData
@export var skill1_neutral_enhanced: MoveData
@export var skill1_down_enhanced: MoveData

# Skill 2
@export var skill2_neutral: MoveData
@export var skill2_down: MoveData
@export var skill2_neutral_enhanced: MoveData
@export var skill2_down_enhanced: MoveData

# Skill 3
@export var skill3_neutral: MoveData
@export var skill3_down: MoveData
@export var skill3_neutral_enhanced: MoveData
@export var skill3_down_enhanced: MoveData

@export_subgroup("Ultimates")
@export var super1: MoveData  # S1+S2
@export var super2: MoveData  # S2+S3
@export var super3: MoveData  # S1+S3
@export var ultimate: MoveData  # S1+S2+S3

# ============ PASSIVE & METER ============
#@export_group("Character Mechanics")
#@export var passive_ability: PassiveData
#@export var character_meter: CharacterMeter

# ============ AUDIO/VISUAL ============
@export_group("Presentation")
@export var voice_lines: Dictionary = {}  # action_name: AudioStream
@export var intro_animation: String = "intro"
@export var victory_animation: String = "victory"

# ============ METHODS ============
func get_move_by_name(move_name: String) -> MoveData:
	match move_name:
		"neutral_light": return neutral_light
		"forward_light": return forward_light
		"back_light": return back_light
		"down_light": return down_light
		"air_light": return air_light
		"neutral_heavy": return neutral_heavy
		"down_heavy": return down_heavy
		"air_heavy": return air_heavy
		# ... (all 28 moves)
	return null

func get_all_normals() -> Array[MoveData]:
	return [
		neutral_light, forward_light, back_light, down_light, air_light,
		neutral_heavy, down_heavy, air_heavy
	]

func get_all_specials() -> Array[MoveData]:
	return [
		skill1_neutral, skill1_down, skill1_neutral_enhanced, skill1_down_enhanced,
		skill2_neutral, skill2_down, skill2_neutral_enhanced, skill2_down_enhanced,
		skill3_neutral, skill3_down, skill3_neutral_enhanced, skill3_down_enhanced
	]

func get_all_ultimates() -> Array[MoveData]:
	return [super1, super2, super3, ultimate]

func validate() -> bool:
	# Ensure all 24 moves are defined (excluding 4 universal actions)
	var moves = get_all_normals() + get_all_specials() + get_all_ultimates()
	for move in moves:
		if move == null:
			push_error("Character %s missing move!" % character_name)
			return false
	return true
