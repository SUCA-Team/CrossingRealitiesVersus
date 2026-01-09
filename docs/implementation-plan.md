# Implementation Plan
## Crossing Realities Versus

**Date:** January 4, 2026  
**Engine:** Godot 4.5  
**Target:** 24-week development cycle  

---

## PHASE 1: FOUNDATION (Weeks 1-4)

### Week 1: Project Setup & Core Systems
**Goal:** Basic project structure and tick system

- [ ] Create Godot project with proper settings (60 FPS lock)
- [ ] Set up folder structure (`res://scripts/`, `res://data/`, `res://scenes/`)
- [ ] Implement GameManager singleton with centralized tick system
- [ ] Implement global frame counter
- [ ] Create basic test scene
- [ ] Set up version control practices

**Deliverable:** Empty project with GameManager ticking at 60 FPS

---

### Week 2: Input System
**Goal:** Complete input polling and buffering

- [ ] Implement InputManager singleton
- [ ] Create InputData and InputBuffer classes
- [ ] Set up input mappings for P1 and P2 (keyboard)
- [ ] Implement input buffering (5-frame window)
- [ ] Create InputDisplay for debugging
- [ ] Test input polling at 60 FPS

**Deliverable:** Working input system with buffer visualization

---

### Week 3: Basic Fighter & Movement
**Goal:** Character can move on screen

- [ ] Create Fighter (CharacterBody2D) scene
- [ ] Implement basic movement (walk left/right)
- [ ] Implement jump with gravity
- [ ] Create simple Stage scene with ground
- [ ] Connect Fighter to InputManager
- [ ] Test 2 fighters on stage

**Deliverable:** Two characters that can walk and jump

---

### Week 4: State Machine Foundation
**Goal:** Fighter uses state machine for logic

- [ ] Create StateMachine node
- [ ] Implement State base class
- [ ] Create IdleState, WalkState, JumpState
- [ ] Implement state transitions
- [ ] Test state switching with debug display
- [ ] Add state visualization for debugging

**Deliverable:** Fighter with working state machine (Idle/Walk/Jump)

---

## PHASE 2: COMBAT CORE (Weeks 5-8)

### Week 5: Resource System
**Goal:** HP and Stamina working

- [ ] Implement HPSystem class
- [ ] Implement StaminaSystem class (frame-based regen)
- [ ] Create ResourceManager node
- [ ] Connect to Fighter
- [ ] Create basic HP/Stamina bars in HUD
- [ ] Test stamina regeneration and consumption

**Deliverable:** Fighters with visible HP and Stamina

---

### Week 6: Hitbox/Hurtbox System
**Goal:** Can detect hits between fighters

- [ ] Implement Hitbox class (Area2D)
- [ ] Implement Hurtbox class (Area2D)
- [ ] Create HitboxManager with object pooling
- [ ] Create HurtboxManager
- [ ] Set up collision layers (P1/P2)
- [ ] Implement hit detection
- [ ] Test with debug visualization

**Deliverable:** Hitboxes detect hurtbox collisions

---

### Week 7: Basic Attacks & Damage
**Goal:** Fighter can attack and deal damage

- [ ] Create MoveData resource structure
- [ ] Create MoveSystem node
- [ ] Implement AttackState
- [ ] Create 2-3 basic normal attacks (Light, Heavy)
- [ ] Implement damage application
- [ ] Create HitData structure
- [ ] Test hit confirmation and damage

**Deliverable:** Fighter can perform attacks that damage opponent

---

### Week 8: Hitstun & Block
**Goal:** Hit reactions and blocking work

- [ ] Implement HitStunState with frame-based duration
- [ ] Implement BlockState
- [ ] Implement BlockStunState
- [ ] Add knockback to hits
- [ ] Connect stamina consumption to blocking
- [ ] Test block vs hit interactions
- [ ] Add basic hit/block VFX

