# Character Data Structure & Design Guidelines
## Crossing Realities Versus

**Date:** January 3, 2026  

---

## 1. OVERVIEW

This document defines:
- Character data structure
- Move design guidelines
- Passive ability framework
- Character archetype templates
- Balance considerations

**Design Constraint:** Each character has exactly **28 moves** (hard limit).

---

## 2. CHARACTER DATA STRUCTURE

### 2.1. CharacterData Resource

```gdscript
class_name CharacterData
extends Resource

# ============ IDENTITY ============
@export_group("Identity")
@export var character_name: String = "Character"
@export var character_id: String = "char_001"
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
@export_group("Character Mechanics")
@export var passive_ability: PassiveData
@export var character_meter: CharacterMeter

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
```

---

## 3. MOVE DATA STRUCTURE

### 3.1. MoveData Resource (Detailed)

```gdscript
class_name MoveData
extends Resource

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
@export var hitbox_data: Array[HitboxData] = []
# Each move can have multiple hitboxes that spawn at different times
# Allows for multi-hit moves, disjointed hitboxes, etc.

# ============ CANCEL PROPERTIES ============
@export_group("Cancel Options")
@export var cancellable_on_hit: bool = false
@export var cancellable_on_block: bool = false
@export var cancellable_on_whiff: bool = false
@export var cancel_window_start: int = 0  # Frame number
@export var cancel_window_end: int = 0
@export var cancellable_into: Array[String] = []  # Move names

# ============ STATUS EFFECTS ============
@export_group("Status Effects")
@export var on_hit_status: StatusEffect = null
@export var on_block_status: StatusEffect = null
@export var self_buff_on_use: StatusEffect = null

# ============ MOVEMENT ============
@export_group("Movement")
@export var has_forward_momentum: bool = true
@export var momentum_speed: float = 100.0
@export var locks_movement: bool = true  # Character cannot move during move

# ============ INPUT REQUIREMENTS ============
@export_group("Input")
@export var input_command: InputCommand
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
```

---

### 3.2. HitboxData Resource

```gdscript
class_name HitboxData
extends Resource

# ============ IDENTIFICATION ============
@export_group("Identity")
@export var hitbox_name: String = "Hitbox"
@export var hitbox_id: int = 0  # Index in multi-hit moves

# ============ SHAPE & POSITION ============
@export_group("Shape")
@export var shape_type: ShapeType = ShapeType.RECTANGLE
@export var size: Vector2 = Vector2(50, 50)  # Width x Height for rectangle
@export var radius: float = 25.0  # For circle shape
@export var offset: Vector2 = Vector2(30, 0)  # Offset from fighter's position
@export var follows_fighter: bool = true  # Move with fighter or stay at spawn position

enum ShapeType { RECTANGLE, CIRCLE, CAPSULE }

# ============ TIMING ============
@export_group("Timing")
@export var spawn_frame: int = 5  # Frame when hitbox appears (relative to move start)
@export var duration_frames: int = 3  # How long hitbox stays active
@export var despawn_frame: int = 8  # Frame when hitbox disappears (auto-calculated if 0)

# ============ HIT PROPERTIES ============
@export_group("Hit Properties")
@export var damage: int = 50  # Can override move's base damage
@export var hitstun_frames: int = 0  # 0 = use move's hitstun
@export var blockstun_frames: int = 0  # 0 = use move's blockstun
@export var knockback: Vector2 = Vector2.ZERO  # ZERO = use move's knockback

# ============ HIT BEHAVIOR ============
@export_group("Hit Behavior")
@export var hit_type: HitType = HitType.NORMAL
@export var can_hit_multiple: bool = false  # Can hit same target multiple times
@export var max_hits: int = 1  # Max times this hitbox can hit (0 = unlimited)
@export var hit_priority: int = 1  # Higher priority beats lower priority hitboxes

enum HitType {
    NORMAL,      # Standard hit
    GRAB,        # Beats blocking
    PROJECTILE,  # Can be destroyed/reflected
    ANTI_AIR,    # Extra damage vs airborne
    THROW       # Unblockable grab
}

# ============ SPECIAL PROPERTIES ============
@export_group("Special Properties")
@export var is_disjointed: bool = false  # No hurtbox (weapon hitbox)
@export var is_invincible: bool = false  # Grants i-frames during active frames
@export var is_armor: bool = false  # Absorbs hits without interruption
@export var armor_hits: int = 1  # Number of hits armor can absorb

# ============ VISUAL ============
@export_group("Visual")
@export var show_debug: bool = true  # Show hitbox in debug mode
@export var debug_color: Color = Color(1, 0, 0, 0.3)  # Red transparent

# ============ METHODS ============
func get_despawn_frame() -> int:
    """Calculate when hitbox should despawn"""
    if despawn_frame > 0:
        return despawn_frame
    return spawn_frame + duration_frames

func is_active_on_frame(frame: int) -> bool:
    """Check if hitbox is active on given frame"""
    return frame >= spawn_frame and frame < get_despawn_frame()

func get_actual_damage() -> int:
    """Get damage value (can be overridden or use move's damage)"""
    return damage

func get_actual_knockback(move_knockback: Vector2) -> Vector2:
    """Get knockback (use override or move's knockback)"""
    if knockback != Vector2.ZERO:
        return knockback
    return move_knockback

func get_shape_collision() -> Shape2D:
    """Generate collision shape for this hitbox"""
    match shape_type:
        ShapeType.RECTANGLE:
            var rect = RectangleShape2D.new()
            rect.size = size
            return rect
        ShapeType.CIRCLE:
            var circle = CircleShape2D.new()
            circle.radius = radius
            return circle
        ShapeType.CAPSULE:
            var capsule = CapsuleShape2D.new()
            capsule.radius = size.x / 2.0
            capsule.height = size.y
            return capsule
    return null

func get_world_position(fighter_position: Vector2, facing_right: bool) -> Vector2:
    """Calculate world position of hitbox based on fighter position and facing"""
    var adjusted_offset = offset
    if not facing_right:
        adjusted_offset.x *= -1  # Flip horizontally
    return fighter_position + adjusted_offset
```

