v# Project Architecture Document
## Crossing Realities Versus

**Engine:** Godot 4.5  
**Language:** GDScript  
**Date:** January 3, 2026  

---

## 1. ARCHITECTURE OVERVIEW

### 1.1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Game Manager                          │
│  (Scene Management, Match Flow, Game State)             │
└─────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
┌───────▼────────┐ ┌────▼─────┐ ┌───────▼────────┐
│  Input System  │ │  Match   │ │   UI System    │
│   (P1 & P2)    │ │  Manager │ │                │
└────────┬───────┘ └────┬─────┘ └───────┬────────┘
         │              │                │
         │       ┌──────▼──────┐        │
         │       │   Stage     │        │
         │       └──────┬──────┘        │
         │              │                │
    ┌────▼──────────────▼───────────┐   │
    │      Fighter System            │   │
    │  ┌──────────────────────────┐ │   │
    │  │  Fighter (CharacterBody2D)│ │   │
    │  │  ┌────────────────────┐  │ │   │
    │  │  │ State Machine      │  │ │   │
    │  │  └────────────────────┘  │ │   │
    │  │  ┌────────────────────┐  │ │   │
    │  │  │ Resource Manager   │  │ │   │
    │  │  │  (HP, Stamina, etc)│  │ │   │
    │  │  └────────────────────┘  │ │   │
    │  │  ┌────────────────────┐  │ │   │
    │  │  │ Move System        │  │ │   │
    │  │  └────────────────────┘  │ │   │
    │  │  ┌────────────────────┐  │ │   │
    │  │  │ Combat System      │  │ │   │
    │  │  │ (Hitbox, Hurtbox)  │  │ │   │
    │  │  └────────────────────┘  │ │   │
    │  └──────────────────────────┘ │   │
    └────────────────────────────────┘   │
                                         │
         ┌───────────────────────────────┘
         │
    ┌────▼──────────┐
    │  HUD System   │
    │  (HP, Stamina,│
    │   Timer, etc) │
    └───────────────┘
```

---

## 2. CORE MODULES

### 2.1. Game Manager (Singleton/Autoload)
**Responsibility:** Global game state, scene management, configuration

**Key Features:**
- Match settings (rounds, time limit, character selection)
- Scene transitions
- Global pause/resume
- Player configuration storage
- FPS management (locked at 60)

**Implementation:**
- Autoload singleton pattern
- Persistent across scenes

---

### 2.2. Input System
**Responsibility:** Raw input polling and key mapping

**Key Components:**
- **InputManager (Autoload):** Polls raw keyboard inputs for P1/P2
- **InputBuffer (Per-Fighter):** Stores input history for command detection
- **CommandDetector (Per-Fighter):** Recognizes complex input sequences (dashes, grabs, ultimates)

**Features:**
- Per-player input isolation (P1/P2)
- Match-scoped input buffering (only during gameplay)
- Modifier detection (same-frame or windowed)
- Motion input-free design

**Architecture Note:**
- InputManager is lightweight and stateless (only polls)
- InputBuffers are created per-Fighter during match start
- Buffers destroyed when match ends (no memory waste)
- No buffering during menus/character select

---

### 2.3. Match Manager
**Responsibility:** Match flow, round management, win conditions

**Features:**
- Round counter
- Timer system
- Victory condition checking
- Round transition handling
- Match reset

**States:**
- `PRE_MATCH` - Character intro/positioning
- `FIGHTING` - Active combat
- `ROUND_END` - End of round sequence
- `MATCH_END` - Match complete

---

### 2.4. Stage System
**Responsibility:** Battle environment, boundaries, camera management

**Features:**
- Stage boundaries (soft and hard limits)
- Camera follow system (both fighters)
- Ground collision
- Visual effects/background

**Technical:**
- Static collision for ground
- Area2D for boundaries
- Camera2D with smoothing

---

## 3. FIGHTER SYSTEM ARCHITECTURE

### 3.1. Fighter Node Structure

```
Fighter (CharacterBody2D)
├── CollisionShape2D (body)
├── AnimationPlayer
├── AnimationTree
├── Sprite2D (or multiple for parts)
├── StateMachine (Node)
│   ├── IdleState
│   ├── WalkState
│   ├── JumpState
│   ├── DashState
│   ├── AttackState
│   ├── BlockState
│   ├── HitStunState
│   ├── StunnedState (stamina depleted)
│   └── KnockdownState
├── ResourceManager (Node)
│   ├── HP
│   ├── Stamina
│   └── CharacterMeter (custom per character)
├── MoveSystem (Node)
│   ├── NormalMoves
│   ├── SpecialMoves
│   └── Ultimates
├── CombatSystem (Node)
│   ├── HitboxManager
│   ├── HurtboxManager
│   └── ComboTracker
├── StatusManager (Node)
│   └── ActiveStatusEffects[]
└── PassiveAbility (Node)
```

---

### 3.2. State Machine Pattern

**Base State Class:**
```gdscript
class_base State
  - enter()
  - exit()
  - update(delta)
  - physics_update(delta)
  - handle_input(event)
