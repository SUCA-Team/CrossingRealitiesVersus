# Component Communication Architecture
## Crossing Realities Versus

**Date:** January 4, 2026  

---

## 1. OVERVIEW

This document explains how core gameplay components communicate with each other in the fighting game. The architecture follows a **hierarchical tick-based system** with clear communication patterns for deterministic, frame-perfect execution.

**Key Principles:**
- Single source of truth (GameManager)
- Deterministic execution order
- Frame-perfect synchronization
- Minimal coupling between systems

---

## 2. ARCHITECTURAL OVERVIEW

### 2.1. Communication Hierarchy

```
GameManager (Autoload)
    ↓ tick()
MatchManager
    ↓ tick()
Fighter 1 ←→ Fighter 2 (via collision)
    ↓ tick()
    ├→ InputBuffer (owned by Fighter)
    ├→ StateMachine
    ├→ ResourceManager
    ├→ MoveSystem
    ├→ CombatSystem
    ├→ StatusManager
    └→ PassiveAbility

InputManager (Autoload)
    ↑ poll_input()
    (stateless, called by Fighter)
```

---

## 3. COMMUNICATION PATTERNS

### 3.1. Tick Cascade (Parent → Child)

**Pattern:** Synchronous method calls down the hierarchy

**Purpose:** Ensures deterministic execution order every frame

**Flow:**
```gdscript
# GameManager._physics_process() at 60 FPS
func _physics_process(delta: float) -> void:
    current_frame += 1
    tick()

func tick() -> void:
    if current_match:
        current_match.tick()  # Cascade to MatchManager
```

```gdscript
# MatchManager.tick()
func tick() -> void:
    p1_fighter.tick()  # Fighter 1 updates
    p2_fighter.tick()  # Fighter 2 updates
    update_timer()     # Match timer
    check_win_conditions()
```

```gdscript
# Fighter.tick()
func tick() -> void:
    # 1. Poll input first
    var current_input = InputManager.poll_input(player_id)
    input_buffer.add_input(current_input)
    
    # 2. Update state machine (decides actions)
    state_machine.tick()
    
    # 3. Update resources (regen, decay)
    resource_manager.tick()
    
    # 4. Update move system (frame data)
    move_system.tick()
    
    # 5. Update combat (hitboxes, combos)
    combat_system.tick()
    
    # 6. Update status effects
    status_manager.tick()
    
    # 7. Update passive ability
    passive_ability.tick()
    
    # 8. Apply physics
    move_and_slide()
```

**Characteristics:**
- ✅ One-way flow (parent calls child)
- ✅ Guaranteed order
- ✅ Synchronous execution
- ❌ Child never calls parent's tick()

---

### 3.2. Pull-Based Data Access (Component → Service)

**Pattern:** Component requests data from a service

**Purpose:** Components get information when needed without coupling

**Examples:**

#### Fighter → InputManager
```gdscript
# Fighter pulls input data
func tick() -> void:
    var current_input = InputManager.poll_input(player_id)  # PULL
    input_buffer.add_input(current_input)
```

#### State → InputBuffer
```gdscript
# State checks for commands in Fighter's buffer
func tick() -> void:
    var attack_cmd = CommandDetector.detect_attack_command(
        fighter.input_buffer,  # PULL from Fighter's buffer
        fighter.facing_right
    )
    if not attack_cmd.is_empty():
        fighter.move_system.execute_move(...)
```

#### MoveSystem → ResourceManager
```gdscript
# MoveSystem checks if resources are available
func can_execute_move(move: MoveData) -> bool:
    if move.stamina_cost > 0:
        if not fighter.resource_manager.has_stamina(move.stamina_cost):  # PULL
            return false
    return true
```

