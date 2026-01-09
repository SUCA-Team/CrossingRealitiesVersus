# Implementation Status & Next Steps
## Crossing Realities Versus

**Date:** January 7, 2026  
**Current Phase:** Early Development - Core Structure

---

## 1. CURRENT IMPLEMENTATION SUMMARY

### ✅ Implemented Files

| File | Type | Status | Notes |
|------|------|--------|-------|
| `character.gd` | Node2D | Minimal | Basic structure only |
| `character.tscn` | Scene | Basic | Has CharacterBody2D + Sprite |
| `character_data.gd` | Resource | Complete | Matches docs |
| `move_data.gd` | Resource | Complete | Matches docs |
| `player_context.gd` | RefCounted | Complete | Good structure |
| `player_controller.gd` | RefCounted | Minimal | Needs input polling |
| `command_buffer.gd` | RefCounted | Empty | Placeholder only |
| `combat_context.gd` | Node | Empty | Placeholder only |
| `status_manager.gd` | Node | Empty | Placeholder only |
| `match.gd` | Node | Working | Frame tick system works |
| `match.tscn` | Scene | Minimal | Just Match node |
| `game_manager.gd` | Autoload | Empty | Placeholder only |
| `input_mapper.gd` | Resource | Complete | Good design |
| `p1/p2_input_mapper.tres` | Resource | Complete | Key bindings done |

---

## 2. ARCHITECTURE ANALYSIS

### Current Structure (Your Implementation)

```
Match (Node) - Frame-based tick
├── PlayerContext (RefCounted) - P1
│   ├── PlayerController (RefCounted) - Input handling
│   ├── CommandBuffer (RefCounted) - Input buffering
│   ├── CombatContext (Node) - Combat state
│   └── Character (Node2D) - Visual + Logic
│       └── CharacterBody2D - Physics
└── PlayerContext (RefCounted) - P2
    └── (same structure)
```

### Key Design Decisions

✅ **PlayerContext Pattern** - Excellent choice
- Encapsulates all player-specific state
- Clean dependency injection
- Easy to pass around

✅ **Resource-Based Input** - Good for flexibility
- InputMapper as Resource (not autoload)
- Easy to create custom schemes
- Can save/load

✅ **Frame-Based Tick** - Perfect for fighting games
- Match._physics_process() drives everything
- Deterministic frame counting
- Ready for rollback netcode

✅ **Separation of Concerns**
- Logic (RefCounted) vs Visual (Node2D)
- Data (Resource) vs Behavior (Script)

---

## 3. MISSING COMPONENTS (Priority Order)

### 🔴 Critical (Blocks Gameplay)

1. **InputData class** - Structure for input data
   - Priority: HIGHEST
   - Blocks: Everything input-related
   - File: `core/character/common/input_data.gd`

2. **StateMachine** - State management
   - Priority: HIGHEST
   - Blocks: All character behavior
   - File: `core/character/common/state_machine.gd`

3. **State base class + Basic States** - Idle, Walk, Attack
   - Priority: HIGHEST  
   - Blocks: Character actions
   - Files: `core/character/common/state.gd`, `states/*.gd`

4. **PlayerController input polling** - Actually read keyboard
   - Priority: HIGHEST
   - Blocks: Player control
   - File: `player_controller.gd` (implement tick())

5. **Character component initialization** - Create state machine, etc.
   - Priority: HIGHEST
   - Blocks: Character functionality
   - File: `character.gd` (expand _init and _ready)

### 🟡 High Priority (Core Combat)

6. **HitboxData Resource** - Define hitbox properties
7. **Hitbox class (Area2D)** - Spawnable hitbox
8. **Hurtbox class (Area2D)** - Damage reception
9. **HitboxManager** - Spawn/manage hitboxes
10. **HurtboxManager** - Manage hurtbox
11. **ResourceManager** - HP/Stamina tracking
12. **HitData class** - Hit result data
13. **HitStun/BlockStun States** - Lockout mechanics

### 🟢 Medium Priority (Polish)

14. **CommandBuffer implementation** - Input buffering logic
15. **CombatContext implementation** - Combo tracking
16. **CommandDetector** - Complex inputs (dash, grab)
17. **MoveSystem** - Move execution engine
18. **More States** - Dash, Jump, Block, etc.

### 🔵 Low Priority (Enhancement)

