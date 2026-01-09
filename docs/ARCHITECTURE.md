# Crossing Realities Versus - System Architecture
**Date:** January 8, 2026  
**Version:** 2.0 - Rollback-Ready Architecture

---

## 1. CORE DESIGN PRINCIPLES

### 1.1. Separation of Concerns

**Three-Layer Architecture:**

```
┌─────────────────────────────────────────────────┐
│ PRESENTATION LAYER (Godot Nodes)               │
│ - Character (Node2D): Sprites, animations      │
│ - UI: Health bars, meters, effects             │
│ - Audio: Sound effects, music                  │
│ - Particles: VFX, hit sparks                   │
└────────────────┬────────────────────────────────┘
                 │ Syncs from ↓
┌─────────────────────────────────────────────────┐
│ GAME STATE LAYER (Pure Data - RefCounted)      │
│ - PlayerState: Position, velocity, resources   │
│ - CombatState: Health, meter, combo, status    │
│ - MatchState: Frame, timer, round, score       │
│ ← All deterministic, serializable for rollback │
└────────────────┬────────────────────────────────┘
                 │ Updated by ↓
┌─────────────────────────────────────────────────┐
│ SYSTEMS LAYER (Logic Processing)               │
│ - InputSystem: Poll → Command                  │
│ - StateMachine: State transitions              │
│ - CombatSystem: Hitbox collision, damage       │
│ - PhysicsSystem: Movement, gravity             │
│ - StatusSystem: Buffs, debuffs, passives       │
└─────────────────────────────────────────────────┘
```

**Why This Matters:**
- **Rollback:** Game state can be saved/restored without Nodes
- **Determinism:** Pure data + deterministic systems = reproducible
- **Testing:** Game logic testable without Godot scene tree
- **Performance:** Minimal state to serialize (no Node overhead)

---

## 2. STATE ARCHITECTURE

### 2.1. Core State Classes

All game state is **RefCounted** (not Node) for rollback serialization:

```gdscript
# Complete game state for one frame
class MatchSnapshot extends RefCounted:
    var frame: int
    var p1_state: PlayerSnapshot
    var p2_state: PlayerSnapshot
    var stage_data: Dictionary  # Stage-specific state
    
    func serialize() -> PackedByteArray
    func deserialize(data: PackedByteArray) -> void

# Complete player state for one frame
class PlayerSnapshot extends RefCounted:
    # Transform
    var position: Vector2
    var velocity: Vector2
    var facing_right: bool
    
    # Combat
    var health: int
    var meter: float
    var stamina: float
    var combo_count: int
    
    # State machine
    var current_state: int       # State enum (not reference!)
    var state_frame: int          # Frames in current state
    var animation_frame: int      # For sync
    
    # Lockout
    var hitstun_frames: int
    var blockstun_frames: int
    var recovery_frames: int
    
    # Active entities
    var active_hitboxes: Array[HitboxSnapshot]
    var active_projectiles: Array[ProjectileSnapshot]
    var active_statuses: Array[StatusSnapshot]
    
    func serialize() -> PackedByteArray
    func deserialize(data: PackedByteArray) -> void
```

**Critical Rules:**
- ✅ Plain data types only (int, float, Vector2, Array)
- ✅ No Node references (store IDs/enums instead)
- ✅ No signals (use polling instead)
- ✅ Deterministic methods only (no random without seeded RNG)
- ❌ Never store references to other snapshots

---

### 2.2. State vs Presentation Separation

```gdscript
# GAME STATE (RefCounted)
class PlayerState extends RefCounted:
    var position: Vector2 = Vector2.ZERO
    var health: int = 1000
    var current_state_id: int = StateID.IDLE
    
    # Updates game logic
    func tick(input: Command, systems: Systems) -> void:
        systems.state_machine.tick(self, input)
        systems.physics.tick(self)
        systems.combat.tick(self)

# PRESENTATION (Node2D)
class Character extends Node2D:
    var state: PlayerState  # Reference to game state
    
    # Syncs visuals from state
    func sync_from_state() -> void:
        position = state.position
        sprite.flip_h = not state.facing_right
        animation_player.play(StateID.to_animation(state.current_state_id))
        health_bar.value = state.health
```

