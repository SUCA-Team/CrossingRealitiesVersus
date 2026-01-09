# Combat System Implementation Plan
## Crossing Realities Versus

**Date:** January 3, 2026  

---

## 1. OVERVIEW

The combat system handles:
- Hitbox/Hurtbox collision detection
- Hit confirmation and damage application
- Combo tracking and damage scaling
- Hitstun/Blockstun management
- Knockback and juggle mechanics
- Visual/audio feedback

**Core Principle:** Frame-perfect fighting game mechanics with clear, responsive feedback.

---

## 2. HITBOX/HURTBOX SYSTEM

### 2.1. Architecture Overview

```
Fighter (CharacterBody2D)
├── CombatSystem (Node)
│   ├── HitboxManager (Node2D)
│   │   └── Hitbox Pool (Area2D[])
│   └── HurtboxManager (Node2D)
│       └── MainHurtbox (Area2D)
└── AttackState
    └── Spawns hitboxes via CombatSystem
```

---

### 2.2. Hitbox Implementation

```gdscript
class_name Hitbox
extends Area2D

# Hitbox properties
var hitbox_data: HitboxData
var owner_fighter: Fighter
var active: bool = false
var hit_enemies: Array[Fighter] = []  # Prevent multi-hit

# Lifetime
var lifetime_frames: int = 0
var max_lifetime: int = 3  # Active frames

# Signals
signal hit_connected(target: Fighter, hitbox_data: HitboxData)

func _ready() -> void:
    # Set collision layers
    # Layer 1: P1 attacks, Layer 2: P2 attacks
    # Mask 3: P1 hurtbox, Mask 4: P2 hurtbox
    area_entered.connect(_on_area_entered)
    monitoring = false
    monitorable = true

func activate(data: HitboxData, owner: Fighter) -> void:
    hitbox_data = data
    owner_fighter = owner
    active = true
    hit_enemies.clear()
    lifetime_frames = 0
    max_lifetime = data.active_end_frame - data.active_start_frame
    
    # Set shape and position
    var collision_shape = CollisionShape2D.new()
    collision_shape.shape = data.shape
    collision_shape.position = data.position
    add_child(collision_shape)
    
    # Set collision layer based on owner
    if owner.player_id == 1:
        collision_layer = 1  # P1 hitbox
        collision_mask = 4   # Check P2 hurtbox
    else:
        collision_layer = 2  # P2 hitbox
        collision_mask = 3   # Check P1 hurtbox
    
    monitoring = true
    visible = OS.is_debug_build()  # Show in debug mode

func tick() -> void:
    if not active:
        return
    
    lifetime_frames += 1
    if lifetime_frames >= max_lifetime:
        deactivate()

func deactivate() -> void:
    active = false
    monitoring = false
    hit_enemies.clear()
    
    # Remove collision shapes
    for child in get_children():
        if child is CollisionShape2D:
            child.queue_free()

func _on_area_entered(area: Area2D) -> void:
    if not active:
        return
    
    # Check if area is a hurtbox
    if not area is Hurtbox:
        return
    
    var hurtbox = area as Hurtbox
    var target = hurtbox.owner_fighter
    
    # Prevent friendly fire
    if target == owner_fighter:
        return
    
    # Prevent multi-hit
    if target in hit_enemies:
        return
    
    # Check if hurtbox is vulnerable
    if hurtbox.invulnerable:
        return
    
    # Hit confirmed!
    hit_enemies.append(target)
    hit_connected.emit(target, hitbox_data)
```

---

### 2.3. HitboxData (Resource)

```gdscript
class_name HitboxData
extends Resource

# Shape and position
@export var shape: Shape2D  # RectangleShape2D or CircleShape2D
@export var position: Vector2 = Vector2.ZERO  # Relative to fighter
@export var rotation: float = 0.0

# Timing
@export var active_start_frame: int = 5   # Startup
@export var active_end_frame: int = 8     # Startup + Active

# Damage properties
@export var damage: int = 50
@export var chip_damage_multiplier: float = 0.1

# Hitstun/Blockstun
@export var hitstun_frames: int = 15
@export var blockstun_frames: int = 8

# Knockback
@export var knockback_force: Vector2 = Vector2(200, -100)
@export var knockback_on_block: Vector2 = Vector2(50, 0)

# Hit properties
@export var ground_bounce: bool = false
@export var wall_bounce: bool = false
@export var launches: bool = false  # Launches opponent into air
@export var hard_knockdown: bool = false

# Status effect
@export var on_hit_status: StatusEffect = null

# VFX/SFX
@export var hit_effect: PackedScene  # Particle effect on hit
@export var hit_sound: AudioStream
@export var block_effect: PackedScene
@export var block_sound: AudioStream
```

