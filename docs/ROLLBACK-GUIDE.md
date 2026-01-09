# Rollback vs Core Gameplay - Quick Reference
**Crossing Realities Versus**

This document clarifies what you need **now** (core gameplay) vs **later** (rollback netcode).

---

## TL;DR

**✅ Implement First (Core Gameplay - Makes Game Playable)**
- PlayerSnapshot, HitboxSnapshot, StatusSnapshot
- StateMachine, CombatSystem, PhysicsSystem
- CharacterView (rename Character)
- All systems and game logic

**🌐 Defer Until Netcode (Rollback-Specific)**
- MatchSnapshot coordinator
- RollbackManager class
- serialize()/clone() methods
- Input history storage

**Your current architecture is already rollback-ready!** You're using deterministic design patterns that enable rollback without changing game logic.

---

## Core Gameplay (Do This First) ✅

### Phase 1: State Separation
```gdscript
// ✅ Core - Implement now
class PlayerSnapshot extends RefCounted:
    var position: Vector2i
    var health: int
    var state_id: StateID
    # ... all game state
    
    func is_airborne() -> bool  # ✅ Core
    func can_act() -> bool      # ✅ Core
    
    # 🌐 Rollback - Add later
    # func serialize() -> Dictionary
    # func clone() -> PlayerSnapshot
```

### Phase 2: Systems
```gdscript
// ✅ Core - All systems needed for gameplay
class StateMachine:
    static func tick(state, cmd, opponent, data) -> StateTransition
    
class CombatSystem:
    static func check_collisions(p1, p2) -> Array[HitResult]
    
class PhysicsSystem:
    static func tick(state, char_data, bounds) -> void
```

### Phase 3: Passives & Status
```gdscript
// ✅ Core - Character abilities and effects
class StatusSnapshot extends RefCounted:
    var status_type: StatusType
    var frames_remaining: int
    # ... status state

class PassiveSystem:
    static func check_triggers(state, opponent, trigger_type) -> void
```

---

## Rollback-Specific (Do This Later) 🌐

### What You'll Add in Phase 4

**1. MatchSnapshot Coordinator** 🌐
```gdscript
// 🌐 Only for rollback - skip initially
class MatchSnapshot extends RefCounted:
    var frame: int
    var p1: PlayerSnapshot
    var p2: PlayerSnapshot
    
    func serialize() -> Dictionary  # Network transmission
    func clone() -> MatchSnapshot   # History storage
```

**2. RollbackManager** 🌐
```gdscript
// 🌐 Only for netcode
class RollbackManager:
    var snapshot_history: Array[MatchSnapshot]
    var input_history: Array
    
    func save_snapshot(snapshot)
    func rollback_to_frame(frame)
```

**3. Serialization Methods** 🌐
```gdscript
// Add these to PlayerSnapshot later
func serialize() -> Dictionary:
    return {
        "position": [position.x, position.y],
        "health": health,
        "state_id": state_id,
        # ... all state
    }

func deserialize(data: Dictionary) -> void:
    position = Vector2i(data.position[0], data.position[1])
    health = data.health
    # ... restore all state

func clone() -> PlayerSnapshot:
    var copy = PlayerSnapshot.new()
    # ... deep copy all state
    return copy
```

**4. Input History** 🌐
```gdscript
// Add to Match later
class InputHistory:
    const MAX_FRAMES = 8
    var p1_history: Array[InputData]
    var p2_history: Array[InputData]
    
    func store(p1_input, p2_input)
    func get_at_frame(player_id, frame) -> InputData
```

---

## Why This Separation Works

### Rollback-Ready Design (Already Doing) ✅

1. **Deterministic Logic** ✅
   - Fixed-point math (Vector2i, not Vector2)
   - No `randf()` without seeded RNG
   - Manual collision (Rect2i, not Area2D signals)
   - Frame counters, not time-based

2. **State Separation** ✅
   - State in RefCounted (PlayerSnapshot)
   - Presentation in Node2D (CharacterView)
   - No hidden state in scene tree

3. **Stateless Systems** ✅
   - Systems don't store state
   - Pure functions: same input → same output
   - Can rerun during rollback

### Rollback-Specific Code (Add Later) 🌐

1. **Serialization** 🌐
   - Convert state to Dictionary/bytes
   - For network transmission
   - Not needed for local gameplay

2. **Snapshot History** 🌐
   - Store last 8 frames of game state
   - For rollback recovery
   - Not needed without netcode

3. **Input History** 🌐
   - Store last 8 frames of input
   - For re-simulation after rollback
   - Not needed for local gameplay

---

## Class-by-Class Breakdown

