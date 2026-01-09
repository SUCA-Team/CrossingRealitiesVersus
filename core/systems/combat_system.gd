## Combat system for hitbox collision and damage calculation.
##
## Uses manual rectangle collision (Rect2i) for determinism.
## No reliance on Godot's physics engine or Area2D signals.
##
## Handles:
## - Hitbox vs hurtbox collision
## - Damage application
## - Hit/block determination
## - Hitstun/blockstun
## - Combo scaling
##
## Design: Stateless processor (RefCounted).
class_name CombatSystem extends RefCounted

## Result of a hitbox collision.
class HitResult:
	var attacker_id: int
	var defender_id: int
	var damage: int
	var hitstun_frames: int
	var blockstun_frames: int
	var knockback: Vector2i
	var launches: bool
	
	func _init(_attacker: int, _defender: int):
		attacker_id = _attacker
		defender_id = _defender


## Check for collisions between two players.
##
## @param p1: PlayerSnapshot
## @param p2: PlayerSnapshot
## @return: Array of HitResult
static func check_collisions(p1: PlayerSnapshot, p2: PlayerSnapshot) -> Array:
	var results: Array = []
	
	# TODO: Phase 2 - Implement with HitboxSnapshot
	# For now, this is a placeholder
	# Will check p1.hitboxes vs p2.get_hurtbox()
	# and p2.hitboxes vs p1.get_hurtbox()
	
	return results


## Apply hit to defender.
##
## Calculates final damage with combo scaling.
## Sets defender to hitstun/blockstun state.
## Applies knockback.
static func apply_hit(
	defender: PlayerSnapshot,
	attacker: PlayerSnapshot,
	hit_result: HitResult,
	is_blocking: bool
) -> void:
	
	# Check invulnerability
	if not defender.can_be_hit():
		return  # Invulnerable, no hit
	
	if is_blocking:
		_apply_blockstun(defender, hit_result)
	else:
		_apply_hitstun(defender, attacker, hit_result)


## Apply blockstun (defender blocked the attack).
static func _apply_blockstun(defender: PlayerSnapshot, hit: HitResult) -> void:
	# Chip damage (10% of normal damage)
	var chip = int(hit.damage * 0.1)
	defender.health -= chip
	defender.health = max(defender.health, 0)
	
	# Enter blockstun
	defender.state_id = StateMachine.StateID.BLOCKSTUN
	defender.lockout_frames = hit.blockstun_frames
	defender.state_frame = 0
	
	# Minimal pushback
	defender.velocity.x = hit.knockback.x / 2
	
	defender.blocked_this_frame = true


## Apply hitstun (defender got hit).
static func _apply_hitstun(
	defender: PlayerSnapshot,
	attacker: PlayerSnapshot,
	hit: HitResult
) -> void:
	
	# Increment combo
	attacker.combo_count += 1
	
	# Calculate scaled damage
	var final_damage = hit.damage
	if attacker.combo_count > 1:
		var scaling = _get_combo_scaling(attacker.combo_count)
		final_damage = int(hit.damage * scaling)
	
	# Apply damage
	defender.health -= final_damage
	defender.health = maxi(defender.health, 0)
	
	# Enter hitstun
	if defender.is_grounded:
		defender.state_id = StateMachine.StateID.HITSTUN_GROUND
	else:
		defender.state_id = StateMachine.StateID.HITSTUN_AIR
	
	defender.lockout_frames = hit.hitstun_frames
	defender.state_frame = 0
	
	# Apply knockback
	PhysicsSystem.apply_knockback(defender, hit.knockback)
	
	# Set hit flags
	defender.hit_this_frame = true
	attacker.damage_this_frame = true  # Attacker also knows they hit


## Get combo scaling multiplier.
## Damage decreases as combo count increases.
static func _get_combo_scaling(combo_count: int) -> float:
	# Fighting game standard scaling
	match combo_count:
		1: return 1.0   # 100%
		2: return 0.9   # 90%
		3: return 0.8   # 80%
		4: return 0.7   # 70%
		5: return 0.6   # 60%
		_: return 0.5   # 50% minimum


## Reset combo if defender landed or too much time passed.
static func check_combo_reset(attacker: PlayerSnapshot, defender: PlayerSnapshot) -> void:
	# Reset combo if defender lands while not in hitstun
	if defender.is_grounded and \
	   defender.state_id != StateMachine.StateID.HITSTUN_GROUND and \
	   defender.state_id != StateMachine.StateID.HITSTUN_AIR:
		attacker.combo_count = 0


## Calculate damage with all modifiers.
## TODO: Add status effect multipliers in Phase 3
static func calculate_damage(
	base_damage: int,
	combo_count: int,
	_attacker: PlayerSnapshot,
	_defender: PlayerSnapshot
) -> int:
	
	var damage = base_damage
	
	# Combo scaling
	if combo_count > 1:
		damage = int(damage * _get_combo_scaling(combo_count))
	
	# TODO: Phase 3 - Status effect multipliers
	# var atk_multiplier = StatusSystem.get_multiplier(attacker, "damage")
	# var def_multiplier = StatusSystem.get_multiplier(defender, "defense")
	# damage = int(damage * atk_multiplier * def_multiplier)
	
	return damage