**Key Insight:** Character Node is a "view" of PlayerState, not the source of truth.

---

## 3. INPUT SYSTEM (Current Implementation ✓)

**Already optimal for rollback!** Bitmasking is industry standard.

```gdscript
# Single integer stores all input (perfect for netcode)
class InputData extends RefCounted:
    var player_id: int
    var frame: int
    var held_mask: int     # 10 bits = 10 inputs
    var pressed_mask: int

# High-level intent
class Command extends RefCounted:
    enum Type { NULL, LIGHT_NEUTRAL, ... }  # 35 types
    var type: Type
    var frame: int
```

**Rollback Integration:**
```gdscript
# Store input history for rollback
class InputHistory:
    const MAX_ROLLBACK_FRAMES = 8
    var history: Array[InputData] = []
    
    func add(input: InputData) -> void:
        history.append(input)
        if history.size() > MAX_ROLLBACK_FRAMES:
            history.pop_front()
    
    func get_at_frame(frame: int) -> InputData:
        for input in history:
            if input.frame == frame:
                return input
        return null
```

**No changes needed** - current implementation is rollback-ready!

---

## 4. STATE MACHINE SYSTEM

### 4.1. State as Data (Not Objects)

**Problem with OOP States:**
```gdscript
# ❌ BAD: State objects are hard to serialize
class IdleState extends State:
    var internal_timer: float  # Can't save this for rollback!
```

**Solution: Data-Driven States:**
```gdscript
# ✅ GOOD: State is just an ID + frame counter
enum StateID {
    IDLE,
    WALK_FORWARD,
    WALK_BACK,
    DASH,
    JUMP,
    ATTACK_LIGHT,
    ATTACK_HEAVY,
    HITSTUN,
    BLOCKSTUN,
    # ... ~50 states total
}

# State machine is pure logic
class StateMachine:
    func tick(player: PlayerState, input: Command) -> void:
        match player.current_state_id:
            StateID.IDLE:
                tick_idle(player, input)
            StateID.ATTACK_LIGHT:
                tick_attack_light(player, input)
            # ...
    
    func tick_idle(player: PlayerState, input: Command) -> void:
        # Check transitions
        if input.type == Command.Type.LIGHT_NEUTRAL:
            transition_to(player, StateID.ATTACK_LIGHT)
        elif input.type == Command.Type.JUMP:
            transition_to(player, StateID.JUMP)
        # Handle movement
        if player.held_mask & InputBits.RIGHT:
            transition_to(player, StateID.WALK_FORWARD)
```

**Benefits:**
- State is just `int current_state_id` + `int state_frame` = easy to serialize
- State machine logic is stateless (operates on PlayerState)
- Clear, centralized state logic

---

### 4.2. Transition Rules

```gdscript
# Cancellable states
const CANCELLABLE_STATES = [
    StateID.IDLE,
    StateID.WALK_FORWARD,
    StateID.WALK_BACK,
]

# Cannot act during these
const LOCKOUT_STATES = [
    StateID.HITSTUN,
    StateID.BLOCKSTUN,
    StateID.ATTACK_STARTUP,
    StateID.ATTACK_RECOVERY,
]

func can_act(player: PlayerState) -> bool:
    return player.current_state_id in CANCELLABLE_STATES \
        and player.hitstun_frames == 0 \
        and player.blockstun_frames == 0 \
        and player.recovery_frames == 0
```

---

## 5. COMBAT SYSTEM

### 5.1. Hitbox as Data