| Class | Priority | Reason |
|-------|----------|--------|
| **PlayerSnapshot** | ✅ Critical | Core game state |
| **HitboxSnapshot** | ✅ Critical | Collision detection |
| **ProjectileSnapshot** | ✅ High | If game has projectiles |
| **StatusSnapshot** | ✅ Medium | Buffs/debuffs |
| **MatchSnapshot** | 🌐 Rollback | Coordinator (skip initially) |
| | | |
| **StateMachine** | ✅ Critical | State transitions |
| **CombatSystem** | ✅ Critical | Damage/collision |
| **PhysicsSystem** | ✅ Critical | Movement/gravity |
| **StatusSystem** | ✅ Medium | Status effects |
| **PassiveSystem** | ✅ Medium | Character abilities |
| | | |
| **CharacterView** | ✅ Critical | Visual representation |
| **HitboxView** | ✅ Low | Debug tool (optional) |
| | | |
| **RollbackManager** | 🌐 Rollback | Entire class (defer) |

---

## Your Match.tick() Evolution

### Now (Core Gameplay) ✅
```gdscript
func tick() -> void:
    # 1. Input
    var p1_cmd = input_system.map_command(...)
    var p2_cmd = input_system.map_command(...)
    
    # 2. State machine
    state_machine.tick(p1_snapshot, p1_cmd, ...)
    state_machine.tick(p2_snapshot, p2_cmd, ...)
    
    # 3. Physics
    physics_system.tick(p1_snapshot, ...)
    physics_system.tick(p2_snapshot, ...)
    
    # 4. Combat
    combat_system.check_collisions(p1_snapshot, p2_snapshot)
    
    # 5. Status/Passives
    status_system.tick(p1_snapshot)
    passive_system.tick_cooldowns(p1_snapshot)
    
    # 6. Presentation
    p1_view.sync_from_state(p1_snapshot)
    p2_view.sync_from_state(p2_snapshot)
```

### Later (With Rollback) 🌐
```gdscript
func tick() -> void:
    # Same as above...
    
    # 7. Rollback (ADD THIS LATER) 🌐
    rollback_manager.save_snapshot(match_snapshot.clone())
    rollback_manager.save_inputs(p1_input, p2_input)
    
    # Network receives remote input for frame N-3
    # if (remote_input.frame < current_frame):
    #     rollback_manager.rollback_to_frame(remote_input.frame)
    #     # Re-simulate frames N-3 to N
```

---

## Common Questions

### Q: Do I need MatchSnapshot to make the game work?
**A:** No! Just use `p1_snapshot` and `p2_snapshot` directly in Match. MatchSnapshot is purely for rollback coordination.

### Q: What about serialize() and clone()?
**A:** Skip them initially. Your game logic works without serialization. Add them when implementing netcode.

### Q: Is my architecture still "rollback-ready" if I skip rollback features?
**A:** Yes! Rollback-ready means:
- ✅ Deterministic (you're doing this)
- ✅ State separation (you're doing this)
- ✅ Stateless systems (you're doing this)
- 🌐 Serialization (add later)

The first 3 make your game work. The 4th enables rollback.

### Q: How much work is adding rollback later?
**A:** If you follow the architecture:
- **Week 1-3:** Implement core gameplay (state/systems/presentation)
- **Week 4:** Add rollback (serialization + RollbackManager)

Only ~1 week of work because your architecture is ready.

### Q: Can I test rollback without netcode?
**A:** Yes! In Phase 4, simulate rollback locally:
```gdscript
# Simulate 3-frame rollback every 60 frames
if frames_elapsed % 60 == 0:
    rollback_manager.rollback_to_frame(frames_elapsed - 3)
    # Game should look identical
```

---

## Implementation Checklist

### Now: Core Gameplay ✅
- [ ] Fix 3 critical bugs
- [ ] Create PlayerSnapshot (state separation)
- [ ] Create CharacterView (rename Character)
- [ ] Implement StateMachine with StateID enum
- [ ] Implement CombatSystem with manual collision
- [ ] Implement PhysicsSystem with fixed-point math
- [ ] Add StatusSystem for buffs/debuffs
- [ ] Add PassiveSystem for abilities
- [ ] Test game is fully playable locally

### Later: Rollback Netcode 🌐
- [ ] Add serialize()/deserialize() to PlayerSnapshot
- [ ] Create MatchSnapshot coordinator
- [ ] Implement RollbackManager
- [ ] Add input history storage
- [ ] Test local rollback simulation
- [ ] Add network synchronization
- [ ] Test with simulated latency
- [ ] Polish network UI (ping display, etc.)

---

## Key Takeaway

**You're building a rollback-ready fighting game, not a rollback engine.**

Focus on making the game fun first. The architecture prepares for rollback without blocking gameplay development. When you're ready for online, adding rollback is a clean additional layer, not a rewrite.

**Architecture is already perfect. Just defer the serialization layer until Phase 4.** 🚀