---

### 3.3. HitboxData Usage Examples

#### Example 1: Simple Single Hitbox (Jab)

```gdscript
# In move_data/jab.tres
[resource]
# ... move properties ...
hitbox_data = [
    {
        "hitbox_name": "Jab Hitbox",
        "shape_type": ShapeType.RECTANGLE,
        "size": Vector2(40, 30),
        "offset": Vector2(35, -10),
        "spawn_frame": 3,
        "duration_frames": 2,
        "hit_type": HitType.NORMAL
    }
]
```

#### Example 2: Multi-Hit Move (Triple Slash)

```gdscript
# In move_data/triple_slash.tres
[resource]
move_name = "Triple Slash"
startup_frames = 5
active_frames = 15
recovery_frames = 10

hitbox_data = [
    # First Hit
    {
        "hitbox_id": 0,
        "hitbox_name": "Slash 1",
        "spawn_frame": 5,
        "duration_frames": 2,
        "offset": Vector2(30, -10),
        "size": Vector2(50, 40),
        "damage": 30,
        "knockback": Vector2(50, 0)  # Small knockback
    },
    # Second Hit
    {
        "hitbox_id": 1,
        "hitbox_name": "Slash 2",
        "spawn_frame": 10,
        "duration_frames": 2,
        "offset": Vector2(40, -5),
        "size": Vector2(55, 45),
        "damage": 35,
        "knockback": Vector2(75, 0)
    },
    # Third Hit (Launcher)
    {
        "hitbox_id": 2,
        "hitbox_name": "Slash 3",
        "spawn_frame": 15,
        "duration_frames": 3,
        "offset": Vector2(45, -15),
        "size": Vector2(60, 50),
        "damage": 50,
        "knockback": Vector2(150, -200)  # Launch!
    }
]
```

#### Example 3: Disjointed Weapon Hitbox

```gdscript
# In move_data/sword_swing.tres
[resource]
hitbox_data = [
    {
        "hitbox_name": "Sword Arc",
        "shape_type": ShapeType.CIRCLE,
        "radius": 80,
        "offset": Vector2(60, -20),
        "spawn_frame": 8,
        "duration_frames": 4,
        "is_disjointed": true,  # Sword has no hurtbox
        "hit_priority": 2
    }
]
```

#### Example 4: Grab Hitbox

```gdscript
# In move_data/command_grab.tres
[resource]
hitbox_data = [
    {
        "hitbox_name": "Grab Box",
        "shape_type": ShapeType.RECTANGLE,
        "size": Vector2(45, 60),
        "offset": Vector2(30, 0),
        "spawn_frame": 6,
        "duration_frames": 2,
        "hit_type": HitType.GRAB,  # Beats blocking!
        "damage": 80
    }
]
```

#### Example 5: Invincible Reversal

```gdscript
# In move_data/dragon_punch.tres
[resource]
hitbox_data = [
    {
        "hitbox_name": "Rising Fist",
        "shape_type": ShapeType.CAPSULE,
        "size": Vector2(40, 80),
        "offset": Vector2(20, -40),
        "spawn_frame": 3,
        "duration_frames": 8,
        "is_invincible": true,  # I-frames during active frames
        "damage": 120,
        "knockback": Vector2(100, -300)
    }
]
```

#### Example 6: Armor Move

```gdscript
# In move_data/heavy_tackle.tres
[resource]
hitbox_data = [
    {
        "hitbox_name": "Armored Rush",
        "shape_type": ShapeType.RECTANGLE,
        "size": Vector2(60, 70),
        "offset": Vector2(40, 0),
        "spawn_frame": 10,
        "duration_frames": 15,
        "is_armor": true,  # Absorbs hits
        "armor_hits": 2,  # Can tank 2 hits
        "damage": 90,
        "has_forward_momentum": true
    }
]
```

---

### 3.4. ProjectileData Resource