**Deliverable:** Complete hit/block system with hitstun

---

## PHASE 3: ADVANCED SYSTEMS (Weeks 9-12)

### Week 9: Dash System
**Goal:** All 4 dash variants working

- [ ] Implement DashState
- [ ] Implement HeavyDashState (pass-through)
- [ ] Implement EvadeState (i-frames)
- [ ] Implement GrabState
- [ ] Create CommandDetector for dash commands
- [ ] Test all dash variants
- [ ] Balance stamina costs

**Deliverable:** Complete dash system (Dash/Heavy/Evade/Grab)

---

### Week 10: Combo System
**Goal:** Combos scale damage and track hits

- [ ] Implement ComboTracker class
- [ ] Add damage scaling formula
- [ ] Create ComboDisplay UI
- [ ] Implement cancel system for moves
- [ ] Test combo chains
- [ ] Add combo counter to HUD

**Deliverable:** Working combo system with scaling

---

### Week 11: Special Moves
**Goal:** Can execute special moves with modifiers

- [ ] Expand CommandDetector for attack modifiers
- [ ] Create special move templates
- [ ] Implement enhanced move variants (meter cost)
- [ ] Add projectile system (if needed for character)
- [ ] Test special move execution
- [ ] Balance frame data and damage

**Deliverable:** Special moves with normal/enhanced variants

---

### Week 12: Status Effects & Guard Break
**Goal:** Status effects and stamina depletion work

- [ ] Implement StatusEffect resource
- [ ] Create StatusManager node
- [ ] Implement StunnedState (stamina depleted)
- [ ] Test guard break on 0 stamina
- [ ] Create 2-3 example status effects (Burn, Armor, etc.)
- [ ] Test status application on hit

**Deliverable:** Status effects and guard break functional

---

## PHASE 4: FIRST CHARACTER (Weeks 13-16)

### Week 13: Character Data Structure
**Goal:** Complete character data pipeline

- [ ] Finalize CharacterData resource
- [ ] Create character creation template
- [ ] Set up data folder organization
- [ ] Create character loader system
- [ ] Test character instantiation
- [ ] Document character creation workflow

**Deliverable:** CharacterData resource system ready

---

### Week 14: First Character - Normals
**Goal:** Complete all 8 normal attacks

- [ ] Design first character concept (all-rounder)
- [ ] Create character sprite/animations
- [ ] Implement all 5 Light attacks
- [ ] Implement all 3 Heavy attacks
- [ ] Create hitbox data for each normal
- [ ] Balance frame data
- [ ] Test all normals in combat

**Deliverable:** First character with 8 normals

---

### Week 15: First Character - Specials & Meter
**Goal:** 12 special moves and character meter

- [ ] Design character meter type (Damage/Charge/Stack)
- [ ] Implement CharacterMeter class for this character
- [ ] Create all 12 special moves (3 skills × 4 variants)
- [ ] Implement meter building and spending
- [ ] Test enhanced moves
- [ ] Balance stamina/meter costs

**Deliverable:** First character with specials and meter

---

### Week 16: First Character - Ultimates & Passive
**Goal:** Complete first character (28 moves)

- [ ] Implement multi-button detection for ultimates
- [ ] Create all 4 ultimates
- [ ] Design character passive ability
- [ ] Implement PassiveAbility script
- [ ] Test passive activation/conditions
- [ ] Balance ultimate damage and conditions
- [ ] Playtest full character

**Deliverable:** First complete character (28 moves + passive)

---

## PHASE 5: MATCH SYSTEM & SECOND CHARACTER (Weeks 17-20)

### Week 17: Match Flow
**Goal:** Complete match management

- [ ] Implement MatchManager fully
- [ ] Create round system (best of 3)
- [ ] Implement match timer (countdown)
- [ ] Create round start/end sequences
- [ ] Implement KO detection
- [ ] Add round win tracking
- [ ] Test full match flow

