# Tick-Based Frame System
## Crossing Realities Versus

**Date:** January 4, 2026  

---

## 1. OVERVIEW

This game uses a **tick-based frame system** instead of delta-time updates. Every system is synchronized to 60 FPS, where 1 tick = 1 frame = 1/60 second.

---

## 2. WHY TICK-BASED?

### 2.1. Fighting Game Requirements

**Determinism:**
- Frame data must be exact (e.g., "5 frame startup" means exactly 5 frames)
- Combos must be reproducible
- Hit confirmation needs frame-perfect precision

**Consistency:**
- Delta-time can vary slightly even at locked FPS
- Frame-based logic eliminates floating-point imprecision
- Network play (future) requires deterministic simulation

**Design Clarity:**
- Frame data is easier to understand (5 frames vs 0.0833 seconds)
- Balancing is more intuitive
- Debug/training tools show frame counts

---

## 3. IMPLEMENTATION

### 3.1. Core Pattern - Single Tick Source

**CRITICAL: Only GameManager has `_physics_process`**

All other systems implement ONLY `tick()`, which is called by their parent:

```gdscript
# GameManager (Autoload) - SINGLE SOURCE
func _physics_process(delta: float) -> void:
    current_frame += 1
    tick()

func tick() -> void:
    # InputManager no longer ticked (stateless)
    if current_match:
        current_match.tick()  # Cascade to match

# MatchManager - NO _physics_process
func tick() -> void:
    p1_fighter.tick()
    p2_fighter.tick()
    update_timer()

# Fighter - NO _physics_process
func tick() -> void:
    state_machine.tick()
    resource_manager.tick()
    # ... other subsystems
    move_and_slide()  # Godot physics

# All subsystems - NO _physics_process
func tick() -> void:
    # Frame-based logic here
    pass
```

**Why this architecture?**
- Single source of truth (GameManager.current_frame)
- Guaranteed call order (Input → Match → Fighters → Subsystems)
- No duplicate _physics_process calls
- Clear parent-child tick cascade

---

### 3.2. Global Frame Counter

```gdscript
# In GameManager (Autoload) - SINGLE SOURCE
var current_frame: int = 0

func _physics_process(delta: float) -> void:
    current_frame += 1
    tick()
```

All systems reference `GameManager.current_frame` for timestamps.

**Example:**
```gdscript
# In InputData
var timestamp: int

# In InputManager.poll_input()
input.timestamp = GameManager.current_frame

# In ComboTracker
var frames_elapsed = GameManager.current_frame - combo_start_frame
```

---

## 4. TICK CASCADE ARCHITECTURE

### 4.0. Tick Flow Diagram

```
_physics_process (Godot Engine, 60 FPS)
    ↓
GameManager._physics_process(delta)
    ↓
GameManager.tick() ← SINGLE SOURCE
    ↓
    └→ MatchManager.tick()
        ├→ Fighter1.tick()
        │   ├→ [Polls input via InputManager.poll_input(1)]
        │   ├→ [Adds to fighter1.input_buffer]
        │   ├→ StateMachine.tick()
        │   │   └→ CurrentState.tick()
        │   ├→ ResourceManager.tick()
        │   │   ├→ StaminaSystem.tick()
        │   │   └→ CharacterMeter.tick()
        │   ├→ MoveSystem.tick()
        │   ├→ CombatSystem.tick()
        │   │   ├→ HitboxManager.tick()
        │   │   └→ ComboTracker.tick()
        │   ├→ StatusManager.tick()
        │   └→ PassiveAbility.tick()
        │
        ├→ Fighter2.tick() (same as above)
        │
        └→ update_timer()
```

**Key Points:**
- Only ONE `_physics_process` in entire game (GameManager)
- Tick cascades down through hierarchy
- Guaranteed execution order
- All systems use `GameManager.current_frame`
- InputManager is stateless (no tick needed)
- Each Fighter polls input and manages its own buffer

---

## 4.1. INPUT BUFFER OWNERSHIP

**Design Decision:** Input buffers live in Fighter instances, not InputManager.

**Rationale:**
- InputManager is an autoload, would buffer inputs even in menus
- Fighter-owned buffers only exist during active matches
- Easy to clear between rounds (fighter.input_buffer.clear())
- No wasted memory/processing when not in gameplay

**Lifecycle:**
```
Menu Screen → No buffers exist (memory efficient)
Match Start → Fighters spawn → InputBuffers created in Fighter._ready()
Each Frame  → Fighter.tick() polls InputManager.poll_input(player_id)
           → Adds input to fighter.input_buffer
Round End   → fighter.reset_for_new_round() → buffer.clear()
Match End   → Fighters freed → InputBuffers destroyed
```