```gdscript
# Hitbox is pure data (not Area2D Node)
class HitboxSnapshot extends RefCounted:
    var owner_id: int           # Which player
    var hitbox_id: int          # Unique ID
    var rect: Rect2             # Position + size (relative to character)
    var active_frames: int      # Remaining active frames
    var damage: int
    var hitstun_frames: int
    var blockstun_frames: int
    var knockback: Vector2
    var hit_once: bool         # Can only hit once
    var already_hit: Array[int]  # IDs of already hit entities
    
    func get_world_rect(char_pos: Vector2, facing_right: bool) -> Rect2:
        var world_rect = rect
        world_rect.position += char_pos
        if not facing_right:
            world_rect.position.x = char_pos.x - (rect.position.x + rect.size.x)
        return world_rect
```

**Collision Detection (System):**
```gdscript
class CombatSystem:
    func tick(p1: PlayerState, p2: PlayerState) -> void:
        # Check all hitbox vs hurtbox collisions
        for hitbox in p1.active_hitboxes:
            if hitbox.owner_id in p2.already_hit:
                continue  # Already hit by this hitbox
            
            var hit_rect = hitbox.get_world_rect(p1.position, p1.facing_right)
            var hurt_rect = get_hurtbox_rect(p2)
            
            if hit_rect.intersects(hurt_rect):
                apply_hit(p2, hitbox, p1)
                hitbox.already_hit.append(p2.player_id)
    
    func apply_hit(defender: PlayerState, hitbox: HitboxSnapshot, attacker: PlayerState) -> void:
        if is_blocking(defender):
            defender.health -= hitbox.damage * 0.1  # Chip damage
            defender.blockstun_frames = hitbox.blockstun_frames
        else:
            defender.health -= hitbox.damage
            defender.hitstun_frames = hitbox.hitstun_frames
            defender.velocity = hitbox.knockback
            attacker.combo_count += 1
```

**No Area2D needed!** Manual rect collision is deterministic and fast.

---

## 6. STATUS EFFECT SYSTEM (Passives)

### 6.1. Status as Data

```gdscript
# Status effect is pure data
class StatusSnapshot extends RefCounted:
    enum Type {
        # Buffs
        ATTACK_UP,
        DEFENSE_UP,
        SPEED_UP,
        METER_GAIN_UP,
        
        # Debuffs
        ATTACK_DOWN,
        DEFENSE_DOWN,
        SLOW,
        POISON,
        BURN,
        
        # Special
        INVINCIBLE,
        SUPER_ARMOR,
        COUNTER_STANCE,
        ABSORB,
    }
    
    var status_id: int
    var type: Type
    var remaining_frames: int
    var potency: float         # Multiplier (1.5 = 50% increase)
    var tick_damage: int        # For poison/burn
    var stacks: int            # For stackable effects
    
    func tick() -> void:
        remaining_frames -= 1
        # Tick damage applied by StatusSystem
```

### 6.2. Status System

```gdscript
class StatusSystem:
    func tick(player: PlayerState) -> void:
        # Update all statuses
        for status in player.active_statuses:
            status.tick()
            
            # Apply tick effects
            match status.type:
                StatusSnapshot.Type.POISON:
                    player.health -= status.tick_damage
                StatusSnapshot.Type.BURN:
                    player.health -= status.tick_damage
        
        # Remove expired
        player.active_statuses = player.active_statuses.filter(
            func(s): return s.remaining_frames > 0
        )
    
    func apply_status(player: PlayerState, status: StatusSnapshot) -> void:
        # Check for existing status
        for existing in player.active_statuses:
            if existing.type == status.type:
                # Stack or refresh
                if is_stackable(status.type):
                    existing.stacks += 1
                    existing.potency += status.potency * 0.5  # Diminishing returns
                else:
                    existing.remaining_frames = max(existing.remaining_frames, status.remaining_frames)
                return
        
        # Add new status
        player.active_statuses.append(status)
    
    func get_damage_multiplier(player: PlayerState) -> float:
        var mult = 1.0
        for status in player.active_statuses:
            match status.type:
                StatusSnapshot.Type.ATTACK_UP:
                    mult *= status.potency
                StatusSnapshot.Type.ATTACK_DOWN:
                    mult /= status.potency
        return mult
    
    func is_invincible(player: PlayerState) -> bool:
        return player.active_statuses.any(
            func(s): return s.type == StatusSnapshot.Type.INVINCIBLE
        )
```

