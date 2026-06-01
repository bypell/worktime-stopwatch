@tool
extends Resource

#const SAVE_DATA_PATH := "res://addons/worktime_stopwatch_saved_data.tres"

@export var starting_date : Dictionary = {}
@export var current_day_data : Resource = null
@export var previous_days_data : Array[Resource] = []

var _last_used_path := ""


func save_data(path: String = "") -> int:
	if path == "":
		path = _last_used_path
	else:
		_last_used_path = path
		
	return ResourceSaver.save(self, path)


static func load_saved_data(path: String) -> Resource:
	if FileAccess.file_exists(path):
		return load(path)
	
	if FileAccess.file_exists("addons/worktime_stopwatch_saved_data.res"):
		return load("res://addons/worktime_stopwatch_saved_data.res")
	
	return load(path)


static func verify_saved_data_exists(saved_data_path: String) -> bool:
	return ResourceLoader.exists(saved_data_path)
