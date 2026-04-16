extends Node


# Copy pasted from Google Sheets
enum ActionNames {TEMPORARY_CAMP, WOODEN_WALLS, HUNTERS_LODGE, WOODCUTTERS_HUT, GATHER_WOOD, TRAIN_SOLDIERS, SCOUT, FARM, ANIMAL_PENS, QUARRY, GATHER_FOOD, GRANARY, STONE_WALL, GUARD_TOWER, MILL, MARKET, BARRACKS, HELP_MONTREK, STABLES, IRON_MINE, SAWMILL, STEELWORKS, BLOOMERY, COAL_MINE, SMITHY, MINE_CARTS, LABOR_HALLS, POWER_PLANT, ASSEMBLY_LINE, WORKSHOP, CANONS, TANK_FACTORY, REFINERY, TANK, FACTORY, SEMICOND, OIL_PUMPS, URAN_MINE, COMPUTER, GIGAFACTORY, AI, ROBOT, DRONE, MISSILES, HELP_ADVANCED}
enum ResearchNames {BASIC_TOOLS = 100, AGRICULTURE = 101, BASIC_DEFENCE = 102, BUILD_ROAD = 103, STONE_WORKING = 104, BOWMAKERS = 105, SCOUT_MINES = 106, CAVE_STORAGE = 107, TIER_II = 108, IRON_TOOLS = 109, METALLURGY = 110, SCOUT_RUINS = 111, SCOUT_SURROUNDINGS = 112, SCOUT_HILLS = 113, SCOUT_CAVES = 114, SCOUT_COAL = 115, STEEL_TOOLS = 116, STEAM = 117, GUNPOWDER  = 118, TRAINS = 119, STONE_ROAD = 120, RAILWAY = 121, ELECTRICITY = 122, IT = 123, ABOMB = 124, ROCKET = 125, BUNKER = 126, BELT = 127, OIL = 128, ATOM_POWER = 129, AIR = 130, AIRPORT = 131, PROGRAM = 132, SPACE = 133}


var actions : Dictionary[int, Actions] = {} 
# Runtime state
var action_state :Dictionary[int,float]= {} # id -> progress
# Execution
var queue : Array[int] = []                 # IDs
var current_action_id : int = -1
# Completion tracking
var finished_researched : Array[int] = [] #IDs
# soldier modifier
const SOLDIER_DEF := 4 # change if changed in Google sheets 
var soldier_multiplier: int = 1


func _ready() -> void:
	SignalManager.connect("hour_passed", tick_actions)


# puts build actions into unlocked == false except ID 0, returns available -> [0]
func loop_buildings() -> Array[int]:
	reset_action_state()
	# reset all on loop
	queue = []
	current_action_id = -1
	# return array initiazition:
	var available : Array[int] = []
	# loop buildings
	for id in actions.keys():
		var action : Actions = actions[id]
		# Applies completed soldier upgrade research (soldier_multiplier) to action
		if action.ID == ActionNames.TRAIN_SOLDIERS:
			action.reward["defence"] = SOLDIER_DEF * soldier_multiplier 
		# Lock all actions except the first one
		if action.type != Actions.ActionTypes.RESEARCH:
			action.unlocked = false
	# Check first unlocks after looping
	unlock_actions_and_research()
	return available

func reset_action_state()->void:
	var new_action_state: Dictionary[int, float]
	for key in action_state:
		if key >= 100:
			new_action_state[key] = action_state[key]
		else:
			continue
	action_state = new_action_state


# used for saving
func export_state() -> Dictionary:
	return {
		"action_state": action_state,
		"queue": queue,
		"current_action_id": current_action_id,
		"finished_researched": finished_researched,
		"soldier_multiplier": soldier_multiplier
	}

# used for loading
func import_state(state: Dictionary) -> void:
	action_state = state.get("action_state", {})
	queue = state.get("queue", [])
	current_action_id = state.get("current_action_id", -1)
	finished_researched = state.get("finished_researched", [])
	soldier_multiplier = state.get("soldier_multiplier", 1)
	# multiply soldiers to correct multiplier - from load and check if Barracks
	multiply_soldiers_deff_production(soldier_multiplier)
	if GlobalVars.village.is_built(16):
		ActionsManager.multiply_soldiers_deff_production(1.5)


func reset() -> void:
	action_state = {}
	queue = []
	current_action_id = -1
	finished_researched = []
	soldier_multiplier = 1


