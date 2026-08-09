class_name HumanoidMobility
extends RefCounted

## Shared physical profile for ordinary human-controlled and AI actors.
##
## A full authored block is one metre high. The extra quarter metre keeps the
## jump usable with discrete physics steps and at the lip of a block instead of
## making the nominal apex exactly equal to the obstacle.
const GRAVITY := 18.0
const JUMP_HEIGHT := 1.25
const JUMP_VELOCITY := 6.7082039325 # sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
