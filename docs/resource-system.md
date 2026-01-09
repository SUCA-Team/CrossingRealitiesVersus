# Resource System Implementation Plan
## Crossing Realities Versus

**Date:** January 3, 2026  

---

## 1. OVERVIEW

The resource system manages three core resources:
1. **HP (Health Points)** - Traditional health
2. **Stamina** - Primary defensive resource (blocking, dashing)
3. **Character Meter** - Custom per-character resource

This document provides detailed implementation specifications for each system.

---

## 2. HP SYSTEM

### 2.1. Design Specifications

**Core Properties:**
- Default maximum: 1000 HP
- Cannot exceed maximum
- Minimum is 0 (death)
- Integer-based for precision
- No natural regeneration (unless passive provides it)

**Damage Types:**
- **Normal damage:** Full damage on hit
- **Chip damage:** Reduced damage on block (default 10% of move damage)

---

### 2.2. Implementation

#### HPSystem Class

```gdscript
class_name HPSystem
extends Node

# Properties
var current_hp: int = 1000
var max_hp: int = 1000
var is_dead: bool = false

# Signals
signal hp_changed(current: int, maximum: int, delta: int)
signal hp_depleted()
signal healed(amount: int)
signal damaged(amount: int, is_chip: bool)

# Initialization
func initialize(maximum: int) -> void:
    max_hp = maximum
    current_hp = max_hp
    is_dead = false
    hp_changed.emit(current_hp, max_hp, 0)

# Damage Application
func take_damage(damage: int, is_chip: bool = false) -> void:
    if is_dead:
        return
    
    var actual_damage = clamp(damage, 0, current_hp)
    current_hp -= actual_damage
    
    damaged.emit(actual_damage, is_chip)
    hp_changed.emit(current_hp, max_hp, -actual_damage)
    
    if current_hp <= 0:
        current_hp = 0
        is_dead = true
        hp_depleted.emit()

# Healing
func heal(amount: int) -> void:
    if is_dead:
        return
    
    var actual_heal = min(amount, max_hp - current_hp)
    if actual_heal <= 0:
        return
    
    current_hp += actual_heal
    healed.emit(actual_heal)
    hp_changed.emit(current_hp, max_hp, actual_heal)

# Set HP directly (for debugging/training mode)
func set_hp(value: int) -> void:
    var old_hp = current_hp
    current_hp = clamp(value, 0, max_hp)
    var delta = current_hp - old_hp
    
    if current_hp <= 0 and not is_dead:
        is_dead = true
        hp_depleted.emit()
    elif current_hp > 0 and is_dead:
        is_dead = false
    
    hp_changed.emit(current_hp, max_hp, delta)

# Queries
func get_hp_percentage() -> float:
    return float(current_hp) / float(max_hp) * 100.0

func is_low_hp(threshold: float = 20.0) -> bool:
    return get_hp_percentage() <= threshold

func get_remaining_hp() -> int:
    return current_hp

func get_max_hp() -> int:
    return max_hp
```

---

### 2.3. Chip Damage Calculation

```gdscript
# In CombatSystem
func calculate_chip_damage(move: MoveData) -> int:
    return int(move.damage * move.chip_damage_multiplier)

# Default chip_damage_multiplier = 0.1 (10% of move damage)
```

**Example:**
- Move deals 100 damage
- On block: 10 chip damage
- Attacker still applies pressure without breaking through

---

### 2.4. HP Bar UI Integration

