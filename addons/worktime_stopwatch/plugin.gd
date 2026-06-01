@tool
extends EditorPlugin

const CONTINUOUS_DATE_CHECK_DELAY := 5.0

const SavedData = preload("res://addons/worktime_stopwatch/save_load/saved_data.gd")
const DayData = preload("res://addons/worktime_stopwatch/config_dialog/calendar/day_data.gd")

const MainWidget := preload("res://addons/worktime_stopwatch/dock/stopwatch_dock.tscn")
const ConfigDialog := preload("res://addons/worktime_stopwatch/config_dialog/config_dialog.tscn")
const Settings := preload("res://addons/worktime_stopwatch/save_load/settings.gd")

var saved_data_instance: Resource
var main_dock_instance: Control
var config_window_instance: Window
var settings: Object

var saved_data_dir := "res://addons/" # worktime_stopwatch_saved_data.tres
var saved_data_path := "res://addons/worktime_stopwatch_saved_data.tres"
var settings_dir := "res://addons/" # worktime_stopwatch_settings.cfg
var settings_path := "res://addons/worktime_stopwatch_settings.cfg"

var _continuous_date_check_cooldown := CONTINUOUS_DATE_CHECK_DELAY
var _continuous_date_check := false:
	set(value):
		_continuous_date_check = value
		set_process(value) # HACK should remove if more member variables related to a setting need process
		if value:
			_continuous_date_check_cooldown = CONTINUOUS_DATE_CHECK_DELAY


func _enter_tree() -> void:
	# loading potential settings and saved data path
	var config = ConfigFile.new()
	if FileAccess.file_exists("res://addons/worktime_stopwatch/local_paths_config.cfg"):
		var err := config.load("res://addons/worktime_stopwatch/local_paths_config.cfg")
		if err == OK:
			saved_data_dir = config.get_value(
					"local_settings",
					"saved_data_path",
					"res://addons/"
			)
			saved_data_path = saved_data_dir + "/worktime_stopwatch_saved_data.tres"
			settings_dir = config.get_value(
					"local_settings",
					"settings_path",
					"res://addons/"
			)
			settings_path = saved_data_dir + "/worktime_stopwatch_settings.cfg"
	else:
		config.set_value("local_settings", "saved_data_path", saved_data_dir)
		config.set_value("local_settings", "settings_path", settings_dir)
		config.save("res://addons/worktime_stopwatch/local_paths_config.cfg")
		
		var file = FileAccess.open("res://addons/worktime_stopwatch/.gitignore", FileAccess.WRITE)
		file.store_string("local_paths_config.cfg")
		file.close()
	
	# load settings and start listening to changes
	settings = Settings.new()
	if not FileAccess.file_exists(settings_path):
		settings.load_default_settings()
		settings.save(settings_path)
	else:
		settings.load_settings(settings_path)
	_continuous_date_check = settings.continuous_date_check
	settings.settings_updated.connect(_on_settings_updated)
	
	# load data
	_load_or_create_saved_data()
	
	# instantiation of dock and config window
	main_dock_instance = MainWidget.instantiate()
	config_window_instance = ConfigDialog.instantiate()
	
	# connecting widget signals
	main_dock_instance.settings_menu_opening_requested.connect(func(): config_window_instance.popup_centered())
	main_dock_instance.stopped_stopwatch.connect(_save_current_work_time)
	main_dock_instance.reset_stopwatch.connect(_save_current_work_time)
	main_dock_instance.started_stopwatch.connect(_save_current_work_time)
	
	# connecting config window signals
	config_window_instance.progress_reset_accepted.connect(
			func():
				_create_and_set_new_saved_data_object()
				main_dock_instance.force_reset_current_work_time()
				_refresh_stopwatch_widget()
				_refresh_config_window()
	)
	config_window_instance.requested_save_calendar_as_csv.connect(
			func(path: String, delimiter: String):
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_line("Day number,Date,Work time (seconds),Target work time (seconds)".replace(",", delimiter))
				# store every saved data
				for day_data in saved_data_instance.previous_days_data:
					var data : PackedStringArray = [
						str(day_data.day_number), 
						Time.get_date_string_from_unix_time((Time.get_unix_time_from_datetime_dict(day_data.date))), 
						str((int(day_data.work_time) / 1000)), 
						str(int(day_data.target_work_time) / 1000),
					]
					file.store_csv_line(data, delimiter)
				file.close()
	)
	
	# setting up settings ui
	config_window_instance.setup_settings_ui.bind(settings).call_deferred()
	
	# adding dock and windows
	config_window_instance.hide()
	EditorInterface.get_base_control().add_child(config_window_instance)
	_add_widget_as_dock(main_dock_instance)
	
	# update widget displays with data
	_initialize_stopwatch_widget()
	_refresh_config_window()
	main_dock_instance.settings_updated(settings)
	
	# auto start stopwatch if it was set in the settings
	if settings.auto_start_stopwatch_on_load:
		main_dock_instance.auto_start_stopwatch()


