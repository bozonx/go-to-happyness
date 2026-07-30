class_name TerrainDetailCodec
extends RefCounted

## The detail byte of a terrain column (design_docs/engine/terrain_materials.md §5).
##
## ```
## bit 7 6 5 4 | 3 2 | 1 0
##     variant | wear | snow_depth
## ```
##
## Three surface states in ONE byte, not three parallel arrays: three arrays cost
## three cache misses per cell in the mesher and in the texture update, for a
## saving that does not exist. Snow rides into the save format for free — it took
## the two spare bits the parent document (§12) had already reserved — so seasons
## cost neither a bigger file nor a format version bump.
##
## `variant` is four bits wide, allowing up to sixteen visual variants without
## touching the saved column format. The GPU packs only the surface styles that
## are actually used; this field is an authored variant id, not an array layer.

const VARIANT_SHIFT := 4
const VARIANT_MASK := 0x0F
const WEAR_SHIFT := 2
const WEAR_MASK := 0x03
const SNOW_MASK := 0x03

## §6.1: untouched, trodden, a bare path. Three levels, no more — the fourth
## would have to mean something to navigation, and it does not.
const MAX_WEAR := 2
## §6.2: ~0.15 m, ~0.3 m, ~0.5 m of snow.
const MAX_SNOW_DEPTH := 3
const MAX_VARIANT := 15

const DEFAULT_DETAIL := 0


## Packs raw field values. Clamping here is to the FIELD WIDTH, not to the
## semantic range, so the codec is a bijection on all 256 bytes: a value read out
## of a save always packs back to the byte it came from, whatever wrote it. The
## semantic limit on wear (`MAX_WEAR`, two levels of a possible three) is enforced
## by the writers below, which is where a caller's intent actually is.
static func pack(variant: int, wear: int, snow_depth: int) -> int:
	return (
		(clampi(variant, 0, VARIANT_MASK) << VARIANT_SHIFT)
		| (clampi(wear, 0, WEAR_MASK) << WEAR_SHIFT)
		| clampi(snow_depth, 0, SNOW_MASK)
	)


static func variant_of(detail: int) -> int:
	return (detail >> VARIANT_SHIFT) & VARIANT_MASK


static func wear_of(detail: int) -> int:
	return (detail >> WEAR_SHIFT) & WEAR_MASK


static func snow_depth_of(detail: int) -> int:
	return detail & SNOW_MASK


static func with_variant(detail: int, variant: int) -> int:
	return (detail & ~(VARIANT_MASK << VARIANT_SHIFT)) | (clampi(variant, 0, MAX_VARIANT) << VARIANT_SHIFT)


static func with_wear(detail: int, wear: int) -> int:
	return (detail & ~(WEAR_MASK << WEAR_SHIFT)) | (clampi(wear, 0, MAX_WEAR) << WEAR_SHIFT)


static func with_snow_depth(detail: int, snow_depth: int) -> int:
	return (detail & ~SNOW_MASK) | clampi(snow_depth, 0, MAX_SNOW_DEPTH)