19. **StatusManager implementation** - Status effects
20. **PassiveAbility system** - Character mechanics
21. **ProjectileData/Projectile** - Projectile system
22. **AnimationPlayer integration** - Sync animations
23. **VFX/SFX system** - Effects
24. **UI/HUD** - Health bars, etc.

---

## 4. IMMEDIATE IMPLEMENTATION PLAN

### Week 1: Input & Basic Movement

#### Day 1-2: Input System
**Goal:** See character respond to keyboard

**Tasks:**
1. Create `InputData` class
   ```gdscript
   class_name InputData extends RefCounted
   var player_id: int
   var timestamp: int
   var directional: Vector2
   var buttons: Dictionary
   ```

2. Implement `PlayerController.tick()`
   ```gdscript
   func tick(ctx: PlayerContext):
       # Poll keyboard using keymap
       var horizontal = 0
       if Input.is_action_pressed(keymap.left): horizontal -= 1
       if Input.is_action_pressed(keymap.right): horizontal += 1
       # ... etc
       
       # Create InputData
       var input = InputData.new()
       input.directional = Vector2(horizontal, vertical)
       input.player_id = ctx.player_id
       input.timestamp = ctx.match_.frames_elapsed
       
       # Store in buffer
       ctx.cmd_buffer.add_input(input)
   ```

3. Implement `CommandBuffer`
   ```gdscript
   var buffer: Array[InputData] = []
   func add_input(input: InputData) -> void
   func get_last_input() -> InputData
   ```

4. **Test:** Print input to console each frame

#### Day 3-4: State Machine

**Tasks:**
1. Create `StateMachine` class
   ```gdscript
   class_name StateMachine extends RefCounted
   var current_state: State
   var states: Dictionary
   var character: Character
   
   func tick() -> void
   func change_state(name: String, params: Dictionary) -> void
   ```

2. Create `State` base class
   ```gdscript
   class_name State extends RefCounted
   var state_name: String
   var character: Character
   
   func enter(params: Dictionary) -> void
   func exit() -> void
   func tick() -> void
   func check_transitions() -> String
   func handle_input(input: InputData) -> void
   ```

3. Create `IdleState`
   ```gdscript
   class_name IdleState extends State
   func enter(params: Dictionary) -> void:
       character.velocity = Vector2.ZERO
   
   func check_transitions() -> String:
       var input = character.player_ctx.cmd_buffer.get_last_input()
       if input and not input.is_neutral():
           return "Walk"
       return ""
   ```

4. Update `Character._init()` to create state machine
   ```gdscript
   func _init(char_data_: CharacterData, ctx: PlayerContext) -> void:
       char_data = char_data_
       player_ctx = ctx
       
       state_machine = StateMachine.new()
       state_machine.character = self
       
       var idle = IdleState.new()
       idle.state_name = "Idle"
       state_machine.add_state("Idle", idle)
       
       state_machine.change_state("Idle")
   ```

5. **Test:** Character enters Idle state on spawn

#### Day 5-7: Basic Movement

**Tasks:**
1. Create `WalkState`
   ```gdscript
   func tick() -> void:
       var input = character.player_ctx.cmd_buffer.get_last_input()
       if input:
           character.velocity.x = input.directional.x * character.char_data.walk_speed
   
   func check_transitions() -> String:
       var input = character.player_ctx.cmd_buffer.get_last_input()
       if input and input.is_neutral():
           return "Idle"
       return ""
   ```

2. Update `Character.tick()` to apply physics
   ```gdscript
   func tick():
       state_machine.tick()
       
       # Apply gravity
       if body and not body.is_on_floor():
           velocity.y += 980.0 / 60.0
       else:
           velocity.y = 0
       
       # Move
       if body:
           body.velocity = velocity
           body.move_and_slide()
   ```

3. Add `Character.handle_input()`
   ```gdscript
   func handle_input(input_data: InputData) -> void:
       if state_machine.current_state:
           state_machine.current_state.handle_input(input_data)
   ```

4. Call `handle_input()` from `PlayerController.tick()`
   ```gdscript
   func tick(ctx: PlayerContext):
       # ... poll input ...
       
       if ctx.character.can_act():
           ctx.character.handle_input(input)
   ```

5. **Test:** Move character left/right with WASD/Arrows

---

### Week 2: Basic Combat