**Deliverable:** Full match system with rounds

---

### Week 18: UI/HUD Polish
**Goal:** Complete and polish all UI

- [ ] Polish HP/Stamina bars with animations
- [ ] Add character meter display
- [ ] Improve combo counter display
- [ ] Add round indicators
- [ ] Create pause menu
- [ ] Add training mode UI
- [ ] Test UI responsiveness

**Deliverable:** Polished in-game UI

---

### Week 19: Second Character - Implementation
**Goal:** Second complete character

- [ ] Design second character (different archetype)
- [ ] Create sprites/animations
- [ ] Implement all 28 moves
- [ ] Create unique passive ability
- [ ] Create unique character meter
- [ ] Test character balance vs first character

**Deliverable:** Second playable character

---

### Week 20: Character Select & Menus
**Goal:** Menu system complete

- [ ] Create main menu
- [ ] Implement character select screen
- [ ] Add stage select (if multiple stages)
- [ ] Create options menu (controls, audio, etc.)
- [ ] Implement scene transitions
- [ ] Add character portraits and UI art
- [ ] Test full menu flow

**Deliverable:** Complete menu system

---

## PHASE 6: POLISH & BALANCE (Weeks 21-24)

### Week 21: Visual Effects & Audio
**Goal:** Add all VFX and SFX

- [ ] Create hit effect particles
- [ ] Create block effect particles
- [ ] Add dash/movement VFX
- [ ] Implement all hit sounds
- [ ] Add UI sounds
- [ ] Create background music
- [ ] Test audio/visual feedback

**Deliverable:** Complete VFX and audio

---

### Week 22: Balance Pass
**Goal:** Balance all characters and systems

- [ ] Playtest extensively (both characters)
- [ ] Adjust frame data based on testing
- [ ] Balance damage values
- [ ] Tune stamina costs and regen
- [ ] Fix exploits and infinites
- [ ] Document balance changes

**Deliverable:** Balanced game ready for testing

---

### Week 23: Bug Fixes & Optimization
**Goal:** Fix all known issues

- [ ] Fix collision bugs
- [ ] Fix state machine edge cases
- [ ] Optimize hitbox pooling
- [ ] Fix input buffer issues
- [ ] Optimize rendering
- [ ] Fix UI bugs
- [ ] Profile performance (maintain 60 FPS)

**Deliverable:** Stable, bug-free build

---

### Week 24: Final Polish & Release Prep
**Goal:** Release-ready build

- [ ] Final playtesting session
- [ ] Add credits screen
- [ ] Create README documentation
- [ ] Add controller support (if time permits)
- [ ] Final art pass
- [ ] Create trailer/promotional materials
- [ ] Package for distribution
- [ ] Release!

**Deliverable:** Release-ready game

---

## PARALLEL TASKS (Ongoing)

Throughout all phases:

### Art & Animation
- Character sprites
- Stage backgrounds
- UI elements
- VFX particles
- Icon/promotional art

### Audio
- Hit sounds
- UI sounds
- Character voice lines
- Background music
- Sound effects

### Documentation
- Code documentation
- Design document updates
- Player manual
- Tutorial content

### Testing
- Weekly playtests
- Bug tracking
- Balance notes
- Performance profiling

---

## MILESTONES & CHECKPOINTS

### Milestone 1 (Week 4): Prototype
- Two characters can move and jump
- Input system working

### Milestone 2 (Week 8): Combat Alpha
- Attacks, damage, hit reactions working
- Block system functional

### Milestone 3 (Week 12): Feature Complete (Systems)
- All combat systems implemented
- Special moves, combos, status effects

### Milestone 4 (Week 16): First Playable Character
- One complete character (28 moves)
- Can fight against clone

### Milestone 5 (Week 20): Content Complete
- Two characters
- Match system
- Menus

### Milestone 6 (Week 24): Release
- Polished, balanced, bug-free