```

**Transition Logic:**
- States check conditions and request transitions
- State machine validates transitions
- Clean exit/enter sequences

**Priority:**
1. Hitstun/Blockstun (forced)
2. Special states (stunned, grabbed)
3. Attack commitment
4. Movement
5. Idle

---

### 3.3. Resource Management System

**HP System:**
- Current HP / Max HP
- Damage application
- Death check
- Chip damage on block

**Stamina System:**
- Current Stamina / Max Stamina (default 100)
- Regeneration rate (configurable)
- Consumption on actions
- Regeneration interruption
- Block stamina drain
- Stun on depletion (0 stamina)

**Character Meter:**
- Custom per character
- Can be charge-based, stack-based, or gauge-based
- Used for enhanced specials/supers

---

### 3.4. Move System Design

**Move Data Structure:**
```
MoveData (Resource)
  - move_name: String
  - move_type: NORMAL/SPECIAL/ULTIMATE
  - startup_frames: int
  - active_frames: int
  - recovery_frames: int
  - damage: int
  - stamina_cost: int
  - hitbox_data: Array[HitboxData]
  - animation_name: String
  - cancellable_into: Array[String]
  - on_hit_effect: StatusEffect
  - scaling_factor: float
```

**Move Categories:**
1. **Normals** (8 per character)
   - Light attacks (5)
   - Heavy attacks (3)
   
2. **Specials** (12 per character)
   - 3 skills × 2 variants (normal/enhanced) × 2 modifiers (neutral/down)
   
3. **Ultimates** (4 per character)
   - S1+S2, S2+S3, S1+S3 (Supers)
   - S1+S2+S3 (Ultimate)

**Total: 28 moves per character (hard limit)**

---

## 4. COMBAT SYSTEM ARCHITECTURE

### 4.1. Hitbox/Hurtbox System

**Hitbox (Area2D):**
- Offensive collision area
- Active only during attack frames
- Contains attack properties (damage, hitstun, knockback)
- Can have multiple per move

**Hurtbox (Area2D):**
- Vulnerable area on character
- Always active (except during i-frames)
- Receives hit data

**Collision Layers:**
- Layer 1: P1 Hitbox
- Layer 2: P2 Hitbox
- Layer 3: P1 Hurtbox
- Layer 4: P2 Hurtbox

**Detection:**
- Hitbox signals overlap with opponent hurtbox
- Combat system validates hit
- Applies damage and hitstun

---

### 4.2. Combo System

**Combo Tracker:**
- Tracks consecutive hits
- Maintains combo counter
- Manages scaling
- Resets on:
  - Ground/air recovery
  - Combo drop
  - Neutral reset

**Damage Scaling:**
```
scaled_damage = base_damage * scaling_factor^(hit_count - 1)
where scaling_factor = 0.9 (configurable)
```

**Hitstun Scaling:**
- Longer combos = less hitstun per hit
- Prevents infinite combos

---

### 4.3. Block System

**Block Mechanics:**
- Activated by holding Down
- Blocks all attacks (no high/low)
- Consumes stamina on hit
- Takes chip damage
- No stamina regeneration while blocking
- At 0 stamina: Block breaks, enters stunned state

**Grab Counter:**
- Forward+Down+Dash grabs blocking opponent
- Free (0 stamina cost)
- Beats block and idle
- Loses to attacks

---

### 4.4. Dash System Implementation

**Standard Dash:**
- Fast horizontal movement
- 10 stamina cost
- Can cancel into attacks
- Cannot pass through opponent body

**Heavy Dash:**
- Down+Dash
- 30 stamina cost
- Passes through opponent and projectiles
- Extended i-frames
- Longer recovery

**Evade:**
- Back+Down+Dash
- 0 stamina cost
- Short i-frame window
- Quick recovery
- Position shift

**Grab:**
- Forward+Down+Dash
- 0 stamina cost
- Command grab
- Beats block

---

## 5. STATUS & PASSIVE SYSTEM

### 5.1. Status Effect Framework

**StatusEffect (Resource):**
```
StatusEffect
  - effect_name: String
  - effect_type: BUFF/DEBUFF
  - duration: float (seconds, -1 for permanent)
  - stack_count: int
  - max_stacks: int
  - tick_interval: float
  - on_apply_effect: Callable
  - on_tick_effect: Callable
  - on_remove_effect: Callable