---

### 2.4. Hurtbox Implementation

```gdscript
class_name Hurtbox
extends Area2D

var owner_fighter: Fighter
var invulnerable: bool = false
var invuln_timer_frames: int = 0

func _ready() -> void:
    # Set collision layers
    # P1: Layer 3, P2: Layer 4
    monitorable = true
    monitoring = false

func tick() -> void:
    if invuln_timer_frames > 0:
        invuln_timer_frames -= 1
        if invuln_timer_frames <= 0:
            invulnerable = false

func set_invulnerable(duration_frames: int) -> void:
    invulnerable = true
    invuln_timer_frames = duration_frames

func disable() -> void:
    invulnerable = true

func enable() -> void:
    invulnerable = false
```

---

### 2.5. HitboxManager (Object Pooling)

```gdscript
class_name HitboxManager
extends Node2D

var fighter: Fighter
var hitbox_pool: Array[Hitbox] = []
var active_hitboxes: Array[Hitbox] = []

const POOL_SIZE = 10

func _ready() -> void:
    # Pre-create hitbox pool
    for i in range(POOL_SIZE):
        var hitbox = Hitbox.new()
        hitbox.hit_connected.connect(_on_hit_connected)
        add_child(hitbox)
        hitbox_pool.append(hitbox)

func spawn_hitbox(data: HitboxData) -> Hitbox:
    # Get inactive hitbox from pool
    var hitbox = null
    for hb in hitbox_pool:
        if not hb.active:
            hitbox = hb
            break
    
    if hitbox == null:
        # Pool exhausted, create new one
        hitbox = Hitbox.new()
        hitbox.hit_connected.connect(_on_hit_connected)
        add_child(hitbox)
        hitbox_pool.append(hitbox)
    
    # Activate hitbox
    hitbox.activate(data, fighter)
    active_hitboxes.append(hitbox)
    
    return hitbox

func despawn_hitbox(hitbox: Hitbox) -> void:
    hitbox.deactivate()
    active_hitboxes.erase(hitbox)

func despawn_all() -> void:
    for hitbox in active_hitboxes.duplicate():
        despawn_hitbox(hitbox)

func _on_hit_connected(target: Fighter, hitbox_data: HitboxData) -> void:
    # Create HitData
    var hit_data = HitData.new()
    hit_data.attacker = fighter
    hit_data.defender = target
    hit_data.hitbox_data = hitbox_data
    hit_data.move_data = fighter.move_system.current_move
    hit_data.damage = hitbox_data.damage
    
    # Apply combo scaling
    var scaling = fighter.combat_system.combo_tracker.get_current_scaling()
    hit_data.scaled_damage = int(hit_data.damage * scaling)
    
    # Send to opponent's combat system
    target.combat_system.receive_hit(hit_data)
    
    # Notify attacker
    fighter.combat_system.hit_confirmed(hit_data)
```

---

## 3. HIT DETECTION & RESPONSE

### 3.1. CombatSystem

