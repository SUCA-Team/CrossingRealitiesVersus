# GAME DESIGN DOCUMENT  
## CROSSING REALITIES VERSUS

**Genre:** 2D Fighting Game  
**Platform:** PC  
**Target:** Local PvP  
**Control Scheme:** Keyboard-first  
**Status:** Pre-production GDD  

---

## 1. VISION & DESIGN GOALS

### 1.1. Core Objectives

Crossing Realities Versus is designed to:

- Prioritize direct competitive play (local PvP)
- Be fully playable on keyboard, with no motion inputs required
- Emphasize tactical decision-making over complex execution
- Apply pressure through resources, positioning, and pacing
- Reduce reliance on traditional high/low mix-ups

The game targets fighting game players who prefer reading situations and committing to risks rather than relying on airtight defense.

---

### 1.2. Design Philosophy

> “Blocking is a choice, not a safe state.”

- No crouching
- No overhead / low attacks
- Defense consumes resources and accumulates risk over time

---

## 2. PROJECT SCOPE & DIRECTION

### 2.1. Initial Phase Scope

**Includes:**
- Local PvP
- Basic UI

---

## 3. CONTROLS & INPUT SYSTEM

### 3.1. Movement Inputs (Left Hand)

| Input   | Function |
|--------|----------|
| Forward | Move forward |
| Back   | Move backward |
| Up     | Jump (up to 2 air jumps) |
| Down   | Block |

---

### 3.2. Action Inputs (Right Hand)

| Button    | Function |
|-----------|----------|
| Light     | Light attack |
| Heavy     | Heavy attack |
| Special 1 | Skill |
| Special 2 | Skill |
| Special 3 | Skill |
| Dash      | Dash |

Total: 6 action buttons.

---

### 3.3. Modifier Rules

- Modifiers are determined by directional inputs
- Modifier + action must be entered on the same frame or within the allowed input window
- No motion inputs are used

---

## 4. MOVEMENT & DASH SYSTEM

### 4.1. Jumping

- Ground jump + 1 air jump
- Flexible aerial control

---

### 4.2. Dash System (Universal)

| Input                  | Name        | Effect                         | Cost     |
|------------------------|-------------|--------------------------------|----------|
| Dash                   | Dash        | Fast movement                  | Stamina  |
| Down + Dash            | Heavy Dash  | Phases through bodies / moves  | High     |
| Forward + Down + Dash  | Grab        | Catches block / idle state     | 0        |
| Back + Down + Dash     | Evade       | Quick evade (i-frames)         | 0        |

Dash is the primary pacing tool, not just a movement option.

---

## 5. MOVE TAXONOMY (PER CHARACTER)

### 5.1. Normals

**Light Attacks (5):**
- Neutral Light  
- Forward + Light  
- Back + Light  
- Down + Light  
- Air Light  

**Heavy Attacks (3):**
- Neutral Heavy  
- Down + Heavy  
- Air Heavy  

**Total Normals:** 8

---

### 5.2. Specials

Applies to **Special 1 / 2 / 3**:

| State     | Modifier        |
|-----------|-----------------|
| Normal    | Neutral, Down   |
| Enhanced | Neutral, Down   |

→ 2 variants per skill  
→ 3 skills  
→ 12 specials

---

### 5.3. Ultimates

| Input              | Type      |
|--------------------|-----------|
| S1 + S2            | Super     |
| S2 + S3            | Super     |
| S1 + S3            | Super     |
| S1 + S2 + S3       | Ultimate  |

Total: 4

---

### 5.4. Universal Actions

- Dash  
- Heavy Dash  
- Evade  
- Grab  

---

### 5.5. Total Move Count

**28 moves per character**

This is a hard limit to control complexity and balance.

---

## 6. RESOURCE SYSTEM

### 6.1. HP

- Traditional health bar
- Default: 1000 HP

---

### 6.2. Stamina (PRIMARY DESIGN AXIS)

**Properties:**
- Regenerates quickly while idle
- Regeneration is interrupted when performing actions
- Does not regenerate while blocking

**On successful block:**
- Take chip damage
- Lose stamina

**When stamina reaches 0:**
- Character becomes stunned
- Cannot act for a fixed duration
- Fully open to punishment

---

### 6.3. Stamina Cost (Baseline)

| Action          | Cost |
|-----------------|------|
| Dash            | 10   |
| Heavy Dash      | 30   |
| Light           | ~3   |
| Heavy           | ~6   |
| Special         | ~10  |
| Evade / Grab   | 0    |
| Ultimate        | 0    |

---

### 6.4. Super / Meter

- No universal standard
- Each character has their own system

---

## 7. STATUS & PASSIVE SYSTEM

### 7.1. Status Effects

- Buffs / Debuffs / Stacks
- Can stack
- Duration-based or condition-based expiration

Examples:
- Burn
- Armor
- Stack-based regeneration

---

### 7.2. Passive Abilities

Each character must have exactly **1 Passive**.

A Passive:
- Changes the rules of play
- Defines the character archetype
- Is not a simple stat boost

A good Passive:
- Has activation conditions
- Comes with risks or limitations
- Forces players into a specific playstyle

---

## 8. COMBO & DAMAGE SCALING

- Higher hit count → lower damage per hit
- Longer combos → higher stamina consumption
- Reduces the effectiveness of spam