```

**Examples:**
- Burn: Damage over time
- Armor: Damage reduction stacks
- Slow: Movement speed reduction
- Regen: HP recovery over time

---

### 5.2. Passive Ability System

**Passive (Node):**
- One per character
- Defines character archetype
- Modifies core gameplay rules
- Has activation conditions

**Example Design:**
```
PassiveAbility
  - passive_name: String
  - description: String
  - activate_condition(): bool
  - on_activate()
  - on_deactivate()
  - modify_stats(stat_name, value)
```

**Passive Categories:**
- Resource manipulation (stamina/HP/meter)
- Move property changes (frame data, damage)
- New mechanics (counters, parries)
- Conditional buffs

---

## 6. UI SYSTEM

### 6.1. HUD Architecture

**Components:**
- **HPBar** (Player 1 & 2)
  - Current/Max HP display
  - Color-coded danger states
  
- **StaminaBar** (Player 1 & 2)
  - Current/Max stamina
  - Regeneration visual
  - Depletion warning
  
- **CharacterMeter** (Player 1 & 2)
  - Custom per character
  
- **Timer**
  - Countdown display
  - Warning at low time
  
- **ComboCounter**
  - Hit counter
  - Damage counter

---

### 6.2. Menu System

**Main Menu:**
- Local Versus
- Training Mode
- Options
- Exit

**Character Select:**
- Grid layout
- Preview
- Confirmation

---

## 7. DATA MANAGEMENT

### 7.1. Character Data

**CharacterData (Resource):**
```
CharacterData
  - character_name: String
  - max_hp: int = 1000
  - max_stamina: int = 100
  - stamina_regen_rate: float
  - walk_speed: float
  - dash_speed: float
  - jump_force: float
  - air_jumps: int = 1
  - move_list: Array[MoveData]
  - passive_ability: PassiveData
  - character_meter_type: MeterType
```

All characters are defined as `.tres` resources.

---

### 7.2. Move Data Repository

**Organized by character:**
```
res://data/characters/
  character_a/
    character_a_data.tres
    normals/
      neutral_light.tres
      forward_light.tres
      ...
    specials/
      skill1_neutral.tres
      skill1_enhanced.tres
      ...
    ultimates/
      super1.tres
      ...
