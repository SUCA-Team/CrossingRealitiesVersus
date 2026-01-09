# Crossing Realities Versus - Documentation Index
**2D Fighting Game for Godot 4.x**

---

## 📚 START HERE

### New to the Project?
1. Read [ARCHITECTURE.md](ARCHITECTURE.md) - Complete system design
2. Review [input-system.md](input-system.md) - Already implemented (no changes needed)
3. Check [implementation-status.md](implementation-status.md) - What's done and what's next

### Implementing Features?
1. Follow the **4-phase migration plan** in [ARCHITECTURE.md](ARCHITECTURE.md#12-migration-plan)
2. Reference specific sections for implementation details
3. Maintain rollback-readiness throughout development

---

## 📖 DOCUMENTATION MAP

### Core Architecture
- **[ARCHITECTURE.md](ARCHITECTURE.md)** ⭐ *START HERE*
  - Complete system design for production-scale game
  - Three-layer architecture (Presentation/State/Systems)
  - Rollback netcode strategy
  - Status effects and passive abilities
  - Migration plan from current to optimal

### Implemented Systems
- **[input-system.md](input-system.md)** ✅ *ROLLBACK-READY*
  - Bitmasking implementation (industry standard)
  - Command abstraction and buffering
  - No changes needed for rollback
  - Grade: **A+** for rollback readiness

### Legacy Documentation
- [combat-system.md](combat-system.md) - Outdated, see ARCHITECTURE.md Section 5
- [tick-system.md](tick-system.md) - Outdated, see ARCHITECTURE.md Section 1.2
- [character-data.md](character-data.md) - Partial, see ARCHITECTURE.md Section 4
- [class-structure.md](class-structure.md) - Outdated, see ARCHITECTURE.md Section 1
- [component-communication.md](component-communication.md) - Outdated, see ARCHITECTURE.md Section 8
- [resource-system.md](resource-system.md) - Outdated, see ARCHITECTURE.md Section 6
- [implementation-plan.md](implementation-plan.md) - Outdated, see ARCHITECTURE.md Section 12

### Project Context
- [implementation-status.md](implementation-status.md) - Current progress tracker
- [CrossingRealitiesVersus-en.md](CrossingRealitiesVersus-en.md) - Game design vision
- [CrossingRealitiesVersus-vi.md](CrossingRealitiesVersus-vi.md) - Vietnamese translation
- [GameplayRules-vi.md](GameplayRules-vi.md) - Vietnamese gameplay rules

---

## 🎯 QUICK REFERENCE

### Current Implementation Status

| System | Status | Rollback-Ready | Grade |
|--------|--------|----------------|-------|
| **Input System** | ✅ Complete | ✅ Yes | A+ |
| **Command Mapping** | ⚠️ Partial | ✅ Yes | A- |
| **Frame Sync** | ✅ Complete | ✅ Yes | A |
| **State/Presentation** | ❌ Coupled | ❌ No | D |
| **State Machine** | ❌ Not Started | ❌ No | N/A |
| **Combat System** | ❌ Not Started | ❌ No | N/A |
| **Status Effects** | ❌ Placeholder | ❌ No | N/A |
| **Passive Abilities** | ❌ Not Started | ❌ No | N/A |
| **Rollback Manager** | ❌ Not Started | ❌ No | N/A |

### Critical Bugs to Fix

1. **CommandBuffer lacks size limit** → Add `const BUFFER_SIZE: int = 20`
2. **Commands never consumed** → Implement `Character.tick()` command handling
3. **Characters not in scene tree** → Add to tree in `Match._ready()`

### Immediate Next Steps

**Phase 1: State Separation (Week 1)**
1. Create `PlayerSnapshot` class with all game state
2. Create `CharacterView` (rename current Character)
3. Implement `sync_from_state()` method
4. Create `MatchSnapshot` coordinator

See [ARCHITECTURE.md Section 12](ARCHITECTURE.md#12-migration-plan) for complete roadmap.

---

## 🏗️ ARCHITECTURE OVERVIEW

### Three-Layer Design

```
┌─────────────────────────────────────────┐
│   PRESENTATION LAYER (Node2D)           │
│   - CharacterView, HitboxView           │
│   - Visual effects, animations          │
│   - Syncs from game state                │
└─────────────────────────────────────────┘
              ↓ sync_from_state()
┌─────────────────────────────────────────┐
│   GAME STATE LAYER (RefCounted)         │
│   - MatchSnapshot, PlayerSnapshot        │
│   - Pure data, no Node references        │
│   - Serializable for rollback            │
└─────────────────────────────────────────┘
              ↓ process()
┌─────────────────────────────────────────┐
│   SYSTEMS LAYER (RefCounted)            │
│   - StateMachine, CombatSystem           │
│   - StatusSystem, PhysicsSystem          │
│   - Reads state, returns updates         │
└─────────────────────────────────────────┘
```

**Key Principle:** Game state is pure data. Systems process state deterministically. Presentation reads state without modifying it.

### Why This Matters

**Rollback netcode requires:**
- Complete state serialization (save/restore game state)
- No hidden state in Node properties
- Deterministic execution (same input → same output)
- Efficient state snapshots (~4KB per frame)

**Current architecture blocks rollback because:**
- Character extends Node2D (position in tree, not data)
- State machine would use Node states (not serializable)
- Commands never consumed (no state progression)
- No separation between game logic and visuals

**Migrating to three-layer architecture enables:**
- ✅ Save complete game state in 8-frame history
- ✅ Rollback to any frame and re-simulate
- ✅ Transmit state snapshots over network
- ✅ Implement replay system
- ✅ Add status effects and passives as pure data

---

## 🔬 DEVELOPMENT WORKFLOW

### Adding a New Move

1. **Define in CharacterData** (data layer)
   ```gdscript
   @export var new_move: MoveData
   ```

2. **Add MoveData resource** (data layer)
   ```gdscript
   # res://data/moves/character_name/new_move.tres
   startup_frames = 8
   active_frames = 4
   recovery_frames = 12
   ```

3. **Add StateID** (state layer)
   ```gdscript
   # In StateID enum
   NEW_MOVE_STARTUP,
   NEW_MOVE_ACTIVE,
   NEW_MOVE_RECOVERY,
   ```

4. **Add Command** (input layer)
   ```gdscript
   # In Command.Type enum
   NEW_MOVE,
   ```

5. **Map input to command** (input layer)
   ```gdscript
   # In PlayerController._map_command()
   if _is_special_motion(input) and (input.pressed_mask & InputBits.SPECIAL1):
       cmd_buffer.push(Command.new(Command.Type.NEW_MOVE, input.frame))
   ```

6. **Handle in state machine** (systems layer)
   ```gdscript
   # In StateMachine.tick()
   if state_id == StateID.IDLE and cmd == Command.Type.NEW_MOVE:
       return StateTransition.new(StateID.NEW_MOVE_STARTUP, data.new_move)
   ```

7. **Process state transition** (systems layer)
   ```gdscript
   # StateMachine automatically handles:
   # - Frame counting
   # - State progression (startup → active → recovery)
   # - Hitbox activation
   ```

8. **Sync visual** (presentation layer)
   ```gdscript
   # CharacterView.sync_from_state() already handles:
   # - Position
   # - Animation (based on state_id)
   # - Hitbox rendering
   ```

**That's it!** The architecture handles the rest deterministically.

---

## 🧪 TESTING STRATEGY

### Unit Tests (Per-System)
- `test_input_system.gd` - Bitmasking, command mapping
- `test_state_machine.gd` - State transitions, frame counting
- `test_combat_system.gd` - Hitbox collision, damage calculation
- `test_status_system.gd` - Buff/debuff application, stacking
- `test_physics_system.gd` - Movement, gravity, collision

### Integration Tests (Cross-System)
- `test_match_flow.gd` - Complete match simulation
- `test_rollback.gd` - Save/restore state, re-simulation
- `test_netcode.gd` - Input delay, rollback correctness

### Determinism Tests (Critical)
- Same input history → Same game state (100 iterations)
- Rollback 8 frames → Same outcome
- No floating point drift over 10,000 frames

### Performance Tests
- State snapshot < 4KB
- Rollback < 2ms (60 FPS budget: 16.67ms)
- Input processing < 0.1ms

---

## 📊 PROGRESS TRACKING

### Phase 1: State Separation (Week 1)
- [ ] Create PlayerSnapshot with all state variables
- [ ] Create CharacterView (rename Character)
- [ ] Implement sync_from_state()
- [ ] Create MatchSnapshot

### Phase 2: Systems Refactor (Week 2)
- [ ] Extract StateMachine as data-driven system
- [ ] Implement CombatSystem with manual collision
- [ ] Create StatusSystem for buffs/debuffs
- [ ] Implement PhysicsSystem

### Phase 3: Passives (Week 3)
- [ ] Create PassiveData resource
- [ ] Implement PassiveSystem with triggers
- [ ] Add passive_abilities to CharacterData
- [ ] Test trigger types

### Phase 4: Rollback (Week 4)
- [ ] Implement serialize()/deserialize()
- [ ] Create RollbackManager
- [ ] Add input history
- [ ] Test local rollback

### Phase 5: Polish (Week 5)
- [ ] Performance optimization
- [ ] Complete all 35 command mappings
- [ ] Visual polish (effects, animations)
- [ ] Comprehensive testing

---

## 🎓 LEARNING RESOURCES

### Fighting Game Development
- **GDC Talks:**
  - "Rollback Netcode in 'Mortal Kombat' and 'Injustice 2'" (NetherRealm Studios)
  - "Building a Better Input System" (Skullgirls)
  - "Determinism in Competitive Fighting Games" (Killer Instinct)

- **Articles:**
  - GGPO Whitepaper (Tony Cannon)
  - "Core-A Gaming" YouTube series on fighting game mechanics
  - Gaffer on Games: "Deterministic Lockstep"

### Godot Specific
- Godot docs: Custom Resources
- Godot docs: RefCounted vs Object
- Godot forums: Deterministic physics discussions

### Bitmasking and Performance
- "Bit Twiddling Hacks" (Sean Eron Anderson)
- "Data-Oriented Design" (Richard Fabian)

---

## 🤝 CONTRIBUTION GUIDELINES

### Code Style
- Follow GDScript style guide
- Use `class_name` for all classes
- Document public methods with docstrings
- Use type hints everywhere

### Adding Features
1. Check if requires architecture changes
2. Write unit tests first (TDD)
3. Ensure determinism (if game logic)
4. Update documentation
5. Test rollback impact

### Reviewing Code
- Verify determinism (no `randf()`, no `Time.get_ticks()`)
- Check state is in RefCounted classes
- Ensure no hidden state in Nodes
- Validate serialization

---

## 🐛 DEBUGGING GUIDE

### Input Not Registering
1. Check `InputMapper` resource has correct keycodes
2. Enable input debug print in `PlayerController.tick()`
3. Verify `Input.is_action_pressed()` returns true
4. Check bitmask is set correctly

### Commands Not Executing
1. Verify command is in buffer (print `cmd_buffer.buffer.size()`)
2. Check state machine accepts command in current state
3. Ensure `CommandBuffer.pop()` is called
4. Verify frame window is valid (within 3 frames)

### State Desync in Rollback
1. Print state hashes before/after rollback
2. Check for non-deterministic code:
   - Random numbers without seeded RNG
   - Time-based calculations
   - Floating point operations
3. Verify input history is correct
4. Test with single-player match first

### Performance Issues
1. Profile with Godot's built-in profiler
2. Check state snapshot size (should be ~4KB)
3. Verify no expensive operations in `_physics_process`
4. Consider object pooling for projectiles

---

## 📝 CHANGELOG

### January 8, 2026
- ✅ Created comprehensive ARCHITECTURE.md
- ✅ Validated input system as rollback-ready (A+ grade)
- ✅ Updated input-system.md to reference new architecture
- ✅ Created documentation index (this file)
- 🔄 Migration plan defined (4 phases)

### January 7, 2026
- ✅ Completed input system documentation
- ✅ Added command mapping reference
- ✅ Identified 4 critical bugs
- ✅ Provided comprehensive code review

### Earlier
- ✅ Input system implementation (bitmasking)
- ✅ Command abstraction
- ✅ Frame synchronization
- ✅ Basic match structure

---

## 📞 CONTACT & SUPPORT

### Questions?
- Check existing documentation first
- Search closed issues for similar problems
- Ask in discussions (design questions)
- File issues for bugs

### Priorities
1. **Critical:** Rollback-breaking bugs (desync, non-determinism)
2. **High:** Gameplay bugs (incorrect damage, state transitions)
3. **Medium:** Performance issues, missing features
4. **Low:** Visual polish, convenience features

---

## 🎯 PROJECT GOALS

### Short-Term (Next Month)
- ✅ Complete state/presentation separation
- ✅ Implement data-driven state machine
- ✅ Add status effect system
- ✅ Create passive ability framework

### Mid-Term (Next Quarter)
- ⬜ Implement local rollback (no network)
- ⬜ Add 2 complete characters with unique movesets
- ⬜ Polish visual feedback
- ⬜ Create training mode

### Long-Term (Next Year)
- ⬜ Network rollback netcode
- ⬜ Ranked matchmaking
- ⬜ Replay system
- ⬜ 8+ character roster
- ⬜ Tournament mode

---

**Remember:** This is a marathon, not a sprint. Focus on architecture quality over feature quantity. A solid foundation enables rapid feature development later.

**Next Action:** Fix the 3 critical bugs, then start Phase 1 (state separation).

Good luck! 🚀
