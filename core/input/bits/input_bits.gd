## Input bit flags for efficient bitmasking operations.
##
## Uses bitwise operations to store all input states in a single integer.
## Each input is represented by a unique bit position (1 << n).
## This allows combining multiple inputs with OR (|) and checking with AND (&).
##
## Performance: Single int vs 10+ bool variables = faster comparisons, less memory.
## Example: mask = InputBits.UP | InputBits.LIGHT  # Both pressed
##          if mask & InputBits.UP: print("Up is pressed")
class_name InputBits

## Directional inputs (bits 0-3)
const UP    := 1 << 0  # 0b0000000001
const DOWN  := 1 << 1  # 0b0000000010
const LEFT  := 1 << 2  # 0b0000000100
const RIGHT := 1 << 3  # 0b0000001000

## Action buttons (bits 4-9)
const LIGHT    := 1 << 4  # 0b0000010000
const HEAVY    := 1 << 5  # 0b0000100000
const DASH     := 1 << 6  # 0b0001000000
const SPECIAL1 := 1 << 7  # 0b0010000000
const SPECIAL2 := 1 << 8  # 0b0100000000
const SPECIAL3 := 1 << 9  # 0b1000000000
