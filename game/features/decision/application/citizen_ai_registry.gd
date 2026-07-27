class_name CitizenAIRegistry
extends RefCounted

## Centralized catalog of citizen AI goals and settlement order providers.
## Keeps the bootstrapper free of feature-internal class lists.

static func default_goals() -> Array[AICitizenGoal]:
	return [
		SleepGoal.new(),
		MealGoal.new(),
		ToiletGoal.new(),
		RestGoal.new(),
		ReturnHomeWhenIdleGoal.new(),
		FollowLeaderGoal.new(),
		RegisterGoal.new(),
		ForestryGoal.new(),
		FarmingGoal.new(),
		ConstructionGoal.new(),
		GatheringGoal.new(),
		CleaningGoal.new(),
		ExcavationGoal.new(),
		ServiceWorkGoal.new(),
		FactoryWorkGoal.new(),
		CourierDeliveryGoal.new(),
	]


static func default_order_providers() -> Array[OrderProvider]:
	return [
		WorkforceOrderProvider.new(),
		DailyPlayerOrderProvider.new(),
		ForestryOrderProvider.new(),
		FarmingOrderProvider.new(),
		ConstructionOrderProvider.new(),
		GatheringOrderProvider.new(),
		ExcavationOrderProvider.new(),
		ServiceWorkOrderProvider.new(),
		FactoryWorkOrderProvider.new(),
		CourierDeliveryOrderProvider.new(),
	]
