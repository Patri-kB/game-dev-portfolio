extends Node

const SAVE_PATH = "user://savegame.tres"

var load_request = false
var loaded = false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST and !GlobalVars.end_of_game:
		save_game()
		print("Goodbye!")


# function that loads data from JSON and separates them into their classes
func import_actions_from_json(file_path: String, type:String = "BUILD"):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		printerr("Failed to open action file: ", file_path)
		return

	var json_data = JSON.parse_string(file.get_as_text())

	if json_data == null:
		printerr("Failed to parse JSON from file: ", file_path)
		return
	if type == "BUILD":
		import_build_actions(json_data)
	elif type == "RESEARCH":
		import_research_from_json(json_data) # Corrected to pass json_data

func import_build_actions(json_data):
	var loaded_actions :Dictionary[int, Actions]= {}
	for action_id:String in json_data:
		var action_info = json_data[action_id]
		var new_action : Actions = BuildActions.new()
		if action_info.get("is_repeatable", false):
			new_action.type = Actions.ActionTypes.REPEATABLE
		else:
			new_action.type = Actions.ActionTypes.BUILD

		#core info
		new_action.ID = action_id.to_int()
		new_action.name = action_info.get("Name", "Unnamed Action")
		new_action.description = action_info.get("description", "")
		#Gameplay data
		new_action.work_hours = action_info.get("work_hours", 1.0)
		new_action.prerequisites = action_info.get("prerequisites", [])
		new_action.costs = action_info.get("cost", {})
		new_action.logs = action_info.get("log", "")
		new_action.reward = action_info.get("reward", {})
		# Unlock state (definition-level default)
		new_action.unlocked = false
		# Store by ID
		loaded_actions[new_action.ID] = new_action
	# Assign to ActionsManager
	ActionsManager.actions = loaded_actions

func import_research_from_json(json_data): # Corrected signature
	var loaded_research_actions :Dictionary[int,Actions]= {}
	for action_id:String in json_data:
		var action_info = json_data[action_id]
		var new_action := Research.new()

		new_action.ID = action_id.to_int()
		new_action.type = Actions.ActionTypes.RESEARCH
		new_action.name = action_info.get("name", "Unnamed Research") 
		new_action.work_hours = action_info.get("work_hours", 1.0)
		new_action.prerequisites = action_info.get("prerequisites", [])
		new_action.effect_id = action_info.get("effect_id", "")
		new_action.description = action_info.get("description", "")
		new_action.ui_category = action_info.get("ui_category", "")
		new_action.logs = action_info.get("log", "")
		loaded_research_actions[new_action.ID] = new_action
		new_action.unlocked = false
	ActionsManager.actions.merge(loaded_research_actions)

# --- Save and Load Game State ---

func save_game(path:String = SAVE_PATH) -> void:
	var save_data: SaveGame = SaveGame.new()
	save_data.saved_GlobalVars = GlobalVars.export_state()
	save_data.saved_village = GlobalVars.village.export_state()
	save_data.current_goal_ID = ProgressionManager.current_goal_ID # only one variable saved
	save_data.saved_outpost_state = OutpostManager.export_state()
	save_data.saved_action_manager = ActionsManager.export_state()
	save_data.saved_time = TimeManager.export_state()
	ResourceSaver.save(save_data, path)

func load_game(path:String = SAVE_PATH) -> void:
	if not ResourceLoader.exists(path):
		print("Save file not found!")
		return
	var save_data:SaveGame = ResourceLoader.load(path) as SaveGame
	if not save_data:
		print("Failed to load save file!")
		return
	# Load the data
	if !GlobalVars.import_state(save_data.saved_GlobalVars):
		print("Game finished.")
		return
	GlobalVars.village.import_state(save_data.saved_village)
	TimeManager.import_state(save_data.saved_time)
	ActionsManager.import_state(save_data.saved_action_manager)
	ProgressionManager.import_state(save_data.current_goal_ID)
	OutpostManager.import_state(save_data.saved_outpost_state)
	# handle goals that are finished already
	ProgressionManager.set_next_goal_active()
	SignalManager.update_all_labels.emit()
	# set loaded flag to true
	loaded = true
	load_request = false



func reset_game_state()->void:
	GlobalVars.reset()
	ProgressionManager.reset()
	OutpostManager.reset()
	ActionsManager.reset()
	TimeManager.reset()