```gdscript
class_name ProjectileData
extends Resource

# ============ IDENTIFICATION ============
@export_group("Identity")
@export var projectile_name: String = "Projectile"
@export var projectile_id: String = "proj_001"

# ============ VISUAL ============
@export_group("Visual")
@export var projectile_scene: PackedScene  # Custom projectile scene
@export var sprite: Texture2D
@export var animation_name: String = "travel"
@export var scale: Vector2 = Vector2(1, 1)
@export var rotation_speed: float = 0.0  # Degrees per frame (spinning projectiles)

# ============ MOVEMENT ============
@export_group("Movement")
@export var movement_type: MovementType = MovementType.LINEAR
@export var speed: float = 300.0  # Pixels per second
@export var acceleration: float = 0.0  # For accelerating projectiles
@export var max_speed: float = 600.0  # Cap for accelerating projectiles
@export var gravity_multiplier: float = 0.0  # 0 = no gravity, 1.0 = normal gravity
@export var homing_strength: float = 0.0  # 0 = no homing, 1.0 = instant turn
@export var homing_duration_frames: int = 0  # How long homing is active (0 = infinite)
@export var arc_height: float = 0.0  # For arcing projectiles
@export var wave_amplitude: float = 0.0  # For wave pattern projectiles
@export var wave_frequency: float = 1.0  # Waves per second

enum MovementType {
    LINEAR,      # Straight line
    ARCING,      # Parabolic arc
    HOMING,      # Tracks target
    WAVE,        # Sine wave pattern
    BOOMERANG,   # Returns to sender
    STATIONARY   # Doesn't move (trap/mine)
}

# ============ LIFETIME ============
@export_group("Lifetime")
@export var lifetime_frames: int = 180  # 3 seconds at 60 FPS (0 = infinite)
@export var max_distance: float = 0.0  # Max travel distance (0 = unlimited)
@export var despawn_on_hit: bool = true  # Destroy after hitting
@export var pierce_count: int = 0  # How many targets it can hit (0 = one target only)

# ============ HITBOX ============
@export_group("Hitbox")
@export var hitbox_shape: HitboxData.ShapeType = HitboxData.ShapeType.CIRCLE
@export var hitbox_size: Vector2 = Vector2(20, 20)
@export var hitbox_radius: float = 15.0
@export var damage: int = 40
@export var hitstun_frames: int = 12
@export var blockstun_frames: int = 8
@export var knockback: Vector2 = Vector2(100, -50)
@export var chip_damage_multiplier: float = 0.15  # Usually higher for projectiles

# ============ BEHAVIOR ============
@export_group("Behavior")
@export var can_be_reflected: bool = true  # Can be reflected back
@export var can_be_destroyed: bool = true  # Can be destroyed by attacks
@export var projectile_health: int = 1  # Hits needed to destroy (0 = invincible)
@export var destroys_other_projectiles: bool = false  # Destroys enemy projectiles on contact
@export var multi_hit: bool = false  # Can hit same target multiple times
@export var hit_interval_frames: int = 10  # Frames between multi-hits

# ============ SPECIAL PROPERTIES ============
@export_group("Special Properties")
@export var spawns_on_destroy: PackedScene = null  # Spawn something when destroyed
@export var explodes_on_contact: bool = false  # Creates explosion hitbox
@export var explosion_radius: float = 60.0
@export var explosion_damage: int = 60
@export var bounces_off_walls: bool = false  # Reflects off stage boundaries
@export var max_bounces: int = 3
@export var sticks_to_target: bool = false  # Attaches to hit target
@export var delayed_hit_frames: int = 0  # Explodes after delay (mines/grenades)

# ============ VFX/SFX ============
@export_group("Effects")
@export var trail_effect: PackedScene = null  # Trail behind projectile
@export var hit_effect: PackedScene = null
@export var destroy_effect: PackedScene = null
@export var travel_sound: AudioStream = null
@export var hit_sound: AudioStream = null
@export var destroy_sound: AudioStream = null

# ============ COLLISION ============
@export_group("Collision")
@export var collision_layer: int = 5  # Projectile layer
@export var collision_mask: int = 12  # Detects P1 & P2 hurtboxes

# ============ METHODS ============
func get_hitbox_shape() -> Shape2D:
    """Generate collision shape for projectile hitbox"""
    match hitbox_shape:
        HitboxData.ShapeType.RECTANGLE:
            var rect = RectangleShape2D.new()
            rect.size = hitbox_size
            return rect
        HitboxData.ShapeType.CIRCLE:
            var circle = CircleShape2D.new()
            circle.radius = hitbox_radius
            return circle
        HitboxData.ShapeType.CAPSULE:
            var capsule = CapsuleShape2D.new()
            capsule.radius = hitbox_size.x / 2.0
            capsule.height = hitbox_size.y
            return capsule
    return null

func calculate_velocity(facing_right: bool, spawn_position: Vector2) -> Vector2:
    """Calculate initial velocity based on movement type"""
    var direction = Vector2.RIGHT if facing_right else Vector2.LEFT
    
    match movement_type:
        MovementType.LINEAR:
            return direction * speed
        MovementType.ARCING:
            # Combine horizontal speed with upward arc
            return Vector2(direction.x * speed, -arc_height)
        MovementType.HOMING:
            return direction * speed  # Will be adjusted per frame
        MovementType.WAVE:
            return direction * speed  # Wave applied as offset
        MovementType.BOOMERANG:
            return direction * speed  # Will reverse later
        MovementType.STATIONARY:
            return Vector2.ZERO
    
    return direction * speed
```

---

### 3.5. Projectile Class (CharacterBody2D)

