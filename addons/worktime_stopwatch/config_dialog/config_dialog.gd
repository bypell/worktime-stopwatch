@tool
extends Window

signal progress_reset_accepted
signal requested_save_calendar_as_csv(path: String, delimiter: String)

@onready var scroll_container : ScrollContainer = %ScrollContainer
@onready var calendar_ui: MarginContainer = %Calendar
@onready var settings_ui: MarginContainer = %Settings


func _ready():
	# TODO use is_part_of_edited_scene() once it's exposed
	#if not get_tree().edited_scene_root == null and get_tree().edited_scene_root in [self, owner]:
		#return
	if is_part_of_edited_scene():
		return
		
	
	$TabContainer.current_tab = 0
	
	if scroll_container.has_theme_stylebox_override("panel"):
		scroll_container.remove_theme_stylebox_override("panel")
	
	scroll_container.add_theme_stylebox_override("panel", get_theme_stylebox("Background", "EditorStyles"))
	$Panel.color = get_theme_color("base_color", "Editor")


func _notification(what : int) -> void:
	if (what == NOTIFICATION_WM_CLOSE_REQUEST):
		hide()


func update_displayed_info(saved_data_instance):
	calendar_ui.update_displayed_info(saved_data_instance)


func setup_settings_ui(settings: Object):
	settings_ui.setup(settings)


func _on_reset_progress_button_pressed() -> void:
	%ResetProgressConfirmationDialog.popup_centered()


func _on_reset_progress_confirmation_dialog_confirmed() -> void:
	progress_reset_accepted.emit()


func _on_extra_csv_export_destination_chosen(path: String, delimiter: String) -> void:
	requested_save_calendar_as_csv.emit(path, delimiter)