---

## 5. SYSTEM-BY-SYSTEM BREAKDOWN

### 5.1. Fighter

```gdscript
func _physics_process(delta: float) -> void:
    tick()

func tick() -> void:
    state_machine.tick()
    resource_manager.tick()
    move_system.tick()
    combat_system.tick()
    status_manager.tick()
    passive_ability.tick()
```

---

### 5.2. State Machine

```gdscript
func tick() -> void:
    if current_state:
        current_state.tick()  # State handles its own frame logic
        var next_state = current_state.check_transitions()
        if next_state != "":
            change_state(next_state)
```

---

### 5.3. State (Base Class)

```gdscript
class_name State

func tick() -> void:
    # Override in derived states
    # Handle per-frame logic here
    pass
```

**Example (HitStunState):**
```gdscript
var duration_frames: int = 15
var elapsed_frames: int = 0

func tick() -> void:
    elapsed_frames += 1
    
    if elapsed_frames >= duration_frames:
        state_machine.change_state("Idle")
```

---

### 5.4. ResourceManager

```gdscript
func tick() -> void:
    stamina_system.tick()  # Regenerate stamina per frame
    if character_meter:
        character_meter.tick()  # Charge meter per frame
```

---

### 5.5. StaminaSystem

**Before (delta-time):**
```gdscript
func update(delta: float) -> void:
    current_stamina += regen_rate * delta  # 30 per second
```

**After (frame-based):**
```gdscript
var regen_per_frame: float  # 30 / 60 = 0.5 per frame

func initialize(maximum: float, regen: float) -> void:
    regen_rate = regen
    regen_per_frame = regen_rate / 60.0  # Pre-calculate

func tick() -> void:
    current_stamina += regen_per_frame  # Add 0.5 every frame
```

---

### 5.6. MoveSystem

```gdscript
var current_frame: int = 0  # Current frame of move execution

func tick() -> void:
    if not current_move:
        return
    
    current_frame += 1
    
    # Check if hitbox should spawn
    if current_move.is_frame_active(current_frame):
        spawn_hitbox()
    
    # Check if move is complete
    if current_frame >= current_move.get_total_frames():
        end_move()
```

---

### 5.7. Hitbox

```gdscript
var lifetime_frames: int = 0
var max_lifetime: int = 3  # Active for 3 frames

func tick() -> void:
    lifetime_frames += 1
    if lifetime_frames >= max_lifetime:
        deactivate()
```

---

### 5.8. ComboTracker

**Before (delta-time):**
```gdscript
var combo_timer: float = 1.5  # seconds

func update(delta: float) -> void:
    combo_timer -= delta
```

**After (frame-based):**
```gdscript
var combo_timer_frames: int = 90  # 1.5 * 60 = 90 frames

func tick() -> void:
    combo_timer_frames -= 1
    if combo_timer_frames <= 0:
        end_combo()
```

---

### 5.9. InputManager

```gdscript
var current_frame: int = 0

func tick() -> void:
    current_frame += 1
    
    # Poll inputs every frame
    var p1_input = poll_input(1)
    var p2_input = poll_input(2)
    
    # Store with frame timestamp
    p1_input.timestamp = current_frame
    p2_input.timestamp = current_frame
    
    p1_input_buffer.add_input(p1_input)
    p2_input_buffer.add_input(p2_input)
```

---

### 5.10. Projectile

**Before (delta-time):**
```gdscript
var velocity: Vector2 = Vector2(300, 0)  # pixels per second

func _physics_process(delta: float) -> void:
    position += velocity * delta
```

**After (frame-based):**
```gdscript
var velocity: Vector2 = Vector2(300, 0)  # pixels per second
var velocity_per_frame: Vector2  # Pre-calculated

func _ready() -> void:
    velocity_per_frame = velocity / 60.0  # 300 / 60 = 5 pixels per frame

func tick() -> void:
    position += velocity_per_frame  # Move 5 pixels every frame
```

---

## 6. CONVERTING TIMES TO FRAMES

### 6.1. Conversion Formula

```gdscript
frames = seconds * 60
seconds = frames / 60.0
```

### 6.2. Common Conversions

| Seconds | Frames |
|---------|--------|
| 0.083s  | 5f     |
| 0.167s  | 10f    |
| 0.25s   | 15f    |
| 0.5s    | 30f    |
| 1.0s    | 60f    |
| 1.5s    | 90f    |
| 2.0s    | 120f   |

### 6.3. Helper Functions

