# Class Structure & Hierarchy
## Crossing Realities Versus

**Date:** January 8, 2026  
**Status:** Current implementation + Planned architecture

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) for three-layer separation strategy

---

## 0. EVOLUTION ROADMAP

This document tracks **two architectures**:

### Current Implementation (Section 1-3)
- ✅ Input system with bitmasking
- ✅ Frame-synchronized tick
- ✅ PlayerContext coordination
- ⚠️ State coupled to Node2D (blocks rollback)
- ❌ No state machine
- ❌ No systems layer

### Target Architecture (Section 4-7)
- Three-layer separation (Presentation/State/Systems)
- State snapshots for rollback
- Data-driven state machine
- Systems process pure data
- Status effects and passives

**Migration:** See [ARCHITECTURE.md Section 12](ARCHITECTURE.md#12-migration-plan)

---

## 1. CURRENT CLASS HIERARCHY

### 1.1. Visual Overview

```
┌─────────────────────────────────────────────────────┐
│ SCENE TREE (Godot Nodes)                            │
├─────────────────────────────────────────────────────┤
│                                                      │
│  GameManager (Autoload)                              │
│      - Global configuration (minimal)                │
│                                                      │
│  Match (Node) - Root coordinator                     │
│      - Frame counter                                 │
│      - Tick orchestration                            │
│      - Owns PlayerContexts                           │
│                                                      │
│  Character (Node2D) - Visual representation          │
│      - Sprite, animations                            │
│      - Scene tree position                           │
│      - ⚠️ Currently couples state + presentation     │
│                                                      │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ REFCOUNTED LAYER (Pure logic)                        │
├─────────────────────────────────────────────────────┤
│                                                      │
│  PlayerContext - Per-player coordinator              │
│      ├── PlayerController - Input polling            │
│      │     ├── InputState - Press detection          │
│      │     └── CommandBuffer - Buffering             │
│      ├── CombatContext - Health/meter/combo          │
│      └── Character reference                         │
│                                                      │
│  Command - High-level intent enum                    │
│  InputData - Frame snapshot (bitmasks)               │
│                                                      │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ RESOURCE LAYER (Data definitions)                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  CharacterData - Stats, moves, physics               │
│  MoveData - Frame data, damage, hitboxes             │
│  InputMapper - Key bindings per player               │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### 1.2. Ownership and References

```
Match (Node)
  ├─ owns → PlayerContext (RefCounted) - P1
  │            ├─ owns → PlayerController
  │            │            ├─ owns → InputState
  │            │            └─ owns → CommandBuffer
  │            ├─ owns → CombatContext
  │            └─ refs → Character (Node2D)
  │
  ├─ owns → PlayerContext (RefCounted) - P2
  │            └─ ... (same structure)
  │
  ├─ refs → Character (Node2D) - added to scene tree
  └─ refs → Character (Node2D) - added to scene tree
```

**Key Principles:**
- Match owns PlayerContext via variable (auto-freed when Match freed)
- PlayerContext owns controller/combat (RefCounted chain)
- Character exists in scene tree, referenced by PlayerContext
- Each PlayerContext has opponent reference (set by Match)

---

## 2. IMPLEMENTED CLASSES (CURRENT)

### 2.1. Autoload Layer

#### GameManager
**File:** `autoload/game_manager.gd`  
**Type:** Node (Autoload)  
**Status:** ✅ Placeholder

```gdscript
extends Node
# Currently minimal
func _process(delta: float) -> void:
    pass
```

**Current Role:** None (empty autoload)

**Planned Role:**
- Scene management (menu → match → results)
- Global settings (volume, keybinds)
- Match configuration (character selection, stage)
- Persistent data (unlocks, statistics)

---

### 2.2. Match Layer

#### Match
**File:** `core/match/match.gd`  
**Type:** Node  
**Status:** ✅ Implemented, ⚠️ Incomplete

**Responsibilities:**
- Frame counting (`frames_elapsed: int`)
- Tick coordination (calls `p1.tick()`, `p2.tick()`)
- Player context ownership

```gdscript
class_name Match extends Node

var frames_elapsed: int = 0
var running: bool = true
var p1: PlayerContext
var p2: PlayerContext

func _physics_process(_delta: float) -> void:
    if running:
        frames_elapsed += 1
        tick()

func tick() -> void:
    p1.tick(frames_elapsed)
    p2.tick(frames_elapsed)
```

**Missing:**
- Adding characters to scene tree
- Setting opponent references
- Collision detection
- Win condition checks
- Pause/resume logic

**Future (Rollback Era):**
- Will coordinate RollbackManager
- Store match configuration
- Handle input history

---

### 2.3. Player Layer

#### PlayerContext
**File:** `core/character/common/player_context.gd`  
**Type:** RefCounted  
**Status:** ✅ Implemented

**Core Design:** Coordinator that owns all player-specific components

```gdscript
class_name PlayerContext extends RefCounted

var player_id: int
var match_: Match
var character: Character
var controller: PlayerController
var combat: CombatContext
var opponent: PlayerContext

func _init(_player_id: int, _match: Match, _char_data: CharacterData)
func tick(frame: int) -> void
```

**Responsibilities:**
- Create and own PlayerController, CombatContext
- Reference Character (owned by scene tree)
- Coordinate tick flow: input → character update

**Why RefCounted:** Not in scene tree, purely logical container

---

#### Character
**File:** `core/character/common/character.gd`  
**Type:** Node2D  
**Status:** ✅ Created, ❌ Empty implementation

```gdscript
class_name Character extends Node2D

var char_data: CharacterData
var facing_right: bool = true

func _init(char_data_: CharacterData) -> void
func _ready() -> void  # TODO: Setup visuals
func tick(ctx: PlayerContext, frame: int) -> void  # TODO: State machine
```

**Current Problems:**
- ⚠️ Couples game state with visual representation
- ❌ No state machine implementation
- ❌ Never consumes commands from buffer
- ❌ Not added to scene tree by Match

**Future (After Migration):**
- Rename to `CharacterView`
- Become pure presentation layer
- Sync from `PlayerSnapshot` state
- No game logic, only visuals

---

### 2.4. Input System

#### PlayerController
**File:** `core/input/player_controller.gd`  
**Type:** RefCounted  
**Status:** ✅ Implemented, ⚠️ Partial command mapping

```gdscript
class_name PlayerController extends RefCounted

var player_id: int
var keymap: InputMapper
var input_state: InputState
var cmd_buffer: CommandBuffer

func tick(ctx: PlayerContext, frame: int) -> void:
    # 1. Poll keyboard → bitmask
    var raw = _poll_raw_input()
    
    # 2. Detect presses
    input_state.update(raw)
    
    # 3. Create snapshot
    var input = InputData.new(...)
    
    # 4. Map to commands
    _map_command(ctx, input)
```

**Implemented:**
- Bitmasking (10 inputs in 1 integer)
- Press detection via bitwise operations
- Light attack command mapping

**Missing:**
- Heavy attack mappings
- Dash variant mappings
- Special move mappings
- Super/ultimate combinations

**Rollback Status:** ✅ Already optimal, no changes needed

---

#### InputData
**File:** `core/input/input_data.gd`  
**Type:** RefCounted  
**Status:** ✅ Complete

```gdscript
class_name InputData extends RefCounted

var player_id: int
var frame: int
var held_mask: int     # Currently held inputs
var pressed_mask: int  # Just pressed this frame
```

**Serialization:** 16 bytes per frame (4 ints)  
**Rollback Ready:** ✅ Yes

---

#### InputState
**File:** `core/input/input_state.gd`  
**Type:** RefCounted  
**Status:** ✅ Complete

```gdscript
class_name InputState extends RefCounted

var prev_mask: int = 0
var curr_mask: int = 0

func update(new_mask: int) -> void
func pressed() -> int  # Returns curr_mask & ~prev_mask
func released() -> int
func held() -> int
```

**Purpose:** Detects button presses via bitwise comparison  
**Rollback Ready:** ✅ Yes (deterministic)

---

#### Command
**File:** `core/input/command.gd`  
**Type:** RefCounted  
**Status:** ✅ Enum defined, ⚠️ Needs refactor

```gdscript
class_name Command extends RefCounted

enum Type {
    NULL,
    LIGHT_NEUTRAL, LIGHT_FORWARD, LIGHT_BACK, LIGHT_DOWN,
    LIGHT_AIR,    # ⚠️ State-dependent, should be removed
    HEAVY_NEUTRAL, HEAVY_DOWN,
    HEAVY_AIR,    # ⚠️ State-dependent, should be removed
    DASH, HEAVYDASH, GRAB, EVADE,
    JUMP,
    # ... 35 total types
}

var type: Type
var frame: int
```

**Architectural Issue:** AIR variants depend on character state  
**Recommended Fix:** Remove `_AIR` variants, let state machine decide  
**See:** Earlier conversation about state-agnostic commands

---

#### CommandBuffer
**File:** `core/input/command_buffer.gd`  
**Type:** RefCounted  
**Status:** ✅ Implemented

```gdscript
class_name CommandBuffer extends RefCounted

const BUFFER_SIZE: int = 20
const COMMAND_WINDOW: int = 3  # frames

var buffer: Array[Command] = []

func push(cmd: Command) -> void
func pop(current_frame: int) -> Command
```

**Fixed:** Size limit added  
**Purpose:** 3-frame input leniency (50ms at 60 FPS)

---

#### InputBits
**File:** `core/input/input_bits.gd`  
**Type:** Class (static constants)  
**Status:** ✅ Complete

```gdscript
class_name InputBits

const UP    := 1 << 0  # 0b0000000001
const DOWN  := 1 << 1  # 0b0000000010
const LEFT  := 1 << 2  # 0b0000000100
const RIGHT := 1 << 3  # 0b0000001000
const LIGHT    := 1 << 4
const HEAVY    := 1 << 5
const DASH     := 1 << 6
const SPECIAL1 := 1 << 7
const SPECIAL2 := 1 << 8
const SPECIAL3 := 1 << 9
```

**Purpose:** Bit flag constants for masking operations

---

### 2.5. Combat Layer (Placeholders)

#### CombatContext
**File:** `core/character/common/combat_context.gd`  
**Type:** RefCounted  
**Status:** ❌ Placeholder only

```gdscript
class_name CombatContext extends RefCounted
# Currently empty
```

**Planned Contents:**
```gdscript
var health: int
var max_health: int
var meter: float
var stamina: float
var combo_count: int
var juggle_points: int
var hit_this_frame: bool
```

---

#### StatusManager
**File:** `core/character/common/status_manager.gd`  
**Type:** RefCounted  
**Status:** ❌ Placeholder only

```gdscript
class_name StatusManager extends RefCounted
# Currently empty
```

**Planned Contents:** See Section 5.4

---

### 2.6. Resource Layer (Data Definitions)

#### CharacterData
**File:** `core/character/common/character_data.gd`  
**Type:** Resource  
**Status:** ✅ Complete structure

```gdscript
class_name CharacterData extends Resource

# Identity
@export var character_name: String
@export var character_id: String
@export var portrait: Texture2D

# Stats
@export var max_hp: int = 1000
@export var max_stamina: float = 100.0

# Physics
@export var walk_speed: float = 200.0
@export var dash_speed: float = 400.0
@export var jump_force: float = -400.0
@export var gravity: float = 980.0

# Moves (35 MoveData exports)
@export var neutral_light: MoveData
@export var forward_light: MoveData
@export var air_light: MoveData  # ⚠️ Will be removed with command refactor
# ... all move variants
```

**Usage:** Instantiate as `.tres` files per character

---

#### MoveData
**File:** `core/character/common/move_data.gd`  
**Type:** Resource  
**Status:** ✅ Complete structure

```gdscript
class_name MoveData extends Resource

enum MoveType { NORMAL, SPECIAL, ULTIMATE }
enum HitPriority { LOW, MEDIUM, HIGH, HIGHEST }

# Identity
@export var move_name: String
@export var move_type: MoveType

# Frame Data
@export var startup_frames: int = 5
@export var active_frames: int = 3
@export var recovery_frames: int = 10

# Damage
@export var damage: int = 50
@export var chip_damage_multiplier: float = 0.1

# Stun
@export var hitstun_frames: int = 15
@export var blockstun_frames: int = 8

# Knockback
@export var knockback_force: Vector2 = Vector2(200, -100)

# Hit Properties
@export var launches: bool = false
@export var ground_bounce: bool = false
@export var wall_bounce: bool = false
@export var hard_knockdown: bool = false

# Cancel Options
@export var cancellable_on_hit: bool = true
@export var cancellable_on_block: bool = true
```

---

#### InputMapper
**File:** `utils/input_mapper/input_mapper.gd`  
**Type:** Resource  
**Status:** ✅ Complete

```gdscript
class_name InputMapper extends Resource

@export var index: int

@export var up: StringName
@export var down: StringName
@export var left: StringName
@export var right: StringName

@export var light: StringName
@export var heavy: StringName
@export var dash: StringName
@export var special1: StringName
@export var special2: StringName
@export var special3: StringName
```

**Instances:**
- `p1_input_mapper.tres` - WASD + JUIOKL
- `p2_input_mapper.tres` - Arrows + Numpad

---

## 3. CRITICAL BUGS TO FIX

### Bug #1: Commands Never Consumed ⚠️ CRITICAL
**File:** `character.gd`  
**Problem:** `tick()` is empty, never calls `ctx.controller.cmd_buffer.pop()`

```gdscript
# Current (broken)
func tick(ctx: PlayerContext, frame: int) -> void:
    pass  # Does nothing!

# Needs implementation
func tick(ctx: PlayerContext, frame: int) -> void:
    var cmd = ctx.controller.cmd_buffer.pop(frame)
    if cmd:
        # TODO: Pass to state machine
        print("Command: ", Command.Type.keys()[cmd.type])
```

---

### Bug #2: Characters Not in Scene Tree ⚠️ CRITICAL
**File:** `match.gd`  
**Problem:** Characters created but never added to tree (can't render)

```gdscript
# Fix in Match._ready()
func _ready() -> void:
    p1 = PlayerContext.new(1, self, CharacterData.new())
    p2 = PlayerContext.new(2, self, CharacterData.new())
    
    # Add these:
    p1.opponent = p2
    p2.opponent = p1
    
    add_child(p1.character)
    add_child(p2.character)
    
    # Set positions
    p1.character.position = Vector2(200, 300)
    p2.character.position = Vector2(600, 300)
    p2.character.facing_right = false
```

---

### Bug #3: CommandBuffer Size Limit
**File:** `command_buffer.gd`  
**Status:** ✅ Fixed (user already added)

---


## 4. TARGET ARCHITECTURE (PLANNED)

> **Complete details in [ARCHITECTURE.md](ARCHITECTURE.md)**

**Priority Guide:**
- ✅ **Core gameplay** - Implement first (makes game playable)
- 🌐 **Rollback-specific** - Defer until netcode phase
- All classes designed to be rollback-ready from the start

### 4.1. Three-Layer Separation

```
┌──────────────────────────────────────────┐
│  PRESENTATION LAYER (Node2D)             │
│                                          │
│  CharacterView - Visual only             │
│      - Sprite, AnimationPlayer           │
│      - Position = snapshot.position      │
│      - No game logic                     │
│                                          │
│  HitboxView - Debug visualization        │
│      - Draws Rect from snapshot          │
│                                          │
└──────────────────────────────────────────┘
         ↑ sync_from_state(snapshot)
┌──────────────────────────────────────────┐
│  GAME STATE LAYER (RefCounted)           │
│                                          │
│  MatchSnapshot - Complete game state     │
│      - frame: int                        │
│      - p1: PlayerSnapshot                │
│      - p2: PlayerSnapshot                │
│                                          │
│  PlayerSnapshot - Per-player state       │
│      - position: Vector2i                │
│      - velocity: Vector2i                │
│      - health, meter, stamina            │
│      - state_id: StateID (enum)          │
│      - state_frame: int                  │
│      - hitboxes: Array[HitboxSnapshot]   │
│      - statuses: Array[StatusSnapshot]   │
│                                          │
└──────────────────────────────────────────┘
         ↓ process(snapshot) -> updates
┌──────────────────────────────────────────┐
│  SYSTEMS LAYER (RefCounted)              │
│                                          │
│  InputSystem - Command detection         │
│  StateMachine - State transitions        │
│  CombatSystem - Collision detection      │
│  PhysicsSystem - Movement/gravity        │
│  StatusSystem - Buff/debuff ticks        │
│  PassiveSystem - Trigger checks          │
│                                          │
└──────────────────────────────────────────┘
```

### 4.2. Key Principles

**1. State is Pure Data**
- All game state in RefCounted classes
- No Node references in state
- Serializable for rollback (save/restore)
- Fixed-point integers for determinism

**2. Systems are Stateless**
- Receive snapshot, return updates
- No internal state storage
- Pure functions (same input → same output)
- Can be rerun during rollback

**3. Presentation Syncs from State**
- Reads snapshot every frame
- Never modifies game state
- Visual-only operations (particles, camera shake)
- Can lag behind state without breaking logic

---

## 5. PLANNED CLASSES (NOT YET IMPLEMENTED)

### 5.1. State Layer Classes

#### MatchSnapshot 🌐
**Type:** RefCounted  
**Status:** ❌ Not implemented  
**Priority:** 🌐 **Rollback-specific** (defer until netcode)
**Purpose:** State serialization for rollback save/restore

```gdscript
class_name MatchSnapshot extends RefCounted

var frame: int
var p1: PlayerSnapshot
var p2: PlayerSnapshot
var stage_bounds: Rect2i
var time_remaining: int

func serialize() -> Dictionary
func deserialize(data: Dictionary) -> void
func clone() -> MatchSnapshot
```

**Responsibilities:**
- Complete game state at a single frame
- Serialization for rollback save/restore 🌐
- Deep copy for snapshot history 🌐

**Note:** Game can run with PlayerSnapshot only. MatchSnapshot is purely for rollback coordination.

---

#### PlayerSnapshot ✅
**Type:** RefCounted  
**Status:** ❌ Not implemented  
**Priority:** 🔴 **Core gameplay** - Critical for state separation

```gdscript
class_name PlayerSnapshot extends RefCounted

# Physics state (fixed-point for determinism)
var position: Vector2i       # x1000 scaling
var velocity: Vector2i       # x1000 scaling
var is_grounded: bool
var facing_right: bool

# Resources
var health: int
var meter: float
var stamina: float
var stamina_locked_until: int  # Frame number

# State machine
var state_id: StateID        # Enum, not object
var state_frame: int         # Frames in current state
var lockout_frames: int      # Can't act
var invulnerable_frames: int

# Combat state
var combo_count: int
var juggle_points_used: int
var hit_this_frame: bool
var blocked_this_frame: bool

# Active entities
var hitboxes: Array[HitboxSnapshot] = []
var projectiles: Array[ProjectileSnapshot] = []
var statuses: Array[StatusSnapshot] = []

# Passive abilities (trigger state)
var passive_cooldowns: Dictionary  # passive_id: frames_remaining

func serialize() -> Dictionary  # 🌐 Only for rollback
func clone() -> PlayerSnapshot    # 🌐 Only for rollback
func is_airborne() -> bool
func can_act() -> bool
```

**Key Design:** All state as primitive types or arrays of snapshots

**Core vs Rollback:**
- ✅ **Core:** All state variables, is_airborne(), can_act()
- 🌐 **Rollback:** serialize(), clone() methods (add later)

---

#### HitboxSnapshot ✅
**Type:** RefCounted  
**Status:** ❌ Not implemented  
**Priority:** 🔴 **Core gameplay** - Needed for collision detection

```gdscript
class_name HitboxSnapshot extends RefCounted

var id: int  # Unique ID for this hitbox instance
var rect: Rect2i
var owner_id: int  # 1 or 2
var damage: int
var hit_priority: int
var frames_active: int
var max_frames: int
var hit_players: Array[int] = []  # Already hit (no double-hit)
var knockback: Vector2i
var hitstun_frames: int
var launches: bool
var ground_bounce: bool
```

---

#### ProjectileSnapshot ✅
**Type:** RefCounted  
**Status:** ❌ Not implemented  
**Priority:** 🟡 **Core gameplay** - If game has projectiles

```gdscript
class_name ProjectileSnapshot extends RefCounted

var id: int
var position: Vector2i
var velocity: Vector2i
var owner_id: int
var hitbox: HitboxSnapshot
var lifetime_frames: int
var max_lifetime: int
var reflect_count: int  # Times reflected
```

---

#### StatusSnapshot ✅
**Type:** RefCounted  
**Status:** ❌ Not implemented  
**Priority:** 🟢 **Core gameplay** - Medium priority (status effects)

```gdscript
class_name StatusSnapshot extends RefCounted

enum StatusType {
    # Buffs
    DAMAGE_BOOST,
    SPEED_BOOST,
    DEFENSE_BOOST,
    METER_GAIN_BOOST,
    INVULNERABILITY,
    
    # Debuffs
    DAMAGE_REDUCTION,
    SPEED_REDUCTION,
    STAMINA_DRAIN,
    METER_DRAIN,
    
    # Crowd Control
    STUN,
    SLOW,
    POISON,
    BURN,
    FREEZE,
    
    # Special
    COUNTER_STANCE,
    ABSORB_SHIELD,
    REFLECT,
}

var status_type: StatusType
var duration_frames: int
var frames_remaining: int
var stack_count: int
var magnitude: float  # Multiplier or flat value
var source_player: int  # Who applied it
```

---

### 5.2. Systems Layer Classes

#### StateMachine ✅
**Type:** RefCounted (stateless processor)  
**Status:** ❌ Not implemented  
**Priority:** 🔴 **Core gameplay** - CRITICAL

```gdscript
class_name StateMachine extends RefCounted

enum StateID {
    # Universal
    IDLE,
    WALK_FORWARD,
    WALK_BACKWARD,
    CROUCH,
    JUMP_STARTUP,
    AIRBORNE,
    LANDING,
    DASH_STARTUP,
    DASHING,
    
    # Defense
    BLOCKSTUN,
    HITSTUN_GROUND,
    HITSTUN_AIR,
    KNOCKDOWN,
    WAKEUP,
    
    # Light attacks (per move)
    LIGHT_NEUTRAL_STARTUP,
    LIGHT_NEUTRAL_ACTIVE,
    LIGHT_NEUTRAL_RECOVERY,
    # ... all move states
    
    # Specials, Supers...
}

# Data-driven state transition
class StateTransition:
    var next_state: StateID
    var move_data: MoveData  # If starting an attack
    var reset_frame: bool = true

# Process state machine logic
static func tick(
    state: PlayerSnapshot,
    cmd: Command,
    opponent: PlayerSnapshot,
    char_data: CharacterData
) -> StateTransition:
    
    # Check state progression first
    if state.lockout_frames > 0:
        state.lockout_frames -= 1
        return null  # No transition
    
    # Auto-progress multi-phase states
    match state.state_id:
        StateID.LIGHT_NEUTRAL_STARTUP:
            if state.state_frame >= state.move_data.startup_frames:
                return StateTransition.new(StateID.LIGHT_NEUTRAL_ACTIVE, false)
        
        StateID.LIGHT_NEUTRAL_ACTIVE:
            if state.state_frame >= state.move_data.active_frames:
                return StateTransition.new(StateID.LIGHT_NEUTRAL_RECOVERY, false)
        
        StateID.LIGHT_NEUTRAL_RECOVERY:
            if state.state_frame >= state.move_data.recovery_frames:
                return StateTransition.new(StateID.IDLE)
    
    # Handle command input
    if cmd:
        return _handle_command(state, cmd, char_data)
    
    return null

static func _handle_command(state: PlayerSnapshot, cmd: Command, data: CharacterData) -> StateTransition:
    # Context-aware command processing
    match [state.state_id, cmd.type]:
        [StateID.IDLE, Command.Type.LIGHT_ATTACK]:
            return StateTransition.new(StateID.LIGHT_NEUTRAL_STARTUP, data.neutral_light)
        
        [StateID.AIRBORNE, Command.Type.LIGHT_ATTACK]:
            return StateTransition.new(StateID.AIR_LIGHT_STARTUP, data.air_light)
        
        [StateID.IDLE, Command.Type.LIGHT_FORWARD]:
            return StateTransition.new(StateID.LIGHT_FORWARD_STARTUP, data.forward_light)
        
        # ... all command mappings
    
    return null
```

**Key Innovation:** States are enum IDs, not objects. Rollback-ready but works without rollback.

**Core vs Rollback:**
- ✅ **Core:** All state transition logic, tick(), _handle_command()
- 🌐 **Rollback benefit:** Enum IDs serialize easily (no special code needed)

---

#### CombatSystem ✅
**Type:** RefCounted (stateless processor)  
**Status:** ❌ Not implemented  
**Priority:** 🔴 **Core gameplay** - CRITICAL

```gdscript
class_name CombatSystem extends RefCounted

# Manual rectangle collision (deterministic)
static func check_collisions(
    p1: PlayerSnapshot,
    p2: PlayerSnapshot
) -> Array[HitResult]:
    
    var results: Array[HitResult] = []
    
    # Check P1's hitboxes vs P2's hurtbox
    for hitbox in p1.hitboxes:
        if hitbox.owner_id == 1 and not hitbox.hit_players.has(2):
            var p2_hurtbox = _get_hurtbox_rect(p2)
            if hitbox.rect.intersects(p2_hurtbox):
                results.append(HitResult.new(1, 2, hitbox))
                hitbox.hit_players.append(2)
    
    # Check P2's hitboxes vs P1's hurtbox
    # ... (mirror logic)
    
    return results

static func apply_hit(
    defender: PlayerSnapshot,
    hit: HitResult,
    is_blocking: bool
) -> void:
    
    if defender.invulnerable_frames > 0:
        return  # Can't be hit
    
    if is_blocking:
        # Blockstun
        defender.state_id = StateID.BLOCKSTUN
        defender.lockout_frames = hit.hitbox.blockstun_frames
        defender.health -= hit.hitbox.damage * 0.1  # Chip damage
        defender.velocity.x = hit.hitbox.knockback.x / 2
    else:
        # Hitstun
        defender.hit_this_frame = true
        defender.combo_count += 1
        
        var scaled_damage = hit.hitbox.damage
        if defender.combo_count > 1:
            scaled_damage *= _get_combo_scaling(defender.combo_count)
        
        defender.health -= scaled_damage
        defender.velocity = hit.hitbox.knockback
        
        if defender.is_grounded:
            defender.state_id = StateID.HITSTUN_GROUND
        else:
            defender.state_id = StateID.HITSTUN_AIR
        
        defender.lockout_frames = hit.hitbox.hitstun_frames
    
    defender.state_frame = 0

class HitResult:
    var attacker_id: int
    var defender_id: int
    var hitbox: HitboxSnapshot
```

**Key Feature:** Manual Rect collision, no physics engine

**Core vs Rollback:**
- ✅ **Core:** All collision and damage logic
- 🌐 **Rollback benefit:** Manual collision is deterministic (no special code needed)

---

#### PhysicsSystem ✅
**Type:** RefCounted (stateless processor)  
**Status:** ❌ Not implemented  
**Priority:** 🔴 **Core gameplay** - CRITICAL

```gdscript
class_name PhysicsSystem extends RefCounted

static func tick(
    state: PlayerSnapshot,
    char_data: CharacterData,
    stage_bounds: Rect2i
) -> void:
    
    # Apply gravity
    if not state.is_grounded:
        state.velocity.y += int(char_data.gravity * 1000)  # Fixed-point
    
    # Apply velocity
    state.position.x += state.velocity.x / 1000
    state.position.y += state.velocity.y / 1000
    
    # Ground check
    if state.position.y >= stage_bounds.position.y:
        state.position.y = stage_bounds.position.y
        state.velocity.y = 0
        state.is_grounded = true
        
        if state.state_id == StateID.AIRBORNE:
            state.state_id = StateID.LANDING
    else:
        state.is_grounded = false
    
    # Friction
    if state.is_grounded and state.state_id == StateID.IDLE:
        state.velocity.x = int(state.velocity.x * 0.9)
    
    # Bounds check
    state.position.x = clampi(state.position.x, 
        stage_bounds.position.x, 
        stage_bounds.end.x)
```

**Key Feature:** Fixed-point math (×1000) for determinism

**Core vs Rollback:**
- ✅ **Core:** All movement, gravity, collision logic
- 🌐 **Rollback benefit:** Fixed-point ensures determinism (no special code needed)

---

#### StatusSystem ✅
**Type:** RefCounted (stateless processor)  
**Status:** ❌ Not implemented  
**Priority:** 🟢 **Core gameplay** - Medium (add after basics work)

```gdscript
class_name StatusSystem extends RefCounted

static func tick(state: PlayerSnapshot) -> void:
    for i in range(state.statuses.size() - 1, -1, -1):
        var status = state.statuses[i]
        
        # Apply effect
        match status.status_type:
            StatusSnapshot.StatusType.POISON:
                state.health -= int(status.magnitude)
            
            StatusSnapshot.StatusType.BURN:
                state.health -= int(status.magnitude)
                state.meter -= status.magnitude * 0.1
            
            StatusSnapshot.StatusType.SPEED_BOOST:
                # Applied as multiplier in movement code
                pass
            
            StatusSnapshot.StatusType.INVULNERABILITY:
                state.invulnerable_frames = max(
                    state.invulnerable_frames,
                    status.frames_remaining
                )
        
        # Decrement duration
        status.frames_remaining -= 1
        if status.frames_remaining <= 0:
            state.statuses.remove_at(i)

static func add_status(
    state: PlayerSnapshot,
    status_type: StatusSnapshot.StatusType,
    duration: int,
    magnitude: float,
    source_player: int
) -> void:
    
    # Check if status is stackable
    var existing = _find_status(state, status_type)
    if existing:
        if _is_stackable(status_type):
            existing.stack_count += 1
            existing.magnitude += magnitude
            existing.frames_remaining = duration  # Refresh
        else:
            existing.frames_remaining = max(existing.frames_remaining, duration)
    else:
        var status = StatusSnapshot.new()
        status.status_type = status_type
        status.duration_frames = duration
        status.frames_remaining = duration
        status.magnitude = magnitude
        status.source_player = source_player
        state.statuses.append(status)

static func get_multiplier(
    state: PlayerSnapshot,
    stat_type: String  # "damage", "speed", "defense"
) -> float:
    
    var multiplier = 1.0
    for status in state.statuses:
        match [stat_type, status.status_type]:
            ["damage", StatusSnapshot.StatusType.DAMAGE_BOOST]:
                multiplier *= (1.0 + status.magnitude * status.stack_count)
            ["damage", StatusSnapshot.StatusType.DAMAGE_REDUCTION]:
                multiplier *= (1.0 - status.magnitude * status.stack_count)
            ["speed", StatusSnapshot.StatusType.SPEED_BOOST]:
                multiplier *= (1.0 + status.magnitude)
            ["speed", StatusSnapshot.StatusType.SLOW]:
                multiplier *= (1.0 - status.magnitude)
    
    return multiplier
```

---

#### PassiveSystem ✅
**Type:** RefCounted (stateless processor)  
**Status:** ❌ Not implemented  
**Priority:** 🟢 **Core gameplay** - Medium (character variety)

```gdscript
class_name PassiveSystem extends RefCounted

enum TriggerType {
    ON_MATCH_START,
    ON_ROUND_START,
    ON_DAMAGE_DEALT,
    ON_DAMAGE_TAKEN,
    ON_HEALTH_LOW,     # < 30%
    ON_HEALTH_CRITICAL, # < 10%
    ON_COMBO_COUNT,    # Combo >= N
    ON_OPPONENT_KNOCKED_DOWN,
}

static func check_triggers(
    state: PlayerSnapshot,
    opponent: PlayerSnapshot,
    char_data: CharacterData,
    trigger: TriggerType
) -> void:
    
    for passive_data in char_data.passive_abilities:
        if passive_data.trigger_type != trigger:
            continue
        
        # Check cooldown
        if state.passive_cooldowns.get(passive_data.id, 0) > 0:
            continue
        
        # Check condition
        if not _check_condition(state, opponent, passive_data):
            continue
        
        # Activate passive
        _activate_passive(state, passive_data)
        
        # Set cooldown
        if passive_data.cooldown_frames > 0:
            state.passive_cooldowns[passive_data.id] = passive_data.cooldown_frames

static func tick_cooldowns(state: PlayerSnapshot) -> void:
    for passive_id in state.passive_cooldowns:
        state.passive_cooldowns[passive_id] -= 1
        if state.passive_cooldowns[passive_id] <= 0:
            state.passive_cooldowns.erase(passive_id)

static func _activate_passive(state: PlayerSnapshot, data: PassiveData) -> void:
    match data.effect_type:
        PassiveData.EffectType.ADD_STATUS:
            StatusSystem.add_status(
                state,
                data.status_type,
                data.duration,
                data.magnitude,
                state.player_id
            )
        
        PassiveData.EffectType.RESTORE_HEALTH:
            state.health = mini(state.health + data.value, state.max_health)
        
        PassiveData.EffectType.RESTORE_METER:
            state.meter = minf(state.meter + data.value, 100.0)
        
        PassiveData.EffectType.TEMPORARY_INVULN:
            state.invulnerable_frames = data.duration
```

---

### 5.3. Presentation Layer Classes

#### CharacterView ✅
**Type:** Node2D  
**Status:** ❌ Not implemented (currently called "Character")  
**Priority:** 🔴 **Core gameplay** - Rename existing Character class

```gdscript
class_name CharacterView extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# Sync from game state (called every frame)
func sync_from_state(snapshot: PlayerSnapshot) -> void:
    # Position
    position.x = snapshot.position.x / 1000.0  # Fixed-point to float
    position.y = snapshot.position.y / 1000.0
    
    # Facing
    sprite.flip_h = not snapshot.facing_right
    
    # Animation (map state ID to animation name)
    var anim_name = _get_animation_for_state(snapshot.state_id)
    if anim_player.current_animation != anim_name:
        anim_player.play(anim_name)
    
    # Health bar, effects, etc.

static func _get_animation_for_state(state_id: StateMachine.StateID) -> String:
    match state_id:
        StateMachine.StateID.IDLE:
            return "idle"
        StateMachine.StateID.WALK_FORWARD, StateMachine.StateID.WALK_BACKWARD:
            return "walk"
        StateMachine.StateID.AIRBORNE:
            return "jump"
        StateMachine.StateID.LIGHT_NEUTRAL_STARTUP, \
        StateMachine.StateID.LIGHT_NEUTRAL_ACTIVE, \
        StateMachine.StateID.LIGHT_NEUTRAL_RECOVERY:
            return "light_attack"
        _:
            return "idle"
```

**Key Feature:** Read-only, never modifies game state

**Core vs Rollback:**
- ✅ **Core:** All visual sync logic
- 🌐 **Rollback benefit:** Read-only design makes rollback visual sync trivial

---

#### HitboxView ✅
**Type:** Node2D  
**Status:** ❌ Not implemented  
**Priority:** 🔵 **Core gameplay** - Low (debug visualization, optional)

```gdscript
class_name HitboxView extends Node2D

func sync_from_state(hitboxes: Array[HitboxSnapshot]) -> void:
    queue_redraw()

func _draw() -> void:
    for hitbox in _cached_hitboxes:
        var rect = Rect2(
            hitbox.rect.position.x / 1000.0,
            hitbox.rect.position.y / 1000.0,
            hitbox.rect.size.x / 1000.0,
            hitbox.rect.size.y / 1000.0
        )
        
        var color = Color.RED if hitbox.owner_id == 1 else Color.BLUE
        color.a = 0.3
        draw_rect(rect, color)
```

---

### 5.4. New Resource Classes

#### PassiveData ✅
**Type:** Resource  
**Status:** ❌ Not implemented  
**Priority:** 🟢 **Core gameplay** - Medium (character abilities)

```gdscript
class_name PassiveData extends Resource

enum EffectType {
    ADD_STATUS,
    RESTORE_HEALTH,
    RESTORE_METER,
    RESTORE_STAMINA,
    TEMPORARY_INVULN,
    DAMAGE_BOOST_NEXT_HIT,
}

@export var passive_name: String
@export var passive_id: String
@export var description: String

@export var trigger_type: PassiveSystem.TriggerType
@export var condition_value: float  # For thresholds (health %, combo count)

@export var effect_type: EffectType
@export var status_type: StatusSnapshot.StatusType  # If ADD_STATUS
@export var duration: int  # Frames
@export var magnitude: float
@export var value: int  # Flat value (health/meter restore)

@export var cooldown_frames: int = 0  # 0 = no cooldown
@export var max_activations: int = -1  # -1 = unlimited
```

**Usage in CharacterData:**
```gdscript
@export_group("Passive Abilities")
@export var passive_abilities: Array[PassiveData] = []
```

---

## 6. SYSTEMS COORDINATOR

### Match (Core + Rollback Versions)

**Two versions shown below:**
1. **✅ Core version** - What you need to make the game work
2. **🌐 Rollback additions** - What to add later for netcode (marked with 🌐)

```gdscript
class_name Match extends Node

var current_snapshot: MatchSnapshot  # 🌐 Can be just PlayerSnapshots initially
var rollback_manager: RollbackManager  # 🌐 ROLLBACK-SPECIFIC - Add later

var p1_view: CharacterView
var p2_view: CharacterView

# Systems (stateless processors)
var input_system: InputSystem
var state_machine: StateMachine
var combat_system: CombatSystem
var physics_system: PhysicsSystem
var status_system: StatusSystem
var passive_system: PassiveSystem

func _ready() -> void:
    # Create initial snapshot
    current_snapshot = MatchSnapshot.new()
    current_snapshot.p1 = PlayerSnapshot.new(1)
    current_snapshot.p2 = PlayerSnapshot.new(2)
    
    # Create visual representations
    p1_view = CharacterView.new()
    p2_view = CharacterView.new()
    add_child(p1_view)
    add_child(p2_view)
    
    # Initialize systems
    input_system = InputSystem.new()
    state_machine = StateMachine.new()
    combat_system = CombatSystem.new()
    physics_system = PhysicsSystem.new()
    status_system = StatusSystem.new()
    passive_system = PassiveSystem.new()
    
    rollback_manager = RollbackManager.new()

func _physics_process(_delta: float) -> void:
    if running:
        current_snapshot.frame += 1
        tick()

func tick() -> void:
    # 1. Input
    var p1_input = input_system.poll_input(1, current_snapshot.frame)
    var p2_input = input_system.poll_input(2, current_snapshot.frame)
    
    var p1_cmd = input_system.map_command(p1_input, current_snapshot.p1)
    var p2_cmd = input_system.map_command(p2_input, current_snapshot.p2)
    
    # 2. State machine
    var p1_transition = state_machine.tick(
        current_snapshot.p1, p1_cmd, current_snapshot.p2, p1_char_data
    )
    var p2_transition = state_machine.tick(
        current_snapshot.p2, p2_cmd, current_snapshot.p1, p2_char_data
    )
    
    if p1_transition:
        _apply_transition(current_snapshot.p1, p1_transition)
    if p2_transition:
        _apply_transition(current_snapshot.p2, p2_transition)
    
    # 3. Physics
    physics_system.tick(current_snapshot.p1, p1_char_data, stage_bounds)
    physics_system.tick(current_snapshot.p2, p2_char_data, stage_bounds)
    
    # 4. Combat
    var hits = combat_system.check_collisions(
        current_snapshot.p1,
        current_snapshot.p2
    )
    for hit in hits:
        combat_system.apply_hit(
            current_snapshot.p2 if hit.defender_id == 2 else current_snapshot.p1,
            hit,
            false  # TODO: Check blocking
        )
    
    # 5. Status effects
    status_system.tick(current_snapshot.p1)
    status_system.tick(current_snapshot.p2)
    
    # 6. Passives (tick cooldowns)
    passive_system.tick_cooldowns(current_snapshot.p1)
    passive_system.tick_cooldowns(current_snapshot.p2)
    
    # 7. Rollback (save snapshot) - 🌐 ROLLBACK-SPECIFIC
    # rollback_manager.save_snapshot(current_snapshot.clone())
    # ↑ Skip this entirely until implementing netcode
    
    # 8. Presentation sync
    p1_view.sync_from_state(current_snapshot.p1)
    p2_view.sync_from_state(current_snapshot.p2)
```

---

## 7. ROLLBACK MANAGER 🌐

**🌐 ROLLBACK-SPECIFIC - DEFER THIS ENTIRE SECTION**

This class is **only for netcode**. Your game will work perfectly without it.
Implement this in Phase 4 when adding online multiplayer.

```gdscript
class_name RollbackManager extends RefCounted

const MAX_ROLLBACK_FRAMES: int = 8

var snapshot_history: Array[MatchSnapshot] = []
var input_history: Array[Array] = []  # Array of [p1_input, p2_input] pairs

func save_snapshot(snapshot: MatchSnapshot) -> void:
    snapshot_history.append(snapshot)
    if snapshot_history.size() > MAX_ROLLBACK_FRAMES:
        snapshot_history.pop_front()

func save_inputs(p1_input: InputData, p2_input: InputData) -> void:
    input_history.append([p1_input, p2_input])
    if input_history.size() > MAX_ROLLBACK_FRAMES:
        input_history.pop_front()

func rollback_to_frame(target_frame: int, match_: Match) -> void:
    # Find snapshot at target frame
    var snapshot: MatchSnapshot = null
    for s in snapshot_history:
        if s.frame == target_frame:
            snapshot = s.clone()
            break
    
    if not snapshot:
        push_error("Cannot rollback: frame %d not in history" % target_frame)
        return
    
    # Restore state
    match_.current_snapshot = snapshot
    
    # Re-simulate from target_frame to current
    var current_frame = match_.current_snapshot.frame
    var frames_to_simulate = current_frame - target_frame
    
    for i in range(frames_to_simulate):
        var input_pair = input_history[i]
        
        # Re-run game logic with saved inputs
        # (Same tick logic as normal, but using historical inputs)
        match_.tick_with_inputs(input_pair[0], input_pair[1])
    
    # Update visuals to match corrected state
    match_.p1_view.sync_from_state(match_.current_snapshot.p1)
    match_.p2_view.sync_from_state(match_.current_snapshot.p2)

func clear() -> void:
    snapshot_history.clear()
    input_history.clear()
```

---

## 8. FILE STRUCTURE (PLANNED)

```
core/
  input/             # ✅ Implemented
    input_bits.gd
    input_data.gd
    input_state.gd
    command.gd
    command_buffer.gd
    player_controller.gd  # Will become InputSystem
  
  state/             # ❌ Not implemented
    match_snapshot.gd       # 🌐 Rollback-specific (defer)
    player_snapshot.gd      # ✅ Core (critical)
    hitbox_snapshot.gd      # ✅ Core (critical)
    projectile_snapshot.gd  # ✅ Core (if using projectiles)
    status_snapshot.gd      # ✅ Core (medium priority)
  
  systems/           # ❌ Not implemented
    state_machine.gd     # ✅ Core (CRITICAL)
    combat_system.gd     # ✅ Core (CRITICAL)
    physics_system.gd    # ✅ Core (CRITICAL)
    status_system.gd     # ✅ Core (medium priority)
    passive_system.gd    # ✅ Core (medium priority)
  
  presentation/      # ❌ Not implemented
    character_view.gd  # ✅ Core (CRITICAL - rename current Character)
    hitbox_view.gd     # ✅ Core (debug tool, optional)
    effect_view.gd     # ✅ Core (visual polish, low priority)
  
  match/             # ⚠️ Partial
    match.gd              # ✅ Core - Needs refactor for systems
    rollback_manager.gd   # 🌐 Rollback-specific (defer)
  
  character/
    common/          # ⚠️ Data classes exist, logic missing
      character_data.gd      # ✅ Complete
      move_data.gd           # ✅ Complete
      passive_data.gd        # ❌ Not implemented
      character.gd           # ⚠️ Needs refactor → CharacterView
      player_context.gd      # ⚠️ Needs refactor
      combat_context.gd      # ❌ Will be removed (state in snapshot)
      status_manager.gd      # ❌ Will become StatusSystem
```

---

## 9. MIGRATION CHECKLIST

**Legend:**
- ✅ = Core gameplay (needed to play)
- 🌐 = Rollback-specific (defer to Phase 4)

### Phase 1: State Separation (Week 1) ✅
- [ ] Create `PlayerSnapshot` with all game state ✅
- [ ] ~~Create `MatchSnapshot` coordinator~~ 🌐 Skip for now
- [ ] Create `CharacterView` (rename current `Character`) ✅
- [ ] Implement `sync_from_state()` method ✅
- [ ] Test visual sync without rollback ✅

### Phase 2: Systems Extraction (Week 2) ✅
- [ ] Create `StateMachine` with StateID enum ✅
- [ ] Create `CombatSystem` with manual collision ✅
- [ ] Create `PhysicsSystem` with fixed-point math ✅
- [ ] Create `StatusSystem` with buff/debuff logic ✅
- [ ] Refactor `Match.tick()` to use systems ✅

### Phase 3: Passives and Status (Week 3) ✅
- [ ] Create `PassiveData` resource ✅
- [ ] Create `PassiveSystem` with triggers ✅
- [ ] Create `StatusSnapshot` for effects ✅
- [ ] Implement status stacking/duration ✅
- [ ] Add passive abilities to CharacterData ✅

### Phase 4: Rollback (Week 4) 🌐
**🌐 DEFER THIS ENTIRE PHASE UNTIL READY FOR NETCODE**
- [ ] Implement `serialize()`/`deserialize()` for all snapshots 🌐
- [ ] Create `RollbackManager` with history 🌐
- [ ] Add input history storage 🌐
- [ ] Implement `rollback_to_frame()` 🌐
- [ ] Test local rollback without netcode 🌐

### Phase 5: Polish (Week 5) ✅
- [ ] Performance profiling ✅
- [ ] Complete all 35 command mappings ✅
- [ ] Add visual effects system ✅
- [ ] Comprehensive testing ✅
- [ ] Documentation updates ✅

---

## 10. CLASS COUNT SUMMARY

### Currently Implemented
- ✅ 12 classes (input system + data resources)
- ⚠️ 5 placeholder classes (empty or minimal)

### Planned to Add - Core Gameplay ✅
- ❌ 5 state classes (PlayerSnapshot, HitboxSnapshot, etc.) ✅
- ❌ 5 systems classes (StateMachine, CombatSystem, etc.) ✅
- ❌ 3 presentation classes (CharacterView, etc.) ✅
- ❌ 1 passive data resource ✅

### Planned to Add - Rollback Only 🌐
- ❌ 1 MatchSnapshot (state coordinator) 🌐
- ❌ 1 RollbackManager (netcode) 🌐
- ❌ serialize()/clone() methods in snapshots 🌐

**Core Gameplay Target:** 31 classes  
**With Rollback Target:** 33 classes

---

## 11. DESIGN PRINCIPLES SUMMARY

1. **Separation of Concerns** ✅ Core
   - State = Pure data (RefCounted)
   - Systems = Stateless processors
   - Presentation = Visual sync

2. **Determinism** ✅ Core (rollback-ready bonus)
   - Fixed-point math for physics ✅
   - No random without seeded RNG ✅
   - No floating point in game state ✅
   - Manual collision detection ✅
   - *Benefit: Makes rollback possible later without code changes*

3. **Rollback Ready** 🌐 Deferred
   - ~~Complete state in snapshots~~ ✅ Core (PlayerSnapshot exists)
   - ~~No hidden state in Nodes~~ ✅ Core (design principle)
   - ~~Fast serialization~~ 🌐 Add serialize() methods in Phase 4
   - ~~Efficient cloning~~ 🌐 Add clone() methods in Phase 4

4. **Data-Driven** ✅ Core
   - State machine uses enum IDs
   - Move data in resources
   - Passive abilities as data
   - Status effects as snapshots

5. **Composition over Inheritance** ✅ Core
   - Systems process snapshots
   - No deep class hierarchies
   - Clear interfaces
   - Easy to test

**Key Insight:** Principles 1, 2, 4, 5 make the game work AND prepare for rollback. Only principle 3 (serialization) is rollback-specific.

---

## 12. IMPLEMENTATION PRIORITY

### Immediate (Phases 1-3) ✅
**Goal:** Make the game playable

1. Fix 3 critical bugs
2. Create PlayerSnapshot (state separation)
3. Create CharacterView (rename Character)
4. Implement StateMachine, CombatSystem, PhysicsSystem
5. Add StatusSystem and PassiveSystem

**Skip for now:**
- ❌ MatchSnapshot (just use PlayerSnapshots directly)
- ❌ RollbackManager (entire class)
- ❌ serialize()/clone() methods
- ❌ Input history storage

### Later (Phase 4) 🌐
**Goal:** Add online multiplayer

Only when you're ready for netcode:
1. Add serialize()/deserialize() to PlayerSnapshot
2. Create MatchSnapshot coordinator
3. Implement RollbackManager
4. Add input history
5. Test rollback with simulated network delay

**Your architecture is already rollback-ready!** You're just deferring the serialization layer.

---

**Next Steps:** Fix critical bugs, then begin Phase 1 migration (core gameplay only).

See [ARCHITECTURE.md](ARCHITECTURE.md) for implementation details.

## 2. CORE CLASSES

### 2.1. GameManager (Autoload Singleton)

```gdscript
# Current Implementation (Minimal)
extends Node

func _process(delta: float) -> void:
    pass
```

**Current State:** Minimal implementation, placeholder for future features

**Future Responsibilities:**
- Global game state management
- Scene transitions (match loading, menus)
- Match configuration storage
- Settings persistence
- Global frame counter (if needed for rollback netcode)

**Note:** Currently, frame counting happens in Match class. Consider moving to GameManager if you plan to implement:
- Replay system (needs consistent frame numbering)
- Rollback netcode (needs global frame authority)
- Cross-scene frame tracking

---

### 2.2. Input System (Resource-Based)

**Current Implementation:** No InputManager autoload. Input handling is done via:

#### InputMapper (Resource)
```gdscript
class_name InputMapper extends Resource

@export var index: int

@export var up: StringName
@export var down: StringName
@export var left: StringName
@export var right: StringName

@export var light: StringName
@export var heavy: StringName
@export var dash: StringName
@export var special1: StringName
@export var special2: StringName
@export var special3: StringName
```

**Files:**
- `p1_input_mapper.tres` - Player 1 key bindings (WASD + JUIOKL)
- `p2_input_mapper.tres` - Player 2 key bindings (Arrows + Numpad)

**Usage:**
```gdscript
# In PlayerController
var keymap: InputMapper

func _init(index: int) -> void:
    match index:
        1:
            keymap = load("res://utils/input_mapper/p1_input_mapper.tres")
        2:
            keymap = load("res://utils/input_mapper/p2_input_mapper.tres")

func tick(ctx: PlayerContext):
    # Poll input using keymap.up, keymap.down, etc.
    pass
```

**Design Choice:** Input mappings stored as Resources instead of autoload singleton
- ✅ Easier to create custom control schemes
- ✅ No global state
- ✅ Can be saved/loaded as files

#### CommandBuffer (RefCounted)
```gdscript
class_name CommandBuffer extends RefCounted
# Currently empty - placeholder for input buffering logic
```

**Future Implementation:**
```gdscript
var buffer: Array[InputData] = []
var max_size: int = 5

func add_input(input: InputData) -> void
func get_last_n_inputs(n: int) -> Array[InputData]
func has_button_press(button: String, within_frames: int) -> bool
func clear() -> void
```

---

## 3. FIGHTER CLASS HIERARCHY

### 3.1. Fighter (Main Character Class)

```gdscript
class_name Fighter
extends CharacterBody2D

# Components (child nodes)
@onready var state_machine: StateMachine = $StateMachine
@onready var resource_manager: ResourceManager = $ResourceManager
@onready var move_system: MoveSystem = $MoveSystem
@onready var combat_system: CombatSystem = $CombatSystem
@onready var status_manager: StatusManager = $StatusManager
@onready var passive_ability: PassiveAbility = $PassiveAbility
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree

# Input buffer (per-Fighter instance!)
var input_buffer: InputBuffer

# Character data
var character_data: CharacterData
var player_id: int  # 1 or 2
var facing_right: bool = true

# Physics properties
var walk_speed: float
var dash_speed: float
var jump_force: float
var gravity: float = 980.0
var air_jumps_remaining: int

# State
var is_grounded: bool = false
var current_move: MoveData = null
var combo_count: int = 0

# Signals
signal health_changed(new_hp: int, max_hp: int)
signal stamina_changed(new_stamina: float, max_stamina: float)
signal died()
signal move_started(move_name: String)
signal move_ended(move_name: String)
signal hit_connected(damage: int)
signal was_hit(damage: int)

# Core methods
func _ready() -> void

func tick() -> void:
    # Called by MatchManager.tick()
    # Frame-based update (no delta needed)
    state_machine.tick()
    resource_manager.tick()
    move_system.tick()
    combat_system.tick()
    status_manager.tick()
    passive_ability.tick()
    
    # Physics movement (uses Godot's internal delta)
    move_and_slide()

func initialize(char_data: CharacterData, p_id: int) -> void
func handle_input(input: InputData) -> void
func apply_damage(damage: int, is_chip: bool = false) -> void
func heal(amount: int) -> void
func flip() -> void
func get_opponent() -> Fighter
func is_in_hitstun() -> bool
func is_blocking() -> bool
func can_act() -> bool
```

**Design Notes:**
- Composition over inheritance (components as child nodes)
- Signals for loose coupling with UI and other systems
- All frame-dependent logic in `_physics_process()`

---

### 3.2. StateMachine

```gdscript
class_name StateMachine
extends Node

var current_state: State = null
var states: Dictionary = {}  # state_name: State
var fighter: Fighter

signal state_changed(from_state: String, to_state: String)

func _ready() -> void
func tick() -> void:
    if current_state:
        current_state.tick()
        var next_state = current_state.check_transitions()
        if next_state != "":
            change_state(next_state)

func add_state(state_name: String, state: State) -> void
func change_state(new_state_name: String) -> void
func get_current_state_name() -> String
```

#### State (Base Class)

```gdscript
class_name State
extends Node

var fighter: Fighter
var state_machine: StateMachine

# Virtual methods (override in child states)
func enter() -> void
func exit() -> void
func tick() -> void  # Called every frame (replaces update/physics_update)
func handle_input(input: InputData) -> void
func check_transitions() -> String  # Returns next state name or ""
```

#### Concrete State Classes

```gdscript
# IdleState
class_name IdleState extends State
# - Stamina regeneration
# - Check for input to transition
# - Default state

# WalkState
class_name WalkState extends State
# - Move fighter horizontally
# - Can transition to attacks, jumps, dash

# JumpState
class_name JumpState extends State
# - Apply vertical velocity
# - Track air jumps
# - Check for landing

# DashState
class_name DashState extends State
# - Fast horizontal movement
# - Stamina consumption
# - Can cancel into attacks

# HeavyDashState
class_name HeavyDashState extends State
# - Pass through opponent
# - I-frames
# - Higher stamina cost

# AttackState
class_name AttackState extends State
# - Executes current move with three lockout phases:
#   1. STARTUP: Complete lockout, no hitbox active
#   2. ACTIVE: Lockout continues, hitbox spawns
#   3. RECOVERY: Lockout unless in cancel window
# - Tracks elapsed frames vs move's frame data
# - Spawns/despawns hitboxes at precise frames
# - Cancel system:
#   - can_cancel flag set during cancel window
#   - Only specific moves can be cancelled into
#   - Cancel conditions: on_hit, on_block, on_whiff
# - Movement locked unless move has momentum property

# BlockState
class_name BlockState extends State
# - Disables stamina regeneration
# - Takes chip damage on hit (10% of attack damage)
# - Consumes stamina per blocked hit (15 stamina)
# - Can hold block indefinitely if not hit
# - Transitions to BlockStunState when hit (lockout)
# - Transitions to Stunned if stamina reaches 0

# HitStunState
class_name HitStunState extends State
# - Complete action lockout (cannot act)
# - Frame-precise duration based on attack's hitstun value
# - Applies knockback velocity on enter
# - Auto-transitions to Idle when frames expire
# - Input is ignored but still buffered
# - Gravity still applies during hitstun

# StunnedState (Stamina depleted)
class_name StunnedState extends State
# - Complete action lockout (100% vulnerable)
# - Fixed duration: 120 frames (2 seconds at 60 FPS)
# - Cannot act, block, or move
# - Takes full damage from all attacks
# - Visual indicator (dazed animation)
# - Auto-transitions to Idle after duration
# - Stamina slowly regenerates during stun

# GrabbedState
class_name GrabbedState extends State
# - Being grabbed
# - Take damage
# - Cannot act

# EvadeState
class_name EvadeState extends State
# - Quick movement
# - I-frames
# - Short duration
```

---

### 3.3. ResourceManager

```gdscript
class_name ResourceManager
extends Node

var fighter: Fighter

# HP System
var current_hp: int
var max_hp: int = 1000

# Stamina System
var current_stamina: float
var max_stamina: float = 100.0
var stamina_regen_rate: float = 30.0  # per second
var stamina_regen_enabled: bool = true
var stamina_regen_timer: float = 0.0
var stamina_regen_delay: float = 0.5  # delay after action

# Character Meter (custom per character)
var character_meter: CharacterMeter

# Signals
signal hp_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal meter_changed(value: float)
signal hp_depleted()
signal stamina_depleted()

# HP Methods
func initialize_hp(max_value: int) -> void
func take_damage(damage: int, is_chip: bool = false) -> void
func heal(amount: int) -> void
func is_dead() -> bool

# Stamina Methods
func initialize_stamina(max_value: float, regen_rate: float) -> void
func consume_stamina(amount: float) -> bool
func regenerate_stamina(delta: float) -> void
func interrupt_regen() -> void
func is_stamina_depleted() -> bool
func get_stamina_percentage() -> float

# Meter Methods
func initialize_meter(meter_type: CharacterMeter) -> void
func add_meter(amount: float) -> void
func spend_meter(amount: float) -> bool
func get_meter_value() -> float
```

#### CharacterMeter (Base Class)

```gdscript
class_name CharacterMeter
extends Resource

export var meter_name: String
export var max_value: float = 100.0
var current_value: float = 0.0

# Virtual methods
func gain_on_hit(damage_dealt: float) -> void
func gain_on_damage_taken(damage_taken: float) -> void
func spend(amount: float) -> bool
func reset() -> void
```

**Derived Meter Types:**
```gdscript
# ChargeMeter (fills over time)
class_name ChargeMeter extends CharacterMeter
var charge_rate: float

# DamageMeter (fills on dealing/taking damage)
class_name DamageMeter extends CharacterMeter
var gain_on_hit_multiplier: float
var gain_on_hurt_multiplier: float

# StackMeter (discrete stacks)
class_name StackMeter extends CharacterMeter
var max_stacks: int
func add_stack() -> void
func remove_stack() -> void
func get_stack_count() -> int
```

---

### 3.4. MoveSystem

```gdscript
class_name MoveSystem
extends Node

var fighter: Fighter
var move_list: Dictionary = {}  # move_name: MoveData

# Current move tracking
var current_move: MoveData = null
var current_frame: int = 0
var move_active: bool = false

# Cancel tracking
var cancellable: bool = false
var cancel_window_start: int = 0
var cancel_window_end: int = 0

func _ready() -> void
func load_moves(character_data: CharacterData) -> void
func execute_move(move_name: String) -> bool
func update_move(delta: float) -> void
func can_execute_move(move_name: String) -> bool
func cancel_into(move_name: String) -> bool
func end_move() -> void
func get_move_by_input(input: InputData) -> String
```

#### MoveData (Resource)

```gdscript
class_name MoveData
extends Resource

# Identification
@export var move_name: String
@export var move_id: String
@export var move_type: MoveType  # NORMAL, SPECIAL, ULTIMATE

# Animation
@export var animation_name: String
@export var startup_frames: int = 5
@export var active_frames: int = 3
@export var recovery_frames: int = 10

# Properties
@export var damage: int = 50
@export var stamina_cost: float = 5.0
@export var meter_cost: float = 0.0
@export var chip_damage_multiplier: float = 0.1

# Hitbox data
@export var hitbox_data: Array[HitboxData] = []

# Hitstun & Knockback
@export var hitstun_frames: int = 15
@export var blockstun_frames: int = 8
@export var knockback_force: Vector2 = Vector2.ZERO

# Cancel properties
@export var cancellable_on_hit: bool = false
@export var cancellable_on_block: bool = false
@export var cancel_window: Vector2i = Vector2i(0, 0)  # start, end frame
@export var cancellable_into: Array[String] = []

# Status effects
@export var on_hit_status: StatusEffect = null
@export var on_block_status: StatusEffect = null

# Combo properties
@export var damage_scaling: float = 0.9
@export var launches: bool = false
@export var ground_bounce: bool = false
@export var wall_bounce: bool = false

# Input requirements
@export var input_command: InputCommand

func get_total_frames() -> int:
    return startup_frames + active_frames + recovery_frames

func is_frame_active(frame: int) -> bool:
    return frame >= startup_frames and frame < startup_frames + active_frames
```

#### InputCommand (Resource)

```gdscript
class_name InputCommand
extends Resource

@export var directional: Vector2 = Vector2.ZERO  # Required direction
@export var buttons: Array[String] = []          # Required buttons
@export var requires_neutral: bool = false
@export var air_only: bool = false
@export var ground_only: bool = false

func matches(input: InputData, fighter: Fighter) -> bool
```

---

### 3.5. CombatSystem

```gdscript
class_name CombatSystem
extends Node

var fighter: Fighter

# Hitbox/Hurtbox managers
@onready var hitbox_manager: HitboxManager = $HitboxManager
@onready var hurtbox_manager: HurtboxManager = $HurtboxManager

# Combo tracking
var combo_tracker: ComboTracker

# Hit detection
var active_hitboxes: Array[Hitbox] = []

func _ready() -> void
func spawn_hitbox(hitbox_data: HitboxData, frame: int) -> void
func despawn_hitbox(hitbox: Hitbox) -> void
func on_hit_connected(hitbox: Hitbox, hurtbox: Hurtbox) -> void
func apply_hit(hit_data: HitData) -> void
func take_hit(hit_data: HitData) -> void
```

#### HitboxManager

```gdscript
class_name HitboxManager
extends Node2D

var fighter: Fighter
var hitbox_pool: Array[Hitbox] = []  # Object pooling

func spawn_hitbox(data: HitboxData) -> Hitbox
func return_hitbox(hitbox: Hitbox) -> void
```

#### Hitbox (Area2D)

```gdscript
class_name Hitbox
extends Area2D

var hitbox_data: HitboxData
var owner_fighter: Fighter
var active: bool = false
var hit_enemies: Array[Fighter] = []  # Prevent multi-hit in same attack

signal hit_connected(target: Fighter)

func _ready() -> void
func activate(data: HitboxData, owner: Fighter) -> void
func deactivate() -> void
func _on_area_entered(area: Area2D) -> void
```

#### HitboxData (Resource)

```gdscript
class_name HitboxData
extends Resource

@export var shape: Shape2D
@export var position: Vector2
@export var size: Vector2
@export var active_start_frame: int
@export var active_end_frame: int
@export var damage: int
@export var hitstun_frames: int
@export var blockstun_frames: int
@export var knockback: Vector2
@export var hit_effect: PackedScene  # VFX
@export var sound_effect: AudioStream
```

#### HurtboxManager

```gdscript
class_name HurtboxManager
extends Node2D

var fighter: Fighter
@onready var main_hurtbox: Hurtbox = $MainHurtbox

func set_invulnerable(duration: float) -> void
func disable() -> void
func enable() -> void
```

#### Hurtbox (Area2D)

```gdscript
class_name Hurtbox
extends Area2D

var owner_fighter: Fighter
var invulnerable: bool = false

func set_invulnerable(value: bool) -> void
```

#### ComboTracker

```gdscript
class_name ComboTracker
extends Node

var combo_count: int = 0
var total_damage: int = 0
var scaling_factor: float = 0.9
var combo_active: bool = false
var combo_timer: float = 0.0
var combo_timeout: float = 1.0  # Reset after 1 second

signal combo_started()
signal combo_continued(hit_count: int)
signal combo_ended(hit_count: int, total_damage: int)

func add_hit(damage: int) -> void
func reset_combo() -> void
func get_current_scaling() -> float
func update(delta: float) -> void
```

---

### 3.6. StatusManager

```gdscript
class_name StatusManager
extends Node

var fighter: Fighter
var active_effects: Array[StatusEffectInstance] = []

func apply_status(effect: StatusEffect) -> void
func remove_status(effect_name: String) -> void
func update_effects(delta: float) -> void
func has_status(effect_name: String) -> bool
func get_status_stack_count(effect_name: String) -> int
func clear_all() -> void
```

#### StatusEffect (Resource)

```gdscript
class_name StatusEffect
extends Resource

@export var effect_name: String
@export var effect_type: EffectType  # BUFF, DEBUFF
@export var duration: float = -1.0  # -1 = permanent
@export var max_stacks: int = 1
@export var stackable: bool = false
@export var tick_interval: float = 0.0  # 0 = no ticking
@export var icon: Texture2D

# Effect modifiers
@export var stat_modifiers: Dictionary = {}  # stat_name: value
@export var damage_per_tick: int = 0

# Virtual methods (override with scripts)
func on_apply(fighter: Fighter) -> void
func on_tick(fighter: Fighter) -> void
func on_remove(fighter: Fighter) -> void
func on_stack_added(fighter: Fighter, stack_count: int) -> void
```

#### StatusEffectInstance

```gdscript
class_name StatusEffectInstance

var effect: StatusEffect
var remaining_duration: float
var stack_count: int = 1
var tick_timer: float = 0.0

func update(delta: float, fighter: Fighter) -> bool  # Returns true if expired
```

---

### 3.7. PassiveAbility

```gdscript
class_name PassiveAbility
extends Node

var fighter: Fighter
var passive_data: PassiveData

# Virtual methods (override per character)
func _ready() -> void
func initialize(data: PassiveData) -> void
func activate() -> void
func deactivate() -> void
func check_activation_condition() -> bool
func on_deal_damage(damage: int) -> void
func on_take_damage(damage: int) -> void
func on_move_used(move: MoveData) -> void
func modify_move_property(move: MoveData, property: String, value: Variant) -> Variant
```

#### PassiveData (Resource)

```gdscript
class_name PassiveData
extends Resource

@export var passive_name: String
@export var description: String
@export var icon: Texture2D
@export var passive_script: Script  # Custom PassiveAbility script
```

---

## 4. MATCH & STAGE CLASSES

### 4.1. MatchManager

```gdscript
class_name MatchManager
extends Node

enum MatchState {
    PRE_MATCH,
    FIGHTING,
    ROUND_END,
    MATCH_END
}

var current_state: MatchState = MatchState.PRE_MATCH
var p1_fighter: Fighter
var p2_fighter: Fighter
var stage: Stage
var timer: float = 99.0
var rounds_to_win: int = 2
var p1_rounds_won: int = 0
var p2_rounds_won: int = 0

signal round_started()
signal round_ended(winner_id: int)
signal match_ended(winner_id: int)
signal timer_updated(time: float)

func _ready() -> void
func tick() -> void:
    # Cascade tick to both fighters
    if p1_fighter:
        p1_fighter.tick()
    if p2_fighter:
        p2_fighter.tick()
    
    # Update match timer
    update_timer()
    check_win_conditions()

func initialize_match() -> void
func start_round() -> void
func end_round(winner_id: int) -> void
func check_win_conditions() -> void
func update_timer(delta: float) -> void
```

---

### 4.2. Stage

```gdscript
class_name Stage
extends Node2D

@onready var ground: StaticBody2D = $Ground
@onready var left_boundary: Area2D = $LeftBoundary
@onready var right_boundary: Area2D = $RightBoundary
@onready var camera: Camera2D = $Camera2D

var stage_data: StageData
var p1_spawn_position: Vector2
var p2_spawn_position: Vector2

func _ready() -> void
func initialize(data: StageData) -> void
func update_camera(p1_pos: Vector2, p2_pos: Vector2) -> void
```

#### StageData (Resource)

```gdscript
class_name StageData
extends Resource

@export var stage_name: String
@export var scene_path: String
@export var ground_level: float
@export var left_bound: float
@export var right_bound: float
@export var p1_spawn: Vector2
@export var p2_spawn: Vector2
@export var background_music: AudioStream
```

---

## 5. UI CLASSES

### 5.1. HUD

```gdscript
class_name HUD
extends CanvasLayer

@onready var p1_hp_bar: HPBar = $P1/HPBar
@onready var p2_hp_bar: HPBar = $P2/HPBar
@onready var p1_stamina_bar: StaminaBar = $P1/StaminaBar
@onready var p2_stamina_bar: StaminaBar = $P2/StaminaBar
@onready var p1_meter: CharacterMeterUI = $P1/MeterBar
@onready var p2_meter: CharacterMeterUI = $P2/MeterBar
@onready var timer_label: Label = $Timer
@onready var combo_display: ComboDisplay = $ComboDisplay

func _ready() -> void
func connect_fighters(p1: Fighter, p2: Fighter) -> void
func update_hp(player_id: int, current: int, maximum: int) -> void
func update_stamina(player_id: int, current: float, maximum: float) -> void
func update_timer(time: float) -> void
func show_combo(hit_count: int, damage: int) -> void
```

#### HPBar

```gdscript
class_name HPBar
extends ProgressBar

@export var damage_bar_delay: float = 0.3
var target_value: float
var damage_tween: Tween

func update_hp(current: int, maximum: int) -> void
func animate_damage() -> void
```

#### StaminaBar

```gdscript
class_name StaminaBar
extends ProgressBar

@export var regen_color: Color = Color.GREEN
@export var depleted_color: Color = Color.RED

func update_stamina(current: float, maximum: float) -> void
func flash_depleted() -> void
```

---

## 6. DATA RESOURCE CLASSES

### 6.1. CharacterData

```gdscript
class_name CharacterData
extends Resource

# Identity
@export var character_name: String
@export var character_id: String
@export var portrait: Texture2D
@export var character_scene: PackedScene

# Stats
@export var max_hp: int = 1000
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 30.0

# Physics
@export var walk_speed: float = 200.0
@export var dash_speed: float = 400.0
@export var heavy_dash_speed: float = 500.0
@export var jump_force: float = -400.0
@export var gravity: float = 980.0
@export var air_jumps: int = 1

# Combat
@export var move_list: Array[MoveData] = []
@export var passive_ability: PassiveData
@export var character_meter_type: CharacterMeter

func get_move(move_name: String) -> MoveData
func get_all_normals() -> Array[MoveData]
func get_all_specials() -> Array[MoveData]
func get_all_ultimates() -> Array[MoveData]
```

---

## 7. UTILITY CLASSES

### 7.1. FrameData

```gdscript
class_name FrameData

static func frames_to_seconds(frames: int) -> float:
    return frames / 60.0

static func seconds_to_frames(seconds: float) -> int:
    return int(seconds * 60.0)
```

---

### 7.2. HitData

```gdscript
class_name HitData

var attacker: Fighter
var defender: Fighter
var move_data: MoveData
var damage: int
var scaled_damage: int
var hitstun_frames: int
var blockstun_frames: int
var knockback: Vector2
var is_counter_hit: bool = false
var status_effect: StatusEffect = null

func apply_scaling(scaling_factor: float) -> void
```

---

## 8. ENUMS & CONSTANTS

```gdscript
# MoveType
enum MoveType {
    NORMAL,
    SPECIAL,
    ULTIMATE
}

# EffectType
enum EffectType {
    BUFF,
    DEBUFF
}

# HitType
enum HitType {
    NORMAL,
    COUNTER,
    PUNISH
}

# FighterState (matches state machine states)
enum FighterState {
    IDLE,
    WALK,
    JUMP,
    DASH,
    HEAVY_DASH,
    ATTACK,
    BLOCK,
    HITSTUN,
    BLOCKSTUN,
    STUNNED,
    GRABBED,
    EVADE,
    KNOCKDOWN
}
```

---

## 9. CLASS INTERACTION FLOW

### 9.1. Input → Action Flow

```
InputManager (polls keyboard)
    ↓
InputBuffer (stores input)
    ↓
Fighter.handle_input(input)
    ↓
StateMachine.current_state.handle_input(input)
    ↓
MoveSystem.get_move_by_input(input)
    ↓
MoveSystem.execute_move(move_name)
    ↓
AttackState (executes move)
    ↓
CombatSystem.spawn_hitbox()
```

### 9.2. Hit Detection Flow

```
Hitbox (Area2D enters Hurtbox)
    ↓
Hitbox.hit_connected signal
    ↓
CombatSystem.on_hit_connected()
    ↓
HitData created (with scaling)
    ↓
Opponent.CombatSystem.take_hit(HitData)
    ↓
ResourceManager.take_damage()
    ↓
StateMachine.change_state("HitStun")
    ↓
ComboTracker.add_hit()
```

### 9.3. Resource Update Flow

```
ResourceManager.consume_stamina()
    ↓
ResourceManager.stamina_changed signal
    ↓
HUD.update_stamina()
    ↓
StaminaBar (updates visual)
```

---

## 10. DESIGN PRINCIPLES

### 10.1. Composition over Inheritance
- Fighter uses component nodes rather than deep class hierarchies
- Each system is independent and modular

### 10.2. Signal-Based Communication
- Loose coupling between systems
- UI reacts to fighter signals
- Easy to extend and debug

### 10.3. Resource-Based Data
- All game data in `.tres` files
- Easy balancing without code changes
- Shareable between characters where appropriate

### 10.4. State Pattern for Fighter Logic
- Clean separation of behavior
- Easy to add new states
- Clear transition logic

### 10.5. Object Pooling for Performance
- Hitboxes pooled and reused
- VFX particles pooled
- Prevents GC spikes during gameplay

---

## SUMMARY

This class structure provides:
- **Clear separation of concerns**
- **Modularity** for independent development
- **Extensibility** for new characters and features
- **Performance** through pooling and efficient updates
- **Maintainability** through resource-based data and composition

All classes follow Godot best practices and GDScript conventions.