---

## CRITICAL PATH

These tasks MUST be completed before moving to next phase:

1. **Tick System** → Everything depends on this
2. **Input Buffer** → Required for all player actions
3. **State Machine** → Required for fighter logic
4. **Hitbox System** → Required for combat
5. **Resource System** → Required for stamina mechanics
6. **Move System** → Required for all attacks
7. **Character Data** → Required for characters

---

## RISK MITIGATION

### High Risk Areas

**Stamina Balance:**
- Risk: Block-as-resource might feel too punishing
- Mitigation: Extensive playtesting, tunable values
- Contingency: Add stamina boost items or adjust costs

**Frame-Perfect Execution:**
- Risk: Input buffer might not feel responsive enough
- Mitigation: Test buffer window sizes (3-5-7 frames)
- Contingency: Add leniency options in settings

**Character Balance:**
- Risk: One character dominates
- Mitigation: Weekly balance testing
- Contingency: Quick patch system for adjustments

**Performance:**
- Risk: Can't maintain 60 FPS
- Mitigation: Profile early, optimize hitbox pooling
- Contingency: Reduce visual effects, simplify animations

---

## TOOLS & WORKFLOW

### Development Tools
- Godot 4.5
- Git for version control
- GitHub for repository
- VS Code / Godot built-in editor

### Asset Creation
- Aseprite / Photoshop for sprites
- Audacity for audio editing
- LMMS / FL Studio for music

### Testing
- Manual playtesting (weekly)
- Frame data testing tool (build in Week 18)
- Training mode for iteration

---

## TEAM STRUCTURE (If Applicable)

**Solo Developer:**
- Follow phases sequentially
- Focus on core gameplay first
- Art/audio can be placeholder initially

**Small Team (2-3):**
- Programmer: Core systems
- Artist: Characters & UI
- Sound Designer: Audio implementation

**Larger Team:**
- Lead: Architecture oversight
- Gameplay Programmer: Combat systems
- UI Programmer: Menus & HUD
- Character Designer: Move design & balance
- Artist: Sprites & animations
- Sound Designer: Audio

---

## POST-RELEASE ROADMAP

### Version 1.1 (Post-Release)
- Additional characters (2-3 more)
- Additional stages
- Training mode enhancements
- Balance patches

### Version 2.0 (Future)
- Online multiplayer (rollback netcode)
- Ranked mode
- Replay system
- More characters

### Long-term
- Story mode
- Tournament mode
- Character customization
- DLC characters

---

## SUCCESS CRITERIA

### Technical Goals
✅ Maintains 60 FPS locked at all times  
✅ Input buffer works within 5 frames  
✅ Hitboxes are frame-accurate  
✅ No game-breaking bugs  

### Design Goals
✅ Block-as-resource feels fair and strategic  
✅ 28 moves per character provides depth  
✅ Characters feel distinct from each other  
✅ Combat is easy to learn, hard to master  

### Polish Goals
✅ UI is clean and informative  
✅ VFX and audio provide clear feedback  
✅ Menus are responsive and intuitive  
✅ Game looks and sounds professional  

---

## NOTES

- **Stay flexible:** Adjust timeline based on progress
- **Playtest early:** Get feedback from Week 8 onwards
- **Document everything:** Keep design docs updated
- **Focus on core:** Polish can wait, gameplay cannot
- **Iterate quickly:** Fix issues as they arise

**Remember:** A polished game with 2 characters is better than a buggy game with 10 characters.

---

## NEXT STEPS

**Start Here:**
1. Set up Godot project
2. Implement GameManager with tick system
3. Test 60 FPS lock
4. Implement InputManager
5. Create first test character

**Week 1 Checklist:**
- [ ] Project created and configured
- [ ] GameManager autoload working
- [ ] Global frame counter incrementing
- [ ] Basic test scene with debug display
- [ ] Git repository initialized

Good luck! 🎮