```gdscript
class_name Projectile
extends CharacterBody2D

var projectile_data: ProjectileData
var owner_fighter: Fighter
var frames_alive: int = 0
var distance_traveled: float = 0.0
var hit_targets: Array[Fighter] = []
var current_health: int = 0
var bounce_count: int = 0
var is_reflected: bool = false
var homing_target: Fighter = null
var initial_position: Vector2
var base_velocity: Vector2

@onready var hitbox_area: Area2D = $HitboxArea
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

signal projectile_hit(target: Fighter, hit_data: HitData)
signal projectile_destroyed()
signal projectile_reflected(new_owner: Fighter)

func _ready() -> void:
    # Disable built-in physics process
    set_physics_process(false)

func initialize(data: ProjectileData, owner: Fighter, spawn_pos: Vector2) -> void:
    projectile_data = data
    owner_fighter = owner
    initial_position = spawn_pos
    global_position = spawn_pos
    
    # Setup health
    current_health = projectile_data.projectile_health
    
    # Setup hitbox
    setup_hitbox()
    
    # Setup visual
    if projectile_data.sprite:
        sprite.texture = projectile_data.sprite
        sprite.scale = projectile_data.scale
    
    # Calculate initial velocity
    base_velocity = projectile_data.calculate_velocity(owner_fighter.facing_right, spawn_pos)
    velocity = base_velocity
    
    # Find homing target if needed
    if projectile_data.movement_type == ProjectileData.MovementType.HOMING:
        find_homing_target()
    
    # Play animation
    if animation_player and projectile_data.animation_name:
        animation_player.play(projectile_data.animation_name)
    
    # Play travel sound
    if projectile_data.travel_sound:
        play_sound(projectile_data.travel_sound)
    
    # Spawn trail effect
    if projectile_data.trail_effect:
        spawn_trail()

func setup_hitbox() -> void:
    """Setup projectile hitbox Area2D"""
    var collision_shape = CollisionShape2D.new()
    collision_shape.shape = projectile_data.get_hitbox_shape()
    hitbox_area.add_child(collision_shape)
    
    # Setup collision layers
    hitbox_area.collision_layer = projectile_data.collision_layer
    hitbox_area.collision_mask = projectile_data.collision_mask
    
    # Manual overlap checking (frame-synchronized)
    hitbox_area.monitoring = true

func tick() -> void:
    """Called from MatchManager's tick() - frame-synchronized"""
    frames_alive += 1
    
    # Update movement
    update_movement()
    
    # Update rotation
    if projectile_data.rotation_speed != 0:
        rotation_degrees += projectile_data.rotation_speed
    
    # Check lifetime
    if projectile_data.lifetime_frames > 0 and frames_alive >= projectile_data.lifetime_frames:
        destroy()
        return
    
    # Check distance
    distance_traveled = global_position.distance_to(initial_position)
    if projectile_data.max_distance > 0 and distance_traveled >= projectile_data.max_distance:
        destroy()
        return
    
    # Move projectile
    var collision = move_and_collide(velocity / 60.0)  # Convert to per-frame movement
    
    # Handle wall collision
    if collision:
        if projectile_data.bounces_off_walls and bounce_count < projectile_data.max_bounces:
            handle_bounce(collision)
        else:
            destroy()
            return
    
    # Check for hits (manual overlap check)
    check_hits()

func update_movement() -> void:
    """Update velocity based on movement type"""
    match projectile_data.movement_type:
        ProjectileData.MovementType.LINEAR:
            # Apply acceleration if any
            if projectile_data.acceleration != 0:
                var speed = velocity.length()
                speed = min(speed + projectile_data.acceleration, projectile_data.max_speed)
                velocity = velocity.normalized() * speed
        
        ProjectileData.MovementType.ARCING:
            # Apply gravity
            velocity.y += 980.0 * projectile_data.gravity_multiplier / 60.0
        
        ProjectileData.MovementType.HOMING:
            # Steer towards target
            if homing_target and (projectile_data.homing_duration_frames == 0 or 
                                   frames_alive < projectile_data.homing_duration_frames):
                var direction = (homing_target.global_position - global_position).normalized()
                velocity = velocity.lerp(direction * projectile_data.speed, 
                                        projectile_data.homing_strength)
        
        ProjectileData.MovementType.WAVE:
            # Apply sine wave offset
            var wave_offset = sin(frames_alive * projectile_data.wave_frequency * TAU / 60.0) * projectile_data.wave_amplitude
            var perpendicular = Vector2(-base_velocity.y, base_velocity.x).normalized()
            velocity = base_velocity + perpendicular * wave_offset
        
        ProjectileData.MovementType.BOOMERANG:
            # Reverse direction after certain point
            if distance_traveled >= projectile_data.max_distance / 2.0:
                var direction = (owner_fighter.global_position - global_position).normalized()
                velocity = direction * projectile_data.speed
        
        ProjectileData.MovementType.STATIONARY:
            velocity = Vector2.ZERO

func check_hits() -> void:
    """Manually check for overlapping hurtboxes"""
    var overlapping_areas = hitbox_area.get_overlapping_areas()
    
    for area in overlapping_areas:
        if not area is Hurtbox:
            continue
        
        var target_fighter = area.owner_fighter
        
        # Skip owner (unless reflected)
        if target_fighter == owner_fighter and not is_reflected:
            continue
        
        # Skip already hit targets (unless multi-hit)
        if target_fighter in hit_targets and not projectile_data.multi_hit:
            continue
        
        # Process hit
        process_hit(target_fighter)
        
        # Check if should despawn
        if projectile_data.despawn_on_hit and projectile_data.pierce_count <= hit_targets.size():
            destroy()
            return

func process_hit(target_fighter: Fighter) -> void:
    """Process projectile hitting a target"""
    hit_targets.append(target_fighter)
    
    # Create hit data
    var hit_data = HitData.new()
    hit_data.attacker = owner_fighter
    hit_data.target = target_fighter
    hit_data.damage = projectile_data.damage
    hit_data.knockback = projectile_data.knockback
    hit_data.hitstun_frames = projectile_data.hitstun_frames
    hit_data.hit_position = global_position
    hit_data.hit_frame = GameManager.current_frame
    hit_data.is_projectile = true
    
    # Apply facing to knockback
    if not owner_fighter.facing_right:
        hit_data.knockback.x *= -1
    
    # Emit signal
    emit_signal("projectile_hit", target_fighter, hit_data)
    
    # Apply hit to target
    target_fighter.combat_system.apply_hit(hit_data)
    
    # Explosion on contact
    if projectile_data.explodes_on_contact:
        create_explosion()
    
    # Play hit effect
    if projectile_data.hit_effect:
        spawn_effect(projectile_data.hit_effect, global_position)
    
    # Play hit sound
    if projectile_data.hit_sound:
        play_sound(projectile_data.hit_sound)

func take_damage(damage: int) -> void:
    """Projectile takes damage from attacks"""
    if not projectile_data.can_be_destroyed:
        return
    
    current_health -= damage
    
    if current_health <= 0:
        destroy()

func reflect(new_owner: Fighter) -> void:
    """Reflect projectile back to sender"""
    if not projectile_data.can_be_reflected:
        return
    
    owner_fighter = new_owner
    is_reflected = true
    
    # Reverse velocity
    velocity *= -1
    base_velocity *= -1
    
    # Clear hit targets
    hit_targets.clear()
    
    # Update collision mask to hit original owner
    hitbox_area.collision_mask = get_opposite_mask()
    
    # Emit signal
    emit_signal("projectile_reflected", new_owner)

func handle_bounce(collision: KinematicCollision2D) -> void:
    """Handle projectile bouncing off walls"""
    bounce_count += 1
    
    # Reflect velocity
    velocity = velocity.bounce(collision.get_normal())
    base_velocity = velocity

func create_explosion() -> void:
    """Create explosion hitbox at current position"""
    var explosion_hitbox = HitboxData.new()
    explosion_hitbox.hitbox_name = "Explosion"
    explosion_hitbox.shape_type = HitboxData.ShapeType.CIRCLE
    explosion_hitbox.radius = projectile_data.explosion_radius
    explosion_hitbox.damage = projectile_data.explosion_damage
    explosion_hitbox.spawn_frame = 0
    explosion_hitbox.duration_frames = 3
    
    # Spawn explosion hitbox via owner's hitbox manager
    owner_fighter.hitbox_manager.spawn_hitbox_at_position(
        explosion_hitbox, 
        global_position
    )

func find_homing_target() -> void:
    """Find closest enemy to home in on"""
    var fighters = get_tree().get_nodes_in_group("fighters")
    var closest_distance = INF
    
    for fighter in fighters:
        if fighter == owner_fighter:
            continue
        
        var distance = global_position.distance_to(fighter.global_position)
        if distance < closest_distance:
            closest_distance = distance
            homing_target = fighter

func destroy() -> void:
    """Destroy projectile"""
    # Spawn destroy effect
    if projectile_data.destroy_effect:
        spawn_effect(projectile_data.destroy_effect, global_position)
    
    # Play destroy sound
    if projectile_data.destroy_sound:
        play_sound(projectile_data.destroy_sound)
    
    # Spawn on destroy
    if projectile_data.spawns_on_destroy:
        var spawned = projectile_data.spawns_on_destroy.instantiate()
        get_parent().add_child(spawned)
        spawned.global_position = global_position
    
    # Emit signal
    emit_signal("projectile_destroyed")
    
    # Remove from scene
    queue_free()

func spawn_effect(effect_scene: PackedScene, position: Vector2) -> void:
    var effect = effect_scene.instantiate()
    get_parent().add_child(effect)
    effect.global_position = position

func spawn_trail() -> void:
    var trail = projectile_data.trail_effect.instantiate()
    add_child(trail)

func play_sound(sound: AudioStream) -> void:
    var audio_player = AudioStreamPlayer2D.new()
    add_child(audio_player)
    audio_player.stream = sound
    audio_player.play()
    audio_player.finished.connect(audio_player.queue_free)

func get_opposite_mask() -> int:
    # Flip P1/P2 detection
    if owner_fighter.player_id == 1:
        return 1 << 3  # Detect P2 hurtbox
    else:
        return 1 << 2  # Detect P1 hurtbox
```