```gdscript
# HPBar.gd
class_name HPBar
extends ProgressBar

@export var smooth_transition: bool = true
@export var transition_speed: float = 50.0  # HP per second
@export var show_damage_bar: bool = true
@export var damage_bar_delay: float = 0.5

@onready var damage_bar: ProgressBar = $DamageBar

var target_value: int
var current_display: float
var damage_bar_timer: float = 0.0

func _ready() -> void:
    if show_damage_bar:
        damage_bar.max_value = max_value
        damage_bar.value = value

func update_hp(current: int, maximum: int) -> void:
    max_value = maximum
    target_value = current
    
    if not smooth_transition:
        value = current
        if show_damage_bar:
            damage_bar.value = current
    else:
        current_display = value
        damage_bar_timer = damage_bar_delay

func _process(delta: float) -> void:
    if not smooth_transition:
        return
    
    # Smooth HP bar transition
    if current_display != target_value:
        var direction = sign(target_value - current_display)
        current_display += direction * transition_speed * delta
        
        if direction > 0 and current_display > target_value:
            current_display = target_value
        elif direction < 0 and current_display < target_value:
            current_display = target_value
        
        value = current_display
    
    # Damage bar follows after delay
    if show_damage_bar and damage_bar_timer > 0:
        damage_bar_timer -= delta
        if damage_bar_timer <= 0:
            var tween = create_tween()
            tween.tween_property(damage_bar, "value", target_value, 0.3)
```

---

## 3. STAMINA SYSTEM

### 3.1. Design Specifications

**Core Properties:**
- Default maximum: 100 stamina
- Regenerates automatically when idle
- Regeneration rate: 30/second (default, configurable per character)
- Stops regenerating during actions
- Stops regenerating while blocking
- At 0 stamina: Character enters "Stunned" state

**Stamina Costs (Baseline):**
| Action | Cost |
|--------|------|
| Dash | 10 |
| Heavy Dash | 30 |
| Light Attack | 3 |
| Heavy Attack | 6 |
| Special (normal) | 10 |
| Special (enhanced) | 20 |
| Block (per hit) | 15 |
| Evade | 0 |
| Grab | 0 |
| Ultimate | 0 |

**Stunned State:**
- Duration: 120 frames (2 seconds)
- Cannot act, block, or move
- Fully vulnerable to attacks
- Stamina regenerates during stun
- Auto-exit when duration ends

---

### 3.2. Implementation

#### StaminaSystem Class

```gdscript
class_name StaminaSystem
extends Node

# Properties
var current_stamina: float = 100.0
var max_stamina: float = 100.0
var regen_rate: float = 30.0  # per second
var regen_enabled: bool = true
var regen_delay: float = 0.5  # delay after action
var regen_timer: float = 0.0

# State
var is_depleted: bool = false
var is_regenerating: bool = false

# Signals
signal stamina_changed(current: float, maximum: float, delta: float)
signal stamina_depleted()
signal stamina_restored()  # After being depleted
signal regen_started()
signal regen_stopped()

# Initialization
func initialize(maximum: float, regen: float) -> void:
    max_stamina = maximum
    current_stamina = max_stamina
    regen_rate = regen
    stamina_changed.emit(current_stamina, max_stamina, 0.0)

# Consumption
func consume(amount: float) -> bool:
    if amount <= 0:
        return true
    
    if current_stamina < amount:
        # Not enough stamina
        return false
    
    current_stamina -= amount
    interrupt_regen()
    
    stamina_changed.emit(current_stamina, max_stamina, -amount)
    
    if current_stamina <= 0:
        current_stamina = 0
        is_depleted = true
        stamina_depleted.emit()
    
    return true

# Force consume (even if not enough)
func force_consume(amount: float) -> void:
    current_stamina -= amount
    interrupt_regen()
    
    if current_stamina < 0:
        current_stamina = 0
    
    stamina_changed.emit(current_stamina, max_stamina, -amount)
    
    if current_stamina <= 0 and not is_depleted:
        is_depleted = true
        stamina_depleted.emit()

# Regeneration
var regen_delay_frames: int = 30  # 0.5 seconds at 60 FPS
var regen_timer_frames: int = 0
var regen_per_frame: float  # Calculated from regen_rate

func initialize(maximum: float, regen: float) -> void:
    max_stamina = maximum
    current_stamina = max_stamina
    regen_rate = regen
    regen_per_frame = regen_rate / 60.0  # Convert per-second to per-frame
    stamina_changed.emit(current_stamina, max_stamina, 0.0)

func tick() -> void:
    if not regen_enabled:
        return
    
    # Handle regen delay (frame-based)
    if regen_timer_frames > 0:
        regen_timer_frames -= 1
        if regen_timer_frames <= 0:
            is_regenerating = true
            regen_started.emit()
        return
    
    # Regenerate stamina (frame-based)
    if is_regenerating and current_stamina < max_stamina:
        var old_stamina = current_stamina
        current_stamina = min(current_stamina + regen_per_frame, max_stamina)
        var delta_stamina = current_stamina - old_stamina
        
        stamina_changed.emit(current_stamina, max_stamina, delta_stamina)
        
        # Restore from depleted state
        if is_depleted and current_stamina > 0:
            is_depleted = false
            stamina_restored.emit()

# Interrupt regeneration
func interrupt_regen() -> void:
    if is_regenerating:
        is_regenerating = false
        regen_stopped.emit()
    regen_timer_frames = regen_delay_frames

# Control regeneration
func enable_regen() -> void:
    regen_enabled = true

func disable_regen() -> void:
    regen_enabled = false
    is_regenerating = false

# Queries
func has_stamina(amount: float) -> bool:
    return current_stamina >= amount

func get_stamina_percentage() -> float:
    return (current_stamina / max_stamina) * 100.0

func is_stamina_depleted() -> bool:
    return is_depleted

func is_low_stamina(threshold: float = 20.0) -> bool:
    return get_stamina_percentage() <= threshold

# Instant refill (for debug/training)
func refill() -> void:
    var old = current_stamina
    current_stamina = max_stamina
    is_depleted = false
    stamina_changed.emit(current_stamina, max_stamina, max_stamina - old)
```