```gdscript
class_name CombatSystem
extends Node

var fighter: Fighter

@onready var hitbox_manager: HitboxManager = $HitboxManager
@onready var hurtbox_manager: HurtboxManager = $HurtboxManager
@onready var combo_tracker: ComboTracker = $ComboTracker

# Signals
signal hit_landed(hit_data: HitData)
signal was_hit(hit_data: HitData)
signal blocked(hit_data: HitData)

func _ready() -> void:
    hitbox_manager.fighter = fighter
    hurtbox_manager.owner_fighter = fighter
    combo_tracker.fighter = fighter

# Spawn hitbox during attack
func spawn_hitbox(data: HitboxData) -> void:
    hitbox_manager.spawn_hitbox(data)

func despawn_all_hitboxes() -> void:
    hitbox_manager.despawn_all()

# Called when fighter's attack connects
func hit_confirmed(hit_data: HitData) -> void:
    combo_tracker.add_hit(hit_data.scaled_damage)
    hit_landed.emit(hit_data)
    
    # Meter gain on hit
    fighter.resource_manager.character_meter.on_deal_damage(hit_data.scaled_damage)
    
    # VFX/SFX
    spawn_hit_effect(hit_data)
    play_hit_sound(hit_data)

# Called when fighter is hit
func receive_hit(hit_data: HitData) -> void:
    if fighter.is_blocking():
        handle_block(hit_data)
    else:
        handle_hit(hit_data)

func handle_hit(hit_data: HitData) -> void:
    # Apply damage
    fighter.resource_manager.hp_system.take_damage(hit_data.scaled_damage, false)
    
    # Meter gain on hurt
    fighter.resource_manager.character_meter.on_take_damage(hit_data.scaled_damage)
    
    # Apply hitstun
    fighter.state_machine.change_state("HitStun", {
        "duration_frames": hit_data.hitbox_data.hitstun_frames,
        "knockback": hit_data.hitbox_data.knockback_force
    })
    
    # Apply status effect
    if hit_data.hitbox_data.on_hit_status:
        fighter.status_manager.apply_status(hit_data.hitbox_data.on_hit_status)
    
    # Reset opponent's combo on hit
    hit_data.attacker.combat_system.combo_tracker.refresh_combo()
    
    was_hit.emit(hit_data)

func handle_block(hit_data: HitData) -> void:
    # Calculate chip damage
    var chip_damage = int(hit_data.damage * hit_data.hitbox_data.chip_damage_multiplier)
    fighter.resource_manager.hp_system.take_damage(chip_damage, true)
    
    # Consume stamina
    var stamina_cost = 15.0  # Default block cost
    if not fighter.resource_manager.stamina_system.consume(stamina_cost):
        # Stamina depleted, guard break
        handle_guard_break(hit_data)
        return
    
    # Apply blockstun
    fighter.state_machine.change_state("BlockStun", {
        "duration_frames": hit_data.hitbox_data.blockstun_frames,
        "knockback": hit_data.hitbox_data.knockback_on_block
    })
    
    # Reset attacker's combo
    hit_data.attacker.combat_system.combo_tracker.end_combo()
    
    blocked.emit(hit_data)
    
    # VFX/SFX
    spawn_block_effect(hit_data)
    play_block_sound(hit_data)

func handle_guard_break(hit_data: HitData) -> void:
    # Stamina depleted during block
    fighter.state_machine.change_state("Stunned")
    
    # Take reduced damage
    var break_damage = hit_data.scaled_damage / 2
    fighter.resource_manager.hp_system.take_damage(break_damage, false)

# VFX/SFX
func spawn_hit_effect(hit_data: HitData) -> void:
    if not hit_data.hitbox_data.hit_effect:
        return
    
    var effect = hit_data.hitbox_data.hit_effect.instantiate()
    effect.global_position = hit_data.defender.global_position
    get_tree().current_scene.add_child(effect)

func play_hit_sound(hit_data: HitData) -> void:
    if not hit_data.hitbox_data.hit_sound:
        return
    
    var audio_player = AudioStreamPlayer.new()
    audio_player.stream = hit_data.hitbox_data.hit_sound
    add_child(audio_player)
    audio_player.play()
    audio_player.finished.connect(audio_player.queue_free)

func spawn_block_effect(hit_data: HitData) -> void:
    if not hit_data.hitbox_data.block_effect:
        return
    
    var effect = hit_data.hitbox_data.block_effect.instantiate()
    effect.global_position = hit_data.defender.global_position
    get_tree().current_scene.add_child(effect)

func play_block_sound(hit_data: HitData) -> void:
    if not hit_data.hitbox_data.block_sound:
        return
    
    var audio_player = AudioStreamPlayer.new()
    audio_player.stream = hit_data.hitbox_data.block_sound
    add_child(audio_player)
    audio_player.play()
    audio_player.finished.connect(audio_player.queue_free)
```

---