#### Day 1-3: Hitbox System

**Tasks:**
1. Create `HitboxData` Resource
   ```gdscript
   class_name HitboxData extends Resource
   @export var size: Vector2 = Vector2(50, 50)
   @export var offset: Vector2 = Vector2(30, 0)
   @export var spawn_frame: int = 5
   @export var duration_frames: int = 3
   @export var damage: int = 50
   ```

2. Create `Hitbox` class (Area2D)
   ```gdscript
   class_name Hitbox extends Area2D
   var hitbox_data: HitboxData
   var owner_fighter: Character
   var frames_active: int = 0
   var is_active: bool = false
   
   func tick() -> void:
       if is_active:
           frames_active += 1
           check_overlaps()  # Manual overlap checking
   
   func check_overlaps() -> void:
       var overlapping = get_overlapping_areas()
       for area in overlapping:
           if area is Hurtbox:
               process_hit(area.owner_fighter)
   ```

3. Create `Hitbox.tscn`
   ```
   Hitbox (Area2D)
   └── CollisionShape2D (created dynamically)
   ```

4. Create `HitboxManager`
   ```gdscript
   class_name HitboxManager extends RefCounted
   var character: Character
   var active_hitboxes: Array[Hitbox] = []
   
   func spawn_hitbox(data: HitboxData) -> Hitbox
   func despawn_hitbox(hitbox: Hitbox) -> void
   func tick() -> void
   ```

5. **Test:** Spawn hitbox, see debug rect appear

#### Day 4-5: Hurtbox & Hit Detection

**Tasks:**
1. Create `Hurtbox` class (Area2D)
   ```gdscript
   class_name Hurtbox extends Area2D
   var owner_fighter: Character
   
   func setup_collision_layers() -> void:
       if owner_fighter.player_ctx.player_id == 1:
           collision_layer = 1 << 2  # P1 hurtbox
       else:
           collision_layer = 1 << 3  # P2 hurtbox
   ```

2. Add hurtbox to `Character.tscn`
   ```
   Character (Node2D)
   ├── CharacterBody (CharacterBody2D)
   ├── Sprite (Sprite2D)
   ├── StatusManager (Node)
   └── Hurtbox (Area2D)
       └── CollisionShape2D
   ```

3. Create `HitData` class
   ```gdscript
   class_name HitData extends RefCounted
   var attacker: Character
   var target: Character
   var damage: int
   var knockback: Vector2
   var hitstun_frames: int
   ```

4. Implement hit processing in `Hitbox.process_hit()`
   ```gdscript
   func process_hit(target: Character) -> void:
       var hit_data = HitData.new()
       hit_data.attacker = owner_fighter
       hit_data.target = target
       hit_data.damage = hitbox_data.damage
       
       # Apply hit
       target.take_hit(hit_data)
   ```

5. **Test:** Hitbox overlaps hurtbox, print "HIT!"

#### Day 6-7: Health & Hitstun

**Tasks:**
1. Create `ResourceManager`
   ```gdscript
   class_name ResourceManager extends RefCounted
   var character: Character
   var current_hp: int
   var max_hp: int
   var current_stamina: float
   var max_stamina: float
   
   func take_damage(amount: int, is_chip: bool) -> void
   func heal(amount: int) -> void
   func tick() -> void  # Stamina regen
   ```

2. Create `HitStunState`
   ```gdscript
   class_name HitStunState extends State
   var hitstun_frames_remaining: int = 0
   
   func enter(params: Dictionary) -> void:
       hitstun_frames_remaining = params.get("hitstun_frames", 15)
       character.velocity = params.get("knockback", Vector2.ZERO)
   
   func tick() -> void:
       hitstun_frames_remaining -= 1
   
   func check_transitions() -> String:
       if hitstun_frames_remaining <= 0:
           return "Idle"
       return ""
   
   func handle_input(input: InputData) -> void:
       pass  # Complete lockout
   ```

3. Implement `Character.take_hit()`
   ```gdscript
   func take_hit(hit_data: HitData) -> void:
       resource_manager.take_damage(hit_data.damage, false)
       state_machine.change_state("HitStun", {
           "hitstun_frames": hit_data.hitstun_frames,
           "knockback": hit_data.knockback
       })
   ```