---

### 3.3. Block Stamina Drain

```gdscript
# In BlockState.gd
func handle_block(hit_data: HitData) -> void:
    var stamina_cost = hit_data.move_data.block_stamina_cost
    
    if fighter.resource_manager.stamina_system.consume(stamina_cost):
        # Successfully blocked
        fighter.apply_chip_damage(hit_data)
        fighter.state_machine.change_state("BlockStun")
    else:
        # Stamina depleted, guard break
        fighter.state_machine.change_state("Stunned")
```

**Block Stamina Cost:**
```gdscript
# In MoveData
@export var block_stamina_cost: float = 15.0
```

---

### 3.4. Stunned State Implementation

```gdscript
class_name StunnedState
extends State

const STUN_DURATION_FRAMES = 120  # 2 seconds at 60 FPS

var stun_timer: int = 0

func enter() -> void:
    stun_timer = STUN_DURATION_FRAMES
    fighter.animation_player.play("stunned")
    # Character is vulnerable, cannot act

func physics_update(delta: float) -> void:
    stun_timer -= 1
    
    # Stamina regenerates during stun
    fighter.resource_manager.stamina_system.update(delta)
    
    if stun_timer <= 0:
        state_machine.change_state("Idle")

func handle_input(input: InputData) -> void:
    # Cannot act while stunned
    pass

func check_transitions() -> String:
    return ""  # No transitions except timeout
```

---

### 3.5. Stamina Bar UI