### 3.2. HitData Structure

```gdscript
class_name HitData

var attacker: Fighter
var defender: Fighter
var move_data: MoveData
var hitbox_data: HitboxData
var damage: int
var scaled_damage: int
var is_counter_hit: bool = false
var is_blocked: bool = false

func apply_scaling(scaling_factor: float) -> void:
    scaled_damage = int(damage * scaling_factor)

func to_dict() -> Dictionary:
    return {
        "attacker": attacker.player_id,
        "defender": defender.player_id,
        "move": move_data.move_name,
        "damage": damage,
        "scaled_damage": scaled_damage,
        "counter": is_counter_hit,
        "blocked": is_blocked
    }
```

---

## 4. COMBO SYSTEM

### 4.1. ComboTracker

```gdscript
class_name ComboTracker
extends Node

var fighter: Fighter

# Combo state
var combo_count: int = 0
var total_damage: int = 0
var combo_active: bool = false
var combo_timer: float = 0.0
var combo_timeout: float = 1.5  # seconds

# Scaling
@export var base_scaling: float = 0.9
@export var min_scaling: float = 0.3  # Minimum 30% damage

# Signals
signal combo_started()
signal combo_continued(hit_count: int, damage: int)
signal combo_ended(hit_count: int, total_damage: int)

func _physics_process(delta: float) -> void:
    if combo_active:
        combo_timer -= delta
        if combo_timer <= 0:
            end_combo()

func add_hit(damage: int) -> void:
    if not combo_active:
        start_combo()
    
    combo_count += 1
    total_damage += damage
    combo_timer_frames = combo_timeout_frames  # Reset timer
    
    combo_continued.emit(combo_count, total_damage)

func start_combo() -> void:
    combo_active = true
    combo_count = 0
    total_damage = 0
    combo_timer_frames = combo_timeout_frames
    combo_started.emit()

func end_combo() -> void:
    if not combo_active:
        return
    
    var final_count = combo_count
    var final_damage = total_damage
    
    combo_active = false
    combo_count = 0
    total_damage = 0
    
    if final_count > 0:
        combo_ended.emit(final_count, final_damage)

func refresh_combo() -> void:
    # Reset timer but keep combo active
    combo_timer_frames = combo_timeout_frames

func get_current_scaling() -> float:
    if combo_count == 0:
        return 1.0
    
    # Scaling formula: base_scaling^(combo_count - 1)
    var scaling = pow(base_scaling, combo_count - 1)
    return max(scaling, min_scaling)

func get_combo_data() -> Dictionary:
    return {
        "active": combo_active,
        "count": combo_count,
        "damage": total_damage,
        "scaling": get_current_scaling()
    }
```

---

### 4.2. Damage Scaling Formula

**Standard Scaling:**
```
scaled_damage = base_damage × (0.9)^(hit_count - 1)
```

**Examples:**
- Hit 1: 100 damage × 0.9^0 = 100 damage (100%)
- Hit 2: 100 damage × 0.9^1 = 90 damage (90%)
- Hit 3: 100 damage × 0.9^2 = 81 damage (81%)
- Hit 4: 100 damage × 0.9^3 = 73 damage (73%)
- Hit 5: 100 damage × 0.9^4 = 66 damage (66%)
- ...
- Hit 10: 100 damage × 0.9^9 = 39 damage (39%)
- Hit 15: 100 damage × 0.9^14 = 23 damage (23%, but clamped to 30% minimum)

**Minimum Scaling:** 30% (prevents damage from becoming negligible)

---

### 4.3. Combo Display UI

```gdscript
class_name ComboDisplay
extends Control

@onready var combo_label: Label = $ComboLabel
@onready var damage_label: Label = $DamageLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var display_timer: float = 0.0
const DISPLAY_DURATION = 2.0

func _ready() -> void:
    visible = false

func show_combo(hit_count: int, damage: int) -> void:
    if hit_count <= 1:
        return  # Don't show for single hits
    
    combo_label.text = "%d HIT COMBO!" % hit_count
    damage_label.text = "%d DAMAGE" % damage
    
    visible = true
    display_timer = DISPLAY_DURATION
    
    # Play animation
    animation_player.play("combo_pulse")

func _process(delta: float) -> void:
    if visible and display_timer > 0:
        display_timer -= delta
        if display_timer <= 0:
            visible = false

func on_combo_ended(hit_count: int, total_damage: int) -> void:
    show_combo(hit_count, total_damage)
```