---

## 7. CHARACTER SYSTEM

### 7.1. Character Data (Resource)

```gdscript
# Static character definition (loaded from .tres)
class CharacterData extends Resource:
    @export var character_name: String
    @export var max_hp: int = 1000
    @export var walk_speed: float = 200.0
    @export var dash_speed: float = 400.0
    
    # Moves
    @export var neutral_light: MoveData
    @export var forward_light: MoveData
    # ... all moves
    
    # Passives (NEW!)
    @export var passive_abilities: Array[PassiveData]
```

### 7.2. Passive Abilities

```gdscript
class PassiveData extends Resource:
    enum Trigger {
        ON_ROUND_START,
        ON_DAMAGE_DEALT,
        ON_DAMAGE_TAKEN,
        ON_KILL,
        ON_HEALTH_LOW,  # < 30%
        ON_METER_FULL,
        ON_COMBO_10,
        ALWAYS_ACTIVE,
    }
    
    @export var passive_name: String
    @export var trigger: Trigger
    @export var status_to_apply: StatusSnapshot.Type
    @export var duration_frames: int
    @export var potency: float
    
    # Conditions
    @export var health_threshold: float = 0.0
    @export var meter_threshold: float = 0.0

# Example: "Warrior's Resolve" - Attack up when HP < 30%
var warriors_resolve = PassiveData.new()
warriors_resolve.passive_name = "Warrior's Resolve"
warriors_resolve.trigger = PassiveData.Trigger.ON_HEALTH_LOW
warriors_resolve.status_to_apply = StatusSnapshot.Type.ATTACK_UP
warriors_resolve.duration_frames = 9999  # Permanent while condition met
warriors_resolve.potency = 1.3  # 30% damage increase
warriors_resolve.health_threshold = 0.3
```

---

## 8. SYSTEMS COORDINATOR

```gdscript
# Central coordinator for all game logic
class GameSystems:
    var input_system: InputSystem
    var state_machine: StateMachine
    var physics_system: PhysicsSystem
    var combat_system: CombatSystem
    var status_system: StatusSystem
    var passive_system: PassiveSystem
    
    func tick(match_state: MatchSnapshot, p1_input: InputData, p2_input: InputData) -> void:
        # 1. Input → Commands
        var p1_cmd = input_system.process(p1_input, match_state.p1_state)
        var p2_cmd = input_system.process(p2_input, match_state.p1_state)
        
        # 2. State machines
        state_machine.tick(match_state.p1_state, p1_cmd)
        state_machine.tick(match_state.p2_state, p2_cmd)
        
        # 3. Passive triggers
        passive_system.tick(match_state.p1_state)
        passive_system.tick(match_state.p2_state)
        
        # 4. Status effects
        status_system.tick(match_state.p1_state)
        status_system.tick(match_state.p2_state)
        
        # 5. Physics
        physics_system.tick(match_state.p1_state)
        physics_system.tick(match_state.p2_state)
        
        # 6. Combat (hitbox collision)
        combat_system.tick(match_state.p1_state, match_state.p2_state)
        
        # 7. Increment frame
        match_state.frame += 1
```

---

## 9. ROLLBACK INTEGRATION

### 9.1. Rollback Manager

```gdscript
class RollbackManager:
    const MAX_ROLLBACK_FRAMES = 8
    
    var state_history: Array[MatchSnapshot] = []
    var input_history: Dictionary = {}  # frame → [p1_input, p2_input]
    
    func save_state(state: MatchSnapshot) -> void:
        state_history.append(state.duplicate())
        if state_history.size() > MAX_ROLLBACK_FRAMES:
            state_history.pop_front()
    
    func rollback_to_frame(target_frame: int, systems: GameSystems) -> MatchSnapshot:
        # Find closest saved state before target
        var rollback_state: MatchSnapshot = null
        for state in state_history:
            if state.frame <= target_frame:
                rollback_state = state
            else:
                break
        
        if not rollback_state:
            push_error("Cannot rollback to frame " + str(target_frame))
            return state_history[-1]
        
        # Restore state
        var current = rollback_state.duplicate()
        
        # Re-simulate from rollback point to current
        for frame in range(rollback_state.frame + 1, target_frame + 1):
            var p1_input = input_history[frame][0]
            var p2_input = input_history[frame][1]
            systems.tick(current, p1_input, p2_input)
        
        return current
```