---

### 3.6. ProjectileManager (Manages Active Projectiles)

```gdscript
class_name ProjectileManager
extends Node

var fighter: Fighter
var active_projectiles: Array[Projectile] = []
var max_active_projectiles: int = 3  # Limit per fighter
var projectile_scene: PackedScene

signal projectile_spawned(projectile: Projectile)
signal projectile_destroyed(projectile: Projectile)

func _ready() -> void:
    fighter = get_parent() as Fighter
    projectile_scene = preload("res://character/common/projectile.tscn")

func spawn_projectile(data: ProjectileData, spawn_offset: Vector2 = Vector2.ZERO) -> Projectile:
    """Spawn a projectile"""
    # Check limit
    if active_projectiles.size() >= max_active_projectiles:
        # Destroy oldest projectile
        var oldest = active_projectiles[0]
        despawn_projectile(oldest)
    
    # Calculate spawn position
    var spawn_pos = fighter.global_position + spawn_offset
    if not fighter.facing_right:
        spawn_offset.x *= -1
        spawn_pos = fighter.global_position + spawn_offset
    
    # Create projectile
    var projectile = projectile_scene.instantiate() as Projectile
    get_tree().root.add_child(projectile)  # Add to root, not fighter
    
    projectile.initialize(data, fighter, spawn_pos)
    projectile.projectile_destroyed.connect(func(): despawn_projectile(projectile))
    
    active_projectiles.append(projectile)
    emit_signal("projectile_spawned", projectile)
    
    return projectile

func tick() -> void:
    """Update all active projectiles"""
    for projectile in active_projectiles:
        projectile.tick()

func despawn_projectile(projectile: Projectile) -> void:
    """Remove projectile"""
    if projectile in active_projectiles:
        active_projectiles.erase(projectile)
    
    emit_signal("projectile_destroyed", projectile)
    
    if is_instance_valid(projectile):
        projectile.queue_free()

func despawn_all_projectiles() -> void:
    """Clear all projectiles"""
    for projectile in active_projectiles.duplicate():
        despawn_projectile(projectile)
    active_projectiles.clear()

func reflect_projectile(projectile: Projectile) -> void:
    """Reflect a projectile back"""
    if projectile.projectile_data.can_be_reflected:
        projectile.reflect(fighter)
```

---

### 3.7. Projectile Move Integration

To spawn a projectile from a move, add this to MoveData:

```gdscript
# In MoveData class
@export_group("Projectile")
@export var spawns_projectile: bool = false
@export var projectile_data: ProjectileData = null
@export var projectile_spawn_frame: int = 8  # Frame when projectile spawns
@export var projectile_spawn_offset: Vector2 = Vector2(40, -20)  # Offset from fighter
```

Then in AttackState:

```gdscript
func tick() -> void:
    frames_elapsed += 1
    
    # Check if projectile should spawn
    if current_move.spawns_projectile and frames_elapsed == current_move.projectile_spawn_frame:
        fighter.projectile_manager.spawn_projectile(
            current_move.projectile_data,
            current_move.projectile_spawn_offset
        )
    
    # ... rest of attack logic
```