---

## 5. HITSTUN & BLOCKSTUN

### 5.1. HitStunState

```gdscript
class_name HitStunState
extends State

var duration_frames: int = 15
var elapsed_frames: int = 0
var knockback: Vector2 = Vector2.ZERO
var knockback_decay: float = 0.9

func enter() -> void:
    # Get parameters from state machine
    if state_machine.state_params.has("duration_frames"):
        duration_frames = state_machine.state_params["duration_frames"]
    if state_machine.state_params.has("knockback"):
        knockback = state_machine.state_params["knockback"]
    
    elapsed_frames = 0
    fighter.animation_player.play("hitstun")

func tick() -> void:
    elapsed_frames += 1
    
    # Apply knockback
    fighter.velocity = knockback
    knockback *= knockback_decay  # Decay over time
    
    fighter.move_and_slide()
    
    # Check for end
    if elapsed_frames >= duration_frames:
        state_machine.change_state("Idle")

func exit() -> void:
    fighter.velocity = Vector2.ZERO

func can_transition() -> bool:
    return false  # Cannot cancel hitstun
```

---

### 5.2. BlockStunState

```gdscript
class_name BlockStunState
extends State

var duration_frames: int = 8
var elapsed_frames: int = 0
var knockback: Vector2 = Vector2.ZERO

func enter() -> void:
    if state_machine.state_params.has("duration_frames"):
        duration_frames = state_machine.state_params["duration_frames"]
    if state_machine.state_params.has("knockback"):
        knockback = state_machine.state_params["knockback"]
    
    elapsed_frames = 0
    fighter.animation_player.play("block_hit")

func tick() -> void:
    elapsed_frames += 1
    
    # Apply pushback
    fighter.velocity = knockback
    fighter.move_and_slide()
    
    if elapsed_frames >= duration_frames:
        state_machine.change_state("Block")

func exit() -> void:
    fighter.velocity = Vector2.ZERO
```

---

## 6. KNOCKBACK & JUGGLE MECHANICS

### 6.1. Knockback Application

```gdscript
# In HitStunState
func apply_knockback(knockback_force: Vector2) -> void:
    # Adjust knockback based on facing direction
    if fighter.facing_right:
        fighter.velocity = knockback_force
    else:
        fighter.velocity = Vector2(-knockback_force.x, knockback_force.y)
```

---

### 6.2. Juggle System (Air Combos)

```gdscript
class_name JuggleTracker

var juggle_count: int = 0
var max_juggles: int = 3  # Prevent infinite air combos
var in_air: bool = false

func on_launched() -> void:
    in_air = true
    juggle_count = 0

func on_air_hit() -> void:
    juggle_count += 1

func can_juggle() -> bool:
    return juggle_count < max_juggles

func on_grounded() -> void:
    in_air = false
    juggle_count = 0
```

---

### 6.3. Ground Bounce & Wall Bounce

```gdscript
# In HitStunState or physics process
func check_ground_bounce() -> void:
    if fighter.is_grounded and hit_data.hitbox_data.ground_bounce:
        # Bounce back up
        fighter.velocity.y = -300
        hit_data.hitbox_data.ground_bounce = false  # Only once

func check_wall_bounce() -> void:
    if fighter.is_on_wall() and hit_data.hitbox_data.wall_bounce:
        # Bounce away from wall
        fighter.velocity.x = -fighter.velocity.x * 0.8
        hit_data.hitbox_data.wall_bounce = false  # Only once
```

---

## 7. FRAME DATA SYSTEM

### 7.1. Frame Data Structure

```gdscript
class_name FrameData

# Move timing
var startup_frames: int      # Frames before hitbox is active
var active_frames: int       # Frames hitbox is active
var recovery_frames: int     # Frames after hitbox deactivates
var total_frames: int        # Total move duration

# Advantage
var on_hit_advantage: int    # Frame advantage on hit
var on_block_advantage: int  # Frame advantage on block

# Calculated properties
func calculate_total() -> int:
    return startup_frames + active_frames + recovery_frames

func calculate_on_hit_advantage(hitstun_frames: int) -> int:
    return hitstun_frames - recovery_frames

func calculate_on_block_advantage(blockstun_frames: int) -> int:
    return blockstun_frames - recovery_frames
```