```gdscript
class_name StaminaBar
extends ProgressBar

@export var normal_color: Color = Color(0.0, 0.8, 1.0)  # Cyan
@export var low_color: Color = Color(1.0, 0.8, 0.0)     # Yellow
@export var depleted_color: Color = Color(1.0, 0.2, 0.0) # Red
@export var low_threshold: float = 30.0

var flash_timer: float = 0.0

func _ready() -> void:
    max_value = 100.0

func update_stamina(current: float, maximum: float) -> void:
    max_value = maximum
    value = current
    
    # Update color based on stamina level
    var percentage = (current / maximum) * 100.0
    
    if percentage <= 0:
        modulate = depleted_color
        flash_depleted()
    elif percentage <= low_threshold:
        modulate = low_color
    else:
        modulate = normal_color

func flash_depleted() -> void:
    var tween = create_tween()
    tween.set_loops(3)
    tween.tween_property(self, "modulate:a", 0.3, 0.2)
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _process(delta: float) -> void:
    # Subtle pulse effect during regeneration
    if value < max_value and value > 0:
        flash_timer += delta * 3.0
        var pulse = (sin(flash_timer) + 1.0) / 2.0 * 0.1 + 0.9
        modulate.a = pulse
    else:
        modulate.a = 1.0
```

---

## 4. CHARACTER METER SYSTEM

### 4.1. Design Overview

**Purpose:**
- Custom resource system per character
- Used for enhanced specials, supers, or character-specific mechanics
- No universal standard (unlike Stamina/HP)

**Meter Types:**
1. **Charge Meter** - Fills over time
2. **Damage Meter** - Fills on dealing/taking damage
3. **Stack Meter** - Discrete stacks gained through conditions
4. **Hybrid Meter** - Combination of above

---

### 4.2. Base Class Implementation

#### CharacterMeter (Base)

```gdscript
class_name CharacterMeter
extends Resource

@export var meter_name: String = "Meter"
@export var max_value: float = 100.0
@export var starting_value: float = 0.0
@export var resets_on_round: bool = true

var current_value: float = 0.0

signal meter_changed(current: float, maximum: float)
signal meter_filled()
signal meter_depleted()

# Virtual methods (override in derived classes)
func initialize() -> void:
    current_value = starting_value
    meter_changed.emit(current_value, max_value)

func tick() -> void:
    pass  # Override for time-based meters (called every frame)

func on_deal_damage(damage: int) -> void:
    pass  # Override for damage-based gain

func on_take_damage(damage: int) -> void:
    pass  # Override for damage-taken gain

func on_move_used(move: MoveData) -> void:
    pass  # Override for action-based gain

# Common methods
func add_meter(amount: float) -> void:
    var old_value = current_value
    current_value = clamp(current_value + amount, 0.0, max_value)
    meter_changed.emit(current_value, max_value)
    
    if old_value < max_value and current_value >= max_value:
        meter_filled.emit()

func spend_meter(amount: float) -> bool:
    if current_value < amount:
        return false
    
    current_value -= amount
    meter_changed.emit(current_value, max_value)
    
    if current_value <= 0:
        meter_depleted.emit()
    
    return true

func has_meter(amount: float) -> bool:
    return current_value >= amount

func get_meter_percentage() -> float:
    return (current_value / max_value) * 100.0

func reset() -> void:
    current_value = starting_value
    meter_changed.emit(current_value, max_value)
```

---

### 4.3. Derived Meter Types

#### ChargeMeter (Time-Based)

```gdscript
class_name ChargeMeter
extends CharacterMeter

@export var charge_rate: float = 10.0  # per second
@export var charge_while_blocking: bool = false
@export var charge_while_attacking: bool = true
@export var charge_while_hit: bool = false

var charge_per_frame: float  # Calculated from charge_rate

func initialize() -> void:
    super.initialize()
    charge_per_frame = charge_rate / 60.0  # Convert per-second to per-frame

func tick() -> void:
    # Charge over time (frame-based)
    add_meter(charge_per_frame)
```

**Example Character:**
- Meter fills constantly
- Can spend meter for enhanced specials
- Strategic resource management

---

#### DamageMeter (Combat-Based)