# returns Actions object based on it's ID
func return_Action_based_on_ID(actionID: int) -> Actions:
	return actions.get(actionID)


func queue_action(actionID: int) -> void:
	if current_action_id == -1:
		start_action_by_ID(actionID)
	else:
		queue.append(actionID)
		SignalManager.emit_signal("action_started_or_queued")

func delete_action_from_queue(index:int)->void:
	# index for current action
	if index == -1:
		start_next_action_from_queue()
	else:
		queue.remove_at(index)
	SignalManager.emit_signal("action_started_or_queued")


func start_action_by_ID(actionID: int) -> void:
	if !can_start_action(actionID):
		return
	var action := get_action(actionID)
	if action.type in [Actions.ActionTypes.BUILD, Actions.ActionTypes.REPEATABLE] and !has_been_paid(action.ID):
		GlobalVars.village.spend_resources(action.costs)
	# is queue empty? If no, push ID to queue, else check if not paused manually (resume time)
	if current_action_id != -1:
		queue.push_front(current_action_id)
	elif !TimeManager.manual_lock:
		TimeManager.resume_time()
	current_action_id = actionID
	if !action_state.has(actionID):
		action_state[actionID] = 0.0
	SignalManager.emit_signal("action_started_or_queued")


# applies workforce to current action, if done, applies rest to next one
func tick_actions(is_workhour) -> void:
	if current_action_id == -1 or !is_workhour:
		return

	var workforce : float = GlobalVars.village.inventory.workforce

	while workforce > 0 and current_action_id != -1:
		var action := actions[current_action_id]

		# Ensure state exists
		if !action_state.has(current_action_id):
			action_state[current_action_id] = 0.0

		var progress = action_state[current_action_id]
		var remaining : float = action.work_hours - progress

		var work_spent :float = min(workforce, remaining)
		progress += work_spent
		workforce -= work_spent

		action_state[current_action_id] = progress

		# Action finished
		if progress >= action.work_hours:
			complete_current_action()


func complete_current_action() -> void:
	if current_action_id == ResearchNames.ROCKET and GlobalVars.end_of_game == false:
		SignalManager.EndOfGame.emit()
		return
	var id := current_action_id
	var action :Actions = actions[id]
	# handle different type of actions behavior
	match action.type:
		Actions.ActionTypes.BUILD:
			GlobalVars.village.mark_building_complete(action)
			action_state.erase(id)
		Actions.ActionTypes.REPEATABLE:
			GlobalVars.village.add_rewards(action.reward, GlobalVars.village.inventory)
			action_state[id] = 0.0
		Actions.ActionTypes.RESEARCH:
			finished_researched.append(id)
			action_state.erase(id)
			if action.effect_id != "":
				handle_research_effect(action.effect_id)
				if action.effect_id == "end_first_loop":
					return
			if ProgressionManager.current_goal_ID == action.ID:
				ProgressionManager.set_next_goal_active()
	# unlock actions
	unlock_actions_and_research()
	# Move to next action
	start_next_action_from_queue()
	SignalManager.emit_signal("action_completed", action.ID, action.logs)


# loops through action queue, checks if any can be started. 
func start_next_action_from_queue() -> void:
	current_action_id = -1
	# while queue is not empty go to next item and check that, 
	while !queue.is_empty():
		var next_id : int = queue.pop_front() # discards it, not needed if cannot be started 
		#if can be started, saves it to current_action_id and exits function
		if can_start_action(next_id):
			start_action_by_ID(next_id)
			return
	# No valid action found, stop time
	TimeManager.stop_time()


func get_available_actions() -> Array[int]:
	var result : Array[int] = []
	for id in actions:
		var a : Actions = actions[id]
		# skip locked actions
		if !a.unlocked:
			continue
		# skip build actions that have been built 
		if a.type == Actions.ActionTypes.BUILD and GlobalVars.village.is_built(id): continue
		# skip repeatable actions whose reward would take soft lock player with 0 workforce.
		if a.type == Actions.ActionTypes.REPEATABLE and a.reward.has("workforce"):
			if ((-a.reward["workforce"]) >= GlobalVars.village.inventory["workforce"]):
				continue
		# skip researched
		if a.type == Actions.ActionTypes.RESEARCH and finished_researched.has(id):
			continue
		# if didn't skip, add to result
		result.append(id)
	return result


