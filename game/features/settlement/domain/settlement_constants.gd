class_name SettlementConstants
extends RefCounted

## Single source of truth for settlement gameplay tuning constants. Extracted
## from SettlementGame so the module owns its configuration without the 845-line
## scene script acting as a constants holder.

const CELL_SIZE := BuildingBlueprints.BLOCK_SIZE
const BUILDING_CLEARANCE_BLOCKS := 3.0
const NAVIGATION_CLEARANCE_MARGIN := 1.0
const MAX_BUILD_SLOPE := 0.35
const POPULATION := 4
const FOOD_PURCHASE_PRICE := 2
const ENTRANCE_GLOVE_PRICE := 20
const ENTRANCE_BUCKET_PRICE := 15
const ENTRANCE_WATER_PRICE := 2
const OUTSIDE_WORK_BASE_REWARD_MIN := 4
const OUTSIDE_WORK_BASE_REWARD_MAX := 12
const OUTSIDE_WORK_UPGRADE_REWARD := 16
const HOUSE_CAPACITY := 4
const CONSTRUCTION_DURATION := 4.0
const DEMOLITION_DURATION := 3.0
const INTERACTION_RANGE := 4.5
const POCKET_CAPACITY := 8
const SAWMILL_PROCESS_DURATION := 4.0

const GAME_DAY_REAL_SECONDS := 300.0
const GAME_MINUTES_PER_SECOND := 1440.0 / GAME_DAY_REAL_SECONDS

const WORKER_POLL_INTERVAL := 0.5

const OFFICIAL_WORKPLACE_TYPES: Array[String] = BuildingTypes.CIVIC_TYPES
const OFFICER_POST_RADIUS := 3.5
const FIRE_SUPPLY_TARGET := 4

const RABBIT_MAX_COUNT := 8

const ERA_CATEGORIES := ["tent", "earth", "clay", "wood", "stone", "brick"]