### 9.2. Determinism Requirements

**Strict Rules:**
- ✅ Use frame counters (not delta time)
- ✅ Use seeded RNG (not `randf()`)
- ✅ No floating point operations if possible (use fixed-point math)
- ✅ All input as integers
- ✅ All collision as integer rect math
- ❌ No `_process()` or `_physics_process()` for game logic
- ❌ No signals for game logic
- ❌ No Node operations in game state

---

## 10. DIRECTORY STRUCTURE

```
core/
├── input/
│   ├── input_bits.gd          # Bitmask constants
│   ├── input_data.gd          # Input snapshot
│   ├── input_state.gd         # Press detection
│   ├── command.gd             # High-level command
│   └── command_buffer.gd      # Buffering
│
├── state/                      # NEW: Pure game state
│   ├── match_snapshot.gd      # Complete game state
│   ├── player_snapshot.gd     # Player state
│   ├── hitbox_snapshot.gd     # Hitbox data
│   ├── projectile_snapshot.gd # Projectile data
│   └── status_snapshot.gd     # Status effect data
│
├── systems/                    # NEW: Logic processors
│   ├── state_machine.gd       # State transitions
│   ├── physics_system.gd      # Movement, gravity
│   ├── combat_system.gd       # Collision, damage
│   ├── status_system.gd       # Status effects
│   ├── passive_system.gd      # Passive abilities
│   └── game_systems.gd        # Coordinator
│
├── data/                       # Resources
│   ├── character_data.gd      # Character stats/moves
│   ├── move_data.gd           # Move properties
│   └── passive_data.gd        # NEW: Passive abilities
│
├── presentation/               # NEW: Visual only
│   ├── character_view.gd      # Syncs from PlayerSnapshot
│   ├── ui/                    # Health bars, etc.
│   └── vfx/                   # Particles, effects
│
└── match/
    ├── match.gd               # Root coordinator
    └── rollback_manager.gd    # NEW: Rollback logic
```

---

## 11. MIGRATION PLAN

### Phase 1: State Separation (Week 1)
1. Create `PlayerSnapshot` with all game state
2. Move Character to presentation layer
3. Implement `Character.sync_from_state()`

### Phase 2: Systems Refactor (Week 2)
4. Extract StateMachine as data-driven system
5. Implement CombatSystem with manual collision
6. Create StatusSystem for effects

### Phase 3: Passives (Week 3)
7. Create PassiveData resource
8. Implement PassiveSystem
9. Add passive triggers to CharacterData

### Phase 4: Rollback (Week 4)
10. Implement MatchSnapshot serialization
11. Create RollbackManager
12. Add input history storage
13. Test rollback on local match

---

## 12. BENEFITS SUMMARY

**Scalability:**
- ✅ **Rollback netcode**: Pure data state = easy save/restore
- ✅ **Character variety**: Data-driven moves/passives
- ✅ **Status effects**: Flexible buff/debuff system
- ✅ **Testing**: Game logic separate from Godot
- ✅ **Performance**: Minimal state to serialize
- ✅ **Debugging**: Can save/load exact game state
- ✅ **Replay**: Store input history only

**Current vs Optimal:**
- Input system: ✅ Already optimal
- State management: ⚠️ Needs separation
- Combat system: ⚠️ Needs data-driven approach
- Character system: ⚠️ Needs passive support
- Rollback: ❌ Not implemented

This architecture supports **all future features** while maintaining the solid input foundation you've already built.
