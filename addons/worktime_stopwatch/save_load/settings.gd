extends RefCounted

signal settings_updated

#const FILE_PATH := "res://addons/worktime_stopwatch_settings.cfg"

const DEFAULT_AUTO_START_STOPWATCH_ON_LOAD := false
const DEFAULT_CURRENT_DAILY_WORK_TIME_MINUTES := 20.0
const DEFAULT_GODOT_PROJECT_WINDOW := true
const DEFAULT_OTHER_WINDOWS := true
const DEFAULT_OTHER_WINDOWS_KEYWORDS := "Blender, ArmorPaint, Aseprite, LMMS, Audacity, FL Studio"
const DEFAULT_CONTINUOUS_DATE_CHECK := false

var config: ConfigFile

var auto_start_stopwatch_on_load: bool
var current_daily_work_time_minutes: float
var godot_project_window: bool
var other_windows: bool
var other_windows_keywords: String
var continuous_date_check: bool

var _last_used_path := ""


func _init() -> void:
	config = ConfigFile.new()


func load_default_settings():
	auto_start_stopwatch_on_load = DEFAULT_AUTO_START_STOPWATCH_ON_LOAD
	current_daily_work_time_minutes = DEFAULT_CURRENT_DAILY_WORK_TIME_MINUTES
	godot_project_window = DEFAULT_GODOT_PROJECT_WINDOW
	other_windows = DEFAULT_OTHER_WINDOWS
	other_windows_keywords = DEFAULT_OTHER_WINDOWS_KEYWORDS
	continuous_date_check = DEFAULT_CONTINUOUS_DATE_CHECK


func are_settings_default() -> bool:
	var checks: Array[Callable] = [
		func(): return auto_start_stopwatch_on_load == DEFAULT_AUTO_START_STOPWATCH_ON_LOAD,
		func(): return is_equal_approx(current_daily_work_time_minutes, DEFAULT_CURRENT_DAILY_WORK_TIME_MINUTES),
		func(): return godot_project_window == DEFAULT_GODOT_PROJECT_WINDOW,
		func(): return other_windows == DEFAULT_OTHER_WINDOWS,
		func(): return other_windows_keywords == DEFAULT_OTHER_WINDOWS_KEYWORDS,
		func(): return continuous_date_check == DEFAULT_CONTINUOUS_DATE_CHECK
	]
	
	for c in checks:
		if not c.call():
			return false
	
	return true


func load_settings(path: String = "") -> int:
	if path == "":
		path = _last_used_path
	else:
		_last_used_path = path
	
	# load the file
	config = ConfigFile.new()
	var err := config.load(path)

	if err != OK:
		return err
	
	# apply the values in the config to the member variables
	auto_start_stopwatch_on_load = config.get_value(
			"auto_start",
			"auto_start_stopwatch_on_load",
			DEFAULT_AUTO_START_STOPWATCH_ON_LOAD
	)
	current_daily_work_time_minutes = config.get_value(
			"daily_work_time",
			"current_daily_work_time_minutes",
			DEFAULT_CURRENT_DAILY_WORK_TIME_MINUTES
	)
	godot_project_window = config.get_value(
			"focused_window_behavior",
			"godot_project_window",
			DEFAULT_GODOT_PROJECT_WINDOW
	)
	other_windows = config.get_value(
			"focused_window_behavior",
			"other_windows",
			DEFAULT_OTHER_WINDOWS
	)
	other_windows_keywords = config.get_value(
			"focused_window_behavior",
			"other_windows_keywords",
			DEFAULT_OTHER_WINDOWS_KEYWORDS
	)
	continuous_date_check = config.get_value(
			"date_checking_behavior",
			"continuous_date_check",
			DEFAULT_CONTINUOUS_DATE_CHECK
	)
	
	settings_updated.emit()
	
	return err


func save(path: String = ""):
	if path == "":
		path = _last_used_path
	else:
		_last_used_path = path
	
	# we put the values of the member variables in the config file and then save it
	config.set_value("auto_start", "auto_start_stopwatch_on_load", auto_start_stopwatch_on_load)
	config.set_value("daily_work_time", "current_daily_work_time_minutes", current_daily_work_time_minutes)
	config.set_value("focused_window_behavior", "godot_project_window", godot_project_window)
	config.set_value("focused_window_behavior", "other_windows", other_windows)
	config.set_value("focused_window_behavior", "other_windows_keywords", other_windows_keywords)
	config.set_value("date_checking_behavior", "continuous_date_check", continuous_date_check)
	
	config.save(path)
	settings_updated.emit()