```

---

## 8. PERFORMANCE CONSIDERATIONS

### 8.1. Physics & Timing

- **Fixed FPS:** 60 FPS (`max_fps = 60`)
- **Single Tick Source:** GameManager is the ONLY system that calls `_physics_process()`
- **Cascading Tick:** GameManager.tick() → MatchManager.tick() → Fighter.tick() → Subsystems
- **Frame Data:** Measured in frames (1 frame = 1/60s = 1 tick)
- **Frame Counter:** Global frame counter in GameManager increments each tick

```gdscript
# GameManager (Autoload) - SINGLE SOURCE OF TICK
var current_frame: int = 0
var current_match: MatchManager = null

func _physics_process(delta: float) -> void:
    current_frame += 1
    tick()

func tick() -> void:
    # Cascade tick to active match
    if current_match:
        current_match.tick()
    
    # Update global systems
    InputManager.tick()
```

---

### 8.2. Optimization Strategies

- **Object Pooling:** Hitboxes, VFX particles
- **Visibility Culling:** Off-screen effects
- **Animation Caching:** Pre-load all character animations
- **State Machine Optimization:** Minimize state transitions
- **Input Buffering:** Limited to 5 frames max

---

## 9. DESIGN PATTERNS USED

### 9.1. Core Patterns

1. **Singleton/Autoload:** GameManager, InputSystem
2. **State Pattern:** Fighter state machine
3. **Observer Pattern:** Damage events, resource changes
4. **Strategy Pattern:** Passive abilities, character meters
5. **Factory Pattern:** Move instantiation
6. **Resource Pattern:** Character data, move data
7. **Component Pattern:** Fighter node composition

---

## 10. SCALABILITY & EXTENSIBILITY

### 10.1. Adding New Characters

1. Create CharacterData resource
2. Define 28 moves (8 normals, 12 specials, 4 ultimates, 4 universal)
3. Implement PassiveAbility script
4. Create animations
5. Set up hitbox data
6. Balance testing

**Time estimate:** 2-4 weeks per character

---

### 10.2. Future Extensions

**Possible additions:**
- Online multiplayer (rollback netcode)
- Training mode features (frame data, hitbox display)
- Replay system
- Tutorial system
- Story mode
- Additional game modes

**Architecture supports:**
- Modular design allows adding systems without breaking existing code
- Resource-based data for easy balancing
- State machine extensibility for new character states

---

## 11. DEVELOPMENT PHASES

### Phase 1: Foundation (Weeks 1-4)
- Input system
- Basic fighter movement
- State machine
- Resource system (HP, Stamina)

### Phase 2: Combat Core (Weeks 5-8)
- Hitbox/Hurtbox system
- Basic normals
- Block system
- Damage application

### Phase 3: Advanced Systems (Weeks 9-12)
- Dash system (all variants)
- Special moves
- Combo system & scaling
- Status effects

### Phase 4: Character Implementation (Weeks 13-16)
- First playable character (full moveset)
- Passive ability
- Character meter
- Ultimates

### Phase 5: Second Character & Polish (Weeks 17-20)
- Second character
- Balance pass
- UI/HUD implementation
- Match flow

### Phase 6: Testing & Refinement (Weeks 21-24)
- Playtesting
- Bug fixes
- Balance adjustments
- Performance optimization

---

## 12. TECHNICAL CONSTRAINTS

### 12.1. Hard Limits

- **28 moves per character** (design constraint)
- **60 FPS locked** (fighting game standard)
- **2 players only** (local PvP focus)
- **No rollback netcode in Phase 1** (scope limitation)

### 12.2. Engine Limitations

- Godot 4.5 physics engine
- GDScript performance (acceptable for 2D fighting game)
- Input latency (minimize with polling)

---

## CONCLUSION

This architecture prioritizes:
- **Modularity:** Each system can be developed/tested independently
- **Extensibility:** Easy to add characters, moves, systems
- **Clarity:** Clear separation of concerns
- **Performance:** Optimized for 60 FPS fighting game requirements
- **Maintainability:** Resource-based data, clean state management

The design follows fighting game conventions while implementing the unique "no crouch, block-as-resource" mechanics defined in the GDD.