func get_action(id: int) -> Actions:
	return actions.get(id)

func get_action_state(id:int) -> float:
	if action_state.has(id):
		return action_state[id]
	else:
		return 0.0

func has_been_paid(action_ID:int)->bool:
	return action_state.keys().has(action_ID)

func is_build_available(id: int) -> bool:
	var action := actions[id]
	if action.type != Actions.ActionTypes.BUILD:
		return false
	if !action.unlocked:
		return false
	if GlobalVars.village.is_built(id):
		return false
	return true


# this is where I will check if enough resources 
func can_start_action(id: int) -> bool:
	var a :Actions = actions.get(id)
	if !a.unlocked:
		SignalManager.add_log.emit("Cannot start action, action locked.")
		return false
	# check if started
	if has_been_paid(a.ID):
		return true
	# check costs
	if a.type == Actions.ActionTypes.RESEARCH:
		return !ActionsManager.finished_researched.has(id)
	if !GlobalVars.village.can_afford(a.costs):
		SignalManager.add_log.emit("Cannot start action, not enough resources.")
		return false
	if a.reward.has("workforce"):
		if ((-a.reward["workforce"]) >= GlobalVars.village.inventory["workforce"]):
			SignalManager.add_log.emit("Cannot start action, workforce would drop to 0.")
			return false
	return !GlobalVars.village.is_built(id)

# helper function, returns name from ID
func get_action_name(actionID: int) -> String:
	var action :Actions = actions.get(actionID)
	if action == null:
		return "UNKNOWN ACTION"
	return action.name
#func that returns type + name (build ThisBuilding, research ThatResearch) 
func get_action_display_name(actionID: int) -> String:
	var action :Actions= actions.get(actionID)
	if action == null:
		return "UNKNOWN ACTION"
	match action.type:
		Actions.ActionTypes.BUILD:
			return "Build: " + action.name
		Actions.ActionTypes.RESEARCH:
			if action.ui_category == "INFRASTRUCTURE":
				return "Build: " + action.name
			if action.ui_category == "SCOUT":
				return "Scout: " + action.name
			return "Research: " + action.name
		_:
			return action.name


# loops actions and research to unlock them
func unlock_actions_and_research() -> void:
	for id in actions.keys():
		var action : Actions = actions[id]
		# Skip already unlocked actions
		if action.unlocked:
			continue
		var all_requirements_met := true
		for req_id:int in action.prerequisites:
			var requirement_met := false
			# Requirement satisfied by building
			if GlobalVars.village.is_built(req_id):
				requirement_met = true
			# Requirement satisfied by research
			elif finished_researched.has(req_id):
				requirement_met = true
			#if not met, break (continue with next action)
			if !requirement_met:
				all_requirements_met = false
				break
		if all_requirements_met:
			action.unlocked = true
			SignalManager.action_unlocked.emit(id)
			print("Unlocked action:", action.name)


func clear_active_and_queue()->void:
	queue = []
	current_action_id = -1
	TimeManager.stop_time()


# function that handles research effects 
func handle_research_effect(effect_id:String)->void:
	match effect_id:
		"tools_up":
			GlobalVars.upgrade_level_up()
		"end_first_loop":
			TimeManager.toggle_time(true,true)
			current_action_id = -1
			SignalManager.emit_signal("end_first_loop")
		"connect_Montrek":
			OutpostManager.connect_Montrek()
		"cave_storage_up":
			GlobalVars.upgrade_level_up("cave")
		"stone_road":
			OutpostManager.infrastructure = "STONE_ROAD"
		"railroad":
			OutpostManager.infrastructure = "RAIL"
		"plane":
			OutpostManager.infrastructure = "PLANE"
		"train_soldiers_up":
			var effect_multiplier := 2
			soldier_multiplier *= effect_multiplier
			multiply_soldiers_deff_production(effect_multiplier)


# returns true if infrastructure research is active, used to stop village prooduction
func is_active_infrastructure_research()->bool:
	if current_action_id in [ResearchNames.BUILD_ROAD, ResearchNames.STONE_ROAD, ResearchNames.RAILWAY]:
		return true
	return false


# Multiplies soldiers (ID 5) rewards by modifier
func multiply_soldiers_deff_production(modifier) -> void:
	var action_to_change : BuildActions = ActionsManager.actions[5]
	action_to_change.reward["defence"] *= modifier