```gdscript
class_name DamageMeter
extends CharacterMeter

@export var gain_on_hit_multiplier: float = 0.5  # % of damage dealt
@export var gain_on_hurt_multiplier: float = 0.3  # % of damage taken
@export var gain_on_block_multiplier: float = 0.1  # % of blocked damage

func on_deal_damage(damage: int) -> void:
    add_meter(damage * gain_on_hit_multiplier)

func on_take_damage(damage: int) -> void:
    add_meter(damage * gain_on_hurt_multiplier)

func on_block(damage: int) -> void:
    add_meter(damage * gain_on_block_multiplier)
```

**Example Character:**
- Aggressive playstyle rewarded
- Taking damage also builds meter (comeback mechanic)
- Traditional fighting game meter

---

#### StackMeter (Discrete Stacks)

```gdscript
class_name StackMeter
extends CharacterMeter

@export var max_stacks: int = 5
var current_stacks: int = 0

func initialize() -> void:
    current_stacks = 0
    current_value = 0.0
    max_value = float(max_stacks)
    meter_changed.emit(current_value, max_value)

func add_stack() -> void:
    if current_stacks < max_stacks:
        current_stacks += 1
        current_value = float(current_stacks)
        meter_changed.emit(current_value, max_value)
        
        if current_stacks >= max_stacks:
            meter_filled.emit()

func remove_stack() -> void:
    if current_stacks > 0:
        current_stacks -= 1
        current_value = float(current_stacks)
        meter_changed.emit(current_value, max_value)
        
        if current_stacks <= 0:
            meter_depleted.emit()

func spend_stacks(amount: int) -> bool:
    if current_stacks < amount:
        return false
    
    current_stacks -= amount
    current_value = float(current_stacks)
    meter_changed.emit(current_value, max_value)
    return true

func get_stack_count() -> int:
    return current_stacks

func has_stacks(amount: int) -> bool:
    return current_stacks >= amount
```

**Example Character:**
- Gain stacks on specific actions (e.g., landing specials)
- Spend stacks for buffs or enhanced moves
- Visual clarity (discrete icons)

---

### 4.4. Meter UI Integration

```gdscript
class_name CharacterMeterUI
extends Control

enum MeterDisplayType {
    BAR,      # Progress bar
    SEGMENTS, # Divided segments
    STACKS,   # Individual icons
    NUMERIC   # Number display
}

@export var display_type: MeterDisplayType = MeterDisplayType.BAR
@export var meter_color: Color = Color.YELLOW

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var segments_container: HBoxContainer = $Segments
@onready var stacks_container: HBoxContainer = $Stacks
@onready var numeric_label: Label = $NumericLabel

var meter: CharacterMeter

func initialize(character_meter: CharacterMeter) -> void:
    meter = character_meter
    meter.meter_changed.connect(_on_meter_changed)
    
    match display_type:
        MeterDisplayType.BAR:
            setup_bar()
        MeterDisplayType.SEGMENTS:
            setup_segments()
        MeterDisplayType.STACKS:
            setup_stacks()
        MeterDisplayType.NUMERIC:
            setup_numeric()

func _on_meter_changed(current: float, maximum: float) -> void:
    match display_type:
        MeterDisplayType.BAR:
            progress_bar.value = current
            progress_bar.max_value = maximum
        MeterDisplayType.SEGMENTS:
            update_segments(current, maximum)
        MeterDisplayType.STACKS:
            update_stacks(int(current))
        MeterDisplayType.NUMERIC:
            numeric_label.text = "%d / %d" % [int(current), int(maximum)]
```

---

## 5. INTEGRATION WITH FIGHTER

### 5.1. ResourceManager Node