---

### 3.8. Projectile Usage Examples

#### Example 1: Fast Straight Fireball

```gdscript
# fireball.tres
[resource]
projectile_name = "Fireball"
movement_type = MovementType.LINEAR
speed = 400.0
lifetime_frames = 180
hitbox_shape = ShapeType.CIRCLE
hitbox_radius = 20.0
damage = 45
hitstun_frames = 15
blockstun_frames = 10
knockback = Vector2(150, -50)
can_be_reflected = true
can_be_destroyed = true
projectile_health = 1
despawn_on_hit = true
```

#### Example 2: Arcing Grenade

```gdscript
# grenade.tres
[resource]
projectile_name = "Grenade"
movement_type = MovementType.ARCING
speed = 250.0
arc_height = 300.0
gravity_multiplier = 1.0
lifetime_frames = 120
explodes_on_contact = true
explosion_radius = 80.0
explosion_damage = 70
despawn_on_hit = true
delayed_hit_frames = 60  # Explodes after 1 second if doesn't hit
```

#### Example 3: Homing Missile

```gdscript
# homing_missile.tres
[resource]
projectile_name = "Homing Missile"
movement_type = MovementType.HOMING
speed = 350.0
homing_strength = 0.08  # Gradual turning
homing_duration_frames = 180  # Homes for 3 seconds
lifetime_frames = 240
damage = 60
can_be_reflected = false  # Too smart to reflect
despawn_on_hit = true
```

#### Example 4: Multi-Hit Beam

```gdscript
# beam.tres
[resource]
projectile_name = "Energy Beam"
movement_type = MovementType.LINEAR
speed = 600.0
hitbox_shape = ShapeType.CAPSULE
hitbox_size = Vector2(15, 100)
multi_hit = true
hit_interval_frames = 5  # Hits every 5 frames
damage = 15  # Lower per-hit damage
pierce_count = 99  # Hits everyone
despawn_on_hit = false
lifetime_frames = 60
```

#### Example 5: Boomerang

```gdscript
# boomerang.tres
[resource]
projectile_name = "Boomerang"
movement_type = MovementType.BOOMERANG
speed = 400.0
max_distance = 400.0  # Goes 400px then returns
damage = 50
multi_hit = true  # Can hit on way out AND back
hit_interval_frames = 30
despawn_on_hit = false
lifetime_frames = 180
```

#### Example 6: Mine/Trap

```gdscript
# mine.tres
[resource]
projectile_name = "Proximity Mine"
movement_type = MovementType.STATIONARY
lifetime_frames = 600  # Lasts 10 seconds
delayed_hit_frames = 30  # Arms after 0.5 seconds
explodes_on_contact = true
explosion_radius = 100.0
explosion_damage = 80
can_be_destroyed = true
projectile_health = 3  # Takes 3 hits to destroy
```

---

## 4. MOVE DESIGN GUIDELINES

### 4.1. Normals (8 per character)

#### Light Attacks (5 moves)

**Neutral Light:**
- **Purpose:** Quick poke, combo starter
- **Frame Data:** Fast startup (3-5f), low recovery
- **Damage:** Low (30-50)
- **Example:** Quick jab

**Forward Light:**
- **Purpose:** Mid-range poke, pressure tool
- **Frame Data:** Medium startup (5-7f)
- **Damage:** Low-medium (40-60)
- **Example:** Forward kick

**Back Light:**
- **Purpose:** Anti-air or retreat option
- **Frame Data:** Fast startup (4-6f)
- **Damage:** Low (35-50)
- **Example:** Back step slash

**Down Light:**
- **Purpose:** Low-commitment pressure
- **Frame Data:** Fast startup (4-6f)
- **Damage:** Low (30-45)
- **Example:** Low poke (NOT a low attack, just positioning)

**Air Light:**
- **Purpose:** Air-to-air, jump-in
- **Frame Data:** Fast startup (4-6f)
- **Damage:** Medium (45-60)
- **Example:** Jump kick

---

#### Heavy Attacks (3 moves)

**Neutral Heavy:**
- **Purpose:** High damage punish, combo ender
- **Frame Data:** Slow startup (10-15f), high recovery
- **Damage:** High (80-120)
- **Example:** Heavy punch

**Down Heavy:**
- **Purpose:** Launcher or knockdown
- **Frame Data:** Medium-slow startup (8-12f)
- **Damage:** High (70-100)
- **Special:** Often launches opponent
- **Example:** Uppercut

**Air Heavy:**
- **Purpose:** Air combo ender or cross-up
- **Frame Data:** Medium startup (6-10f)
- **Damage:** High (70-110)
- **Example:** Diving strike

---

### 4.2. Specials (12 per character)

**Skill Structure:**
- 3 skills (S1, S2, S3)
- Each skill has:
  - Neutral variant (default)
  - Down variant (modifier)
  - Enhanced neutral (meter)
  - Enhanced down (meter + modifier)

**Design Philosophy:**
- **Skill 1:** Utility/mobility (dash attack, teleport, projectile)
- **Skill 2:** Pressure/setup (trap, buff, command grab)
- **Skill 3:** Anti-air/defensive (reversal, counter, evade)

**Example Skill Set:**

**Skill 1 - Projectile:**
- Neutral: Fast straight projectile
- Down: Arcing projectile (high/low trajectory)
- Enhanced Neutral: Larger, multi-hit projectile
- Enhanced Down: Homing projectile

**Skill 2 - Buff:**
- Neutral: Damage buff (short duration)
- Down: Speed buff (short duration)
- Enhanced Neutral: Damage + armor (longer duration)
- Enhanced Down: Full stat buff (medium duration)