4. Add HP display (simple print to console)
   ```gdscript
   func take_damage(amount: int, is_chip: bool) -> void:
       current_hp = max(0, current_hp - amount)
       print("P%d HP: %d/%d" % [character.player_ctx.player_id, current_hp, max_hp])
   ```

5. **Test:** Hit reduces HP, victim enters hitstun

---

## 5. CODE TEMPLATES

### InputData Template

```gdscript
# core/character/common/input_data.gd
class_name InputData extends RefCounted

var player_id: int
var timestamp: int
var directional: Vector2 = Vector2.ZERO
var buttons: Dictionary = {}

func is_neutral() -> bool:
    return directional == Vector2.ZERO

func is_forward(facing_right: bool) -> bool:
    return (directional.x > 0 and facing_right) or (directional.x < 0 and not facing_right)

func is_back(facing_right: bool) -> bool:
    return (directional.x < 0 and facing_right) or (directional.x > 0 and not facing_right)

func is_down() -> bool:
    return directional.y > 0

func is_up() -> bool:
    return directional.y < 0

func has_button(button: String) -> bool:
    return buttons.get(button, false)
```

### Complete PlayerController

```gdscript
# core/character/common/player_controller.gd
class_name PlayerController extends RefCounted

var keymap: InputMapper

func _init(index: int) -> void:
    match index:
        1:
            keymap = load("res://utils/input_mapper/p1_input_mapper.tres")
        2:
            keymap = load("res://utils/input_mapper/p2_input_mapper.tres")
        _:
            assert(false, "Invalid player index: %d" % index)

func tick(ctx: PlayerContext) -> void:
    # Poll directional input
    var horizontal = 0
    var vertical = 0
    
    if Input.is_action_pressed(keymap.left):
        horizontal -= 1
    if Input.is_action_pressed(keymap.right):
        horizontal += 1
    if Input.is_action_pressed(keymap.up):
        vertical -= 1
    if Input.is_action_pressed(keymap.down):
        vertical += 1
    
    # Create input data
    var input = InputData.new()
    input.player_id = ctx.player_id
    input.timestamp = ctx.match_.frames_elapsed
    input.directional = Vector2(horizontal, vertical)
    
    # Poll buttons
    input.buttons["light"] = Input.is_action_pressed(keymap.light)
    input.buttons["heavy"] = Input.is_action_pressed(keymap.heavy)
    input.buttons["dash"] = Input.is_action_pressed(keymap.dash)
    input.buttons["special1"] = Input.is_action_pressed(keymap.special1)
    input.buttons["special2"] = Input.is_action_pressed(keymap.special2)
    input.buttons["special3"] = Input.is_action_pressed(keymap.special3)
    
    # Add to buffer
    ctx.cmd_buffer.add_input(input)
    
    # Process input if character can act
    if ctx.character and ctx.character.can_act():
        ctx.character.handle_input(input)
```

### Complete CommandBuffer

```gdscript
# core/character/common/command_buffer.gd
class_name CommandBuffer extends RefCounted

var buffer: Array[InputData] = []
var max_size: int = 5

func add_input(input: InputData) -> void:
    buffer.push_back(input)
    if buffer.size() > max_size:
        buffer.pop_front()

func get_last_input() -> InputData:
    if buffer.is_empty():
        return null
    return buffer[buffer.size() - 1]

func get_last_n_inputs(n: int) -> Array[InputData]:
    var result: Array[InputData] = []
    var start_index = max(0, buffer.size() - n)
    for i in range(start_index, buffer.size()):
        result.append(buffer[i])
    return result

func has_button_press(button: String, within_frames: int = 5) -> bool:
    var recent = get_last_n_inputs(within_frames)
    for input in recent:
        if input.has_button(button):
            return true
    return false

func clear() -> void:
    buffer.clear()
```

---

## 6. TESTING CHECKPOINTS

### Checkpoint 1: Input Echo ✓
- [ ] Run game, press keys
- [ ] Console prints input each frame
- [ ] Both P1 and P2 work independently

### Checkpoint 2: State Transitions ✓
- [ ] Character starts in Idle
- [ ] Press movement key → Walk state
- [ ] Release key → Idle state
- [ ] Console prints state changes

### Checkpoint 3: Movement ✓
- [ ] WASD moves P1 left/right
- [ ] Arrows move P2 left/right
- [ ] Characters stay on ground
- [ ] Movement feels responsive

