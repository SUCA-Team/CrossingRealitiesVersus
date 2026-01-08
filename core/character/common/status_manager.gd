## Manages status effects applied to a character.
##
## Potential status effects:
## - Buffs (attack up, defense up, speed up)
## - Debuffs (poison, slow, stun)
## - Temporary invulnerability
## - Counter states
##
## Design: Node child of Character in scene tree.
## TODO: Implement status effect system.
class_name StatusManager extends Node

# TODO: Add status tracking
# var active_statuses: Array[StatusEffect] = []
# 
# func apply_status(status: StatusEffect) -> void:
#     active_statuses.append(status)
# 
# func tick(frame: int) -> void:
#     for status in active_statuses:
#         status.tick(frame)
#         if status.is_expired():
#             active_statuses.erase(status)