**Skill 3 - Reversal:**
- Neutral: Quick invincible strike
- Down: Counter stance (parry)
- Enhanced Neutral: Invincible multi-hit reversal
- Enhanced Down: Counter into full combo

---

### 4.3. Ultimates (4 per character)

**Super 1 (S1+S2):**
- **Type:** Offensive super
- **Damage:** High (200-300)
- **Frame Data:** Fast startup (1-3f invincible)
- **Example:** Cinematic command grab

**Super 2 (S2+S3):**
- **Type:** Utility super
- **Damage:** Medium (150-200)
- **Special:** Grants buffs, setup, or position advantage
- **Example:** Install mode (temporary power-up)

**Super 3 (S1+S3):**
- **Type:** Defensive super
- **Damage:** Medium (150-250)
- **Frame Data:** Full invincibility
- **Example:** Counter super

**Ultimate (S1+S2+S3):**
- **Type:** Max damage super
- **Damage:** Massive (300-500)
- **Frame Data:** Cinematic (startup invincible)
- **Requirement:** Often requires specific conditions
- **Example:** Full-screen ultimate attack

---

## 5. PASSIVE ABILITY FRAMEWORK

### 5.1. PassiveData Resource

```gdscript
class_name PassiveData
extends Resource

@export var passive_name: String = "Passive"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var passive_script: Script  # Custom PassiveAbility implementation

# Configuration (varies per passive)
@export var config: Dictionary = {}
```

---

### 5.2. PassiveAbility Base Class

```gdscript
class_name PassiveAbility
extends Node

var fighter: Fighter
var passive_data: PassiveData
var is_active: bool = false

# Virtual methods (override in derived classes)
func initialize(data: PassiveData) -> void:
    passive_data = data

func activate() -> void:
    is_active = true

func deactivate() -> void:
    is_active = false

func check_activation_condition() -> bool:
    return false  # Override

# Hooks (override as needed)
func on_deal_damage(damage: int) -> void:
    pass

func on_take_damage(damage: int) -> void:
    pass

func on_kill() -> void:
    pass

func on_move_used(move: MoveData) -> void:
    pass

func on_block() -> void:
    pass

func on_hit_taken() -> void:
    pass

func on_combo_started() -> void:
    pass

func on_combo_ended(hit_count: int) -> void:
    pass

func on_stamina_depleted() -> void:
    pass

func on_low_hp() -> void:
    pass

# Stat modification
func modify_stat(stat_name: String, base_value: float) -> float:
    return base_value  # Override to modify

func modify_move_property(move: MoveData, property: String) -> Variant:
    return move.get(property)  # Override to modify
```

---

### 5.3. Example Passive Abilities

#### Berserker Passive
```gdscript
class_name BerserkerPassive
extends PassiveAbility

var damage_multiplier: float = 1.0
const LOW_HP_THRESHOLD = 0.3  # 30% HP

func check_activation_condition() -> bool:
    var hp_percent = float(fighter.resource_manager.hp_system.current_hp) / fighter.resource_manager.hp_system.max_hp
    return hp_percent <= LOW_HP_THRESHOLD

func tick() -> void:
    if check_activation_condition():
        if not is_active:
            activate()
    else:
        if is_active:
            deactivate()

func activate() -> void:
    super.activate()
    damage_multiplier = 1.5  # +50% damage

func deactivate() -> void:
    super.deactivate()
    damage_multiplier = 1.0

func modify_move_property(move: MoveData, property: String) -> Variant:
    if property == "damage" and is_active:
        return int(move.damage * damage_multiplier)
    return move.get(property)
```

#### Vampire Passive
```gdscript
class_name VampirePassive
extends PassiveAbility

const LIFESTEAL_PERCENT = 0.2  # 20% of damage dealt

func on_deal_damage(damage: int) -> void:
    var heal_amount = int(damage * LIFESTEAL_PERCENT)
    fighter.resource_manager.hp_system.heal(heal_amount)
```

#### Momentum Passive
```gdscript
class_name MomentumPassive
extends PassiveAbility

var current_stacks: int = 0
const MAX_STACKS = 5
const STACK_DECAY_FRAMES = 180  # 3 seconds at 60 FPS
var stack_timer_frames: int = 0

func on_hit_taken() -> void:
    # Lose all stacks on hit
    current_stacks = 0

func on_deal_damage(damage: int) -> void:
    # Gain stack on hit
    if current_stacks < MAX_STACKS:
        current_stacks += 1
    stack_timer_frames = STACK_DECAY_FRAMES

func tick() -> void:
    if current_stacks > 0:
        stack_timer_frames -= 1
        if stack_timer_frames <= 0:
            current_stacks = max(0, current_stacks - 1)
            stack_timer_frames = STACK_DECAY_FRAMES

func modify_stat(stat_name: String, base_value: float) -> float:
    if stat_name == "walk_speed" or stat_name == "dash_speed":
        return base_value * (1.0 + current_stacks * 0.1)  # +10% per stack
    return base_value
```

---

### 5.4. Passive Design Guidelines

**Good Passive:**
- Changes gameplay meaningfully
- Has activation conditions or costs
- Defines character archetype
- Creates risk/reward decisions

**Bad Passive:**
- Simple stat boost (boring)
- Always active with no conditions (passive)
- No counterplay (frustrating)

**Examples of Good Passives:**
- "Deal more damage at low HP" (risk/reward)
- "Gain stacks on hit, lose on being hit" (momentum-based)
- "Enhanced specials after successful block" (defensive reward)
- "Passive abilities at the cost of max HP" (permanent trade-off)

---

## 6. CHARACTER ARCHETYPES

### 6.1. Rushdown

**Stats:**
- Walk speed: Fast (250)
- Dash speed: Very fast (500)
- HP: Low-medium (900)
- Stamina regen: Fast (35/sec)

