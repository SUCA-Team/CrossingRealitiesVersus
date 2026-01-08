## Snapshot of input state for a single frame.
##
## Stores player input as bitmasks for efficient processing and buffering.
class_name InputData extends RefCounted

var player_id: int
var frame: int

var held_mask: int
var pressed_mask: int

func _init(pid: int, frm: int, hld_msk: int, prs_msk: int) -> void:
	player_id = pid
	frame = frm
	held_mask = hld_msk
	pressed_mask = prs_msk