### Checkpoint 4: Attack Spawn ✓
- [ ] Press J (P1 light attack)
- [ ] Character enters Attack state
- [ ] Red debug rectangle appears
- [ ] Rectangle disappears after duration
- [ ] Character returns to Idle

### Checkpoint 5: Hit Detection ✓
- [ ] P1 attacks near P2
- [ ] Console prints "HIT!"
- [ ] P2 enters HitStun state
- [ ] P2 HP decreases
- [ ] P2 recovers after hitstun

---

## 7. ARCHITECTURE STRENGTHS & RECOMMENDATIONS

### ✅ What You Did Right

1. **PlayerContext Pattern** 
   - Excellent encapsulation
   - Easy dependency injection
   - Keeps related data together

2. **Resource-Based Configuration**
   - CharacterData, MoveData, InputMapper as Resources
   - Easy to create variations
   - Inspectable in editor

3. **Frame-Based Tick System**
   - Deterministic
   - Ready for netcode
   - No delta time issues

4. **Minimal Autoloads**
   - Only GameManager
   - Avoids global state bloat
   - Easier to reason about

### 💡 Suggestions

1. **Consider Moving Frame Counter to GameManager**
   - Pro: Single source of truth
   - Pro: Easier for replays/netcode
   - Con: Creates dependency on GameManager
   - **Recommendation:** Keep in Match for now, move later if needed

2. **Add can_act() Early**
   - Implement in Character class ASAP
   - Used everywhere for input gating
   - Prevents many bugs

3. **Start with Debug Rendering**
   - Draw hitboxes/hurtboxes as colored rects
   - Show state names above characters
   - Print frame advantage to console
   - Makes development much faster

4. **Use Composition for Components**
   - StateMachine, HitboxManager, etc. as RefCounted
   - Create in Character._init()
   - Lighter weight than Node-based components

5. **Test Incrementally**
   - Don't implement everything at once
   - Get each piece working before moving on
   - Write simple test scenes

---

## 8. COMMON PITFALLS TO AVOID

### ❌ Don't Do This:

1. **Using Area2D signals for hit detection**
   - Signals fire during physics step, not your tick()
   - Causes timing desynchronization
   - **Use manual overlap checking instead**

2. **Creating InputManager autoload**
   - You already have a better solution (InputMapper Resources)
   - Don't add unnecessary global state

3. **Making States extend Node**
   - Too heavy, unnecessary
   - States should be RefCounted
   - Only StateMachine needs to be Node (if at all)

4. **Forgetting to call tick()**
   - Every system needs tick() called from Match
   - Easy to forget new systems
   - **Maintain tick() call chain carefully**

5. **Using _process() or _physics_process() in components**
   - All frame logic should go through tick()
   - **Disable physics processing in components**

---

## 9. NEXT MILESTONES

### Milestone 1: Playable Prototype (2 weeks)
- Two characters can move and attack
- Basic hit detection works
- HP tracking functional
- Simple hitstun implementation

### Milestone 2: Complete Combat (4 weeks)
- Multiple moves per character
- Combo system
- Block/blockstun
- Stamina system
- Frame advantage working

### Milestone 3: Polish & Features (6-8 weeks)
- Special moves
- Meter/ultimates
- Status effects
- Projectiles
- Character-specific mechanics
- UI/HUD
- VFX/SFX

---

## 10. SUPPORT RESOURCES

### Documentation Files
- `architecture.md` - Overall system design
- `class-structure.md` - Class hierarchy (being updated)
- `character-data.md` - CharacterData/MoveData structure
- `input-system.md` - Input handling details
- `combat-system.md` - Combat mechanics
- `tick-system.md` - Frame-based timing

### Key Concepts to Understand
1. **Frame-based timing** - Everything happens in ticks, not delta time
2. **Manual overlap checking** - Don't use Area2D signals
3. **State machine pattern** - Clean state transitions
4. **Context pattern** - PlayerContext for dependency injection
5. **Resource vs RefCounted vs Node** - When to use each

### Getting Help
- Check documentation first
- Test incrementally
- Use print() liberally for debugging
- Draw debug visuals (rectangles, text)
- Ask specific questions about specific systems

---

**You have a solid foundation! The architecture is clean and the design patterns are good. Focus on implementing the core gameplay loop first (input → movement → attack → hit detection → damage), then expand from there.**