```gdscript
class_name ResourceManager
extends Node

var fighter: Fighter

# Systems
var hp_system: HPSystem
var stamina_system: StaminaSystem
var character_meter: CharacterMeter

func _ready() -> void:
    hp_system = HPSystem.new()
    stamina_system = StaminaSystem.new()
    add_child(hp_system)
    add_child(stamina_system)

func initialize(char_data: CharacterData) -> void:
    # Initialize HP
    hp_system.initialize(char_data.max_hp)
    hp_system.hp_changed.connect(_on_hp_changed)
    hp_system.hp_depleted.connect(_on_hp_depleted)
    
    # Initialize Stamina
    stamina_system.initialize(char_data.max_stamina, char_data.stamina_regen_rate)
    stamina_system.stamina_changed.connect(_on_stamina_changed)
    stamina_system.stamina_depleted.connect(_on_stamina_depleted)
    
    # Initialize Character Meter
    if char_data.character_meter_type:
        character_meter = char_data.character_meter_type.duplicate()
        character_meter.initialize()
        character_meter.meter_changed.connect(_on_meter_changed)

func _physics_process(delta: float) -> void:
    stamina_system.update(delta)
    if character_meter:
        character_meter.update(delta)

# Signal handlers
func _on_hp_changed(current: int, maximum: int, delta: int) -> void:
    fighter.health_changed.emit(current, maximum)

func _on_hp_depleted() -> void:
    fighter.died.emit()

func _on_stamina_changed(current: float, maximum: float, delta: float) -> void:
    fighter.stamina_changed.emit(current, maximum)

func _on_stamina_depleted() -> void:
    fighter.state_machine.change_state("Stunned")

func _on_meter_changed(current: float, maximum: float) -> void:
    # Can be connected to HUD or passive abilities
    pass
```

---

## 6. BALANCING CONSIDERATIONS

### 6.1. Stamina Balancing

**Key Questions:**
- How much stamina should blocking consume?
- How fast should stamina regenerate?
- What's the cost/benefit of Heavy Dash?

**Recommended Testing Approach:**
1. Start with baseline values
2. Playtest extensively
3. Track: Stamina depletion frequency, block pressure effectiveness
4. Adjust regen rate and costs iteratively

---

### 6.2. HP-to-Stamina Ratio

**Goal:** Stamina should deplete ~2-3 times per round on average
- Too frequent: Makes blocking useless
- Too rare: Removes pressure mechanic

**Tuning Dials:**
- Stamina capacity (100 default)
- Regen rate (30/sec default)
- Block costs (15 per hit default)
- Attack stamina costs

---

### 6.3. Character Meter Balance

**Design Goals:**
- Meter should enable meaningful decisions
- Should NOT be always available (resource management)
- Should reward specific playstyles

**Examples:**
- Charge meter: Rewards patience, can hold back
- Damage meter: Rewards aggression, comeback potential
- Stack meter: Rewards execution, visible progress

---

## 7. TESTING & DEBUG TOOLS

### 7.1. Debug Commands

```gdscript
# In ResourceManager (debug builds only)
func _input(event: InputEvent) -> void:
    if not OS.is_debug_build():
        return
    
    if event.is_action_pressed("debug_refill_hp"):
        hp_system.set_hp(hp_system.max_hp)
    
    if event.is_action_pressed("debug_refill_stamina"):
        stamina_system.refill()
    
    if event.is_action_pressed("debug_deplete_stamina"):
        stamina_system.force_consume(stamina_system.max_stamina)
    
    if event.is_action_pressed("debug_fill_meter"):
        if character_meter:
            character_meter.add_meter(character_meter.max_value)
```

---

### 7.2. Training Mode Features

**Resource Control Panel:**
- Set HP to specific value
- Set Stamina to specific value
- Toggle infinite stamina
- Toggle infinite meter
- Display resource consumption per action

**Data Display:**
- Real-time HP/Stamina/Meter values
- Consumption per action
- Regeneration rate
- Time to full stamina

---

## SUMMARY

The resource system provides:
- **HP:** Traditional health with chip damage on block
- **Stamina:** Core defensive resource, no blocking at 0
- **Character Meter:** Custom mechanics per character

All three systems integrate seamlessly with the Fighter class and provide clear feedback through UI and signals.

**Key Design Principle:** Stamina is the primary innovation that differentiates this game from traditional fighters—block as a resource, not a safe state.