---

### 7.2. Frame Data Display (Training Mode)

```gdscript
class_name FrameDataDisplay
extends Control

@onready var startup_label: Label = $Startup
@onready var active_label: Label = $Active
@onready var recovery_label: Label = $Recovery
@onready var advantage_label: Label = $Advantage

func display_move_data(move: MoveData) -> void:
    startup_label.text = "Startup: %d" % move.startup_frames
    active_label.text = "Active: %d" % move.active_frames
    recovery_label.text = "Recovery: %d" % move.recovery_frames
    
    var total = move.startup_frames + move.active_frames + move.recovery_frames
    advantage_label.text = "Total: %d" % total

func display_advantage(advantage: int) -> void:
    if advantage > 0:
        advantage_label.text = "+%d (Advantage)" % advantage
        advantage_label.modulate = Color.GREEN
    elif advantage < 0:
        advantage_label.text = "%d (Disadvantage)" % advantage
        advantage_label.modulate = Color.RED
    else:
        advantage_label.text = "0 (Neutral)"
        advantage_label.modulate = Color.YELLOW
```

---

## 8. PRIORITY SYSTEM

### 8.1. Hit Priority Rules

**When two hitboxes collide:**
1. **Both players get hit** (no priority system by default)
2. OR: Implement priority based on move type

```gdscript
enum HitPriority {
    LOW = 0,      # Light normals
    MEDIUM = 1,   # Heavy normals
    HIGH = 2,     # Specials
    HIGHEST = 3   # Ultimates, armor moves
}

func resolve_hit_clash(hit1: HitData, hit2: HitData) -> void:
    var priority1 = hit1.move_data.hit_priority
    var priority2 = hit2.move_data.hit_priority
    
    if priority1 > priority2:
        # Hit1 wins, only hit2's fighter gets hit
        hit2.defender.combat_system.receive_hit(hit1)
    elif priority2 > priority1:
        # Hit2 wins
        hit1.defender.combat_system.receive_hit(hit2)
    else:
        # Equal priority, both hit (clash)
        hit1.defender.combat_system.receive_hit(hit2)
        hit2.defender.combat_system.receive_hit(hit1)
```

---

## 9. COUNTER HIT SYSTEM

### 9.1. Counter Hit Detection

**Counter Hit:** Hitting opponent during their attack startup or recovery.

```gdscript
func detect_counter_hit(hit_data: HitData) -> bool:
    var defender_state = hit_data.defender.state_machine.current_state
    
    # Counter if defender is in attack state
    if defender_state is AttackState:
        return true
    
    return false

func apply_counter_hit_bonus(hit_data: HitData) -> void:
    # Counter hit bonuses
    hit_data.scaled_damage = int(hit_data.scaled_damage * 1.2)  # +20% damage
    hit_data.hitbox_data.hitstun_frames = int(hit_data.hitbox_data.hitstun_frames * 1.3)  # +30% hitstun
    hit_data.is_counter_hit = true
```

---

## 10. ARMOR & SUPER ARMOR

### 10.1. Armor System

```gdscript
class_name ArmorSystem

var has_armor: bool = false
var armor_hits: int = 0  # Number of hits armor can absorb
var armor_damage_reduction: float = 0.5  # 50% damage reduction

func activate_armor(hits: int, reduction: float = 0.5) -> void:
    has_armor = true
    armor_hits = hits
    armor_damage_reduction = reduction

func deactivate_armor() -> void:
    has_armor = false
    armor_hits = 0

func process_hit_with_armor(hit_data: HitData) -> bool:
    if not has_armor:
        return false  # No armor, take hit normally
    
    # Reduce damage
    hit_data.scaled_damage = int(hit_data.scaled_damage * armor_damage_reduction)
    
    # No hitstun
    hit_data.hitbox_data.hitstun_frames = 0
    
    # Consume armor hit
    armor_hits -= 1
    if armor_hits <= 0:
        deactivate_armor()
    
    return true  # Armored through hit
```