**Move Properties:**
- Fast normals (3-5f startup)
- Plus on block pressure tools
- Quick dashes and mobility
- Low damage per hit, high combo potential

**Passive Example:**
- "Gain speed boost after successful dash cancel"

---

### 6.2. Zoner

**Stats:**
- Walk speed: Slow (150)
- Dash speed: Medium (350)
- HP: Medium (1000)
- Stamina regen: Medium (30/sec)

**Move Properties:**
- Multiple projectile options
- Anti-air tools
- Keep-away normals
- High chip damage

**Passive Example:**
- "Projectiles deal bonus chip damage"

---

### 6.3. Grappler

**Stats:**
- Walk speed: Slow (180)
- Dash speed: Fast in short bursts (450)
- HP: High (1100)
- Stamina regen: Slow (25/sec)
- Weight: Heavy (1.2)

**Move Properties:**
- Command grabs (Forward+Down+Dash variants)
- Armor on heavy attacks
- High damage per hit
- Slow normals

**Passive Example:**
- "Gain armor after landing a grab"

---

### 6.4. All-Rounder

**Stats:**
- Balanced across the board
- Walk speed: Medium (200)
- HP: Medium (1000)
- Stamina regen: Medium (30/sec)

**Move Properties:**
- Versatile normals
- Balanced specials (projectile + mobility + reversal)
- No major weaknesses, no major strengths

**Passive Example:**
- "Gain meter faster than other characters"

---

### 6.5. Stance Character

**Stats:**
- Variable depending on stance
- HP: Medium (1000)

**Move Properties:**
- Special moves change stances
- Different normals per stance
- Meter is stance timer or stack-based

**Passive Example:**
- "Switch stances automatically on combo ender"

---

## 7. BALANCE CONSIDERATIONS

### 7.1. Damage Budget

**Target Total HP: 1000**
**Expected Hits to Kill: 8-15**

**Damage Ranges:**
- Light normals: 30-60
- Heavy normals: 70-120
- Specials: 60-100
- Enhanced specials: 100-150
- Supers: 200-300
- Ultimate: 300-500

**Combo Damage:**
- 3-hit combo: ~180-250 (20-25% HP)
- 5-hit combo: ~300-400 (30-40% HP)
- 8-hit combo: ~450-550 (45-55% HP)

---

### 7.2. Stamina Economy

**Total Stamina: 100**

**Cost Guidelines:**
- Light: 3 (can do ~33 lights)
- Heavy: 6 (can do ~16 heavies)
- Special: 10 (can do 10 specials)
- Dash: 10
- Heavy Dash: 30
- Block: 15 per hit (~6 blocks before stun)

**Goal:** Stamina should deplete ~2-3 times per round.

---

### 7.3. Frame Data Balance

**Plus Frames:**
- +3 to +5: Strong pressure
- +6 or more: Too strong (avoid)
- Negative on block: Most moves

**Startup Speed:**
- 3-5f: Fast (jabs, reversals)
- 6-10f: Medium (most normals)
- 11-15f: Slow (heavies, big specials)
- 16+f: Very slow (ultimates, command grabs)

---

## 8. TEMPLATE CHARACTER

```gdscript
# Example: Template Character Resource
# Save as: res://data/characters/template_character.tres

extends CharacterData

func _init():
    character_name = "Template"
    character_id = "template_001"
    description = "A balanced all-rounder character"
    
    # Stats
    max_hp = 1000
    max_stamina = 100
    stamina_regen_rate = 30.0
    
    # Physics
    walk_speed = 200.0
    dash_speed = 400.0
    jump_force = -400.0
    
    # Normals
    neutral_light = preload("res://data/moves/template/neutral_light.tres")
    forward_light = preload("res://data/moves/template/forward_light.tres")
    # ... (assign all 28 moves)
    
    # Passive & Meter
    passive_ability = preload("res://data/passives/template_passive.tres")
    character_meter = DamageMeter.new()
```

---

## 9. MOVE CREATION WORKFLOW

### 9.1. Step-by-Step Process

**1. Conceptualize Move:**
- Purpose (poke, punish, combo, special property)
- Visual concept
- Hit properties

**2. Define Frame Data:**
- Startup (how fast?)
- Active (how long does hitbox stay?)
- Recovery (how punishable?)

**3. Set Damage & Resources:**
- Base damage
- Stamina cost
- Meter cost/gain

**4. Create Hitbox Data:**
- Shape and position
- Knockback direction
- Special properties (launch, bounce, etc.)

**5. Animation:**
- Create animation in AnimationPlayer
- Mark hitbox spawn frames
- Add VFX/SFX

**6. Test & Balance:**
- Frame data testing
- Combo potential
- Risk/reward balance

---

## 10. DATA ORGANIZATION

### 10.1. File Structure

```
res://data/
├── characters/
│   ├── character_a/
│   │   ├── character_a_data.tres
│   │   ├── character_a_scene.tscn
│   │   ├── normals/
│   │   │   ├── neutral_light.tres
│   │   │   ├── forward_light.tres
│   │   │   └── ...
│   │   ├── specials/
│   │   │   ├── skill1_neutral.tres
│   │   │   └── ...
│   │   └── ultimates/
│   │       ├── super1.tres
│   │       └── ...
│   └── character_b/
│       └── ...
├── passives/
│   ├── berserker_passive.tres
│   └── ...
└── status_effects/
    ├── burn.tres
    └── ...
```

---

## SUMMARY

This character data structure provides:
- **Comprehensive character definition** with all 28 moves
- **Flexible passive system** for unique character mechanics
- **Balanced archetypes** for diverse playstyles
- **Resource-based data** for easy balancing and iteration
- **Clear guidelines** for move and character design

**Key Constraint:** 28 moves per character ensures design focus and prevents bloat while providing enough depth for competitive play.