func _exit_tree() -> void:
	_save_current_work_time()
	
	remove_control_from_docks(main_dock_instance)
	main_dock_instance.queue_free()
	config_window_instance.queue_free()
	
	#settings.free()


func _process(delta: float) -> void:
	if _continuous_date_check:
		_continuous_date_check_cooldown -= delta
		if _continuous_date_check_cooldown <= 0.0:
			if _is_current_date_newer_than_saved_current_date():
				_save_current_work_time()
			_continuous_date_check_cooldown = CONTINUOUS_DATE_CHECK_DELAY


func _on_settings_updated():
	_continuous_date_check = settings.continuous_date_check
	
	main_dock_instance.settings_updated(settings)
	saved_data_instance.current_day_data.target_work_time = settings.current_daily_work_time_minutes * 60000
	
	_refresh_stopwatch_widget()


func _initialize_stopwatch_widget():
	main_dock_instance.initialize_displayed_info(saved_data_instance)


func _refresh_stopwatch_widget(update_displayed_current_work_time := false):
	main_dock_instance.update_displayed_info(saved_data_instance, update_displayed_current_work_time)


func _refresh_config_window():
	config_window_instance.update_displayed_info(saved_data_instance)


func _load_or_create_saved_data():
	if SavedData.verify_saved_data_exists(saved_data_path):
		# if data file exists, we load it
		saved_data_instance = SavedData.load_saved_data(saved_data_path)
		
		# if the current date inside of the saved data is older than the current date, we update it
		if _is_current_date_newer_than_saved_current_date():
			_switch_to_new_day()
	else:
		# if data file doesn't exist, we create one
		_create_and_set_new_saved_data_object()


func _create_and_set_new_saved_data_object():
	var current_date: Dictionary = Time.get_date_dict_from_system()
	saved_data_instance = SavedData.new()
	saved_data_instance.starting_date = current_date
	
	var current_day_data = DayData.new()
	current_day_data.day_number = 1
	current_day_data.date = current_date
	current_day_data.work_time = 0
	current_day_data.target_work_time = settings.current_daily_work_time_minutes * 60000
	
	saved_data_instance.current_day_data = current_day_data


func _add_widget_as_dock(widget_instance):
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, widget_instance)
	
	var tabs = widget_instance.get_parent().get_parent()
	var vsplit = tabs.get_parent()
	
	await get_tree().process_frame #disgusting
	await get_tree().process_frame #disgusting
	await get_tree().process_frame #still disgusting
	
	# this whole thing is disgusting
	
	vsplit.split_offsets[0] = 415


# Appends data from the current (outdated) day to previous_days_data
# and initializes data for a new day, including day_number, date, work_time = 0, figuring out target_work_time, etc.
func _switch_to_new_day():
	var current_date = Time.get_date_dict_from_system()
	if saved_data_instance.current_day_data.date == current_date:
		printerr("Tried to switch to a new day but the dates are the same.")
		return
	
	saved_data_instance.previous_days_data.append(saved_data_instance.current_day_data)
	
	var previous_current_day_data = saved_data_instance.current_day_data
	var new_current_day_data = DayData.new()
	
	new_current_day_data.day_number = previous_current_day_data.day_number + _get_days_diff_between_date_dicts(
			saved_data_instance.current_day_data.date,
			current_date
			)
	new_current_day_data.date = current_date
	new_current_day_data.work_time = 0
	new_current_day_data.target_work_time = settings.current_daily_work_time_minutes * 60000
	
	saved_data_instance.current_day_data = new_current_day_data
	#saved_data_instance.save_data()


# Saves current progress and if the date is no longer the same, makes the necessary calls to switch to a new day
func _save_current_work_time():
	saved_data_instance.current_day_data.work_time = main_dock_instance.get_elapsed_time()
	saved_data_instance.save_data(saved_data_path)
	
	if _is_current_date_newer_than_saved_current_date():
		_switch_to_new_day()
		_refresh_stopwatch_widget(true)
		_refresh_config_window()


# Gets the difference in days between two date dictionaries
func _get_days_diff_between_date_dicts(date_dict_1 : Dictionary, date_dict_2 : Dictionary) -> int:
	var date_1 = Time.get_unix_time_from_datetime_dict(date_dict_1)
	var date_2 = Time.get_unix_time_from_datetime_dict(date_dict_2)
	var delta = (date_2 - date_1)
	return (delta / 60 / 60 / 24)


# Returns whether the current date (in the loaded saved data) is no longer the actual date
func _is_current_date_newer_than_saved_current_date() -> bool:
	return _get_days_diff_between_date_dicts(saved_data_instance.current_day_data.date, Time.get_date_dict_from_system()) > 0