---

## 11. PROJECTILE SYSTEM

### 11.1. Projectile Implementation

```gdscript
class_name Projectile
extends Area2D

var owner_fighter: Fighter
var velocity: Vector2 = Vector2(300, 0)
var hitbox_data: HitboxData
var hit_enemies: Array[Fighter] = []
var lifetime_frames: int = 300  # 5 seconds at 60 FPS
var pierce: bool = false  # Can hit multiple enemies
var velocity_per_frame: Vector2  # Calculated from velocity

func _ready() -> void:
    area_entered.connect(_on_area_entered)
    velocity_per_frame = velocity / 60.0  # Convert per-second to per-frame

func tick() -> void:
    position += velocity_per_frame
    
    lifetime_frames -= 1
    if lifetime_frames <= 0:
        queue_free()

func _on_area_entered(area: Area2D) -> void:
    if area is Hurtbox:
        var hurtbox = area as Hurtbox
        var target = hurtbox.owner_fighter
        
        if target == owner_fighter:
            return
        
        if target in hit_enemies and not pierce:
            return
        
        # Create hit data
        var hit_data = HitData.new()
        hit_data.attacker = owner_fighter
        hit_data.defender = target
        hit_data.hitbox_data = hitbox_data
        hit_data.damage = hitbox_data.damage
        hit_data.scaled_damage = hitbox_data.damage  # No scaling for projectiles
        
        target.combat_system.receive_hit(hit_data)
        hit_enemies.append(target)
        
        if not pierce:
            queue_free()
```

---

## 12. TESTING & DEBUG TOOLS

### 12.1. Hitbox Visualization

```gdscript
# In Hitbox._draw()
func _draw() -> void:
    if not OS.is_debug_build():
        return
    
    if active:
        draw_rect(Rect2(-10, -10, 20, 20), Color.RED, false, 2.0)
    else:
        draw_rect(Rect2(-10, -10, 20, 20), Color.GRAY, false, 1.0)
```

---

### 12.2. Frame-by-Frame Mode

```gdscript
class_name FrameStepController

var frame_step_enabled: bool = false
var paused: bool = false

func _input(event: InputEvent) -> void:
    if not OS.is_debug_build():
        return
    
    if event.is_action_pressed("debug_toggle_frame_step"):
        frame_step_enabled = not frame_step_enabled
        get_tree().paused = frame_step_enabled
    
    if event.is_action_pressed("debug_step_frame") and frame_step_enabled:
        # Advance one physics frame
        Engine.physics_ticks_per_second = 1
        await get_tree().physics_frame
        Engine.physics_ticks_per_second = 60
```

---

## 13. PERFORMANCE OPTIMIZATION

### 13.1. Collision Optimization

**Strategies:**
- Object pooling for hitboxes (already implemented)
- Disable monitoring when hitboxes are inactive
- Use appropriate collision layers/masks
- Limit number of active hitboxes per fighter

---

### 13.2. VFX Optimization

**Strategies:**
- Pool particle effects
- Limit number of active particles
- Use simple shaders
- Cull off-screen effects

```gdscript
class_name VFXPool

var effect_pool: Dictionary = {}  # effect_name: Array[Node]

func get_effect(effect_scene: PackedScene) -> Node:
    var pool_key = effect_scene.resource_path
    
    if not effect_pool.has(pool_key):
        effect_pool[pool_key] = []
    
    # Find inactive effect
    for effect in effect_pool[pool_key]:
        if not effect.is_visible():
            effect.visible = true
            return effect
    
    # Create new
    var effect = effect_scene.instantiate()
    effect_pool[pool_key].append(effect)
    return effect
```

---

## SUMMARY

The combat system provides:
- **Precise hitbox/hurtbox collision** with frame-accurate detection
- **Combo tracking** with damage scaling to prevent infinite combos
- **Hitstun/blockstun** for competitive frame advantage mechanics
- **Flexible hit properties** (knockback, launches, bounces)
- **VFX/SFX feedback** for clear hit confirmation

**Core Innovation:** Block as a resource (stamina) creates unique pressure situations where traditional block strings become guard-break opportunities.
