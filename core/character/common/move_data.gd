class_name MoveData extends Resource

# ============ IDENTIFICATION ============
@export_group("Identity")
@export var move_name: String = "Move"
@export var move_id: String = "move_001"
@export_multiline var description: String = ""
@export var move_type: MoveType = MoveType.NORMAL
@export var hit_priority: HitPriority = HitPriority.MEDIUM

enum MoveType { NORMAL, SPECIAL, ULTIMATE }
enum HitPriority { LOW, MEDIUM, HIGH, HIGHEST }

# ============ ANIMATION ============
@export_group("Animation")
@export var animation_name: String = "idle"

# ============ FRAME DATA ============
@export_group("Frame Data")
@export var startup_frames: int = 5
@export var active_frames: int = 3
@export var recovery_frames: int = 10

# ============ DAMAGE ============
@export_group("Damage")
@export var damage: int = 50
@export var chip_damage_multiplier: float = 0.1
@export var scales_in_combo: bool = true

# ============ RESOURCES ============
@export_group("Resource Costs")
@export var stamina_cost: float = 5.0
@export var meter_cost: float = 0.0

# ============ HITSTUN/BLOCKSTUN ============
@export_group("Stun Properties")
@export var hitstun_frames: int = 15
@export var blockstun_frames: int = 8
@export var hitstun_scaling: bool = true  # Scales with combo count

# ============ KNOCKBACK ============
@export_group("Knockback")
@export var knockback_force: Vector2 = Vector2(200, -100)
@export var knockback_on_block: Vector2 = Vector2(50, 0)

# ============ HIT PROPERTIES ============
@export_group("Hit Properties")
@export var launches: bool = false
@export var ground_bounce: bool = false
@export var wall_bounce: bool = false
@export var hard_knockdown: bool = false

# ============ HITBOXES ============
@export_group("Hitboxes")
#@export var hitbox_data: Array[HitboxData] = []

# ============ CANCEL PROPERTIES ============
@export_group("Cancel Options")
@export var cancellable_on_hit: bool = true
@export var cancellable_on_block: bool = true
@export var cancellable_on_whiff: bool = true
@export var cancel_window_start: int = 0  # Frame number
@export var cancel_window_end: int = 0
@export var cancellable_into: Array[String] = []  # Move names

# ============ STATUS EFFECTS ============
@export_group("Status Effects")
#@export var on_hit_status: StatusEffect = null
#@export var on_block_status: StatusEffect = null
#@export var self_buff_on_use: StatusEffect = null

# ============ MOVEMENT ============
@export_group("Movement")
@export var has_forward_momentum: bool = true
@export var momentum_speed: float = 100.0
@export var locks_movement: bool = true  # Character cannot move during move

# ============ INPUT REQUIREMENTS ============
@export_group("Input")
#@export var input_command: InputCommand
@export var air_ok: bool = false
@export var ground_only: bool = false

# ============ VFX/SFX ============
@export_group("Effects")
@export var startup_effect: PackedScene
@export var hit_effect: PackedScene
@export var block_effect: PackedScene
@export var sound_effect: AudioStream
@export var voice_line: AudioStream

# ============ METHODS ============
func get_total_frames() -> int:
	return startup_frames + active_frames + recovery_frames

func is_frame_active(frame: int) -> bool:
	return frame >= startup_frames and frame < startup_frames + active_frames

func calculate_scaled_damage(combo_count: int, scaling_factor: float = 0.9) -> int:
	if not scales_in_combo or combo_count == 0:
		return damage
	return int(damage * pow(scaling_factor, combo_count - 1))

func get_on_hit_advantage() -> int:
	return hitstun_frames - recovery_frames

func get_on_block_advantage() -> int:
	return blockstun_frames - recovery_frames

func is_plus_on_hit() -> bool:
	return get_on_hit_advantage() > 0

func is_plus_on_block() -> bool:
	return get_on_block_advantage() > 0