```gdscript
class_name FrameData

static func frames_to_seconds(frames: int) -> float:
    return frames / 60.0

static func seconds_to_frames(seconds: float) -> int:
    return int(seconds * 60.0)
```

---

## 7. TIMERS: FRAMES VS DELTA

### 7.1. Frame-Based Timers (Preferred)

```gdscript
var timer_frames: int = 60  # 1 second

func tick() -> void:
    timer_frames -= 1
    if timer_frames <= 0:
        trigger_event()
```

**Advantages:**
- Exact frame count
- No floating-point errors
- Easy to reason about

---

### 7.2. Delta-Time (When Needed)

**Use delta-time for:**
- UI animations (non-gameplay)
- Camera smoothing
- Visual effects that aren't frame-critical

```gdscript
# For UI fade-in (not gameplay critical)
func _process(delta: float) -> void:
    modulate.a += fade_speed * delta
```

---

## 8. PHYSICS MOVEMENT

### 8.1. Move and Slide (Still Uses Delta)

Godot's `move_and_slide()` internally handles delta-time, but since we're at locked 60 FPS, velocity is effectively per-frame:

```gdscript
# In State.tick()
func tick() -> void:
    # Set velocity (pixels per frame at 60 FPS)
    fighter.velocity.x = 200  # Will move ~200 pixels per frame
    
    # Called from _physics_process which has delta
    # But at 60 FPS locked, this is consistent
```

**Note:** Velocity values in Godot are technically "per second" but at locked 60 FPS with `_physics_process`, they behave consistently as per-frame values.

---

## 9. INPUT BUFFERING WITH FRAMES

```gdscript
# InputBuffer stores frame timestamps
class_name InputData

var timestamp: int  # Frame number when input occurred

# Check if button was pressed within buffer window
func has_button_press(button: String, window_frames: int) -> bool:
    var current = InputManager.current_frame
    
    for input in buffer:
        if input.has_button_press(button):
            var frames_ago = current - input.timestamp
            if frames_ago <= window_frames:
                return true
    
    return false
```

---

## 10. DEBUGGING WITH FRAMES

### 10.1. Frame Display

```gdscript
# In HUD or debug overlay
func _process(delta: float) -> void:
    frame_label.text = "Frame: %d" % InputManager.current_frame
```

### 10.2. Frame Step Mode

```gdscript
var frame_step_mode: bool = false

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("debug_frame_step"):
        frame_step_mode = true
        get_tree().paused = true
    
    if event.is_action_pressed("debug_advance_frame"):
        if frame_step_mode:
            # Advance exactly 1 frame
            get_tree().paused = false
            await get_tree().physics_frame
            get_tree().paused = true
```

---

## 11. BEST PRACTICES

### 11.1. DO

✅ Use `tick()` for all gameplay logic  
✅ Use frame counters for timers  
✅ Pre-calculate per-frame values from per-second rates  
✅ Reference global frame counter for timestamps  
✅ Use integers for frame counts (avoid float drift)  

### 11.2. DON'T

❌ Don't add `_physics_process` to any system except GameManager  
❌ Don't create separate frame counters (use GameManager.current_frame)  
❌ Don't mix delta-time and frame counts in gameplay  
❌ Don't use `_process(delta)` for gameplay logic  
❌ Don't use floating-point timers for frame-critical events  
❌ Don't forget to convert seconds to frames in design documents  
❌ Don't call tick() directly - let the parent system cascade it  

---

## 12. EXAMPLE: COMPLETE MOVE EXECUTION

```gdscript
# MoveSystem.tick()
func tick() -> void:
    if not current_move:
        return
    
    current_frame += 1
    
    # Startup phase (frames 1-5)
    if current_frame < current_move.startup_frames:
        # Charging up, no hitbox yet
        pass
    
    # Active phase (frames 6-8)
    elif current_frame >= current_move.startup_frames and \
         current_frame < current_move.startup_frames + current_move.active_frames:
        # Spawn hitbox on first active frame
        if current_frame == current_move.startup_frames:
            spawn_hitbox()
    
    # Recovery phase (frames 9-18)
    elif current_frame < current_move.get_total_frames():
        # Move is recovering, can't act yet
        pass
    
    # Move complete
    else:
        end_move()
```

---

## SUMMARY

**Tick-based = Frame-perfect fighting game mechanics**

- 1 tick = 1 frame = 1/60 second
- All gameplay uses `tick()` instead of delta-time
- Frame counters replace float timers
- Deterministic, reproducible, and easier to balance

This architecture ensures the game behaves exactly as designed, with frame-perfect precision for competitive play.