**Characteristics:**
- ✅ Decoupled (component doesn't know when service updates)
- ✅ On-demand access
- ✅ No circular dependencies
- ✅ Service is stateless (InputManager) or encapsulated (ResourceManager)

---

### 3.3. Command Pattern (Component → Component)

**Pattern:** Component tells another component to do something

**Purpose:** Execute actions while maintaining encapsulation

**Examples:**

#### StateMachine → MoveSystem
```gdscript
# State detects input and commands MoveSystem
class IdleState extends State:
    func tick() -> void:
        var attack_cmd = CommandDetector.detect_attack_command(
            fighter.input_buffer, 
            fighter.facing_right
        )
        
        if not attack_cmd.is_empty():
            # COMMAND: Tell MoveSystem to execute move
            fighter.move_system.execute_attack(
                attack_cmd["button"],
                attack_cmd["modifier"]
            )
```

#### MoveSystem → CombatSystem
```gdscript
# MoveSystem commands CombatSystem to spawn hitboxes
func execute_move(move: MoveData) -> void:
    current_move = move
    current_frame_in_move = 0
    
    for hitbox_data in move.hitboxes:
        # COMMAND: Tell CombatSystem to create hitbox
        fighter.combat_system.spawn_hitbox(
            hitbox_data,
            fighter.facing_right
        )
```

#### MoveSystem → ResourceManager
```gdscript
# MoveSystem commands ResourceManager to consume resources
func execute_move(move: MoveData) -> void:
    # COMMAND: Consume stamina
    fighter.resource_manager.consume_stamina(move.stamina_cost)
    
    # COMMAND: Consume meter
    if move.meter_cost > 0:
        fighter.resource_manager.consume_meter(move.meter_cost)
```

**Characteristics:**
- ✅ Clear intent (verb-based methods: execute, spawn, consume)
- ✅ Encapsulation maintained
- ✅ One-way communication
- ✅ Easy to test and mock

---

### 3.4. Event Broadcasting (Component → Observers)

**Pattern:** Component emits signals, observers react

**Purpose:** Decouple logic from presentation/audio/effects

**Examples:**

#### Fighter → UI/VFX
```gdscript
# Fighter broadcasts state changes
signal health_changed(new_hp: int, max_hp: int)
signal stamina_changed(new_stamina: float, max_stamina: float)
signal died()
signal move_started(move_name: String)
signal hit_connected(damage: int)
signal was_hit(damage: int)

func take_damage(hit_data: HitData) -> void:
    var damage = calculate_damage(hit_data)
    resource_manager.damage(damage)
    
    # BROADCAST: Anyone listening can react
    was_hit.emit(damage)
    health_changed.emit(resource_manager.get_hp(), resource_manager.max_hp)
```

#### UI/VFX → Fighter (Observers)
```gdscript
# In HPBar.gd
func _ready() -> void:
    fighter.health_changed.connect(_on_health_changed)

func _on_health_changed(new_hp: int, max_hp: int) -> void:
    update_bar(new_hp, max_hp)

# In HitVFX.gd
func _ready() -> void:
    fighter.was_hit.connect(_on_fighter_hit)

func _on_fighter_hit(damage: int) -> void:
    play_hit_effect()
```

**Characteristics:**
- ✅ Decoupled (Fighter doesn't know about UI)
- ✅ Multiple observers can listen
- ✅ Used for presentation layer (UI, audio, VFX)
- ❌ NOT used for core gameplay logic (for determinism)

---

### 3.5. Collision-Based Communication (Fighter ↔ Fighter)

**Pattern:** Godot physics engine detects collisions, triggers callbacks

**Purpose:** Cross-fighter interaction via hitbox/hurtbox system

**Flow:**

#### 1. Hitbox Creation
```gdscript
# MoveSystem spawns hitbox
func spawn_hitbox(hitbox_data: HitboxData) -> void:
    var hitbox = combat_system.hitbox_manager.get_hitbox()
    hitbox.setup(hitbox_data, fighter)
    hitbox.set_collision_layer_bit(fighter.player_id, true)  # P1 or P2
```

#### 2. Collision Detection (Godot Engine)
```gdscript
# Hitbox (Area2D) detects Hurtbox (Area2D)
func _on_area_entered(area: Area2D) -> void:
    if area is Hurtbox:
        if area.fighter.player_id != self.fighter.player_id:  # Opponent only
            # COLLISION DETECTED
            on_hit(area)
```

#### 3. Damage Application
```gdscript
# Hitbox → Opponent Fighter
func on_hit(hurtbox: Hurtbox) -> void:
    var hit_data = create_hit_data()
    
    # CROSS-FIGHTER CALL: Direct method call to opponent
    hurtbox.fighter.take_damage(hit_data)
    
    # Notify own fighter
    fighter.on_hit_connected(hit_data)
```

#### 4. Opponent Reacts
```gdscript
# In Fighter.gd
func take_damage(hit_data: HitData) -> void:
    # Apply damage
    resource_manager.damage(hit_data.damage)
    
    # Change state
    state_machine.change_state("HitStun", {
        "duration": hit_data.hitstun_frames,
        "knockback": hit_data.knockback
    })
    
    # Clear input buffer (interrupted)
    input_buffer.clear()
    
    # Broadcast
    was_hit.emit(hit_data.damage)
```

**Characteristics:**
- ✅ Only cross-fighter communication method
- ✅ Handled by Godot engine (reliable)
- ✅ Uses collision layers for P1/P2 isolation
- ✅ Direct method call after collision detected

---

### 3.6. Shared State via Fighter (Hub Pattern)

**Pattern:** Fighter acts as central data hub, components access fighter's properties

**Purpose:** Components share common state without knowing about each other

**Fighter as Hub:**
```gdscript
class_name Fighter
extends CharacterBody2D

# Shared state that all components can access
var player_id: int
var facing_right: bool
var is_grounded: bool
var current_move: MoveData
var combo_count: int

# Component references
var state_machine: StateMachine
var resource_manager: ResourceManager
var move_system: MoveSystem
var combat_system: CombatSystem
var input_buffer: InputBuffer
```

**Examples:**

#### Components Reading Fighter State
```gdscript
# CommandDetector needs facing direction
var dash_cmd = CommandDetector.detect_dash_command(
    fighter.input_buffer,
    fighter.facing_right  # Shared state
)

# MoveSystem checks grounded state
func can_execute_move(move: MoveData) -> bool:
    if move.requires_grounded and not fighter.is_grounded:  # Shared state
        return false
```

#### Components Writing Fighter State
```gdscript
# MoveSystem updates fighter's current move
func execute_move(move: MoveData) -> void:
    fighter.current_move = move  # Update shared state
    fighter.velocity = Vector2.ZERO

# CombatSystem updates combo count
func on_hit_connected(hit_data: HitData) -> void:
    fighter.combo_count += 1  # Update shared state
```

**Characteristics:**
- ✅ Components don't need references to each other
- ✅ Single source of truth (Fighter)
- ✅ Easy to access common data
- ⚠️ Be careful not to create hidden dependencies

---

## 4. DETAILED COMPONENT INTERACTIONS

### 4.1. Input Flow: Keyboard → Action

```
┌─────────────────────────────────────────────────────────────┐
│ FRAME N: Input Processing                                   │
└─────────────────────────────────────────────────────────────┘

1. Godot Engine detects keyboard state

2. Fighter.tick() calls InputManager.poll_input(player_id)
   ↓
3. InputManager reads Godot Input singleton
   ↓
4. InputManager creates InputData with timestamp
   ↓
5. Fighter adds InputData to its input_buffer
   ↓
6. StateMachine.tick() executes current state
   ↓
7. State uses CommandDetector to check input_buffer
   ↓
8. CommandDetector returns command (e.g., "dash", "forward_light")
   ↓
9. State calls fighter.move_system.execute_move() or state_machine.change_state()
```

**Key Points:**
- Input polled once per fighter per frame
- Input stored in fighter's local buffer (not global)
- Command detection happens in states, not centrally
- States make decisions based on buffered inputs

---

### 4.2. Attack Flow: Button Press → Damage

```
┌─────────────────────────────────────────────────────────────┐
│ FULL ATTACK SEQUENCE                                         │
└─────────────────────────────────────────────────────────────┘

FRAME 100: Input Detection
    Fighter.tick()
    └→ State detects "forward + light" in input_buffer
    └→ State calls move_system.execute_attack("light", "forward")

FRAME 100: Move Execution
    MoveSystem.execute_attack()
    ├→ Looks up MoveData from character_data
    ├→ Checks can_execute_move() (resources, state)
    ├→ Consumes stamina via resource_manager.consume_stamina()
    ├→ Changes state via state_machine.change_state("Attack")
    └→ Stores current_move reference

FRAME 100-105: Attack Animation
    AttackState.tick() every frame
    └→ Increments frame counter
    └→ Checks move.hitboxes for spawn timing

FRAME 103: Hitbox Spawns (based on move data)
    MoveSystem.tick()
    └→ Detects frame 3 of move
    └→ Calls combat_system.spawn_hitbox(hitbox_data)
    
    CombatSystem.spawn_hitbox()
    ├→ Gets Hitbox from object pool
    ├→ Configures position, size, damage, hitstun
    ├→ Sets collision layer (P1 or P2)
    └→ Activates hitbox in scene

FRAME 103: Collision Detection (Godot Engine)
    Hitbox (Area2D) enters Hurtbox (Area2D)
    └→ _on_area_entered(hurtbox) called by engine

FRAME 103: Hit Confirmation
    Hitbox.on_hit(hurtbox)
    ├→ Creates HitData (damage, hitstun, knockback)
    ├→ Calls hurtbox.fighter.take_damage(hit_data)  ← CROSS-FIGHTER
    └→ Calls attacker.combat_system.on_hit_connected()

FRAME 103: Damage Application (Defender)
    Defender.take_damage(hit_data)
    ├→ resource_manager.damage(hit_data.damage)
    ├→ state_machine.change_state("HitStun")
    ├→ input_buffer.clear()  (interrupt)
    ├→ velocity = hit_data.knockback
    └→ was_hit.emit(damage)  (signal for UI/VFX)

FRAME 103: Hit Registration (Attacker)
    Attacker.combat_system.on_hit_connected()
    ├→ combo_tracker.register_hit()
    ├→ fighter.combo_count += 1
    └→ fighter.hit_connected.emit(damage)

FRAME 104-110: Hitstun
    Defender in HitStunState
    └→ Can't act, just counts frames
    └→ Transitions to Idle when frames_in_state >= hitstun_duration

FRAME 106: Recovery
    Attacker still in AttackState (recovery frames)
    └→ Can't act, animation plays
    └→ Input buffer stores any buttons pressed

FRAME 111: Both Actionable
    Both fighters return to Idle/neutral state
```

**Timeline Visualization:**
```
Frame: 100  101  102  103  104  105  106  107  108  109  110  111
P1:    [====Attack State====][=====Recovery=====]              Idle
       ^    ^    ^    ^Hit!
       Input     Hitbox
       
P2:    Idle                  [======HitStun======]              Idle
                             ^Damage Applied
```

---

### 4.3. Resource Management Flow

#### Stamina Regeneration
```
Every Frame (if not blocking):
    Fighter.tick()
    └→ ResourceManager.tick()
        └→ StaminaSystem.tick()
            ├→ current_stamina += regen_per_frame
            ├→ Clamps to max_stamina
            └→ fighter.stamina_changed.emit()  (for UI)
```

#### Stamina Consumption
```
Move Execution:
    MoveSystem.execute_move(move)
    ├→ Checks can_execute_move()
    │   └→ resource_manager.has_stamina(move.stamina_cost)
    └→ resource_manager.consume_stamina(move.stamina_cost)
        └→ StaminaSystem.consume()
            ├→ current_stamina -= amount
            ├→ fighter.stamina_changed.emit()
            └→ if current_stamina <= 0:
                    fighter.on_stamina_depleted()
```

#### Stamina Depletion (Guard Break)
```
StaminaSystem.tick() detects 0 stamina:
    └→ fighter.on_stamina_depleted()
        └→ state_machine.change_state("Stunned")
            ├→ StunnedState prevents all actions
            ├→ Duration based on character data
            └→ fighter.stamina_depleted.emit()  (for UI/VFX)
```

#### Character Meter Building
```
Damage Taken:
    Fighter.take_damage(hit_data)
    └→ resource_manager.add_meter(hit_data.damage * meter_gain_multiplier)
        └→ CharacterMeter.add()
            └→ fighter.meter_changed.emit()

Hit Connected:
    CombatSystem.on_hit_connected()
    └→ fighter.resource_manager.add_meter(damage * 0.5)
```

---

### 4.4. State Machine Flow

#### State Transitions
```
Current State → New State:

1. Something triggers transition:
   - Input detected (attack button)
   - Timer expired (recovery finished)
   - Event occurred (hit by opponent)

2. StateMachine.change_state("NewState", params)
   ├→ Calls current_state.exit(fighter)
   ├→ Sets current_state = new_state
   ├→ Calls new_state.enter(fighter, params)
   └→ Resets frames_in_state = 0

3. New state takes control:
   - State.tick() called every frame
   - State reads fighter properties
   - State modifies fighter (velocity, etc.)
   - State can trigger another transition
```

#### Example: Idle → Attack → Recovery → Idle
```gdscript
# IDLE STATE
class IdleState extends State:
    func tick() -> void:
        # Check for attack input
        var attack_cmd = CommandDetector.detect_attack_command(
            fighter.input_buffer, fighter.facing_right
        )
        
        if not attack_cmd.is_empty():
            # Transition to attack
            fighter.move_system.execute_attack(...)
            # MoveSystem changes state to "Attack"

# ATTACK STATE
class AttackState extends State:
    var move: MoveData
    
    func enter(params: Dictionary) -> void:
        move = params["move"]
    
    func tick() -> void:
        frames_in_state += 1
        
        # Check if move finished
        if frames_in_state >= move.total_frames:
            state_machine.change_state("Idle")

# State machine ensures only one state active at a time
```

---

### 4.5. Status Effect Flow

#### Application
```
Hit with status effect:
    Fighter.take_damage(hit_data)
    └→ if hit_data.status_effect:
            status_manager.apply_status(hit_data.status_effect)
```

#### Update Every Frame
```
Fighter.tick()
└→ StatusManager.tick()
    └→ for each active_status:
        ├→ status.tick(fighter)  ← Status modifies fighter directly
        ├→ status.duration_frames -= 1
        └→ if duration <= 0:
                remove_status(status)
```

#### Example: Burn Status
```gdscript
class BurnStatus extends StatusEffect:
    var damage_per_frame: float = 2.0
    
    func tick(fighter: Fighter) -> void:
        # Directly modify fighter's resources
        fighter.resource_manager.damage(damage_per_frame)
        
        # Could also affect other properties
        fighter.defense_multiplier *= 0.9
```

---

### 4.6. Passive Ability Flow

#### Continuous Monitoring
```
Fighter.tick()
└→ PassiveAbility.tick()
    └→ Checks conditions every frame
    └→ Applies effects when triggered
```

#### Example: Counter Passive
```gdscript
class CounterPassive extends PassiveAbility:
    func tick() -> void:
        # Monitor for block → attack input
        if fighter.state_machine.current_state_name == "BlockStun":
            if fighter.input_buffer.has_button_press("light", 3):
                # Trigger counter
                fighter.move_system.execute_move("counter_attack")
                fighter.state_machine.change_state("CounterAttack")
```

#### Example: Rage Passive
```gdscript
class RagePassive extends PassiveAbility:
    func tick() -> void:
        # Check HP percentage
        var hp_percent = fighter.resource_manager.get_hp_percent()
        
        if hp_percent < 0.3:  # Below 30%
            fighter.damage_multiplier = 1.5
        else:
            fighter.damage_multiplier = 1.0
```

---

## 5. COMMUNICATION ANTI-PATTERNS

### ❌ What NOT to Do

#### 1. Circular Ticking
```gdscript
# BAD: Parent ticks child, child ticks parent
func tick() -> void:
    child.tick()

# In child:
func tick() -> void:
    parent.tick()  # NEVER DO THIS
```

#### 2. Multiple _physics_process
```gdscript
# BAD: Only GameManager should have _physics_process
class Fighter:
    func _physics_process(delta):  # DON'T
        tick()
```

#### 3. Using Signals for Gameplay Logic
```gdscript
# BAD: Signals introduce non-determinism
func execute_move():
    move_executed.emit()  # Don't rely on this for logic

# Instead, use direct calls:
func execute_move():
    combat_system.spawn_hitbox()  # Direct call
```

#### 4. Global State Outside GameManager
```gdscript
# BAD: Static/global variables in multiple places
class SomeSystem:
    static var global_frame: int  # DON'T
    
# GOOD: Use GameManager.current_frame
func tick():
    var frame = GameManager.current_frame  # Single source
```

#### 5. Components Knowing About UI
```gdscript
# BAD: Gameplay code coupled to UI
class Fighter:
    func take_damage(damage):
        hp -= damage
        hp_bar.update()  # DON'T reference UI
        
# GOOD: Use signals for UI
class Fighter:
    func take_damage(damage):
        hp -= damage
        health_changed.emit(hp, max_hp)  # UI listens
```

---

## 6. TESTING & DEBUGGING COMMUNICATION

### 6.1. Debugging Tools

#### Communication Logger
```gdscript
class CommunicationLogger:
    static func log_call(caller: String, method: String, target: String):
        if OS.is_debug_build():
            print("[Frame %d] %s → %s.%s()" % [
                GameManager.current_frame,
                caller,
                target,
                method
            ])

# Usage:
func execute_move(move: MoveData):
    CommunicationLogger.log_call("MoveSystem", "spawn_hitbox", "CombatSystem")
    combat_system.spawn_hitbox(...)
```

#### State Visualizer
```gdscript
# Shows current state of all systems
class SystemStateDisplay extends Label:
    func _process(_delta):
        text = """
        Frame: %d
        P1 State: %s
        P1 Move: %s
        P1 HP: %d
        P1 Stamina: %.1f
        """ % [
            GameManager.current_frame,
            p1.state_machine.current_state_name,
            p1.current_move.name if p1.current_move else "None",
            p1.resource_manager.get_hp(),
            p1.resource_manager.get_stamina()
        ]
```

### 6.2. Unit Testing Communication

#### Test State Transitions
```gdscript
func test_idle_to_attack_transition():
    var fighter = Fighter.new()
    fighter.state_machine.change_state("Idle")
    
    # Simulate input
    var input = InputData.new()
    input.button_presses["light"] = true
    fighter.input_buffer.add_input(input)
    
    # Execute tick
    fighter.state_machine.tick()
    
    # Assert state changed
    assert(fighter.state_machine.current_state_name == "Attack")
```

#### Test Resource Communication
```gdscript
func test_stamina_consumption():
    var fighter = Fighter.new()
    var initial_stamina = fighter.resource_manager.get_stamina()
    
    # Execute move with stamina cost
    var move = MoveData.new()
    move.stamina_cost = 20
    fighter.move_system.execute_move(move)
    
    # Assert stamina consumed
    assert(fighter.resource_manager.get_stamina() == initial_stamina - 20)
```

---

## 7. PERFORMANCE CONSIDERATIONS

### 7.1. Communication Overhead

**Minimal Overhead Patterns:**
- ✅ Direct method calls (fastest)
- ✅ Property access via references (fast)
- ✅ Tick cascade (one call per frame)

**Higher Overhead Patterns:**
- ⚠️ Signals (emission + connection lookup)
- ⚠️ Dictionary passing (allocation)
- ⚠️ String comparisons (for command names)

### 7.2. Optimization Strategies

#### Cache References
```gdscript
# GOOD: Cache component references
func _ready():
    state_machine = $StateMachine
    resource_manager = $ResourceManager

func tick():
    state_machine.tick()  # Cached reference
```

#### Minimize Allocations
```gdscript
# BAD: Creates new dictionary every frame
func get_attack_data() -> Dictionary:
    return {"damage": 10, "hitstun": 5}  # Allocates

# GOOD: Return existing object
func get_attack_data() -> AttackData:
    return cached_attack_data  # No allocation
```

#### Use Object Pooling
```gdscript
# For frequently created/destroyed objects
class HitboxManager:
    var hitbox_pool: Array[Hitbox] = []
    
    func get_hitbox() -> Hitbox:
        if hitbox_pool.is_empty():
            return Hitbox.new()
        return hitbox_pool.pop_back()  # Reuse
    
    func return_hitbox(hitbox: Hitbox):
        hitbox_pool.append(hitbox)  # Pool for reuse
```

---

## 8. SUMMARY

### Communication Matrix

| From → To | Pattern | Purpose | Example |
|-----------|---------|---------|---------|
| GameManager → MatchManager | Tick Cascade | Frame update | `match.tick()` |
| MatchManager → Fighter | Tick Cascade | Frame update | `fighter.tick()` |
| Fighter → Subsystems | Tick Cascade | Frame update | `state_machine.tick()` |
| Fighter → InputManager | Pull | Get input data | `poll_input(id)` |
| State → MoveSystem | Command | Execute move | `execute_attack()` |
| MoveSystem → CombatSystem | Command | Spawn hitbox | `spawn_hitbox()` |
| MoveSystem → ResourceManager | Command | Consume resources | `consume_stamina()` |
| Hitbox → Opponent Fighter | Collision + Call | Apply damage | `take_damage()` |
| Fighter → UI | Signal | Update display | `health_changed.emit()` |
| All → Fighter | Shared State | Access properties | `fighter.facing_right` |

### Key Takeaways

1. **Hierarchical Tick System:** Single source (GameManager) cascades down
2. **Pull-Based Input:** Fighters poll input when needed
3. **Command Pattern:** Components tell each other what to do
4. **Event Broadcasting:** Signals decouple logic from presentation
5. **Collision-Based:** Only cross-fighter communication method
6. **Shared State:** Fighter acts as central hub
7. **Deterministic:** No race conditions, predictable execution
8. **Frame-Perfect:** Everything synchronized to 60 FPS

This architecture ensures reliable, testable, and deterministic fighting game mechanics.
